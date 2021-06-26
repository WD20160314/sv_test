`timescale 1ns/1ns;

`include "my_io.sv"

module my_test_top;
  bit SystemClk;
  
  //例化接口
  my_io top_io(SystemClk);
  
  //program ??
  test t(top_io)
  
  //例化DUT
  router dut(
	.reset_n  (top_io.reset_n),
	.din      (top_io.din),
	.valid_n  (top_io.valid_n),
	.frame_n  (top_io.frame_n),
	.dout     (top_io.dout),
	.valido_n (top_io.valido_n),
	.frameo_n (top_io.frameo_n),
	.busy_n   (top_io.busy_n)
  );
  
  //时钟初始化
  initial begin
    SystemClk = 0;
	forever begin
	#100
	SystemClk = ~SystemClk;
	end
  
  end


endmodule