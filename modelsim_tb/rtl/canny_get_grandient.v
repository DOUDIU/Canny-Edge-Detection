module canny_get_grandient
(
	input			       clk,
	input			       rst_s,
	
	input			       mediant_hs,
	input			       mediant_vs,
	input			       mediant_de,
	input    	[7:0]      mediant_img,
	
	output		           grandient_hs,
	output		           grandient_vs,
	output		           grandient_de,
	output  reg [15:0]	   gra_path//�ݶȷ�ֵ+����+�ߵ���ֵ״̬
);
//˫��ֵ�ĸߵ���ֵ
parameter THRESHOLD_LOW  = 10'd50;
parameter THRESHOLD_HIGH = 10'd100;

reg[9:0] Gx_1;//GX��һ�м���
reg[9:0] Gx_3;
reg[9:0] Gy_1;
reg[9:0] Gy_3;

reg[10:0] Gx;//Gx Gy ����� ��ƫ��
reg[10:0] Gy;

reg[23:0] sqrt_in;//�����ݶ�ֵ������ƽ����
reg[9:0] sqrt_out;//��ƽ���õ����ݶ�
reg[10:0] sqrt_rem;//��ƽ��������
wire [23:0] sqrt_in_n;
wire [15:0] sqrt_out_n;
wire [10:0] sqrt_rem_n;

//9X9���� sobel������
wire [7:0]  ma1_1;
wire [7:0]  ma1_2;
wire [7:0]  ma1_3;
wire [7:0]  ma2_1;
wire [7:0]  ma2_2;
wire [7:0]  ma2_3;
wire [7:0]  ma3_1;
wire [7:0]  ma3_2;
wire [7:0]  ma3_3;
//��¼�������أ���������ǰ����ȫΪ8'h00,Ҳ����������Ȼ
reg edge_de_a;
reg edge_de_b;
wire edge_de;
reg [9:0] row_cnt;
//-----�Ǽ���ֵ����----
reg[1:0] sign;//Gx Gy  �� ��
reg type; // Gx Gy ���  ͬ��

reg  path_one;
wire path_two;
reg  path_thr;
wire path_fou;//�ĸ��ݶȷ���
wire start;//�жϣ���xy�᷽����û������

wire    sobel_vsync;
wire    sobel_href;
wire    sobel_clken;

vip_matrix_generate_3x3_8bit u_sobel_matrix_generate_3x3_8bit(
    .clk        (clk), 
    .rst_n      (rst_s),
    
    //����ǰͼ������
    .per_frame_vsync    (mediant_vs),
    .per_frame_href     (mediant_hs), 
    .per_frame_clken    (mediant_de),
    .per_img_y          (mediant_img),
    
    //������ͼ������
    .matrix_frame_vsync (sobel_vsync),
    .matrix_frame_href  (sobel_href),
    .matrix_frame_clken (sobel_clken),
    .matrix_p11         (ma1_1),    
    .matrix_p12         (ma1_2),    
    .matrix_p13         (ma1_3),
    .matrix_p21         (ma2_1),    
    .matrix_p22         (ma2_2),    
    .matrix_p23         (ma2_3),
    .matrix_p31         (ma3_1),    
    .matrix_p32         (ma3_2),    
    .matrix_p33         (ma3_3)
);
//----------------Sobel Parameter--------------------------------------------
//      Gx             Gy				 Pixel
// [+1  0  -1]   [+1  +2  +1]   [ma1_1  ma1_2  ma1_3]
// [+2  0  -2]   [ 0   0   0]   [ma2_1  ma2_2  ma2_3]
// [+1  0  -1]   [-1  -2  -1]   [ma3_1  ma3_2  ma3_3]
//-------------------------------------------------------------
//��GX����Gy 2�����ȼ�  ��һ����ˮ��     
always @ (posedge clk or negedge rst_s)
begin
	if(!rst_s)
		begin
            Gx_1 <= 10'd0;
            Gx_3 <= 10'd0;
		end
	else
		begin
            Gx_1 <= {2'b00,ma1_1} + {1'b0,ma2_1,1'b0} +{2'b0,ma3_1};
            Gx_3 <= {2'b00,ma1_3} + {1'b0,ma2_3,1'b0} +{2'b0,ma3_3};
		end
end

always @ (posedge clk or negedge rst_s)
begin
	if(!rst_s)
		begin
            Gy_1 <= 10'd0;
            Gy_3 <= 10'd0;
		end
	else
		begin
            Gy_1 <= {2'b00,ma1_1} + {1'b0,ma1_2,1'b0} +{2'b0,ma1_3};
            Gy_3 <= {2'b00,ma3_1} + {1'b0,ma3_2,1'b0} +{2'b0,ma3_3};
		end
end

//�ڶ��� ---Gx1 Gx3��Gy1 Gy3  ����  ��� xy�����ƫ��  ���ж�GX GY������    
always @(posedge clk or negedge rst_s)
begin
	if(!rst_s)
		begin
		Gx <= 11'd0;
		Gy <= 11'd0;
		sign <= 2'b00;
		end
	else
		begin
		Gx <= (Gx_1 >= Gx_3)? Gx_1 - Gx_3 : Gx_3 - Gx_1;
		Gy <= (Gy_1 >= Gy_3)? Gy_1 - Gy_3 : Gy_3 - Gy_1;
		sign[0] <= (Gx_1 >= Gx_3)? 1'b1 : 1'b0;//�ж�GX Gy ������1 �� 0 ��
		sign[1] <= (Gy_1 >= Gy_3)? 1'b1 : 1'b0;
		end
end

//������ ƽ����  + GX��GY��ͬ�ţ�+  GX GY ��С���� + �ݶȷ��� 
//�� Gx^2 Gy^2,�ṩ������Ip�����ݶȣ� //�ݶȵķ�����Ǻ���f(x,y)������������ķ����ݶȵ�ģΪ�����������ֵ��
// �ݶȵ��� = (Gx^2 + Gy^2)��ƽ��
always @(posedge clk or negedge rst_s)
begin
	if(!rst_s)
		sqrt_in <= 24'd0;
	else
		sqrt_in <= Gx*Gx + Gy*Gy;
end
assign sqrt_in_n = sqrt_in;

//��Gx Gy  ���������������  ����  ��� 1 ͬ�� 0
always @ (posedge clk or negedge rst_s)
begin
	if(!rst_s)
	   type <= 1'b0;
	else if(sign[0]^sign[1])
        type <= 1'b1;
	else
		type <= 1'b0;
end

// �� GX GY ��С�������жϣ�Ҳ���� GX > GY*2.5 �� Gy > GX*2.5?
// ���� GX > GY*2.5 �ض�Ϊx�᷽��
always @ (posedge clk or negedge rst_s)
begin
	if (!rst_s)
		path_one <= 1'b0;
	else if(Gx > (Gy + Gy + Gy[10:1]))
		path_one <= 1'b1;
	else//�����и�ʧ��㣬����Gx Gy��10λ��������GY*2.5 ����1023ʱ��ֻȡ��10λ����λ��ʧ����if�������ͻ����XY��ͬʱΪ1
		path_one <= 1'b0;
end

// ���� Gy > Gx*2.5 �ض�Ϊy�᷽��
always @ (posedge clk or negedge rst_s)
begin
	if (!rst_s)
		path_thr <= 1'b0;
	else if(Gy > (Gx + Gx + Gx[10:1]))
		path_thr <= 1'b1;
	else
		path_thr <= 1'b0;
end

//  �ж��� x y �᷽�� ���ж������ԽǷ���
// ����������ԭ�������Ͻ� ------->  x
//			     |
//			     |
//			    y|
// ͬ�� Ϊ \   ���Ϊ  /  (��Ȼ���� X Y �� �����ǵ������)
assign start = (path_one | path_thr)? 1'b0 : 1'b1;
assign path_two = (start) ?     type : 1'b0;
assign path_fou = (start) ?     ~type: 1'b0;		
//�� path �����ʵ����ӳ٣�ƥ��ʱ��
reg    [9:0]   path_fou_t;
reg    [9:0]   path_thr_t;
reg    [9:0]   path_two_t;
reg    [9:0]   path_one_t;
always@(posedge clk or negedge rst_s)
begin
  if (!rst_s)
  begin
    path_fou_t        <=  10'd0 ;
    path_thr_t        <=  10'd0 ;
    path_two_t        <=  10'd0 ;
    path_one_t        <=  10'd0 ;
  end
  else
  begin
	   path_fou_t <= {path_fou_t[8:0], path_fou} ;
	   path_thr_t <= {path_thr_t[8:0], path_thr} ;
	   path_two_t <= {path_two_t[8:0], path_two} ;
	   path_one_t <= {path_one_t[8:0], path_one} ;
  end
end
wire        path_fou_f;
wire        path_thr_f;
wire        path_two_f;
wire        path_one_f;

assign path_fou_f = path_fou_t[6] ;
assign path_thr_f = path_thr_t[6] ;
assign path_two_f = path_two_t[6] ;
assign path_one_f = path_one_t[6] ;
	
// //����IP����߼���//�ӳ�7��ʱ��
cordic_0 u_cordic(
    .aclk                     (clk),
    .s_axis_cartesian_tvalid  (1'b1),
    .s_axis_cartesian_tdata   (sqrt_in_n),
    .m_axis_dout_tvalid       (),
   . m_axis_dout_tdata        (sqrt_out_n)
  );								

//���ļ�
//�����õ��ݶȣ��ټ���4������gra_path[13:10]
//gra_path[15:14]�ߵ���ֵ��gra_path[13:10]�ĸ�����gra_path[9:0]�ݶȷ�ֵ
always @(posedge clk or negedge rst_s)
begin
	if(!rst_s)
		gra_path <= 16'd0;
	else if (sqrt_out_n > THRESHOLD_HIGH)
		gra_path <= {1'b1,1'b0,path_fou_f,path_thr_f,path_two_f,path_one_f,sqrt_out_n[9:0]};
	else if (sqrt_out_n > THRESHOLD_LOW)
		gra_path <= {1'b0,1'b1,path_fou_f,path_thr_f,path_two_f,path_one_f,sqrt_out_n[9:0]};
	else
		gra_path <= 16'd0;
end

//�� hs vs de �����ʵ����ӳ٣�ƥ��ʱ��
reg    [10:0]  sobel_vsync_t     ;
reg    [10:0]  sobel_href_t      ;
reg    [10:0]  sobel_clken_t     ;
always@(posedge clk or negedge rst_s)
begin
  if (!rst_s)
  begin
    sobel_vsync_t    <= 11'd0 ;
    sobel_href_t     <= 11'd0 ;
    sobel_clken_t    <= 11'd0 ;
  end
  else
  begin
	   sobel_vsync_t <= {sobel_vsync_t[9:0], sobel_vsync } ;
	   sobel_href_t  <= {sobel_href_t [9:0], sobel_href  } ;
	   sobel_clken_t <= {sobel_clken_t[9:0], sobel_clken } ;
  end
end

assign grandient_hs = sobel_href_t  [10] ;
assign grandient_vs = sobel_vsync_t [10] ;
assign grandient_de = sobel_clken_t [10] ;

endmodule
