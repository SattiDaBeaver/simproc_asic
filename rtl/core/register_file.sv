module register_file (
	input  logic            clk,
    input  logic            rst,
	input  logic            RFWrite,
	input  logic    [1:0]   regA,
	input  logic    [1:0]   regB,
	input  logic    [1:0]   regW,
	input  logic    [7:0]   dataW,

	output logic    [7:0]   dataA,
	output logic    [7:0]   dataB
);

    logic [7:0] rf[0:3];

	always_ff @ (posedge clk) begin
        if (rst) begin
            rf[0] <= 8'b0;
            rf[1] <= 8'b0;
            rf[2] <= 8'b0;
            rf[3] <= 8'b0;
        end
		else if (RFWrite) begin
            rf[regW] <= dataW;
		end
	end
	always_comb begin
        dataA = rf[regA];
        dataB = rf[regB];
    end
endmodule