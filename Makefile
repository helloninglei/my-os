# Makefile 规则说明：https://seisman.github.io/how-to-write-makefile/introduction.html
ASM=nasm
CC=gcc

SRC_DIR=src
TOOLS_DIR=src/tools
BUILD_DIR=build

.PHONY: all floppy_image kernel bootloader clean always tools_fat

all: floppy_image tools_fat



####################################
# 说明：冒号后面的为依赖项(always表示无任何依赖)，下方的为生成方式
# floppy_image 依赖--> main_floppy.img 依赖--> bootloader、kernel
# bootloader 依赖--> bootloader.bin （生成方式：$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin）
# kernel 依赖-> kernel.bin (生成方式：$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin)
####################################

####################################
# Floppy image 
####################################
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img test.txt "::test.txt"

####################################
# Bootloader 
####################################
# bootloader依赖 --> bootloader.bin
bootloader: $(BUILD_DIR)/bootloader.bin

# bootloader.bin 生成方式
$(BUILD_DIR)/bootloader.bin: always
	$(ASM) $(SRC_DIR)/bootloader/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin

####################################
# Kernel 
####################################
# kernel 依赖 --> kernel.bin
kernel: $(BUILD_DIR)/kernel.bin

# kernel.bin 生成方式
$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin


####################################
# Tools 
####################################
tools_fat: ${BUILD_DIR}/tools/fat

$(BUILD_DIR)/tools/fat: always $(TOOLS_DIR)/fat/fat.c 
	mkdir -p $(BUILD_DIR)/tools
	$(CC) -g -W -o $(BUILD_DIR)/tools/fat $(TOOLS_DIR)/fat/fat.c


####################################
# Always 
####################################
always: 
	mkdir -p $(BUILD_DIR)


####################################
# Clean 
####################################
clean: 
	rm -rf $(BUILD_DIR)/*