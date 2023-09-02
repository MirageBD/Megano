MAKE			= make
CP				= cp
MV				= mv
RM				= rm -f

SRC_DIR			= ./src
EXE_DIR			= ./exe
BIN_DIR			= ./bin

# mega65 fork of ca65: https://github.com/dillof/cc65
AS				= ca65mega
ASFLAGS			= -g --cpu 45GS02 -U --feature force_range -I ./exe
LD				= ld65
C1541			= c1541
CC1541			= cc1541
SED				= sed
PU				= pucrunch
BBMEGA			= b2mega
LC				= crush 6
GCC				= gcc
MC				= MegaConvert

CONVERTBREAK	= 's/al [0-9A-F]* \.br_\([a-z]*\)/\0\nbreak \.br_\1/'
CONVERTWATCH	= 's/al [0-9A-F]* \.wh_\([a-z]*\)/\0\nwatch store \.wh_\1/'

CONVERTVICEMAP	= 's/al //'

.SUFFIXES: .o .s .out .bin .pu .b2 .a

default: all

OBJS = $(EXE_DIR)/boot.o $(EXE_DIR)/main.o

# % is a wildcard
# $< is the first dependency
# $@ is the target
# $^ is all dependencies

# -----------------------------------------------------------------------------

$(BIN_DIR)/bmp_charset.bin: $(BIN_DIR)/bitmap.bin
	$(MC) $< m1:1 d1:0 b1:$(BIN_DIR)/bmp_charset.bin b2:$(BIN_DIR)/bmp_screen.bin p1:$(BIN_DIR)/bmp_pal.bin

$(EXE_DIR)/boot.o: $(SRC_DIR)/boot.s $(SRC_DIR)/main.s $(SRC_DIR)/modplay.s $(SRC_DIR)/loader.s Makefile Linkfile
	$(AS) $(ASFLAGS) -o $@ $<

$(EXE_DIR)/boot.prg: $(EXE_DIR)/boot.o Linkfile
	$(LD) -Ln $(EXE_DIR)/boot.maptemp --dbgfile $(EXE_DIR)/boot.dbg -C Linkfile -o $@ $(EXE_DIR)/boot.o
	$(SED) $(CONVERTVICEMAP) < $(EXE_DIR)/boot.maptemp > boot.map
	$(SED) $(CONVERTVICEMAP) < $(EXE_DIR)/boot.maptemp > boot.list

$(EXE_DIR)/megano65.d81: $(EXE_DIR)/boot.prg $(BIN_DIR)/bmp_charset.bin $(BIN_DIR)/bmp_screen.bin $(BIN_DIR)/bmp_pal.bin
	$(RM) $@
	$(CC1541) -n "megano65" -i " 2022" -d 19 -v\
	 \
	 -f "megano65" -w $(EXE_DIR)/boot.prg \
	 -f "1" -w $(BIN_DIR)/bmp_charset.bin \
	 -f "2" -w $(BIN_DIR)/bmp_screen.bin \
	 -f "3" -w $(BIN_DIR)/bmp_pal.bin \
	 -f "4" -w $(BIN_DIR)/samples.bin \
	$@

# -----------------------------------------------------------------------------

run: $(EXE_DIR)/megano65.d81

# reset
	m65 -l COM3 -F

# deploy assets
#	mega65_ftp.exe -l COM3 -s 2000000 -c "cd /" \
#	-c "put E:\mega\Piano\bin\bmp_charset.bin bcharset.bin" \
#	-c "put E:\mega\Piano\bin\bmp_screen.bin bscreen.bin" \
#	-c "put E:\mega\Piano\bin\bmp_pal.bin bpal.bin" \
#	-c "put E:\mega\Piano\bin\samples.bin samples.bin"

	mega65_ftp.exe -l COM3 -s 2000000 -c "cd /" \
	-c "put F:\mega\Piano\exe\megano65.d81 megano65.d81"

# start prg
#	m65 -l COM3 -F -r $(EXE_DIR)/boot.prg
#	m65 -l COM3 -r $(EXE_DIR)/boot.prg
#	m65 -l COM3 -F -4 -r $(EXE_DIR)/boot.prg	# start in C64 mode

	m65 -l COM3 -F
	sleep 4
	m65 -l COM3 -T 'mount "megano65.d81"~Mload "$$"~Mlist~Mload "megano65"~Mlist~Mrun'

# start debugger
#	m65dbg --device /dev/ttyS2

clean:
	$(RM) $(EXE_DIR)/*.*
	$(RM) $(EXE_DIR)/*

