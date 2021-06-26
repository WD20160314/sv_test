module arb_with_ifc(arb_if arbif);
	
	always @ (posedge arbif.clk or posedge arbif.rst)
		begin
			if(arbif.rst)
				arbif.grant <= 2'b00;
			else if(arbif.request[0])
				arbif.grant <= 2'b01;
			else if(arbif.request[1])
				arbif.grant <= 2'b10;
			else
				arbif.grant <= 2'b0;
		end


endmodule