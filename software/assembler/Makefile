ifeq ($(wildcard .arch),)
# If .arch file does not exist, default ARCH to empty
	ARCH := 
else
	ARCH := $(shell cat .arch)
endif

# Map numeric code to architecture name and compiler
ifeq ($(ARCH),9)
    CXX := clang++
	ARCH_NAME := ARM64
else ifeq ($(ARCH),12)
    CXX := clang++
	ARCH_NAME := ARM64EC
else ifeq ($(ARCH),6)
    CXX := g++
	ARCH_NAME := AMD64
else
    CXX := g++
	ARCH_NAME := Unknown
endif

CXXFLAGS := -Wall -std=c++17
SRC := main.cpp assembler.cpp
INFILE := main.s
OUTFILE := main.bin
OUT := assemble

all: assemble

assemble: $(SRC) 
	@echo "Compiling for $(ARCH_NAME)..."
	$(CXX) $(CXXFLAGS) $(SRC) -o $(OUT)
	@echo "Build complete."

run: assemble
	@echo "Running main..."
	./$(OUT) $(INFILE) $(OUTFILE)

clean:
	@echo "Cleaning build artifacts..."
	rm -f $(OUT)

info:
	@echo "Processor Architecture: $(ARCH_NAME)"

update-arch:
	@echo "Updating architecture info..."
	@powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Architecture" > .arch

help:
	@echo "Available targets:"
	@echo "  all         - Build the main program (default)"
	@echo "  run         - Build and run main"
	@echo "  clean       - Remove build artifacts"
	@echo "  info        - Show processor architecture"
	@echo "  update-arch - Refresh architecture info"
	@echo "  help        - Show this help message"

.PHONY: all run clean info update-arch help
