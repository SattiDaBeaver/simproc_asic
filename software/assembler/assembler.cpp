#include "assembler.hpp"

Instruction::Instruction(string m, int l) {
    mnemonic = m;
    line_num = l;
}

Assembler::Assembler() {
    curr_line = 0;
    curr_mem_addr = 0;
    is_text = false;
}

// Parse Line 
int Assembler::ParseLine (const string& line) {
    string l = line;

    // Remove Comments
    size_t comment_position = l.find('#');
    // if found comment
    if (comment_position != string::npos) {
        l = l.substr(0, comment_position);
    }

    // Remove leading/trailing whitespaces
    l.erase(0, l.find_first_not_of(" \t\r\n")); // remove leading whitespace
    l.erase(l.find_last_not_of(" \t\r\n") + 1); // remove trailing whitespace (till end of line)

    // Check for empty line
    if (l.empty()) {
        return 0;
    }

    // Get mnemonic
    istringstream line_stream(l);
    string token;
    line_stream >> token;
    string mnemonic = token; 

    vector<string> operands;

    while (line_stream >> token) {
        // Remove trailing comma if present
        if (!token.empty() && token.back() == ',') {
            token.pop_back();
        }
        operands.push_back(token);
    }

    Instruction instr(mnemonic, curr_line);
    instr.operands = operands;
    instructions.push_back(instr);

    return 0;
}

int32_t Assembler::GetValueFromString(string& str) {
    int32_t num;
    try
    {
        num = static_cast<int32_t>(stoi(str, nullptr, 0));
    }
    catch(const std::exception& e)
    {
        return VALUE_ERR;
    }
    
    return num;
}

uint8_t Assembler::GetValueFromRegister(string& str) {
    if (str == "r0" || str == "R0") {
        return 0;
    }
    if (str == "r1" || str == "R1") {
        return 1;
    }
    if (str == "r2" || str == "R2") {
        return 2;
    }
    if (str == "r3" || str == "R3") {
        return 3;
    }
    return INVALID_REG;
}

uint8_t Assembler::FindLabel(string& str) {
    auto iter = this->labels.find(str);
    if (iter == opcode_table.end()) {
        return LABEL_ERR; // return error
    }
    return iter->second;
}

uint8_t Assembler::IntToImm2(int32_t val) {
    return (val & 0x3);
}

uint8_t Assembler::IntToImm4(int32_t val) {
    return (val & 0xF);
}

uint8_t Assembler::IntToImm5(int32_t val) {
    return (val & 0x1F);
}


uint8_t Assembler::AssembleInstruction(const Instruction& instruction) {
    string instr = instruction.mnemonic;

    // Assembler directives
    if (instr == ".data") {
        // check text before data
        if (this->is_text) { 
            cout << "Error: \".data\" must be before \".text\" on line " << instruction.line_num << endl;
            return INSTR_ERR;
        }

        return ASM_DATA;
    }

    if (instr == ".text") {
        if (this->is_text) { 
            cout << "Error: \".text\" cannot be defined twice on line " << instruction.line_num << endl;
            return INSTR_ERR;
        }
        this->is_text = true;
        return ASM_TEXT;
    }

    // check if data
    // Change this section later to support labels
    if (!this->is_text) {
        if (instruction.operands.size() < 1) {
            cout << "Error: Too few operands (found " << instruction.operands.size() << 
            ", expected 1) on line " << instruction.line_num << "\n";
            return INSTR_ERR; // return error
        } 
        else if (instruction.operands.size() > 1) {
            cout << "Error: Too many operands (found " << instruction.operands.size() << 
            ", expected 1) on line " << instruction.line_num << "\n";
            return INSTR_ERR; // return error
        }
        string label = instruction.mnemonic;
        string data_str = instruction.operands[0];
        int32_t data_int32 = GetValueFromString(data_str);

        if (data_int32 > 127 || data_int32 < -128) {
            cout << "Error: Value out of bounds (found " << data_int32 << 
            ", expected -128 to 127) on line " << instruction.line_num << "\n";
            return INSTR_ERR; // return error
        }
        uint8_t data_word = (uint8_t) (data_int32 & 0xFF);

        // store label 
        this->labels.insert({label, (uint8_t)(curr_mem_addr)});

        return data_word;
    }


    // Instruction
    // This section might be redundant
    //-----------------------------------
    auto iter = this->opcode_table.find(instruction.mnemonic);
    if (iter == opcode_table.end()) {
        cout << "Error: Unknown instruction \"" << instruction.mnemonic <<
        "\" on line " << instruction.line_num << endl;
        return INSTR_ERR; // return error
    }

    //-----------------------------------

    uint8_t instr_word = 0;
    instr_word |= iter->second; // Set opcode bits

    // shift (2 instructions)
    if (instr == "shl" || instr == "shr") {

        if (instruction.operands.size() < 2) {
            cout << "Error: Too few operands (found " << instruction.operands.size() << 
            ", expected 2) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        } 
        else if (instruction.operands.size() > 2) {
            cout << "Error: Too many operands (found " << instruction.operands.size() << 
            ", expected 2) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }
        // register + immediate

        // Get register
        string rA = instruction.operands[0];
        string shift_str = instruction.operands[1];

        uint8_t reg_dest = GetValueFromRegister(rA);

        if (reg_dest == INVALID_REG) {
            cout << "Error: Invalid register name \"" << rA << 
            "\" on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }

        // Get immediate value
        int32_t val = GetValueFromString(shift_str);


        // Out of bounds check
        if (val > 3 || val < 0) {
            cout << "Error: Value out of bounds (found " << val << 
            ", expected 0 to 3) on line " << instruction.line_num << "\n";

            return INSTR_ERR; // return error
        }

        // Convert to imm2
        uint8_t imm2 = IntToImm2(val);
        instr_word |= ((reg_dest << 3) | imm2) << 3;

        return instr_word;
    }

    // ori (1 instruction)
    if (instr == "ori") {
        if (instruction.operands.size() < 1) {
            cout << "Error: Too few operands (found " << instruction.operands.size() << 
            ", expected 1) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        } 
        else if (instruction.operands.size() > 1) {
            cout << "Error: Too many operands (found " << instruction.operands.size() << 
            ", expected 1) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }
        string ori_str = instruction.operands[0];
        int32_t val = GetValueFromString(ori_str);

        // Check for label
        uint8_t label = FindLabel(ori_str);
        if (label == LABEL_ERR) { // label does not exist OR number used
            if (val == VALUE_ERR) { // label does not exist 
                cout << "Error: Label \"" << ori_str << "\" does not exist on line " << instruction.line_num << "\n";
                return INSTR_ERR; // return error
            }
        }
        else { // label exists
            val = label;
        }

        // Out of bounds check
        if (val > 31 || val < 0) {
            cout << "Error: Value out of bounds (found " << val << 
            ", expected 0 to 31) on line " << instruction.line_num << "\n";

            return INSTR_ERR; // return error
        }

        uint8_t imm5 = IntToImm5(val);
        instr_word |= (imm5 << 3);

        return instr_word;
    }

    // add sub nand store and load (5 instructions)
    if (instr == "add" || instr == "sub" || instr == "nand" ||
        instr == "store" || instr == "load") {

        if (instruction.operands.size() < 2) {
            cout << "Error: Too few operands (found " << instruction.operands.size() << 
            ", expected 2) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        } 
        else if (instruction.operands.size() > 2) {
            cout << "Error: Too many operands (found " << instruction.operands.size() << 
            ", expected 2) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }

        string rA = instruction.operands[0];
        string rB = instruction.operands[1];

        uint8_t reg_src = GetValueFromRegister(rA);
        uint8_t reg_dest= GetValueFromRegister(rB);

        if (reg_src == INVALID_REG) {
            cout << "Error: Invalid register name \"" << rA << 
            "\" on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }

        if (reg_dest == INVALID_REG) {
            cout << "Error: Invalid register name \"" << rB << 
            "\" on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }
        

        instr_word |= ((reg_src << 2) | reg_dest) << 4;

        return instr_word;
    }

    // branch instructions (4 instructions)
    if (instr == "bnz" || instr == "bpz" || instr == "bz" ||
        instr == "jump") {

        if (instruction.operands.size() < 1) {
            cout << "Error: Too few operands (found " << instruction.operands.size() << 
            ", expected 1) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        } 
        else if (instruction.operands.size() > 1) {
            cout << "Error: Too many operands (found " << instruction.operands.size() << 
            ", expected 1) on line " << instruction.line_num << "\n";
            
            return INSTR_ERR; // return error
        }

        // Get value
        string branch_str = instruction.operands[0];
        int32_t val = GetValueFromString(branch_str);
        
        // Out of bounds check
        if (val > 7 || val < -8) {
            cout << "Error: Value out of bounds (found " << val << 
            ", expected -8 to 7) on line " << instruction.line_num << "\n";

            return INSTR_ERR; // return error
        }

        // Convert to Imm4
        uint8_t imm4 = IntToImm4(val);
        instr_word |= (imm4 << 4);

        return instr_word;
    }

    // invalid instruction error
    cout << "Error: (This error should not occur) Invalid instruction on line " << 
    instruction.line_num << "\n";

    return INSTR_ERR; 
}

int Assembler::Assemble(const string& input_file, const string& output_file) {
    ifstream in_stream(input_file);
    if (!in_stream.is_open()) {
        cout << "Error: Cannot open input file: " << input_file << endl;
        return ASSEMBLER_ERR;
    }

    ofstream out_stream(output_file, ios::binary); 
    if (!out_stream.is_open()) {
        cout << "Error: Cannot open output file: " << output_file << endl;
        return ASSEMBLER_ERR;
    }

    
    this->curr_line = 0;
    string line;

    // Parse file
    while (getline(in_stream, line)) {
        this->curr_line++;
        ParseLine(line);
    }

    // Debugging prints
    for (Instruction instr : instructions) {
        cout << instr.line_num << ": " << instr.mnemonic;
        for (string op : instr.operands) {
            cout << " " << op;
        }
        cout << endl;
    }

    // Assemble instructions
    for (Instruction instr : instructions) {
        uint8_t instr_word = AssembleInstruction(instr);

        // invalid instruction / directive
        if (instr_word == INSTR_ERR) {
            return ASSEMBLER_ERR;
        }

        // .data directive
        if (instr_word == ASM_DATA) {
            continue;
        }

        // .text directive
        if (instr_word == ASM_TEXT) {
            if (curr_mem_addr > DATA_END) {
                cout << "Error: Too much data bro wtf (max bytes: " << 
                (DATA_END - DATA_START + 1) << ")\n";
                return ASSEMBLER_ERR;
            }
            for (; curr_mem_addr < TEXT_START; curr_mem_addr++) {
                cout << bitset<8>(0).to_string() << "\n";
                out_stream << bitset<8>(0).to_string() << "\n";
            }
            continue;
        }

        // Valid data / instruction
        curr_mem_addr++;
        #ifdef DEBUG
        cout << bitset<8>(instr_word).to_string() << "\n";
        #endif
        out_stream << bitset<8>(instr_word).to_string() << "\n";
    }

    // Padding 
    for (; curr_mem_addr <= TEXT_END; curr_mem_addr++) {
        cout << bitset<8>(0).to_string() << "\n";
        out_stream << bitset<8>(0).to_string() << "\n";
    }

    in_stream.close();
    out_stream.close();

    return 0;
}

