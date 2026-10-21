`timescale 1ns / 1ps

module mic_i2s_clock (
    input  wire clk,
    input  wire resetn,

    output reg  mic_bclk,
    output reg  mic_ws
);

    // 4 位计数器，计数范围为 0 到 15
    reg [3:0] div_cnt;

    // 统计一个声道时隙内的 32 个位时钟周期
    reg [4:0] slot_cnt;

    always @(posedge clk) begin
        if (!resetn) begin
            div_cnt  <= 4'd0;
            slot_cnt <= 5'd0;
            mic_bclk <= 1'b0;
            mic_ws   <= 1'b0;
        end
        else begin
            if (div_cnt == 4'd15) begin
                div_cnt  <= 4'd0;
                mic_bclk <= ~mic_bclk;

                // 旧值为 1，表示本次 BCLK 将从 1 变成 0
                if (mic_bclk == 1'b1) begin
                    if (slot_cnt == 5'd31) begin
                        slot_cnt <= 5'd0;
                        mic_ws   <= ~mic_ws;
                    end
                    else begin
                        slot_cnt <= slot_cnt + 5'd1;
                    end
                end
            end
            else begin
                div_cnt <= div_cnt + 4'd1;
            end
        end
    end

endmodule