`timescale 1ns/1ns

interface my_io(input bit clock );
	logic reset_n;
	logic [15:0] din;
	logic [15:0] valid_n;
	logic [15:0] frame_n;
	logic [15:0] dout;
	logic [15:0] valido_n;
	logic [15:0] frameo_n;
	logic [15:0] busy_n;
	
	clocking cb @ (posedge clock);
	default input #1ns output #1ns;
		output reset_n;
		output din;
		output valid_n;
		output frame_n;
		input  dout;
		input  valido_n;
		input  frameo_n;
		input  busy_n;
	endclocking
	
	modport TB (input cb, output reset_n);
	
endinterface:my_io




