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
    localparam SCREEN_WIDTH = 200;
    localparam SCREEN_HEIGHT = 100;
    localparam PADDLE_HEIGHT = 20;
    localparam PADDLE_X = 5;
    localparam RIGHT_PADDLE_X = 194;

    reg signed [2:0] ball_dx;
    reg signed [2:0] ball_dy;
    reg [19:0] counter;
    reg signed [7:0] hit_offset;
    wire tick = (counter == 20'd0);

    always @(posedge clk) begin
        if (reset) begin
            counter <= 0;
            ball_x <= 100;
            ball_y <= 50;
            ball_dx <= 1;
            ball_dy <= 1;
            paddle_left_y <= 40;
            paddle_right_y <= 40;
            status <= 2'b00;
        end else begin
            counter <= counter + 1;

            if (tick && status == 2'b00) begin
                if (button_up && paddle_left_y > 0)
                    paddle_left_y <= paddle_left_y - 1;
                else if (button_down && paddle_left_y < SCREEN_HEIGHT - PADDLE_HEIGHT)
                    paddle_left_y <= paddle_left_y + 1;

                if (button_up_right && paddle_right_y > 0)
                    paddle_right_y <= paddle_right_y - 1;
                else if (button_down_right && paddle_right_y < SCREEN_HEIGHT - PADDLE_HEIGHT)
                    paddle_right_y <= paddle_right_y + 1;

                ball_x <= ball_x + ball_dx;
                ball_y <= ball_y + ball_dy;

                if (ball_y <= 1)
                    ball_dy <= 1;
                else if (ball_y >= SCREEN_HEIGHT - 2)
                    ball_dy <= -1;

                // Left paddle: collide only while moving left.
                if (ball_dx < 0 && ball_x <= PADDLE_X) begin
                    if (ball_y >= paddle_left_y && ball_y <= paddle_left_y + PADDLE_HEIGHT) begin
                        ball_dx <= 1;
                        hit_offset = $signed({1'b0, ball_y}) - $signed({1'b0, paddle_left_y + 10});
                        ball_dy <= hit_offset >>> 2;
                        if (hit_offset != 0 && (hit_offset >>> 2) == 0)
                            ball_dy <= (hit_offset < 0) ? -1 : 1;
                    end else begin
                        status <= 2'b11;
                    end
                end

                // Right paddle: collide only while moving right.
                if (ball_dx > 0 && ball_x >= RIGHT_PADDLE_X) begin
                    if (ball_y >= paddle_right_y && ball_y <= paddle_right_y + PADDLE_HEIGHT) begin
                        ball_dx <= -1;
                        hit_offset = $signed({1'b0, ball_y}) - $signed({1'b0, paddle_right_y + 10});
                        ball_dy <= hit_offset >>> 2;
                        if (hit_offset != 0 && (hit_offset >>> 2) == 0)
                            ball_dy <= (hit_offset < 0) ? -1 : 1;
                    end else begin
                        status <= 2'b10;
                    end
                end
            end
        end
    end
endmodule
