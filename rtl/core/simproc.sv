module simproc (
    input  logic clk,
    input  logic rst,

    // Memory interface
    output logic    [7:0]   mem_din,
    output logic    [7:0]   mem_addr,
    output logic            mem_we,
    input  logic    [7:0]   mem_dout,

    // Debug interface
    input  logic            run,
    output logic            halt
);

    // ALU wires
    logic [2:0] alu_op;
    logic [7:0] alu_in_a;
    logic [7:0] alu_in_b;
    logic       alu_n, alu_z;
    logic [7:0] alu_out;

    // Register File wires
    logic       rf_write;
    logic [1:0] rf_reg_a_in;
    logic [1:0] rf_reg_b_in;
    logic [1:0] rf_reg_w_in;
    logic [7:0] rf_data_w_in;
    logic [7:0] rf_data_a_out;
    logic [7:0] rf_data_b_out;

    // Program Counter wires
    logic [7:0] pc_in;
    logic       pc_wr;
    logic [7:0] pc_out;

    // Module instantiation
    ALU ALU1 (
        // Inputs
        .ALUop(alu_op),
        .A(alu_in_a),
        .B(alu_in_b),
        // Outputs
        .N(alu_n),
        .Z(alu_z),
        .ALUout(alu_out)
    );

    register_file RF1 (
        .clk(clk),
        .rst(rst),
        // Inputs
        .RFWrite(rf_write),
        .regA(rf_reg_a_in),
        .regB(rf_reg_b_in),
        .regW(rf_reg_w_in),
        .dataW(rf_data_w_in),
        // Outputs
        .dataA(rf_data_a_out),
        .dataB(rf_data_b_out)
    );

    program_counter PC1 (
        .clk(clk),
        .rst(rst),
        // Inputs
        .pc_in(pc_in),
        .pc_wr(pc_wr),
        // Outputs
        .pc_out(pc_out)
    );

    // FSM states
    typedef enum logic[2:0] { 
        IDLE, CYCLE_1, CYCLE_2, CYCLE_3, CYCLE_4, CYCLE_5
    } state_t;

    // ALU operation codes
    typedef enum logic [2:0] {
        ALU_ADD  = 3'b000,
        ALU_SUB  = 3'b001,
        ALU_OR   = 3'b010,
        ALU_NAND = 3'b011,
        ALU_SHL  = 3'b100,
        ALU_SHR  = 3'b101
    } aluop_t;
    
    // Instruction opcodes
    typedef enum logic [3:0] {
        OP_ADD   = 4'b0100,
        OP_SUB   = 4'b0110,
        OP_NAND  = 4'b1000,
        OP_ORI   = 4'b0111,  // Only check 3 LSB
        OP_LOAD  = 4'b0000,
        OP_STORE = 4'b0010,
        OP_BNZ   = 4'b1001,
        OP_BPZ   = 4'b0101,
        OP_BZ    = 4'b1010,
        OP_SHIFT = 4'b0011,  // Only check 3 LSB
        OP_JUMP  = 4'b0001   // Custom instruction
    } opcode_t;

    // Shift instructions
    typedef enum logic {
        SHIFT_R  = 1'b0,
        SHIFT_L  = 1'b1
    } shift_t;
    
endmodule
