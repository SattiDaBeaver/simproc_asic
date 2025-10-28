module simproc (
    input  logic            clk,
    input  logic            rst,

    // Memory interface
    output logic    [7:0]   mem_din,
    output logic    [7:0]   mem_addr,
    output logic            mem_we,
    input  logic    [7:0]   mem_dout,

    // Debug interface
    input  logic    [7:0]   pc_set_val,
    input  logic            pc_set_wr,
    input  logic            run,
    output logic            halt,
    output logic            done
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

    // Data Path wires
    logic [7:0] instr_reg_in;
    logic [7:0] instr_reg_out;

    logic [7:0] mdr_in;
    logic [7:0] mdr_out;

    logic [7:0] reg_a_in;
    logic [7:0] reg_a_out;

    logic [7:0] reg_b_in;
    logic [7:0] reg_b_out;

    logic [7:0] alu_reg_in;
    logic [7:0] alu_reg_out;

    logic       n_flag_in, z_flag_in;
    logic       n_flag_out, z_flag_out;

    // Load wires
    logic       ir_load;
    logic       mdr_load;
    logic       ab_load;
    logic       alu_out_load;
    logic       flag_wr;

    // Assign wires
    always_comb begin
        n_flag_in       = alu_n;
        z_flag_in       = alu_z;
        alu_reg_in      = alu_out;
        reg_a_in        = rf_data_a_out;
        reg_b_in        = rf_data_b_out;
        mdr_in          = mem_dout;
        instr_reg_in    = mem_dout;
    end

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

    state_t curr_state, next_state;

    always_comb begin
        // Default values
        next_state      = curr_state;
        done            = 0;
        halt            = 0;

        pc_in           = 8'b0;
        pc_wr           = 0;

        alu_in_a        = 8'b0;
        alu_in_b        = 8'b0;
        mem_addr        = 8'b0;
        mem_we          = 0;
        mem_din         = 8'b0;
        ir_load         = 0;
        rf_write        = 0;
        rf_data_w_in    = 8'b0;
        alu_op          = ALU_ADD;
        alu_out_load    = 0;
        flag_wr         = 0;

        rf_reg_a_in     = 2'b0;
        rf_reg_b_in     = 2'b0;
        ab_load         = 0;

        mdr_load        = 0;

        rf_reg_w_in     = 2'b0;

        // State case statement (state table)
        case (curr_state)
            IDLE: begin
                halt = 1;
                pc_in = pc_set_val;
                pc_wr = pc_set_wr;

                if (run) begin
                    next_state = CYCLE_1;
                end
                else begin
                    next_state = IDLE;
                end
            end

            CYCLE_1: begin
                // IR <- mem[PC]
                mem_addr        = pc_out;
                ir_load         = 1;

                // PC <- PC + 1
                alu_in_a        = pc_out;
                alu_in_b        = 8'h01;
                alu_op          = ALU_ADD;
                pc_in           = alu_out;
                pc_wr           = 1;

                next_state      = CYCLE_2;
            end

            CYCLE_2: begin
                // Preload regA and regB data in registers
                rf_reg_a_in     = instr_reg_out[7:6];
                rf_reg_b_in     = instr_reg_out[5:4];
                ab_load         = 1;

                next_state      = CYCLE_3;
            end

            CYCLE_3: begin
                if (instr_reg_out[3:0] == OP_ADD || instr_reg_out[3:0] == OP_SUB ||
                    instr_reg_out[3:0] == OP_NAND) begin
                    // Select operation
                    case (instr_reg_out[3:0])
                        OP_ADD:  alu_op = ALU_ADD;
                        OP_SUB:  alu_op = ALU_SUB;
                        OP_NAND: alu_op = ALU_NAND;
                        default: alu_op = ALU_ADD;
                    endcase
                    // select registers A and B
                    alu_in_a        = reg_a_out;
                    alu_in_b        = reg_b_out;
                    // load result in register and set flags
                    alu_out_load    = 1;
                    flag_wr         = 1;

                    next_state = CYCLE_4;
                end

                else if (instr_reg_out[2:0] == OP_SHIFT[2:0]) begin
                    // Select shift operation
                    if (instr_reg_out[5] == 1)
                        alu_op = ALU_SHL;
                    else
                        alu_op = ALU_SHR;
                    // select registers A and B
                    alu_in_a        = reg_a_out;
                    alu_in_b        = {6'b0, instr_reg_out[4:3]};
                    // load result in register and set flags
                    alu_out_load    = 1;
                    flag_wr         = 1;

                    next_state      = CYCLE_4;
                end

                else if (instr_reg_out[3:0] == OP_LOAD) begin
                    // MDR <- mem[rB]
                    mem_addr        = reg_b_out;
                    mdr_load        = 1;

                    next_state      = CYCLE_4;
                end

                else if (instr_reg_out[3:0] == OP_STORE) begin
                    // mem[rB] = rA
                    mem_addr        = reg_b_out;
                    mem_din         = reg_a_out;
                    mem_we          = 1;

                    // Check for run
                    done            = 1;
                    if (run)
                        next_state = CYCLE_1;
                    else
                        next_state = IDLE;

                end

                else if (instr_reg_out[3:0] == OP_BNZ || instr_reg_out[3:0] == OP_BPZ ||
                    instr_reg_out[3:0] == OP_BZ || instr_reg_out[3:0] == OP_JUMP) begin
                    // Select operation
                    case (instr_reg_out[3:0])
                        OP_BNZ: if (!z_flag_out) pc_wr = 1;
                        OP_BPZ: if (!n_flag_out) pc_wr = 1;
                        OP_BZ:  if (z_flag_out)  pc_wr = 1;
                        OP_JUMP:                 pc_wr = 1;
                    endcase
                    // A <- PC, B <- SE(instr[7:4])
                    alu_in_a        = pc_out;
                    alu_in_b        = {{4{instr_reg_out[7]}}, instr_reg_out[7:4]};
                    alu_op          = ALU_ADD;
                    pc_in           = alu_out;

                    // Check for run
                    done            = 1;
                    if (run)
                        next_state = CYCLE_1;
                    else
                        next_state = IDLE;
                end

                else if (instr_reg_out[2:0] == OP_ORI[2:0]) begin
                    // rA <- RF[0]
                    rf_reg_a_in     = 2'b0; // change this to 1, to match SimProc
                    ab_load         = 1;

                    next_state      = CYCLE_4;
                end
            end

            CYCLE_4: begin
                if (instr_reg_out[3:0] == OP_ADD || instr_reg_out[3:0] == OP_SUB ||
                    instr_reg_out[3:0] == OP_NAND || instr_reg_out[2:0] == OP_SHIFT[2:0]) 
                    begin
                    // RF[instr[7:6]] <- ALU out
                    rf_reg_w_in     = instr_reg_out[7:6];
                    rf_data_w_in    = alu_reg_out;
                    rf_write        = 1;

                    // Check for run
                    done            = 1;
                    if (run)
                        next_state = CYCLE_1;
                    else
                        next_state = IDLE;
                end

                else if (instr_reg_out[3:0] == OP_LOAD) begin
                    // RF[instr[7:6]] <- MDR
                    rf_reg_w_in     = instr_reg_out[7:6];
                    rf_data_w_in    = mdr_out;
                    rf_write        = 1;

                    // Check for run
                    done            = 1;
                    if (run)
                        next_state = CYCLE_1;
                    else
                        next_state = IDLE;
                end

                else if (instr_reg_out[2:0] == OP_ORI[2:0]) begin
                    // A <- rA, B <- ZE(instr[7:3])
                    alu_in_a        = reg_a_out;
                    alu_in_b        = {3'b0, instr_reg_out[7:3]};
                    alu_op          = ALU_OR;
                    alu_out_load    = 1;
                    flag_wr         = 1;

                    next_state      = CYCLE_5;
                end
            end

            CYCLE_5: begin
                // only for ORI
                // RF[0] <- ALU out (change later to be SimProc accurate)
                    rf_reg_w_in     = 2'b0; // change this to 1, to match SimProc
                    rf_data_w_in    = alu_reg_out;
                    rf_write        = 1;

                    // Check for run
                    done            = 1;
                    if (run)
                        next_state = CYCLE_1;
                    else
                        next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            curr_state      <= IDLE;

            instr_reg_out   <= 8'b0;
            mdr_out         <= 8'b0;
            reg_a_out       <= 8'b0;
            reg_b_out       <= 8'b0;
            alu_reg_out     <= 8'b0;
            n_flag_out      <= 0;
            z_flag_out      <= 0;
        end
        else begin
            curr_state <= next_state;

            if (ir_load) begin
                instr_reg_out   <= instr_reg_in;
            end
            if (mdr_load) begin
                mdr_out         <= mdr_in;
            end
            if (ab_load) begin
                reg_a_out       <= reg_a_in;
                reg_b_out       <= reg_b_in;
            end
            if (alu_out_load) begin
                alu_reg_out     <= alu_reg_in;
            end
            if (flag_wr) begin
                n_flag_out      <= n_flag_in;
                z_flag_out      <= z_flag_in;
            end
        end
    end
    
endmodule


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


module ALU (
    input  logic    [2:0]   ALUop,
    input  logic    [7:0]   A,
    input  logic    [7:0]   B,
    output logic            N,
    output logic            Z,
    output logic    [7:0]   ALUout
);

    typedef enum logic [2:0] {
        ADD  = 3'b000,
        SUB  = 3'b001,
        OR   = 3'b010,
        NAND = 3'b011,
        SHL  = 3'b100,
        SHR  = 3'b101
    } aluop_t;

    always @ (*) begin
        case(ALUop) 
            ADD:        ALUout = A + B;
            SUB:        ALUout = A - B;
            OR:         ALUout = A | B;
            NAND:       ALUout = ~(A & B);
            SHL:        ALUout = A << B[1:0];
            SHR:        ALUout = A >> B[1:0];

            default:    ALUout = 8'h00; 
        endcase
    end

    assign N = ALUout[7];
    assign Z = ~(|ALUout);
endmodule
