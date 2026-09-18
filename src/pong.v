module new_module (
    input buttondown,
    input buttonup,
    input buttondown_left,
    input buttonup_left,
    input clk,

    output reg [15:0] coordinate_a_y,
    output reg [15:0] coordinate_b_y,

    input reset,
    input [15:0] ball_x,
    input [15:0] ball_y,

    output reg bounce,
    output reg [1:0] status
);

    always @(posedge clk) begin
        // Bounce is a one-clock signal
        bounce <= 0;

        if (reset) begin
            coordinate_a_y <= 150;
            coordinate_b_y <= 150;
            status <= 2'b00;
        end

        else if (status == 2'b00) begin

            // Player A
            if (buttonup)
                coordinate_a_y <= coordinate_a_y + 3;
            else if (buttondown)
                coordinate_a_y <= coordinate_a_y - 3;

            // Player B
            if (buttonup_left)
                coordinate_b_y <= coordinate_b_y + 3;
            else if (buttondown_left)
                coordinate_b_y <= coordinate_b_y - 3;

            // Right paddle
            if (ball_x > 180) begin
                if ((ball_y > coordinate_a_y - 15) &&
                    (ball_y < coordinate_a_y + 15))
                    bounce <= 1;
                else
                    status <= 2'b10;
            end

            // Left paddle
            if (ball_x < 20) begin
                if ((ball_y > coordinate_b_y - 15) &&
                    (ball_y < coordinate_b_y + 15))
                    bounce <= 1;
                else
                    status <= 2'b11;
            end

        end
    end

endmodule
