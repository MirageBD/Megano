main

		;SD_LOAD_CHIPRAM $6000, "bcharset.bin"
		;SD_LOAD_CHIPRAM $3000, "bscreen.bin"
		;SD_LOAD_CHIPRAM $4000, "bpal.bin"
		;SD_LOAD_CHIPRAM $20000, "samples.bin"

		FLOPPY_LOAD $6000, "1"
		FLOPPY_LOAD $3000, "2"
		FLOPPY_LOAD $4000, "3"
		FLOPPY_LOAD $20000, "4"

.define keys $3000
.define screen $c000

.define emptychar $4400

; ----------------------------------------------------------------------------------------------------

		sei
		lda #$35
		sta $01
		
		lda #65
		sta $00

		lda #$00										; disable hotreg
		sta $d05d

		lda #%00100000									; disable PALEMU
		trb $d054

		lda #$00
		sta $d020
		lda #$00
		sta $d021

														; FCLRHI enable full-colour mode for character numbers >$FF
														; CHR16 enable 16-bit character numbers (two screen bytes per character)
		lda #%00000101									; enable Super-Extended Attribute Mode by asserting the FCLRHI and CHR16 signals - set bits 2 and 0 of $D054.
		sta $d054

		ldx #$00
		lda #$00
:		sta emptychar,x
		inx
		cpx #$40
		bne :-

		lda #$7f										; disable CIA
		sta $dc0d
		sta $dd0d

		lda #$a0										; setup IRQ interrupt
		sta $d012
		lda $d011
		and #$7f
		sta $d011
		lda #<irq1
		sta $fffe
		lda #>irq1
		sta $ffff

		lda #$01										; ACK
		sta $d01a

		cli
		
; ----------------------------------------------------------------------------------------------------

		lda #%10000000									; disable 80 columns and disable extended attributes
		trb $d031

		;lda #<$6000									; set pointer to character set
		;sta $d068
		;lda #>$6000
		;sta $d069
		;lda #($6000 & $ff0000) >> 16
		;sta $d06a

		DMA_RUN_JOB clearcolorramjob
		DMA_RUN_JOB clearscreenjob

		lda #<$c000										; set pointer to screen ram
		sta $d060
		lda #>$c000
		sta $d061
		lda #($c000 & $ff0000) >> 16
		sta $d062
		lda #$00
		sta $d063

		;.const COLOR_RAM = $ff80000 ; (bank 255)

		lda #<$0000										; set (offset!) pointer to colour ram
		sta $d064
		lda #>$0000
		sta $d065

		lda $d070										; select mapped bank with the upper 2 bits of $d070
		and #%00111111
		sta $d070

		ldx #$00										; set charset palette
:		lda $4000,x
		sta $d100,x
		lda $4100,x
		sta $d200,x
		lda $4200,x
		sta $d300,x
		inx
		bne :-

		lda $d070
		and #%11001111									; clear bits 4 and 5 (BTPALSEL) so bitmap uses palette 0
		sta $d070

		; ----------------------------------------------- screen

		;lda #40										; Display Row Width ($D05E LSB, bits 4 – 5 of $D063 MSB)
		;sta $d05e
		;lda #$00
		;sta $d063

		lda #80											; logical chars per row
		sta $d058
		lda #$00
		sta $d059

		; turn off saturation
		LDA #$00
		STA $d712

		lda #120
		sta $d05a
		lda #$01
		sta $d05b

loop
		lda $0800
		;inc $5000
		jmp loop

; ----------------------------------------------------------------------------------------------------

.align 256

irq1
		php
		pha
		txa
		pha
		tya
		pha

		lda #$00
		sta $d418
		sta $d438
		sta $d458
		sta $d478

		lda #$00
		sta $d020

		;jsr drawkeyboard

		ldx #$00
		lda #$00
:		sta keyspressed,x
		inx
		cpx #34
		bne :-

		ldy #$00
		ldx #$00
testkeymatrix
		lda rows,x
		sta $d614
		lda $d613
		cmp #$ff
		beq :+
		lda columns,x
		and $d613
		bne :+
		txa
		clc
		lda #$01
		sta keyspressed,x
		iny
:		inx
		cpx #34
		bne testkeymatrix

		ldy #$00

testnextkey
		; update keyboard index mask
		lda #%00000000
		sta keyboardmask
		lda keyspressed,y
		beq testplaysample
		lda #%00000001
		sta keyboardmask

testplaysample
		; check if we need to play a sample
		lda keyspressed,y
		beq testnext3								; 0, not pressed. don't play sample and continue
		cmp prevkeyspressed,y
		beq testnext3								; same as previous state. don't play sample and continue
		
		jsr mpPlaySample

testnext3
		lda iswhitekey,y							; black key - skip to next white key
		bne dolefthalf
		jmp testkeyend

		; draw left side of key
dolefthalf
		lda keyindices,y
		sta keyoffs
		lda screenoffsindices,y
		sta screenoffs
		lda hasblacktoleft,y
		beq :++
		lda keyspressed-1,y							; when drawing the left half of the key, the black key to the left is also the 'own' black key
		beq :+
		lda keyboardmask
		ora #%00000010
		sta keyboardmask
:		lda keyspressed-2,y							; black key to left, so white key to left is -2
		beq :++
		lda keyboardmask
		ora #%00000100
		sta keyboardmask
		jmp :++
:		lda keyspressed-1,y							; no black key to left, so white key to left is -1
		beq :+
		lda keyboardmask
		ora #%00000100
		sta keyboardmask
:
		jsr drawkeyhalf

dorighthalf
		; draw right side of key
		lda #%00000000
		sta keyboardmask
		lda keyspressed,y
		beq :+
		lda #%00000001
		sta keyboardmask
:		clc
		lda keyindices,y
		adc #$02
		sta keyoffs
		clc
		lda screenoffsindices,y
		adc #$02
		sta screenoffs

		lda hasblacktoright,y
		beq :+
		lda keyspressed+1,y							; when drawing the right half of the key, the black key to the left is not the 'own' black key
		beq :+
		lda keyboardmask
		ora #%00000010
		sta keyboardmask
:		lda hasblacktoleft,y
		beq :++
:		lda keyspressed-1,y							; black key to left, so white key to left is -2
		beq :+
		lda keyboardmask
		ora #%00001000
		sta keyboardmask
:

		jsr drawkeyhalf

testkeyend
		iny
		cpy #34
		beq testkeyend2
		jmp testnextkey
testkeyend2

		ldx #$00
:		lda keyspressed,x
		sta prevkeyspressed,x
		inx
		cpx #34
		bne :-

		lda #$00
		sta $d020

		pla
		tay
		pla
		tax
		pla
		plp

		asl $d019
		rti

.align 256

; ----------------------------------------------------------------------------------------------------

rows
.byte 1 ; z
.byte 1 ; s
.byte 2 ; x
.byte 2 ; d
.byte 2 ; c
.byte 3 ; v
.byte 3 ; g
.byte 3 ; b
.byte 3 ; h
.byte 4 ; n
.byte 4 ; j
.byte 4 ; m

.byte 7 ; q
.byte 7 ; 2
.byte 1 ; w
.byte 1 ; 3
.byte 1 ; e
.byte 2 ; r
.byte 2 ; 5
.byte 2 ; t
.byte 2 ; 6
.byte 3 ; y
.byte 3 ; 7
.byte 3 ; u

.byte 4 ; i
.byte 4 ; 9
.byte 4 ; o
.byte 4 ; 0
.byte 5 ; p
.byte 5 ; @
.byte 5 ; -
.byte 6 ; *
.byte 6 ; £
.byte 6 ; up arrow?

columns
.byte 1<<4 ; z
.byte 1<<5 ; s
.byte 1<<7 ; x
.byte 1<<2 ; d
.byte 1<<4 ; c
.byte 1<<7 ; v
.byte 1<<2 ; g
.byte 1<<4 ; b
.byte 1<<5 ; h
.byte 1<<7 ; n
.byte 1<<2 ; j
.byte 1<<4 ; m

.byte 1<<6 ; q
.byte 1<<3 ; 2
.byte 1<<1 ; w
.byte 1<<0 ; 3
.byte 1<<6 ; e
.byte 1<<1 ; r
.byte 1<<0 ; 5
.byte 1<<6 ; t
.byte 1<<3 ; 6
.byte 1<<1 ; y
.byte 1<<0 ; 7
.byte 1<<6 ; u

.byte 1<<1 ; i
.byte 1<<0 ; 9
.byte 1<<6 ; o
.byte 1<<3 ; 0
.byte 1<<1 ; p
.byte 1<<6 ; @
.byte 1<<3 ; -
.byte 1<<1 ; *
.byte 1<<0 ; £
.byte 1<<6 ; up arrow

keyspressedshifted
.byte 0, 0

keyspressed
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;     z  s  x  d  c  v  g  b  h  n  j  m
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;     q  2  w  3  e  r  5  t  6  y  7  u
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;     i  9  o  0  p  @  -  *  £  ua

prevkeyspressed
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;     z  s  x  d  c  v  g  b  h  n  j  m
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;     q  2  w  3  e  r  5  t  6  y  7  u
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
;     i  9  o  0  p  @  -  *  £  ua

keyindices
.byte 0*2, 0*2, 2*2, 0*2, 4*2, 6*2, 0*2, 8*2, 0*2, 10*2, 0*2, 12*2
.byte 0*2, 0*2, 2*2, 0*2, 4*2, 6*2, 0*2, 8*2, 0*2, 10*2, 0*2, 12*2
.byte 0*2, 0*2, 2*2, 0*2, 4*2, 6*2, 0*2, 8*2, 0*2, 10*2, 0*2, 12*2

screenoffsindices
.byte  2*0,  2*0,  2*2,  2*0,  2*4,  2*6,  2*0,  2*8,  2*0, 2*10,  2*0, 2*12
.byte 2*14,  2*0, 2*16,  2*0, 2*18, 2*20,  2*0, 2*22,  2*0, 2*24,  2*0, 2*26
.byte 2*28,  2*0, 2*30,  2*0, 2*32, 2*34,  2*0, 2*36,  2*0, 2*38,  2*0, 2*26

hasblacktoleft
.byte 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1
.byte 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1
.byte 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1

hasblacktoright
.byte 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0
.byte 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0
.byte 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 0

iswhitekey
.byte 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1
.byte 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1
.byte 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1

keybremap
.byte 0, 1, 2, 3, 0, 4, 2, 5
.byte 6, 7, 2, 5, 2, 5, 2, 5

; ----------------------------------------------------------------------------------------------------

drawkeyboard

		lda #$00
		sta keyboardmask

		ldy #$00
:		tya
		sta keyoffs
		sta screenoffs
		jsr drawkeyhalf
		iny
		iny
		tya
		sta keyoffs
		sta screenoffs
		jsr drawkeyhalf
		iny
		iny
		cpy #14*2
		bne :-

		ldy #$00
:		tya
		sta keyoffs
		clc
		adc #14*2
		sta screenoffs
		jsr drawkeyhalf
		iny
		iny
		tya
		sta keyoffs
		clc
		adc #14*2
		sta screenoffs
		jsr drawkeyhalf
		iny
		iny
		cpy #14*2
		bne :-

		ldy #$00
:		tya
		sta keyoffs
		clc
		adc #(14*2+14*2)
		sta screenoffs
		jsr drawkeyhalf
		iny
		iny
		tya
		sta keyoffs
		clc
		adc #(14*2+14*2)
		sta screenoffs
		jsr drawkeyhalf
		iny
		iny
		cpy #12*2
		bne :-

		rts

; ----------------------------------------------------------------------------------------------------

keyboardmask
.byte 0
keyboard
.byte 0
keyoffs
.byte 2
screenoffs
.byte 20

drawkeyhalf

		ldx keyboardmask
		lda keybremap,x
		sta keyboard
		tax

		clc
		lda keyboffslo,x
		adc keyoffs
		sta dkls1+1
		lda keyboffshi,x
		adc #00
		sta dkls1+2

		clc
		lda #<screen
		adc screenoffs
		sta dkld1+1
		lda #>screen
		adc #00
		sta dkld1+2

		clc
		lda dkls1+1
		adc #1
		sta dkls2+1
		lda dkls1+2
		adc #0
		sta dkls2+2

		clc
		lda dkld1+1
		adc #1
		sta dkld2+1
		lda dkld1+2
		adc #0
		sta dkld2+2

		jmp drawkeyloop

		rts

; ----------------------------------------------------------------------------------------------------

drawkeyloop

		ldx #$00

dkls1	lda keys
dkld1	sta screen
dkls2	lda keys+1
dkld2	sta screen+1

		jsr copykeyincsrc
		jsr copykeyincdst

		inx
		cpx #11
		bne dkls1

		rts

; ----------------------------------------------------------------------------------------------------

copykeyincsrc

		clc
		lda dkls1+1
		adc #14*2
		sta dkls1+1
		lda dkls1+2
		adc #00
		sta dkls1+2

		clc
		lda dkls2+1
		adc #14*2
		sta dkls2+1
		lda dkls2+2
		adc #00
		sta dkls2+2

		rts

; ----------------------------------------------------------------------------------------------------

copykeyincdst

		clc
		lda dkld1+1
		adc #80
		sta dkld1+1
		lda dkld1+2
		adc #00
		sta dkld1+2

		clc
		lda dkld2+1
		adc #80
		sta dkld2+1
		lda dkld2+2
		adc #00
		sta dkld2+2

		rts

; ----------------------------------------------------------------------------------------------------

keyboffslo

.byte <(keys+0*28*11)
.byte <(keys+1*28*11)
.byte <(keys+2*28*11)
.byte <(keys+3*28*11)
.byte <(keys+4*28*11)
.byte <(keys+5*28*11)
.byte <(keys+6*28*11)
.byte <(keys+7*28*11)

keyboffshi

.byte >(keys+0*28*11)
.byte >(keys+1*28*11)
.byte >(keys+2*28*11)
.byte >(keys+3*28*11)
.byte >(keys+4*28*11)
.byte >(keys+5*28*11)
.byte >(keys+6*28*11)
.byte >(keys+7*28*11)

; ----------------------------------------------------------------------------------------------------

/*
	Bit(s) Function when GOTOX bit is cleared

	Screen RAM byte 0
		Bits 7 - 0 Lower 8 bits of character number, the same as the VIC-II and	VIC-III

	Screen RAM byte 1
		Bits 7 – 5 Trim pixels from right-hand side of character (bits 0 – 2)
		Bits 4 - 0 Upper 5 bits of character number (bits 8 – 12), allowing	addressing of 8,192 unique characters

	Colour RAM byte 0
		Bit 7 Vertically flip the character
		Bit 6 Horizontally flip the character
		Bit 5 Alpha blend mode (leave 0, discussed later)
		Bit 4
			GOTOX is cleared (set to 0)
			GOTOX allows repositioning of characters along a raster via the
			Raster-Rewrite Buffer, discussed later). Must be set to 0 for
			displaying characters
		Bit 3
			If set, Full-Colour characters use 4 bits per pixel and are 16 pixels
			wide (less any right-hand side trim bits), instead of using 8 bits per
			pixel. When using 8 bits per pixels, the characters are the normal
			8 pixels wide
		Bit 2 Trim pixels from right-hand side of character (bit 3)
		Bits 1 – 0 Number of pixels to trim from top or bottom of character

	Colour RAM byte 1
		If VIC-II multi-colour mode is enabled:
			Bits 7 – 4 Upper 4 bits of colour of character
		If VIC-III extended attributes are enabled:
			Bit 7 Hardware underlining of character
			Bit(s) Function when GOTOX bit is cleared
				Bit 6 Hardware bold attribute of character *
				Bit 5 Hardware reverse video enable of character *
				Bit 4 Hardware blink of character
			Remaining bit-field is common:
				Bits 3 – 0 Low 4 bits of colour of character
*/

clearcolorramjob
				.byte $0a										; Request format (f018a = 11 bytes (Command MSB is $00), f018b is 12 bytes (Extra Command MSB))
				.byte $80, $00									; source megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $81, COLOR_RAM >> 20						; dest megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $84, $00									; Destination skip rate (256ths of bytes)
				.byte $85, $02									; Destination skip rate (whole bytes)

				.byte $00										; No more options

																; 12 byte DMA List structure starts here
				.byte %00000111									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 40*25										; Count LSB + Count MSB

				.word $0000										; this is normally the source addres, but contains the fill value now
				.byte $00										; source bank (ignored)

				.word COLOR_RAM & $ffff							; Destination Address LSB + Destination Address MSB
				.byte ((COLOR_RAM >> 16) & $0f)					; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000									; Command MSB

				.word $0000

				.byte $00										; No more options
				.byte %00000011									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 40*25										; Count LSB + Count MSB

				.word $0000										; this is normally the source addres, but contains the fill value now
				.byte $00										; source bank (ignored)

				.word (COLOR_RAM+1) & $ffff						; Destination Address LSB + Destination Address MSB
				.byte (((COLOR_RAM+1) >> 16) & $0f)				; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000								; Command MSB

				.word $0000

clearscreenjob
				.byte $0a										; Request format (f018a = 11 bytes (Command MSB is $00), f018b is 12 bytes (Extra Command MSB))
				.byte $80, $00									; source megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $81, screen >> 20							; dest megabyte   ($0000000 >> 20) ($00 is  chip ram)
				.byte $84, $00									; Destination skip rate (256ths of bytes)
				.byte $85, $02									; Destination skip rate (whole bytes)

				.byte $00										; No more options

																; 12 byte DMA List structure starts here
				.byte %00000111									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 40*25										; Count LSB + Count MSB

				.word <(emptychar/64)									; this is normally the source addres, but contains the fill value now
				.byte $00										; source bank (ignored)

				.word screen & $ffff							; Destination Address LSB + Destination Address MSB
				.byte ((screen >> 16) & $0f)					; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000								; Command MSB

				.word $0000

				.byte $00										; No more options
				.byte %00000011									; Command LSB
																;     0–1 DMA Operation Type (Only Copy and Fill implemented at the time of writing)
																;             %00 = Copy
																;             %01 = Mix (via MINTERMs)
																;             %10 = Swap
																;             %11 = Fill
																;       2 Chain (i.e., another DMA list follows)
																;       3 Yield to interrupts
																;       4 MINTERM -SA,-DA bit
																;       5 MINTERM -SA, DA bit
																;       6 MINTERM  SA,-DA bit
																;       7 MINTERM  SA, DA bit

				.word 40*25										; Count LSB + Count MSB

				.word >(emptychar/64)							; this is normally the source addres, but contains the fill value now
				.byte $00										; source bank (ignored)

				.word (screen+1) & $ffff						; Destination Address LSB + Destination Address MSB
				.byte (((screen+1) >> 16) & $0f)				; Destination Address BANK and FLAGS (copy to rbBaseMem)
																;     0–3 Memory BANK within the selected MB (0-15)
																;       4 HOLD,      i.e., do not change the address
																;       5 MODULO,    i.e., apply the MODULO field to wraparound within a limited memory space
																;       6 DIRECTION. If set, then the address is decremented instead of incremented.
																;       7 I/O.       If set, then I/O registers are visible during the DMA controller at $D000 – $DFFF.
				;.byte %00000000									; Command MSB

				.word $0000
