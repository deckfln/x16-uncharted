;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
;           start JOYSTICK code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

JOYSTICK_ZP = $40
joystick_data = JOYSTICK_ZP
joystick_data_old = JOYSTICK_ZP + 2
joystick_data_change = JOYSTICK_ZP + 4


;---------------------------------
; joystick management
;---------------------------------

.scope Joystick

JOY_RIGHT 	= %00000001
JOY_LEFT 	= %00000010
JOY_DOWN 	= %00000100
JOY_UP 		= %00001000
JOY_START	= %00010000
JOY_SEL		= %00100000
JOY_Y		= %01000000
JOY_B		= %10000000
JOY_A		= %10000000

;*******************************
;*
;*
init_module:
    jsr update
    stz joystick_data_change    
    stz joystick_data_change + 1
    rts

;*******************************
;*
;*
update:
	; get fake-joystick data from keyboard
	lda #0
	jsr joystick_get
	sta joystick_data
	stx joystick_data + 1

	; get real joystick data
	lda #1
	jsr joystick_get
	cpy #0
	bne @check_buttons_changes

	; if there is a joystick, mix the data
	and joystick_data
	sta joystick_data

	txa
	and joystick_data + 1
	sta joystick_data + 1

@check_buttons_changes:
    lda joystick_data
	eor joystick_data_old
    sta joystick_data_change

    lda joystick_data + 1
	eor joystick_data_old + 1
    sta joystick_data_change + 1

@save_data:
	lda joystick_data
	sta joystick_data_old
	lda joystick_data + 1
	sta joystick_data_old + 1
    rts

;  .A, byte 0:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;              NES  | A | B |SEL|STA|UP |DN |LT |RT |
;              SNES | B | Y |SEL|STA|UP |DN |LT |RT |
;
;  .X, byte 1:      | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
;              NES  | 0 | 0 | 0 | 0 | 0 | 0 | 0 | X |
;              SNES | A | X | L | R | 1 | 1 | 1 | 1 |
;  .Y, byte 2:
;              $00 = joystick present
;              $FF = joystick not present 
.endscope