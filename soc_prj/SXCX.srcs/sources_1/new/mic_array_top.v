`timescale 1ns / 1ps

// 100 MHz clk -> 3.125 MHz BCLK -> 48828.125 seven-channel frames/second.
// All seven outputs change atomically; consume them only when frame_valid=1.
module mic_array_top (
    input wire clk,
    input wire resetn,
    input wire [3:0] mic_data,
    output wire mic_bclk,
    output wire mic_ws,
    output reg signed [23:0] sample0,
    output reg signed [23:0] sample1,
    output reg signed [23:0] sample2,
    output reg signed [23:0] sample3,
    output reg signed [23:0] sample4,
    output reg signed [23:0] sample5,
    output reg signed [23:0] sample6,
    output reg frame_valid,
    output reg sync_error
);
    wire [23:0] lane_left [0:3];
    wire [23:0] lane_right [0:3];
    wire [3:0] lane_valid;

    // One shared clock generator; never use four independent BCLK generators.
    mic_i2s_clock u_clock (
        .clk(clk), .resetn(resetn), .mic_bclk(mic_bclk), .mic_ws(mic_ws)
    );

    genvar lane;
    generate
        for (lane = 0; lane < 4; lane = lane + 1) begin : g_lane
            i2s_rx_pair u_receiver (
                .clk(clk), .resetn(resetn), .mic_bclk(mic_bclk), .mic_ws(mic_ws),
                .mic_data(mic_data[lane]), .left_sample(lane_left[lane]),
                .right_sample(lane_right[lane]), .pair_valid(lane_valid[lane])
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (!resetn) begin
            sample0 <= 24'sd0;
            sample1 <= 24'sd0;
            sample2 <= 24'sd0;
            sample3 <= 24'sd0;
            sample4 <= 24'sd0;
            sample5 <= 24'sd0;
            sample6 <= 24'sd0;
            frame_valid <= 1'b0;
            sync_error <= 1'b0;
        end else begin
            frame_valid <= 1'b0;
            if (|lane_valid) begin
                if ((&lane_valid) && !sync_error) begin
                    sample0 <= lane_left[0];
                    sample1 <= lane_right[0];
                    sample2 <= lane_left[1];
                    sample3 <= lane_right[1];
                    sample4 <= lane_left[2];
                    sample5 <= lane_right[2];
                    sample6 <= lane_right[3]; // D3 LEFT is unused, possibly Hi-Z.
                    frame_valid <= 1'b1;
                end else begin
                    // Sticky control-alignment fault; reset is required to resume.
                    // This is NOT an unplugged-microphone or sound-quality detector.
                    sync_error <= 1'b1;
                end
            end
        end
    end
endmodule
