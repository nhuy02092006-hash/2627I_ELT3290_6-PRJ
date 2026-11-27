// ============================================================================
// coverage.sv - Coverage thu cong (dem bang bien), KHONG dung covergroup
//   (ModelSim Intel FPGA Starter thuong khong ho tro functional coverage).
//   Chi ghi nhan nhung gi DUT THUC SU thuc hien (lay tu monitor).
//   report() ghi results/coverage_summary.txt va in ra transcript.
// ============================================================================
`timescale 1ns/1ps
`include "dut_paths.svh"

module coverage;

  parameter REPORT_FILE = "results/coverage_summary.txt";

  // ---- instruction / branch ----
  integer c_add, c_sub, c_and, c_orr, c_ldr, c_str;
  integer c_beq_taken, c_beq_nottaken, c_b_other, c_cond_skipped, c_dp_s;
  // ---- operand (lenh data-processing) ----
  integer c_opa_zero, c_opb_zero, c_ops_equal, c_ops_differ;
  integer c_op_ones, c_op_alt, c_op_msb;
  // ---- memory ----
  integer c_ld_zero, c_ld_ones, c_ld_alt, c_ld_other;
  integer c_st_zero, c_st_ones, c_st_alt, c_st_other;
  integer c_overwrite, c_read_after_write;
  reg [63:0] ld_seen, st_seen, st_seen_test;
  // ---- co NZCV tung xuat hien ----
  integer c_flag_n, c_flag_z, c_flag_c, c_flag_v;
  // ---- reset / tich hop ----
  integer c_tests, c_resets, c_integ_tests, c_integ_full;
  reg [6:0] kinds_test;        // bit0 ADD, 1 SUB, 2 AND, 3 ORR, 4 LDR, 5 STR, 6 BEQ

  initial begin
    c_add = 0; c_sub = 0; c_and = 0; c_orr = 0; c_ldr = 0; c_str = 0;
    c_beq_taken = 0; c_beq_nottaken = 0; c_b_other = 0; c_cond_skipped = 0; c_dp_s = 0;
    c_opa_zero = 0; c_opb_zero = 0; c_ops_equal = 0; c_ops_differ = 0;
    c_op_ones = 0; c_op_alt = 0; c_op_msb = 0;
    c_ld_zero = 0; c_ld_ones = 0; c_ld_alt = 0; c_ld_other = 0;
    c_st_zero = 0; c_st_ones = 0; c_st_alt = 0; c_st_other = 0;
    c_overwrite = 0; c_read_after_write = 0;
    ld_seen = 64'd0; st_seen = 64'd0; st_seen_test = 64'd0;
    c_flag_n = 0; c_flag_z = 0; c_flag_c = 0; c_flag_v = 0;
    c_tests = 0; c_resets = 0; c_integ_tests = 0; c_integ_full = 0;
    kinds_test = 7'd0;
  end

  // ------------------------------------------------------------ helpers
  task dp_operands;
    reg [31:0] a, b;
    begin
      a = `MON.m_srca;  b = `MON.m_srcb;
      if (a === 32'h0)           c_opa_zero = c_opa_zero + 1;
      if (b === 32'h0)           c_opb_zero = c_opb_zero + 1;
      if (a === b)               c_ops_equal  = c_ops_equal + 1;
      else                       c_ops_differ = c_ops_differ + 1;
      if (a === 32'hFFFFFFFF || b === 32'hFFFFFFFF)                 c_op_ones = c_op_ones + 1;
      if (a === 32'hAAAAAAAA || a === 32'h55555555 ||
          b === 32'hAAAAAAAA || b === 32'h55555555)                 c_op_alt  = c_op_alt + 1;
      if (a[31] === 1'b1 || b[31] === 1'b1)                         c_op_msb  = c_op_msb + 1;
      if (`MON.m_instr[20]) c_dp_s = c_dp_s + 1;
    end
  endtask

  function integer popcount64(input [63:0] v);
    integer k;
    begin
      popcount64 = 0;
      for (k = 0; k < 64; k = k + 1) if (v[k]) popcount64 = popcount64 + 1;
    end
  endfunction

  // ------------------------------------------------------------- sample
  task sample;
    reg [5:0] idx;
    begin
      idx = `MON.m_dataadr[7:2];

      // co NZCV (trang thai hien tai cua DUT)
      if (`MON.m_flags[3] === 1'b1) c_flag_n = c_flag_n + 1;
      if (`MON.m_flags[2] === 1'b1) c_flag_z = c_flag_z + 1;
      if (`MON.m_flags[1] === 1'b1) c_flag_c = c_flag_c + 1;
      if (`MON.m_flags[0] === 1'b1) c_flag_v = c_flag_v + 1;

      case (`MON.m_kind)
        `K_ADD: if (`MON.m_regwrite === 1'b1) begin c_add = c_add + 1; kinds_test[0] = 1'b1; dp_operands; end
                else c_cond_skipped = c_cond_skipped + 1;
        `K_SUB: if (`MON.m_regwrite === 1'b1) begin c_sub = c_sub + 1; kinds_test[1] = 1'b1; dp_operands; end
                else c_cond_skipped = c_cond_skipped + 1;
        `K_AND: if (`MON.m_regwrite === 1'b1) begin c_and = c_and + 1; kinds_test[2] = 1'b1; dp_operands; end
                else c_cond_skipped = c_cond_skipped + 1;
        `K_ORR: if (`MON.m_regwrite === 1'b1) begin c_orr = c_orr + 1; kinds_test[3] = 1'b1; dp_operands; end
                else c_cond_skipped = c_cond_skipped + 1;

        `K_LDR: if (`MON.m_regwrite === 1'b1) begin
                  c_ldr = c_ldr + 1;  kinds_test[4] = 1'b1;
                  ld_seen[idx] = 1'b1;
                  if (st_seen_test[idx]) c_read_after_write = c_read_after_write + 1;
                  if      (`MON.m_rdata === 32'h00000000) c_ld_zero  = c_ld_zero + 1;
                  else if (`MON.m_rdata === 32'hFFFFFFFF) c_ld_ones  = c_ld_ones + 1;
                  else if (`MON.m_rdata === 32'hAAAAAAAA ||
                           `MON.m_rdata === 32'h55555555) c_ld_alt   = c_ld_alt + 1;
                  else                                    c_ld_other = c_ld_other + 1;
                end else c_cond_skipped = c_cond_skipped + 1;

        `K_STR: if (`MON.m_memwrite === 1'b1) begin
                  c_str = c_str + 1;  kinds_test[5] = 1'b1;
                  if (st_seen_test[idx]) c_overwrite = c_overwrite + 1;
                  st_seen[idx] = 1'b1;  st_seen_test[idx] = 1'b1;
                  if      (`MON.m_wdata === 32'h00000000) c_st_zero  = c_st_zero + 1;
                  else if (`MON.m_wdata === 32'hFFFFFFFF) c_st_ones  = c_st_ones + 1;
                  else if (`MON.m_wdata === 32'hAAAAAAAA ||
                           `MON.m_wdata === 32'h55555555) c_st_alt   = c_st_alt + 1;
                  else                                    c_st_other = c_st_other + 1;
                end else c_cond_skipped = c_cond_skipped + 1;

        `K_BEQ: begin
                  kinds_test[6] = 1'b1;
                  if (`MON.m_pcsrc === 1'b1) c_beq_taken    = c_beq_taken + 1;
                  else                       c_beq_nottaken = c_beq_nottaken + 1;
                end

        `K_BOTHER: c_b_other = c_b_other + 1;
        default: ;
      endcase
    end
  endtask

  // -------------------------------------------------- dieu khien theo test
  task begin_test;
    begin
      c_tests = c_tests + 1;
      kinds_test = 7'd0;
      st_seen_test = 64'd0;
    end
  endtask

  task end_test(input integer is_integ);
    begin
      if (is_integ != 0) begin
        c_integ_tests = c_integ_tests + 1;
        if (kinds_test == 7'h7F) c_integ_full = c_integ_full + 1;
      end
    end
  endtask

  task note_reset;
    begin c_resets = c_resets + 1; end
  endtask

  // --------------------------------------------------------------- report
  // Ghi dong thoi ra file va transcript (MCD: bit0 = stdout)
  task report;
    integer mcd, n_kinds, n_ld_addr, n_st_addr, n_ld_pat, n_st_pat;
    reg ok_instr, ok_branch, ok_mem, ok_operand, ok_integ;
    begin
      mcd = $fopen(REPORT_FILE);
      if (mcd == 0) $display("[COV][WARN] khong mo duoc %0s (thu muc results/ da ton tai chua?) - chi in ra transcript", REPORT_FILE);
      mcd = mcd | 32'h1;

      n_kinds = (c_add > 0) + (c_sub > 0) + (c_and > 0) + (c_orr > 0) +
                (c_ldr > 0) + (c_str > 0) + ((c_beq_taken + c_beq_nottaken) > 0);
      n_ld_addr = popcount64(ld_seen);
      n_st_addr = popcount64(st_seen);
      n_ld_pat  = (c_ld_zero > 0) + (c_ld_ones > 0) + (c_ld_alt > 0) + (c_ld_other > 0);
      n_st_pat  = (c_st_zero > 0) + (c_st_ones > 0) + (c_st_alt > 0) + (c_st_other > 0);

      ok_instr   = (n_kinds == 7);
      ok_branch  = (c_beq_taken > 0) && (c_beq_nottaken > 0);
      ok_mem     = (c_ldr > 0) && (c_str > 0) && (n_ld_addr >= 2) && (n_st_addr >= 2) &&
                   (n_ld_pat >= 2) && (n_st_pat >= 2);
      ok_operand = (c_opa_zero + c_opb_zero > 0) && (c_ops_equal > 0) && (c_ops_differ > 0) &&
                   (c_op_ones > 0) && (c_op_alt > 0);
      ok_integ   = (c_integ_full > 0);

      $fdisplay(mcd, "================ COVERAGE SUMMARY ================");
      $fdisplay(mcd, "(so lieu dem tu cac lenh DUT thuc su thuc thi trong mo phong)");
      $fdisplay(mcd, "Tests chay: %0d | Reset giua chung: %0d", c_tests, c_resets);
      $fdisplay(mcd, "");
      $fdisplay(mcd, "[1] Instruction coverage: %0d/7  -> %0s", n_kinds, ok_instr ? "MET" : "NOT MET");
      $fdisplay(mcd, "    ADD=%0d SUB=%0d AND=%0d ORR=%0d LDR=%0d STR=%0d BEQ=%0d (khac: B=%0d, DP co S=%0d, bi bo qua do cond=%0d)",
                c_add, c_sub, c_and, c_orr, c_ldr, c_str, c_beq_taken + c_beq_nottaken,
                c_b_other, c_dp_s, c_cond_skipped);
      $fdisplay(mcd, "[2] Branch coverage     : BEQ taken=%0d, not-taken=%0d -> %0s",
                c_beq_taken, c_beq_nottaken, ok_branch ? "MET" : "NOT MET");
      $fdisplay(mcd, "[3] Memory coverage     : LDR=%0d STR=%0d | dia chi doc khac nhau=%0d, dia chi ghi khac nhau=%0d -> %0s",
                c_ldr, c_str, n_ld_addr, n_st_addr, ok_mem ? "MET" : "NOT MET");
      $fdisplay(mcd, "    mau du lieu LDR: zero=%0d ones=%0d alt=%0d other=%0d | STR: zero=%0d ones=%0d alt=%0d other=%0d",
                c_ld_zero, c_ld_ones, c_ld_alt, c_ld_other, c_st_zero, c_st_ones, c_st_alt, c_st_other);
      $fdisplay(mcd, "    ghi de (STR len dia chi da ghi trong test)=%0d, doc lai sau khi ghi (LDR)=%0d",
                c_overwrite, c_read_after_write);
      $fdisplay(mcd, "[4] Operand coverage    : -> %0s", ok_operand ? "MET" : "NOT MET");
      $fdisplay(mcd, "    toan hang A=0: %0d, B=0: %0d, A==B: %0d, A!=B: %0d, 0xFFFFFFFF: %0d, 0xAAAAAAAA/0x55555555: %0d, MSB=1: %0d",
                c_opa_zero, c_opb_zero, c_ops_equal, c_ops_differ, c_op_ones, c_op_alt, c_op_msb);
      $fdisplay(mcd, "    co NZCV tung =1 (so chu ky): N=%0d Z=%0d C=%0d V=%0d", c_flag_n, c_flag_z, c_flag_c, c_flag_v);
      $fdisplay(mcd, "[5] Integration coverage: test tich hop=%0d, trong do du 7/7 loai lenh=%0d -> %0s",
                c_integ_tests, c_integ_full, ok_integ ? "MET" : "NOT MET");
      $fdisplay(mcd, "==================================================");
      if (mcd != 32'h1) $fclose(mcd & 32'hFFFFFFFE);
    end
  endtask

endmodule
