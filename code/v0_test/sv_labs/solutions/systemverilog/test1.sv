module logic_data_type(input logic rst_h);

	parameter CYCLE = 20;
	logic q, q_l, d, clk, rst_l;
	//时钟
	initial begin
		clk = 0;
		forever #(CYCLE/2) clk = ~clk;
	end
	//复位
	assign rst_l = ~rst_h;
	
	not n1(q_l, q);
	my_dff d1(q,d,clk,rst_l);
	
	/* 
	1.
	logic类型只能有一个驱动， 当有些信号你本来就希望它有多个驱动，
	例如双向总线，这些信号需要被定义成线网类型，例如wire
	*/
	
	
	/*
	2.双状态数据类型
	bit b;
	bit [31:0] b32;
	int unsigned ui;
	int i;
	byte b8;
	shortint s;
	longint l;
	integer i4;   4状态
	time t;       4状态
	real r;
	
	if($isunknown(iport)==1) //检查是否为X或Z
	*/
	
	/*
	3.常量数组
	int ascend[4] = '{0,2,3,4}; //对4个元素进行初始化
	int descend[5];
	descend = `{4,3,2,1,0};  //为5个元素赋值
	descend[0:2] = `{5,6,7};
	ascend = `{4{8}};  //4个值都是8
	descend = `{9,8,default:1};  //{9,8,1,1,1}
	*/
	
	/*
	4.for和foreach
	操作数组的最常见的方式是使用for和foreach。下例中i为for循环局部变量，
	systemverlog的$size函数返回数组的宽度。在foreach循环中，只需要指定
	数组名并在其后面的方括号中给出索引变量，systemverilog会自动遍历数组
	中的元素，索引变量将自动声明，并只在循环内有效。
	*/
	
	initial begin
		bit [31:0] src[5],dst[5];
		for(int i=0;i<$size(src);i++)
			src[i]=i;
		foreach(dst[j])
			dst[j]=src[j]*2; //dst的值是src*2
	end

	int md[2][3] = '{'{0,1,2},'{3,4,5}};
	initial begin
		$display("Initial Value:");
		foreach(md[i,j]) //注意这是正确的用法
			$display("md[%0d][%0d]=%0d",i,j,md[i][j]);
			
		$display("New Value:");
		//对最后三个元素重复赋值5
		md = '{'{9,8,7},'{3{32'd5}}};
		foreach (md[i,j])
			$display("md[%0d][%0d]=%0d",i,j,md[i][j]);
	end
	
	/*
	5.数组复制和比较
	*/
	initial begin
		bit [31:0] src[5] = '{0,1,2,3,4},
					dst[5] = '{5,4,3,2,1};
		//两个数组的聚合比较
		if(src == dst)
			$display("src==dst");
		else
			$display("src!=dst");
		//把src所有元素值复制给dst
		dst = src;
		//只改变一个元素的值
		src[0]= 5;
		//所有元素的值是否相等(否!)
		$display("src $s dat",(src==dst)?"==":"!=");
		//使用数组片段对第1-4个元素进行比较
		$display("src[1:4] %s dst[1:4]",
				(src[1:4]==dst[1:4])?"==":"!=");
	end
	/*
	6.动态数组
	*/
	int dyn[], d2[];   //声明动态数组
	
	initial begin
		dyn = new[5];             //A.分配5个元素
		foreach(dyn[j]) dyn[j]=j; //B.对元素进行初始化
		d2 = dyn;                 //C.复制一个动态数组
		d2[0]=5;                  //D.修改复制值
		$display(dyn[0], d2[0]);  //E.显示数值(0,5)
		dyn=new[20](dyn);         //F.分配20个整数值并进行赋值
		dyn=new[100];             //G.分配100个新的整数值
		dyn.delete();             //H.删除所有元素
	end
	
	/*
	7.队列
	队列的声明是使用带有美元符号的下标:[$]
	*/
	int j=1,
		q2[$]={3,4},           //队列的常量不需要用'
		q[$] = {0,2,5};		   // {0,2,5}
		
	initial begin
		q.insert(1,j);         //{0,1,2,5} 在2之前插入1
		q.insert(3,q2);        //{0,1,2,3,4,5}在q中插入一个队列
		q.delete(1);           //{0,2,3,4,5}删除第一个元素
		
		q.push_front(6);       //{6,0,2,3,4,5} 在队列前面插入
		j=q.pop_back;          //{6,0,2,3,4}   j=5
		q.push_back(8);        //{6,0,2,3,4,8} 在队列末尾插入
		j=q.pop_front;         //{0,2,3,4,8}    j=6
		foreach(q[i])
			$display(q[i]);    //              打印整个队列
		q.delete();            //              删除整个队列
	end
	/*
	8.关联数组
	*/
	
	/*
	9.typedef别名
	*/
	typedef bit [31:0] uint;    // 32比特双状态无符号数
	typedef int unsigned uint;  //等效的定义
	
	/*
	10.结构体 struct
	*/
	//初始化
	initial begin
		typedef struct{int a;
						byte b;
						shortint c;
						int d;
			}my_struct_s;
			
		my_struct_s st= '{32'haaaa_aaaad,
							8'hbb,
							16'hcccc,
							32'hdddd_dddd
		};
		
		$display{"str=%x %x %x %x", st.a, st.b, st.c, st.d};
	end
	
	
endmodule
