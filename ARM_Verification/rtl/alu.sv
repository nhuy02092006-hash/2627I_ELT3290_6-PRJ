// alu.sv - ALU 32-bit (Section 5.2.4). Sach de lai phan HDL cho bai tap 5.11.
//   ALUControl: 00 = ADD, 01 = SUB, 10 = AND, 11 = ORR
//   ALUFlags  = {N, Z, C, V}
//   C, V chi co y nghia voi ADD/SUB (AND/ORR tra ve 0)
`timescale 1ns/1ps

module alu(input  logic [31:0] a, b,
           input  logic [1:0]  ALUControl,
           output logic [31:0] Result,
           output logic [3:0]  ALUFlags);

  logic        neg, zero, carry, overflow;
  logic [31:0] condinvb;
  logic [32:0] sum;

  assign condinvb = ALUControl[0] ? ~b : b;
  assign sum      = {1'b0, a} + {1'b0, condinvb} + ALUControl[0];

  always_comb
    case (ALUControl)
      2'b00, 2'b01: Result = sum[31:0];
      2'b10:        Result = a & b;
      2'b11:        Result = a | b;
      default:      Result = 32'bx;
    endcase

  assign neg      = Result[31];
  assign zero     = (Result == 32'b0);
  assign carry    = (ALUControl[1] == 1'b0) & sum[32];
  assign overflow = (ALUControl[1] == 1'b0) &
                    ~(a[31] ^ b[31] ^ ALUControl[0]) &
                    (a[31] ^ sum[31]);

  assign ALUFlags = {neg, zero, carry, overflow};
endmodule
