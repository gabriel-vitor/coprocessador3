C_FILE = main
S_FILE = assembly
TARGET = main

all: $(S_FILE).o $(C_FILE).o $(TARGET)
	@echo "Compilation complete"

$(S_FILE).o: $(S_FILE).s
	as -o $(S_FILE).o $(S_FILE).s

$(C_FILE).o: $(C_FILE).c header.h
	gcc -std=c99 -Wall -c -o $(C_FILE).o $(C_FILE).c

$(TARGET): $(S_FILE).o $(C_FILE).o
	gcc -o $(TARGET) $(S_FILE).o $(C_FILE).o

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f *.o $(TARGET)

debug: $(TARGET)
	gdb $(TARGET)

