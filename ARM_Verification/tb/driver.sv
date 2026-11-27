// ============================================================================
// driver.sv - Phat kich thich cho DUT
//   * Tao clock (chu ky 10 ns) va reset.
//   * Nap chuong trinh (.dat, hex, moi dong 1 lenh) va du lieu ban dau vao bo nho.
//   * Chay lan luot cac test trong testlist.svh, ket thuc moi test khi DUT gap
//     lenh HALT (B .) hoac het MAX_CYCLES.
//
//   Quy trinh 1 test:
//     drv_begin      : reference model ve trang thai sach (imem = HALT, dmem = 0, R = 0)
//     $readmemh      : nap chuong trinh / du lieu vao BO NHO CUA MODEL (nguon su that)
//     run_test       : giu reset, SAO CHEP bo nho + R0..R14 tu model sang DUT (mirror),
//                      nha reset, cho den HALT, so sanh lan cuoi, in PASS/FAIL.
//   (Mirror duoc thuc hien khi reset con bat nen cac lenh DUT chay trong luc reset
//    khong lam ban trang thai khoi tao.)
//
//   Macro dung trong testlist.svh:
//     RUN_TEST(PROG, NAME, INTEG)               - chuong trinh PROG (file .dat)
//     RUN_TEST_D(PROG, DATA, NAME, INTEG)       - them du lieu ban dau cho dmem
//     RUN_TEST_RST(PROG, NAME, K)               - reset giua chung sau K chu ky
//     EXPECT_MEM(ADDR, VAL)                     - kiem tra "vang": dmem[ADDR] == VAL
//                                                 (dat TRUOC lenh RUN_*; ADDR tinh theo byte)
//     RUN_BOOK_PROGRAM(NAME)                    - chuong trinh mau Hinh 7.60 (khong can file)
//   INTEG = 1 neu la test tich hop (coverage se kiem tra du 7 loai lenh).
// ============================================================================
`timescale 1ns/1ps
`include "dut_paths.svh"

module driver(output reg clk, output reg reset);

  parameter integer MAX_CYCLES   = 1000;   // gioi han so chu ky moi test
  parameter integer RESET_CYCLES = 2;      // so chu ky giu reset truoc khi chay

  reg        halted, timed_out, did_rst, g_en;
  reg [31:0] g_addr, g_val;
  integer    cyc;

  // ------------------------------------------------------------ clock / reset
  initial begin
    clk   = 1'b0;
    reset = 1'b1;
    g_en  = 1'b0;
  end
  always #5 clk = ~clk;                    // chu ky 10 ns

  // ----------------------------------------------------------------- macros
  `define RUN_TEST(PROG, NAME, INTEG) \
    begin drv_begin; $readmemh(PROG, `REF_IMEM); run_test(NAME, INTEG, 0); end

  `define RUN_TEST_D(PROG, DATA, NAME, INTEG) \
    begin drv_begin; $readmemh(PROG, `REF_IMEM); $readmemh(DATA, `REF_DMEM); run_test(NAME, INTEG, 0); end

  `define RUN_TEST_RST(PROG, NAME, K) \
    begin drv_begin; $readmemh(PROG, `REF_IMEM); run_test(NAME, 0, K); end

  `define EXPECT_MEM(ADDR, VAL) \
    begin g_en = 1'b1; g_addr = ADDR; g_val = VAL; end

  `define RUN_BOOK_PROGRAM(NAME) \
    begin drv_begin; load_book_program; g_en = 1'b1; g_addr = 32'd100; g_val = 32'd7; run_test(NAME, 1, 0); end

  // ------------------------------------------------------------------ tasks
  task drv_begin;
    begin
      reset = 1'b1;
      `REF.init_state(`HALT_INSTR);
    end
  endtask

  // Sao chep imem, dmem, R0..R14 tu model sang DUT
  task mirror;
    integer k;
    begin
      for (k = 0; k < 64; k = k + 1) begin
        `DUT_IMEM[k] = `REF_IMEM[k];
        `DUT_DMEM[k] = `REF_DMEM[k];
      end
      for (k = 0; k < 15; k = k + 1) `DUT_RF[k] = `REF_RF[k];
    end
  endtask

  // Reset giua chung: sau khi lenh hien tai da hoan tat, giu reset, model ve PC=0
  // (thanh ghi va bo nho KHONG bi xoa - giong RTL trong sach)
  task midrun_reset;
    begin
      @(posedge clk); #1;                  // lenh dang chay da ghi vao DUT
      `SB.post_check(1'b1);                // so sanh day du truoc khi reset
      `SB.have_prev = 1'b0;
      `REF.reset_cpu;
      `COV.note_reset;
      $display("[DRV] --- reset giua chung tai chu ky %0d ---", cyc);
      reset = 1'b1;
      repeat (RESET_CYCLES) @(posedge clk);
      #1 reset = 1'b0;
    end
  endtask

  task run_test(input [8*48-1:0] name, input integer integ, input integer rst_k);
    integer forced;
    begin
      forced = 0;  did_rst = 1'b0;
      $display("");
      $display("[DRV] ================ TEST %0s ================", name);
      `SB.begin_test(name);
      `COV.begin_test;

      if (`REF_IMEM[0] === `HALT_INSTR) begin
        $display("[DRV][ERROR] chuong trinh rong - file .dat khong tim thay hoac rong?");
        forced = 2;
      end else begin
        reset = 1'b1;
        repeat (RESET_CYCLES) @(posedge clk);
        #1;
        mirror;                            // nap trang thai ban dau vao DUT
        reset = 1'b0;                      // nha reset ngay sau canh len

        cyc = 0;  halted = 1'b0;  timed_out = 1'b0;
        while (!halted && !timed_out) begin
          @(negedge clk); #1;              // sau khi scoreboard xu ly canh xuong
          cyc = cyc + 1;
          if (`DUT_INSTR === `HALT_INSTR)  halted = 1'b1;
          else if (cyc >= MAX_CYCLES)      timed_out = 1'b1;
          else if (rst_k > 0 && cyc == rst_k && !did_rst) begin
            did_rst = 1'b1;
            midrun_reset;
          end
        end

        if (timed_out) forced = 1;
        else repeat (2) begin @(negedge clk); #1; end   // de scoreboard kiem tra vong HALT
      end

      if (forced == 0 && g_en) `SB.golden(g_addr, g_val);
      `SB.end_test(forced);
      `COV.end_test(integ);
      g_en  = 1'b0;
      reset = 1'b1;
    end
  endtask

  // Chuong trinh mau trong sach (Hinh 7.60): ket qua dung -> mem[100] = 7
  task put(input integer a, input [31:0] w);
    begin `REF_IMEM[a] = w; end
  endtask

  task load_book_program;
    begin
      put( 0, 32'hE04F000F);  // SUB R0, R15, R15
      put( 1, 32'hE2802005);  // ADD R2, R0, #5
      put( 2, 32'hE280300C);  // ADD R3, R0, #12
      put( 3, 32'hE2437009);  // SUB R7, R3, #9
      put( 4, 32'hE1874002);  // ORR R4, R7, R2
      put( 5, 32'hE0035004);  // AND R5, R3, R4
      put( 6, 32'hE0855004);  // ADD R5, R5, R4
      put( 7, 32'hE0558007);  // SUBS R8, R5, R7
      put( 8, 32'h0A00000C);  // BEQ END   (khong nhay)
      put( 9, 32'hE0538004);  // SUBS R8, R3, R4
      put(10, 32'hAA000000);  // BGE AROUND (nhay)
      put(11, 32'hE2805000);  // ADD R5, R0, #0  (bi bo qua)
      put(12, 32'hE0578002);  // AROUND: SUBS R8, R7, R2
      put(13, 32'hB2857001);  // ADDLT R7, R5, #1
      put(14, 32'hE0477002);  // SUB R7, R7, R2
      put(15, 32'hE5837054);  // STR R7, [R3, #84]
      put(16, 32'hE5902060);  // LDR R2, [R0, #96]
      put(17, 32'hE08FF000);  // ADD R15, R15, R0 (PC = PC + 8)
      put(18, 32'hE280200E);  // ADD R2, R0, #14 (bi bo qua)
      put(19, 32'hEA000001);  // B END
      put(20, 32'hE280200D);  // ADD R2, R0, #13 (bi bo qua)
      put(21, 32'hE280200A);  // ADD R2, R0, #10 (bi bo qua)
      put(22, 32'hE5802064);  // END: STR R2, [R0, #100]
    end
  endtask

  // ------------------------------------------------------------- chay test
  initial begin
    #1;
    `include "testlist.svh"
    `COV.report;
    `SB.final_report;
    $display("[DRV] Ket thuc mo phong.");
    $stop;
  end

endmodule
