`timescale 1ns/1ps
module fir_filter_tb;

    parameter DATA_WIDTH = 16;
    parameter TAPS       = 8;
    
    // Testbench signals
    reg                       clk;
    reg                       rst;
    reg  [DATA_WIDTH-1:0]     s_axis_tdata;
    reg                       s_axis_tvalid;
    reg                       s_axis_tlast;
    reg                       m_axis_tready; // Drive always ready
    
    wire [DATA_WIDTH-1:0]     m_axis_tdata;
    wire                      m_axis_tvalid;
    wire                      m_axis_tlast;
    wire                      s_axis_tready; // Unused since always '1' in the design
    
    // Instantiate the FIR filter module (without bypass mode)
    fir_filter #(
        .DATA_WIDTH(DATA_WIDTH),
        .TAPS(TAPS)
    ) uut (
        .clk(clk),
        .rst(rst),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    // Test stimulus
    initial begin
        // Initialize signals
        clk         = 0;
        rst         = 1;
        s_axis_tdata= 0;
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        m_axis_tready = 1;  // Always ready
        
        // Hold reset for 20 ns
        #20;
        rst = 0;
        
        // Wait one clock cycle after reset
        @(posedge clk);
        
        // Send a series of samples:
        // Sample 1
        s_axis_tdata  = 16'd10;
        s_axis_tvalid = 1;
        s_axis_tlast  = 0;
        @(posedge clk);
        
        // Sample 2
        s_axis_tdata  = 16'd20;
        s_axis_tvalid = 1;
        s_axis_tlast  = 0;
        @(posedge clk);
        
        // Sample 3
        s_axis_tdata  = 16'd30;
        s_axis_tvalid = 1;
        s_axis_tlast  = 0;
        @(posedge clk);
        
        // Sample 4, mark as last sample to initiate flush mode.
        s_axis_tdata  = 16'd40;
        s_axis_tvalid = 1;
        s_axis_tlast  = 1;
        @(posedge clk);
        
        // After sending the last sample, deassert valid and last.
        s_axis_tvalid = 0;
        s_axis_tlast  = 0;
        
        // Wait enough clock cycles for the flush (TAPS cycles)
        repeat (TAPS) @(posedge clk);
        repeat (TAPS) @(posedge clk);
        
        // End simulation
        $finish;
    end

    // Optional: Monitor signals during simulation
    initial begin
        $monitor("Time=%0t | s_axis_tdata=%d, s_axis_tvalid=%b, s_axis_tlast=%b || m_axis_tdata=%d, m_axis_tvalid=%b, m_axis_tlast=%b", 
                 $time, s_axis_tdata, s_axis_tvalid, s_axis_tlast, m_axis_tdata, m_axis_tvalid, m_axis_tlast);
    end

endmodule
