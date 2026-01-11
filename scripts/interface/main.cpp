#include <iostream>
#include "uart.hpp"
#include <windows.h>

using namespace std;

int main (int argc, char* argv[]) {
    UART uart;

    int baud = 1000000;

    uart.open("COM5", baud);

    int size = 3;

    // for (int i = 0; i < 256; i++) {
    //     uint8_t pkt1[] = {0x5C, 0x00, 0x00};
    //     uart.write(pkt1, size);
    // }

    uint8_t pkt1[] = {0x5C, 0x00, 0x14};
    uart.write(pkt1, size);

    int mem_depth = 256;

    for (int i = 0; i < mem_depth; i++) {
        uint8_t pkt[] = {0xA3, (uint8_t) i, 0x00};
        uart.write(pkt, size);
    }

    Sleep(10);

    uint8_t read[256];
    int read_bytes = 0;

    if ((read_bytes = uart.read(read, mem_depth, 10)) == 0) {
        cout << "No bytes read" << endl; 
        return 0;
    }

    cout << "Bytes Read    : " << read_bytes << endl;
    cout << "Bytes Expected: " << mem_depth << endl;
    
    for (int i = 0; i < mem_depth; i++) {
        cout << (int)read[i] << " ";
        if (i % 8 == 7) {
            cout << "\n";
        }
    }

    return 0;
}