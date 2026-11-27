// ============================================================================
// regfile.sv - Register file 3 cong (HDL Example 7.6)
//   - R0..R14 luu trong mang; doc R15 tra ve r15 (= PC + 8)
//   - Ghi dong bo theo canh len clock; doc to hop
//   - KHONG co reset (giong sach) -> testbench phai khoi tao thanh ghi
// Luu y: dung "always @(posedge clk)" (khong dung always_ff) de testbench co
// the nap gia tri khoi tao vao mang 'regs' bang hierarchical assignment.
// ============================================================================
`timescale 1ns/1ps

module regfile(input  logic        clk,
               input  logic        we3,
               input  logic [3:0]  ra1, ra2, wa3,
               input  logic [31:0] wd3, r15,
               output logic [31:0] rd1, rd2);

  logic [31:0] regs [0:14];

  always @(posedge clk)
    if (we3 && (wa3 != 4'd15)) regs[wa3] <= wd3;

  assign rd1 = (ra1 == 4'd15) ? r15 : regs[ra1];
  assign rd2 = (ra2 == 4'd15) ? r15 : regs[ra2];
endmodule
