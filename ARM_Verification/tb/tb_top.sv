// ============================================================================
// tb_top.sv - Testbench top-level: noi driver, DUT, monitor, reference model,
//             scoreboard va coverage.
//
//   driver ----clk/reset----> DUT (top)
//   monitor  : doc tin hieu DUT (hierarchical, xem dut_paths.svh)
//   reference_model : mo hinh doc lap (PC, R0..R14, NZCV, imem, dmem)
//   scoreboard : goi monitor + model moi canh xuong clock va so sanh
//   coverage : dem coverage tu giao dich cua monitor
// ============================================================================
`timescale 1ns/1ps

module tb_top;

  wire        clk, reset;
  wire [31:0] WriteData, DataAdr;
  wire        MemWrite;

  driver          u_drv(.clk(clk), .reset(reset));

  top             dut(.clk(clk), .reset(reset),
                      .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));

  monitor         u_mon();
  reference_model u_ref();
  coverage        u_cov();
  scoreboard      u_sb(.clk(clk), .reset(reset));

endmodule
