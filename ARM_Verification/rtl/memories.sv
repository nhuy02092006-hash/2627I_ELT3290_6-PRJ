// ============================================================================
// memories.sv - Instruction memory & Data memory (HDL Example 7.14, 7.15)
//   64 word x 32 bit, dia chi word-aligned (a[31:2])
//   imem: doc to hop. dmem: doc to hop, ghi dong bo canh len clock.
//   Noi dung duoc testbench (driver) nap vao qua hierarchical reference.
// ============================================================================
`timescale 1ns/1ps

module imem(input  logic [31:0] a,
            output logic [31:0] rd);
  logic [31:0] RAM [0:63];
  assign rd = RAM[a[31:2]];
endmodule

module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);
  logic [31:0] RAM [0:63];
  assign rd = RAM[a[31:2]];
  always @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule
