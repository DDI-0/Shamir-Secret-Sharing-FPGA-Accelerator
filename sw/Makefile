CC ?= gcc
CROSS_CC = arm-linux-gnueabihf-gcc
CFLAGS = -Wall -Wextra -O2 -std=c99 -D_POSIX_C_SOURCE=199309L -Iinclude

BUILD = build
SRCS = src/main.c src/fpga_driver.c src/random.c

all: $(BUILD)/shamir

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/shamir: $(SRCS) | $(BUILD)
	$(CC) $(CFLAGS) -o $@ $(SRCS)

.PHONY: cross
cross: CC = $(CROSS_CC)
cross: clean all

.PHONY: clean
clean:
	rm -rf $(BUILD)
