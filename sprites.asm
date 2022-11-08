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
	; compute vera memory for the target sprite
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
