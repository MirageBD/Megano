# -----------------------------------------------------------------------------

megabuild		= 0
attachdebugger	= 0

# -----------------------------------------------------------------------------

MAKE			= make
CP				= cp
MV				= mv
RM				= rm -f

SRC_DIR			= ./src
EXE_DIR			= ./exe
BIN_DIR			= ./bin

# mega65 fork of ca65: https://github.com/dillof/cc65
AS				= ca65mega
ASFLAGS			= -g -D megabuild=$(megabuild) --cpu 45GS02 -U --feature force_range -I ./exe
LD				= ld65
C1541			= c1541
CC1541			= cc1541
SED				= sed
PU				= pucrunch
BBMEGA			= b2mega
LC				= crush 6
GCC				= gcc
MC				= MegaConvert
MEGAADDRESS		= megatool -a
MEGACRUNCH		= megatool -c
MEGAIFFL		= megatool -i
MEGAMOD			= MegaMod
EL				= etherload -i 192.168.1.255
XMEGA65			= H:\xemu\xmega65.exe
MEGAFTP			= mega65_ftp -i 192.168.1.255

CONVERTBREAK	= 's/al [0-9A-F]* \.br_\([a-z]*\)/\0\nbreak \.br_\1/'
CONVERTWATCH	= 's/al [0-9A-F]* \.wh_\([a-z]*\)/\0\nwatch store \.wh_\1/'

CONVERTVICEMAP	= 's/al //'

.SUFFIXES: .o .s .out .bin .pu .b2 .a

default: all

OBJS = $(EXE_DIR)/boot.o $(EXE_DIR)/main.o

# -----------------------------------------------------------------------------

$(BIN_DIR)/bitmap_chars0.bin: $(BIN_DIR)/bitmap.bin
	$(MC) $< m1:1 d1:0 cl1:10000 rc1:0

$(EXE_DIR)/boot.o: $(SRC_DIR)/boot.s $(SRC_DIR)/main.s $(SRC_DIR)/modplay.s $(SRC_DIR)/loader.s Makefile Linkfile
	$(AS) $(ASFLAGS) -o $@ $<

$(EXE_DIR)/boot.prg: $(EXE_DIR)/boot.o Linkfile
	$(LD) -Ln $(EXE_DIR)/boot.maptemp --dbgfile $(EXE_DIR)/boot.dbg -C Linkfile -o $@ $(EXE_DIR)/boot.o
	$(SED) $(CONVERTVICEMAP) < $(EXE_DIR)/boot.maptemp > boot.map
	$(SED) $(CONVERTVICEMAP) < $(EXE_DIR)/boot.maptemp > boot.list

$(EXE_DIR)/megano65.d81: $(EXE_DIR)/boot.prg $(BIN_DIR)/bitmap_chars0.bin $(BIN_DIR)/bitmap_screen0.bin $(BIN_DIR)/bitmap_pal0.bin
	$(RM) $@
	$(CC1541) -n "megano65" -i " 2022" -d 19 -v\
	 \
	 -f "megano65" -w $(EXE_DIR)/boot.prg \
	 -f "1" -w $(BIN_DIR)/bitmap_chars0.bin \
	 -f "2" -w $(BIN_DIR)/bitmap_screen0.bin \
	 -f "3" -w $(BIN_DIR)/bitmap_pal0.bin \
	 -f "4" -w $(BIN_DIR)/samples.bin \
	$@

# -----------------------------------------------------------------------------

run: $(EXE_DIR)/megano65.d81

ifeq ($(megabuild), 1)

	$(MEGAFTP) -c "put D:\Mega\megano65\exe\megano65.d81 megano65.d81" -c "quit"
	$(EL) -m MEGANO65.D81 -r $(EXE_DIR)/boot.prg.addr
ifeq ($(attachdebugger), 1)
	m65dbg --device /dev/ttyS2
endif
else
	cmd.exe /c $(XMEGA65) -autoload -8 $(EXE_DIR)/megano65.d81
endif

clean:
	$(RM) $(EXE_DIR)/*.*
	$(RM) $(EXE_DIR)/*
