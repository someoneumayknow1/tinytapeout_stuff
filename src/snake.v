`default_nettype none

module snake_game #(
    parameter MAX_LEN = 32
) (
    input wire clk,
    input wire reset,
    input wire button_left,
    input wire button_right,
    input wire tick,
    output reg [1:0] status,
    output reg [5:0] length,
    output reg [4:0] food_x,
    output reg [4:0] food_y,
    output wire [MAX_LEN*5-1:0] body_x,
    output wire [MAX_LEN*5-1:0] body_y
);
    localparam DIR_UP=2'd0, DIR_RIGHT=2'd1, DIR_DOWN=2'd2, DIR_LEFT=2'd3;

    // Packed shift registers are much cheaper than 32 individually
    // conditionally-updated array registers.
    reg [MAX_LEN*5-1:0] snake_x;
    reg [MAX_LEN*5-1:0] snake_y;
    reg [1:0] dir;
    reg left_armed, right_armed;
    reg [15:0] lfsr;
    integer i;

    assign body_x = snake_x;
    assign body_y = snake_y;

    function [1:0] turn_left;
        input [1:0] d;
        begin turn_left=d-1'b1; end
    endfunction

    function [1:0] turn_right;
        input [1:0] d;
        begin turn_right=d+1'b1; end
    endfunction

    // The next head position is also the position used for self-collision.
    reg [4:0] next_head_x;
    reg [4:0] next_head_y;
    always @(*) begin
        next_head_x = snake_x[4:0];
        next_head_y = snake_y[4:0];
        case(dir)
            DIR_UP:    next_head_y = snake_y[4:0] - 5'd1;
            DIR_RIGHT: next_head_x = snake_x[4:0] + 5'd1;
            DIR_DOWN:  next_head_y = snake_y[4:0] + 5'd1;
            default:   next_head_x = snake_x[4:0] - 5'd1;
        endcase
    end

    always @(posedge clk) begin
        if(reset) begin
            status<=0;
            length<=6'd5;
            dir<=DIR_RIGHT;
            left_armed<=1;
            right_armed<=1;
            lfsr<=16'h1ACE;
            food_x<=5'd25;
            food_y<=5'd10;

            snake_x<=0;
            snake_y<=0;
            snake_x[4:0]<=5'd20;
            snake_x[9:5]<=5'd19;
            snake_x[14:10]<=5'd18;
            snake_x[19:15]<=5'd17;
            snake_x[24:20]<=5'd16;
            snake_y[4:0]<=5'd10;
            snake_y[9:5]<=5'd10;
            snake_y[14:10]<=5'd10;
            snake_y[19:15]<=5'd10;
            snake_y[24:20]<=5'd10;
        end else begin
            // A held button only turns once until that button is released.
            if(!button_left) left_armed<=1;
            if(!button_right) right_armed<=1;

            if(tick&&status==0) begin
                if(button_left&&left_armed&&dir!=DIR_RIGHT) begin
                    dir<=turn_left(dir);
                    left_armed<=0;
                end else if(button_right&&right_armed&&dir!=DIR_LEFT) begin
                    dir<=turn_right(dir);
                    right_armed<=0;
                end

                // Wall collision uses the current direction.
                if((dir==DIR_UP&&snake_y[4:0]==5'd0)||
                   (dir==DIR_RIGHT&&snake_x[4:0]==5'd39)||
                   (dir==DIR_DOWN&&snake_y[4:0]==5'd19)||
                   (dir==DIR_LEFT&&snake_x[4:0]==5'd0)) begin
                    status<=2'b01;
                end else begin
                    // One simple shift: old body positions move toward the tail.
                    // Unused tail positions can contain stale data; length decides
                    // which positions are live.
                    snake_x <= {snake_x[MAX_LEN*5-6:0],next_head_x};
                    snake_y <= {snake_y[MAX_LEN*5-6:0],next_head_y};

                    // Food is on the next head cell.
                    if(next_head_x==food_x && next_head_y==food_y) begin
                        if(length<6'd32) length<=length+1'b1;
                        lfsr<={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
                        if(lfsr[5:0]<6'd40) food_x<=lfsr[4:0]; else food_x<=5'd0;
                        if(lfsr[10:6]<5'd20) food_y<=lfsr[10:6]; else food_y<=5'd0;
                    end

                    // Only the new head checks the existing body.
                    for(i=1;i<MAX_LEN;i=i+1) begin
                        if((i<length) &&
                           (next_head_x==snake_x[i*5 +: 5]) &&
                           (next_head_y==snake_y[i*5 +: 5]))
                            status<=2'b01;
                    end
                end
            end
        end
    end
endmodule
