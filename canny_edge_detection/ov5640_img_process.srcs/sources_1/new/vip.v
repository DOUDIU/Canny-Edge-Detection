module vip(
    //module clock
    input           clk            ,   // ʱ���ź�
    input           rst_n          ,   // ��λ�źţ�����Ч��

    //ͼ����ǰ�����ݽӿ�
    input           pre_frame_vsync,   
    input           pre_frame_hsync,
    input           pre_frame_de   ,
    input    [15:0] pre_rgb        ,
    input    [10:0] xpos           ,
    input    [10:0] ypos           ,

    //ͼ���������ݽӿ�
    output          post_frame_vsync,  // ��ͬ���ź�
    output          post_frame_hsync,  // ��ͬ���ź�
    output          post_frame_de   ,  // ��������ʹ��
    output   [15:0] post_rgb,           // RGB565��ɫ����

    input           key_in
);

//wire define
wire   [ 7:0]         img_y;
wire                  pe_frame_vsync;
wire                  pe_frame_href;
wire                  pe_frame_clken;

reg    [15:0]         post_rgb;
reg                   post_frame_vsync;
reg                   post_frame_hsync;
reg                   post_frame_de;

wire                  ycbcr_vsync;
wire                  ycbcr_hsync; 
wire                  ycbcr_de;
wire      [7:0]       img_ycbcr;

wire                  gray_vsync;
wire                  gray_hsync; 
wire                  gray_de;
wire      [7:0]       img_gray;

wire                  binarization_vsync;
wire                  binarization_hsync; 
wire                  binarization_de;   
wire                  img_binarization;

wire                  erosion_vsync;
wire                  erosion_hsync; 
wire                  erosion_de;   
wire                  img_erosion;

wire                  dilation_vsync;	
wire                  dilation_hsync;
wire                  dilation_de;  
wire                  img_dilation;  
  
wire                  sobel_vsync;     
wire                  sobel_hsync;
wire                  sobel_de;       
wire                  img_sobel;        

wire                  canny_vsync;     
wire                  canny_hsync;
wire                  canny_de;       
wire                  img_canny;

wire                  key_out;
reg                   key_out_last;
reg         [3:0]     key_state;
//*****************************************************
//**                    main code
//*****************************************************


//RGBתYCbCrģ��
rgb2ycbcr u_rgb2ycbcr(
    //module clock
    .clk             (clk    ),            // ʱ���ź�
    .rst_n           (rst_n  ),            // ��λ�źţ�����Ч��
    //ͼ����ǰ�����ݽӿ�
    .pre_frame_vsync (pre_frame_vsync),    // vsync�ź�
    .pre_frame_hsync (pre_frame_hsync),    // href�ź�
    .pre_frame_de    (pre_frame_de   ),    // data enable�ź�
    .img_red         (pre_rgb[15:11] ),
    .img_green       (pre_rgb[10:5 ] ),
    .img_blue        (pre_rgb[ 4:0 ] ),
    //ͼ���������ݽӿ�
    .post_frame_vsync(ycbcr_vsync),     // vsync�ź�
    .post_frame_hsync(ycbcr_hsync),      // href�ź�
    .post_frame_de   (ycbcr_de),     // data enable�ź�
    .img_y           (img_ycbcr),              //�Ҷ�����
    .img_cb          (),
    .img_cr          ()
);

//�Ҷ�ͼ��ֵ�˲�
vip_gray_median_filter u_vip_gray_median_filter(
    .clk    (clk),   
    .rst_n  (rst_n), 
    
    //Ԥ����ͼ������
    .pe_frame_vsync (ycbcr_vsync),      // vsync�ź�
    .pe_frame_href  (ycbcr_hsync),       // href�ź�
    .pe_frame_clken (ycbcr_de),      // data enable�ź�
    .pe_img_y       (img_ycbcr),               
                                           
    //������ͼ������                     
    .pos_frame_vsync (gray_vsync),        // vsync�ź�
    .pos_frame_href  (gray_hsync),        // href�ź�
    .pos_frame_clken (gray_de   ),           // data enable�ź�
    .pos_img_y       (img_gray)          //��ֵ�˲���ĻҶ�����
);

//canny��Ե���
canny_edge_detect_top u_canny_edge_detect_top(
        .clk                (clk),             //cmos ����ʱ��
        .rst_n              (rst_n),  
                            
        .per_frame_vsync    (gray_vsync), 
        .per_frame_href     (gray_hsync),  
        .per_frame_clken    (gray_de), 
        .per_img_y          (img_gray),       
                          
        .post_frame_vsync   (canny_vsync), 
        .post_frame_href    (canny_hsync),  
        .post_frame_clken   (canny_de), 
        .post_img_bit       (img_canny)
    );
//��ֵ��ģ��
binarization  u_binarization(
    .clk         (clk),
    .rst_n       (rst_n),
    //ͼ����ǰ�����ݽӿ�     
    .ycbcr_vsync (gray_vsync),
    .ycbcr_hsync (gray_hsync),
    .ycbcr_de    (gray_de),   
    .luminance   (img_gray),
    //ͼ���������ݽӿ�     
    .post_vsync  (binarization_vsync),
    .post_hsync  (binarization_hsync),
    .post_de     (binarization_de),
    .monoc       (img_binarization)                   //��ֵ���������
);
VIP_Bit_Erosion_Detector
#(
	.IMG_HDISP(800),
	.IMG_VDISP(480)
) u_VIP_Bit_Erosion_Detector
(
	//global clock
	.clk               (clk),     				//cmos video pixel clock
	.rst_n             (rst_n), 				//global reset

	//Image data prepred to be processd
	.per_frame_vsync   (binarization_vsync),     	//Prepared Image data vsync valid signal
	.per_frame_href    (binarization_hsync),     		//Prepared Image data href vaild  signal
	.per_frame_clken   (binarization_de),        	//Prepared Image data output/capture enable clock
	.per_img_Bit       (img_binarization),  		//Prepared Image Bit flag outout(1: Value, 0:inValid)
	
	//Image data has been processd
	.post_frame_vsync      (erosion_vsync),     //Processed Image data vsync valid signal
	.post_frame_href       (erosion_hsync),     //Processed Image data href vaild  signal
	.post_frame_clken      (erosion_de),        //Processed Image data output/capture enable clock
	.post_img_Bit	       (img_erosion)            //ocessed Image Bit flag outout(1: Value, 0:inValid)
);

VIP_Bit_Dilation_Detector
#(
	.IMG_HDISP(800),
	.IMG_VDISP(480) 
)u_VIP_Bit_Dilation_Detector
(
	//global clock
	.clk               (clk),  				//cmos video pixel clock
	.rst_n             (rst_n),			     //global reset

	//Image data prepred to be processd
	.per_frame_vsync   (erosion_vsync),     	//Prepared Image data vsync valid signal
	.per_frame_href    (erosion_hsync),     		//Prepared Image data href vaild  signal
	.per_frame_clken   (erosion_de),       	//Prepared Image data output/capture enable clock
	.per_img_Bit       (img_erosion),     	//Prepared Image Bit flag outout(1: Value, 0:inValid)
	
	//Image data has been processd
	.post_frame_vsync         (dilation_vsync),	//Processed Image data vsync valid signal
	.post_frame_href          (dilation_hsync),	//Processed Image data href vaild  signal
	.post_frame_clken         (dilation_de), 	   //Processed Image data output/capture enable clock
	.post_img_Bit             (img_dilation)     	//Processed Image Bit flag outout(1: Value, 0:inValid)
);
vip_sobel_edge_detector 
    #(
      .SOBEL_THRESHOLD(128)//Sobel ��ֵ
    )
    u_vip_sobel_edge_detector(
    .clk                (clk),            
    .rst_n              (rst_n),  
    //����ǰ����          
    .per_frame_vsync    (gray_vsync),   
    .per_frame_href     (gray_hsync),    
    .per_frame_clken    (gray_de),     
    .per_img_y          (img_gray),      
    //����������          
    .post_frame_vsync   (sobel_vsync), 
    .post_frame_href    (sobel_hsync),  
    .post_frame_clken   (sobel_de), 
    .post_img_bit       (img_sobel)
);

key_stable u_key_stable(
        .clk_sys    (clk),
        .reset_n    (rst_n),
        .key_in     (key_in),
        .key_out    (key_out)
    );
    
always@(posedge clk or negedge rst_n)
    if(!rst_n)
        key_out_last <= key_out;
    else
        key_out_last <= key_out;
    
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        key_state <= 4'd7;
    else if(!key_out_last & key_out)
        key_state <= key_state == 4'd7 ? 1'b0 : key_state + 1'b1;
    else
        key_state <= key_state;
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        begin
            post_rgb            <=   pre_rgb;    
            post_frame_vsync    <=   pre_frame_vsync;       
            post_frame_hsync    <=   pre_frame_hsync;       
            post_frame_de       <=   pre_frame_de;       
        end
     else
         begin
            case(key_state)
            4'd0:
                begin
                    post_frame_vsync    <=   pre_frame_vsync;       
                    post_frame_hsync    <=   pre_frame_hsync;       
                    post_frame_de       <=   pre_frame_de;  
                    post_rgb            <=   pre_rgb;    
                end
            4'd1:
                begin  
                    post_frame_vsync    <=   ycbcr_vsync;       
                    post_frame_hsync    <=   ycbcr_hsync;       
                    post_frame_de       <=   ycbcr_de;   
                    post_rgb            <=   {img_ycbcr[7:3],img_ycbcr[7:2],img_ycbcr[7:3]};   
                end                          
            4'd2:
                begin
                    post_frame_vsync    <=   gray_vsync;        
                    post_frame_hsync    <=   gray_hsync;        
                    post_frame_de       <=   gray_de;    
                    post_rgb            <=   {img_gray[7:3],img_gray[7:2],img_gray[7:3]};   
                end
            4'd3:  
                begin
                    post_frame_vsync    <=   binarization_vsync;          
                    post_frame_hsync    <=   binarization_hsync;          
                    post_frame_de       <=   binarization_de;      
                    post_rgb            <=   {16{img_binarization}};     
                end                          
            4'd4:
                begin
                    post_frame_vsync    <=   erosion_vsync;         
                    post_frame_hsync    <=   erosion_hsync;         
                    post_frame_de       <=   erosion_de;     
                    post_rgb            <=   {16{img_erosion}};    
                end
            4'd5:  
                begin
                    post_frame_vsync    <=   dilation_vsync;	       
                    post_frame_hsync    <=   dilation_hsync;        
                    post_frame_de       <=   dilation_de;    
                    post_rgb            <=   {16{img_dilation}};   
                end
            4'd6:  
                begin
                    post_frame_vsync    <=   sobel_vsync;           
                    post_frame_hsync    <=   sobel_hsync;           
                    post_frame_de       <=   sobel_de;       
                    post_rgb            <=   {16{img_sobel}};    
                end   
            4'd7:  
                begin
                    post_frame_vsync    <=   canny_vsync;           
                    post_frame_hsync    <=   canny_hsync;           
                    post_frame_de       <=   canny_de;       
                    post_rgb            <=   {16{img_canny}};    
                end         
            default:
                begin
                    post_frame_vsync    <=   pre_frame_vsync;       
                    post_frame_hsync    <=   pre_frame_hsync;       
                    post_frame_de       <=   pre_frame_de;  
                    post_rgb            <=   pre_rgb;    
                end                 
            endcase      
         end
end

endmodule