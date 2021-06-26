`timescale 1ns/1ns

program automatic my_test(my_io.TB rtr_io);
	initial begin
		reset();
	end

task reset();
	rtr_io.reset_n = 1'b0;
	rtr_io.cb.valid_n <= 1'b1;
	rtr_io.cb.frame_n <= 1'b1;
	#1 rtr_io.cb.reset_n <= 1'b1;
	repeat(15) @(rtr_io.cb);
endtask:reset

initial begin
	$display("Hello World");
end

	
endprogram