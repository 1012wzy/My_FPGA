`timescale 1ns / 1ps
module tb_mic_i2s_clock;
    reg clk = 0;
    reg resetn = 0;
    wire mic_bclk, mic_ws;
    integer bclk_edges = 0;
    integer falls = 0;
    integer ws_edges = 0;
    time last_bclk = 0;
    time last_ws = 0;
    mic_i2s_clock dut(clk, resetn, mic_bclk, mic_ws);
    always #5 clk = ~clk;
    always @(mic_bclk) begin
        #1;
        if (resetn) begin
            if (bclk_edges > 0 && $time-last_bclk != 160)
                $fatal(1,"BCLK half-period mismatch");
            last_bclk = $time;
            bclk_edges = bclk_edges + 1;
        end
    end
    always @(negedge mic_bclk) if (resetn) falls = falls + 1;
    always @(mic_ws) begin
        #1;
        if (resetn) begin
            if (mic_bclk !== 0 || falls != 32)
                $fatal(1,"WS edge alignment or slot length mismatch");
            if (ws_edges > 0 && $time-last_ws != 10240)
                $fatal(1,"WS half-period mismatch");
            last_ws = $time;
            ws_edges = ws_edges + 1;
            falls = 0;
        end
    end
    initial begin
        #6;
        if (mic_bclk !== 0 || mic_ws !== 0) $fatal(1,"Reset mismatch");
        #94 resetn = 1;
        #100000;
        if (bclk_edges < 600 || ws_edges != 9) $fatal(1,"Clock activity missing");
        $display("PASS: BCLK 320 ns, WS 20.48 us, 32 BCLK cycles per slot.");
        $finish;
    end
endmodule
