; Memory map:
;	$C100 - Grunio's OAM
;	$C150 - Carrot's OAM
;	$C170 - Carrot collision state
;	$C180 - Carrot type: black or grey/green (depends on the GameBoy's screen)
;	$C190 - Grunio's Color (Grunio/Dida)
;	$C200 - RNG seed
;	$C201 - User RNG manipulation
;	$C210 - Score
;	$C220 - "Lives" (We all know Grunio and Dida are invincible)

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
	ld	[rOBP0], a

;Setting coordinates for the viewport

	ld a, 0
	ld [rSCX], a
	ld [rSCY], a
	
	call turn_off_LCD	; We have gain access to VRAM
	
; Loading Sprites
	
	ld	hl, Sprite_Data
	ld	de, _VRAM
	ld	bc, 16*10		; 16 * number of sprites to load
	
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
	
; Let's prepare the seed for the RNG
; We can use the property of the OAM, after each reset GameBoy is filled
; with random values. This will be base for our random generator.
; We will use value of the 1st sprite.
; We will use address $C200 for the seed and
; address $C201 for our user manipulation

	ld	hl, _OAMRAM
	ld	a, [hl]
	ld	hl, $C200
	ld	[hl], a
	jp	cleaning_OAM
	
; Generating next value

generate_next_value:	
	ld	hl, $C200
	ld	a, [hl]
	ld	hl, $C201
.next_generation:
	swap a
	rlca
	xor	a, [hl]
	cp	144
	jp	c, .return_value
	jp	.next_generation
.return_value
	ld	hl, $C200
	ld	[hl], a
	ret
	
; Cleaning OAM
; SOME STUPID !@# BUGS WITHOUT IT
; Because turning on the sprite layer
; Creates some garbage in the OAM!!!
; For the faster completion, cleaning occurs only during the HBlank
; Yes, it's not perfect, but remaining garbage is not visible

cleaning_OAM:
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

; Preparing Grunio's personal space

	ld	hl, $C100
	ld	de, Grunio_OAM
	ld	b, 4*6	; 4 bytes * 6 Grunio sprites
.next_OAM_Grunio_Byte:
	ld	a, [de]
	ld	[hl], a
	dec	b
	inc	hl
	inc	de
	ld	a, b
	jp nz, .next_OAM_Grunio_Byte
	
; Preparing the carrot's space

	ld	hl, $C150
	ld	de, Carrot_OAM
	ld	b, 4*4
.next_OAM_Carrot_Byte:
	ld	a, [de]
	ld	[hl], a
	dec	b
	inc	hl
	inc	de
	ld	a, b
	jp nz, .next_OAM_Carrot_Byte
	ld	hl, $C170	; Carrot's collision state
	ld	a, 0	; State $42 = generate a new carrot
				; Since we begin a new game, generate one
	ld	[hl], a
	
; Reset score
	ld	a, 0
	ld	hl, $C210
	ld	[hl], a

; Reset "lives"
	ld	a, 3
	ld	hl, $C220
	ld	[hl], a
	
; PALETTE TEST
	ld	hl, $FF49
	ld	a, $FF
	ld	[hl], a
	ld	hl, $C153
	ld	a, [hl]
	set	4, a
	ld	[hl], a
	ld	hl, $C157
	ld	a, [hl]
	set	4, a
	ld	[hl], a

; Main loop

main_loop:
	call	wait_for_VBlank
	call	update_Carrot
	call	check_collision
	call	draw_Grunio
	call	draw_Carrot
	call	handle_input
	call	generate_next_value
.fin_vB
	jr	main_loop
	
wait_for_VBlank:
	ldh	a, [rLY]
	cp	145
	jr	nz, wait_for_VBlank
	ret

; Subroutine drawing Grunio
; So far no DMA, so the drawing occurs during the VBlank
; So this is basically my own "DMA"

draw_Grunio:
	ld	hl, $FE00
	ld	de, $C100
	ld	b, 4*6
.next_Grunio_byte:
	ld	a, [de]
	ld	[hl], a
	inc	hl
	inc	de
	dec	b
	jp	nz, .next_Grunio_byte
	ret

draw_Carrot:
	ld	hl, $FE18
	ld	de, $C150
	ld	b, 4*2
.next_Grunio_byte:
	ld	a, [de]
	ld	[hl], a
	inc	hl
	inc	de
	dec	b
	jp	nz, .next_Grunio_byte
	ld	hl, $C201	; Bigger RNG manipulation
	ld	a, [hl]
	inc	a
	ld	[hl], a
	ret
	
update_Carrot:
	ld	hl, $C170	; Let's check if we should reset the carrot after the collision
	ld	a, [hl]
	cp	$42
	jp	z, .generate_new_carrot	; If yes, generate a new carrot
	ld	hl, $C150	; The carrot's OAM
	ld	a, [hl]
	add	a, 2
	ld	[hl], a
	ld	hl, $C154
	add	a, 8
	ld	[hl], a
	ret
.generate_new_carrot:
	ld	hl, $C200
	ld	a, [hl]
	add	8
	ld	hl, $C151
	ld	[hl], a
	ld	hl, $C155
	ld	[hl], a
	ld	hl, $C150
	ld	a, 0
	ld	[hl], a
	ld	hl, $C154
	add	8
	ld	[hl], a
	ret
	
; Collision between the carrot and Grunio
	
check_collision:
; Check y collision
	ld	hl, $C150	; Carrot Y
	ld	a, [hl]
	cp	$68		; Is Carrot too high?
	jp	c, .too_high
	cp	$78		; Is Carrot at the correct height?
	jp	c, .correct_height	; Carrot is between 
	ld	hl, $C170
	ld	a, $42	; State for "reset a carrot"
	ld	[hl], a
	ld	hl, $C220	; Lose a "life"
	ld	a, [hl]
	dec	a
	ld	[hl], a
	ret
.correct_height:
; Carrot's right side and Grunio's left side
	ld	hl, $C151
	ld	a, [hl]
	add	8	; We want to compare Carrot's right side with Grunio's left side
	ld	hl, $C101
	cp	a, [hl]
	jp	c, .too_high	; Not colliding
; Carrot's left side and Grunio's right side
.check_left_side:
	ld	hl, $C101
	ld	a, [hl]
	add	a, 24	; Grunio's sprite is 24 pixel wide
	ld	hl, $C151
	cp	a, [hl]
	jp	c, .too_high	; The check is reversed in this case, so the condition is also reversed
; The conditions are fulfilled, let's add one point to score
; And reset the carrot
.collision_true:
	ld	hl, $C170
	ld	a, $42
	ld	[hl], a
	ld	hl, $C210
	ld	a, [hl]
	inc	a
	ld	[hl], a
	ret
.too_high:
	ld	hl, $C170
	ld	a, 0
	ld	[hl], a
	ret


; Handling input and moving Grunio

handle_input:
	ld	a, %11101101
	ld	[rP1], a
	ld	a, [rP1]	; Reading several times
	ld	a, [rP1]	; To secure the correct reading
	ld	a, [rP1]
	ld	a, [rP1]
	cp	%11101101	; Is "left" direction pressed?
	jp	nz, .jump_to_right
	ld	hl, $C201	; RNG user manipulation
	ld	a, [hl]
	add	a, 119		; Arbitrary value
	ld	[hl], a
	xor	[hl]
	bit	7, a
	ld	a, [$C101]	; Grunio's horizontal position
	cp	6			; Grunio's position can't be < 8
	jp	z, .jump_to_right	; We want to see entire Grunio on the screen
	ld	[hl], a
	ld	b, 6		; Moving all 6 sprites
	ld	hl, $C101
	ld	de, 2		; The offset between X positions in our "OAM"
.move_Grunio_left:
	ld	a, [hl]
	sub	3			; Move sprite 2px left
	ld	[hl], a
	inc	hl
	inc	hl
	set	5, [hl]
	add	hl, de
	dec	b
	ld	a, b
	cp	0
	jp	nz, .move_Grunio_left
	ld	b, 3		; Swapping Grunio's sprites to the left side
	ld	c, 4
	ld	de, 4
	ld	hl, $C102
	ld	a, [hl]
	cp	$06			; If Grunio is turned, don't turn him again
	jp	z, .jump_to_right
.swap_sprites_to_left:
	ld	a, [hl]
	add	c
	ld	[hl], a
	add	hl, de
	ld	a, [hl]
	add	c
	ld	[hl], a
	add	hl, de
	ld	a, c
	sub	4
	ld	c, a
	dec	b
	ld	a, b
	cp	0
	jp nz, .swap_sprites_to_left
.jump_to_right:
	cp	%11101110	; Is "right" direction pressed?
	jp	nz, .return
	ld	hl, $C201	; RNG user manipulation
	ld	a, [hl]
	add	a, 241		; Arbitrary value
	ld	[hl], a
	xor	[hl]
	bit	5, a
	ld	a, [$C101]
	cp	$92			; Grunio again can't leave the screen
	jp	z, .return
	ld	hl, $C101
	ld	b, 6
	ld	de, 4		; The offset between X positions in our "OAM"
.move_Grunio_right:
	ld	a, [hl]
	add	3
	ld	[hl], a
	add	hl, de
	dec	b
	ld	a, b
	cp	0
	jp	nz, .move_Grunio_right
	ld	b, 2		; Swapping Grunio's sprites to the right side
	ld	de, 3
	ld	hl, $C102
	ld	a, [hl]
	cp	$02			; If Grunio is turned to the right, don't turn him again
	jp	z, .return
.swap_sprites_to_right:
	ld	a, b
	ld	[hl], a
	inc	hl
	res	5, [hl]
	add	hl, de
	inc	b
	ld	a, b
	cp	$08
	jp nz, .swap_sprites_to_right	
.return:
	ret

turn_off_LCD:
	call wait_for_VBlank
							; we are in VBlank, we turn off the LCD
    ld      a,[rLCDC]     	; in A, the contents of the LCDC 
    res     7,a             ; we zero bit 7 (on the LCD)
    ld      [rLCDC],a 		; DON'T CHANGE THIS SUBROUTINE! Possible real hardware damage
	
	ret
	
Sprite_Data:
db	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
db	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
DB	$00,$00,$0F,$0F,$1F,$18,$3F,$30	; Grunio sprites start!
DB	$FF,$E0,$FF,$80,$FF,$80,$FF,$80
DB	$BF,$C0,$9F,$E0,$8F,$F3,$81,$FF
DB	$41,$7F,$27,$3F,$38,$38,$1E,$1E
DB	$00,$00,$C4,$C4,$FE,$3E,$FD,$07
DB	$FD,$06,$FF,$00,$FF,$00,$FF,$00
DB	$FF,$00,$FF,$00,$FF,$00,$00,$FF
DB	$00,$FF,$FF,$FF,$0E,$0E,$07,$07
DB	$00,$00,$00,$00,$00,$00,$80,$80
DB	$E0,$60,$F0,$10,$58,$28,$48,$38
DB	$C8,$38,$98,$78,$20,$E0,$40,$C0
DB	$80,$80,$00,$00,$00,$00,$00,$00	; Grunio end
DB 	$00,$22,$00,$14,$00,$18,$00,$10	; Carrot start
DB 	$FF,$FF,$62,$5E,$4A,$76,$6A,$56
DB 	$52,$6E,$62,$5E,$46,$7A,$56,$6A
DB 	$54,$6C,$38,$28,$30,$30,$10,$10	; Carrot end
Grunio_OAM:
db	$78, $50, $2, 0
db	$80, $50, $3, 0
db	$78, $58, $4, 0
db	$80, $58, $5, 0
db	$78, $60, $6, 0
db	$80, $60, $7, 0
Carrot_OAM:
db	$79, $00, $8, 0
db	$79, $00, $9, 0

EndTileCara: