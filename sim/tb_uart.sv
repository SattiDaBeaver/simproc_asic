module UART_wrapper_tb;

    // === Parameters ===
    localparam CLK_PERIOD   = 10;         // 100 MHz clock (10 ns period)
    localparam CLK_BITS     = 8;
    localparam DATA_WIDTH   = 8;
    localparam PARITY_BITS  = 0;
    localparam STOP_BITS    = 1;

    // === DUT signals ===
    logic clk;
    logic rst;
    logic [CLK_BITS-1:0] clk_per_bit;
    logic [DATA_WIDTH-1:0] TX_dataIn;
    logic TX_en;
    logic TX_out;
    logic TX_done;
    logic TX_busy;

    logic RX_dataIn;
    logic [DATA_WIDTH-1:0] RX_dataOut;
    logic RX_done;
    logic RX_parityError;

    // === Clock Generation ===
    always #(CLK_PERIOD/2) clk = ~clk;

    // === DUT Instantiation ===
    UART_wrapper #(
        .CLK_BITS(CLK_BITS),
        .DATA_WIDTH(DATA_WIDTH),
        .PARITY_BITS(PARITY_BITS),
        .STOP_BITS(STOP_BITS)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .clk_per_bit(clk_per_bit),

        .TX_dataIn(TX_dataIn),
        .TX_en(TX_en),

        .RX_dataIn(RX_dataIn),

        .TX_out(TX_out),
        .TX_done(TX_done),
        .TX_busy(TX_busy),

        .RX_dataOut(RX_dataOut),
        .RX_done(RX_done),
        .RX_parityError(RX_parityError)
    );

    // === Loopback ===
    assign RX_dataIn = TX_out;

    // === Test Procedure ===
    initial begin
        // Dump wave file
        $dumpfile("dump.vcd"); 
        $dumpvars;
        // Initialize
        clk = 0;
        rst = 1;
        TX_en = 0;
        TX_dataIn = 8'h00;
        clk_per_bit = 8'd16; // Faster baud for simulation
        #(10*CLK_PERIOD);
        rst = 0;

        // === Send Byte 1 ===
        @(negedge clk);
        TX_dataIn = 8'hA5;
        TX_en = 1;
        @(negedge clk);
        TX_en = 0;

        // Wait for TX done and RX done
        wait (TX_done);
        $display("[%0t] TX done", $time);
        wait (RX_done);
        $display("[%0t] RX done, RX_dataOut = 0x%0h", $time, RX_dataOut);

        // === Send Byte 2 ===
        @(negedge clk);
        TX_dataIn = 8'h3C;
        TX_en = 1;
        @(negedge clk);
        TX_en = 0;

        wait (TX_done);
        $display("[%0t] TX done", $time);
        wait (RX_done);
        $display("[%0t] RX done, RX_dataOut = 0x%0h", $time, RX_dataOut);

        // === End Simulation ===
        #(1000);
        $finish;
    end

endmodule
