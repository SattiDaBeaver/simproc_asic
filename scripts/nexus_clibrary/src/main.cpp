#include <iostream>
#include <string>
#include <windows.h>

using namespace std;

class SerialPort {
private:
    HANDLE hSerial;

public:
    // Constructor
    SerialPort() {
        hSerial = INVALID_HANDLE_VALUE;
    }

    // Open the serial port
    bool openPort(const string& portName, int baudRate = 9600) {
        // Open the serial port
        // Use CreateFileA for ANSI string, CreateFileW for wide strings
        hSerial = CreateFileA(portName.c_str(),
                             GENERIC_READ | GENERIC_WRITE,  // Read and write access
                             0,                             // No sharing
                             NULL,                          // Default security attributes
                             OPEN_EXISTING,                 // Port must exist
                             FILE_ATTRIBUTE_NORMAL,         // Normal file attributes
                             NULL);                         // No template file

        if (hSerial == INVALID_HANDLE_VALUE) {
            DWORD error = GetLastError();
            cerr << "Error opening port " << portName << " (Error code: " << error << ")" << endl;
            return false;
        }

        // Get current port configuration
        DCB dcbSerialParams = {0};  // Device Control Block
        dcbSerialParams.DCBlength = sizeof(dcbSerialParams);
        
        if (!GetCommState(hSerial, &dcbSerialParams)) {
            cerr << "Error getting current port configuration" << endl;
            closePort();
            return false;
        }

        // Set serial port parameters (8N1 configuration)
        dcbSerialParams.BaudRate = baudRate;        // Baud rate (9600, 115200, etc.)
        dcbSerialParams.ByteSize = 8;               // 8 data bits
        dcbSerialParams.StopBits = ONESTOPBIT;      // 1 stop bit
        dcbSerialParams.Parity = NOPARITY;          // No parity bit
        dcbSerialParams.fDtrControl = DTR_CONTROL_ENABLE;  // Enable DTR
        dcbSerialParams.fRtsControl = RTS_CONTROL_ENABLE;  // Enable RTS

        // Apply the configuration
        if (!SetCommState(hSerial, &dcbSerialParams)) {
            cerr << "Error setting port configuration" << endl;
            closePort();
            return false;
        }

        // Set timeout values (in milliseconds)
        COMMTIMEOUTS timeouts = {0};
        timeouts.ReadIntervalTimeout = 50;          // Max time between chars (ms)
        timeouts.ReadTotalTimeoutConstant = 50;     // Total read timeout base (ms)
        timeouts.ReadTotalTimeoutMultiplier = 10;   // Per-byte read timeout (ms)
        timeouts.WriteTotalTimeoutConstant = 50;    // Total write timeout (ms)
        timeouts.WriteTotalTimeoutMultiplier = 10;  // Per-byte write timeout (ms)
        
        if (!SetCommTimeouts(hSerial, &timeouts)) {
            cerr << "Error setting timeout values" << endl;
            closePort();
            return false;
        }

        // Clear any existing data in the buffers
        PurgeComm(hSerial, PURGE_RXCLEAR | PURGE_TXCLEAR);

        cout << "Successfully opened " << portName << " at " << baudRate << " baud (8N1)" << endl;
        return true;
    }

    // Send data over serial port
    bool sendData(const string& data) {
        if (!isOpen()) {
            cerr << "Port is not open" << endl;
            return false;
        }

        DWORD bytesWritten = 0;
        bool success = WriteFile(hSerial,                    // Handle to file
                                data.c_str(),               // Data to write
                                (DWORD)data.length(),       // Number of bytes to write
                                &bytesWritten,              // Number of bytes actually written
                                NULL);                      // Overlapped I/O (not used)

        if (!success) {
            DWORD error = GetLastError();
            cerr << "Error writing to port (Error code: " << error << ")" << endl;
            return false;
        }

        cout << "Sent " << bytesWritten << " bytes: \"" << data << "\"" << endl;
        return true;
    }

    // Read data from serial port
    string readData(int maxBytes = 256) {
        if (!isOpen()) {
            cerr << "Port is not open" << endl;
            return "";
        }

        char buffer[1024];  // Read buffer
        DWORD bytesRead = 0;
        string result;

        // Ensure we don't read more than buffer size
        if (maxBytes > sizeof(buffer) - 1) {
            maxBytes = sizeof(buffer) - 1;
        }

        bool success = ReadFile(hSerial,           // Handle to file
                               buffer,            // Buffer to store data
                               maxBytes,          // Maximum bytes to read
                               &bytesRead,        // Actual bytes read
                               NULL);             // Overlapped I/O (not used)

        if (success && bytesRead > 0) {
            buffer[bytesRead] = '\0';  // Null-terminate the string
            result = string(buffer, bytesRead);
            cout << "Received " << bytesRead << " bytes: \"" << result << "\"" << endl;
        } else if (!success) {
            DWORD error = GetLastError();
            cerr << "Error reading from port (Error code: " << error << ")" << endl;
        }
        // If bytesRead == 0, it just means no data was available (timeout)

        return result;
    }

    // Check if port is open and valid
    bool isOpen() {
        return hSerial != INVALID_HANDLE_VALUE;
    }

    // Close the serial port
    void closePort() {
        if (hSerial != INVALID_HANDLE_VALUE) {
            CloseHandle(hSerial);
            hSerial = INVALID_HANDLE_VALUE;
            cout << "Serial port closed" << endl;
        }
    }

    // Destructor - automatically close port
    ~SerialPort() {
        closePort();
    }
};

// Example usage and testing
int main(int argc, char* argv[]) {
    SerialPort serial;
    if (argc != 2) {
        cout << "Invalid number of arguments" << endl;
        return -1;
    }
    // Common Windows COM port names: COM1, COM2, COM3, etc.
    // Check Device Manager -> Ports (COM & LPT) to see available ports
    string portName = argv[1];  // Change this to match your device
    int baudRate = 921600;            // Common baud rates: 9600, 19200, 38400, 57600, 115200

    cout << "Windows Serial Communication Test" << endl;
    cout << "=================================" << endl;

    // Try to open the serial port
    if (!serial.openPort(portName, baudRate)) {
        cerr << "Failed to open " << portName << endl;
        cout << "\nTips:" << endl;
        cout << "- Check Device Manager for correct COM port number" << endl;
        cout << "- Make sure no other program is using the port" << endl;
        cout << "- Verify the device is connected and drivers are installed" << endl;
        return -1;
    }
    
    cout << "\n--- Test 3: Interactive mode ---" << endl;
    cout << "Type commands to send (or 'quit' to exit):" << endl;
    
    string userInput;
    while (true) {
        cout << "Send> ";
        getline(cin, userInput);
        
        if (userInput == "quit" || userInput == "exit") {
            break;
        }
        
        // Send user input (add line ending if not present)
        if (!userInput.empty()) {
            if (userInput.back() != '\n') {
                userInput += "\r\n";
            }
            serial.sendData(userInput);
            
            // Wait a bit and try to read response
            Sleep(200);
            serial.readData();
        }
    }
    
    cout << "\nTest completed. Port will be closed automatically." << endl;
    
    // Port is automatically closed by destructor
    return 0;
}