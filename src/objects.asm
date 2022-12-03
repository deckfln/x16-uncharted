;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start OBJECT code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Objects

OBJECT_ZP = $0060	    ; memory reserved for objects

objects_map: .word 0
objects_sprites: .word 0    ; vera memory of the start of the sprites

.enum Attribute
    GRAB = 1
.endenum

.struct Object
	entity		.tag Entity
    imageID     .byte   ; ID of the image in the spritesheet
    attribute   .byte
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

    ; register the entity
    lda r3L
    ldy r3H
    jsr Entities::register

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
   	lda #%00010000					; collision mask 1
   	ldx #%01010000					; 16x16 sprite
	jsr Sprite::load

    ; display the object
	lda (r3)                        ; sprite id
    tay
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display
    
    ldy #Entity::bDirty
    lda #01
    sta (r3),y                      ; force the object to be placed on screen

    ; bDirty is TRUE
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
;   output: r3 = pointer to the object
;
set_position_index:
    lda Entities::get_pointer

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
    jsr Entities::set_position

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

;************************************************
; find the object with a sprite ID
;   input: A = spriteID
;   output: (r3) start of the address of the objects 
;           Y = memory index of the start of the object, $FF if no object
;
get_by_spriteID:
    sta OBJECT_ZP

    lda objects_map
    sta r3L
    lda objects_map + 1
    sta r3H

    lda (r3)            ; number of objects
    tax
    inc r3L             ; move to the first object

    ldy #00
@loop:
    lda (r3), y
    cmp OBJECT_ZP
    beq @found

    ; last object ?
    dex
    beq @no_object

    ; move to the next object
    tya
    clc
    adc #.sizeof(Object)
    tay
    bra @loop

@found:
    rts

@no_object:
    ldy #$ff
    rts

.endscope
