`default_nettype none

module tt_um_huahuahua_lmaooooooo (
    input wire [7:0] ui_in, output wire [7:0] uo_out,
    input wire [7:0] uio_in, output wire [7:0] uio_out, output wire [7:0] uio_oe,
    input wire ena, input wire clk, input wire rst_n
);
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire [1:0] R, G, B;
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;
    wire _unused = &{ena, uio_in, ui_in[7:4]};

    hvsync_generator hvsync_gen(.clk(clk),.reset(~rst_n),.hsync(hsync),.vsync(vsync),.display_on(video_active),.hpos(pix_x),.vpos(pix_y));

    // 200x100 logical game area, centered on 640x480 VGA.
    wire in_game_area = (pix_x >= 10'd120) && (pix_x < 10'd520) && (pix_y >= 10'd140) && (pix_y < 10'd340);
    wire [7:0] game_x = pix_x[9:1] - 8'd60;
    wire [6:0] game_y = pix_y[9:1] - 7'd70;

    wire button0=ui_in[0], button1=ui_in[1], button2=ui_in[2], button3=ui_in[3];
    reg [19:0] game_counter;
    wire game_tick=(game_counter==20'd0);
    always @(posedge clk) begin
        if (~rst_n) game_counter<=0; else game_counter<=game_counter+1'b1;
    end

    reg [1:0] selected_game;
    reg playing;

    wire [7:0] pong_ball_x;
    wire [6:0] pong_ball_y,pong_left_y,pong_right_y;
    wire [1:0] pong_status;
    pong pong_game(
        .clk(clk),.reset((~rst_n)||(~playing)||(selected_game!=2'd1)),
        .button_up(button0),.button_down(button1),.button_up_right(button2),.button_down_right(button3),
        .ball_x(pong_ball_x),.ball_y(pong_ball_y),.paddle_left_y(pong_left_y),.paddle_right_y(pong_right_y),.status(pong_status)
    );

    wire [1:0] snake_status;
    wire [4:0] snake_length;
    wire [5:0] snake_food_x;
    wire [4:0] snake_food_y;
    wire [16*6-1:0] snake_body_x;
    wire [16*5-1:0] snake_body_y;
    snake_game snake_game_inst(
        .clk(clk),.reset((~rst_n)||(~playing)||(selected_game!=2'd0)),
        .button_left(button0),.button_right(button1),.tick(game_tick),.status(snake_status),.length(snake_length),
        .food_x(snake_food_x),.food_y(snake_food_y),.body_x(snake_body_x),.body_y(snake_body_y)
    );

    // Menu buttons are one-shot: a held button acts once, then must be released.
    reg menu_up_armed, menu_down_armed, menu_start_armed;
    always @(posedge clk) begin
        if (~rst_n) begin
            selected_game<=0;
            playing<=0;
            menu_up_armed<=1'b1;
            menu_down_armed<=1'b1;
            menu_start_armed<=1'b1;
        end else if (game_tick) begin
            if (!button0) menu_up_armed<=1'b1;
            if (!button1) menu_down_armed<=1'b1;
            if (!button2) menu_start_armed<=1'b1;

            if (!playing) begin
                if (button0 && menu_up_armed) begin
                    menu_up_armed<=1'b0;
                    if(selected_game==0) selected_game<=3;
                    else selected_game<=selected_game-1'b1;
                end else if (button1 && menu_down_armed) begin
                    menu_down_armed<=1'b0;
                    if(selected_game==3) selected_game<=0;
                    else selected_game<=selected_game+1'b1;
                end else if (button2 && menu_start_armed && (selected_game==2'd0 || selected_game==2'd1)) begin
                    menu_start_armed<=1'b0;
                    playing<=1'b1;
                end
            end else if ((selected_game==2'd0 && snake_status!=0) ||
                         (selected_game==2'd1 && pong_status!=0)) begin
                playing<=1'b0;
            end
        end
    end

    reg pixel_on;
    integer i;
    reg [5:0] snake_cell_x;
    reg [4:0] snake_cell_y;
    always @(*) begin
        pixel_on=1'b0; snake_cell_x=5'd0; snake_cell_y=5'd0;
        if (!playing) begin
            // Snake icon.
            if((game_y>=12)&&(game_y<15)&&(game_x>=45)&&(game_x<80)) pixel_on=1'b1;
            if((game_y>=15)&&(game_y<18)&&(game_x>=75)&&(game_x<105)) pixel_on=1'b1;
            if((game_y>=18)&&(game_y<21)&&(game_x>=100)&&(game_x<130)) pixel_on=1'b1;
            if((game_y>=20)&&(game_y<23)&&(game_x>=125)&&(game_x<155)) pixel_on=1'b1;
            if((game_x>=160)&&(game_x<165)&&(game_y>=17)&&(game_y<22)) pixel_on=1'b1;
            // Pong icon.
            if((game_x>=45)&&(game_x<50)&&(game_y>=31)&&(game_y<43)) pixel_on=1'b1;
            if((game_x>=150)&&(game_x<155)&&(game_y>=31)&&(game_y<43)) pixel_on=1'b1;
            if((game_x>=97)&&(game_x<103)&&(game_y>=34)&&(game_y<40)) pixel_on=1'b1;
            // Space Invaders icon.
            if((game_y>=51)&&(game_y<55)&&(game_x>=85)&&(game_x<115)) pixel_on=1'b1;
            if((game_y>=55)&&(game_y<61)&&(game_x>=78)&&(game_x<122)) pixel_on=1'b1;
            if((game_y>=61)&&(game_y<64)&&(game_x>=84)&&(game_x<92)) pixel_on=1'b1;
            if((game_y>=61)&&(game_y<64)&&(game_x>=108)&&(game_x<116)) pixel_on=1'b1;
            // Empty slot icon.
            if((game_y>=71)&&(game_y<74)&&(game_x>=95)&&(game_x<110)) pixel_on=1'b1;
            if((game_y>=74)&&(game_y<80)&&(game_x>=108)&&(game_x<113)) pixel_on=1'b1;
            if((game_y>=80)&&(game_y<83)&&(game_x>=101)&&(game_x<106)) pixel_on=1'b1;
            if((game_y>=86)&&(game_y<89)&&(game_x>=101)&&(game_x<106)) pixel_on=1'b1;
            // Selection marker.
            if((game_x>=25)&&(game_x<31)) begin
                if((selected_game==0)&&(game_y>=10)&&(game_y<25)) pixel_on=1'b1;
                if((selected_game==1)&&(game_y>=29)&&(game_y<46)) pixel_on=1'b1;
                if((selected_game==2)&&(game_y>=49)&&(game_y<66)) pixel_on=1'b1;
                if((selected_game==3)&&(game_y>=69)&&(game_y<91)) pixel_on=1'b1;
            end
        end else if(selected_game==2'd1) begin
            if((game_x==0)||(game_x==199)||(game_y==0)||(game_y==99)) pixel_on=1'b1;
            if((game_x<5)&&(game_y>=pong_left_y)&&(game_y<pong_left_y+20)) pixel_on=1'b1;
            if((game_x>=195)&&(game_y>=pong_right_y)&&(game_y<pong_right_y+20)) pixel_on=1'b1;
            if((game_x>=pong_ball_x-2)&&(game_x<=pong_ball_x+2)&&(game_y>=pong_ball_y-2)&&(game_y<=pong_ball_y+2)) pixel_on=1'b1;
            if((game_x==99||game_x==100)&&((game_y&3)!=0)) pixel_on=1'b1;
        end else if(selected_game==2'd0) begin
            // Snake: 40x20 cells in a 160x80 playfield.
            if((game_x>=20)&&(game_x<180)&&(game_y>=10)&&(game_y<90)) begin
                if((game_x==20)||(game_x==179)||(game_y==10)||(game_y==89)) pixel_on=1'b1;
                snake_cell_x=(game_x-8'd20)>>2;
                snake_cell_y=(game_y-7'd10)>>2;
                if((snake_cell_x==snake_food_x)&&(snake_cell_y==snake_food_y)) pixel_on=1'b1;
                for(i=0;i<16;i=i+1) begin
                    if((i<snake_length)&&
                       (snake_cell_x==snake_body_x[i*6 +: 6])&&
                       (snake_cell_y==snake_body_y[i*5 +: 5])) pixel_on=1'b1;
                end
            end
        end else if(selected_game==2'd2) begin
            // Space Invaders placeholder.
            if((game_x>=95)&&(game_x<105)&&(game_y>=85)&&(game_y<90)) pixel_on=1'b1;
        end
    end

    assign R=(video_active&&in_game_area&&pixel_on)?2'b11:2'b00;
    assign G=(video_active&&in_game_area&&pixel_on)?2'b11:2'b00;
    assign B=(video_active&&in_game_area&&pixel_on)?2'b11:2'b00;
endmodule

module hvsync_generator(
    input wire clk,input wire reset,output reg hsync,output reg vsync,output wire display_on,
    output wire [9:0] hpos,output wire [9:0] vpos
);
    localparam H_VISIBLE=640,H_FRONT=16,H_SYNC=96,H_TOTAL=800;
    localparam V_VISIBLE=480,V_FRONT=10,V_SYNC=2,V_TOTAL=525;
    reg [9:0] h_count,v_count;
    assign hpos=h_count; assign vpos=v_count; assign display_on=(h_count<H_VISIBLE)&&(v_count<V_VISIBLE);
    always @(posedge clk) begin
        if(reset) begin h_count<=0;v_count<=0;hsync<=1;vsync<=1;end
        else begin
            if(h_count==H_TOTAL-1) begin h_count<=0;if(v_count==V_TOTAL-1)v_count<=0;else v_count<=v_count+1'b1;end
            else h_count<=h_count+1'b1;
            hsync<=!((h_count>=H_VISIBLE+H_FRONT)&&(h_count<H_VISIBLE+H_FRONT+H_SYNC));
            vsync<=!((v_count>=V_VISIBLE+V_FRONT)&&(v_count<V_VISIBLE+V_FRONT+V_SYNC));
        end
    end
endmodule
