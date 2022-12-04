.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

   jmp start

.macro LOAD_r0 addr16
	lda #<addr16
	sta r0L
	lda #>addr16
	sta r0H
.endmacro
.macro SAVE_r0 addr16
	lda r0L
	sta addr16
	lda r0H
	sta addr16 + 1
.endmacro
.macro LOAD_r1 addr16
	lda #<addr16
	sta r1L
	lda #>addr16
	sta r1H
.endmacro
.macro LOAD_r3 addr16
	lda #<addr16
	sta r3L
	lda #>addr16
	sta r3H
.endmacro
   
.include "x16.inc"   
.include "vera.inc"

; VRAM Addresses
VRAM_layer0_map   = $00000
VRAM_layer1_map   = $00800
VRAM_tiles        = $01000

HIMEM = $a000

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 240
LEVEL_TILES_WIDTH = 32
LEVEL_WIDTH = LEVEL_TILES_WIDTH*16
LEVEL_HEIGHT = 32*16

.enum
	TILE_NO_COLLISION
	TILE_SOLID_GROUND
	TILE_SOLD_SLOP_LEFT
	TILE_SOLD_SLOP_RIGHT
	TILE_SOLID_LADER
	TILE_LEDGE
.endenum

.macro SET_DEBUG
	inc trigger_debug
.endmacro

.macro CHECK_DEBUG
	pha
	lda trigger_debug
	beq @no_debug
	dec trigger_debug
	stp
@no_debug:
	pla
.endmacro

;---------------------------------
; joystick management
;---------------------------------

JOY_RIGHT 	= %00000001
JOY_LEFT 	= %00000010
JOY_DOWN 	= %00000100
JOY_UP 		= %00001000
JOY_START	= %00010000
JOY_SEL		= %00100000
JOY_Y		= %01000000
JOY_B		= %10000000

JOY_A		= %10000000

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

current_load: .word 0		; end of the last memory load

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
	stx current_load
	sty current_load + 1
.endmacro

.macro LOAD_FILE_NEXT filename, length
	lda #1
	ldx #8
	ldy #0
	jsr SETLFS
	lda #length
	ldx #<filename
	ldy #>filename
	jsr SETNAM
	lda #0
	ldx current_load
	ldy current_load + 1
	jsr LOAD
	stx current_load
	sty current_load + 1
.endmacro

.scope Vera

vram_load: .word 0		; end of the last memory load

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
	stx Vera::vram_load
	sty Vera::vram_load + 1
.endmacro

.macro VLOAD_FILE_NEXT filename, length
	lda #1
	ldx #8
	ldy #0
	jsr SETLFS
	lda #length
	ldx #<filename
	ldy #>filename
	jsr SETNAM
	lda #(^Vera::vram_load + 2)
	ldx Vera::vram_load
	ldy Vera::vram_load + 1
	jsr LOAD
	stx Vera::vram_load
	sty Vera::vram_load + 1
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

.include "tiles.asm"
.include "sprites.asm"
.include "tilemap.asm"
.include "entities.asm"
.include "objects.asm"
.include "layers.asm"
.include "player.asm"

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; main code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------
	
objects: .word 0

start:
	; 320x240
	lda #64
	sta veradchscale
	sta veradcvscale

	; activate layer0
	lda #%01110001
;	and #(255-VERA_LAYER0)
;	ora #(VERA_LAYER1)             ; Read Video Register
	sta veradcvideo             ; Store new value to Video Register

	jsr Layers::init

	;---------------------------------
	; load tiles file into vram 
	;---------------------------------
	jsr Tiles::load_static

	;---------------------------------
	;---------------------------------
	; load tilemaps into vram 
	;---------------------------------
	jsr Tilemap::load

	; load animated tiles into ram 
	;---------------------------------
	jsr Tiles::load_anim

	;---------------------------------
	; load sprite 0,1,2 into vram 
	;---------------------------------
load_sprites:
	; prepare VERA sprites 
	jsr Sprite::init_addr_table

	LOAD_r0 (::VRAM_tiles + tiles * tile_size)	; base for the sprites
	jsr Player::init	

	;---------------------------------
	; load objects list into ram 
	;---------------------------------
	jsr Objects::init

	jsr Entities::update				; place all entitieson on screen
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
   lda veraien
   ora #VERA_VSYNC_BIT ; make VERA only generate VSYNC IRQs
   sta veraien
   cli ; enable IRQ now that vector is properly set
	
mainloop:	
	wai	
	bra mainloop

	rts

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; deal with IRQ"s
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------
custom_irq_handler:
	lda veraisr
	tax
	and #VERA_SPRCOL_BIT
	beq @check_vsync

@sprite_collision:
	sta veraisr						; acknowled the SPRCOL IRQ
	txa
	lsr
	lsr
	lsr
	lsr								; extract the collision mask (4:7)
	jsr Sprite::register_collision

@check_vsync:
	txa
	and #VERA_VSYNC_BIT
	beq @continue

@frame_update:
	sta veraisr						; acknowled the VSYNC IRQ

	;---------------------------------
	; animate sprite
	;---------------------------------
	jsr Player::animate

	;---------------------------------
	; swap animated tiles
	;---------------------------------
	jsr Tiles::animate

	;---------------------------------
	; sprite collisions management
	;---------------------------------
	jsr Sprite::check_irq_collision

	;---------------------------------
	; check keyboard
	;---------------------------------
@check_keyboard:
	; get fake-joystick data from keyboard
	lda #0
	jsr joystick_get
	sta joystick_data
	stx joystick_data + 1

	; get real joystick data
	lda #1
	jsr joystick_get
	cpy #0
	bne @check_buttons

	; if there is a joystick, mix the data
	and joystick_data
	sta joystick_data

	txa
	and joystick_data + 1
	sta joystick_data + 1

@check_buttons:
	; check button A press/release
	eor joystick_data_old + 1

	bit #JOY_A
	beq @save_data				; no change for the A

	lda joystick_data + 1
	bit #JOY_A
	beq @grab
@release:
	jsr Player::release_object
	bra @save_data
@grab:
	jsr Player::grab_object
@save_data:
	lda joystick_data + 1
	sta joystick_data_old + 1

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

@other_check:
	lda joystick_data

	bit #(JOY_RIGHT|JOY_B)
	beq @jump_right
	bit #(JOY_LEFT|JOY_B)
	beq @jump_left
	bit #JOY_RIGHT
	beq @joystick_right
	bit #JOY_LEFT
	beq @joystick_left
	bit #JOY_DOWN
	beq @movedown
	bit #JOY_UP
	beq @moveup
	bit #JOY_B
	beq @jump

	jsr Player::set_idle

@continue:
	jsr Layers::update					; refresh layers if needed
	jsr Entities::update				; place all entities on on screen
	jsr Player::check_scroll_layers

	; continue to default IRQ handler
	jmp (default_irq_vector)
	; RTI will happen after jump

@jump_right:
	lda #$01					; jump right
	jsr Player::jump
	bra @continue

@jump_left:
	lda #$ff					; jump left
	jsr Player::jump
	bra @continue

@joystick_left:
	jsr Player::move_left
	bra @continue

@joystick_right:
	jsr Player::move_right
	bra @continue

@moveup:
	jsr Player::move_up
	bra @continue

@movedown:
	jsr Player::move_down
	bra @continue

@jump:
	lda #0				; jump up
	jsr Player::jump
	bra @continue

.segment "DATA"
.include "tilemap.inc"
.include "sprite.inc"

default_irq_vector: .addr 0
trigger_debug: .byte 0
tiles_attributes: 
	.byte %00000000	;	TILE_NO_COLLISION
	.byte %00000111	;	TILE_SOLID_GROUND
	.byte %00000100	;	TILE_SOLD_SLOP_LEFT
	.byte %00000100	;	TILE_SOLD_SLOP_RIGHT
	.byte %00001001	;	TILE_SOLID_LADER
	.byte %00001001	;	TILE_LEDGE

.segment "BSS"
	joystick_data: .byte 0, 0
	joystick_data_old: .byte 0, 0
	sprites_table: .res 256		; VERA memory of each of the 256 sprites
	player0: .tag PLAYER
	player_on_slop: .byte 0
