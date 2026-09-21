`default_nettype none

module snake_game #(
    parameter MAX_LEN = 16,   // must be a power of two (index math below relies on wraparound)
    parameter PTR_W   = 4     // log2(MAX_LEN)
) (
    input wire clk,
    input wire reset,
    input wire button_left,
    input wire button_right,
    input wire tick,
    output reg [1:0] status,
    output reg [4:0] length,
    output reg [5:0] food_x,
    output reg [4:0] food_y,
    output wire [MAX_LEN*6-1:0] body_x,
    output wire [MAX_LEN*5-1:0] body_y
);
    localparam DIR_UP=2'd0, DIR_RIGHT=2'd1, DIR_DOWN=2'd2, DIR_LEFT=2'd3;

    // Circular buffer: history[head_ptr] is always the current head.
    // Logical slot i (0 = head, 1 = next segment, ...) lives at physical
    // index (head_ptr - i), which wraps automatically because head_ptr and
    // g are both PTR_W-bit and MAX_LEN is a power of two.
    // Each entry packs {x[5:0], y[4:0]} -- x needs 6 bits (playfield is
    // 40 cells wide, 0-39), y needs 5 bits (playfield is 20 cells tall, 0-19).
    reg  [10:0] history [0:MAX_LEN-1];
    reg  [PTR_W-1:0] head_ptr;
    reg  [1:0] dir;
    reg  left_armed, right_armed;
    reg  [15:0] lfsr;
    integer i;

    wire [5:0] head_x = history[head_ptr][10:5];
    wire [4:0] head_y = history[head_ptr][4:0];

    // Address-based read: one small subtractor per slot instead of the
    // old approach of physically copying every slot on every move.
    wire [PTR_W-1:0] rd_idx [0:MAX_LEN-1];
    genvar g;
    generate
        for (g = 0; g < MAX_LEN; g = g + 1) begin : UNPACK
            assign rd_idx[g] = head_ptr - g[PTR_W-1:0];
            assign body_x[g*6 +: 6] = history[rd_idx[g]][10:5];
            assign body_y[g*5 +: 5] = history[rd_idx[g]][4:0];
        end
    endgenerate

    reg [1:0] next_dir;
    reg [5:0] next_head_x;
    reg [4:0] next_head_y;
    reg self_collision;

    // dir +/- 1 is always a 90-degree turn in this UP->RIGHT->DOWN->LEFT
    // ordering, so it can never be an instant reversal -- no direction
    // needs to be excluded here.
    always @(*) begin
        next_dir = dir;
        if (button_left && left_armed)
            next_dir = dir - 2'd1;
        else if (button_right && right_armed)
            next_dir = dir + 2'd1;
    end

    // Movement uses the current direction; a turn applies to the following move.
    always @(*) begin
        next_head_x = head_x;
        next_head_y = head_y;
        case (dir)
            DIR_UP:    next_head_y = head_y - 5'd1;
            DIR_RIGHT: next_head_x = head_x + 6'd1;
            DIR_DOWN:  next_head_y = head_y + 5'd1;
            default:   next_head_x = head_x - 6'd1;
        endcase
    end

    // New head compared with the previous (length-1) body positions.
    always @(*) begin
        self_collision = 1'b0;
        for (i = 1; i < MAX_LEN; i = i + 1) begin
            if ((i < length) && ({next_head_x, next_head_y} == history[rd_idx[i]]))
                self_collision = 1'b1;
        end
    end

    wire [PTR_W-1:0] next_ptr = head_ptr + 1'b1;

    always @(posedge clk) begin
        if (reset) begin
            status <= 2'b00;
            length <= 5'd5;
            dir <= DIR_RIGHT;
            left_armed <= 1'b1;
            right_armed <= 1'b1;
            lfsr <= 16'h1ACE;
            food_x <= 6'd25;
            food_y <= 5'd10;
            head_ptr <= {PTR_W{1'b0}};

            history[0] <= {6'd20, 5'd10};
            history[1] <= {6'd19, 5'd10};
            history[2] <= {6'd18, 5'd10};
            history[3] <= {6'd17, 5'd10};
            history[4] <= {6'd16, 5'd10};
            for (i = 5; i < MAX_LEN; i = i + 1)
                history[i] <= 11'd0;
        end else begin
            // A held button turns only once. Release re-arms it.
            if (!button_left)  left_armed  <= 1'b1;
            if (!button_right) right_armed <= 1'b1;

            if (tick && status == 2'b00) begin
                if (button_left && left_armed)
                    left_armed <= 1'b0;
                if (button_right && right_armed)
                    right_armed <= 1'b0;

                if ((dir == DIR_UP    && head_y == 5'd0)  ||
                    (dir == DIR_RIGHT && head_x == 6'd39) ||
                    (dir == DIR_DOWN  && head_y == 5'd19) ||
                    (dir == DIR_LEFT  && head_x == 6'd0)) begin
                    status <= 2'b01;
                end else if (self_collision) begin
                    status <= 2'b01;
                end else begin
                    head_ptr <= next_ptr;
                    history[next_ptr] <= {next_head_x, next_head_y};
                    dir <= next_dir;

                    if ((next_head_x == food_x) && (next_head_y == food_y)) begin
                        if (length < MAX_LEN[4:0])
                            length <= length + 1'b1;
                        lfsr <= {lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
                        if (lfsr[5:0]  < 6'd40) food_x <= lfsr[5:0];  else food_x <= 6'd0;
                        if (lfsr[10:6] < 5'd20) food_y <= lfsr[10:6]; else food_y <= 5'd0;
                    end
                end
            end
        end
    end
endmodule
