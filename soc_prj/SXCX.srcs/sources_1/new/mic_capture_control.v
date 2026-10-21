`timescale 1ns / 1ps
// Configuration INIT holds acquisition reset while the CEP regulator starts.
// 10,000,000 cycles at 100MHz = 100ms engineering settling guard, NOT power-good.
// The operator must also enable capture through VIO after checking real voltage.
module mic_capture_control #(
    parameter integer STARTUP_CYCLES = 10_000_000
) (
    input wire clk,
    input wire capture_enable,
    output wire resetn
);
    localparam integer CW = (STARTUP_CYCLES < 2) ? 1 : $clog2(STARTUP_CYCLES);
    reg [CW-1:0] startup_count = 0;
    reg startup_done = 0;
    reg [1:0] enable_pipe = 0;
    always @(posedge clk) begin
        enable_pipe <= {enable_pipe[0], capture_enable};
        if (!startup_done) begin
            if (startup_count == STARTUP_CYCLES-1)
                startup_done <= 1'b1;
            else
                startup_count <= startup_count + 1'b1;
        end
    end
    assign resetn = startup_done & enable_pipe[1];
endmodule
