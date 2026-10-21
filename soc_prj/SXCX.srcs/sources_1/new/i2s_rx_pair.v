`timescale 1ns / 1ps

// 24-bit I2S receiver; BCLK and WS come from the same clk-domain generator.
module i2s_rx_pair (
    input wire clk,
    input wire resetn,
    input wire mic_bclk,
    input wire mic_ws,
    input wire mic_data,
    output reg signed [23:0] left_sample,
    output reg signed [23:0] right_sample,
    output reg pair_valid
);
    (* ASYNC_REG = "TRUE" *) reg data_meta;
    (* ASYNC_REG = "TRUE" *) reg data_sync;
    reg bclk_d;
    reg ws_last;
    reg ws_initialized;
    reg slot_seen;
    reg [4:0] bit_cnt;
    reg [23:0] shift_reg;
    reg left_ready;
    wire bclk_rise = mic_bclk & ~bclk_d;

    // External data is sampled through two registers. Board timing still matters.
    always @(posedge clk) begin
        if (!resetn) begin
            data_meta <= 1'b0;
            data_sync <= 1'b0;
            bclk_d <= 1'b0;
        end else begin
            data_meta <= mic_data;
            data_sync <= data_meta;
            bclk_d <= mic_bclk;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            ws_last <= 1'b0;
            ws_initialized <= 1'b0;
            slot_seen <= 1'b0;
            bit_cnt <= 5'd0;
            shift_reg <= 24'd0;
        end else if (bclk_rise) begin
            ws_last <= mic_ws;
            if (!ws_initialized) begin
                // Learn the present WS level; do not invent a boundary at startup.
                ws_initialized <= 1'b1;
            end else if (mic_ws != ws_last) begin
                // This edge is the I2S delay bit; the NEXT edge carries the MSB.
                slot_seen <= 1'b1;
                bit_cnt <= 5'd0;
                shift_reg <= 24'd0;
            end else if (slot_seen && bit_cnt < 5'd24) begin
                shift_reg <= {shift_reg[22:0], data_sync};
                bit_cnt <= bit_cnt + 5'd1;
            end
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            left_sample <= 24'sd0;
            right_sample <= 24'sd0;
            pair_valid <= 1'b0;
            left_ready <= 1'b0;
        end else begin
            pair_valid <= 1'b0;
            if (bclk_rise && ws_initialized) begin
                if (mic_ws != ws_last) begin
                    if (!mic_ws) left_ready <= 1'b0;
                end else if (slot_seen && bit_cnt == 5'd23) begin
                    // Include the current LSB, not the previous shift_reg value.
                    if (!mic_ws) begin
                        left_sample <= {shift_reg[22:0], data_sync};
                        left_ready <= 1'b1;
                    end else begin
                        right_sample <= {shift_reg[22:0], data_sync};
                        pair_valid <= left_ready;
                        left_ready <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
