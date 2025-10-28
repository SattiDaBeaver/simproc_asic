module tb_simproc;

    logic clk;
    logic rst;
    logic run;
    logic [7:0] pc_set_val;
    logic pc_set_wr;
    logic halt;
    logic done;

    logic [7:0] mem_din;
    logic [7:0] mem_addr;
    logic mem_we;
    logic [7:0] mem_dout;

    // --- Clock ---
    initial clk = 0;
    always #5 clk = ~clk; // 10 ns period

    // --- Memory ---
    logic [7:0] mem [0:255];

    // Small program in memory
    initial begin
        DUT.RF1.rf[0] = 8'h00;
        DUT.RF1.rf[1] = 8'h00;
        DUT.RF1.rf[2] = 8'h00;
        DUT.RF1.rf[3] = 8'h00;
    
        mem[0] = 8'b1001_0000;
        mem[1] = 8'b0100_0100;
      	mem[2] = 8'b0100_0111;
        mem[3] = 8'b1010_1000;
        mem[4] = 8'b0000_0110;
        mem[5] = 8'b1101_1010;
        
        
      	// mem[0]  = 8'b00000110;
        // mem[1]  = 8'b01010110;
        // mem[2]  = 8'b10100110;
        // mem[3]  = 8'b11110110;
        // mem[4]  = 8'b00001111;
        // mem[5]  = 8'b10000100;
        // mem[6]  = 8'b00000110;
        // mem[7]  = 8'b11000111;
        // mem[8]  = 8'b00111011;
        // mem[9]  = 8'b01000010;
        // mem[10] = 8'b01100100;
        // mem[11] = 8'b00011010;
        // mem[12] = 8'b11000001;
        // mem[13] = 8'b00100100;
        // mem[14] = 8'b11000000;
        // mem[15] = 8'b11100100;
        // mem[16] = 8'b11000010;
        // mem[17] = 8'b00101010;
        // mem[18] = 8'b00100110;
        // mem[19] = 8'b10000001;
        // mem[20] = 8'b00100100;
        // mem[21] = 8'b11000000;
        // mem[22] = 8'b11100100;
        // mem[23] = 8'b11000010;
        // mem[24] = 8'b00100110;
        // mem[25] = 8'b10000001;
    end

    // Memory read/write model
    assign mem_dout = mem[mem_addr];
    always_ff @(posedge clk) begin
        if (mem_we)
            mem[mem_addr] <= mem_din;
    end

    // --- DUT ---
    simproc DUT (
        .clk(clk),
        .rst(rst),
        .mem_din(mem_din),
        .mem_addr(mem_addr),
        .mem_we(mem_we),
        .mem_dout(mem_dout),
        .pc_set_val(pc_set_val),
        .pc_set_wr(pc_set_wr),
        .run(run),
        .halt(halt),
        .done(done)
    );

    // --- Stimulus ---
    initial begin
        $dumpfile("dump.vcd"); 
      	$dumpvars;
        // Reset DUT
        rst = 1;
        run = 0;
        pc_set_val = 8'h00;
        pc_set_wr  = 1;
        #20;
        rst = 0;
        pc_set_wr = 0;
      	DUT.RF1.rf[0] = 8'h00;
        DUT.RF1.rf[1] = 8'h01;
        DUT.RF1.rf[2] = 8'h00;
        DUT.RF1.rf[3] = 8'h00;
        run = 1;
        // #10
        // run = 0;

        // Run for some cycles
        repeat (30) @(posedge clk);

      	// DUT.RF1.rf[0] = 8'h00;
      	// #5
      	// run = 1;
        // #10
        // run = 0;
      	// repeat (8) @(posedge clk);

        // Stop simulation
        $finish;
    end

    // --- Monitor FSM, registers, and memory address ---
    always_ff @(posedge clk) begin
        if (DUT.curr_state == 1) begin
        $display("Time=%0t ns | PC =%0d|FSM=%0d | Done=%b | MemAddr=%0h | RF[0]=%0h RF[1]=%0h RF[2]=%0h RF[3]=%0h",
                $time, DUT.pc_out, DUT.curr_state, done, mem_addr,
                DUT.RF1.rf[0], DUT.RF1.rf[1], DUT.RF1.rf[2], DUT.RF1.rf[3]);
        // $display("MEM[C2]=%0h MEM[C1]=%0h MEM[C0]=%0h",
        //         mem[8'hC2], mem[8'hC1], mem[8'hC0]);
        end
    end

endmodule
