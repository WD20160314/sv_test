module top;

logic [1:0] grant, request;
bit clk;

initial begin
	forever #50 clk = ~clk;
end


//2.接口方式
//创建接口
interface arb_if(input bit clk);
	logic [1:0] grant, request;
	bit rst;
endinterface


arb_if arbif(clk);

arb_with_ifc a1(
	arbif
);

test_with_ifc t1(
	arbif
);

//1.传统方式
// arb_with_port  a1(
	// grant,
	// request,
	// rst,
	// clk
// );

// test_with_port t1(
	// grant,
	// request,
	// rst,
	// clk
// );

endmodule
