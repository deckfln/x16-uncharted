;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start ENTITY code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.struct Entity
    spriteID    .byte   ; ID of the vera sprite
	status		.byte	; status of the player : IDLE, WALKING, CLIMBING, FALLING
    levelx      .word   ; level position
    levely      .word 
    px          .word   ; screen position
    py          .word 
	falling_ticks .word	; ticks since the player is falling (thing t in gravity) 
	delta_x		.byte	; when driving by phisics, original delta_x value
	collision_addr	.word	; cached @ of the collision equivalent of the center of the player
.endstruct

.scope Entities

;************************************************
; init all attributes of an entity
;   input: R3 = start of the object
;
init:
    lda #00
    ldy #Entity::spriteID
	sta (r3), y
    ldy #Entity::status
	lda #STATUS_WALKING_IDLE
	sta (r3), y
    lda #00
    ldy #Entity::falling_ticks
	sta (r3),y 
    iny
	sta (r3),y 
    ldy #Entity::px
	sta (r3),y
    iny
	sta (r3),y
    ldy #Entity::py
	sta (r3),y
    iny
	sta (r3),y
    ldy #Entity::levelx
	sta (r3),y
    iny
	sta (r3),y
    ldy #Entity::levely
	sta (r3),y
    iny
	sta (r3),y
    rts

;************************************************
; change  position of the sprite (level view) => (screen view)
;   input: R3 = start of the object
;
set_position:
    ; screenX = levelX - layer1_scroll_x
    ldy #(Entity::levelx)
    sec
    lda (r3), y
    sbc VERA_L1_hscrolllo
    sta r0L
    iny
    lda (r3), y
    sbc VERA_L1_hscrolllo + 1
    sta r0H

    ; screenY = levelY - layer1_scroll_y
    ldy #(Entity::levely)
    sec
    lda (r3), y
    sbc VERA_L1_vscrolllo
    sta r1L
    iny
    lda (r3), y
    sbc VERA_L1_vscrolllo + 1
    sta r1H

    ; save the screen positions in the object
    ldy #(Entity::px)
    lda r0L
    sta (r3), y
    iny
    lda r0H
    sta (r3), y

    ldy #(Entity::py)
    lda r1L
    sta (r3), y
    iny
    lda r1H
    sta (r3), y

    ; get the sprite ID
	lda (r3)                        ; sprite id
    tay

    ; adresse of the and px, py attributes
    clc
    lda r3L
    adc #(Entity::px)
    sta r0L
    lda r3H
    adc #00
    sta r0H
	jsr Sprite::position			; set position of the sprite

    rts

;************************************************
; increase entity X position
;   input: R3 = start of the object
;
position_x_inc:
	; move the absolute position levelx + 1
	ldy #Entity::levelx
    lda (r3),y
    inc
    sta (r3),y
    bne :+
    iny
    lda (r3),y
    inc
    sta (r3),y
:
	
	ldy #Entity::px
    lda (r3),y
    inc
    sta (r3),y
    bne :+
    iny
	lda (r3),y
	inc
	sta (r3),y
:
	rts

;************************************************
; decrease entity X position
;   input: R3 = start of the object
;
position_x_dec:
	ldy #Entity::levelx
    lda (r3),y
    dec
    sta (r3),y
    cmp #$ff
    bne :+
    iny
    lda (r3),y
    dec
    sta (r3),y
:
	
	ldy #Entity::px
    lda (r3),y
    dec
    sta (r3),y
    cmp #$ff
    bne :+
    iny
	lda (r3),y
	dec
	sta (r3),y
:
	rts

;************************************************
; increase entity Y position
;   input: R3 = start of the object
;
position_y_inc:
	; move the absolute position levelx + 1
	ldy #Entity::levely
    lda (r3),y
    inc
    sta (r3),y
    bne :+
    iny
    lda (r3),y
    inc
    sta (r3),y
:
	
	ldy #Entity::py
    lda (r3),y
    inc
    sta (r3),y
    bne :+
    iny
	lda (r3),y
	inc
	sta (r3),y
:
	rts

;************************************************
; decrease entity X position
;   input: R3 = start of the object
;
position_y_dec:
	ldy #Entity::levely
    lda (r3),y
    dec
    sta (r3),y
    cmp #$ff
    bne :+
    iny
    lda (r3),y
    dec
    sta (r3),y
:
	
	ldy #Entity::py
    lda (r3),y
    dec
    sta (r3),y
    cmp #$ff
    bne :+
    iny
	lda (r3),y
	dec
	sta (r3),y
:
	rts

.endscope