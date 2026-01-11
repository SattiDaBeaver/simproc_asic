#pragma once 

#include <cstdint>
#include <cstddef>

#define UART_NO_ERR             0
#define UART_GENERIC_ERR        -128

#define UART_NO_HANDLE          -1
#define UART_NO_DATA            -2
#define UART_INVALID_LEN        -3
#define UART_WRITE_ERR          -4
#define UART_READ_ERR           -5

#define UART_HANDLE_ALR_EXISTS  -6
#define UART_INVALID_HANDLE_VAL -7
#define UART_GET_COMM_STATE_ERR -8
#define UART_SET_COMM_STATE_ERR -9
#define UART_COMM_TIMEOUT_ERR   -10

class UART {
private:
    void* handle;
public:
    UART();
    ~UART();

    // Open / Close
    int open(const char* port_name, uint32_t baudrate);
    void close();

    bool is_open();

    // Write
    int write_byte(uint8_t byte);
    int write(const uint8_t* data, size_t len);

    // Read
    int read_byte(uint8_t& byte, uint32_t timeout_ms);
    int read(uint8_t* buffer, size_t len, uint32_t timeout_ms);
};