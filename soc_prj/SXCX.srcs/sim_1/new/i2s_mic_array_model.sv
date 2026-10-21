`timescale 1ns / 1ps

// Simulation ONLY: independent four-line microphone model driven by DUT clocks.
module i2s_mic_array_model (
    input wire resetn,
    input wire bclk,
    input wire ws,
    input wire [7:0] epoch,
    output reg [3:0] data,
    output reg [167:0] expected_samples,
    output integer frame_id,
    output integer slot_bit
);
    reg last_ws;
    reg [3:0] next_data;
    reg [23:0] word_value;
    integer lane;
    integer channel;
    integer ch;

    function automatic [23:0] sample_value(input integer frame, input integer idx,
                                           input integer session);
        case ((frame + idx + session) % 8)
            0: sample_value = 24'h000000;
            1: sample_value = 24'hFFFFFF;
            2: sample_value = 24'h800000;
            3: sample_value = 24'h7FFFFF;
            4: sample_value = 24'h000001;
            5: sample_value = 24'hFFFFFE;
            6: sample_value = 24'h123401 ^ (frame << 8) ^ (idx << 16) ^ session;
            7: sample_value = 24'hABCDEF ^ (frame << 8) ^ (idx << 16) ^ session;
        endcase
    endfunction

    initial begin
        data = 0; expected_samples = 0; frame_id = 0;
        slot_bit = 0; last_ws = 0;
    end

    always @(negedge bclk or negedge resetn) begin
        // Wait for the DUT's nonblocking WS update on this falling edge.
        #1;
        if (!resetn) begin
            data = 0; expected_samples = 0; frame_id = 0;
            slot_bit = 0; last_ws = 0;
        end else begin
            if (ws != last_ws) begin
                last_ws = ws;
                slot_bit = 0;
                if (!ws) frame_id = frame_id + 1;
                for (ch = 0; ch < 7; ch = ch + 1)
                    expected_samples[ch*24 +: 24] = sample_value(frame_id, ch, epoch);
            end else slot_bit = slot_bit + 1;

            for (lane = 0; lane < 4; lane = lane + 1) begin
                if (lane == 3 && !ws) begin
                    next_data[lane] = 1'bz; // No eighth microphone.
                end else if (slot_bit >= 1 && slot_bit <= 24) begin
                    channel = lane == 3 ? 6 : lane*2 + ws;
                    word_value = sample_value(frame_id, channel, epoch);
                    next_data[lane] = word_value[24-slot_bit];
                end else begin
                    next_data[lane] = slot_bit[0] ? 1'bx : 1'bz;
                end
            end
            // Different bounded delays on each lane; no zero-delay idealization.
            data[0] <= #(8  + (frame_id % 5)*3) next_data[0];
            data[1] <= #(25 + (frame_id % 5)*4) next_data[1];
            data[2] <= #(45 + (frame_id % 5)*5) next_data[2];
            data[3] <= #(65 + (frame_id % 5)*3) next_data[3];
        end
    end
endmodule
