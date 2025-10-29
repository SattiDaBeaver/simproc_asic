module top_fpga (
    input  logic    [9:0]  SW,
    input  logic    [1:0]  KEY,
    input  logic           CLOCK_50,
    inout  logic    [15:0] ARDUINO_IO,

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

    assign {HEX4, HEX4, HEX3, HEX2} = '1;

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