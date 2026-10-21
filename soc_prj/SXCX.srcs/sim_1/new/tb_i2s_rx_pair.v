`timescale 1ns / 1ps

module tb_i2s_rx_pair;
    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg mic_bclk = 1'b0;
    reg mic_ws = 1'b0;
    reg mic_data = 1'b0;

    wire signed [23:0] left_sample;
    wire signed [23:0] right_sample;
    wire pair_valid;

    // 参考值由发送端测试场景提供，不从接收模块内部读取
    reg [23:0] expected_left = 24'd0;
    reg [23:0] expected_right = 24'd0;
    reg allow_pair = 1'b0;
    reg previous_valid = 1'b0;
    integer data_bit = -1;
    integer pair_count = 0;

    i2s_rx_pair dut (
        .clk(clk), .resetn(resetn),
        .mic_bclk(mic_bclk), .mic_ws(mic_ws), .mic_data(mic_data),
        .left_sample(left_sample), .right_sample(right_sample),
        .pair_valid(pair_valid)
    );

    always #5 clk = ~clk;

    // 每个系统时钟都检查输出；#1 等待非阻塞赋值生效
    always @(posedge clk) begin
        #1;
        if (!resetn) begin
            if (pair_valid !== 1'b0 || left_sample !== 24'd0 ||
                right_sample !== 24'd0)
                $fatal(1, "Reset outputs mismatch");
            previous_valid = 1'b0;
        end
        else begin
            if (pair_valid !== 1'b0 && pair_valid !== 1'b1)
                $fatal(1, "pair_valid is unknown");
            if (pair_valid) begin
                if (previous_valid)
                    $fatal(1, "pair_valid lasted longer than one clk cycle");
                if (!allow_pair || mic_ws !== 1'b1 || data_bit != 0 ||
                    mic_bclk !== 1'b1)
                    $fatal(1, "Unexpected or early pair_valid");
                if (left_sample !== expected_left || right_sample !== expected_right)
                    $fatal(1, "Sample mismatch: L=%h expected=%h R=%h expected=%h",
                        left_sample, expected_left, right_sample, expected_right);
                pair_count = pair_count + 1;
                $display("PAIR %0d PASS: left=%h (%0d), right=%h (%0d)",
                    pair_count, left_sample, $signed(left_sample),
                    right_sample, $signed(right_sample));
            end
            previous_valid = pair_valid;
        end
    end

    // 模拟一个 320 ns 位周期；下降沿后 20 ns 更新外部数据
    task send_bit;
        input value;
        begin
            mic_bclk = 1'b0;
            repeat (2) @(negedge clk);
            mic_data = value;
            repeat (14) @(negedge clk);
            mic_bclk = 1'b1;
            repeat (16) @(negedge clk);
            mic_bclk = 1'b0;
        end
    endtask

    // 32 位时隙：1 个延迟位、24 个音频位、7 个剩余位
    // interrupt_slot=1 时，在样本中途复位接收器
    task send_slot;
        input channel;
        input [23:0] sample_word;
        input expect_pair;
        input interrupt_slot;
        integer bit_index;
        integer padding;
        integer count_before;
        begin
            count_before = pair_count;
            allow_pair = expect_pair;
            mic_ws = channel;
            data_bit = -1;
            send_bit(1'b1);
            for (bit_index = 23; bit_index >= 0; bit_index = bit_index - 1) begin
                data_bit = bit_index;
                if (interrupt_slot && bit_index == 12) begin
                    resetn = 1'b0;
                    repeat (3) @(negedge clk);
                    resetn = 1'b1;
                end
                send_bit(sample_word[bit_index]);
            end
            data_bit = -1;
            for (padding = 0; padding < 7; padding = padding + 1)
                send_bit(~sample_word[0]);
            if (pair_count != count_before + expect_pair)
                $fatal(1, "Wrong number of valid pairs in this slot");
            allow_pair = 1'b0;
        end
    endtask

    initial begin
        #100;
        @(negedge clk);
        resetn = 1'b1;

        // 启动时未看到左声道边界：不能输出一对有效数据
        send_slot(0, 24'h13579B, 0, 0);
        send_slot(1, 24'h2468AC, 0, 0);

        // 覆盖符号位、不同的最低位、全零和全一
        expected_left = 24'h800001; expected_right = 24'h7FFFFE;
        send_slot(0, expected_left, 0, 0);
        send_slot(1, expected_right, 1, 0);
        expected_left = 24'h000000; expected_right = 24'hFFFFFF;
        send_slot(0, expected_left, 0, 0);
        send_slot(1, expected_right, 1, 0);
        expected_left = 24'hA5C39E; expected_right = 24'h123457;
        send_slot(0, expected_left, 0, 0);
        send_slot(1, expected_right, 1, 0);

        // 已收齐左声道，但右声道中途复位：旧左声道不得用于配对
        send_slot(0, 24'h7FFFFF, 0, 0);
        send_slot(1, 24'h654321, 0, 1);
        expected_left = 24'h800000; expected_right = 24'h000001;
        send_slot(0, expected_left, 0, 0);
        send_slot(1, expected_right, 1, 0);

        // 左声道中途复位：紧随其后的右声道也不能单独报有效
        send_slot(0, 24'h00FF00, 0, 1);
        send_slot(1, 24'h111111, 0, 0);
        expected_left = 24'h123456; expected_right = 24'hABCDEF;
        send_slot(0, expected_left, 0, 0);
        send_slot(1, expected_right, 1, 0);

        if (pair_count != 5) $fatal(1, "Expected five complete pairs");
        $display("PASS: five exact sample pairs; final-bit preservation; startup suppression; one-cycle valid; mid-left and mid-right reset recovery.");
        $finish;
    end

    initial begin
        #250000;
        $fatal(1, "Simulation timeout");
    end
endmodule
