`timescale 1ns/1ps

module tb_data_proc;

    parameter FIFO_BITS = 16;
    parameter WIDTH     = 32;


    reg clk_in;
    reg clk_out;
    reg rstn;

    reg  [7:0] pixel_in;
    reg        valid_in;
    wire       ready_in;

    wire [7:0] pixel_out;
    wire       valid_out;
    reg        ready_out;

    reg  [1:0]  mode;
    reg  [71:0] kernel;
    wire [31:0] status;

    integer i;

    data_proc #(FIFO_BITS, WIDTH) dut (
        .clk_in(clk_in),
        .clk_out(clk_out),
        .rstn(rstn),
        .pixel_in(pixel_in),
        .valid_in(valid_in),
        .ready_in(ready_in),
        .pixel_out(pixel_out),
        .valid_out(valid_out),
        .ready_out(ready_out),
        .mode(mode),
        .kernel(kernel),
        .status(status)
    );

  
    // clock
  
    initial begin
        clk_in = 0;
        forever #5 clk_in = ~clk_in;   // 100 MHz
    end

    initial begin
        clk_out = 0;
        forever #7 clk_out = ~clk_out; // async 
    end

  
    initial begin
        $dumpfile("iris2.vcd");
        $dumpvars(0, tb_data_proc);
    end

  
  
    initial begin

        // Initial values
        rstn       = 0;
        pixel_in   = 0;
        valid_in   = 0;
        ready_out  = 1;
        mode       = 2'b00;
        kernel     = 0;

        // reset
        #50;
        rstn = 1;


        // bypass

		$display("bypass");
        mode = 2'b00;

        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk_in);
            if (ready_in) begin
                pixel_in <= i;
                valid_in <= 1;
            end
        end

        @(posedge clk_in);
        valid_in <= 0;

        #500;


        // invert

		$display("inversion");
        mode = 2'b01;

        for (i = 0; i < 20; i = i + 1) begin
            @(posedge clk_in);
            if (ready_in) begin
                pixel_in <= i;
                valid_in <= 1;
            end
        end

        @(posedge clk_in);
        valid_in <= 0;

        #500;


        // convolution
  
		$display("convolution");
        mode = 2'b10;

  
        kernel = {
            8'd1,8'd1,8'd1,
            8'd1,8'd1,8'd1,
            8'd1,8'd1,8'd1
        };

        for (i = 0; i < 64; i = i + 1) begin
            @(posedge clk_in);
            if (ready_in) begin
                pixel_in <= i;
                valid_in <= 1;
            end
        end

        @(posedge clk_in);
        valid_in <= 0;

        #2000;

        $display("Simulation Finished");
        $finish;
    end

    always @(posedge clk_out) begin
        if (valid_out) begin
            $display("Time=%0t | Mode=%0d | Output Pixel=%0d",
                      $time, mode, pixel_out);
        end
    end

endmodule
