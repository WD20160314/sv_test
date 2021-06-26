`timescale 1ns/1ns;

`include "my_io.sv"

module t1;
	bit clk;
	
	my_io top_io(clk);
	
	my_test t(top_io);
	
	router dut(
		.reset_n (top_io.reset_n),
		.din     (top_io.din),
		.valid_n (top_io.valid_n),
		.frame_n (top_io.frame_n),
		.dout    (top_io.dout),
		.valido_n(top_io.valido_n),
		.frameo_n(top_io.frameo_n),
		.busy_n  (top_io.busy_n)
	);
	
	initial begin
		clk = 0;
	end

	always #10 clk = ~clk;

endmodule 


