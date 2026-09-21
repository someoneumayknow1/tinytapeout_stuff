```verilog
`default_nettype none

module snake_game (
    input  wire       clk,
    input  wire       reset,

    // Four-button interface
    // 0 = not pressed, 1 = pressed
    input  wire       btn_up,
    input  wire       btn_down,
    input  wire       btn_left,
    input  wire       btn_right,

    // Logical 32x32 screen position
    input  wire [4:0] render_x,
    input  wire [4:0] render_y,

    output reg        pixel_on
);

    localparam DIR_UP    = 2'd0;
    localparam DIR_RIGHT = 2'd1;
    localparam DIR_DOWN  = 2'd2;
    localparam DIR_LEFT  = 2'd3;

    localparam MAX_LEN = 32;

    // One packed coordinate:
    // {x[4:0], y[4:0]}
    reg [9:0] history [0:31];

    reg [5:0] length;
    reg [1:0] dir;

    reg btn_up_old;
    reg btn_down_old;
    reg btn_left_old;
    reg btn_right_old;

    reg [4:0] food_x;
    reg [4:0] food_y;

    reg [15:0] move_counter;

    integer i;

    wire [4:0] head_x = history[0][9:5];
    wire [4:0] head_y = history[0][4:0];

    /*
     * A movement tick.
     *
     * This is intentionally slow enough to make the game playable
     * on a VGA clock.
     */
    wire move_tick = (move_counter == 16'd50000);

    /*
     * Direction changes happen only on a button's rising edge.
     *
     * Therefore:
     *
     * press RIGHT
     *     -> turn once
     *
     * hold RIGHT
     *     -> nothing else happens
     *
     * release RIGHT
     *     -> ready for another press
     */
    wire up_pressed =
        btn_up && !btn_up_old;

    wire down_pressed =
        btn_down && !btn_down_old;

    wire left_pressed =
        btn_left && !btn_left_old;

    wire right_pressed =
        btn_right && !btn_right_old;

    reg [1:0] next_dir;
    reg [4:0] next_x;
    reg [4:0] next_y;
    reg collision;

    /*
     * Calculate the next direction.
     *
     * 180-degree turns are forbidden.
     */
    always @* begin
        next_dir = dir;

        if (up_pressed && dir != DIR_DOWN)
            next_dir = DIR_UP;
        else if (right_pressed && dir != DIR_LEFT)
            next_dir = DIR_RIGHT;
        else if (down_pressed && dir != DIR_UP)
            next_dir = DIR_DOWN;
        else if (left_pressed && dir != DIR_RIGHT)
            next_dir = DIR_LEFT;
    end

    /*
     * Calculate the next head position.
     *
     * The 32x32 grid wraps around at the edges.
     */
    always @* begin
        next_x = head_x;
        next_y = head_y;

        case (next_dir)
            DIR_UP: begin
                if (head_y == 0)
                    next_y = 5'd31;
                else
                    next_y = head_y - 5'd1;
            end

            DIR_RIGHT: begin
                if (head_x == 5'd31)
                    next_x = 5'd0;
                else
                    next_x = head_x + 5'd1;
            end

            DIR_DOWN: begin
                if (head_y == 5'd31)
                    next_y = 5'd0;
                else
                    next_y = head_y + 5'd1;
            end

            DIR_LEFT: begin
                if (head_x == 0)
                    next_x = 5'd31;
                else
                    next_x = head_x - 5'd1;
            end
        endcase
    end

    /*
     * Self collision.
     *
     * This is the important simplification:
     *
     *       {next_x,next_y} == history[i]
     *
     * No distance calculations.
     * No geometry.
     * No separate X/Y collision system.
     */
    always @* begin
        collision = 1'b0;

        for (i = 0; i < 32; i = i + 1) begin
            if ((i < length) &&
                ({next_x, next_y} == history[i]))
                collision = 1'b1;
        end
    end

    /*
     * Game state.
     */
    always @(posedge clk) begin
        if (reset) begin
            history[0] <= {5'd16, 5'd16};
            history[1] <= {5'd15, 5'd16};
            history[2] <= {5'd14, 5'd16};
            history[3] <= {5'd13, 5'd16};

            length <= 6'd4;
            dir <= DIR_RIGHT;

            food_x <= 5'd24;
            food_y <= 5'd16;

            move_counter <= 16'd0;

            btn_up_old <= 1'b0;
            btn_down_old <= 1'b0;
            btn_left_old <= 1'b0;
            btn_right_old <= 1'b0;
        end
        else begin

            /*
             * Remember button state so a held button
             * doesn't repeatedly trigger turns.
             */
            btn_up_old <= btn_up;
            btn_down_old <= btn_down;
            btn_left_old <= btn_left;
            btn_right_old <= btn_right;

            /*
             * Movement clock.
             */
            if (move_tick) begin
                move_counter <= 16'd0;

                if (!collision) begin

                    /*
                     * Move the old body positions backwards.
                     *
                     * history[0] is always the head.
                     */
                    for (i = 31; i > 0; i = i - 1) begin
                        if (i < length)
                            history[i] <= history[i-1];
                    end

                    history[0] <= {next_x, next_y};

                    dir <= next_dir;

                    /*
                     * Eat food.
                     *
                     * The snake grows by one entry.
                     */
                    if ((next_x == food_x) &&
                        (next_y == food_y)) begin

                        if (length < MAX_LEN)
                            length <= length + 6'd1;

                        /*
                         * Simple deterministic food position.
                         * We can replace this with a tiny LFSR later
                         * if desired.
                         */
                        food_x <= food_x + 5'd7;
                        food_y <= food_y + 5'd11;
                    end
                end
                else begin
                    /*
                     * Collision = restart the snake.
                     */
                    history[0] <= {5'd16, 5'd16};
                    history[1] <= {5'd15, 5'd16};
                    history[2] <= {5'd14, 5'd16};
                    history[3] <= {5'd13, 5'd16};

                    length <= 6'd4;
                    dir <= DIR_RIGHT;
                end
            end
            else begin
                move_counter <= move_counter + 16'd1;
            end
        end
    end

    /*
     * GRAPHICS
     *
     * The renderer asks:
     *
     * "Is the current pixel's logical coordinate equal
     *  to one of the snake positions?"
     *
     * Same history array.
     * No second copy of the snake.
     */
    always @* begin
        pixel_on = 1'b0;

        if ((render_x == food_x) &&
            (render_y == food_y)) begin
            pixel_on = 1'b1;
        end
        else begin
            for (i = 0; i < 32; i = i + 1) begin
                if ((i < length) &&
                    (render_x == history[i][9:5]) &&
                    (render_y == history[i][4:0]))
                    pixel_on = 1'b1;
            end
        end
    end

endmodule
```
