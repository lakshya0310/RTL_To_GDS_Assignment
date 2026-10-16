`timescale 1ns / 1ps

module tb_mult;

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    integer ia, ib;
    integer errors;
    integer checked;
    reg [7:0] expected;

    // Instantiate the Unit Under Test (UUT)
    mult_array uut (
        .clk   (clk),
        .rst_n (rst_n),
        .a     (a),
        .b     (b),
        .p     (p)
    );

    // Generate clock with 10 ns period (5 ns high, 5 ns low)
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Main stimulus and verification block
    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);

        errors  = 0;
        checked = 0;
        a       = 4'd0;
        b       = 4'd0;
        rst_n   = 1'b0;

        // Hold rst_n low for the first 2 clock cycles
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Apply all 256 combinations (a = 0..15, b = 0..15)
        for (ia = 0; ia < 16; ia = ia + 1) begin
            for (ib = 0; ib < 16; ib = ib + 1) begin
                a = ia[3:0];
                b = ib[3:0];
                expected = ia * ib;

                // Edge 1: inputs a and b are captured into a_reg, b_reg
                @(posedge clk);
                // Edge 2: product is captured into output register p
                @(posedge clk);
                // Wait 2 ns after Edge 2 so both RTL and Part B #1 unit-delay GLS settle
                #2;

                checked = checked + 1;
                if (p !== expected) begin
                    $display("MISMATCH: a=%0d (0x%0h), b=%0d (0x%0h) | expected p=%0d (0x%02h), got p=%0d (0x%02h) at time %0t",
                             a, a, b, b, expected, expected, p, p, $time);
                    errors = errors + 1;
                end

                // Align to negative edge before driving the next input vector
                @(negedge clk);
            end
        end

        // Print exact summary line required by Part A
        if (errors == 0) begin
            $display("PASS: %0d vectors checked, 0 errors", checked);
        end else begin
            $display("FAIL: %0d vectors checked, %0d errors", checked, errors);
        end

        #10;
        $finish;
    end

endmodule
