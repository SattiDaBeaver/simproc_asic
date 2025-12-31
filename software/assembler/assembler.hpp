#pragma once

#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>

#define INVALID_REG     8u
#define INSTR_ERR       0x0C 
#define ASSEMBLER_ERR   -1

using namespace std;

class Instruction {
public:
    string mnemonic;
    vector<string> operands;
    int line_num;

    Instruction(string m, int l);
};

class Assembler {
private:
    vector<Instruction> instructions;
    int curr_line;

    // OpCodes
    static constexpr uint8_t ADD   = 0x04;
    static constexpr uint8_t SUB   = 0x06;
    static constexpr uint8_t NAND  = 0x08;
    static constexpr uint8_t ORI   = 0x07; // only check 3 LSB
    static constexpr uint8_t LOAD  = 0x00;
    static constexpr uint8_t STORE = 0x02;
    static constexpr uint8_t BNZ   = 0x09;
    static constexpr uint8_t BPZ   = 0x05;
    static constexpr uint8_t BZ    = 0x0A;
    // static constexpr uint8_t SHIFT = 0x03; // only check 3 LSB
    static constexpr uint8_t SHL   = 0x23; // shift left bit
    static constexpr uint8_t SHR   = 0x03; // shift right
    static constexpr uint8_t JUMP  = 0x01;

    // Mnemonic to OpCode mapping
    const unordered_map<string, uint8_t> opcode_table = {
        {"add"  , ADD},
        {"sub"  , SUB},
        {"nand" , NAND},
        {"ori"  , ORI},
        {"load" , LOAD},
        {"store", STORE},
        {"bnz"  , BNZ},
        {"bpz"  , BPZ},
        {"bz"   , BZ},
        {"shl"  , SHL},
        {"shr"  , SHR},
        {"jump" , JUMP}
    };

    // Methods
    int ParseLine(const string& line);
    uint8_t AssembleInstruction(const Instruction& instruction);
    int32_t GetValueFromString(string& str);
    uint8_t GetValueFromRegister(string& str);
    uint8_t IntToImm2(int32_t val); 
    uint8_t IntToImm4(int32_t val); 
    uint8_t IntToImm5(int32_t val);

public:
    Assembler();
    int Assemble(const string& input_file, const string& output_file);
};