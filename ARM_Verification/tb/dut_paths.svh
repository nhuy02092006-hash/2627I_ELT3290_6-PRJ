// ============================================================================
// dut_paths.svh - TAP TRUNG moi duong dan hierarchical vao DUT + hang so dung chung.
// Neu RTL cua giang vien dat ten khac sach, CHI can sua file nay.
// (File .svh la file include, khong bien dich rieng. Dung +incdir+tb khi vlog.)
// ============================================================================
`ifndef DUT_PATHS_SVH
`define DUT_PATHS_SVH

// ---- tin hieu quan sat tren DUT (instance goc: tb_top.dut) ----
`define DUT_PC         tb_top.dut.u_cpu.PC
`define DUT_INSTR      tb_top.dut.Instr
`define DUT_READDATA   tb_top.dut.ReadData
`define DUT_MEMWRITE   tb_top.dut.MemWrite
`define DUT_DATAADR    tb_top.dut.DataAdr
`define DUT_WRITEDATA  tb_top.dut.WriteData
`define DUT_REGWRITE   tb_top.dut.u_cpu.RegWrite
`define DUT_PCSRC      tb_top.dut.u_cpu.PCSrc
`define DUT_RESULT     tb_top.dut.u_cpu.u_dp.Result
`define DUT_SRCA       tb_top.dut.u_cpu.u_dp.SrcA
`define DUT_SRCB       tb_top.dut.u_cpu.u_dp.SrcB
`define DUT_FLAGS      tb_top.dut.u_cpu.u_ctrl.u_cl.Flags      // {N,Z,C,V}

// ---- trang thai kien truc / bo nho cua DUT (mang) ----
`define DUT_RF         tb_top.dut.u_cpu.u_dp.u_rf.regs         // R0..R14
`define DUT_IMEM       tb_top.dut.u_imem.RAM                   // 64 word
`define DUT_DMEM       tb_top.dut.u_dmem.RAM                   // 64 word

// ---- cac khoi cua testbench ----
`define DRV            tb_top.u_drv
`define MON            tb_top.u_mon
`define REF            tb_top.u_ref
`define SB             tb_top.u_sb
`define COV            tb_top.u_cov
`define REF_IMEM       tb_top.u_ref.imem
`define REF_DMEM       tb_top.u_ref.dmem
`define REF_RF         tb_top.u_ref.regs

// ---- hang so ----
// Lenh dung chuong trinh: B . (nhay ve chinh no, imm24 = 0xFFFFFE)
`define HALT_INSTR     32'hEAFFFFFE

// Phan loai lenh (monitor.classify)
`define K_ADD    0
`define K_SUB    1
`define K_AND    2
`define K_ORR    3
`define K_LDR    4
`define K_STR    5
`define K_BEQ    6
`define K_BOTHER 7
`define K_DPOTH  8
`define K_HALT   9
`define K_UNK   10

`endif
