INCLUDE "gbhw.inc"

SECTION "start", ROM0[$0100]
	nop
	jp	st
	
	ROM_HEADER	ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE
	
	
st:
	nop
	di
	ld	sp, $ffff
	
inicialization:
	ld	a, %11100100	;Pallete registering
	ld	[rBGP], a

;Setting coordinates for the viewport

	ld a, 0
	ld [rSCX], a
	ld [rSCY], a
	
	call turn_off_LCD	; We have gain access to VRAM
	
; Loading Sprites
	
	ld	hl, Sprite_Data
	ld	de, _VRAM
	ld	bc, 16*2		; 16 * number of sprites to load
	
.load_graphics:
	ld	a, [hl]
	ld	[de], a
	dec	bc
	ld	a, b
	or	c
	jr	z, .cls
	inc	hl
	inc	de
	jr	.load_graphics
	
; Cleaning VRAM
	
.cls:
	ld	hl, $9800
	ld	de, 32*32

.clear_screen:
	ld	a, $01
	ld	[hl], a
	dec	de
	ld	a, d
	or	e
	jp	z, .turn_on_LCD
	inc	hl
	jp	.clear_screen	
	
.turn_on_LCD:	
	ld	a, %10000010	; Turning on the LCD
	ld	[rLCDC], a	
	
; Cleaning OAM
; SOME STUPID !@# BUGS WITHOUT IT
; Because turning on the sprite layer
; Creates some garbage in the OAM!!!
; For the faster completion, cleaning occurs only during the HBlank
; Yes, it's not perfect, but remaining garbage is not visible

	ld	b, 160
	ld	hl, $FE00
	
.clean_OAM:
	ld	a, [rSTAT]
	cp	$80		; Hex 80 = HBlank is active
	jp	nz, .clean_OAM
	ld	a, 0
	ldi	[hl], a
	dec	b
	ld	a, b
	jp	nz, .clean_OAM

; Main loop

main_loop:
	call	wait_for_VBlank
.fin_vB
	jr	main_loop
	
wait_for_VBlank:
	ldh	a, [rLY]
	cp	145
	jr	nz, wait_for_VBlank
	ret

turn_off_LCD:
	call wait_for_VBlank
							; we are in VBlank, we turn off the LCD
    ld      a,[rLCDC]     	; in A, the contents of the LCDC 
    res     7,a             ; we zero bit 7 (on the LCD)
    ld      [rLCDC],a 		; DON'T CHANGE THIS SUBROUTINE! Possible real hardware damage
	
	ret
	
Sprite_Data:
db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

EndTileCara: