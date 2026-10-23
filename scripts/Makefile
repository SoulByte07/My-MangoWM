CC ?= gcc
CFLAGS ?= -O3 -Wall -Wextra -pedantic
TARGET = system_monitor

all: $(TARGET)

$(TARGET): system_monitor.c
	$(CC) $(CFLAGS) -o $(TARGET) system_monitor.c

clean:
	rm -f $(TARGET)

.PHONY: all clean
