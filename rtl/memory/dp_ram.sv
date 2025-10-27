module dp_ram #(
    parameter DATA_WIDTH = 8,
    parameter MEM_DEPTH = 256
) (
    input  logic            clk,

	input  logic    [7:0]   din_a,
    input  logic    [7:0]   addr_a,
    input  logic            we_a,
    output logic    [7:0]   dout_a,

    input  logic    [7:0]   din_b,
    input  logic    [7:0]   addr_b,
    input  logic            we_b,
    output logic    [7:0]   dout_b
);

    logic [7:0] mem [0:255];

    always_ff @ (posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
        if (we_b) begin
            mem[addr_b] <= din_b;
        end
    end

    always_comb begin
        dout_a = mem[addr_a];
        dout_b = mem[addr_b];
    end    
endmodule