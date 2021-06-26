module process();

task bus_read(	input logic [31:0] addr,
				ref   logic [31:0] data
			);
	//请求总线并驱动地址
	bus.request=1'b1;
	@(posedge bus.grant) bus.addr=addr;

	//等待来自存储器的数据
	@(posedge bus.enable) data=bus.data;

	//释放总线并等待许可
	bus.request = 1'b0;
	@(negedge bus.grant);
	
endtask

logic [31:0] addr, data;

initial fork
	bus_read(addr, data);
	thread2:begin
		@data; //在数据变化时触发
		@display("Read %h from bus",data);
	end
join

/*
2.自动存储
*/
program automatic test;
	task wait_for_mem(
		input [31:0] addr, expect_data,
		output success
	);
	
	while(bus.addr!== addr)
		@(bus.addr);
	success = (bus.data==expect_data);
	endtask
	
endprogram

endmodule
