;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start OBJECT code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Objects

objects_map: .word 0
objects_sprites: .word 0    ; vera memory of the start of the sprites

.struct Object
    spriteID    .byte   ; ID of the vera sprite
    imageID     .byte   ; ID of the image in the spritesheet
    levelx      .word   ; level position
    levely      .word 
    px          .word   ; screen position
    py          .word 
.endstruct

;************************************************
; init the object data of the level
;
init:
    ; load the list of objects at the end of the previous load
    lda current_load
    sta objects_map
    lda current_load + 1
    sta objects_map + 1
	LOAD_FILE_NEXT fsobjects, (fsobjects_end-fsobjects)

    ; load the sprites  of objects at the end of the previous vload
    lda Vera::vram_load
    sta objects_sprites
    lda Vera::vram_load + 1
    sta objects_sprites + 1
	VLOAD_FILE_NEXT fssprites1, (fssprites1_end-fssprites1)

    ; add each available sprites on screen
    lda objects_map
    sta r2L
    lda objects_map + 1
    sta r2H

    lda (r2)
    sta $31     ; number of objects

    inc r2L

@loop:
    ; get a free sprite
    jsr Sprite::new
    txa
    sta (r2)

    ; load the first object
	lda objects_sprites
	sta r0L
	lda objects_sprites + 1
	sta r0H
    jsr Sprite::vram_to_16_5
    lda r1L
    sta r0L
    lda r1H
    sta r0H

	lda (r2)                        ; sprite id
    tay
   	ldx #%01010000					; 16x16 sprite
	jsr Sprite::load

    ; display the object
	lda (r2)                        ; sprite id
    tay
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display
    
    ; position the first object
	lda (r2)                        ; sprite id
    tay

    ; adresse of thepx, py attributes
    clc
    lda r2L
    adc #Object::levelx
    sta r0L
    lda r2H
    adc #00
    sta r0H
	jsr Sprite::position			; set position of the sprite

    dec $31
    beq @return

    ; move to the next object
    clc
    lda r2L
    adc #.sizeof(Object)
    sta r2L
    lda r2H
    adc #00
    sta r2H

    bra @loop

@return:
    rts
.endscope
