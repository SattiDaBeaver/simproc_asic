module UART_wrapper #(
    parameter CLK_PER_BIT = 50,
    parameter dataWidth   = 8,
    parameter parityBits  = 0,
    parameter stopBits    = 1
) (
    input  logic                    clk,
    input  logic                    rst,

    input  logic   [dataWidth-1:0]  TX_dataIn,
    input  logic                    TX_en,

    input  logic                    RX_dataIn,

    output logic                    TX_out,
    output logic                    TX_done,
    output logic                    TX_busy,

    output logic   [dataWidth-1:0]  RX_dataOut,
    output logic                    RX_done,
    output logic                    RX_parityError
);
    // UART Transmitter Module
    UART_TX #(
        .CLK_PER_BIT(CLK_PER_BIT),
        .dataWidth(dataWidth),
        .parityBits(parityBits),
        .stopBits(stopBits)
        ) 
        UART_TX1 ( 
        .clk(clk),
        .rst(rst),
        .dataIn(TX_dataIn),
        .TXen(TX_en),

        .TXout(TX_out),
        .TXdone(TX_done),
        .busy(TX_busy)
    );

    // UART Receiver Module
    UART_RX #(
        .CLK_PER_BIT(CLK_PER_BIT),
        .dataWidth(dataWidth),
        .parityBits(parityBits),
        .stopBits(stopBits)
        )
        UART_RX1 (
        .clk(clk),
        .rst(rst),
        .dataIn(RX_dataIn),

        .RXout(RX_dataOut),
        .RXdone(RX_done),
        .parityError(RX_parityError)
    );
endmodule

module UART_RX #(
    parameter CLK_PER_BIT = 50,    // system clock / baud rate = 50M / 1M = 50
    parameter dataWidth = 8,
    parameter stopBits = 2,  // either 1 or 2 stop bits
    parameter parityBits = 1,
    parameter packetSize = dataWidth + stopBits + parityBits + 1
    // Total Packet Size = dataWidth + stopBits + 1 Start Bit + 1 Parity Bit
) ( 
    input  logic                                clk,
    input  logic                                rst,
    input  logic                                dataIn,

    output logic    [dataWidth - 1 : 0]         RXout,
    output logic                                RXdone,
    output logic                                parityError
);
    
    localparam clkBits = $clog2(CLK_PER_BIT);
    localparam indexBits = $clog2(packetSize);

    logic   [indexBits - 1 : 0]     index;
    logic   [clkBits - 1 : 0]       clkCount;

    logic                           regInMeta;
    logic                           regIn;
    logic                           parity;

    logic    [dataWidth - 1 : 0]    dataOut;
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
                    if (clkCount == ((CLK_PER_BIT - 1) / 2)) begin
                        clkCount <= 0;
                        state <= RECEIVE;
                    end
                    else begin
                        clkCount <= clkCount + 1;
                        state <= START;
                    end

                end

                RECEIVE: begin

                    if (clkCount < CLK_PER_BIT - 1) begin
                        clkCount <= clkCount + 1;
                        state <= RECEIVE;
                    end

                    else begin
                        clkCount <= 0;
                        if (index < dataWidth) begin
                            dataOut[index] <= regIn;
                            index <= index + 1;
                            state <= RECEIVE;
                        end
                        else if (index == dataWidth && parityBits > 0) begin
                            parity <= regIn;
                            state <= DONE;
                        end
                        else begin
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    if (clkCount < CLK_PER_BIT - 1) begin
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
        if (parityBits > 0) begin
            parityError = (^RXout) ^ parity;
        end
        else begin
            parityError = 0;
        end
    end
endmodule

module UART_TX #(
    parameter CLK_PER_BIT = 50,    // system clock / baud rate = 50M / 1M = 50
    parameter dataWidth = 8,
    parameter stopBits = 1,        // either 1 or 2 stop bits
    parameter parityBits = 1,
    parameter packetSize = dataWidth + stopBits + parityBits + 1 
    // Total Packet Size = dataWidth + stopBits + 1 Start Bit + 1 Parity Bit
) ( 
    input  logic                                clk,
    input  logic                                rst,
    input  logic      [dataWidth - 1 : 0]       dataIn,
    input  logic                                TXen,

    output logic                                TXout,
    output logic                                TXdone,
    output logic                                busy
);
    
    localparam clkBits = $clog2(CLK_PER_BIT);
    localparam indexBits = $clog2(packetSize);

    logic   [packetSize - 1 : 0]        packet;
    logic                               parityBit;
    logic   [indexBits - 1 : 0]         index;
    logic   [clkBits - 1 : 0]           clkCount;



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
            TXout <= 1'b1;
            state <= IDLE;
            busy <= 1'b0;
            index <= 1'b0;
            clkCount <= 0;
            TXdone <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    TXout <= 1'b1;
                    index <= 1'b0;
                    clkCount <= 0;
                    TXdone <= 0;

                    if (TXen) begin
                        if (parityBits > 0) begin
                            packet <= {{stopBits{1'b1}}, parityBit, dataIn, 1'b0};
                        end 
                        else begin
                            packet <= {{stopBits{1'b1}}, dataIn, 1'b0};
                        end
                        //                ^                               ^
                        //                |                               |
                        //              Stop                            Start
                        busy <= 1'b1;
                        state <= TRANSMIT;
                    end
                    else begin
                        state <= IDLE;
                    end
                end

                TRANSMIT: begin
                    TXout <= packet[index];

                    if (clkCount < CLK_PER_BIT - 1) begin
                        clkCount <= clkCount + 1;
                        state <= TRANSMIT;
                    end

                    else begin
                        clkCount <= 0;
                        if (index == packetSize - 1) begin
                            state <= DONE;
                        end
                        else begin
                            index <= index + 1;
                            state <= TRANSMIT;
                        end
                    end
                end

                DONE: begin
                    state <= IDLE;
                    busy <= 1'b0;
                    TXdone <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end 
    end
endmodule

