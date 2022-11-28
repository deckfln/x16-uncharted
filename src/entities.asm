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

.endscope