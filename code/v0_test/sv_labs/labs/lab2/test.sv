//Lab 1 - Task 3, Step 2
//
`timescale 1ns/1ns
//Declare a program block with arguments to connect
//to modport TB declared in interface
//ToDo
program automatic test(router_io.TB rtr_io);
	bit [3:0] sa;
	bit [3:0] da;
	logic [7:0] payload[$];
		
	
  initial begin
	reset();
	gen();
	send();
  end

  
task reset();
  rtr_io.reset_n = 1'b0;
  rtr_io.cb.frame_n <= '1;
  rtr_io.cb.valid_n <= '1;
  #2 rtr_io.cb.reset_n <= 1'b1;
  repeat(15) @(rtr_io.cb);
endtask: reset


task gen();
	sa <= 'd3;
	da <= 'd7;
	payload.delete();
	repeat($urandom_range(2,4))
		payload.push_back($urandom);
endtask: gen

task send();
	send_addr();
	send_pading();
	send_payload();
endtask: send
  
task send_addr();
	rtr_io.cb.frame_n[sa] <= 1'b0;
	for(int i=0;i<4;i++) begin
		rtr_io.cb.din[sa] <= da[i];
		@(rtr_io.cb);
	end
endtask: send_addr

task send_pading();
	rtr_io.cb.frame_n <= 1'b0;
	rtr_io.cb.valid_n <= 1'b1;
	rtr_io.cb.din[sa] <= 1'b1;
	repeat(5) @(rtr_io.cb);
endtask:send_pading
  
task send_payload();
	foreach(payload[index])
	  for(int i=0; i<8; i++) begin
	    rtr_io.cb.din[sa] <= payload[index][i];
		rtr_io.cb.valid_n[sa] <= 1'b0; //driving a valid bit
		rtr_io.cb.frame_n[sa] <= ((i == 7) && (index == (payload.size() - 1)));
		@(rtr_io.cb);
	  end
	  rtr_io.cb.valid_n[sa] <= 1'b1;
endtask: send_payload
  
endprogram: test


  //Lab 1 - Task 6, Steps 3 and 4 -
  //
  //Replace $display() in initial block with $vcdpluson
  //Call reset() task
  //ToDo - Caution!! Do only in Task 6

//Lab 1 - Task 6, Step 2
//
//Define a task called reset() inside the program to reset DUT per spec.
//ToDo - Caution!! Do only in Task 6

