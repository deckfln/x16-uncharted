;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Sprite code
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
;
; create a table with the VERA @addr for each sprite
;
init_addr_table:
	; start of the sprites in VERA memory
	lda #<vram_sprd
	sta r0L
	lda #>vram_sprd
	sta r0H

	ldx #128
	ldy #0
 @loop:	
	lda r0H
	sta sprites_table,y
	iny
	lda r0L
	sta sprites_table,y
	iny

	clc
	lda r0L
	adc #8
	sta r0L
	lda r0H
	adc #0
	sta r0H	; move to next sprite

	dex
	bne @loop

	rts

;
; the the VERA memory pointer to sprite Y + attribute X
;	Y = sprite index
;	X = attribute offset
;
vram:
	phx			; save X on the stack

	tya			; index of the sprite
	asl
	tay			; index of the address of the sprite (y*2)

	lda #0
	sta veractl
	lda #<(vram_sprd >> 16) | $10
	sta verahi
	lda sprites_table, y
	sta veramid
	iny
	tsx
	lda $0101,x	; reload X from the stack
	adc sprites_table, y
	sta veralo	; vera = $1fc00 + sprite index (X) * 8
	plx
	rts

load:
	jsr set_bitmap

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
; change the address of the bitmap for the sprite
;	Y = sprite index
;	r0 = vera memory (12:5)
;
set_bitmap:
	ldx #VSPRITE::address125
	jsr vram			; set very pointer to the address of the bitmap

	lda r0L
	sta veradat
	lda r0H
	ora #$80						; M = 8 bits
	sta veradat

	rts
;
; change the display byte for a sprite
;	Y = sprite index
;	X = display value to set
;
display:
	stx r0L		; save X for later

	; set vram memory on the X sprite
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram

	lda r0L
	sta veradat
	rts

;
; define position of sprite
;	Y = sprite index
;	r0 = addr of word X & word Y
;
position:
	; set vram memory on the X sprite
	ldx #VSPRITE::x70
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

;
; Change the flipping of a sprite
;	Y = sprite index
;	A = value to set
;
set_flip:
	sta $30
	sty $31

	; set vram memory on the X sprite
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram

	lda veradat				;get current value
	and #SPRITE_FLIP_CLEAR
	ora $30					; change only the flip value
	sta $30

	ldy $31
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram
	lda $30
	sta veradat
	rts
.endscope
