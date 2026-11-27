// ============================================================================
// controller.sv - Control unit (Section 7.3.2, HDL Example 7.2 - 7.4)
//   controller = decoder (Main Decoder + ALU Decoder + PC Logic) + condlogic
// ============================================================================
`timescale 1ns/1ps

module controller(input  logic        clk, reset,
                  input  logic [31:12] Instr,
                  input  logic [3:0]  ALUFlags,
                  output logic [1:0]  RegSrc,
                  output logic        RegWrite,
                  output logic [1:0]  ImmSrc,
                  output logic        ALUSrc,
                  output logic [1:0]  ALUControl,
                  output logic        MemWrite, MemtoReg,
                  output logic        PCSrc);

  logic [1:0] FlagW;
  logic       PCS, RegW, MemW;

  decoder u_dec(Instr[27:26], Instr[25:20], Instr[15:12],
                FlagW, PCS, RegW, MemW,
                MemtoReg, ALUSrc, ImmSrc, RegSrc, ALUControl);

  condlogic u_cl(clk, reset, Instr[31:28], ALUFlags,
                 FlagW, PCS, RegW, MemW,
                 PCSrc, RegWrite, MemWrite);
endmodule

// ---------------------------------------------------------------------------
// Decoder: Main Decoder (Table 7.2) + ALU Decoder (Table 7.3) + PC Logic
// ---------------------------------------------------------------------------
module decoder(input  logic [1:0] Op,
               input  logic [5:0] Funct,
               input  logic [3:0] Rd,
               output logic [1:0] FlagW,
               output logic       PCS, RegW, MemW,
               output logic       MemtoReg, ALUSrc,
               output logic [1:0] ImmSrc, RegSrc, ALUControl);

  logic [9:0] controls;
  logic       Branch, ALUOp;

  // ---- Main Decoder ----
  always_comb
    case (Op)
      2'b00:   if (Funct[5]) controls = 10'b0000101001;  // DP immediate
               else          controls = 10'b0000001001;  // DP register
      2'b01:   if (Funct[0]) controls = 10'b0001111000;  // LDR
               else          controls = 10'b1001110100;  // STR
      2'b10:   controls = 10'b0110100010;                // B
      default: controls = 10'bx;
    endcase

  assign {RegSrc, ImmSrc, ALUSrc, MemtoReg, RegW, MemW, Branch, ALUOp} = controls;

  // ---- ALU Decoder ----
  always_comb
    if (ALUOp) begin
      case (Funct[4:1])
        4'b0100: ALUControl = 2'b00;  // ADD
        4'b0010: ALUControl = 2'b01;  // SUB
        4'b0000: ALUControl = 2'b10;  // AND
        4'b1100: ALUControl = 2'b11;  // ORR
        default: ALUControl = 2'bx;   // chua ho tro
      endcase
      FlagW[1] = Funct[0];                                   // cap nhat N,Z neu S=1
      FlagW[0] = Funct[0] & (ALUControl == 2'b00 | ALUControl == 2'b01); // C,V chi ADD/SUB
    end else begin
      ALUControl = 2'b00;  // LDR/STR/B dung phep cong
      FlagW      = 2'b00;
    end

  // ---- PC Logic ----
  assign PCS = ((Rd == 4'b1111) & RegW) | Branch;
endmodule

// ---------------------------------------------------------------------------
// Conditional Logic: giu thanh ghi co NZCV, chan ghi khi dieu kien sai
// ---------------------------------------------------------------------------
module condlogic(input  logic       clk, reset,
                 input  logic [3:0] Cond,
                 input  logic [3:0] ALUFlags,
                 input  logic [1:0] FlagW,
                 input  logic       PCS, RegW, MemW,
                 output logic       PCSrc, RegWrite, MemWrite);

  logic [1:0] FlagWrite;
  logic [3:0] Flags;      // {N, Z, C, V}
  logic       CondEx;

  flopenr #(2) flagreg1(clk, reset, FlagWrite[1], ALUFlags[3:2], Flags[3:2]);
  flopenr #(2) flagreg0(clk, reset, FlagWrite[0], ALUFlags[1:0], Flags[1:0]);

  condcheck cc(Cond, Flags, CondEx);

  assign FlagWrite = FlagW & {2{CondEx}};
  assign RegWrite  = RegW  & CondEx;
  assign MemWrite  = MemW  & CondEx;
  assign PCSrc     = PCS   & CondEx;
endmodule

// ---------------------------------------------------------------------------
// Condition check (Table 6.3)
// ---------------------------------------------------------------------------
module condcheck(input  logic [3:0] Cond,
                 input  logic [3:0] Flags,
                 output logic       CondEx);

  logic neg, zero, carry, overflow, ge;

  assign {neg, zero, carry, overflow} = Flags;
  assign ge = (neg == overflow);

  always_comb
    case (Cond)
      4'b0000: CondEx = zero;             // EQ
      4'b0001: CondEx = ~zero;            // NE
      4'b0010: CondEx = carry;            // CS
      4'b0011: CondEx = ~carry;           // CC
      4'b0100: CondEx = neg;              // MI
      4'b0101: CondEx = ~neg;             // PL
      4'b0110: CondEx = overflow;         // VS
      4'b0111: CondEx = ~overflow;        // VC
      4'b1000: CondEx = carry & ~zero;    // HI
      4'b1001: CondEx = ~(carry & ~zero); // LS
      4'b1010: CondEx = ge;               // GE
      4'b1011: CondEx = ~ge;              // LT
      4'b1100: CondEx = ~zero & ge;       // GT
      4'b1101: CondEx = ~(~zero & ge);    // LE
      4'b1110: CondEx = 1'b1;             // AL
      default: CondEx = 1'bx;
    endcase
endmodule
