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
initModule:
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
    beq @return ; if no object in the level
    sta $31     ; number of objects
    stz $32     ; object #0

    inc r3L
@loop: 
    ; get a free sprite
    jsr Sprite::new
    txa
    ldy #Entity::spriteID
    sta (r3),y

    ; register the entity
    lda r3L
    ldy r3H
    jsr Entities::register
    txa
    ldy #Entity::id
    sta (r3),y

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

    ldy #Entity::spriteID
	lda (r3),y                        ; sprite id
    tay
   	lda #%00010000					; collision mask 1
   	ldx #%01010000					; 16x16 sprite
	jsr Sprite::load

    ; display the object
    ldy #Entity::spriteID
	lda (r3),y                       ; sprite id
    tay
	ldx #SPRITE_ZDEPTH_TOP
	jsr Sprite::display

	ldy #Entity::bFlags
	lda #(EntityFlags::physics | EntityFlags::moved | EntityFlags::colission_map_changed)
	sta (r3),y	                    ; force screen position and size to be recomputed
    jsr Entities::set_position

    jsr Entities::init_next         ; only init data not loaded from disk

    ; register virtual functions move_right/left
    lda (r3)
    asl
    tax
    lda #<Objects::move_right
    sta Entities::fnMoveRight_table,x
    lda #>Objects::move_right
    sta Entities::fnMoveRight_table+1,x
    lda #<Objects::move_left
    sta Entities::fnMoveLeft_table,x
    lda #>Objects::move_left
    sta Entities::fnMoveLeft_table+1,x

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
;   output: (r3) start of the object
;           Y = EntityID, $FF if no object
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

    ldy #Entity::spriteID
@loop:
    lda (r3), y
    cmp OBJECT_ZP
    beq @found

    ; last object ?
    dex
    beq @no_object

    ; move to the next object
    clc
    lda r3L
    adc #.sizeof(Object)
    sta r3L
    lda r3H
    adc #00
    sta r3H
    bra @loop

@found:
    ldy #Entity::id
    lda (r3), y
    tay
    rts

@no_object:
    ldy #$ff
    rts

;************************************************
; virtual function move_right
;   input: r3 = start of the object
move_right:
	lda #01
	sta Entities::bBasicCollisionTest		; for objects do basic collision

    jsr Entities::Walk::right

	stz Entities::bBasicCollisionTest		; remove basic collision
    rts

;************************************************
; virtual function move_left
;   input: r3 = start of the object
move_left:
	lda #01
	sta Entities::bBasicCollisionTest		; for objects do basic collision

    jsr Entities::Walk::left

	stz Entities::bBasicCollisionTest		; remove basic collision
    rts

.endscope
