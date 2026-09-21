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
    output reg [4:0] length,
    output reg [4:0] food_x,
    output reg [4:0] food_y,
    output wire [MAX_LEN*5-1:0] body_x,
    output wire [MAX_LEN*5-1:0] body_y
);
    localparam DIR_UP=2'd0, DIR_RIGHT=2'd1, DIR_DOWN=2'd2, DIR_LEFT=2'd3;
    reg [1:0] dir;
    reg [4:0] snake_x [0:MAX_LEN-1];
    reg [4:0] snake_y [0:MAX_LEN-1];
    reg left_armed, right_armed;
    reg [15:0] lfsr;
    integer i;

    genvar g;
    generate
        for(g=0;g<MAX_LEN;g=g+1) begin : PACK_BODY
            assign body_x[g*5 +: 5]=snake_x[g];
            assign body_y[g*5 +: 5]=snake_y[g];
        end
    endgenerate

    function [1:0] turn_left;
        input [1:0] d;
        begin turn_left=d-1'b1; end
    endfunction
    function [1:0] turn_right;
        input [1:0] d;
        begin turn_right=d+1'b1; end
    endfunction

    always @(posedge clk) begin
        if(reset) begin
            status<=0; length<=5; dir<=DIR_RIGHT;
            left_armed<=1; right_armed<=1; lfsr<=16'h1ACE;
            food_x<=25; food_y<=10;
            snake_x[0]<=20; snake_y[0]<=10;
            snake_x[1]<=19; snake_y[1]<=10;
            snake_x[2]<=18; snake_y[2]<=10;
            snake_x[3]<=17; snake_y[3]<=10;
            snake_x[4]<=16; snake_y[4]<=10;
            for(i=5;i<MAX_LEN;i=i+1) begin snake_x[i]<=0; snake_y[i]<=0; end
        end else begin
            // A press can turn once. The button must be released before
            // another turn can be made with that button.
            if(!button_left) left_armed<=1;
            if(!button_right) right_armed<=1;

            if(tick&&status==0) begin
                if(button_left&&left_armed&&dir!=DIR_RIGHT) begin dir<=turn_left(dir); left_armed<=0; end
                else if(button_right&&right_armed&&dir!=DIR_LEFT) begin dir<=turn_right(dir); right_armed<=0; end

                if((dir==DIR_UP&&snake_y[0]==0)||(dir==DIR_RIGHT&&snake_x[0]==39)||
                   (dir==DIR_DOWN&&snake_y[0]==19)||(dir==DIR_LEFT&&snake_x[0]==0)) begin
                    status<=2'b01;
                end else begin
                    // Shift the current body.
                    for(i=MAX_LEN-1;i>0;i=i-1) begin
                        if(i<length) begin snake_x[i]<=snake_x[i-1]; snake_y[i]<=snake_y[i-1]; end
                    end
                    case(dir)
                        DIR_UP: begin snake_x[0]<=snake_x[0]; snake_y[0]<=snake_y[0]-1'b1; end
                        DIR_RIGHT: begin snake_x[0]<=snake_x[0]+1'b1; snake_y[0]<=snake_y[0]; end
                        DIR_DOWN: begin snake_x[0]<=snake_x[0]; snake_y[0]<=snake_y[0]+1'b1; end
                        default: begin snake_x[0]<=snake_x[0]-1'b1; snake_y[0]<=snake_y[0]; end
                    endcase

                    // Food is on the next head cell.
                    if((dir==DIR_UP&&snake_x[0]==food_x&&snake_y[0]==food_y+1'b1)||
                       (dir==DIR_RIGHT&&snake_x[0]==food_x-1'b1&&snake_y[0]==food_y)||
                       (dir==DIR_DOWN&&snake_x[0]==food_x&&snake_y[0]==food_y-1'b1)||
                       (dir==DIR_LEFT&&snake_x[0]==food_x+1'b1&&snake_y[0]==food_y)) begin
                        if(length<5'd31) length<=length+1'b1;
                        lfsr<={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
                        if(lfsr[5:0]<40) food_x<=lfsr[4:0]; else food_x<=0;
                        if(lfsr[10:6]<20) food_y<=lfsr[10:6]; else food_y<=0;
                    end

                    // Self collision.
                    for(i=1;i<MAX_LEN;i=i+1) begin
                        if((i<length)&&(snake_x[0]==snake_x[i])&&(snake_y[0]==snake_y[i])) status<=2'b01;
                    end
                end
            end
        end
    end
endmodule
