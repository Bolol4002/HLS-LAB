`timescale 1ns/1ps

module tb_adder;

    reg clock;
    reg reset;
    reg start_port;

    reg [31:0] a;
    reg [31:0] b;

    wire done_port;
    wire [31:0] return_port;

    adder dut (
        .clock(clock),
        .reset(reset),
        .start_port(start_port),
        .a(a),
        .b(b),
        .done_port(done_port),
        .return_port(return_port)
    );

    // 100 MHz clock
    always #5 clock = ~clock;

    initial begin

        clock = 0;
        reset = 0;
        start_port = 0;
        a = 0;
        b = 0;

        // Reset
        #20;
        reset = 1;

        // Apply inputs
        a = 10;
        b = 20;

        // Start
        start_port = 1;

        // Wait for completion
        #1;

        $display("START: a=%0d b=%0d done=%b result=%0d",
                 a, b, done_port, return_port);

        if (done_port !== 1'b1)
            $display("ERROR: done_port should be 1!");

        if (return_port !== 32'd30)
            $display("ERROR: expected 30, got %0d", return_port);
        else
            $display("PASS: 10 + 20 = %0d", return_port);

        // Deassert start
        #9;
        start_port = 0;

        #10;

        $finish;
    end

endmodule
