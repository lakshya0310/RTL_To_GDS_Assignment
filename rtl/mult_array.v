`timescale 1ns / 1ps

module mult_array (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  [7:0] p
);

    // Input registers (8 flip-flops)
    reg [3:0] a_reg;
    reg [3:0] b_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_reg <= 4'b0000;
            b_reg <= 4'b0000;
        end else begin
            a_reg <= a;
            b_reg <= b;
        end
    end

    // 16 AND gates for partial products: pp[i][j] = a_reg[j] & b_reg[i]
    wire [3:0] pp [0:3];
    genvar i, j;
    generate
        for (i = 0; i < 4; i = i + 1) begin : gen_pp_row
            for (j = 0; j < 4; j = j + 1) begin : gen_pp_col
                assign pp[i][j] = a_reg[j] & b_reg[i];
            end
        end
    endgenerate

    // Inter-row signals and full adder wires matching Section 2 table
    wire [3:0] r0, r1, r2;
    wire [3:0] s1, s2, s3;
    wire [4:0] c1, c2, c3;
    wire [7:0] prod_comb;

    // Row 0: no adders
    assign prod_comb[0] = pp[0][0];
    assign r0           = {1'b0, pp[0][3], pp[0][2], pp[0][1]};

    // Carry-in ties for rows 1, 2, 3
    assign c1[0] = 1'b0;
    assign c2[0] = 1'b0;
    assign c3[0] = 1'b0;

    // Rows 1, 2, and 3: 4 full adders each (12 instances of full_adder total)
    generate
        for (j = 0; j < 4; j = j + 1) begin : gen_fa_cols
            // Row 1 full adders
            full_adder fa_row1 (
                .a    (pp[1][j]),
                .b    (r0[j]),
                .cin  (c1[j]),
                .sum  (s1[j]),
                .cout (c1[j+1])
            );

            // Row 2 full adders
            full_adder fa_row2 (
                .a    (pp[2][j]),
                .b    (r1[j]),
                .cin  (c2[j]),
                .sum  (s2[j]),
                .cout (c2[j+1])
            );

            // Row 3 full adders
            full_adder fa_row3 (
                .a    (pp[3][j]),
                .b    (r2[j]),
                .cin  (c3[j]),
                .sum  (s3[j]),
                .cout (c3[j+1])
            );
        end
    endgenerate

    // Row 1 and Row 2 outputs passed down
    assign prod_comb[1] = s1[0];
    assign r1           = {c1[4], s1[3], s1[2], s1[1]};

    assign prod_comb[2] = s2[0];
    assign r2           = {c2[4], s2[3], s2[2], s2[1]};

    // Row 3 final product bits
    assign prod_comb[3]   = s3[0];
    assign prod_comb[7:4] = {c3[4], s3[3], s3[2], s3[1]};

    // Output register (8 flip-flops) -> Total 16 flip-flops, 2-cycle latency
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p <= 8'b0000_0000;
        end else begin
            p <= prod_comb;
        end
    end

endmodule
