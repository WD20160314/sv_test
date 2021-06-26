module class_test(
	
	);

class Transaction;
	bit [31:0] addr,crc,data[8];
	
	extern function void display();
	extern function void calc_crc();
	// function void display();
		// $display("Transaction:%h", addr);
	// endfunction:display

	// function void calc_crc();
		// crc = addr ^ data.xor;
	// endfunction
endclass:Transaction

function void Transaction::display();
	$display("Transaction:%h", addr);
endfunction
	
function void Transaction::calc_crc():
	crc = addr ^ data.xor;
endfunction

class PCI_Tran;
	bit [31:0] addr, data;
	function void display();
		$display("@%0t:PCI:addr=%h,data=%h",$time,addr,data);
	endfunction
endclass

class Statistics;
	time startT, stopT;
	static int ntrans=0;
	static time total_elapsed_time=0;
	
	function time how_long;
			how_long = stopT-startT;
			ntrans++;
			total_elapsed_time += how_long;
	endfunction
	
	function void start;
		startT=$time;
	endfunction
	
	rand bit [6:0] b;
	rand bit [5:0] e;
	constraint c_range{
		b inside {[$:4],[20:$]};
		e inside {[$:4],[20:$]};
	}
endclass

initial begin
	check_trans(tr0);
	fork
		begin:threads_inner
			check_trans(tr1);
			check_trans(tr2);
		end
		#(TIME_OUT/2) disable threads_inner;
	join
end

endmodule
