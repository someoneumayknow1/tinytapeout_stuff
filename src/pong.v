`default_nettype none

module pong (
    input wire clk,
    input wire reset,
    input wire button_up,
    input wire button_down,
    input wire button_up_right,
    input wire button_down_right,
    output reg [7:0] ball_x,
    output reg [6:0] ball_y,
    output reg [6:0] paddle_left_y,
    output reg [6:0] paddle_right_y,
    output reg [1:0] status
);
    localparam SCREEN_HEIGHT=100;
    localparam PADDLE_HEIGHT=20;
    localparam LEFT_X=5;
    localparam RIGHT_X=194;
    reg signed [2:0] ball_dx, ball_dy;
    reg [19:0] counter;
    wire signed [8:0] left_hit_offset = $signed({2'b00,ball_y}) - $signed({2'b00,paddle_left_y}) - 9'sd10;
    wire signed [8:0] right_hit_offset = $signed({2'b00,ball_y}) - $signed({2'b00,paddle_right_y}) - 9'sd10;
    wire tick=(counter==20'd0);

    function signed [2:0] offset_to_dy;
        input signed [8:0] offset;
        begin
            if(offset >= 9'sd12) offset_to_dy=3'sd3;
            else if(offset >= 9'sd4) offset_to_dy=3'sd2;
            else if(offset > 0) offset_to_dy=3'sd1;
            else if(offset <= -9'sd12) offset_to_dy=-3'sd3;
            else if(offset <= -9'sd4) offset_to_dy=-3'sd2;
            else if(offset < 0) offset_to_dy=-3'sd1;
            else offset_to_dy=3'sd0;
        end
    endfunction

    always @(posedge clk) begin
        if(reset) begin
            counter<=0; ball_x<=100; ball_y<=50;
            ball_dx<=1; ball_dy<=1;
            paddle_left_y<=40; paddle_right_y<=40; status<=0;
        end else begin
            counter<=counter+1'b1;
            if(tick&&status==0) begin
                if(button_up&&paddle_left_y>0) paddle_left_y<=paddle_left_y-1;
                else if(button_down&&paddle_left_y<SCREEN_HEIGHT-PADDLE_HEIGHT) paddle_left_y<=paddle_left_y+1;
                if(button_up_right&&paddle_right_y>0) paddle_right_y<=paddle_right_y-1;
                else if(button_down_right&&paddle_right_y<SCREEN_HEIGHT-PADDLE_HEIGHT) paddle_right_y<=paddle_right_y+1;

                // Explicit signed movement avoids unsigned wraparound when dy is negative.
                if(ball_dx>0) ball_x<=ball_x+1'b1; else ball_x<=ball_x-1'b1;
                if(ball_dy>0) ball_y<=ball_y+1'b1; else if(ball_dy<0) ball_y<=ball_y-1'b1;

                if(ball_dy<0&&ball_y<=1) ball_dy<=1;
                else if(ball_dy>0&&ball_y>=SCREEN_HEIGHT-2) ball_dy<=-1;

                // Only the paddle the ball is moving toward can collide.
                if(ball_dx<0&&ball_x<=LEFT_X) begin
                    if(ball_y>=paddle_left_y&&ball_y<=paddle_left_y+PADDLE_HEIGHT) begin
                        ball_dx<=1;
                        ball_dy<=offset_to_dy(left_hit_offset);
                    end else status<=2'b11;
                end
                if(ball_dx>0&&ball_x>=RIGHT_X) begin
                    if(ball_y>=paddle_right_y&&ball_y<=paddle_right_y+PADDLE_HEIGHT) begin
                        ball_dx<=-1;
                        ball_dy<=offset_to_dy(right_hit_offset);
                    end else status<=2'b10;
                end
            end
        end
    end
endmodule
