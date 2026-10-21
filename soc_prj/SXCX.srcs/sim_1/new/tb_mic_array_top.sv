`timescale 1ns / 1ps

module tb_mic_array_top;
    reg clk = 0;
    reg resetn = 0;
    reg [7:0] epoch = 0;
    wire [3:0] mic_data;
    wire bclk, ws, frame_valid, sync_error;
    wire signed [23:0] sample0, sample1, sample2, sample3, sample4, sample5, sample6;
    wire [167:0] samples = {sample6,sample5,sample4,sample3,sample2,sample1,sample0};
    wire [167:0] expected_samples;
    wire [31:0] model_frame, slot_bit;
    wire pair_bclk, pair_ws, pair_valid;
    wire signed [23:0] pair_left, pair_right;
    reg [47:0] last_pair;
    reg [167:0] previous_samples;
    reg previous_valid = 0;
    reg previous_pair_valid = 0;
    reg injecting = 0;
    integer total_frames = 0;
    integer session_frames = 0;
    integer pair_frames = 0;
    integer frozen_count;
    integer ch;
    time last_frame_time = 0;
    time last_bclk_time = 0;
    time last_ws_time = 0;

    always #5 clk = ~clk;
    mic_array_top dut (
        .clk(clk), .resetn(resetn), .mic_data(mic_data), .mic_bclk(bclk), .mic_ws(ws),
        .sample0(sample0), .sample1(sample1), .sample2(sample2), .sample3(sample3),
        .sample4(sample4), .sample5(sample5), .sample6(sample6),
        .frame_valid(frame_valid), .sync_error(sync_error)
    );
    // The learning single-line top is checked against the same serial D0 input.
    mic_pair_top pair_dut (
        .clk(clk), .resetn(resetn), .mic_data(mic_data[0]),
        .mic_bclk(pair_bclk), .mic_ws(pair_ws),
        .left_sample(pair_left), .right_sample(pair_right), .pair_valid(pair_valid)
    );
    i2s_mic_array_model microphones (
        .resetn(resetn), .bclk(bclk), .ws(ws), .epoch(epoch), .data(mic_data),
        .expected_samples(expected_samples), .frame_id(model_frame), .slot_bit(slot_bit)
    );

    // Waveform aliases keep the seven expected channels easy to inspect.
    wire signed [23:0] expected0 = expected_samples[23:0];
    wire signed [23:0] expected1 = expected_samples[47:24];
    wire signed [23:0] expected2 = expected_samples[71:48];
    wire signed [23:0] expected3 = expected_samples[95:72];
    wire signed [23:0] expected4 = expected_samples[119:96];
    wire signed [23:0] expected5 = expected_samples[143:120];
    wire signed [23:0] expected6 = expected_samples[167:144];

    always @(posedge clk) begin
        #1;
        if (!resetn) begin
            if (frame_valid !== 0 || sync_error !== 0 || samples !== 168'd0)
                $fatal(1, "Array reset outputs mismatch");
            session_frames = 0;
            last_frame_time = 0;
            previous_valid = 0;
            previous_pair_valid = 0;
            previous_samples = 0;
            last_pair = 0;
        end else begin
            if ({pair_bclk,pair_ws} !== {bclk,ws})
                $fatal(1, "Single-line and array clock generators differ");
            if (frame_valid !== 0 && frame_valid !== 1)
                $fatal(1, "Unknown frame_valid");
            if (!injecting && sync_error !== 0)
                $fatal(1, "Unexpected synchronization error");
            if (pair_valid) begin
                if (previous_pair_valid || model_frame == 0 || !ws || slot_bit != 24)
                    $fatal(1, "Single-line valid timing error");
                if ({pair_right,pair_left} !== expected_samples[47:0])
                    $fatal(1, "Single-line integration sample mismatch");
                last_pair = {pair_right,pair_left};
                pair_frames = pair_frames + 1;
            end
            if (frame_valid) begin
                if (previous_valid || injecting || model_frame == 0 || !ws || slot_bit != 24)
                    $fatal(1, "Array valid timing/startup/error gating failure");
                for (ch = 0; ch < 7; ch = ch + 1)
                    if (samples[ch*24 +: 24] !== expected_samples[ch*24 +: 24])
                        $fatal(1, "Channel %0d mismatch: got %h expected %h", ch,
                               samples[ch*24 +: 24], expected_samples[ch*24 +: 24]);
                if (samples[47:0] !== last_pair)
                    $fatal(1, "Array differs from single-line reference top");
                if (session_frames != 0 && $time-last_frame_time != 20480)
                    $fatal(1, "Frame interval is not 20.48 us");
                last_frame_time = $time;
                session_frames = session_frames + 1;
                total_frames = total_frames + 1;
                $display("FRAME %0d PASS epoch=%0d id=%0d D3_RIGHT=%h",
                         total_frames, epoch, model_frame, sample6);
            end else if (samples !== previous_samples)
                $fatal(1, "Samples changed without frame_valid");
            previous_samples = samples;
            previous_valid = frame_valid;
            previous_pair_valid = pair_valid;
        end
    end

    always @(bclk or negedge resetn) begin
        #1;
        if (!resetn) last_bclk_time = 0;
        else begin
            if (last_bclk_time != 0 && $time-last_bclk_time != 160)
                $fatal(1, "BCLK half-period mismatch");
            last_bclk_time = $time;
        end
    end
    always @(ws or negedge resetn) begin
        #1;
        if (!resetn) last_ws_time = 0;
        else begin
            if (bclk !== 0) $fatal(1, "WS did not change on BCLK falling edge");
            if (last_ws_time != 0 && $time-last_ws_time != 10240)
                $fatal(1, "WS half-period mismatch");
            last_ws_time = $time;
        end
    end

    task reset_system;
        begin
            @(negedge clk);
            resetn = 0;
            epoch = epoch + 1;
            repeat (5) @(negedge clk);
            injecting = 0;
            resetn = 1;
        end
    endtask

    initial begin
        #100;
        @(negedge clk); resetn = 1;
        wait (session_frames >= 6);
        wait (ws == 0 && slot_bit == 12);
        reset_system(); // reset in a left-channel word
        wait (session_frames >= 4);
        wait (ws == 1 && slot_bit == 12);
        reset_system(); // reset in a right-channel word
        wait (session_frames >= 4);

        // Deliberately suppress one lane's valid pulse; do not export a mixed frame.
        @(posedge dut.lane_valid[0]);
        injecting = 1;
        frozen_count = total_frames;
        force dut.lane_valid[2] = 1'b0;
        repeat (2) @(negedge clk);
        release dut.lane_valid[2];
        #1;
        if (sync_error !== 1 || frame_valid !== 0)
            $fatal(1, "Lane mismatch did not latch sync_error");
        #45000;
        if (sync_error !== 1 || total_frames != frozen_count)
            $fatal(1, "Error state did not inhibit frames until reset");
        reset_system();
        wait (session_frames >= 4);
        @(negedge clk);
        if (total_frames < 18 || pair_frames < total_frames)
            $fatal(1, "Insufficient coverage");
        $display("PASS: four data lines / seven channels; %0d atomic frames; %0d single-line pairs; correct D3 RIGHT; unused D3 LEFT Hi-Z; varying input delays; reset recovery; sticky lane-error protection.", total_frames, pair_frames);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
