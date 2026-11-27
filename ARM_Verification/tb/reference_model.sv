// ============================================================================
// reference_model.sv - Mo hinh tham chieu (golden model) DOC LAP voi DUT
//   Khong doc bat ky tin hieu nao cua DUT. Tu giu: PC, R0..R14, co NZCV,
//   instruction memory, data memory. Moi lan goi step() thuc thi DUNG 1 lenh
//   theo dac ta ISA trong giao trinh (Chuong 6 + 7) va ghi lai "ky vong" e_*.
//
//   Tap lenh ho tro (dung nhu CPU trong sach):
//     - Data-processing: ADD, SUB, AND, ORR (reg hoac imm8, rot = 0, khong dich),
//       co bit S (ADD/SUB cap nhat NZCV, AND/ORR chi cap nhat NZ)
//     - LDR/STR [Rn, #+imm12]   (P=1, U=1, B=0, W=0, I=0)
//     - B (BEQ = B voi cond 0000), dich = PC + 8 + SignExt(imm24) << 2
//     - Thuc thi co dieu kien (cond) theo Table 6.3
//   Doc R15 = PC + 8. Ghi R15 -> PC moi = gia tri ghi.
// ============================================================================
`timescale 1ns/1ps

module reference_model;

  // ---- trang thai kien truc ----
  reg [31:0] imem [0:63];
  reg [31:0] dmem [0:63];
  reg [31:0] regs [0:14];
  reg [31:0] pc;
  reg [3:0]  flags;            // {N, Z, C, V}

  // ---- ky vong cua lenh vua thuc thi (do step() dien) ----
  reg [31:0] e_pc, e_instr, e_next_pc;
  reg [31:0] e_alu;            // ky vong ALUResult (= DataAdr)
  reg        e_alu_valid;
  reg        e_exec;           // dieu kien cond thoa
  reg        e_reg_we;
  reg [3:0]  e_rd;
  reg [31:0] e_reg_data;
  reg        e_mem_we, e_mem_re;
  reg [31:0] e_mem_addr, e_mem_wdata, e_mem_rdata;
  reg        e_branch, e_taken;
  reg        e_pcsrc;          // ky vong PCSrc
  reg        e_unsup;          // lenh ngoai tap lenh duoc dac ta

  integer ii;

  // ---------------------------------------------------------------- helpers
  function [31:0] rd_reg(input [3:0] r);
    begin
      if (r == 4'd15) rd_reg = pc + 32'd8;   // doc R15 = PC + 8
      else            rd_reg = regs[r];
    end
  endfunction

  // f = {N, Z, C, V}
  function cond_ok(input [3:0] cond, input [3:0] f);
    reg n, z, c, v, ge;
    begin
      n = f[3]; z = f[2]; c = f[1]; v = f[0];
      ge = (n == v);
      case (cond)
        4'b0000: cond_ok = z;              // EQ
        4'b0001: cond_ok = ~z;             // NE
        4'b0010: cond_ok = c;              // CS/HS
        4'b0011: cond_ok = ~c;             // CC/LO
        4'b0100: cond_ok = n;              // MI
        4'b0101: cond_ok = ~n;             // PL
        4'b0110: cond_ok = v;              // VS
        4'b0111: cond_ok = ~v;             // VC
        4'b1000: cond_ok = c & ~z;         // HI
        4'b1001: cond_ok = ~(c & ~z);      // LS
        4'b1010: cond_ok = ge;             // GE
        4'b1011: cond_ok = ~ge;            // LT
        4'b1100: cond_ok = ~z & ge;        // GT
        4'b1101: cond_ok = ~(~z & ge);     // LE
        4'b1110: cond_ok = 1'b1;           // AL
        default: cond_ok = 1'bx;
      endcase
    end
  endfunction

  // ------------------------------------------------------------------ reset
  // Dua CPU ve trang thai reset: PC = 0, co = 0. Thanh ghi/bo nho KHONG doi.
  task reset_cpu;
    begin
      pc = 32'd0;
      flags = 4'b0000;
    end
  endtask

  // Khoi tao toan bo: imem = halt_word, dmem = 0, R0..R14 = 0, PC = 0, co = 0
  task init_state(input [31:0] halt_word);
    begin
      for (ii = 0; ii < 64; ii = ii + 1) begin
        imem[ii] = halt_word;
        dmem[ii] = 32'd0;
      end
      for (ii = 0; ii < 15; ii = ii + 1) regs[ii] = 32'd0;
      reset_cpu;
    end
  endtask

  // ------------------------------------------------------------------- step
  task step;
    reg [31:0] instr, a, b, res, off, addr, nxt;
    reg [3:0]  cond, rn, rdn, cmd;
    reg [1:0]  op;
    reg        s_bit, i_bit, l_bit, ex, co, ov, arith;
    reg [32:0] sum;
    reg [29:0] idx;
    begin
      // ---- fetch ----
      if (pc[31:8] == 24'd0) instr = imem[pc[7:2]];
      else                   instr = 32'bx;

      e_pc = pc;  e_instr = instr;
      e_alu = 32'bx;  e_alu_valid = 1'b0;
      e_reg_we = 1'b0;  e_rd = 4'd0;  e_reg_data = 32'bx;
      e_mem_we = 1'b0;  e_mem_re = 1'b0;
      e_mem_addr = 32'bx;  e_mem_wdata = 32'bx;  e_mem_rdata = 32'bx;
      e_branch = 1'b0;  e_taken = 1'b0;  e_pcsrc = 1'b0;  e_unsup = 1'b0;

      cond = instr[31:28];
      op   = instr[27:26];
      ex   = cond_ok(cond, flags);
      e_exec = ex;
      nxt  = pc + 32'd4;
      if (ex === 1'bx) e_unsup = 1'b1;

      case (op)
        // ============================ Data-processing ============================
        2'b00: begin
          i_bit = instr[25];  cmd = instr[24:21];  s_bit = instr[20];
          rn = instr[19:16];  rdn = instr[15:12];
          a = rd_reg(rn);
          if (i_bit) b = {24'b0, instr[7:0]};
          else       b = rd_reg(instr[3:0]);
          // ngoai pham vi: immediate co rot, thanh ghi co dich
          if (i_bit  && (instr[11:8] != 4'd0)) e_unsup = 1'b1;
          if (!i_bit && (instr[11:4] != 8'd0)) e_unsup = 1'b1;

          arith = 1'b0;  co = 1'b0;  ov = 1'b0;
          case (cmd)
            4'b0100: begin   // ADD
              sum = {1'b0, a} + {1'b0, b};
              res = sum[31:0];  co = sum[32];
              ov  = (a[31] == b[31]) && (res[31] != a[31]);
              arith = 1'b1;
            end
            4'b0010: begin   // SUB  (a - b = a + ~b + 1)
              sum = {1'b0, a} + {1'b0, ~b} + 33'd1;
              res = sum[31:0];  co = sum[32];
              ov  = (a[31] != b[31]) && (res[31] != a[31]);
              arith = 1'b1;
            end
            4'b0000: res = a & b;    // AND
            4'b1100: res = a | b;    // ORR
            default: begin res = 32'bx; e_unsup = 1'b1; end
          endcase

          if (!e_unsup) begin
            e_alu = res;  e_alu_valid = 1'b1;
            if (ex) begin
              e_reg_we = 1'b1;  e_rd = rdn;  e_reg_data = res;
              if (s_bit) begin
                flags[3] = res[31];
                flags[2] = (res == 32'd0);
                if (arith) begin flags[1] = co; flags[0] = ov; end
              end
              if (rdn == 4'd15) begin nxt = res; e_pcsrc = 1'b1; end
              else              regs[rdn] = res;
            end
          end
        end

        // ============================== LDR / STR ================================
        2'b01: begin
          l_bit = instr[20];  rn = instr[19:16];  rdn = instr[15:12];
          // chi ho tro [Rn, #+imm12]: I=0 P=1 U=1 B=0 W=0
          if (instr[25] || !instr[24] || !instr[23] || instr[22] || instr[21])
            e_unsup = 1'b1;
          addr = rd_reg(rn) + {20'b0, instr[11:0]};
          idx  = addr[31:2];
          e_alu = addr;  e_alu_valid = 1'b1;
          e_mem_addr = addr;

          if (l_bit) begin                                   // LDR
            e_mem_re = 1'b1;
            if (idx < 30'd64) e_mem_rdata = dmem[idx[5:0]];
            else              e_mem_rdata = 32'bx;
            if (ex) begin
              e_reg_we = 1'b1;  e_rd = rdn;  e_reg_data = e_mem_rdata;
              if (rdn == 4'd15) begin nxt = e_mem_rdata; e_pcsrc = 1'b1; end
              else              regs[rdn] = e_mem_rdata;
            end
          end else begin                                     // STR
            e_mem_wdata = rd_reg(rdn);
            if (ex) begin
              e_mem_we = 1'b1;
              if (idx < 30'd64) dmem[idx[5:0]] = e_mem_wdata;
            end
          end
        end

        // ================================= B =====================================
        2'b10: begin
          off = {{6{instr[23]}}, instr[23:0], 2'b00};
          e_branch = 1'b1;
          e_alu = pc + 32'd8 + off;  e_alu_valid = 1'b1;
          if (instr[24]) e_unsup = 1'b1;                     // BL khong ho tro
          if (ex) begin
            e_taken = 1'b1;  e_pcsrc = 1'b1;
            nxt = e_alu;
          end
        end

        default: e_unsup = 1'b1;
      endcase

      e_next_pc = nxt;
      pc = nxt;
    end
  endtask

endmodule
