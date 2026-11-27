// ============================================================================
// top.sv - Top-level cho kiem thu (HDL Example 7.13): CPU + imem + dmem
// ============================================================================
`timescale 1ns/1ps

module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);

  logic [31:0] PC, Instr, ReadData;

  arm  u_cpu (clk, reset, PC, Instr, MemWrite, DataAdr, WriteData, ReadData);
  imem u_imem(PC, Instr);
  dmem u_dmem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule
