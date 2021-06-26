`timescale 1ns/1ps

interface chnl_intf(input clk, input rstn);
  logic [31:0] ch_data;
  logic        ch_valid;
  logic        ch_ready;
  logic [ 5:0] ch_margin;

  logic        a2s_ack;
  clocking drv_ck @(posedge clk);
    default input #1ns output #1ns;
    output ch_data, ch_valid;
    input ch_ready, ch_margin;
  endclocking
  clocking mon_ck @(posedge clk);
    default input #1ns output #1ns;
    input ch_data, ch_valid, ch_ready, ch_margin;
  endclocking

  // PROPERTY ASSERTION

  // when fifo is full, the ready signal should be low while valid data coming 
  property p_fifo_full_ready_low;
    @(posedge clk) (ch_margin === 0 && ch_valid === 1) |-> ch_ready === 0;
  endproperty
  assert property(p_fifo_full_ready_low) else $error("READY is not low while MARGIN is zero!");

  // fifo only writing data 
  property p_write_only;
    @(posedge clk) ch_valid === 1 && ch_ready === 1 |-> a2s_ack === 0;
  endproperty
  cover property(p_write_only);

  // fifo only reading data 
  property p_read_only;
    @(posedge clk) a2s_ack === 1 |-> ch_valid === 0;
  endproperty
  cover property(p_read_only);

  // fifo both writing and reading data
  property p_write_and_read;
    @(posedge clk) ch_valid === 1 && ch_ready === 1 |-> a2s_ack === 1;
  endproperty
  cover property(p_write_and_read);

endinterface

interface mcdt_intf(input clk, input rstn);
  logic [31:0]  mcdt_data;
  logic         mcdt_val;
  logic [ 1:0]  mcdt_id;
  logic [ 2:0]  arb_reqs;
  logic [ 2:0]  arb_acks;
  clocking mon_ck @(posedge clk);
    default input #1ns output #1ns;
    input mcdt_data, mcdt_val, mcdt_id;
  endclocking

  // once channel requests access, no more than 1 target is granted
  property p_arbitration_grant;
    @(posedge clk) $countones(arb_reqs) >0 |-> $countones(arb_acks) <= 1;
  endproperty
  assert property(p_arbitration_grant) else $error("arbiter grants more than 1 target!");

endinterface

module tb;
  logic         clk;
  logic         rstn;
  
  mcdt dut(
     .clk_i       (clk                )
    ,.rstn_i      (rstn               )
    ,.ch0_data_i  (chnl0_if.ch_data   )
    ,.ch0_valid_i (chnl0_if.ch_valid  )
    ,.ch0_ready_o (chnl0_if.ch_ready  )
    ,.ch0_margin_o(chnl0_if.ch_margin )
    ,.ch1_data_i  (chnl1_if.ch_data   )
    ,.ch1_valid_i (chnl1_if.ch_valid  )
    ,.ch1_ready_o (chnl1_if.ch_ready  )
    ,.ch1_margin_o(chnl1_if.ch_margin )
    ,.ch2_data_i  (chnl2_if.ch_data   )
    ,.ch2_valid_i (chnl2_if.ch_valid  )
    ,.ch2_ready_o (chnl2_if.ch_ready  )
    ,.ch2_margin_o(chnl2_if.ch_margin )
    ,.mcdt_data_o (mcdt_if.mcdt_data  )
    ,.mcdt_val_o  (mcdt_if.mcdt_val   )
    ,.mcdt_id_o   (mcdt_if.mcdt_id    )
  );
  
  // clock generation
  initial begin 
    clk <= 0;
    forever begin
      #5 clk <= !clk;
    end
  end
  
  // reset trigger
  initial begin 
    #10 rstn <= 0;
    repeat(10) @(posedge clk);
    rstn <= 1;
  end

  import mcdt_pkg::*;

  chnl_intf chnl0_if(.*);
  chnl_intf chnl1_if(.*);
  chnl_intf chnl2_if(.*);
  mcdt_intf mcdt_if(.*);

  // channel interface monitor MCDT internal channel signals
  assign chnl0_if.a2s_ack = tb.dut.inst_slva_fifo_0.a2sx_ack_i;
  assign chnl1_if.a2s_ack = tb.dut.inst_slva_fifo_1.a2sx_ack_i;
  assign chnl2_if.a2s_ack = tb.dut.inst_slva_fifo_2.a2sx_ack_i;
  // mcdt interface monitoring MCDT internal arbiter signals
  assign mcdt_if.arb_reqs[0] = tb.dut.inst_arbiter.slv0_req_i;
  assign mcdt_if.arb_reqs[1] = tb.dut.inst_arbiter.slv1_req_i;
  assign mcdt_if.arb_reqs[2] = tb.dut.inst_arbiter.slv2_req_i;
  assign mcdt_if.arb_acks[0] = tb.dut.inst_arbiter.a2s0_ack_o;
  assign mcdt_if.arb_acks[1] = tb.dut.inst_arbiter.a2s1_ack_o;
  assign mcdt_if.arb_acks[2] = tb.dut.inst_arbiter.a2s2_ack_o;

  mcdt_basic_test basic_test;
  mcdt_burst_test burst_test;
  mcdt_fifo_full_test fifo_full_test;
  string name;

  initial begin: test_selection
    basic_test = new();
    basic_test.set_interface(chnl0_if, chnl1_if, chnl2_if, mcdt_if);
    // burst_test = new();
    // burst_test.set_interface(chnl0_if, chnl1_if, chnl2_if, mcdt_if);
    // fifo_full_test = new();
    // fifo_full_test.set_interface(chnl0_if, chnl1_if, chnl2_if, mcdt_if);

    basic_test.run();
  end

  initial begin: assertion_control
    fork
      forever begin
        wait(rstn == 0);
        $assertoff();
        wait(rstn == 1);
        $asserton();
      end
    join_none
  end
endmodule

