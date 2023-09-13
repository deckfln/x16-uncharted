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

LOWMEM = $0400
HIMEM = $a000

SCREEN_WIDTH = 320
SCREEN_HEIGHT = 240
LEVEL_TILES_WIDTH = 32
LEVEL_WIDTH = LEVEL_TILES_WIDTH*16
LEVEL_HEIGHT = 32*16

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

;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; 
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.enum CLASS
	ENTITY
	PLAYER
.endenum

.include "utils/bresenhams.asm"
.include "joystick.asm"
.include "tiles.asm"
.include "sprites.asm"
.include "tilemap.asm"
.include "entities.asm"
.include "objects.asm"
.include "layers.asm"
.include "player.asm"

class_set_noaction:	 
	.byte <Entities::set_noaction, >Entities::set_noaction
	.byte <Player::set_noaction, >Player::set_noaction
class_restore_action:
	.byte <Entities::restore_action, >Entities::restore_action
	.byte <Player::restore_action, >Player::restore_action


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

	jsr Layers::initModule
	jsr Entities::initModule
	jsr Player::initModule

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
	; prepare VERA sprites 
	jsr Sprite::initModule

	LOAD_r0 (::VRAM_tiles + tiles * tile_size)	; base for the sprites
	jsr Player::init	

	;---------------------------------
	; load objects list into ram 
	;---------------------------------
	jsr Objects::initModule

	jsr Joystick::init_module

	jsr Entities::update				; place all entities on screen
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
	jsr Player::fn_animate

	;---------------------------------
	; swap animated tiles
	;---------------------------------
	jsr Tiles::update

	;---------------------------------
	; sprite collisions management
	;---------------------------------
	;jsr Sprite::check_irq_collision

	;---------------------------------
	; check keyboard/joystick
	;---------------------------------
	jsr Joystick::update

	;---------------------------------
	; deal with player controls
	;---------------------------------
	jsr Player::controls
	jsr Player::check_scroll_layers

	;---------------------------------
	; generic updates
	;---------------------------------
	jsr Layers::update					; refresh layers if needed
	jsr Entities::update				; place all entities on on screen

	; continue to default IRQ handler
@continue:
	jmp (default_irq_vector)
	; RTI will happen after jump

.segment "DATA"
.include "tilemap.inc"
.include "sprite.inc"

default_irq_vector: .addr 0
trigger_debug: .byte 0
