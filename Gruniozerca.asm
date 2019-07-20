; Gruniożerca
; GameBoy version by Grzegorz Bydełek
; Original concept: Łukasz Kur, Ryszard Brzukała

; Memory map:
;	$C100 - Grunio's OAM	(6 sprites * 4 bytes)
;	$C150 - Carrot's OAM	(2 sprites * 4 bytes)
;	$C170 - Carrot collision state ($00 = Don't reset/no collision, $42 = reset/collision occured)
;	$C180 - Carrot type: "black" or "white" ($12 = "white", $34 = "black")
;	$C190 - Grunio's Colour ($12 = Dzidzia ("white"), $34 = Grunio ("Black")
;			NOTE: In the following code "Grunio" means either Grunio or Dzidzia
;	$C200 - RNG seed
;	$C201 - User RNG manipulation
;	$C210 - Score first 2 digits (BCD)
;	$C211 - Score last 2 digits (BCD)
;	$C212 - Hi-score first 2 digits (BCD)
;	$C213 - Hi-score last 2 digits (BCD)
;	$C220 - "Lives" (We all know Grunio and Dzidzia are invincible)
;	$C230 - Anti-autofire state (0 = not pressed in the last frame; 1 = pressed in the last frame)

INCLUDE "gbhw.inc"	; The hardware definition I use is named like this, change this line
					; or rename your file if you need

GRUNIO_OAM				EQU	$C100
CARROT_OAM				EQU	$C150
CARROT_COLLISION_STATE	EQU	$C170
CARROT_TYPE				EQU	$C180
GRUNIO_COLOUR			EQU	$C190
RNG_SEED				EQU	$C200
USER_RNG_MANIPULATION	EQU	$C201
SCORE_HIGH_BYTE			EQU	$C210
SCORE_LOW_BYTE			EQU	$C211
HI_SCORE_HIGH_BYTE		EQU	$C212
HI_SCORE_LOW_BYTE		EQU	$C213
LIVES					EQU	$C220
ANTI_AUTOFIRE			EQU	$C230

SECTION "start", ROM0[$0100]
	nop
	jp	st
	
	ROM_HEADER	ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE
	
	
st:
	nop
	di
	ld	sp, $ffff
	
inicialization:
	ld	a, %11100100	; Default pallete
	ld	[rBGP], a

; Setting coordinates for the viewport to (0, 0)

	ld a, 0
	ld [rSCX], a
	ld [rSCY], a
	
	call turn_off_LCD	; We have to gain access to VRAM
	
; Loading Sprites
	
	ld	hl, Sprite_Data
	ld	de, _VRAM
	ld	bc, 16*198		; 16 * number of sprites to load
	
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
	
; Cleaning tiles
	
.cls:
	ld	hl, $9800
	ld	de, 32*32
.clear_screen:
	ld	a, $00
	ld	[hl], a
	dec	de
	ld	a, d
	or	e
	jp	z, reset_hi_score
	inc	hl
	jp	.clear_screen	
	
turn_off_LCD:
	call wait_for_VBlank
							; we are in VBlank, we turn off the LCD
    ld      a,[rLCDC]     	; in A, the contents of the LCDC 
    res     7,a             ; we zero bit 7 (on the LCD)
    ld      [rLCDC],a 		; DON'T CHANGE THIS SUBROUTINE! Possible real hardware damage!
	ret
	
turn_on_LCD:	
	ld	a, %10010011	; Turning on the LCD
	ld	[rLCDC], a
	ret
	
; Reseting the hi-score
	
reset_hi_score:
	ld	hl, HI_SCORE_HIGH_BYTE
	ld	a, 0
	ld	[hl], a
	ld	hl, HI_SCORE_LOW_BYTE
	ld	a, $20		; 20 points will be the default hi-score
	ld	[hl], a
	
; Let's prepare the seed for the RNG
; We can use the property of the OAM, after each reset GameBoy is filled
; with random values. This will be base for our random generator.
; We will use the Y value of the 1st sprite.
; We will use address $C200 for the seed and
; address $C201 for our user manipulation

RNG_setup:
	call	turn_on_LCD
	ld	hl, _OAMRAM
	ld	a, [hl]
	ld	hl, RNG_SEED
	ld	[hl], a
	jp	cleaning_OAM
	
; Generating next value

generate_next_value:	
	ld	hl, RNG_SEED
	ld	a, [hl]
	ld	hl, USER_RNG_MANIPULATION
.next_generation:
	swap a
	rlca
	xor	a, [hl]
	cp	144
	jp	c, .return_value
	jp	.next_generation
.return_value
	ld	hl, RNG_SEED
	ld	[hl], a
	ret
	
; Cleaning OAM
; After turning on the console, the memory is filled with random values
; For the faster completion, cleaning occurs only during the HBlank
; Yes, it's not perfect, but remaining garbage is not visible

RESET:
	ld	sp, $FFFF

cleaning_OAM:
	ld	b, 160
	ld	hl, $FE00
	
.clean_OAM:
	ld	a, [rSTAT]
	cp	$80		; $80 = HBlank is active
	jp	nz, .clean_OAM
	ld	a, 0
	ldi	[hl], a
	dec	b
	ld	a, b
	jp	nz, .clean_OAM

; Draw the title screen

title_screen:
	call	turn_off_LCD
	ld	hl, $9800
	ld	de, 32*18
	ld	bc, Title_Screen_Data
.draw_title_screen:
	ld	a, [bc]
	ld	[hl], a
	dec	de
	ld	a, d
	or	e
	jp	z, .show
	inc	hl
	inc	bc
	jp	.draw_title_screen
; Let's also draw the hi-score
.show:
; Draw the thousands digit
	ld	hl, HI_SCORE_HIGH_BYTE
	ld	a, [hl]
	and	%11110000
	SWAP	a
	add	a, $0A
	ld	hl, $9908
	ld	[hl], a
; Draw the hundreds digit
	ld	hl, HI_SCORE_HIGH_BYTE
	ld	a, [hl]
	and	%00001111
	add	a, $0A
	ld	hl, $9909
	ld	[hl], a
; Draw the tens figit
	ld	hl, HI_SCORE_LOW_BYTE
	ld	a, [hl]
	and	%11110000
	SWAP	a
	add	a, $0A
	ld	hl, $990A
	ld	[hl], a
; Draw the ones digit
	ld	hl, HI_SCORE_LOW_BYTE
	ld	a, [hl]
	and	%00001111
	add	a, $0A
	ld	hl, $990B
	ld	[hl], a
	call	turn_on_LCD
.wait_for_start:
	ld	hl, USER_RNG_MANIPULATION
	inc	[hl]		; Let's stir some RNG manipulation
	ld	a, %11010111
	ld	[rP1], a
	ld	a, [rP1]	; Reading several times
	ld	a, [rP1]	; To secure the correct reading
	ld	a, [rP1]
	ld	a, [rP1]
	cp	%11010111	; Is the "start" button pressed?
	jp	nz, .wait_for_start

; Let's draw the main background

	call	turn_off_LCD
.draw_background:
	ld	hl, _SCRN0
	ld	de, 32*20
	ld	bc, BG_tile_map
.draw_next_tile:
	ld	a, [bc]
	add	a, $43		; Tile padding, GameBoy Tile Data Generator doesn't have the option for a padding of the values
	ld	[hl], a
	dec	de
	ld	a, d
	or	e
	jp	z, .continue_reset
	inc	hl
	inc	bc
	jp	.draw_next_tile

.continue_reset:
	call	turn_on_LCD

; Preparing Grunio's personal space

	ld	hl, GRUNIO_OAM
	ld	de, Grunio_OAM_Data
	ld	b, 4*6	; 4 OAM bytes * 6 Grunio sprites
.next_OAM_Grunio_Byte:
	ld	a, [de]
	ld	[hl], a
	dec	b
	inc	hl
	inc	de
	ld	a, b
	jp nz, .next_OAM_Grunio_Byte
	
; Preparing the carrot's space

	ld	hl, CARROT_OAM
	ld	de, Carrot_OAM_Data
	ld	b, 4*4	; 4 OAM bytes * 4 carrot sprites
.next_OAM_Carrot_Byte:
	ld	a, [de]
	ld	[hl], a
	dec	b
	inc	hl
	inc	de
	ld	a, b
	jp nz, .next_OAM_Carrot_Byte

; Reset score
	ld	a, 0
	ld	hl, SCORE_HIGH_BYTE
	ld	[hl], a
	ld	hl, SCORE_LOW_BYTE
	ld	[hl], a

; Reset "lives"
	ld	a, 4
	ld	hl, LIVES
	ld	[hl], a
	
; Reset the carrot's state
	ld	hl, CARROT_TYPE
	ld	a, $12	; $12 = "white" carrot, $34 = "black" carrot
	ld	[hl], a
	ld	hl, CARROT_COLLISION_STATE	; Carrot's collision state
	ld	a, 42	; State $42 = generate a new carrot	
	ld	[hl], a	; Since we begin a new game, generate one
	ld	hl, $C153
	ld	a, [hl]
	set	4, a
	ld	[hl], a
	ld	hl, $C157
	ld	a, [hl]
	set	4, a
	ld	[hl], a
	
; Reset Grunio's state
	ld	[hl], a
	ld	hl, GRUNIO_COLOUR
	ld	a, $12	 ; $12 = Dzidzia (the white guinea pig), $34 = Grunio (the black guinea pig)
	ld	[hl], a
	ld	hl, ANTI_AUTOFIRE
	ld	a, 0
	ld	[hl], a
	
; Prepare palletes for Grunio and the carrot
; Default for Dzidzia and the white carrot
	ld	a, %11100100
	ld	hl, $FF48	; First OBJ pallete for the heroes
	ld	[hl], a
	ld	hl, $FF49	; Second OBJ pallete for the carrot
	ld	[hl], a

; Main loop
; Many calls, many cycles lost. The loop is organised this way for my convenience.
; By organizing every piece one after another we could gain at least 180 cycles,
; but the console is bored waiting for VBlank, so I leave it the way it is.

main_loop:
	call	wait_for_VBlank
	call	update_Carrot
	call	check_collision
	call	draw_Grunio
	call	draw_Carrot
	call	draw_score
	call	draw_hearts
	call	handle_input
	call	generate_next_value
	jr	main_loop
	
; For my convenience the game executes code during the VBlank
; so the game runs in 60 FPS (faster and better than Castlevania: The Adventure DON'T HIT I LOVE THE ENTIRE FRANCHISE!)
; Also, the video memory can only be accessed during VBlank or HBlank, but HBlank is really short.
; An alternative is DMA. It's not used here as I had some problems with it.
	
wait_for_VBlank:
	ldh	a, [rLY]
	cp	145
	jr	nz, wait_for_VBlank
	ret

; Subroutine drawing Grunio
; I implement my own "DMA" for the heroes and the carrot

draw_Grunio:
	ld	hl, $FE00
	ld	de, GRUNIO_OAM
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
	ld	de, CARROT_OAM
	ld	b, 4*2
.next_Grunio_byte:
	ld	a, [de]
	ld	[hl], a
	inc	hl
	inc	de
	dec	b
	jp	nz, .next_Grunio_byte
	ld	hl, USER_RNG_MANIPULATION	; Bigger RNG manipulation
	ld	a, [hl]
	inc	a
	ld	[hl], a
	ret
	
update_Carrot:
	ld	hl, CARROT_COLLISION_STATE	; Let's check if we should reset the carrot after the collision
	ld	a, [hl]
	cp	$42
	jp	z, .generate_new_carrot	; If yes, generate a new carrot
	ld	hl, CARROT_OAM	; The carrot's OAM
	ld	a, [hl]
	add	a, 2
	ld	[hl], a
	ld	hl, $C154
	add	a, 8
	ld	[hl], a
	ret
.generate_new_carrot:
	ld	hl, RNG_SEED	; White or black carrot?
	ld	a, [hl]
	and %00000001
	cp	1
	jp	nz, .prepare_black_carrot	; Yes, this algorithm is very simple
	ld	hl, CARROT_TYPE	; And it depends on the carrot's X position
	ld	a, $12	; The carrot will be white on even X pixels and black on odd X pixels
	ld	[hl], a
	ld	hl, $FF49
	ld	a, %11100100
	ld	[hl], a
	jp	.reset_carrot
.prepare_black_carrot:
	ld	hl, CARROT_TYPE
	ld	a, $34
	ld	[hl], a
	ld	hl, $FF49
	ld	a, %11111111
	ld	[hl], a
.reset_carrot:
	ld	hl, RNG_SEED
	ld	a, [hl]
	add	8
	ld	hl, $C151
	ld	[hl], a
	ld	hl, $C155
	ld	[hl], a
	ld	hl, CARROT_OAM
	ld	a, 0
	ld	[hl], a
	ld	hl, $C154
	add	8
	ld	[hl], a
	ret
	
; Collision between the carrot and Grunio
	
check_collision:
; Check y collision
	ld	hl, CARROT_OAM	; Carrot Y
	ld	a, [hl]
	cp	$68		; Is Carrot too high?
	jp	c, .too_high
	cp	$78		; Is Carrot at the correct height?
	jp	c, .correct_height	; Carrot is between 
	ld	hl, rNR10	; Let's play a "missed" sound
	ld	a, $3A
	ld	[hl], a
	ld	hl, rNR11
	ld	a, $80
	ld	[hl], a
	ld	hl, rNR12
	ld	a, $FF
	ld	[hl], a
	ld	hl, rNR13
	ld	a, $B3
	ld	[hl], a
	ld	hl, rNR14
	ld	a, $C6
	ld	[hl], a
	ld	hl, CARROT_COLLISION_STATE
	ld	a, $42	; State for "reset a carrot"
	ld	[hl], a
	ld	hl, LIVES	; Lose a "life"
	ld	a, [hl]
	cp	0		; Is this the last "life"?
	jp	z, show_game_over
	dec	a
	ld	[hl], a
	ret
.correct_height:
; Is the the correct hero chosen for the carrot?
	ld	hl, CARROT_TYPE
	ld	a, [hl]
	ld	hl, GRUNIO_COLOUR
	cp	a, [hl]
	jp	z, .check_right_side
	ret; If colours aren't correct, return
; Carrot's right side and Grunio's left side
.check_right_side:
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
	add	a, 24	; Grunio's hitbox is 24 pixel wide
	ld	hl, $C151
	cp	a, [hl]
	jp	c, .too_high	; The check is reversed in this case, so the condition is also reversed
; The conditions are fulfilled, let's add one point to score
; And reset the carrot
.collision_true:
	ld	hl, rNR10	; Let's play a "collected" sound
	ld	a, $65
	ld	[hl], a
	ld	hl, rNR11
	ld	a, $80
	ld	[hl], a
	ld	hl, rNR12
	ld	a, $FF
	ld	[hl], a
	ld	hl, rNR13
	ld	a, $06
	ld	[hl], a
	ld	hl, rNR14
	ld	a, $C7
	ld	[hl], a
	ld	hl, CARROT_COLLISION_STATE	; Reset the carrot
	ld	a, $42
	ld	[hl], a
	ld	hl, SCORE_LOW_BYTE
	ld	a, [hl]
	inc	a
	daa		; Holy Moly, included BCD support? Noice!
	cp	$00
	ld	[hl], a
	jp	nz, .dont_add_hundreds
	ld	hl, SCORE_HIGH_BYTE
	ld	a, [hl]
	inc	a
	ld	[hl], a
.dont_add_hundreds:
	ret
.too_high:
	ld	hl, CARROT_COLLISION_STATE
	ld	a, 0
	ld	[hl], a
	ret

; Show "Game over"

show_game_over:
	ld	hl, $98E5
	ld	de, Game_Over_Text
	ld	b, 9
.next_letter:
	ld	a, [de]
	ld	[hl], a
	inc	de
	inc	hl
	dec	b
	ld	a, b
	cp	0
	jp	nz, .next_letter
	ld	de, $02FF	; Let's wait
.next_frame:
	call	wait_for_VBlank
	dec	de
	ld	a, d
	or	e
	cp	0
	jp	nz, .next_frame

; Is the current score higher than the hiscore?
; Executed after "Game over"

check_hiscore:
	ld	hl, SCORE_HIGH_BYTE
	ld	a, [hl]
	ld	hl, HI_SCORE_HIGH_BYTE
	cp	a, [hl]
	jp	c, RESET	; If our score's high byte (thousands and hundreds) is lower
					; than hi-score's high byte, reset.
	ld	hl, SCORE_LOW_BYTE
	ld	a, [hl]
	ld	hl, HI_SCORE_LOW_BYTE
	cp	a, [hl]
	jp	c, RESET	; Same as above, just tens and ones
	ld	hl, SCORE_HIGH_BYTE	; Let's set a new hi-score!
	ld	a, [hl]
	ld	hl, HI_SCORE_HIGH_BYTE
	ld	[hl], a
	ld	hl, SCORE_LOW_BYTE
	ld	a, [hl]
	ld	hl, HI_SCORE_LOW_BYTE
	ld	[hl], a
	jp	RESET	; Time to reset
	
; Handling the input and moving Grunio

handle_input:
	ld	a, %11101101
	ld	[rP1], a
	ld	a, [rP1]	; Reading several times
	ld	a, [rP1]	; To secure the correct reading
	ld	a, [rP1]
	ld	a, [rP1]
	cp	%11101101	; Is "left" direction pressed?
	jp	nz, .jump_to_right
	ld	hl, USER_RNG_MANIPULATION	; RNG user manipulation
	ld	a, [hl]
	add	a, 119		; Arbitrary value
	ld	[hl], a
	xor	[hl]
	bit	7, a
	ld	a, [$C101]	; Grunio's horizontal position
	cp	9			; Grunio's position can't be < 8
	jp	c, .jump_to_right	; We want to see entire Grunio on the screen
	ld	[hl], a
	ld	b, 6		; Moving all 6 sprites
	ld	hl, $C101
	ld	de, 2		; The offset between X positions in our "OAM"
.move_Grunio_left:
	ld	a, [hl]
	sub	3			; Move sprite 3px left
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
	jp	nz, .check_A_button
	ld	hl, USER_RNG_MANIPULATION	; RNG user manipulation
	ld	a, [hl]
	add	a, 241		; Arbitrary value
	ld	[hl], a
	xor	[hl]
	bit	5, a
	ld	a, [$C101]
	cp	$92			; Grunio again can't leave the screen
	jp	nc, .check_A_button
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
	jp	z, .check_A_button
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
.check_A_button
	ld	a, %11011110
	ld	[rP1], a
	ld	a, [rP1]	; Read several times
	ld	a, [rP1]	; To secure the correct reading
	ld	a, [rP1]
	ld	a, [rP1]
	cp	%11011110	; Is the "A" button pressed?
	jp	nz, .reset_autofire
	ld	hl, ANTI_AUTOFIRE
	ld	a, [hl]
	cp	1
	jp	z, .return	; Yes, autofire state = 1, let's return
	ld	a, 1
	ld	[hl], a		; Let's set autofire state to 1
	ld	hl, GRUNIO_COLOUR
	ld	a, $12
	cp	a, [hl]		; Is the hero white?
	jp	nz, .change_to_white	; If no, go change to white
	ld	a, $34
	ld	[hl], a
	ld	hl, $FF48
	ld	a, $FF
	ld	[hl], a
	jp	.return
.change_to_white:
	ld	a, $12
	ld	[hl], a
	ld	hl, $FF48
	ld	a, %11100100
	ld	[hl], a
	jp	.return
.reset_autofire
	ld	hl, ANTI_AUTOFIRE	; Let's reset our autofire state
	ld	a, 0
	ld	[hl], a
.return:
	ret

; Drawing the score during the gameplay

draw_score:
; Draw the thousands digit
	ld	hl, SCORE_HIGH_BYTE
	ld	a, [hl]
	and	%11110000
	SWAP	a
	add	a, $0A
	ld	hl, $9A0F
	ld	[hl], a
; Draw the hundreds digit
	ld	hl, SCORE_HIGH_BYTE
	ld	a, [hl]
	and	%00001111
	add	a, $0A
	ld	hl, $9A10
	ld	[hl], a
; Draw the tens figit
	ld	hl, SCORE_LOW_BYTE
	ld	a, [hl]
	and	%11110000
	SWAP	a
	add	a, $0A
	ld	hl, $9A11
	ld	[hl], a
; Draw the ones digit
	ld	hl, SCORE_LOW_BYTE
	ld	a, [hl]
	and	%00001111
	add	a, $0A
	ld	hl, $9A12
	ld	[hl], a
	ret

draw_hearts:
	ld	hl, LIVES
	ld	b, [hl]
	ld	a, b
	ld	d, 0
	cp	a, $FF
	ret	z
	ld	hl, $9A00
.draw_next_heart:
	inc	hl
	inc	d
	ld	a, d
	cp	4
	ret	z
	cp	a, b
	jp	c, .draw
	jp	z, .draw
	ld	a, $0
	ld	[hl], a
	jp	.draw_next_heart
.draw:
	ld	a, $14
	ld	[hl], a
	jp	.draw_next_heart
	
Sprite_Data:
DB	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0	; Empty sprite
DB	$FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF	; Filled sprite
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
DB	$1C,$1C,$26,$26,$26,$26,$26,$26	; 0 sprite
DB	$26,$26,$26,$26,$26,$26,$1C,$1C
DB	$3C,$3C,$0C,$0C,$0C,$0C,$0C,$0C	; 1 sprite
DB	$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C
DB	$1C,$1C,$26,$26,$26,$26,$06,$06	; 2 sprite
DB	$0C,$0C,$18,$18,$30,$30,$3E,$3E
DB	$1C,$1C,$26,$26,$26,$26,$0C,$0C	; 3 sprite
DB	$0C,$0C,$26,$26,$26,$26,$1C,$1C
DB	$0C,$0C,$1C,$1C,$3C,$3C,$6C,$6C	; 4 sprite
DB	$7E,$7E,$0C,$0C,$0C,$0C,$0C,$0C
DB	$3C,$3C,$20,$20,$20,$20,$3C,$3C	; 5 sprite
DB	$06,$06,$06,$06,$06,$06,$3C,$3C
DB	$3C,$3C,$40,$40,$40,$40,$7C,$7C	; 6 sprite
DB	$46,$46,$46,$46,$46,$46,$3C,$3C
DB	$3C,$3C,$26,$26,$06,$06,$06,$06	; 7 sprite
DB	$06,$06,$06,$06,$06,$06,$06,$06
DB	$3C,$3C,$46,$46,$46,$46,$7E,$7E	; 8 sprite
DB	$46,$46,$46,$46,$46,$46,$3C,$3C
DB	$3C,$3C,$46,$46,$46,$46,$3E,$3E	; 9 sprite
DB	$06,$06,$06,$06,$06,$06,$3C,$3C
DB 	$36,$36,$7F,$7F,$7F,$7F,$7F,$7F ; Heart sprite
DB 	$7F,$7F,$3E,$3E,$1C,$1C,$08,$08
DB	$46,$46,$46,$46,$46,$46,$7E,$7E	; H
DB	$46,$46,$46,$46,$46,$46,$00,$00
DB	$18,$18,$18,$18,$18,$18,$18,$18	; I
DB	$18,$18,$18,$18,$18,$18,$00,$00
DB	$38,$38,$60,$60,$60,$60,$78,$78	; S
DB	$0C,$0C,$0C,$0C,$78,$78,$00,$00
DB	$38,$38,$60,$60,$60,$60,$60,$60	; C
DB	$60,$60,$60,$60,$38,$38,$00,$00
DB	$38,$38,$6C,$6C,$6C,$6C,$6C,$6C	; O
DB	$6C,$6C,$6C,$6C,$38,$38,$00,$00
DB	$78,$78,$6C,$6C,$6C,$6C,$78,$78	; R
DB	$68,$68,$6C,$6C,$6C,$6C,$00,$00
DB	$7C,$7C,$60,$60,$60,$60,$7C,$7C	; E
DB	$60,$60,$60,$60,$7C,$7C,$00,$00
DB	$3C,$3C,$66,$66,$66,$66,$7E,$7E	; A
DB	$66,$66,$66,$66,$66,$66,$00,$00
DB	$66,$66,$76,$76,$76,$76,$6E,$6E	; N
DB	$6E,$6E,$66,$66,$66,$66,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00	; .
DB	$00,$00,$18,$18,$18,$18,$00,$00
DB	$66,$66,$66,$66,$66,$66,$66,$66	; U
DB	$66,$66,$66,$66,$3C,$3C,$00,$00
DB	$78,$78,$66,$66,$66,$66,$66,$66	; D
DB	$66,$66,$66,$66,$78,$78,$00,$00
DB	$60,$60,$60,$60,$60,$60,$60,$60	; L
DB	$60,$60,$60,$60,$7C,$7C,$00,$00
DB	$3E,$3E,$60,$60,$60,$60,$6E,$6E	; G
DB	$66,$66,$66,$66,$3E,$3E,$00,$00
DB	$7C,$7C,$66,$66,$66,$66,$7C,$7C	; P
DB	$60,$60,$60,$60,$60,$60,$00,$00
DB	$7E,$7E,$18,$18,$18,$18,$18,$18	; T
DB	$18,$18,$18,$18,$18,$18,$00,$00
DB	$60,$60,$60,$60,$60,$60,$68,$68	; Ł
DB	$70,$70,$60,$60,$7E,$7E,$00,$00
DB	$66,$66,$66,$66,$68,$68,$70,$70	; K
DB	$68,$68,$66,$66,$66,$66,$00,$00
DB	$7E,$7E,$0C,$0C,$0C,$0C,$30,$30	; Z
DB	$60,$60,$60,$60,$7E,$7E,$00,$00
DB	$00,$00,$00,$00,$00,$00,$3C,$3C	; -
DB	$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$3E,$3E,$7E,$7E	; Logo start
DB	$60,$60,$60,$60,$60,$60,$6E,$6E
DB	$2A,$6E,$44,$66,$00,$66,$00,$66
DB	$00,$7E,$00,$3E,$00,$00,$00,$00
DB	$00,$00,$00,$00,$7C,$7C,$7E,$7E
DB	$66,$66,$66,$66,$66,$66,$7E,$7E
DB	$28,$7C,$44,$6C,$00,$66,$00,$66
DB	$00,$66,$00,$66,$00,$00,$00,$00
DB	$00,$00,$00,$00,$66,$66,$66,$66
DB	$66,$66,$66,$66,$66,$66,$66,$66
DB	$22,$66,$44,$66,$00,$66,$00,$66
DB	$00,$7E,$00,$3C,$00,$00,$00,$00
DB	$00,$00,$00,$00,$66,$66,$66,$66
DB	$66,$66,$76,$76,$76,$76,$76,$76
DB	$2A,$6E,$44,$6E,$00,$6E,$00,$66
DB	$00,$66,$00,$66,$00,$00,$00,$00
DB	$00,$00,$00,$00,$63,$63,$67,$67
DB	$66,$66,$66,$66,$66,$66,$66,$66
DB	$22,$66,$44,$66,$00,$66,$00,$66
DB	$00,$67,$00,$63,$00,$00,$00,$00
DB	$01,$01,$00,$00,$C7,$C7,$E7,$E7
DB	$60,$60,$60,$60,$60,$60,$61,$61
DB	$20,$61,$41,$63,$00,$63,$00,$66
DB	$00,$E7,$00,$C7,$00,$00,$00,$00
DB	$80,$80,$00,$00,$E7,$E7,$E7,$E7
DB	$66,$66,$66,$66,$C6,$C6,$C7,$C7
DB	$02,$07,$04,$06,$00,$06,$00,$06
DB	$00,$E7,$00,$E7,$00,$00,$00,$00
DB	$00,$00,$00,$00,$CF,$CF,$CF,$CF
DB	$0C,$0C,$0C,$0C,$0C,$0C,$CF,$CF
DB	$8A,$CF,$04,$0C,$00,$0C,$00,$0C
DB	$00,$CC,$00,$CC,$00,$00,$00,$00
DB	$00,$00,$00,$00,$87,$87,$CF,$CF
DB	$CC,$CC,$CC,$CC,$CC,$CC,$CC,$CC
DB	$88,$8C,$04,$0C,$00,$CC,$00,$CC
DB	$00,$CF,$00,$C7,$00,$00,$00,$00
DB	$00,$00,$00,$00,$8F,$8F,$9F,$9F
DB	$19,$19,$19,$19,$19,$19,$1F,$1F
DB	$0A,$1F,$11,$19,$00,$19,$00,$19
DB	$00,$99,$00,$99,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$80,$80
DB	$80,$80,$80,$80,$80,$80,$80,$80
DB	$80,$80,$00,$80,$00,$80,$00,$80
DB	$00,$80,$00,$80,$00,$00,$00,$00	; Logo end
DB	$46,$46,$6E,$6E,$7E,$7E,$56,$56	; M
DB	$46,$46,$46,$46,$46,$46,$00,$00
DB	$66,$66,$66,$66,$66,$66,$66,$66	; V
DB	$66,$66,$18,$18,$18,$18,$00,$00
DB	$66,$66,$66,$66,$66,$66,$18,$18	; Y
DB	$18,$18,$18,$18,$18,$18,$00,$00
DB	$7C,$7C,$66,$66,$66,$66,$78,$78	; B
DB	$66,$66,$66,$66,$7C,$7C,$00,$00
; Background tiles
BG_Tile_Data:
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$03,$00
DB	$00,$00,$10,$00,$38,$00,$38,$00,$38,$00,$34,$00,$74,$00,$72,$00
DB	$07,$00,$07,$00,$07,$00,$0F,$00,$1F,$00,$1F,$00,$1F,$00,$3F,$00
DB	$80,$00,$80,$00,$80,$00,$C0,$00,$40,$00,$40,$00,$20,$00,$20,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$01,$00,$03,$00,$03,$00
DB	$72,$00,$F2,$00,$F1,$00,$F1,$00,$E0,$00,$E0,$00,$C2,$00,$C2,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$80,$00,$40,$00,$40,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$03,$00,$07,$00,$07,$00
DB	$7F,$00,$7E,$00,$FE,$00,$FC,$00,$FC,$00,$FC,$00,$F8,$00,$F8,$00
DB	$20,$00,$10,$00,$10,$00,$08,$00,$04,$00,$02,$00,$02,$00,$21,$00
DB	$03,$00,$07,$00,$07,$00,$0F,$00,$0F,$00,$1F,$00,$1F,$00,$3F,$00
DB	$C2,$00,$81,$00,$80,$00,$80,$00,$80,$00,$80,$00,$88,$00,$84,$00
DB	$20,$00,$20,$00,$A0,$00,$90,$00,$50,$00,$48,$00,$48,$00,$64,$00
DB	$00,$00,$00,$00,$01,$00,$01,$00,$03,$00,$03,$00,$03,$00,$07,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00
DB	$0F,$00,$1F,$00,$1F,$00,$3F,$00,$7F,$00,$FF,$00,$FF,$00,$FF,$00
DB	$F8,$00,$F8,$00,$F8,$00,$F8,$00,$F8,$00,$F8,$00,$F8,$00,$F8,$00
DB	$21,$00,$20,$00,$20,$00,$20,$00,$10,$00,$10,$00,$10,$00,$10,$00
DB	$00,$00,$80,$00,$80,$00,$60,$00,$10,$00,$10,$00,$10,$00,$08,$00
DB	$00,$00,$00,$00,$00,$00,$02,$00,$07,$00,$07,$00,$0F,$00,$0F,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00
DB	$3F,$00,$3F,$00,$7F,$00,$7F,$00,$FF,$00,$FF,$00,$FE,$00,$FE,$00
DB	$84,$00,$04,$00,$04,$00,$04,$00,$04,$00,$02,$00,$02,$00,$01,$00
DB	$24,$00,$22,$00,$32,$00,$11,$00,$01,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$80,$00,$40,$00
DB	$07,$00,$07,$00,$0F,$00,$0F,$00,$0F,$00,$1F,$00,$3F,$00,$3F,$00
DB	$03,$00,$03,$00,$07,$00,$0F,$00,$1F,$00,$1F,$00,$3F,$00,$7F,$00
DB	$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00
DB	$F0,$00,$F0,$00,$E0,$00,$E0,$00,$E0,$00,$C0,$00,$C0,$00,$80,$00
DB	$10,$00,$08,$00,$08,$00,$04,$00,$04,$00,$04,$00,$42,$00,$22,$00
DB	$04,$00,$02,$00,$02,$00,$01,$00,$20,$00,$10,$00,$08,$00,$08,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$40,$00,$40,$00,$21,$00
DB	$0E,$00,$1E,$00,$1E,$00,$3E,$00,$3E,$00,$7E,$00,$FE,$00,$FC,$00
DB	$80,$00,$40,$00,$40,$00,$20,$00,$20,$00,$10,$00,$08,$00,$04,$00
DB	$01,$00,$03,$00,$03,$00,$03,$00,$07,$00,$07,$00,$0F,$00,$0F,$00
DB	$FE,$00,$FE,$00,$FE,$00,$FE,$00,$FE,$00,$FE,$00,$FE,$00,$FC,$00
DB	$01,$00,$01,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$81,$00,$80,$00,$80,$00,$40,$00,$40,$00,$20,$00
DB	$40,$00,$20,$00,$20,$00,$90,$00,$90,$00,$48,$00,$44,$00,$24,$00
DB	$7F,$00,$7F,$00,$FF,$00,$FE,$00,$FE,$00,$FE,$00,$FC,$00,$FC,$00
DB	$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$20,$00,$10,$00,$10,$00,$10,$00,$10,$00,$08,$00,$08,$00,$04,$00
DB	$04,$00,$02,$00,$02,$00,$02,$00,$02,$00,$01,$00,$00,$00,$00,$00
DB	$13,$00,$0F,$00,$0F,$00,$07,$00,$03,$00,$00,$00,$80,$00,$40,$00
DB	$FC,$00,$F8,$00,$F8,$00,$F9,$00,$F9,$00,$F9,$00,$38,$00,$00,$00
DB	$04,$00,$02,$00,$01,$00,$01,$00,$00,$00,$00,$00,$84,$00,$44,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$40,$00,$20,$00,$10,$00
DB	$1F,$00,$1F,$00,$3F,$00,$3F,$00,$7F,$00,$7F,$00,$FF,$00,$FF,$00
DB	$FC,$00,$F8,$00,$F8,$00,$F0,$00,$F0,$00,$F0,$00,$E0,$00,$E0,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$10,$00,$20,$00,$20,$00
DB	$22,$00,$11,$00,$11,$00,$08,$00,$04,$00,$04,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$80,$00,$40,$00,$20,$00,$10,$00,$10,$00
DB	$07,$00,$0F,$00,$0F,$00,$1F,$00,$3F,$00,$7F,$00,$FF,$00,$FF,$00
DB	$FC,$00,$F8,$00,$F8,$00,$F8,$00,$F8,$00,$F8,$00,$F0,$00,$F0,$00
DB	$FF,$00,$FF,$00,$FE,$00,$FE,$00,$FC,$00,$FC,$00,$F8,$00,$F0,$00
DB	$02,$00,$01,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$80,$00,$80,$00,$80,$00,$40,$00,$40,$00
DB	$20,$00,$10,$00,$10,$00,$10,$00,$08,$00,$08,$00,$00,$00,$00,$00
DB	$22,$00,$21,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$08,$00,$08,$00,$84,$00,$42,$00,$21,$00,$10,$00,$00,$00,$00,$00
DB	$01,$00,$03,$00,$03,$00,$07,$00,$0F,$00,$DF,$00,$7F,$00,$7F,$00
DB	$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FE,$00
DB	$E0,$00,$C0,$00,$C0,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00
DB	$20,$00,$40,$00,$40,$00,$40,$00,$40,$00,$80,$00,$80,$00,$80,$00
DB	$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$80,$00,$40,$00,$20,$00,$10,$00,$10,$00,$08,$00,$04,$00
DB	$08,$00,$04,$00,$02,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$41,$00,$27,$00,$1F,$00
DB	$03,$00,$07,$00,$1F,$00,$3F,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00
DB	$F0,$00,$F0,$00,$F0,$00,$F0,$00,$E0,$00,$E0,$00,$E0,$00,$E0,$00
DB	$F0,$00,$E0,$00,$E0,$00,$C0,$00,$80,$00,$80,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$01,$00,$03,$00,$07,$00,$1F,$00,$7F,$00,$FF,$00
DB	$7F,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00
DB	$FE,$00,$FC,$00,$F8,$00,$F8,$00,$F0,$00,$F0,$00,$F0,$00,$E0,$00
DB	$80,$00,$80,$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00
DB	$02,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$04,$00,$02,$00,$81,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$1F,$00,$0F,$00,$07,$00,$83,$00,$41,$00,$20,$00,$10,$00,$0E,$00
DB	$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$3F,$00,$0F,$00,$00,$00
DB	$E0,$00,$E0,$00,$C0,$00,$C0,$00,$C0,$00,$C0,$00,$C0,$00,$C0,$00
DB	$FC,$00,$FC,$00,$FF,$00,$FE,$00,$FF,$00,$8F,$00,$FF,$00,$E3,$00
DB	$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$80,$00,$80,$00
DB	$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$0F,$00,$3F,$00,$FF,$00,$FF,$00,$7C,$00,$7F,$00,$3F,$00,$1F,$00
DB	$FF,$00,$FF,$00,$FF,$00,$FF,$00,$07,$00,$FF,$00,$F0,$00,$FF,$00
DB	$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$03,$00,$FF,$00
DB	$E0,$00,$C0,$00,$FF,$00,$C0,$00,$C0,$00,$C0,$00,$C0,$00,$C0,$00
DB	$00,$00,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00
DB	$07,$00,$00,$00,$FF,$00,$00,$00,$03,$00,$3F,$00,$FF,$00,$FF,$00
DB	$F8,$00,$0F,$00,$FF,$00,$38,$00,$C0,$00,$C0,$00,$C0,$00,$80,$00
DB	$FF,$00,$1B,$04,$F9,$06,$F0,$0F,$E0,$1F,$C0,$3F,$00,$FF,$00,$FF
DB	$80,$00,$E0,$00,$E0,$00,$E0,$00,$30,$C0,$00,$F0,$00,$FF,$00,$FF
DB	$00,$00,$00,$08,$00,$0C,$00,$1E,$00,$3F,$00,$7F,$00,$FF,$00,$FF
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$E0,$00,$FF,$00,$FF
DB	$00,$00,$00,$10,$00,$18,$00,$3C,$00,$7F,$00,$FF,$00,$FF,$00,$FF
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$C1,$00,$FF,$00,$FF
DB	$00,$00,$00,$20,$00,$30,$00,$78,$00,$FE,$00,$FF,$00,$FF,$00,$FF
DB	$1F,$00,$0F,$00,$0F,$00,$07,$00,$06,$01,$04,$83,$00,$FF,$00,$FF
DB	$80,$00,$BF,$40,$9F,$60,$0F,$F0,$03,$FC,$00,$FF,$00,$FF,$00,$FF
DB	$7F,$00,$FF,$00,$01,$00,$FE,$01,$FC,$03,$F8,$07,$00,$FF,$00,$FF
DB	$E0,$00,$60,$80,$20,$C0,$00,$E0,$00,$F8,$00,$FE,$00,$FF,$00,$FF
DB	$00,$00,$00,$01,$00,$01,$00,$03,$00,$07,$00,$0F,$00,$FF,$00,$FF
DB	$00,$00,$00,$00,$00,$80,$00,$C0,$00,$F0,$00,$FC,$00,$FF,$00,$FF
DB	$00,$00,$00,$02,$00,$03,$00,$07,$00,$0F,$00,$1F,$00,$FF,$00,$FF
DB	$00,$00,$00,$00,$00,$00,$00,$80,$00,$E0,$00,$F8,$00,$FF,$00,$FF
DB	$00,$00,$00,$04,$00,$06,$00,$0F,$00,$1F,$00,$3F,$00,$FF,$00,$FF
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$C0,$00,$F0,$00,$FF,$00,$FF
DB	$03,$00,$07,$08,$02,$0C,$01,$1E,$00,$3F,$00,$7F,$00,$FF,$00,$FF
DB	$80,$00,$FF,$00,$01,$00,$FF,$00,$7F,$80,$1F,$E0,$00,$FF,$00,$FF
DB	$C0,$00,$C0,$10,$80,$18,$80,$3C,$80,$7F,$80,$7F,$00,$FF,$00,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF,$00,$FF
DB	$00,$FF,$00,$FF,$00,$3F,$00,$16,$00,$06,$00,$06,$00,$06,$7F,$7F
DB	$00,$FF,$00,$E7,$00,$C3,$00,$00,$00,$00,$00,$00,$00,$00,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$18,$00,$18,$00,$18,$00,$18,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$CF,$00,$84,$00,$00,$00,$00,$00,$00,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$F9,$00,$70,$00,$60,$00,$60,$00,$60,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$B0,$00,$30,$00,$30,$00,$30,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FC,$00,$68,$00,$60,$00,$60,$00,$60,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$70,$00,$30,$00,$30,$00,$30,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$79,$00,$70,$00,$60,$00,$60,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$B0,$00,$B0,$00,$30,$00,$30,$FF,$FF
DB	$00,$FF,$00,$E7,$00,$C3,$00,$81,$00,$01,$00,$01,$00,$01,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$F3,$00,$A1,$00,$80,$00,$80,$00,$80,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$C1,$00,$C1,$00,$C1,$00,$C1,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$FE,$00,$E6,$00,$C2,$00,$80,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$FF,$00,$83,$00,$83,$00,$83,$00,$83,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$CE,$00,$84,$00,$00,$00,$00,$00,$00,$FF,$FF
DB	$00,$FF,$00,$FF,$00,$7F,$00,$38,$00,$18,$00,$18,$00,$18,$FF,$FF

Grunio_OAM_Data:
db	$78, $50, $2, 0
db	$80, $50, $3, 0
db	$78, $58, $4, 0
db	$80, $58, $5, 0
db	$78, $60, $6, 0
db	$80, $60, $7, 0

Carrot_OAM_Data:
db	$00, $00, $8, 0
db	$00, $00, $9, 0

Title_Screen_Data:
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$29,$2B,$2D
DB $2F,$31,$33,$35,$37,$39,$3B,$3D,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$2A
DB $2C,$2E,$30,$32,$34,$36,$38,$3A,$3C,$3E
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $15,$16,$28,$17,$18,$19,$1A,$1B,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$17,$23,$1B,$18,$16,$1C,$21
DB $00,$24,$15,$1C,$1D,$26,$17,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$1C
DB $1A,$15,$1D,$1E,$1B,$1F,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$19,$1A
DB $16,$22,$16,$1D,$1C,$21,$00,$18,$19,$1D
DB $18,$1B,$23,$24,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$25,$1F,$26,$1C,$17,$27,$00
DB $26,$1F,$1A,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$1A,$41,$17,$27,$1C,$1A,$20,$00
DB $42,$1A,$27,$1F,$26,$1C,$25,$1C,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$0C
DB $0A,$0B,$13,$00,$20,$1A,$16,$21,$21,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; Background tile map
BG_tile_map:
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$03,$04,$00,$00,$00,$00,$00,$00,$00,$05,$06,$07,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$08,$09,$0A,$00,$00,$00,$00,$00,$00,$00,$0B,$0C,$0D,$00,$00
DB	$00,$00,$00,$0E,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$0F,$10,$11,$12,$13,$00,$14,$15,$00,$00,$0F,$16,$17,$18,$19,$00
DB	$00,$00,$00,$1A,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$1B,$1C,$1D,$1E,$1F,$20,$21,$22,$00,$00,$23,$24,$25,$26,$27,$00
DB	$00,$00,$05,$28,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$1C,$1C,$29,$2A,$2B,$2C,$2D,$2E,$2F,$00,$30,$31,$32,$00,$33,$34
DB	$00,$0F,$35,$36,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$1C,$37,$00,$38,$39,$3A,$00,$3B,$3C,$3D,$3E,$3F,$40,$41,$42,$43
DB	$44,$45,$1C,$46,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$3E,$47,$00,$00,$00,$00,$00,$0F,$48,$49,$4A,$00,$4B,$00,$4C,$4D
DB	$4E,$4F,$1C,$50,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$51,$52,$53,$53,$53,$53,$53,$54,$55,$56,$57,$53,$53,$53,$53,$53
DB	$53,$58,$59,$5A,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$5B,$5C,$5D,$5E,$5F,$60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A
DB	$6B,$6C,$6D,$6E,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F,$6F
DB	$6F,$6F,$6F,$6F,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$74,$7A,$7B,$7C,$7B,$7C
DB	$7D,$7E,$7F,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

Game_Over_Text:
DB	$22, $1C, $3F, $1B, $00, $19, $40, $1B, $1A
EndTileCara: