`timescale 1ns / 1ps
// CEP 3V3-powered microphone top: native PL oscillator, VIO run/stop, two ILAs.
// No PS, DDR, camera or servo is enabled in this build.
module mic_board_top (
    input wire sys_clk_p,
    input wire sys_clk_n,
    input wire [3:0] mic_data,
    output wire mic_bclk,
    output wire mic_ws,
    output wire fep_power_en
);
    wire clk_ibuf, clk;
    IBUFDS #(.DIFF_TERM("FALSE"), .IBUF_LOW_PWR("FALSE")) u_clk_ibuf
        (.I(sys_clk_p), .IB(sys_clk_n), .O(clk_ibuf));
    BUFG u_clk_bufg (.I(clk_ibuf), .O(clk));

    (* MARK_DEBUG = "TRUE" *) wire capture_enable;
    (* MARK_DEBUG = "TRUE" *) wire capture_resetn;
    (* MARK_DEBUG = "TRUE" *) wire frame_valid, sync_error;
    (* MARK_DEBUG = "TRUE" *) wire signed [23:0] sample0, sample1, sample2,
                                                    sample3, sample4, sample5, sample6;
    (* MARK_DEBUG = "TRUE" *) reg [31:0] frame_count = 0;
    mic_capture_control u_control (.clk(clk), .capture_enable(capture_enable),
                                    .resetn(capture_resetn));
    mic_array_top u_array (
        .clk(clk), .resetn(capture_resetn), .mic_data(mic_data),
        .mic_bclk(mic_bclk), .mic_ws(mic_ws),
        .sample0(sample0), .sample1(sample1), .sample2(sample2),
        .sample3(sample3), .sample4(sample4), .sample5(sample5), .sample6(sample6),
        .frame_valid(frame_valid), .sync_error(sync_error)
    );
    always @(posedge clk)
        if (!capture_resetn) frame_count <= 0;
        else if (frame_valid) frame_count <= frame_count + 1'b1;

    // 3V3-version CEPX3: request its regulator on after FPGA configuration.
    // CEP2 pin 1 supplies microphone VIN; NEVER parallel an external 5V source.
    // Shared by CEP1/2/3. This is an enable request, not power-good feedback.
    // Keep power enabled during VIO stop; u_control supplies the startup guard.
    assign fep_power_en = 1'b1;
    // Do not feed an asynchronous external input directly to an ILA comparator.
    (* ASYNC_REG = "TRUE" *) reg [3:0] raw_meta = 0;
    (* ASYNC_REG = "TRUE" *) reg [3:0] raw_sync = 0;
    always @(posedge clk) begin
        raw_meta <= mic_data;
        raw_sync <= raw_meta;
    end
    vio_mic_control u_vio (
        .clk(clk), .probe_in0(capture_resetn), .probe_in1(sync_error),
        .probe_in2(frame_count), .probe_out0(capture_enable)
    );
    ila_mic_raw u_ila_raw (
        .clk(clk), .probe0(raw_sync), .probe1(mic_bclk), .probe2(mic_ws),
        .probe3(capture_resetn), .probe4(frame_valid)
    );
    ila_mic_samples u_ila_samples (
        .clk(clk), .probe0(frame_valid), .probe1(sample0), .probe2(sample1),
        .probe3(sample2), .probe4(sample3), .probe5(sample4), .probe6(sample5),
        .probe7(sample6), .probe8(frame_count), .probe9(sync_error)
    );
endmodule
