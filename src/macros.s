.define COLOR_RAM $ff80000

.macro DMA_RUN_JOB jobPointer
		lda #(jobPointer & $ff0000) >> 16
		sta $d702
		sta $d704
		lda #>jobPointer
		sta $d701
		lda #<jobPointer
		sta $d705
.endmacro

.macro DMA_HEADER sourceBank, destBank
		; f018a = 11 bytes, f018b is 12 bytes
		.byte $0a ; Request format is F018A
		.byte $80, sourceBank
		.byte $81, destBank
.endmacro

.macro DMA_FILL_JOB sourceByte, destination, length, chain
.scope
	.byte $00 ; No more options
	.if chain
		.byte $07 ; Fill and chain
	.else
		.byte $03 ; Fill and last request|
	.endif

	.word length ; Size of Copy
	.word sourceByte
	.byte $00
	.word destination & $ffff
	.byte ((destination >> 16) & $0f)

	.if chain
		.word $0000
	.endif
.endscope
.endmacro

.macro FLOPPY_LOAD addr, fname
.scope
			bra :+
FileName	.byte .sprintf("%s", fname), 0
:			lda #addr >> 20
			sta mbank+1
			lda #<addr
			ldx #>addr
			ldy #(addr & $f0000) >> 16
			jsr SetLoadAddress
			ldx #<FileName
			ldy #>FileName
			jsr LoadFile
.endscope
.endmacro

.macro SD_LOAD_CHIPRAM addr, fname
.scope
			bra :+
FileName	.byte .sprintf("%s", fname), 0
:			lda #>FileName
			ldx #<FileName

			sta FileNameI+2
			stx FileNameI+1

			ldx #$00
FileNameI	lda $babe,x
			sta filebuffer,x
			inx
			bne FileNameI

			ldx #<filebuffer							; Make hypervisor call to set filename to load
			ldy #>filebuffer
			lda #$2e
			sta $d640									; Mega65.HTRAP00
			eom											; Wasted instruction slot required following hyper trap instruction

			ldx #<addr
			ldy #>addr
			ldz #(addr & $ff0000) >> 16

			lda #$36									; $36 for chip RAM at $00ZZYYXX
			sta $d640									; Mega65.HTRAP00
			eom											; Wasted instruction slot required following hyper trap instruction
			bcs :+
			inc $d021
:			
			; XXX Check for error (carry would be clear)
.endscope
.endmacro

.macro SD_LOAD_ATTICRAM addr, fname
.scope
			bra :+
FileName	.byte .sprintf("%s", fname), 0
:			lda #>FileName
			ldx #<FileName

			sta FileNameI+2
			stx FileNameI+1

			ldx #$00
FileNameI	lda $babe,x
			sta filebuffer,x
			inx
			bne FileNameI

			ldx #<addr
			ldy #>addr
			ldz #(addr & $ff0000) >> 16

			lda #$3e									; $3E for Attic RAM at $8000000 + $00ZZYYXX 
			sta $d640									; Mega65.HTRAP00
			eom											; Wasted instruction slot required following hyper trap instruction

			; XXX Check for error (carry would be clear)
.endscope
.endmacro

.macro BASIC_UPSTART addr64, addr65
			.byte $01, $20								; $2001 start address

line10		.word line20								; end of command marker (first byte after the 00 terminator)
			.word 10									; 10
			.byte $8b, $c2								; if peek
			.byte $28, $34, $34, $29					; (44)
			.byte $b2									; ==
			.byte $38									; 8
			.byte $a7									; then
			.byte $9e									; sys xxxx
			.byte .sprintf("%d", addr64)
			.byte $00

line20		.word line30
			.word 20									; 20
			.byte $fe, $02								; bank
			.byte $30									; 0
			.byte 0

line30		.word basicend
			.byte 30, $00								; 30
			.byte $9e									; sys xxxx
			.byte .sprintf("%d", addr65)				; sys xxxx
			.byte 0

basicend	.byte 0
			.byte 0
.endmacro
