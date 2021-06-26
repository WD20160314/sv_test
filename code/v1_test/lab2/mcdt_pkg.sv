package mcdt_pkg;

  // static variables shared by resources
  semaphore run_stop_flags = new();

  class chnl_trans;
    rand bit[31:0] data[];
    rand int ch_id;
    rand int pkt_id;
    rand int data_nidles;
    rand int pkt_nidles;
    bit rsp;
    local static int obj_id = 0;
    constraint cstr{
      soft data.size inside {[4:8]};
      foreach(data[i]) data[i] == 'hC000_0000 + (this.ch_id<<24) + (this.pkt_id<<8) + i;
      soft ch_id == 0;
      soft pkt_id == 0;
      data_nidles inside {[0:2]};
      pkt_nidles inside {[1:10]};
    };

    function new();
      this.obj_id++;
    endfunction

    function chnl_trans clone();
      chnl_trans c = new();
      c.data = this.data;
      c.ch_id = this.ch_id;
      c.pkt_id = this.pkt_id;
      c.data_nidles = this.data_nidles;
      c.pkt_nidles = this.pkt_nidles;
      c.rsp = this.rsp;
      return c;
    endfunction
  endclass: chnl_trans
  
  class chnl_initiator;
    local string name;
    local virtual chnl_intf intf;
    mailbox #(chnl_trans) req_mb;
    mailbox #(chnl_trans) rsp_mb;
  
    function new(string name = "chnl_initiator");
      this.name = name;
    endfunction
  
    function void set_interface(virtual chnl_intf intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction

    task run();
      this.drive();
    endtask

    task drive();
      chnl_trans req, rsp;
      @(posedge intf.rstn);
      forever begin
        this.req_mb.get(req);
        this.chnl_write(req);
        rsp = req.clone();
        rsp.rsp = 1;
        this.rsp_mb.put(rsp);
      end
    endtask
  
    task chnl_write(input chnl_trans t);
      foreach(t.data[i]) begin
        @(posedge intf.clk);
        intf.ch_valid <= 1;
        intf.ch_data <= t.data[i];
        @(negedge intf.clk);
        wait(intf.ch_ready === 'b1);
        $display("%0t channel initiator [%s] sent data %x", $time, name, t.data[i]);
        repeat(t.data_nidles) chnl_idle();
      end
      repeat(t.pkt_nidles) chnl_idle();
    endtask
    
    task chnl_idle();
      @(posedge intf.clk);
      intf.ch_valid <= 0;
      intf.ch_data <= 0;
    endtask
  endclass: chnl_initiator
  
  class chnl_generator;
    rand int pkt_id = -1;
    rand int ch_id = -1;
    rand int data_nidles = -1;
    rand int pkt_nidles = -1;
    rand int data_size = -1;
    rand int ntrans = 10;

    mailbox #(chnl_trans) req_mb;
    mailbox #(chnl_trans) rsp_mb;

    constraint cstr{
      soft ch_id == -1;
      soft pkt_id == -1;
      soft data_size == -1;
      soft data_nidles == -1;
      soft pkt_nidles == -1;
      soft ntrans == 10;
    }

    function new();
      this.req_mb = new();
      this.rsp_mb = new();
    endfunction

    task run();
      repeat(ntrans) send_trans();
      run_stop_flags.put();
    endtask

    // generate transaction and put into local mailbox
    task send_trans();
      chnl_trans req, rsp;
      req = new();
      assert(req.randomize with {local::ch_id >= 0 -> ch_id == local::ch_id; 
                                 local::pkt_id >= 0 -> pkt_id == local::pkt_id;
                                 local::data_nidles >= 0 -> data_nidles == local::data_nidles;
                                 local::pkt_nidles >= 0 -> pkt_nidles == local::pkt_nidles;
                                 local::data_size >0 -> data.size() == local::data_size; 
                               })
        else $fatal("[RNDFAIL] channel packet randomization failure!");
      this.pkt_id++;
      this.req_mb.put(req);
      this.rsp_mb.get(rsp);
      assert(rsp.rsp)
        else $error("[RSPERR] %0t error response received!", $time);
    endtask
  endclass: chnl_generator

  typedef struct packed {
    bit[31:0] data;
    bit[1:0] id;
  } mon_data_t;

  class chnl_monitor;
    local string name;
    local virtual chnl_intf intf;
    mailbox #(mon_data_t) mon_mb;
    function new(string name="chnl_monitor");
      this.name = name;
    endfunction
    function void set_interface(virtual chnl_intf intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction
    task run();
      this.mon_trans();
    endtask

    task mon_trans();
      mon_data_t m;
      forever begin
        @(posedge intf.clk iff (intf.ch_valid==='b1 && intf.ch_ready==='b1));
        m.data = intf.ch_data;
        mon_mb.put(m);
        $display("%0t %s monitored channle data %8x", $time, this.name, m.data);
      end
    endtask
  endclass
  
  class mcdt_monitor;
    local string name;
    local virtual mcdt_intf intf;
    mailbox #(mon_data_t) mon_mb;
    function new(string name="mcdt_monitor");
      this.name = name;
    endfunction
    task run();
      this.mon_trans();
    endtask

    function void set_interface(virtual mcdt_intf intf);
      if(intf == null)
        $error("interface handle is NULL, please check if target interface has been intantiated");
      else
        this.intf = intf;
    endfunction

    task mon_trans();
      mon_data_t m;
      forever begin
        @(posedge intf.clk iff intf.mcdt_val==='b1);
        m.data = intf.mcdt_data;
        m.id = intf.mcdt_id;
        mon_mb.put(m);
        $display("%0t %s monitored mcdt data %8x and id %0d", $time, this.name, m.data, m.id);
      end
    endtask
  endclass

  class chnl_agent;
    local string name;
    chnl_initiator init;
    chnl_monitor mon;
    virtual chnl_intf vif;
    function new(string name = "chnl_agent");
      this.name = name;
      this.init = new({name, ".init"});
      this.mon = new({name, ".mon"});
    endfunction

    function void set_interface(virtual chnl_intf vif);
      this.vif = vif;
      init.set_interface(vif);
      mon.set_interface(vif);
    endfunction
    task run();
      fork
        init.run();
        mon.run();
      join
    endtask
  endclass: chnl_agent

  class mcdt_checker;
    local string name;
    local int error_count;
    local int cmp_count;
    mailbox #(mon_data_t) in_mbs[3];
    mailbox #(mon_data_t) out_mb;

    function new(string name="mcdt_checker");
      this.name = name;
      foreach(this.in_mbs[i]) this.in_mbs[i] = new();
      this.out_mb = new();
      this.error_count = 0;
      this.cmp_count = 0;
    endfunction

    task run();
      this.do_compare();
    endtask

    task do_compare();
      mon_data_t im, om;
      forever begin
        out_mb.get(om);
        case(om.id)
          0: in_mbs[0].get(im);
          1: in_mbs[1].get(im);
          2: in_mbs[2].get(im);
          default: $fatal("id %0d is not available", om.id);
        endcase
        if(om.data != im.data) begin
          this.error_count++;
          $error("[CMPFAIL] Compared failed! mcdt out data %8x ch_id %0d is not equal with channel in data %8x", om.data, om.id, im.data);
        end
        else begin
          $display("[CMPSUCD] Compared succeeded! mcdt out data %8x ch_id %0d is equal with channel in data %8x", om.data, om.id, im.data);
        end
        this.cmp_count++;
      end
    endtask
  endclass

  class mcdt_coverage;
    local virtual chnl_intf chnl_vifs[3]; 
    local virtual mcdt_intf mcdt_vif;

    covergroup cg_fifo_state(int length = 32);
      fifo0: coverpoint chnl_vifs[0].ch_margin {
        option.weight = 0;
        bins empty = {length};
        bins full  = {0};
        bins others = {[1:length-1]};
      }
      fifo1: coverpoint chnl_vifs[1].ch_margin { 
        option.weight = 0;
        bins empty = {length};
        bins full  = {0};
        bins others = {[1:length-1]};
      }
      fifo2: coverpoint chnl_vifs[2].ch_margin {
        option.weight = 0;
        bins empty = {length};
        bins full  = {0};
        bins others = {[1:length-1]};
      }
      fifos: cross fifo0, fifo1, fifo2 {
        bins fifo0_empty = binsof(fifo0.empty );
        bins fifo0_full  = binsof(fifo0.full  );
        bins fifo0_others= binsof(fifo0.others);
        bins fifo1_empty = binsof(fifo1.empty );
        bins fifo1_full  = binsof(fifo1.full  );
        bins fifo1_others= binsof(fifo1.others);
        bins fifo2_empty = binsof(fifo2.empty );
        bins fifo2_full  = binsof(fifo2.full  );
        bins fifo2_others= binsof(fifo2.others);
        bins f0full_f1full = binsof(fifo0.full) && binsof(fifo1.full);
        bins f0full_f2full = binsof(fifo0.full) && binsof(fifo2.full);
        bins f1full_f2full = binsof(fifo1.full) && binsof(fifo2.full);
        bins all_fifo_full = binsof(fifo0.full) && binsof(fifo1.full) && binsof(fifo2.full);
      }
    endgroup: cg_fifo_state

    covergroup cg_channel_data;
      chnl0: coverpoint chnl_vifs[0].ch_valid {
        bins valid   = {1};
        bins burst[] = (1 [* 2]), (1 [* 4]), (1 [* 8]);
        bins single  = (0 => 1 => 0);
      }
      chnl1: coverpoint chnl_vifs[1].ch_valid {
        bins valid   = {1};
        bins burst[] = (1 [* 2]), (1 [* 4]), (1 [* 8]);
        bins single  = (0 => 1 => 0);
      }
      chnl2: coverpoint chnl_vifs[2].ch_valid {
        bins valid   = {1};
        bins burst[] = (1 [* 2]), (1 [* 4]), (1 [* 8]);
        bins single  = (0 => 1 => 0);
      }
      chnls: cross chnl0, chnl1, chnl2 {
        bins chnl0_valid   = binsof(chnl0.valid );
        bins chnl0_burst   = binsof(chnl0.burst );
        bins chnl0_single  = binsof(chnl0.single);
        bins chnl1_valid   = binsof(chnl1.valid );
        bins chnl1_burst   = binsof(chnl1.burst );
        bins chnl1_single  = binsof(chnl1.single);
        bins chnl2_valid   = binsof(chnl2.valid );
        bins chnl2_burst   = binsof(chnl2.burst );
        bins chnl2_single  = binsof(chnl2.single);
        bins c0vld_c1vld   = binsof(chnl0.valid) &&  binsof(chnl1.valid);
        bins c0vld_c2vld   = binsof(chnl0.valid) &&  binsof(chnl2.valid);
        bins c1vld_c2vld   = binsof(chnl1.valid) &&  binsof(chnl2.valid);
        bins all_chnl_vld  = binsof(chnl0.valid) &&  binsof(chnl1.valid) &&  binsof(chnl2.valid);
      }
    endgroup: cg_channel_data

    covergroup cg_arbitration;
      req: coverpoint mcdt_vif.arb_reqs iff(mcdt_vif.arb_reqs !== 0) {
        bins req1[] = {'b001, 'b010, 'b100};
        bins req2[] = {'b011, 'b101, 'b110};
        bins req3 = {'b111};
      }
    endgroup: cg_arbitration

    covergroup cg_arbiter_data;
      valid: coverpoint  mcdt_vif.mcdt_val{
        bins burst   = (1 => 1);
        bins single  = (0 => 1);
      }
      id: coverpoint  mcdt_vif.mcdt_id{
        bins same[] = (0 => 0), (1 => 1), (2 => 2);
        bins diff[] = (0 => 1,2), (1 => 0,2), (2 => 0,1);
      }
      validXid: cross valid, id {
        bins valid_burst    = binsof(valid.burst);
        bins valid_single   = binsof(valid.single);
        bins id_same        = binsof(id.same);
        bins id_diff        = binsof(id.diff);
        bins same_id_burst  = binsof(id.same) && binsof(valid.burst);
        bins same_id_single = binsof(id.same) && binsof(valid.single);
        bins diff_id_burst  = binsof(id.diff) && binsof(valid.burst);
        bins diff_id_single = binsof(id.diff) && binsof(valid.single);
      }
    endgroup: cg_arbiter_data

    function new();
      cg_fifo_state = new();
      cg_channel_data = new();
      cg_arbitration = new();
      cg_arbiter_data = new();
    endfunction


    task run();
      fork 
        this.do_sample();
      join_none
    endtask

    task do_sample();
      forever begin
        @(posedge mcdt_vif.clk iff mcdt_vif.rstn);
        cg_fifo_state.sample();
        cg_channel_data.sample();
        cg_arbitration.sample();
        cg_arbiter_data.sample();
      end
    endtask

    virtual function void set_interface(virtual chnl_intf ch_vifs[3] 
                                        ,virtual mcdt_intf mcdt_vif
                                       );
      this.chnl_vifs = ch_vifs;
      this.mcdt_vif = mcdt_vif;
      if(chnl_vifs[0] == null || chnl_vifs[1] == null || chnl_vifs[2] == null)
        $error("chnl interface handle is NULL, please check if target interface has been intantiated");
      if(mcdt_vif == null)
        $error("mcdt interface handle is NULL, please check if target interface has been intantiated");
    endfunction

  endclass

  class mcdt_root_test;
    chnl_generator gen[3];
    chnl_agent agents[3];
    mcdt_monitor mcdt_mon;
    mcdt_checker chker;
    mcdt_coverage cvrg;
    protected string name;
    event gen_stop_e;

    function new(string name = "mcdt_root_test");
      this.name = name;
      this.chker = new();
      foreach(agents[i]) begin
        this.agents[i] = new($sformatf("agents[%0d]",i));
        this.gen[i] = new();
        this.agents[i].init.req_mb = this.gen[i].req_mb;
        this.agents[i].init.rsp_mb = this.gen[i].rsp_mb;
        this.agents[i].mon.mon_mb = this.chker.in_mbs[i];
      end
      this.mcdt_mon = new();
      this.mcdt_mon.mon_mb = this.chker.out_mb;
      this.cvrg = new();
      $display("%s instantiated and connected objects", this.name);
    endfunction

    virtual task gen_stop_callback();
      // empty
    endtask

    virtual task run_stop_callback();
      $display("run_stop_callback enterred");
      // by default, run would be finished once generators raised 'finish'
      // flags 
      $display("%s: wait for all generators have generated and tranferred transcations", this.name);
      run_stop_flags.get(3);
      $display($sformatf("*****************%s finished********************", this.name));
      $finish();
    endtask

    virtual task run();
      $display($sformatf("*****************%s started********************", this.name));
      this.do_config();
      fork
        agents[0].run();
        agents[1].run();
        agents[2].run();
        mcdt_mon.run();
        chker.run();
        cvrg.run();
      join_none

      // run first the callback thread to conditionally disable gen_threads
      fork
        this.gen_stop_callback();
        @(this.gen_stop_e) disable gen_threads;
      join_none

      fork : gen_threads
        gen[0].run();
        gen[1].run();
        gen[2].run();
      join

      run_stop_callback(); // wait until run stop control task finished
    endtask

    virtual function void set_interface(virtual chnl_intf ch0_vif 
                                        ,virtual chnl_intf ch1_vif 
                                        ,virtual chnl_intf ch2_vif 
                                        ,virtual mcdt_intf mcdt_vif
                                      );
      agents[0].set_interface(ch0_vif);
      agents[1].set_interface(ch1_vif);
      agents[2].set_interface(ch2_vif);
      mcdt_mon.set_interface(mcdt_vif);
      cvrg.set_interface('{ch0_vif, ch1_vif, ch2_vif}, mcdt_vif);
    endfunction

    virtual function void do_config();
    endfunction

  endclass

  class mcdt_basic_test extends mcdt_root_test;
    function new(string name = "mcdt_basic_test");
      super.new(name);
    endfunction
    virtual function void do_config();
      super.do_config();
      assert(gen[0].randomize() with {ntrans==100; data_nidles==0; pkt_nidles==1; data_size==8;})
        else $fatal("[RNDFAIL] gen[0] randomization failure!");
      assert(gen[1].randomize() with {ntrans==50; data_nidles inside {[1:2]}; pkt_nidles inside {[3:5]}; data_size==6;})
        else $fatal("[RNDFAIL] gen[1] randomization failure!");
      assert(gen[2].randomize() with {ntrans==80; data_nidles inside {[0:1]}; pkt_nidles inside {[1:2]}; data_size==32;})
        else $fatal("[RNDFAIL] gen[2] randomization failure!");
    endfunction
  endclass: mcdt_basic_test

  class mcdt_burst_test extends mcdt_root_test;
    function new(string name = "mcdt_burst_test");
      super.new(name);
    endfunction
    virtual function void do_config();
      super.do_config();
      assert(gen[0].randomize() with {ntrans inside {[80:100]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else $fatal("[RNDFAIL] gen[0] randomization failure!");
      assert(gen[1].randomize() with {ntrans inside {[80:100]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else $fatal("[RNDFAIL] gen[1] randomization failure!");
      assert(gen[2].randomize() with {ntrans inside {[80:100]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else $fatal("[RNDFAIL] gen[2] randomization failure!");
    endfunction
  endclass: mcdt_burst_test

  class mcdt_fifo_full_test extends mcdt_root_test;
    function new(string name = "mcdt_fifo_full_test");
      super.new(name);
    endfunction
    virtual function void do_config();
      super.do_config();
      assert(gen[0].randomize() with {ntrans inside {[1000:2000]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else $fatal("[RNDFAIL] gen[0] randomization failure!");
      assert(gen[1].randomize() with {ntrans inside {[1000:2000]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else $fatal("[RNDFAIL] gen[1] randomization failure!");
      assert(gen[2].randomize() with {ntrans inside {[1000:2000]}; data_nidles==0; pkt_nidles==1; data_size inside {8, 16, 32};})
        else $fatal("[RNDFAIL] gen[2] randomization failure!");
    endfunction

    // get all of 3 channles slave ready signals as a 3-bits vector
    local function bit[2:0] get_chnl_ready_flags();
      return {agents[2].vif.ch_ready
             ,agents[1].vif.ch_ready
             ,agents[0].vif.ch_ready
             };
    endfunction

    virtual task gen_stop_callback();
      bit[2:0] chnl_ready_flags;
      $display("gen_stop_callback enterred");
      @(posedge agents[0].vif.rstn);
      forever begin
        @(posedge agents[0].vif.clk);
        chnl_ready_flags = this.get_chnl_ready_flags();
        if($countones(chnl_ready_flags) <= 1) break;
      end

      $display("%s: stop 3 generators running", this.name);
      -> this.gen_stop_e;
    endtask

    virtual task run_stop_callback();
      $display("run_stop_callback enterred");

      // since generators have been forced to stop, and run_stop_flag would
      // not be raised by each generator, so no need to wait for the
      // run_stop_flags any more

      $display("%s: waiting DUT transfering all of data", this.name);
      fork
        wait(agents[0].vif.ch_margin == 'h20);
        wait(agents[1].vif.ch_margin == 'h20);
        wait(agents[2].vif.ch_margin == 'h20);
      join
      $display("%s: 3 channel fifos have transferred all data", this.name);

      $display($sformatf("*****************%s finished********************", this.name));
      $finish();
    endtask
  endclass: mcdt_fifo_full_test

endpackage

