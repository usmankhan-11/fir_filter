`timescale 1ns/1ps
module fir_filter #(
    parameter DATA_WIDTH = 16,
    parameter TAPS       = 8
)(
    input  wire                      clk,
    input  wire                      rst,

    // AXI Stream Input
    input  wire [DATA_WIDTH-1:0]     s_axis_tdata,
    input  wire                      s_axis_tvalid,
    output wire                      s_axis_tready,  // Always ready
    input  wire                      s_axis_tlast,

    // AXI Stream Output
    output reg  [DATA_WIDTH-1:0]     m_axis_tdata,
    output reg                       m_axis_tvalid,
    input  wire                      m_axis_tready,  // Not used to clear final output
    output reg                       m_axis_tlast
);

    // -------------------------------------------------------------------------
    // Hardcoded coefficients
    // -------------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] coeffs [0:TAPS-1];
    integer i;
    initial begin
        coeffs[0] = 16'd2;
        coeffs[1] = 16'd4;
        coeffs[2] = 16'd6;
        coeffs[3] = 16'd8;
        coeffs[4] = 16'd6;
        coeffs[5] = 16'd4;
        coeffs[6] = 16'd2;
        coeffs[7] = 16'd1;
    end

    // -------------------------------------------------------------------------
    // Shift register for samples
    // -------------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] shift_reg [0:TAPS-1];

    // MAC accumulator.
    reg signed [2*DATA_WIDTH-1:0] acc;

    // -------------------------------------------------------------------------
    // Flush mode control: once s_axis_tlast is seen, we need to continue shifting
    // zeros through the filter for TAPS-1 cycles to flush out all stored samples.
    // -------------------------------------------------------------------------
    reg flushing;  // Indicates we are in flush mode.
    reg [$clog2(TAPS):0] flush_count;  // Counts remaining flush cycles.

    // s_axis_tready is always high.
    assign s_axis_tready = 1;

    // -------------------------------------------------------------------------
    // Main FIR processing and flush state machine.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            m_axis_tdata    <= 0;
            m_axis_tvalid   <= 0;
            m_axis_tlast    <= 0;
            flushing        <= 0;
            flush_count     <= 0;
            // Initialize shift register to zeros.
            for (i = 0; i < TAPS; i = i + 1)
                shift_reg[i] <= 0;
        end else begin
            // Default output control.
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;

            // If a new valid sample arrives and we're not flushing,
            // process it normally.
            if (s_axis_tvalid && !flushing) begin
                // Shift register: shift previous samples.
                for (i = TAPS-1; i > 0; i = i - 1)
                    shift_reg[i] <= shift_reg[i-1];
                // Insert the new sample.
                shift_reg[0] <= s_axis_tdata;

                // Compute MAC: accumulate multiply-accumulate over taps.
                acc = 0;
                for (i = 0; i < TAPS; i = i + 1)
                    acc = acc + shift_reg[i] * coeffs[i];

                // Drive output (using lower DATA_WIDTH bits; adjust scaling as needed).
                m_axis_tdata  <= acc[DATA_WIDTH-1:0];
                m_axis_tvalid <= 1;

                // If this sample is flagged as the last, begin flush mode.
                if (s_axis_tlast) begin
                    flushing    <= 1;
                    flush_count <= TAPS - 1; // Extra cycles needed to flush remaining samples.
                end
            end 
            // In flush mode: shift in zeros.
            else if (flushing) begin
                for (i = TAPS-1; i > 0; i = i - 1)
                    shift_reg[i] <= shift_reg[i-1];
                shift_reg[0] <= 0;

                // Compute MAC.
                acc = 0;
                for (i = 0; i < TAPS; i = i + 1)
                    acc = acc + shift_reg[i] * coeffs[i];

                m_axis_tdata  <= acc[DATA_WIDTH-1:0];
                m_axis_tvalid <= 1;

                // Check flush counter.
                if (flush_count == 0) begin
                    // Final flush cycle: assert the output last flag.
                    m_axis_tlast <= 1;
                    flushing    <= 0;
                end else begin
                    flush_count <= flush_count - 1;
                end
            end
            // If no new data and not flushing, output remains invalid.
        end
    end

endmodule
