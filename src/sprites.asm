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

SPRITES_ZP = $0070	; memory reserved for Sprites
packed_bits = SPRITES_ZP
sprites_table = $0400	; VERA memory of each of the 256 sprites

;-----------------------------------------
; sprites components collections
MAX_SPRITES = 32

sprites_xL: .res MAX_SPRITES
sprites_xH: .res MAX_SPRITES
sprites_yL: .res MAX_SPRITES
sprites_yH: .res MAX_SPRITES
sprites_x1L: .res MAX_SPRITES
sprites_x1H: .res MAX_SPRITES
sprites_y1L: .res MAX_SPRITES
sprites_y1H: .res MAX_SPRITES
sprites_aabb_x: .res MAX_SPRITES	; collision box INSIDE the sprite top-left corner
sprites_aabb_y: .res MAX_SPRITES
sprites_aabb_w: .res MAX_SPRITES	; collision box INSIDE the sprite height/width
sprites_aabb_h: .res MAX_SPRITES
sprites_collision_callback: .res (MAX_SPRITES * 2)

sprites_used: .res (128 / 8)	; bit map to manage available sprites
nb_sprites: .byte 1		; 1 reserved for the player
collisions: .word 0		; L = collision happened, H = collision mask
bCounter: .word 0

;************************************************
;  init sprites manager
; create a table with the VERA @addr for each sprite
;
initModule:
	; clear the sprites components
	ldx #(MAX_SPRITES-1)
	dex
:	
	stz sprites_xL,x
	stz sprites_xH,x
	stz sprites_yL,x
	stz sprites_yH,x
	stz sprites_aabb_w,x
	stz sprites_aabb_h,x
	stz sprites_aabb_x,x
	stz sprites_aabb_y,x
	dex
	bpl :-

	; activate sprite colisions
	;lda veraien
	;ora #VERA_SPRCOL_BIT
	;sta veraien

	; all sprites are availble but ZERO (reserved player)
	ldx #($7F / 8)
:
	stz sprites_used,X
	dex
	bne :-
	lda #%00000001
	sta sprites_used

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

;************************************************
; get a new available vera sprite
;	output: X = index of the vera sprite
;			0 = no sprite available
;
new:
	ldx #$00
:
	lda sprites_used,x
	cmp #$ff
	beq @next_byte

	; test each individual bit
	stx packed_bits
	ldx #01
	stx @bit_counter + 1
	ldx #00
@bit_counter:
	bit #01
	beq @found
	asl @bit_counter + 1
	inx
	cpx #08
	bne @bit_counter
	ldx packed_bits				; wtf, found no available bit ?
@next_byte:
	inx
	cmp #$80
	bne :-
	stp							; houston we have a pboelm, no srpite available
@found:
	stx bCounter				; counter bit
	ldx @bit_counter + 1
	stx @set_bit + 1
	ldx packed_bits
@set_bit:
	ora #01
	sta sprites_used,x

	txa	
	asl
	asl	
	asl							; index of the 8 bits packet * 8
	clc
	adc bCounter
	tax
	
	; count activated sprites
	cpx nb_sprites
	bcc :+

	inc nb_sprites
:
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

;************************************************
; configure the sprite
;	input: 	A = sprite collision mask
;			Y = sprite index
;		   	X = sprite size : 
;		   	r0 = vram @ of the sprite data
;
sprites_size: .byte 7, 15, 31, 63	; count byte 0 as a byte, so width is not "8" pixel nut "0" + "7" pixels

load:
	stx SPRITES_ZP
	sta SPRITES_ZP + 2
	sty SPRITES_ZP + 3
	jsr set_bitmap

	stz veradat					; x = 0
	stz veradat
	stz veradat					; y = 0
	stz veradat
	lda SPRITES_ZP + 2			; load collision mask
	ora #%00000000				; collision mask + sprite = disabled + vflip=none + hflip=none
	sta veradat
	lda SPRITES_ZP				; 32x32 sprite
	sta veradat

	lsr
	lsr
	lsr
	lsr
	sta SPRITES_ZP				; focus on sprite_height, sprite_width

	ldy SPRITES_ZP + 3			; sprite index

	and #%00000011				; sprite_width
	tax
	lda sprites_size,x
	sta sprites_aabb_w, y		; store width in pixels in the sprite attribute
	lda #00
	sta sprites_aabb_x, y		; default collision box starts (0,0)

	lda SPRITES_ZP
	lsr
	lsr							; sprite_height
	tax
	lda sprites_size,x
	sta sprites_aabb_h, y		; store height in pixels in the sprite attribute
	lda #00
	sta sprites_aabb_y, y		; default collision box starts (0,0)

	rts

;************************************************
; set the collision box of the sprite
;	input y = sprite index
;		r0L = top-left corner X
;		r0H = top-left corner Y
;		r1L = width
;		r1H = height
;
set_aabb:
	lda r0L
	sta sprites_aabb_x,y
	lda r0H
	sta sprites_aabb_y,y
	lda r1L
	sta sprites_aabb_w,y
	lda r1H
	sta sprites_aabb_h,y
	rts

;************************************************
; configure full veram memory (16:0) into optimized one (12:5)
;	input: r0 = vram @ of the sprite data
;	output: r1		
;
vram_to_16_5:
	; load full VERA memory (12:0) into R0
	lda r0L
	sta r1L
	lda r0H
	sta r1H		

	; convert full addr to vera mode (bit shiting >> 5)
	lda r1H
	lsr
	ror r1L
	lsr
	ror r1L
	lsr
	ror r1L
	lsr
	ror r1L						; bit shift 4x 16 bits vera memory
	lsr
	ror r1L						; bit shift 4x 16 bits vera memory
	sta r1H
	rts

;************************************************
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

;************************************************
; change the display byte for a sprite
;	Y = sprite index
;	X = display value to set
;
display:
	stx r0L		; save X for later
	sty r0H

	; set vram memory on the X sprite
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram
	lda veradat
	and #(<~SPRITE_ZDEPTH_TOP)
	ora r0L
	sta r0L

	ldy r0H
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram

	lda r0L
	sta veradat
	rts

;************************************************
; define position of sprite and recompute bounding box
;	Y = sprite index
;	r0 = addr of word X & word Y
;
position:
	; set vram memory on the X sprite
	sty SPRITES_ZP
	ldx #VSPRITE::x70
	jsr vram
	ldx SPRITES_ZP

	ldy #00
	lda sprites_aabb_x, x	; X offset of the collision box
	beq @no_xoffset
@xoffset:
	sec
	lda (r0L),y
	sta sprites_xL, x
	sbc sprites_aabb_x, x
	sta veradat	
	iny
	lda (r0L),y				
	sta sprites_xH, x
	sbc #00
	sta veradat				; X - xoffset => vera X
	bra @after_xoffset
@no_xoffset:
	lda (r0L),y
	sta veradat
	sta sprites_xL, x
	iny
	lda (r0L),y				
	sta veradat
	sta sprites_xH, x		; X => vera X
@after_xoffset:

	clc
	lda sprites_xL, x
	adc sprites_aabb_w, x
	sta sprites_x1L, x		
	lda sprites_xH, x
	adc #0
	sta sprites_x1H, x		;X1 = x + aabb.w

	lda sprites_aabb_y, x	; Y offset of the collision box
	beq @no_yoffset
@yoffset:
	sec
	lda (r0L),y
	sta sprites_yL, x
	sbc sprites_aabb_y, x
	sta veradat	
	iny
	lda (r0L),y
	sta sprites_yH, x
	sbc #0
	sta veradat				; Y - yoffset  => vera Y high
	bra @after_yoffset
@no_yoffset:
	iny
	lda (r0L),y				
	sta veradat
	sta sprites_yL, x
	iny
	lda (r0L),y				
	sta veradat
	sta sprites_yH, x		; y => vera Y
@after_yoffset:
	clc
	lda sprites_yL, x
	adc sprites_aabb_h, x
	sta sprites_y1L, x
	lda sprites_yH, x
	adc #00
	
	sta sprites_y1H, x		; Y1 = y + aabb.y + aabb.h

	rts

;************************************************
; Change the flipping of a sprite
;	input: Y = sprite index
;			A = value to set : 	SPRITE_FLIP_H / SPRITE_FLIP_V / SPRITE_FLIP_NONE
;
set_flip:
	sta SPRITES_ZP
	sty SPRITES_ZP + 1

	; set vram memory on the X sprite
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram

	; TODO: keep a cache of the sprite flip in RAM to avoid accessing twice the memory
	lda veradat				; get current value, move vera addr to next byte
	and #SPRITE_FLIP_CLEAR
	ora SPRITES_ZP			; change only the flip value
	sta SPRITES_ZP

	ldy SPRITES_ZP + 1
	ldx #VSPRITE::collision_zdepth_vflip_hflip
	jsr vram				; move vera addr back to the sprite
	lda SPRITES_ZP
	sta veradat
	rts

;************************************************
; increase collision box by 1
;	X = sprite index
;
aabb_x_inc:
	inc sprites_xL, x
	bne :+
	inc sprites_xH, x
:
	inc sprites_x1L, x
	bne :+
	inc sprites_x1H, x
:
	rts

;************************************************
; decrease collision box by 1
;	X = sprite index
;
aabb_x_dec:
	dec sprites_xL, x
	lda sprites_xL, x
	cmp #$ff
	bne :+
	dec sprites_xH, x
:
	dec sprites_x1L, x
	lda sprites_x1L, x
	cmp #$ff
	bne :+
	dec sprites_x1H, x
:
	rts

;************************************************
; increase collision box by 1
;	X = sprite index
;
aabb_y_inc:
	inc sprites_yL, x
	bne :+
	inc sprites_yH, x
:
	inc sprites_y1L, x
	bne :+
	inc sprites_y1H, x
:
	rts

;************************************************
; decrease collision box by 1
;	X = sprite index
;
aabb_y_dec:
	dec sprites_yL, x
	lda sprites_yL, x
	cmp #$ff
	bne :+
	dec sprites_yH, x
:
	dec sprites_y1L, x
	lda sprites_y1L, x
	cmp #$ff
	bne :+
	dec sprites_y1H, x
:
	rts

;************************************************
; register sprites collision
; input: A = collision mask
;
register_collision:
	inc collisions
	sta collisions + 1
	rts

;************************************************
; Axis Aligned Bounding Box collision between 2 sprites
; input: X = index of sprite 1
;		 Y = index of sprite 2
; return: Z = no collision
;
aabb_collision:
	lda sprites_xH, x		
	cmp sprites_x1H, y
	bcc :+				; if hi is less than, no need to test lo
	bne @false

	lda sprites_xL, x
	cmp sprites_x1L, y
	bcc :+
	bne @false
:						; s(x).left_x <= s(y).right_x

	lda sprites_xH, y
	cmp sprites_x1H, x
	bcc :+
	bne @false

	lda sprites_xL, y
	cmp sprites_x1L, x
	bcc :+
	bne @false
:						; AND s(y).left_x <= s(x).right_x

	lda sprites_yH, x
	cmp sprites_y1H, y
	bcc :+
	bne @false

	lda sprites_yL, x
	cmp sprites_y1L, y
	bcc :+
	bne @false
:						; AND s(x).bottom_y <= s(y).top_y

	lda sprites_yH, y
	cmp sprites_y1H, x
	bcc :+
	bne @false

	lda sprites_yL, y
	cmp sprites_y1L, x
	bcc :+
	bne @false
:						; AND s(y).bottom_y <= s(x).top_y

@true:
	lda #01
	rts
@false:
	lda #00
	rts

;************************************************
; after a collision IRQ, test all sprites to find colliding ones
; return: a = no collision
;
find_colliding:
	lda nb_sprites
	dec
	sta SPRITES_ZP
	dec
	sta SPRITES_ZP + 1

@inner_loop:
	ldx SPRITES_ZP
	ldy SPRITES_ZP + 1
	jsr aabb_collision
	bne @found

	dec SPRITES_ZP + 1
	bmi @try_next
	bra @inner_loop

@try_next:
	lda SPRITES_ZP
	dec
	beq @not_found
	sta SPRITES_ZP			; start comparison end - 1
	dec						; compare with start - 1 unless < 0
	sta SPRITES_ZP + 1
	bra @inner_loop

@not_found:
	lda #00
	rts
@found:
	lda #01
	rts

;************************************************
; manage collisions after a collision IRQ
;
check_irq_collision:
	lda collisions
	beq @return

	stz collisions		; clear the collision flag

	jsr find_colliding
	
@return:
	rts

;************************************************
; check if sprite X collides with any of the others
; input : X = sprite index to test
; return: a = index of sprite in collision or $FF if no collision
;
check_collision:
	stx SPRITES_ZP
	lda nb_sprites
	dec
	beq @no_collision		; if there is only 1 sprite, no_collision
	tay						; start with the last sprite
@loop:
	cpy SPRITES_ZP
	beq @next				; ignore the input sprite
	jsr aabb_collision
	bne @collision
@next:
	dey
	bmi @no_collision		; 0 has to be taked care off
	bra @loop

@collision:
	tya						; store index of the colliding sprite
	rts

@no_collision:
	lda #$ff
	rts

;************************************************
; simulate a sprite movement and check collision
;	input A = vertical (1) / horizontal (2)
;			  plus (4) / minus (8)
;		  X = sprite index
; 	return: a = index of colliding sprite, $ff if no collision
;
precheck_collision:
	stx SPRITES_ZP + 3
	sta SPRITES_ZP + 2

	bit #$01
	bne @vertical
@horizontal:	
	bit #$08
	bne @horizontal_minus

@horizontal_plus:
	; save current X, X1 and add the delta
	clc
	lda sprites_xL, x
	sta SPRITES_ZP + 5
	adc #01
	sta sprites_xL, x

	lda sprites_xH, x
	sta SPRITES_ZP + 6
	adc #00
	sta sprites_xH, x
@horizontal_plus_width:
	clc
	lda sprites_x1L, x
	sta SPRITES_ZP + 7
	adc #01
	sta sprites_x1L, x

	lda sprites_x1H, x
	sta SPRITES_ZP + 8
	adc #00
	sta sprites_x1H, x
	jmp @test

@horizontal_minus:
	sec
	lda sprites_xL, x
	sta SPRITES_ZP + 5
	sbc #01
	sta sprites_xL, x

	lda sprites_xH, x
	sta SPRITES_ZP + 6
	sbc #00
	sta sprites_xH, x
@horizontal_minus_width:
	sec
	lda sprites_x1L, x
	sta SPRITES_ZP + 7
	sbc #01
	sta sprites_x1L, x

	lda sprites_x1H, x
	sta SPRITES_ZP + 8
	sbc #00
	sta sprites_x1H, x
	bra @test

@vertical:
	bit #08
	bne @vertical_minus
@vertical_plus:
	; save current Y, Y1 and add delta
	clc
	lda sprites_yL, x
	sta SPRITES_ZP + 5
	adc #01
	sta sprites_yL, x

	lda sprites_yH, x
	sta SPRITES_ZP + 6
	adc #00
	sta sprites_yH, x

	clc
	lda sprites_y1L, x
	sta SPRITES_ZP + 7
	adc #01
	sta sprites_y1L, x

	lda sprites_y1H, x
	sta SPRITES_ZP + 8
	adc #00
	sta sprites_y1H, x
	bra @test
@vertical_minus:
	; save current Y, Y1 and add delta
	sec
	lda sprites_yL, x
	sta SPRITES_ZP + 5
	sbc #01
	sta sprites_yL, x

	lda sprites_yH, x
	sta SPRITES_ZP + 6
	sbc #00
	sta sprites_yH, x

	sec
	lda sprites_y1L, x
	sta SPRITES_ZP + 7
	sbc #01
	sta sprites_y1L, x

	lda sprites_y1H, x
	sta SPRITES_ZP + 8
	sbc #00
	sta sprites_y1H, x

@test:
	jsr check_collision
	sta SPRITES_ZP + 4		; save the result

@restore:
	; and restore the data
	ldx SPRITES_ZP + 3
	lda SPRITES_ZP + 2
	bit #02
	beq @vertical_restore
@horizontal_restore:
	lda SPRITES_ZP + 5
	sta sprites_xL, x
	lda SPRITES_ZP + 6
	sta sprites_xH, x
	lda SPRITES_ZP + 7
	sta sprites_x1L, x
	lda SPRITES_ZP + 8
	sta sprites_x1H, x
	bra @return

@vertical_restore:
	lda SPRITES_ZP + 5
	sta sprites_yL, x
	lda SPRITES_ZP + 6
	sta sprites_yH, x
	lda SPRITES_ZP + 7
	sta sprites_y1L, x
	lda SPRITES_ZP + 8
	sta sprites_y1H, x

@return:
	lda SPRITES_ZP + 4	; result of the collision
	rts

.endscope
