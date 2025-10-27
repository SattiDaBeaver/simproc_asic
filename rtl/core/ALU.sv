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