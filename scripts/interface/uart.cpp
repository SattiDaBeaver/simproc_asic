#include "uart.hpp"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

UART::UART() : handle(nullptr) {

}

UART::~UART() {
    close();
}

int UART::open(const char* port_name, uint32_t baudrate) {
    if (handle != nullptr) {
        return UART_HANDLE_ALR_EXISTS;
    }

    HANDLE h = CreateFileA (
        port_name,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        0,
        nullptr
    );

    if (h == INVALID_HANDLE_VALUE) {
        return UART_INVALID_HANDLE_VAL;
    }

    // Serial port configuration
    DCB dcb = {};
    dcb.DCBlength = sizeof(DCB);

    if (!GetCommState(h, &dcb)) {
        CloseHandle(h);
        return UART_GET_COMM_STATE_ERR;
    }

    dcb.BaudRate = baudrate;
    dcb.ByteSize = 8;
    dcb.Parity = NOPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;
    dcb.fDtrControl = DTR_CONTROL_DISABLE;
    dcb.fRtsControl = RTS_CONTROL_DISABLE;

    if (!SetCommState(h, &dcb)) {
        CloseHandle(h);
        return UART_SET_COMM_STATE_ERR;
    }

    // Default timeouts (overridder by read)
    COMMTIMEOUTS timeouts = {};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutConstant = 0;
    timeouts.ReadTotalTimeoutMultiplier = 0;

    timeouts.WriteTotalTimeoutConstant = 0;
    timeouts.WriteTotalTimeoutMultiplier = 0;

    if (!SetCommTimeouts(h, &timeouts)) {
        CloseHandle(h);
        return UART_COMM_TIMEOUT_ERR;
    }
    
    handle = h;
    return UART_NO_ERR;
}

void UART::close() {
    if (handle) {
        CloseHandle((HANDLE)handle);
        handle = nullptr;
    }
}

bool UART::is_open() {
    return handle != nullptr;
}

int UART::write_byte(uint8_t byte) {
    return write (&byte, 1);
}

int UART::write(const uint8_t* data, size_t len) {
    if (handle == nullptr) {
        return UART_NO_HANDLE;
    }
    if (data == nullptr) {
        return UART_NO_DATA;
    }
    if (len == 0) {
        return UART_INVALID_LEN;
    }

    DWORD written = 0;
    if (!WriteFile((HANDLE)handle, data,
        (DWORD)len, &written, nullptr)) {
        return UART_WRITE_ERR;
    }

    return (int) written; // return number of bytes written
}

int UART::read_byte(uint8_t& byte, uint32_t timeout_ms) {
    return read (&byte, 1, timeout_ms);
}
    
int UART::read(uint8_t* buffer, size_t len, uint32_t timeout_ms) {
    if (handle == nullptr) {
        return UART_NO_HANDLE;
    }
    if (buffer == nullptr) {
        return UART_NO_DATA;
    }
    if (len == 0) {
        return UART_INVALID_LEN;
    }

    COMMTIMEOUTS timeouts = {};
    timeouts.ReadIntervalTimeout = MAXDWORD;
    timeouts.ReadTotalTimeoutConstant = timeout_ms;
    timeouts.ReadTotalTimeoutMultiplier = 0;

    if (!SetCommTimeouts((HANDLE)handle, &timeouts)) {
        return UART_COMM_TIMEOUT_ERR;
    }

    DWORD read = 0;
    if (!ReadFile((HANDLE) handle, buffer,
    (DWORD) len, &read, nullptr)) {
        return UART_READ_ERR;
    }
    return (int) read; // return bytes read
}