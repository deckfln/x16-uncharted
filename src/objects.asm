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
    sta r3L
    lda objects_map + 1
    sta r3H

    lda (r3)
    sta $31     ; number of objects
    stz $32     ; object #0

    inc r3L

@loop:
    ; get a free sprite
    jsr Sprite::new
    txa
    sta (r3)

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

	lda (r3)                        ; sprite id
    tay
   	ldx #%01010000					; 16x16 sprite
	jsr Sprite::load

    ; display the object
	lda (r3)                        ; sprite id
    tay
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display
    
    ; position the first object
    jsr set_position_r3

    ; last object ?
    dec $31
    beq @return

    ; move to the next object
    clc
    lda r3L
    adc #.sizeof(Object)
    sta r3L
    lda r3H
    adc #00
    sta r3H

    inc $32                     ; object #next
    bra @loop

@return:
    rts

;************************************************
; change  position of the sprite (level view) => (screen view)
;   input: X = index of the object
;
set_position_index:
    lda objects_map
    sta r3L
    lda objects_map + 1
    sta r3H
    inc r3L

    cpx #00                 ; ignore object 0
    beq @next

@mult:
    clc
    lda r3L
    adc #.sizeof(Object)
    sta r3L
    lda r3H
    adc #00
    sta r3H
    dex
    bne @mult               ; r2 = objects_map + X*sizeof(Object)

@next:

;************************************************
; change  position of the sprite (level view) => (screen view)
;   input: R3 = start of the object
;
set_position_r3:
    ; screenX = levelX - layer1_scroll_x
    ldy #Object::levelx
    sec
    lda (r3), y
    sbc VERA_L1_hscrolllo
    sta r0L
    iny
    lda (r3), y
    sbc VERA_L1_hscrolllo + 1
    sta r0H

    ; screenY = levelY - layer1_scroll_y
    ldy #Object::levely
    sec
    lda (r3), y
    sbc VERA_L1_vscrolllo
    sta r1L
    iny
    lda (r3), y
    sbc VERA_L1_vscrolllo + 1
    sta r1H

    ; save the screen positions in the object
    ldy #Object::px
    lda r0L
    sta (r3), Y
    iny
    lda r0H
    sta (r3), Y

    ldy #Object::py
    lda r1L
    sta (r3), Y
    iny
    lda r1H
    sta (r3), Y

    ; set the player position
	lda (r3)                        ; sprite id
    tay

    ; adresse of thepx, py attributes
    clc
    lda r3L
    adc #Object::px
    sta r0L
    lda r3H
    adc #00
    sta r0H
	jsr Sprite::position			; set position of the sprite

    rts

;************************************************
; change position of all sprites when the layer moves (level view) => (screen view)
;
fix_positions:
    lda objects_map
    sta r3L
    lda objects_map + 1
    sta r3H

    lda (r3)
    sta $31     ; number of objects
    stz $32
    inc r3L
    
@loop:
    ; position the first object
    jsr set_position_r3

    ; last object ?
    inc $32
    dec $31
    beq @return

    ; move to the next object
    clc
    lda r3L
    adc #.sizeof(Object)
    sta r3L
    lda r3H
    adc #00
    sta r3H

    bra @loop

@return:
    rts

.endscope
