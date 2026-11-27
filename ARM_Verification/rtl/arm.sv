// ============================================================================
// arm.sv - ARM single-cycle processor (HDL Example 7.1): controller + datapath
// ============================================================================
`timescale 1ns/1ps

module arm(input  logic        clk, reset,
           output logic [31:0] PC,
           input  logic [31:0] Instr,
           output logic        MemWrite,
           output logic [31:0] ALUResult, WriteData,
           input  logic [31:0] ReadData);

  logic [3:0] ALUFlags;
  logic       RegWrite, ALUSrc, MemtoReg, PCSrc;
  logic [1:0] RegSrc, ImmSrc, ALUControl;

  controller u_ctrl(clk, reset, Instr[31:12], ALUFlags,
                    RegSrc, RegWrite, ImmSrc,
                    ALUSrc, ALUControl,
                    MemWrite, MemtoReg, PCSrc);

  datapath u_dp(clk, reset, RegSrc, RegWrite, ImmSrc,
                ALUSrc, ALUControl,
                MemtoReg, PCSrc,
                ALUFlags, PC, Instr, ALUResult, WriteData, ReadData);
endmodule
