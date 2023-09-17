# -----------------------------------------------------------------------------

megabuild		= 1
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

BINFILES  = $(BIN_DIR)/bitmap_chars0.bin
BINFILES += $(BIN_DIR)/bitmap_screen0.bin
BINFILES += $(BIN_DIR)/bitmap_pal0.bin
BINFILES += $(BIN_DIR)/samples.bin

BINFILESMC  = $(BIN_DIR)/bitmap_chars0.bin.addr.mc
BINFILESMC += $(BIN_DIR)/bitmap_screen0.bin.addr.mc
BINFILESMC += $(BIN_DIR)/bitmap_pal0.bin.addr.mc
BINFILESMC += $(BIN_DIR)/samples.bin.addr.mc

# -----------------------------------------------------------------------------

$(BIN_DIR)/bitmap_chars0.bin: $(BIN_DIR)/bitmap.bin
	$(MC) $< cm1:1 d1:0 cl1:6000 rc1:1

$(EXE_DIR)/boot.o:	$(SRC_DIR)/boot.s \
					$(SRC_DIR)/main.s \
					$(SRC_DIR)/irqload.s \
					$(SRC_DIR)/decruncher.s \
					$(SRC_DIR)/macros.s \
					$(SRC_DIR)/modplay.s \
					Makefile Linkfile
	$(AS) $(ASFLAGS) -o $@ $<

$(BIN_DIR)/alldata.bin: $(BINFILES)
	$(MEGAADDRESS) $(BIN_DIR)/bitmap_chars0.bin      00006000
	$(MEGAADDRESS) $(BIN_DIR)/bitmap_screen0.bin     00004000
	$(MEGAADDRESS) $(BIN_DIR)/bitmap_pal0.bin        00005000
	$(MEGAADDRESS) $(BIN_DIR)/samples.bin            00020000
	$(MEGACRUNCH) $(BIN_DIR)/bitmap_chars0.bin.addr
	$(MEGACRUNCH) $(BIN_DIR)/bitmap_screen0.bin.addr
	$(MEGACRUNCH) $(BIN_DIR)/bitmap_pal0.bin.addr
	$(MEGACRUNCH) $(BIN_DIR)/samples.bin.addr
	$(MEGAIFFL) $(BINFILESMC) $(BIN_DIR)/alldata.bin

$(EXE_DIR)/boot.prg.addr.mc: $(BINFILES) $(EXE_DIR)/boot.o Linkfile
	$(LD) -Ln $(EXE_DIR)/boot.maptemp --dbgfile $(EXE_DIR)/boot.dbg -C Linkfile -o $(EXE_DIR)/boot.prg $(EXE_DIR)/boot.o
	$(MEGAADDRESS) $(EXE_DIR)/boot.prg 00002100
	$(MEGACRUNCH) -e 00002100 $(EXE_DIR)/boot.prg.addr

$(EXE_DIR)/megano65.d81: $(EXE_DIR)/boot.prg.addr.mc $(BIN_DIR)/alldata.bin
	$(RM) $@
	$(CC1541) -n "megano65" -i " 2022" -d 19 -v\
	 \
	 -f "megano65" -w $(EXE_DIR)/boot.prg.addr.mc \
	 -f "megano65.ifflcrc" -w $(BIN_DIR)/alldata.bin \
	$@

# -----------------------------------------------------------------------------

run: $(EXE_DIR)/megano65.d81

ifeq ($(megabuild), 1)
	$(MEGAFTP) -c "put D:\Mega\megano\exe\megano65.d81 megano65.d81" -c "quit"
	$(EL) -m MEGANO65.D81 -r $(EXE_DIR)/boot.prg.addr.mc
ifeq ($(attachdebugger), 1)
	m65dbg --device /dev/ttyS2
endif
else
	cmd.exe /c $(XMEGA65) -autoload -8 $(EXE_DIR)/megano65.d81
endif

clean:
	$(RM) $(EXE_DIR)/*.*
	$(RM) $(EXE_DIR)/*
