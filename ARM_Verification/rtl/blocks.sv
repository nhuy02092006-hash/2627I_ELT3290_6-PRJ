// ============================================================================
// blocks.sv - Cac khoi xay dung co ban (Chuong 5 / HDL Example 7.7-7.11)
// ============================================================================
`timescale 1ns/1ps

module adder #(parameter WIDTH = 32)
              (input  logic [WIDTH-1:0] a, b,
               output logic [WIDTH-1:0] y);
  assign y = a + b;
endmodule

// Thanh ghi co reset (bat dong bo) - dung cho PC
module flopr #(parameter WIDTH = 32)
              (input  logic             clk, reset,
               input  logic [WIDTH-1:0] d,
               output logic [WIDTH-1:0] q);
  always_ff @(posedge clk, posedge reset)
    if (reset) q <= '0;
    else       q <= d;
endmodule

// Thanh ghi co reset va enable - dung cho thanh ghi co NZCV
module flopenr #(parameter WIDTH = 32)
                (input  logic             clk, reset, en,
                 input  logic [WIDTH-1:0] d,
                 output logic [WIDTH-1:0] q);
  always_ff @(posedge clk, posedge reset)
    if (reset)   q <= '0;
    else if (en) q <= d;
endmodule

module mux2 #(parameter WIDTH = 32)
             (input  logic [WIDTH-1:0] d0, d1,
              input  logic             s,
              output logic [WIDTH-1:0] y);
  assign y = s ? d1 : d0;
endmodule

// Mo rong immediate (Table 7.1)
//   ImmSrc=00: imm8  zero-extend (data-processing)
//   ImmSrc=01: imm12 zero-extend (LDR/STR)
//   ImmSrc=10: imm24 sign-extend, nhan 4 (B)
module extend(input  logic [23:0] Instr,
              input  logic [1:0]  ImmSrc,
              output logic [31:0] ExtImm);
  always_comb
    case (ImmSrc)
      2'b00:   ExtImm = {24'b0, Instr[7:0]};
      2'b01:   ExtImm = {20'b0, Instr[11:0]};
      2'b10:   ExtImm = {{6{Instr[23]}}, Instr[23:0], 2'b00};
      default: ExtImm = 32'bx;
    endcase
endmodule
