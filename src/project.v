`default_nettype none

module tt_um_huahuahua_lmaooooooo (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire ena,
    input  wire clk,
    input  wire rst_n
);

    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;
    wire [1:0] R, G, B;

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;

    wire _unused = &{ena, uio_in, ui_in[7:4]};

    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // The game uses a 200x100 logical screen.
    // The VGA timing below is 400x200 visible pixels, so each
    // logical pixel becomes a 2x2 block on the output.
    wire [7:0] game_x = pix_x[8:1];
    wire [6:0] game_y = pix_y[7:1];

    // Four buttons:
    // Menu: button 0 = up, 1 = down, 2 = select, 3 = back.
    // Pong: button 0/1 = left paddle up/down,
    //       button 2/3 = right paddle up/down.
    wire button0 = ui_in[0];
    wire button1 = ui_in[1];
    wire button2 = ui_in[2];
    wire button3 = ui_in[3];

    reg [19:0] game_counter;
    wire game_tick = (game_counter == 20'd0);

    always @(posedge clk) begin
        if (~rst_n)
            game_counter <= 0;
        else
            game_counter <= game_counter + 1'b1;
    end

    reg [1:0] selected_game;
    reg playing;

    reg [7:0] ball_x;
    reg [6:0] ball_y;
    reg signed [1:0] ball_dx;
    reg signed [1:0] ball_dy;
    reg [6:0] paddle_a_y;
    reg [6:0] paddle_b_y;
    reg [1:0] status;

    // Menu/game state and Pong physics.
    always @(posedge clk) begin
        if (~rst_n) begin
            selected_game <= 0;
            playing <= 0;
            ball_x <= 100;
            ball_y <= 50;
            ball_dx <= 1;
            ball_dy <= 1;
            paddle_a_y <= 40;
            paddle_b_y <= 40;
            status <= 2'b00;
        end else if (game_tick) begin
            if (~playing) begin
                if (button0) begin
                    if (selected_game == 0)
                        selected_game <= 3;
                    else
                        selected_game <= selected_game - 1'b1;
                end else if (button1) begin
                    if (selected_game == 3)
                        selected_game <= 0;
                    else
                        selected_game <= selected_game + 1'b1;
                end else if (button2) begin
                    playing <= 1;
                    if (selected_game == 1) begin
                        ball_x <= 100;
                        ball_y <= 50;
                        ball_dx <= 1;
                        ball_dy <= 1;
                        paddle_a_y <= 40;
                        paddle_b_y <= 40;
                        status <= 2'b00;
                    end
                end
            end else if (button3) begin
                playing <= 0;
            end else if (selected_game == 1 && status == 2'b00) begin
                if (button0 && paddle_a_y > 0)
                    paddle_a_y <= paddle_a_y - 1'b1;
                else if (button1 && paddle_a_y < 80)
                    paddle_a_y <= paddle_a_y + 1'b1;

                if (button2 && paddle_b_y > 0)
                    paddle_b_y <= paddle_b_y - 1'b1;
                else if (button3 && paddle_b_y < 80)
                    paddle_b_y <= paddle_b_y + 1'b1;

                ball_x <= ball_x + ball_dx;
                ball_y <= ball_y + ball_dy;

                if (ball_y <= 1)
                    ball_dy <= 1;
                else if (ball_y >= 98)
                    ball_dy <= -1;

                if (ball_x <= 5) begin
                    if ((ball_y >= paddle_a_y) && (ball_y <= paddle_a_y + 20))
                        ball_dx <= 1;
                    else
                        status <= 2'b11;
                end

                if (ball_x >= 194) begin
                    if ((ball_y >= paddle_b_y) && (ball_y <= paddle_b_y + 20))
                        ball_dx <= -1;
                    else
                        status <= 2'b10;
                end
            end
        end
    end

    reg pixel_on;

    // Pixel renderer. It answers: "is this current pixel part of an object?"
    always @(*) begin
        pixel_on = 1'b0;

        if (~playing) begin
            // Four menu entries.
            if ((game_y >= 10) && (game_y < 25) && (game_x >= 30) && (game_x < 170))
                pixel_on = 1'b1;
            if ((game_y >= 30) && (game_y < 45) && (game_x >= 30) && (game_x < 170))
                pixel_on = 1'b1;
            if ((game_y >= 50) && (game_y < 65) && (game_x >= 30) && (game_x < 170))
                pixel_on = 1'b1;
            if ((game_y >= 70) && (game_y < 85) && (game_x >= 30) && (game_x < 170))
                pixel_on = 1'b1;

            // Selection cursor.
            if ((game_x >= 15) && (game_x < 23)) begin
                if ((selected_game == 0) && (game_y >= 14) && (game_y < 21)) pixel_on = 1'b1;
                if ((selected_game == 1) && (game_y >= 34) && (game_y < 41)) pixel_on = 1'b1;
                if ((selected_game == 2) && (game_y >= 54) && (game_y < 61)) pixel_on = 1'b1;
                if ((selected_game == 3) && (game_y >= 74) && (game_y < 81)) pixel_on = 1'b1;
            end
        end else if (selected_game == 1) begin
            // Pong paddles and ball.
            if ((game_x < 5) && (game_y >= paddle_a_y) && (game_y < paddle_a_y + 20))
                pixel_on = 1'b1;
            if ((game_x >= 195) && (game_y >= paddle_b_y) && (game_y < paddle_b_y + 20))
                pixel_on = 1'b1;
            if ((game_x >= ball_x - 2) && (game_x <= ball_x + 2) &&
                (game_y >= ball_y - 2) && (game_y <= ball_y + 2))
                pixel_on = 1'b1;
            if ((game_x == 99 || game_x == 100) && ((game_y & 3) != 0))
                pixel_on = 1'b1;
        end else if (selected_game == 0) begin
            // Snake placeholder: play-field border.
            if ((game_x == 0) || (game_x == 199) || (game_y == 0) || (game_y == 99))
                pixel_on = 1'b1;
        end else if (selected_game == 2) begin
            // Space Invaders placeholder: player block.
            if ((game_x >= 95) && (game_x < 105) && (game_y >= 85) && (game_y < 90))
                pixel_on = 1'b1;
        end
        // selected_game == 3 is intentionally empty.
    end

    assign R = (video_active && pixel_on) ? 2'b11 : 2'b00;
    assign G = (video_active && pixel_on) ? 2'b11 : 2'b00;
    assign B = (video_active && pixel_on) ? 2'b11 : 2'b00;

endmodule


// 400x200 visible-pixel VGA timing generator.
// This is intentionally self-contained so the project does not depend
// on another Verilog source file for the VGA timing.
module hvsync_generator (
    input wire clk,
    input wire reset,
    output reg hsync,
    output reg vsync,
    output wire display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);
    localparam H_VISIBLE = 400;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam V_VISIBLE = 200;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    reg [9:0] h_count;
    reg [9:0] v_count;

    assign hpos = h_count;
    assign vpos = v_count;
    assign display_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    always @(posedge clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
            hsync <= 1'b1;
            vsync <= 1'b1;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end

            hsync <= !((h_count >= H_VISIBLE + H_FRONT) &&
                        (h_count < H_VISIBLE + H_FRONT + H_SYNC));
            vsync <= !((v_count >= V_VISIBLE + V_FRONT) &&
                        (v_count < V_VISIBLE + V_FRONT + V_SYNC));
        end
    end
endmodule
