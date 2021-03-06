// WebAssemblyInstrInfo.td-Describe the WebAssembly Instructions-*- tablegen -*-
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
///
/// \file
/// \brief WebAssembly Instruction definitions.
///
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// WebAssembly Instruction Predicate Definitions.
//===----------------------------------------------------------------------===//

def HasAddr32 : Predicate<"!Subtarget->hasAddr64()">;
def HasAddr64 : Predicate<"Subtarget->hasAddr64()">;
def HasSIMD128 : Predicate<"Subtarget->hasSIMD128()">,
                           AssemblerPredicate<"FeatureSIMD128", "simd128">;

//===----------------------------------------------------------------------===//
// WebAssembly-specific DAG Node Types.
//===----------------------------------------------------------------------===//

def SDT_WebAssemblyCallSeqStart : SDCallSeqStart<[SDTCisVT<0, iPTR>]>;
def SDT_WebAssemblyCallSeqEnd :
    SDCallSeqEnd<[SDTCisVT<0, iPTR>, SDTCisVT<1, iPTR>]>;
def SDT_WebAssemblyCall0    : SDTypeProfile<0, -1, [SDTCisPtrTy<0>]>;
def SDT_WebAssemblyCall1    : SDTypeProfile<1, -1, [SDTCisPtrTy<1>]>;
def SDT_WebAssemblyBrTable  : SDTypeProfile<0, -1, [SDTCisPtrTy<0>]>;
def SDT_WebAssemblyArgument : SDTypeProfile<1, 1, [SDTCisVT<1, i32>]>;
def SDT_WebAssemblyReturn   : SDTypeProfile<0, -1, []>;
def SDT_WebAssemblyWrapper  : SDTypeProfile<1, 1, [SDTCisSameAs<0, 1>,
                                                   SDTCisPtrTy<0>]>;

//===----------------------------------------------------------------------===//
// WebAssembly-specific DAG Nodes.
//===----------------------------------------------------------------------===//

def WebAssemblycallseq_start :
    SDNode<"ISD::CALLSEQ_START", SDT_WebAssemblyCallSeqStart,
           [SDNPHasChain, SDNPOutGlue]>;
def WebAssemblycallseq_end :
    SDNode<"ISD::CALLSEQ_END", SDT_WebAssemblyCallSeqEnd,
           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;
def WebAssemblycall0 : SDNode<"WebAssemblyISD::CALL0",
                              SDT_WebAssemblyCall0,
                              [SDNPHasChain, SDNPVariadic]>;
def WebAssemblycall1 : SDNode<"WebAssemblyISD::CALL1",
                              SDT_WebAssemblyCall1,
                              [SDNPHasChain, SDNPVariadic]>;
def WebAssemblybr_table : SDNode<"WebAssemblyISD::BR_TABLE",
                                 SDT_WebAssemblyBrTable,
                                 [SDNPHasChain, SDNPVariadic]>;
def WebAssemblyargument : SDNode<"WebAssemblyISD::ARGUMENT",
                                 SDT_WebAssemblyArgument>;
def WebAssemblyreturn   : SDNode<"WebAssemblyISD::RETURN",
                                 SDT_WebAssemblyReturn, [SDNPHasChain]>;
def WebAssemblywrapper  : SDNode<"WebAssemblyISD::Wrapper",
                                 SDT_WebAssemblyWrapper>;

//===----------------------------------------------------------------------===//
// WebAssembly-specific Operands.
//===----------------------------------------------------------------------===//

let OperandNamespace = "WebAssembly" in {

let OperandType = "OPERAND_BASIC_BLOCK" in
def bb_op : Operand<OtherVT>;

let OperandType = "OPERAND_FP32IMM" in
def f32imm_op : Operand<f32>;

let OperandType = "OPERAND_FP64IMM" in
def f64imm_op : Operand<f64>;

let OperandType = "OPERAND_P2ALIGN" in {
def P2Align : Operand<i32> {
  let PrintMethod = "printWebAssemblyP2AlignOperand";
}
} // OperandType = "OPERAND_P2ALIGN"

} // OperandNamespace = "WebAssembly"

//===----------------------------------------------------------------------===//
// WebAssembly Instruction Format Definitions.
//===----------------------------------------------------------------------===//

include "WebAssemblyInstrFormats.td"

//===----------------------------------------------------------------------===//
// Additional instructions.
//===----------------------------------------------------------------------===//

multiclass ARGUMENT<WebAssemblyRegClass vt> {
  let hasSideEffects = 1, Uses = [ARGUMENTS], isCodeGenOnly = 1 in
  def ARGUMENT_#vt : I<(outs vt:$res), (ins i32imm:$argno),
                       [(set vt:$res, (WebAssemblyargument timm:$argno))]>;
}
multiclass SIMD_ARGUMENT<ValueType vt> {
  let hasSideEffects = 1, Uses = [ARGUMENTS], isCodeGenOnly = 1 in
  def ARGUMENT_#vt : SIMD_I<(outs V128:$res), (ins i32imm:$argno),
                            [(set (vt V128:$res),
                                  (WebAssemblyargument timm:$argno))]>;
}
defm : ARGUMENT<I32>;
defm : ARGUMENT<I64>;
defm : ARGUMENT<F32>;
defm : ARGUMENT<F64>;
defm : SIMD_ARGUMENT<v16i8>;
defm : SIMD_ARGUMENT<v8i16>;
defm : SIMD_ARGUMENT<v4i32>;
defm : SIMD_ARGUMENT<v4f32>;

let Defs = [ARGUMENTS] in {

// get_local and set_local are not generated by instruction selection; they
// are implied by virtual register uses and defs.
multiclass LOCAL<WebAssemblyRegClass vt> {
let hasSideEffects = 0 in {
  // COPY_LOCAL is not an actual instruction in wasm, but since we allow
  // get_local and set_local to be implicit, we can have a COPY_LOCAL which
  // is actually a no-op because all the work is done in the implied
  // get_local and set_local.
  let isAsCheapAsAMove = 1 in
  def COPY_LOCAL_#vt : I<(outs vt:$res), (ins vt:$src), [],
                         "copy_local\t$res, $src">;

  // TEE_LOCAL is similar to COPY_LOCAL, but writes two copies of its result.
  // Typically this would be used to stackify one result and write the other
  // result to a local.
  let isAsCheapAsAMove = 1 in
  def TEE_LOCAL_#vt : I<(outs vt:$res, vt:$also), (ins vt:$src), [],
                        "tee_local\t$res, $also, $src">;
} // hasSideEffects = 0
}
defm : LOCAL<I32>;
defm : LOCAL<I64>;
defm : LOCAL<F32>;
defm : LOCAL<F64>;
defm : LOCAL<V128>, Requires<[HasSIMD128]>;

let isMoveImm = 1, isAsCheapAsAMove = 1, isReMaterializable = 1 in {
def CONST_I32 : I<(outs I32:$res), (ins i32imm:$imm),
                  [(set I32:$res, imm:$imm)],
                  "i32.const\t$res, $imm">;
def CONST_I64 : I<(outs I64:$res), (ins i64imm:$imm),
                  [(set I64:$res, imm:$imm)],
                  "i64.const\t$res, $imm">;
def CONST_F32 : I<(outs F32:$res), (ins f32imm_op:$imm),
                  [(set F32:$res, fpimm:$imm)],
                  "f32.const\t$res, $imm">;
def CONST_F64 : I<(outs F64:$res), (ins f64imm_op:$imm),
                  [(set F64:$res, fpimm:$imm)],
                  "f64.const\t$res, $imm">;
} // isMoveImm = 1, isAsCheapAsAMove = 1, isReMaterializable = 1

} // Defs = [ARGUMENTS]

def : Pat<(i32 (WebAssemblywrapper tglobaladdr:$addr)),
          (CONST_I32 tglobaladdr:$addr)>;
def : Pat<(i32 (WebAssemblywrapper texternalsym:$addr)),
          (CONST_I32 texternalsym:$addr)>;

//===----------------------------------------------------------------------===//
// Additional sets of instructions.
//===----------------------------------------------------------------------===//

include "WebAssemblyInstrMemory.td"
include "WebAssemblyInstrCall.td"
include "WebAssemblyInstrControl.td"
include "WebAssemblyInstrInteger.td"
include "WebAssemblyInstrConv.td"
include "WebAssemblyInstrFloat.td"
include "WebAssemblyInstrAtomics.td"
include "WebAssemblyInstrSIMD.td"
