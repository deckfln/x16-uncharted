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
	stx r2L		; save the attribute offset for later

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
	lda sprites_table, y
	adc r2L		; add the offset to the start of the sprite
	sta veralo	; vera = $1fc00 + sprite index (X) * 8
	rts

load:
	; compute verma memory for  the target sprite
	lda #<sprites_table
	sta r1L
	lda #>sprites_table
	sta r1H

	tya			; index of the sprite
	asl
	tay			; index of the address of the sprite (y*2)

	lda #0
	sta veractl
	lda #<(vram_sprd >> 16) | $10
	sta verahi
	lda (r1L), y
	sta veramid
	iny
	lda (r1L), y
	sta veralo	; vera = $1fc00 + sprite index (X) * 8

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
.endscope
