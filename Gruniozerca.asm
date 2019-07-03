INCLUDE "gbhw.inc"

SECTION "Copy data", ROM0[$28]
COPY_DATA:
	pop hl
	push bc
	
	ld a, 0
	ld b, a
	
	ld a, $0D
	ld c, a
	
.copy_data_loop:
	ld a, [hl]
	ld [de], a
	
	inc de
	dec bc
	
	ld a, b
	or c
	jr nz, .copy_data_loop
	
	pop bc
	jp hl
	reti

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
	
	ld a, 0		;Setting coordinates for the viewport
	ld [rSCX], a
	ld [rSCY], a
	
	call turn_off_LCD
	
	ld	hl, Sprite_Data
	ld	de, _VRAM
	ld	bc, 16*2		; 16 * number of sprites to load
	
	call DMA_Copy
	
.load_graphics:
	ld	a, [hl]
	ld	[de], a
	dec	bc
	ld	a, b
	or	c
	jr	z, .finish_loading_graphics
	inc	hl
	inc	de
	jr	.load_graphics

.finish_loading_graphics:
	ld	hl, $9800
	ld	de, 32*32
.clear_screen:
	ld	a, 1
	ld	[hl], a
	dec	de
	ld	a, d
	or	e
	jp	z, .finish_drawing
	inc	hl
	jp	.clear_screen
	
.clear_sprites:
	
	
.finish_drawing:
	ld	a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ8|LCDCF_OBJON
	ld	[rLCDC], a	
	
	ld b, 8
	ld de, $C000
	ld hl, Sprite_OAM_Data
	
.next_step:
	ld a, [hl]
	ld [de], a
	inc de
	inc hl
	dec b
	ld a, b
	jp nz, .next_step
	
main_loop:
	ld a, %11101101
	ld [rP1], a
	ld a, [rP1]
	ld a, [rP1]
	ld a, [rP1]
	ld a, [rP1]
	cp %11101101
	jp nz, .skipLeft
	ld a, [_OAMRAM+1]
	cp 8
	jp z, .skipLeft
	dec a
	ld [_OAMRAM+1], a
	ld a, [_OAMRAM+5]
	dec a
	ld [_OAMRAM+5], a
	jp .VBlank
.skipLeft:
	cp %11101110
	jp nz, .VBlank
	ld a, [_OAMRAM+1]
	cp 152
	jp z, .VBlank
	inc a
	ld [_OAMRAM+1], a
	ld a, [_OAMRAM+5]
	inc a
	ld [_OAMRAM+5], a
.VBlank:
	call wait_for_VBlank
.fin_vB
	jr	main_loop
	
wait_for_VBlank:
	ld	a, [rLY]
	cp	145
	jr	nz, wait_for_VBlank
	ret

turn_off_LCD:
	ld	a, [rLCDC]
	rlca
	ret	nc
	
.wait_screen:
	call wait_for_VBlank
							; we are in VBlank, we turn off the LCD
    ld      a,[rLCDC]       ; in A, the contents of the LCDC 
    res     7,a             ; we zero bit 7 (on the LCD)
    ld      [rLCDC],a 		; DON'T CHANGE THIS SUBROUTINE! Possible real hardware damage
	
	ret

DMA_Copy:
	ld de, $FF80
	rst $28
	
	DB $00, $0D
	DB $F5, $3E, $C0, $EA, $46, $FF, $3E, $28, $3D, $20, $FD, $F1, $D9
	ret
	
Sprite_Data:
db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

Sprite_OAM_Data:
db 120, 8, 0, 0, 120, 16, 0, 0

EndTileCara: