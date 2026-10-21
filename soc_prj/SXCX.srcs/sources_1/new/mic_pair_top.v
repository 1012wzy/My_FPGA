`timescale 1ns / 1ps

// Learning top: one serial data line, two audio channels.
module mic_pair_top (
    input wire clk,
    input wire resetn,
    input wire mic_data,
    output wire mic_bclk,
    output wire mic_ws,
    output wire signed [23:0] left_sample,
    output wire signed [23:0] right_sample,
    output wire pair_valid
);
    mic_i2s_clock u_clock (
        .clk(clk), .resetn(resetn), .mic_bclk(mic_bclk), .mic_ws(mic_ws)
    );
    i2s_rx_pair u_receiver (
        .clk(clk), .resetn(resetn), .mic_bclk(mic_bclk), .mic_ws(mic_ws),
        .mic_data(mic_data), .left_sample(left_sample),
        .right_sample(right_sample), .pair_valid(pair_valid)
    );
endmodule
