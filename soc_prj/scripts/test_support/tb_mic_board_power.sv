`timescale 1ns / 1ps
// Test the actual board top with its real default 100ms startup counter.
// Lightweight clock/debug models isolate power/capture integration from JTAG.
module tb_mic_board_power;
    reg clk = 0;
    always #5 clk = ~clk;
    wire bclk, ws, power_en;
    mic_board_top dut (.sys_clk_p(clk), .sys_clk_n(~clk), .mic_data(4'b0),
        .mic_bclk(bclk), .mic_ws(ws), .fep_power_en(power_en));
    integer edges = 0;
    always @(posedge bclk) begin
        if ($time < 100_000_000) $fatal(1,"BCLK started before 100ms power guard");
        edges = edges + 1;
    end
    task tick(input integer n);
        repeat(n) @(posedge clk);
        #1;
    endtask
    initial begin
        #1;
        if (power_en !== 1'b1) $fatal(1,"CEP 3V3 enable is not asserted");
        // Leave VIO at default zero through the complete power guard.
        tick(9_999_999);
        if (dut.u_control.startup_done !== 0 || dut.capture_resetn !== 0)
            $fatal(1,"Default 100ms guard released early");
        if (edges != 0 || bclk !== 0 || ws !== 0)
            $fatal(1,"Clock active before startup");
        tick(1);
        if (dut.u_control.startup_done !== 1 || dut.capture_resetn !== 0)
            $fatal(1,"100ms boundary or default VIO stop incorrect");
        tick(100);
        if (edges != 0) $fatal(1,"Capture started without operator enable");
        @(negedge clk); dut.u_vio.probe_out0 = 1;
        tick(1); if (dut.capture_resetn !== 0) $fatal(1,"Enable pipeline bypassed");
        tick(1); if (dut.capture_resetn !== 1) $fatal(1,"Enable did not release capture");
        tick(8192);
        if (edges == 0 || dut.frame_count < 2 || dut.sync_error !== 0)
            $fatal(1,"Board acquisition failed after power guard");
        @(negedge clk); dut.u_vio.probe_out0 = 0;
        tick(3);
        if (power_en !== 1 || bclk !== 0 || ws !== 0 || dut.frame_count !== 0)
            $fatal(1,"Stop must reset acquisition but keep CEP power on");
        @(negedge clk); dut.u_vio.probe_out0 = 1;
        tick(2); if (dut.capture_resetn !== 1 || power_en !== 1)
            $fatal(1,"Restart unexpectedly cycles power or repeats startup delay");
        $display("PASS: CEP power enabled; actual 100ms default guard; manual start; frames; stop preserves power; restart");
        $finish;
    end
    initial begin #101_000_000; $fatal(1,"Watchdog"); end
endmodule
