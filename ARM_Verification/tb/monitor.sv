// ============================================================================
// monitor.sv - Quan sat DUT (khong tac dong vao DUT)
//   sample() chup mot "giao dich" = tin hieu to hop cua lenh dang thuc thi
//   (goi vao canh XUONG clock, luc tin hieu da on dinh), phan loai lenh va
//   in mot dong log. Du lieu duoc luu o cac bien m_* cho scoreboard/coverage.
// ============================================================================
`timescale 1ns/1ps
`include "dut_paths.svh"

module monitor;

  parameter VERBOSE = 1;     // 1: in moi lenh ra transcript; 0: im lang

  // ---- giao dich quan sat duoc ----
  reg [31:0] m_pc, m_instr;
  reg        m_memwrite, m_regwrite, m_pcsrc;
  reg [31:0] m_dataadr, m_wdata, m_rdata, m_result, m_srca, m_srcb;
  reg [3:0]  m_rd, m_flags;
  integer    m_kind;
  integer    m_cyc;
  reg        m_halt_logged;
  reg [8*6-1:0] m_name;

  initial begin m_cyc = 0; m_halt_logged = 1'b0; end

  // Phan loai lenh (BEQ = nhanh co cond 0000)
  function integer classify(input [31:0] ins);
    begin
      if (ins === `HALT_INSTR) classify = `K_HALT;
      else if (^ins === 1'bx)  classify = `K_UNK;
      else case (ins[27:26])
        2'b00: case (ins[24:21])
                 4'b0100: classify = `K_ADD;
                 4'b0010: classify = `K_SUB;
                 4'b0000: classify = `K_AND;
                 4'b1100: classify = `K_ORR;
                 default: classify = `K_DPOTH;
               endcase
        2'b01: classify = ins[20] ? `K_LDR : `K_STR;
        2'b10: classify = (ins[31:28] == 4'b0000) ? `K_BEQ : `K_BOTHER;
        default: classify = `K_UNK;
      endcase
    end
  endfunction

  task begin_test;
    begin
      m_cyc = 0;
      m_halt_logged = 1'b0;
    end
  endtask

  task sample;
    begin
      m_cyc      = m_cyc + 1;
      m_pc       = `DUT_PC;
      m_instr    = `DUT_INSTR;
      m_memwrite = `DUT_MEMWRITE;
      m_regwrite = `DUT_REGWRITE;
      m_pcsrc    = `DUT_PCSRC;
      m_dataadr  = `DUT_DATAADR;
      m_wdata    = `DUT_WRITEDATA;
      m_rdata    = `DUT_READDATA;
      m_result   = `DUT_RESULT;
      m_srca     = `DUT_SRCA;
      m_srcb     = `DUT_SRCB;
      m_flags    = `DUT_FLAGS;
      m_rd       = m_instr[15:12];
      m_kind     = classify(m_instr);

      case (m_kind)
        `K_ADD:    m_name = m_instr[20] ? "ADDS" : "ADD";
        `K_SUB:    m_name = m_instr[20] ? "SUBS" : "SUB";
        `K_AND:    m_name = m_instr[20] ? "ANDS" : "AND";
        `K_ORR:    m_name = m_instr[20] ? "ORRS" : "ORR";
        `K_LDR:    m_name = "LDR";
        `K_STR:    m_name = "STR";
        `K_BEQ:    m_name = "BEQ";
        `K_BOTHER: m_name = "B";
        `K_DPOTH:  m_name = "DP?";
        `K_HALT:   m_name = "HALT";
        default:   m_name = "???";
      endcase

      // in log (lenh HALT chi in 1 lan cho moi test)
      if (VERBOSE && !(m_kind == `K_HALT && m_halt_logged)) begin
        $display("[MON] cyc=%0d PC=%08h INSTR=%08h %0s cond=%h | ALU=%08h RegWr=%b R%0d<=%08h | MemWr=%b A=%08h WD=%08h RD=%08h | PCSrc=%b NZCV=%b",
                 m_cyc, m_pc, m_instr, m_name, m_instr[31:28],
                 m_dataadr, m_regwrite, m_rd, m_result,
                 m_memwrite, m_dataadr, m_wdata, m_rdata,
                 m_pcsrc, m_flags);
      end
      if (m_kind == `K_HALT) m_halt_logged = 1'b1;
    end
  endtask

endmodule
