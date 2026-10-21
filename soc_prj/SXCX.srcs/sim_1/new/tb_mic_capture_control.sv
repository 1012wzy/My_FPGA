`timescale 1ns / 1ps
module tb_mic_capture_control;
    reg clk=0, enable=0;
    always #5 clk=~clk;
    wire resetn;
    mic_capture_control #(.STARTUP_CYCLES(16)) dut
        (.clk(clk), .capture_enable(enable), .resetn(resetn));
    integer cycles=0;
    always @(posedge clk) begin
        cycles=cycles+1;
        #1;
        if(cycles<16 && resetn) $fatal(1,"Early release during startup");
    end
    task tick(input integer n);
        repeat(n) begin @(posedge clk); #1; end
    endtask
    initial begin
        #2; enable=1;
        tick(15);
        if(resetn) $fatal(1,"Startup not held");
        tick(1);
        if(!resetn) $fatal(1,"Startup failed to release");
        @(negedge clk); enable=0;
        tick(1); if(!resetn) $fatal(1,"Missing first control pipeline stage");
        tick(1); if(resetn) $fatal(1,"Stop failed");
        tick(30); if(resetn) $fatal(1,"Stopped acquisition restarted");
        @(negedge clk); enable=1;
        tick(1); if(resetn) $fatal(1,"Restart bypassed pipeline");
        tick(1); if(!resetn) $fatal(1,"Restart failed");
        $display("PASS: configuration startup hold, VIO stop, indefinite hold and restart");
        $finish;
    end
    initial begin #10000; $fatal(1,"Watchdog"); end
endmodule
