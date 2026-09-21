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

    // One 10-bit coordinate per stored snake position: {x,y}.
    // history[0] is the head, history[31] is the oldest position.
    reg [9:0] history [0:31];
    reg [1:0] dir;
    reg left_armed, right_armed;
    reg [15:0] lfsr;

    // Keep procedural loop indices local to the process that uses them.
    // Sharing one integer between combinational and clocked always blocks
    // makes it a multi-driven 32-bit RTL signal in synthesis.
    integer collision_i;
    integer history_i;

    genvar g;
    generate
        for (g=0; g<MAX_LEN; g=g+1) begin : BODY_OUT
            assign body_x[g*5 +: 5] = history[g][9:5];
            assign body_y[g*5 +: 5] = history[g][4:0];
        end
    endgenerate

    wire [4:0] head_x = history[0][9:5];
    wire [4:0] head_y = history[0][4:0];

    reg [1:0] next_dir;
    reg [4:0] next_head_x, next_head_y;
    reg self_collision;

    always @(*) begin
        next_dir=dir;
        if (button_left && left_armed && dir!=DIR_RIGHT)
            next_dir=dir-2'd1;
        else if (button_right && right_armed && dir!=DIR_LEFT)
            next_dir=dir+2'd1;
    end

    // Movement uses the current direction; a turn applies to the following move.
    always @(*) begin
        next_head_x=head_x;
        next_head_y=head_y;
        case(dir)
            DIR_UP:    next_head_y=head_y-5'd1;
            DIR_RIGHT: next_head_x=head_x+5'd1;
            DIR_DOWN:  next_head_y=head_y+5'd1;
            default:   next_head_x=head_x-5'd1;
        endcase
    end

    // New head compared with the previous 31 body positions.
    always @(*) begin
        self_collision=1'b0;
        for(collision_i=1;collision_i<MAX_LEN;collision_i=collision_i+1) begin
            if((collision_i<length) && ({next_head_x,next_head_y}==history[collision_i]))
                self_collision=1'b1;
        end
    end

    always @(posedge clk) begin
        if(reset) begin
            status<=2'b00;
            length<=6'd5;
            dir<=DIR_RIGHT;
            left_armed<=1'b1;
            right_armed<=1'b1;
            lfsr<=16'h1ACE;
            food_x<=5'd25;
            food_y<=5'd10;

            history[0]<={5'd20,5'd10};
            history[1]<={5'd19,5'd10};
            history[2]<={5'd18,5'd10};
            history[3]<={5'd17,5'd10};
            history[4]<={5'd16,5'd10};
            for(history_i=5;history_i<MAX_LEN;history_i=history_i+1)
                history[history_i]<=10'd0;
        end else begin
            // A held button turns only once. Release re-arms it.
            if(!button_left) left_armed<=1'b1;
            if(!button_right) right_armed<=1'b1;

            if(tick && status==2'b00) begin
                if(button_left && left_armed && dir!=DIR_RIGHT)
                    left_armed<=1'b0;
                if(button_right && right_armed && dir!=DIR_LEFT)
                    right_armed<=1'b0;

                if((dir==DIR_UP && head_y==5'd0) ||
                   (dir==DIR_RIGHT && head_x==5'd39) ||
                   (dir==DIR_DOWN && head_y==5'd19) ||
                   (dir==DIR_LEFT && head_x==5'd0)) begin
                    status<=2'b01;
                end else if(self_collision) begin
                    status<=2'b01;
                end else begin
                    for(history_i=MAX_LEN-1;history_i>0;history_i=history_i-1) begin
                        if(history_i<length)
                            history[history_i]<=history[history_i-1];
                    end
                    history[0]<={next_head_x,next_head_y};
                    dir<=next_dir;

                    if((next_head_x==food_x)&&(next_head_y==food_y)) begin
                        if(length<6'd32)
                            length<=length+1'b1;
                        lfsr<={lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};
                        if(lfsr[5:0]<6'd40) food_x<=lfsr[4:0];
                        else food_x<=5'd0;
                        if(lfsr[10:6]<5'd20) food_y<=lfsr[10:6];
                        else food_y<=5'd0;
                    end
                end
            end
        end
    end
endmodule
