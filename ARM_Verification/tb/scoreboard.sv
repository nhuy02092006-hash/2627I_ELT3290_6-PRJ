// ============================================================================
// scoreboard.sv - So sanh DUT voi Reference Model, tu dong bao PASS/FAIL
//
// Moi canh XUONG clock (khi khong reset), theo dung thu tu:
//   1. post_check : trang thai DUT (PC, NZCV, R0..R14, dmem) sau lenh TRUOC
//                   == trang thai reference model
//   2. MON.sample : monitor chup tin hieu DUT cua lenh HIEN TAI
//   3. REF.step   : reference model thuc thi lenh hien tai, tinh ky vong
//   4. pre_check  : PC, Instr, ALUResult, RegWrite/Rd/Result, MemWrite/dia chi/
//                   du lieu, MemRead, PCSrc cua DUT == ky vong
//   5. COV.sample : cap nhat coverage
// Cuoi moi test: end_test() so sanh toan bo trang thai lan cuoi va in PASS/FAIL.
// ============================================================================
`timescale 1ns/1ps
`include "dut_paths.svh"

module scoreboard(input clk, input reset);

  parameter MAX_PRINT = 20;         // so dong MISMATCH toi da in moi test

  integer n_tests, n_pass, n_fail;
  integer n_checks, err_total, err_test, instr_test, instr_total, checks_test;
  reg     active, have_prev;
  reg [8*48-1:0] cur_name;

  initial begin
    n_tests = 0; n_pass = 0; n_fail = 0;
    n_checks = 0; err_total = 0; err_test = 0;
    instr_test = 0; instr_total = 0; checks_test = 0;
    active = 1'b0; have_prev = 1'b0;
  end

  // ------------------------------------------------------------- bao loi
  task report_err(input [8*16-1:0] what, input [31:0] exp, input [31:0] got);
    begin
      err_test  = err_test + 1;
      err_total = err_total + 1;
      if (err_test <= MAX_PRINT)
        $display("[SB][MISMATCH] test=%0s cyc=%0d PC=%08h %0s : expected=%08h got=%08h",
                 cur_name, `MON.m_cyc, `MON.m_pc, what, exp, got);
    end
  endtask

  task chk32(input [8*16-1:0] what, input [31:0] exp, input [31:0] got);
    begin
      n_checks = n_checks + 1;  checks_test = checks_test + 1;
      if (exp !== got) report_err(what, exp, got);
    end
  endtask

  task chk1(input [8*16-1:0] what, input exp, input got);
    begin
      n_checks = n_checks + 1;  checks_test = checks_test + 1;
      if (exp !== got) report_err(what, {31'b0, exp}, {31'b0, got});
    end
  endtask

  // ------------------------------------------- so sanh trang thai sau lenh
  // chk_pc_flags = 0: bo qua PC va co (dung khi vua reset giua chung)
  task post_check(input chk_pc_flags);
    integer k;
    begin
      if (chk_pc_flags) begin
        chk32("POST_PC",    `REF.pc,              `DUT_PC);
        chk32("POST_NZCV",  {28'b0, `REF.flags},  {28'b0, `DUT_FLAGS});
      end
      for (k = 0; k < 15; k = k + 1) begin
        n_checks = n_checks + 1;  checks_test = checks_test + 1;
        if (`REF.regs[k] !== `DUT_RF[k]) begin
          err_test = err_test + 1;  err_total = err_total + 1;
          if (err_test <= MAX_PRINT)
            $display("[SB][MISMATCH] test=%0s cyc=%0d REGFILE R%0d : expected=%08h got=%08h",
                     cur_name, `MON.m_cyc, k, `REF.regs[k], `DUT_RF[k]);
        end
      end
      for (k = 0; k < 64; k = k + 1) begin
        n_checks = n_checks + 1;  checks_test = checks_test + 1;
        if (`REF.dmem[k] !== `DUT_DMEM[k]) begin
          err_test = err_test + 1;  err_total = err_total + 1;
          if (err_test <= MAX_PRINT)
            $display("[SB][MISMATCH] test=%0s cyc=%0d DMEM[addr 0x%02h] : expected=%08h got=%08h",
                     cur_name, `MON.m_cyc, k * 4, `REF.dmem[k], `DUT_DMEM[k]);
        end
      end
    end
  endtask

  // ------------------------------------- so sanh tin hieu DUT voi ky vong
  task pre_check;
    begin
      chk32("PC",          `REF.e_pc,    `MON.m_pc);
      chk32("INSTR",       `REF.e_instr, `MON.m_instr);

      if (`REF.e_unsup) begin
        err_test = err_test + 1;  err_total = err_total + 1;
        $display("[SB][ERROR] test=%0s PC=%08h INSTR=%08h: lenh nam NGOAI tap lenh duoc dac ta (kiem tra lai chuong trinh test)",
                 cur_name, `MON.m_pc, `MON.m_instr);
      end else begin
        chk32("ALU_RESULT", `REF.e_alu, `MON.m_dataadr);
        chk1 ("REG_WRITE",  `REF.e_reg_we, `MON.m_regwrite);
        if (`REF.e_reg_we) begin
          chk32("REG_RD",   {28'b0, `REF.e_rd}, {28'b0, `MON.m_rd});
          chk32("REG_DATA", `REF.e_reg_data,    `MON.m_result);
        end
        chk1 ("MEM_WRITE",  `REF.e_mem_we, `MON.m_memwrite);
        if (`REF.e_mem_we) begin
          chk32("MEM_ADDR",  `REF.e_mem_addr,  `MON.m_dataadr);
          chk32("MEM_WDATA", `REF.e_mem_wdata, `MON.m_wdata);
        end
        if (`REF.e_mem_re) begin
          chk32("MEM_RADDR", `REF.e_mem_addr,  `MON.m_dataadr);
          chk32("MEM_RDATA", `REF.e_mem_rdata, `MON.m_rdata);
        end
        chk1 ("PCSRC",      `REF.e_pcsrc,  `MON.m_pcsrc);
      end
    end
  endtask

  // ---------------------------------------------------------- chu ky chinh
  always @(negedge clk) begin
    if (active && !reset) begin
      if (have_prev) post_check(1'b1);
      `MON.sample;
      `REF.step;
      pre_check;
      `COV.sample;
      have_prev = 1'b1;
      if (`MON.m_instr !== `HALT_INSTR) begin
        instr_test  = instr_test  + 1;
        instr_total = instr_total + 1;
      end
    end
  end

  // ------------------------------------------------------ dieu khien test
  task begin_test(input [8*48-1:0] name);
    begin
      cur_name = name;
      err_test = 0;  instr_test = 0;  checks_test = 0;
      have_prev = 1'b0;
      active = 1'b1;
      `MON.begin_test;
    end
  endtask

  // Kiem tra "vang" doc lap voi model: dmem[byte_addr] phai bang val
  task golden(input [31:0] byte_addr, input [31:0] val);
    begin
      chk32("GOLDEN_DUT", val, `DUT_DMEM[byte_addr[7:2]]);
      chk32("GOLDEN_REF", val, `REF.dmem[byte_addr[7:2]]);
    end
  endtask

  // forced: 0 = binh thuong, 1 = timeout (khong gap lenh HALT), 2 = chua nap chuong trinh
  task end_test(input integer forced);
    begin
      if (forced == 0) begin
        post_check(1'b1);                       // so sanh toan bo trang thai lan cuoi
      end else begin
        err_test = err_test + 1;  err_total = err_total + 1;
        if (forced == 1)
          $display("[SB][ERROR] test=%0s: TIMEOUT - chuong trinh khong ket thuc (thieu lenh HALT hoac vong lap vo han)", cur_name);
        else
          $display("[SB][ERROR] test=%0s: chua nap duoc chuong trinh (kiem tra duong dan file .dat)", cur_name);
      end
      active = 1'b0;
      n_tests = n_tests + 1;
      if (err_test == 0) n_pass = n_pass + 1; else n_fail = n_fail + 1;
      $display("[SB] TEST %0s : %0s  (instr=%0d checks=%0d errors=%0d)",
               cur_name, (err_test == 0) ? "PASS" : "FAIL",
               instr_test, checks_test, err_test);
    end
  endtask

  task final_report;
    begin
      $display("");
      $display("==================== SCOREBOARD SUMMARY ====================");
      $display(" Tests run          : %0d", n_tests);
      $display(" Tests PASS         : %0d", n_pass);
      $display(" Tests FAIL         : %0d", n_fail);
      $display(" Instructions chk'd : %0d", instr_total);
      $display(" Total comparisons  : %0d", n_checks);
      $display(" Total mismatches   : %0d", err_total);
      if (n_tests > 0 && n_fail == 0)
        $display(" RESULT             : ALL TESTS PASSED");
      else
        $display(" RESULT             : FAILED");
      $display("============================================================");
    end
  endtask

endmodule
