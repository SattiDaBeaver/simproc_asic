module top_fpga (
    input  logic    [9:0]   SW,
    input  logic    [1:0]   KEY,
    input  logic            CLOCK_50,
    inout  logic    [15:0]  ARDUINO_IO,

    output logic    [6:0]   HEX5,
    output logic    [6:0]   HEX4,
    output logic    [6:0]   HEX3,
    output logic    [6:0]   HEX2,
    output logic    [6:0]   HEX1,
    output logic    [6:0]   HEX0,
    output logic    [9:0]   LEDR
);

    // UART signals
    logic [9:0] clk_per_bit;
    logic [7:0] rx_data;
    logic [7:0] tx_data;
    logic rx_done;
    logic tx_en;
    logic parity_error;

    logic tx_busy;
    logic tx_done;

    // Assign the switch values directly to clk_per_bit
    assign clk_per_bit = SW;
    assign tx_data = rx_data;
    assign tx_en = rx_done;

    hex7seg H0 (rx_data[3:0], HEX0);
    hex7seg H1 (rx_data[7:4], HEX1);

    assign {HEX5, HEX4, HEX3, HEX2} = '1;

    // Instantiate UART wrapper
    UART_wrapper #(
        .CLK_BITS(10),
        .DATA_WIDTH(8),
        .PARITY_BITS(0),
        .STOP_BITS(1)
    ) uart0 (
        .clk(CLOCK_50),
        .rst(~KEY[0]),           // Active-low reset
        .clk_per_bit(clk_per_bit),

        .TX_dataIn(tx_data),     // Loopback: RX goes to TX
        .TX_en(tx_en),

        .RX_dataIn(ARDUINO_IO[0]),
        .TX_out(ARDUINO_IO[1]),

        .TX_done(tx_done),
        .TX_busy(tx_busy),
        .RX_dataOut(rx_data),
        .RX_done(rx_done),
        .RX_parityError(parity_error)
    );

endmodule

module UART_wrapper #(
    parameter CLK_BITS     = 8, // bits for adjustable BAUD rate, min BAUD = F_CLK / (2^CLK_BITS)
    parameter DATA_WIDTH   = 8,
    parameter PARITY_BITS  = 0,
    parameter STOP_BITS    = 1
) (
    input  logic                    clk,
    input  logic                    rst,

    input  logic   [CLK_BITS-1:0]   clk_per_bit,

    input  logic   [DATA_WIDTH-1:0] TX_dataIn,
    input  logic                    TX_en,

    input  logic                    RX_dataIn,

    output logic                    TX_out,
    output logic                    TX_done,
    output logic                    TX_busy,

    output logic   [DATA_WIDTH-1:0] RX_dataOut,
    output logic                    RX_done,
    output logic                    RX_parityError
);
    // UART Transmitter Module
    UART_TX #(
        .CLK_BITS(CLK_BITS),
        .DATA_WIDTH(DATA_WIDTH),
        .PARITY_BITS(PARITY_BITS),
        .STOP_BITS(STOP_BITS)
        ) 
        UART_TX1 ( 
        .clk(clk),
        .rst(rst),

        .clk_per_bit(clk_per_bit),
        .dataIn(TX_dataIn),
        .TXen(TX_en),

        .TXout(TX_out),
        .TXdone(TX_done),
        .busy(TX_busy)
    );

    // UART Receiver Module
    UART_RX #(
        .CLK_BITS(CLK_BITS),
        .DATA_WIDTH(DATA_WIDTH),
        .PARITY_BITS(PARITY_BITS),
        .STOP_BITS(STOP_BITS)
        )
        UART_RX1 (
        .clk(clk),
        .rst(rst),

        .clk_per_bit(clk_per_bit),
        .dataIn(RX_dataIn),

        .RXout(RX_dataOut),
        .RXdone(RX_done),
        .parityError(RX_parityError)
    );
endmodule

module UART_RX #(
    parameter CLK_BITS = 8,   // bits for adjustable BAUD rate, min BAUD = F_CLK / (2^CLK_BITS)
    parameter DATA_WIDTH = 8,
    parameter STOP_BITS = 2,  // either 1 or 2 stop bits
    parameter PARITY_BITS = 1,
    parameter PACKET_SIZE = DATA_WIDTH + STOP_BITS + PARITY_BITS + 1
    // Total Packet Size = DATA_WIDTH + STOP_BITS + 1 Start Bit + 1 Parity Bit
) ( 
    input  logic                                clk,
    input  logic                                rst,

    input  logic    [CLK_BITS - 1 : 0]          clk_per_bit,
    input  logic                                dataIn,

    output logic    [DATA_WIDTH - 1 : 0]         RXout,
    output logic                                RXdone,
    output logic                                parityError
);

    localparam indexBits = $clog2(PACKET_SIZE);

    logic   [indexBits - 1 : 0]     index;
    logic   [CLK_BITS - 1 : 0]      clkCount;

    logic                           regInMeta;
    logic                           regIn;
    logic                           parity;

    logic    [DATA_WIDTH - 1 : 0]    dataOut;
    logic                           dataDone;

    // Remove Problems due to Metastability
    always_ff @(posedge clk) begin
        regInMeta <= dataIn;
        regIn <= regInMeta;
    end



    typedef enum logic [1:0] {
        IDLE,
        START,
        RECEIVE,
        DONE
    } 
    state_t;

    state_t state;

    always_ff @(posedge clk) begin
        if (rst) begin
            dataOut <= 0;
            state <= IDLE;
            index <= 1'b0;
            clkCount <= 0;
            dataDone <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    clkCount <= 0;
                    index <= 0;
                    dataOut <= 0;
                    dataDone <= 0;

                    if (regIn == 1'b0) begin    // Start Condition
                        state <= START;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                START: begin
                    if (clkCount == ((clk_per_bit - 1) >> 1)) begin
                        clkCount <= 0;
                        state <= RECEIVE;
                    end
                    else begin
                        clkCount <= clkCount + 1;
                        state <= START;
                    end

                end

                RECEIVE: begin

                    if (clkCount < clk_per_bit - 1) begin
                        clkCount <= clkCount + 1;
                        state <= RECEIVE;
                    end

                    else begin
                        clkCount <= 0;
                        if (index < DATA_WIDTH) begin
                            dataOut[index] <= regIn;
                            index <= index + 1;
                            state <= RECEIVE;
                        end
                        else if (index == DATA_WIDTH && PARITY_BITS > 0) begin
                            parity <= regIn;
                            state <= DONE;
                        end
                        else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (clkCount < clk_per_bit - 1) begin
                        clkCount <= clkCount + 1;
                        state <= DONE;
                    end
                    else begin
                        clkCount <= 0;
                        state <= IDLE;
                        dataDone <= 1'b1;
                        index <= 0;
                        RXout <= dataOut;
                    end
                end

                default: begin
                    state <= IDLE;
                end
                
            endcase
        end 
    end

    always_comb begin
        RXdone = dataDone;
        if (PARITY_BITS > 0) begin
            parityError = (^RXout) ^ parity;
        end
        else begin
            parityError = 0;
        end
    end
endmodule

module UART_TX #(
    parameter CLK_BITS = 8,         // bits for adjustable BAUD rate, min BAUD = F_CLK / (2^CLK_BITS)
    parameter DATA_WIDTH = 8,
    parameter STOP_BITS = 1,        // either 1 or 2 stop bits
    parameter PARITY_BITS = 1,      // can be set to 0
    parameter PACKET_SIZE = DATA_WIDTH + STOP_BITS + PARITY_BITS + 1 
    // Total Packet Size = DATA_WIDTH + STOP_BITS + 1 Start Bit + 1 Parity Bit
) ( 
    input  logic                                clk,
    input  logic                                rst,

    input  logic      [CLK_BITS - 1 : 0]        clk_per_bit,
    input  logic      [DATA_WIDTH - 1 : 0]      dataIn,
    input  logic                                TXen,

    output logic                                TXout,
    output logic                                TXdone,
    output logic                                busy
);

    localparam indexBits = $clog2(PACKET_SIZE);

    logic   [PACKET_SIZE - 1 : 0]       packet;
    logic                               parityBit;
    logic   [indexBits - 1 : 0]         index;
    logic   [CLK_BITS - 1 : 0]          clkCount;

    typedef enum logic [1:0] {
        IDLE,
        TRANSMIT,
        DONE
    } 
    state_t;

    state_t state;

    always_comb begin
        parityBit = ^dataIn;    // 0 for even number of 1's, 1 for odd number of 1's
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            TXout       <= 1'b1;
            state       <= IDLE;
            busy        <= 1'b0;
            index       <= 1'b0;
            clkCount    <= 0;
            TXdone      <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    TXout       <= 1'b1;
                    index       <= 1'b0;
                    clkCount    <= 0;
                    TXdone      <= 0;

                    if (TXen) begin
                        if (PARITY_BITS > 0) begin
                            packet <= {{STOP_BITS{1'b1}}, parityBit, dataIn, 1'b0};
                        end 
                        else begin
                            packet <= {{STOP_BITS{1'b1}}, dataIn, 1'b0};
                        end
                        //                ^                         ^
                        //                |                         |
                        //              Stop                      Start
                        busy <= 1'b1;
                        state <= TRANSMIT;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                TRANSMIT: begin
                    TXout <= packet[index];

                    if (clkCount < clk_per_bit - 1) begin
                        clkCount <= clkCount + 1;
                        state <= TRANSMIT;
                    end

                    else begin
                        clkCount <= 0;
                        if (index == PACKET_SIZE - 1) begin
                            state <= DONE;
                        end
                        else begin
                            index <= index + 1;
                            state <= TRANSMIT;
                        end
                    end
                end

                DONE: begin
                    state       <= IDLE;
                    busy        <= 1'b0;
                    TXdone      <= 1'b1;
                    index       <= 1'b0;
                    clkCount    <= 0;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end 
    end
endmodule

module hex7seg (hex, display);
    input   [3:0] hex;
    output  [6:0] display;

    logic   [6:0] display;

    always @ (hex)
        case (hex)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0011000;
            4'hA: display = 7'b0001000;
            4'hB: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hD: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
        endcase
endmodule