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

  class mcdt_root_test;
    chnl_generator gen[3];
    chnl_agent agents[3];
    mcdt_monitor mcdt_mon;
    mcdt_checker chker;
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

  // USER TODO-1
  // each channel send data packet number inside [80:100]
  // data_nidles == 0, pkt_nidles == 1, data_size inside {8, 16, 32}
  class mcdt_burst_test extends mcdt_root_test;
    function new(string name = "mcdt_burst_test");
      super.new(name);
    endfunction
    virtual function void do_config();
      super.do_config();
      
      // TODO user code to be implemented below
      
    endfunction
  endclass: mcdt_burst_test

  // USER TODO-2
  // keep channel sending out data packets, and please
  // let at least two slave channels raising fifo_full (ready=0) at the same time
  // and then to stop the test
  class mcdt_fifo_full_test extends mcdt_root_test;
    function new(string name = "mcdt_fifo_full_test");
      super.new(name);
    endfunction

    virtual function void do_config();
      super.do_config();
      
      // TODO user code to be implemented below
      
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
      
      // TODO user code to be implemented below
      
    endtask

    virtual task run_stop_callback();
      $display("run_stop_callback enterred");

      // TODO user code to be implemented below

      $display($sformatf("*****************%s finished********************", this.name));
      $finish();
    endtask
  endclass: mcdt_fifo_full_test

endpackage

