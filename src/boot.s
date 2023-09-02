.feature pc_assignment
.feature labels_without_colons
.feature c_comments
;.feature org_per_seg

.include "macros.s"

filebuffer = $0200

; -----------------------------------------------------------------------------------------------

.segment "BASIC"
		BASIC_UPSTART $0840, $2040

.segment "COPYLOADER"
		*= $2040

		lda $2c											; copy loader to $0400
		cmp #$08										; start of basic is $0801 (8), not $2001 (0), so must be c64
		beq in_c64_mode

in_c65_mode
		ldx #$00
:		lda loader,x
		sta $0400,x
		lda loader+256,x
		sta $0400+256,x
		inx
		bne :-
		jmp init

in_c64_mode
		ldx #$00
:		lda loader-$1800,x
		sta $0400,x
		lda loader+256-$1800,x
		sta $0400+256,x
		inx
		bne :-
		jmp init

; ----------------------------------------------------------------------------------------------------

init

		sei

		lda #$00										; enable vic 4 registers
		tax
		tay
		taz
		map
		eom

		lda #$47
		sta $d02f
		lda #$53
		sta $d02f
		eom

		lda #$41										; enable 40MHz
		sta $00

		lda #$7f										; disable CIA interrupts
		sta $dc0d
		sta $dd0d

		lda #$00										; disable IRQ raster interrupts because C65 uses raster interrupts in the ROM
		sta $d01a

		lda #$70										; Disable C65 rom protection using hypervisor trap (see mega65 manual)
		sta $d640
		eom

		lda #%11111000									; unmap c65 roms $d030 by clearing bits 3-7
		trb $d030

		cli

.include "main.s"
.include "modplay.s"

.include "loader.s"

; ----------------------------------------------------------------------------------------------------
