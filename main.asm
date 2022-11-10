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

TILE_SOLID_GROUND = 32
TILE_SOLID_LADER = 33

;---------------------------------
; joystick management
;---------------------------------

JOY_RIGHT 	= %00000001
JOY_LEFT 	= %00000010
JOY_DOWN 	= %00000100
JOY_UP 		= %00001000

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


.include "layers.asm"
.include "sprites.asm"
.include "player.asm"

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
	; load tilemaps into vram 
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
	; load collisionmap into ram 
	;---------------------------------
	lda #0
	sta $00
	LOAD_FILE fscollision, (fscollision_end-fscollision), HIMEM
	
	;---------------------------------
	; load sprite 0,1,2 into vram 
	;---------------------------------
load_sprites:
	; prepare VERA sprites 
	jsr Sprite::init_addr_table

	; load sprites data at the end of the tiles
	VLOAD_FILE fssprite, (fsspriteend-fssprite), (VRAM_tiles + tiles * tile_size)

	; configure each sprites
	lda #0
	sta r2L

	LOAD_r3 (VRAM_tiles + tiles * tile_size)	; base for the sprites
	
@loop:
	lda r2L
	asl
	asl				; sprite_index * 4
	adc r3H			; + sprite_index * 256 => sprite_index * 1024 (sprite_size)
	sta r0H	
	lda r3L
	sta r0L ; sprint index * 256 + sprite_base
	
	ldy r2L
	jsr Sprite::load

	inc r2L
	lda r2L
	cmp #9
	bne @loop
	
	; turn sprite 0 on
	ldy #3
	ldx #SPRITE_ZDEPTH_TOP
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
	; player physics
	;---------------------------------
	jsr Player::physics
	
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

	jsr Player::set_idle

continue:
   ; continue to default IRQ handler
   jmp (default_irq_vector)
   ; RTI will happen after jump

moveleft:
	jsr Player::move_left
	bra continue

moveright:
	jsr Player::move_right
	bra continue
	
moveup:
	jsr Player::move_up
	bra continue

movedown:
	jsr Player::move_down
	bra continue
	
.segment "DATA"
.include "tilemap.inc"
.include "sprite.inc"

default_irq_vector: .addr 0

.segment "BSS"
keyboard: .res 1
player0: .tag PLAYER
sprites_table: .res 256		; VERA memory of each of the 256 sprites
