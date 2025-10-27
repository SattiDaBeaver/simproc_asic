module program_counter (
    input  logic            clk,
    input  logic            rst,
    input  logic    [7:0]   pc_in,
    input  logic            pc_wr,
    output logic    [7:0]   pc_out
); 
    always_ff @ (posedge clk) begin
        if (rst) begin
            pc_out <= 8'b0;
        end
        else if (pc_wr) begin
            pc_out <= pc_in;
        end
    end
endmodule
