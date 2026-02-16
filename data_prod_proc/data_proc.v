`timescale 1ns/1ps

module data_proc #(
    parameter FIFO_BITS = 16,
    parameter width     = 32
)(
    input  clk_in,
    input  clk_out,
    input  rstn,

    // input
    input  [7:0] pixel_in,
    input        valid_in,
    output       ready_in,

    // output
    output reg [7:0] pixel_out,
    output reg       valid_out,
    input            ready_out,

    // control
    input  [1:0]  mode,       
    input  [71:0] kernel,
    output reg [31:0] status
);


reg [7:0] memory [0:FIFO_BITS-1];

reg [4:0] wptr_bin, rptr_bin;
reg [4:0] wptr_gray, rptr_gray;
reg [4:0] rptr_gray1, rptr_gray2;
reg [4:0] wptr_gray1, wptr_gray2;

wire full, empty;
reg  [7:0] fifo_data;

 //binry-gray conversions

function [4:0] bin2gray;
    input [4:0] bin;
    bin2gray = (bin >> 1) ^ bin;
endfunction

function [4:0] gray2bin;
    input [4:0] gray;
    integer j;
    begin
        gray2bin[4] = gray[4];
        for (j=3; j>=0; j=j-1)
            gray2bin[j] = gray2bin[j+1] ^ gray[j];
    end
endfunction


 //write block

assign ready_in = !full;

always @(posedge clk_in or negedge rstn) begin
    if (!rstn) begin
        wptr_bin  <= 0;
        wptr_gray <= 0;
    end
    else if (valid_in && !full) begin
        memory[wptr_bin[3:0]] <= pixel_in;
        wptr_bin  <= wptr_bin + 1;
        wptr_gray <= bin2gray(wptr_bin + 1);
    end
end

// read block

always @(posedge clk_out or negedge rstn) begin
    if (!rstn) begin
        rptr_bin  <= 0;
        rptr_gray <= 0;
        fifo_data <= 0;
    end
    else if (!empty && ready_out) begin
        fifo_data <= memory[rptr_bin[3:0]];
        rptr_bin  <= rptr_bin + 1;
        rptr_gray <= bin2gray(rptr_bin + 1);
    end
end

 //pointer sync using 2-flops to prevent metastabililty along with reset

always @(posedge clk_in or negedge rstn) begin
    if (!rstn) begin
        rptr_gray1 <= 0;
        rptr_gray2 <= 0;
    end else begin
        rptr_gray1 <= rptr_gray;
        rptr_gray2 <= rptr_gray1;
    end
end

always @(posedge clk_out or negedge rstn) begin
    if (!rstn) begin
        wptr_gray1 <= 0;
        wptr_gray2 <= 0;
    end else begin
        wptr_gray1 <= wptr_gray;
        wptr_gray2 <= wptr_gray1;
    end
end


assign empty = (rptr_gray == wptr_gray2);

assign full  =
    (wptr_gray == {~rptr_gray2[4:3],
                    rptr_gray2[2:0]});


// line buffers


reg [7:0] linebuf1 [0:31];
reg [7:0] linebuf2 [0:31];
reg [4:0] col;


reg signed [7:0] w0,w1,w2,
          w3,w4,w5,
          w6,w7,w8;


 //signed kernel considering it could also be negative


wire signed [7:0] k0 = kernel[7:0];
wire signed [7:0] k1 = kernel[15:8];
wire signed [7:0] k2 = kernel[23:16];
wire signed [7:0] k3 = kernel[31:24];
wire signed [7:0] k4 = kernel[39:32];
wire signed [7:0] k5 = kernel[47:40];
wire signed [7:0] k6 = kernel[55:48];
wire signed [7:0] k7 = kernel[63:56];
wire signed [7:0] k8 = kernel[71:64];

reg signed [15:0] sum;
integer i;
    
//mode control


always @(posedge clk_out or negedge rstn) begin
    if (!rstn) begin
        col       <= 0;
        valid_out <= 0;
        pixel_out <= 0;
        status    <= 0;
        sum       <= 0;
        
        w0 <= 0; w1 <= 0; w2 <= 0;
        w3 <= 0; w4 <= 0; w5 <= 0;
        w6 <= 0; w7 <= 0; w8 <= 0;
        
        for (i = 0; i < 32; i = i + 1) begin
            linebuf1[i] <= 0;
            linebuf2[i] <= 0;
        end
    end
    else begin

        case (mode)
            
        //bypass
        2'b00: begin
            if (!empty && ready_out) begin
                pixel_out <= fifo_data;
                valid_out <= 1'b1;
            end
            else
                valid_out <= 1'b0;
        end

        //inversion

        2'b01: begin
            if (!empty && ready_out) begin
                pixel_out <= ~fifo_data; 
                valid_out <= 1'b1;
            end
            else
                valid_out <= 1'b0;
        end

        //convolution

        2'b10: begin
            if (!empty && ready_out) begin

                w0 <= w1;  w1 <= w2;
                w3 <= w4;  w4 <= w5;
                w6 <= w7;  w7 <= w8;

                w2 <= linebuf2[col];
                w5 <= linebuf1[col];
                w8 <= fifo_data;

                linebuf2[col] <= linebuf1[col];
                linebuf1[col] <= fifo_data;

                col <= (col == 31) ? 0 : col + 1;
        
                sum <=  (w0 * k0) + (w1 *  k1) + (w2 *  k2) +
                        (w3 * k3) + (w4 *  k4) + (w5 *  k5) +
                        (w6 * k6) + (w7 *  k7) + (w8 *  k8);
                
                pixel_out <= sum[15:8]; 

                valid_out <= 1'b1;
        end
            else valid_out <= 1'b0;
        end

        // not implemented

        2'b11: begin
            valid_out <= 1'b0;
        end

        endcase

        // status register


        status[0] <= empty;
        status[1] <= full;
        status[3:2] <= mode;

    end
    
end
endmodule

    //Fill the rest of the signals


);

/* --------------------------------------------------------------------------
Purpose of this module : This module should perform certain operations
based on the mode register and pixel values streamed out by data_prod module.

mode[1:0]:
00 - Bypass
01 - Invert the pixel
10 - Convolution with a kernel of your choice (kernel is 3x3 2d array)
11 - Not implemented

Memory map of registers:

0x00 - Mode (2 bits)    [R/W]
0x04 - Kernel (9 * 8 = 72 bits)     [R/W]
0x10 - Status reg   [R]
----------------------------------------------------------------------------*/
