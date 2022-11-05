.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"


   jmp start
   
.include "x16.inc"   
.include "vera.inc"

; VRAM Addresses
VRAM_layer0_map   = $00000
VRAM_layer1_map   = $00800
VRAM_tiles        = $01000

HIMEM = $a000

;---------------------------------
; joystick management
;---------------------------------

JOY_RIGHT 	= %00000001
JOY_LEFT 	= %00000010
JOY_DOWN 	= %00000100
JOY_UP 		= %00001000

.macro LOAD_r0 addr16
	lda #<addr16
	sta r0L
	lda #>addr16
	sta r0H
.endmacro
.macro LOAD_r1 addr16
	lda #<addr16
	sta r1L
	lda #>addr16
	sta r1H
.endmacro

.macro VCOPY from, to, blocks
	LOAD_r0 from
	LOAD_r1 (to & $00ffff)
	ldy #(to >> 16)
	ldx #(blocks)
	jsr Vera::vcopy
.endmacro

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Vera code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.macro LOAD_FILE filename, length, ram
	lda #1
	ldx #8
	ldy #0
	jsr SETLFS
	lda #length
	ldx #<filename
	ldy #>filename
	jsr SETNAM
	lda #0
	ldx #<ram
	ldy #>ram
	jsr LOAD
.endmacro

.scope Vera

.macro VLOAD_FILE filename, length, vram
	lda #1
	ldx #8
	ldy #0
	jsr SETLFS
	lda #length
	ldx #<filename
	ldy #>filename
	jsr SETNAM
	lda #(^vram + 2)
	ldx #<vram
	ldy #>vram
	jsr LOAD
.endmacro

;
; copy from rom to vram
;	r0 : from
;	r1 : to (first 16 bites)
;   	y : vera bank (0, 1)
;	X: blocks
;
vcopy:
	lda #0
	sta veractl
	tya
	ora #$10
	sta verahi
	lda r1H
	sta veramid
	lda r1L
	sta veralo

@loop:	
    ldy #0                              
@loop1tile:
	lda (r0),y                         	; read from tiles data
    sta veradat                      	; Write to VRAM with +1 Autoincrement
    iny
    bne @loop1tile
	
	inc r0H
	dex
	bne @loop
	rts
.endscope

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Layers code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Layers
HSCROLL = 0
VSCROLL = 2

; define size of tiles for layer
.macro VTILEMODE layer, mode
	lda veral0tilebase + layer * 7
	and #VERA_CLEAR_TILE_SIZE
	ora #mode
	sta veral0tilebase + layer * 7
.endmacro

; define number of tiles in the map
.macro VCONFIG_TILES layer,mode
	lda veral0config + layer * 7
	and #VERA_CONFIG_CLEAR_TILES
	ora #mode
	sta veral0config + layer * 7
.endmacro

; define number of colors for the map
.macro VCONFIG_DEPTH layer,mode
	lda veral0config + layer * 7
	and #VERA_CONFIG_CLEAR_DEPTH
	ora #mode
	sta veral0config + layer * 7
.endmacro

; set the tilebase for the layer
.macro VTILEBASE layer,addr
    lda veral0tilebase + layer * 7                  ; set memory for tilebase
	and #VERA_TILEBASE_CLEAR_ADR
	ora #(addr >> 9)
	sta veral0tilebase + layer * 7
.endmacro

; set the mapbase for the layer
.macro VMAPBASE layer,addr
    lda #(addr >> 9)         ; store 2 last bits
    sta veral0mapbase + layer * 7                   ; Store to Map Base Pointer
.endmacro

;
; increase layer scrolling with a 8bits limit
;	X: : 0 = horizontal
;	   : 2 = vertical
;	Y: limit
;
scroll_inc_8:
	sty r0L
	lda VERA_L1_hscrolllo, x
	cmp r0L
	beq @scrollend
@scrollinc:
	inc
	sta VERA_L1_hscrolllo, x
	bne @scrollend
	inc VERA_L1_hscrollhi, x
	bra @scrollend
@scrollend:
	rts

;
; increase layer scrolling with a 16bits limit
;	X: : 0 = horizontal
;	   : 2 = vertical
;	r0L: limit
;
scroll_inc_16:
	lda VERA_L1_hscrolllo, x
	cmp r0L
	bne @scrollinc								; if low bits are not equals to the limit low bits => safe to increase
	tay
	lda VERA_L1_hscrollhi, x
	cmp r0H
	beq @scrollend								; if high bits are equals to the limit high bits => we reached the limit
	tya
@scrollinc:
	inc
	sta VERA_L1_hscrolllo, x
	bne @scrollend
	inc VERA_L1_hscrollhi, x
	bra @scrollend
@scrollend:
	rts

; increase a layer scroll offset but do NOT overlap
.macro VSCROLL_INC direction,limit
.if limit > 255
	LOAD_r0 limit
	ldx #direction
	jsr Layers::scroll_inc_16
.else
	ldy #limit
	ldx #direction
	jsr Layers::scroll_inc_8
.endif
.endmacro

;
;
; decrease a layer scroll offset
;	X : 0 = horizontal
;	  : 2 = vertical
;
scroll_dec:
	lda VERA_L1_hscrolllo, x
	beq @scrollHI			; 00 => decrease high bits
	dec
	sta VERA_L1_hscrolllo, x
	bra @scrollend
@scrollHI:
	ldy VERA_L1_hscrollhi, x
	beq @scrollend		; 0000 => no scrolling
	dec
	sta VERA_L1_hscrolllo, x
	dey
	tya
	sta VERA_L1_hscrollhi, x
@scrollend:
	rts

;
; force layer0 scrolling to be half of the layer1 scrolling
;
scroll_l0:
	lda VERA_L1_hscrollhi, x	; layer0 hScroll is layer 1 / 2
	lsr
	sta VERA_L0_hscrollhi, x
	lda VERA_L1_hscrolllo, x
	ror
	sta VERA_L0_hscrolllo, x
	rts
.endscope

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Layers code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct VSPRITE
	address125 .byte
	mode_xxx_address1613 .byte
	x70 .byte
	x98 .byte
	y70 .byte
	y98 .byte
	collision_zdepth_vflip_hflip .byte
	height_width_offset .byte
.endstruct

.scope Sprite
vram:
	; set vram memory on the X sprite
	lda #0
	sta veractl
	lda #<(vram_sprd >> 16) | $10
	sta verahi
	lda r1H
	sta veramid
	lda r1L
	sta veralo	; vera = $1fc00 + sprite index (X) * 8
	rts
	
load:
	; compute verma memory for  the target sprite
	txa
	stz r1H
	asl
	rol r1H
	asl
	rol r1H
	asl
	rol r1H
	sta r1L		; r1 = sprite index (X) * 8
	
	clc
	lda r1H
	adc #<(vram_sprd >> 8)
	sta r1H		; r1 = $fc00 + sprite index (X) * 8
	
	; set vram memory on the X sprite
	jsr vram
	
	; bit shift vera memory
	lda r0H
	lsr
	ror r0L
	lsr
	ror r0L
	lsr
	ror r0L
	lsr
	ror r0L						; bit shift 4x 16 bits vera memory
	lsr
	ror r0L						; bit shift 4x 16 bits vera memory
	ora #$80						; M = 8 bits
	ldx r0L
	stx veradat					; addres 12:5 of the sprite date
	sta veradat					; M000 + address 16:13
	stz veradat					; x = 0
	stz veradat
	stz veradat					; y = 0
	stz veradat
	lda #%00000000				; collision mask + sprite = disabled + vflip=none + hflip=none
	sta veradat
	lda #%10100000				; 32x32 sprite
	sta veradat
	rts

;
; change the display byte for a sprite
;	X = index of the sprite
;	Y = display value to set
;
display:
	; compute verma memory for  the target sprite
	txa
	stz r1H
	asl
	rol r1H
	asl
	rol r1H
	asl
	rol r1H	; r1 = sprite index (X) * 8
	
	clc
	adc #(VSPRITE::collision_zdepth_vflip_hflip)
	sta r1L		
	lda r1H
	adc #<(vram_sprd >> 8)
	sta r1H		; r1 = $fc00 + sprite index (X) * 8 + zdepth

	; set vram memory on the X sprite
	jsr vram

	sty veradat
	rts

position:
	; compute verma memory for  the target sprite
	txa
	stz r1H
	asl
	rol r1H
	asl
	rol r1H
	asl
	rol r1H	; r1 = sprite index (X) * 8
	
	clc
	adc #(VSPRITE::x70)
	sta r1L		
	lda r1H
	adc #<(vram_sprd >> 8)
	sta r1H		; r1 = $fc00 + sprite index (X) * 8 + zdepth
	
	; set vram memory on the X sprite
	jsr vram
	
	
	ldy #1
	lda (r0L)
	sta veradat
	lda (r0L),y
	sta veradat
	iny
	lda (r0L),y
	sta veradat
	iny
	lda (r0L),y
	sta veradat
	rts
.endscope

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START player code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct PLAYER
	idle			.byte	; bool : player is idle or not
	animation_tick	.byte
	spriteID 		.byte
	px 				.word
	py 				.word
	flip 			.byte
.endstruct

.scope Player
init:
	lda #10
	sta player0 + PLAYER::animation_tick
	sta player0 + PLAYER::idle				; player start idle
	stz player0 + PLAYER::spriteID
	stz player0 + PLAYER::px
	stz player0 + PLAYER::px+1
	stz player0 + PLAYER::py
	stz player0 + PLAYER::py+1
	stz player0 + PLAYER::flip
	rts
	
;
; increase player X position
;
position_x_inc:
	lda player0 + PLAYER::px
	cmp #<(320-32)
	bne @incLOW
	ldx player0 + PLAYER::px + 1
	cpx #>(320-32)
	beq @incend						; we are at the top limit
@incLOW:
	inc 
	sta player0 + PLAYER::px
	bne @incend
@incHi:
	inx
	stx player0 + PLAYER::px + 1
@incend:
	jsr Player::position_set
	rts

;
; decrease player position X unless at 0
;	
position_x_dec:
	lda player0 + PLAYER::px
	cmp #0
	bne @decLOW
	lda player0 + PLAYER::px + 1
	cmp #0
	beq @decend
	dec
	sta player0 + PLAYER::px + 1
	lda #$ff
	sta player0 + PLAYER::px
	bra @decend
@decLOW:
	dec 
	sta player0 + PLAYER::px
@decend:
	jsr Player::position_set
	rts

;
; increase player Y position
;
position_y_inc:
	lda player0 + PLAYER::py
	cmp #(240-32)
	beq @moveleftP0
	inc
	sta player0 + PLAYER::py
	bne @moveleftP0
	inc player0 + PLAYER::py + 1
@moveleftP0:
	jsr Player::position_set
	rts

;
; decrease player position X unless at 0
;	
position_y_dec:
	lda player0 + PLAYER::py
	cmp #0
	bne @decLOW
	lda player0 + PLAYER::py + 1
	cmp #0
	beq @decend
	dec
	sta player0 + PLAYER::py + 1
	lda #$ff
	sta player0 + PLAYER::py
	bra @decend
@decLOW:
	dec 
	sta player0 + PLAYER::py
@decend:
	jsr Player::position_set
	rts

;
; force the current player sprite at its position
;	
position_set:
	ldx player0 + PLAYER::spriteID
	LOAD_r0 (player0 + PLAYER::px)
	jsr Sprite::position			; set position of the sprite
	rts
	
;
; change the player sprite hv flip
;	
display:
	ldx player0 + PLAYER::spriteID
	lda #SPRITE_ZDEPTH_TOP
	and #SPRITE_FLIP_CLEAR
	ora player0 + PLAYER::flip
	tay							; but keep the current sprite flip
	jsr Sprite::display
	rts

;
; Animate the player if needed
;		
animate:
	lda player0 + PLAYER::idle
	bne @end
	
	dec player0 + PLAYER::animation_tick
	bne @end

	lda #10
	sta player0 + PLAYER::animation_tick	; reset animation tick counter
	
	ldx player0 + PLAYER::spriteID
	ldy #SPRITE_ZDEPTH_DISABLED
	jsr Sprite::display			; turn current sprite off
	
	ldx player0 + PLAYER::spriteID
	inx
	cpx #3
	bne @set_sprite_on
	ldx #0
@set_sprite_on:
	stx player0 + PLAYER::spriteID	; turn next sprite on
	jsr Player::display
	jsr Player::position_set
@end:
	rts
	
;
; change the idle status
;
set_idle:
	sta player0 + PLAYER::idle
	rts
	
.endscope

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; main code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------
	
start:
	jsr Player::init
	
	; 320x240
	lda #64
	sta veradchscale
	sta veradcvscale

	; activate layer0
	lda #%01110001
;	and #(255-VERA_LAYER0)
;	ora #(VERA_LAYER1)             ; Read Video Register
	sta veradcvideo             ; Store new value to Video Register

	;---------------------------------
	; load tiles file into vram 
	;---------------------------------
	VLOAD_FILE fstile, (fstileend-fstile), VRAM_tiles

	;---------------------------------
	; load tilemap 1 into vram 
	;---------------------------------
setlayer0:
	VCONFIG_TILES 0,VERA_CONFIG_32x32
	VCONFIG_DEPTH 0,VERA_CONFIG_8BPP
	VMAPBASE 0, VRAM_layer0_map
	VTILEBASE 0, VRAM_tiles
	VTILEMODE 0,VERA_TILE_16x16 
	VLOAD_FILE fsbackground, (fsbackground_end-fsbackground), VRAM_layer0_map
	
setlayer1:
	VCONFIG_TILES 1,VERA_CONFIG_32x32
	VCONFIG_DEPTH 1,VERA_CONFIG_8BPP
	VMAPBASE 1, VRAM_layer1_map
	VTILEBASE 1, VRAM_tiles
	VTILEMODE 1,VERA_TILE_16x16 
	VLOAD_FILE fslevel, (fslevel_end-fslevel), VRAM_layer1_map
	
	;---------------------------------
	; load sprite 0,1,2 into vram 
	;---------------------------------
load_sprites:
	; load sprites data at the end of the tiles
	VLOAD_FILE fssprite, (fsspriteend-fssprite), (VRAM_tiles + tiles * tile_size)

	; configure each sprites
	LOAD_r0 (VRAM_tiles + tiles * tile_size )
	ldx #0
	jsr Sprite::load

	LOAD_r0	(VRAM_tiles + tiles * tile_size + sprite_size )
	ldx #1
	jsr Sprite::load

	LOAD_r0 (VRAM_tiles + tiles * tile_size + sprite_size * 2)
	ldx #2
	jsr Sprite::load
	
	; turn sprite 0 on
	ldx #0
	ldy #SPRITE_ZDEPTH_TOP
	jsr Sprite::display

setirq:
   ; backup default RAM IRQ vector
   lda IRQVec
   sta default_irq_vector
   lda IRQVec+1
   sta default_irq_vector+1

   ; overwrite RAM IRQ vector with custom handler address
   sei ; disable IRQ while vector is changing
   lda #<custom_irq_handler
   sta IRQVec
   lda #>custom_irq_handler
   sta IRQVec+1
   lda #VERA_VSYNC_BIT ; make VERA only generate VSYNC IRQs
   sta veraien
   cli ; enable IRQ now that vector is properly set
	
mainloop:	
	wai
	; do nothing in main loop, just let ISR do everything
	bra mainloop

	rts

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; deal with IRQ"s
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------
custom_irq_handler:
   lda veraisr
   and #VERA_VSYNC_BIT
   beq continue 	; non-VSYNC IRQ, no tick update

	;---------------------------------
	; animate sprite
	;---------------------------------
	jsr Player::animate

	;---------------------------------
	; check keyboard
	;---------------------------------
@check_keyboard:
	lda #0
	jsr joystick_get
	
;  .A, byte 0:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;              NES  | A | B |SEL|STA|UP |DN |LT |RT |
;              SNES | B | Y |SEL|STA|UP |DN |LT |RT |
;
;  .X, byte 1:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;              NES  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | X |
;              SNES | A | X | L | R | 1 | 1 | 1 | 1 |
;  .Y, byte 2:
;              $00 = joystick present
;              $FF = joystick not present 
	bit #JOY_RIGHT
	beq moveright
	bit #JOY_LEFT
	beq moveleft
	bit #JOY_DOWN
	beq movedown
	bit #JOY_UP
	beq moveup

	lda #1
	jsr Player::set_idle

continue:
   ; continue to default IRQ handler
   jmp (default_irq_vector)
   ; RTI will happen after jump

moveleft:
	ldx #Layers::HSCROLL
	jsr Layers::scroll_dec
	ldx #Layers::HSCROLL
	jsr Layers::scroll_l0
	jsr Player::position_x_dec
	
	lda #SPRITE_FLIP_NONE
	sta player0 + PLAYER::flip
	jsr Player::display
	lda #0
	jsr Player::set_idle
	bra continue

moveright:
	VSCROLL_INC Layers::HSCROLL,(32*16-320 - 1)	; 32 tiles * 16 pixels per tiles - 320 screen pixels
	ldx #Layers::HSCROLL
	jsr Layers::scroll_l0
	jsr Player::position_x_inc
	
	lda #SPRITE_FLIP_H
	sta player0 + PLAYER::flip
	jsr Player::display
	lda #0
	jsr Player::set_idle
	bra continue
	
moveup:
	ldx #Layers::VSCROLL
	jsr Layers::scroll_dec
	ldx #Layers::VSCROLL
	jsr Layers::scroll_l0
	jsr Player::position_y_dec
	bra continue

movedown:
	VSCROLL_INC Layers::VSCROLL,(32*16-240 - 1)	; 32 tiles * 16 pixels per tiles - 240 screen pixels 
	ldx #Layers::VSCROLL
	jsr Layers::scroll_l0
	jsr Player::position_y_inc
	bra continue
	
.segment "DATA"
.include "tilemap.inc"
.include "sprite.inc"

default_irq_vector: .addr 0

.segment "BSS"
keyboard: .res 1
player0: .tag PLAYER