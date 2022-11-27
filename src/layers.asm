;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Layers code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Layers

HSCROLL = 0
VSCROLL = 2

;************************************************
; increase layer scrolling with a 8bits limit
;	X: : 0 = horizontal
;	   : 2 = vertical
;	Y: limit
;
scroll_inc_8:
	sty r0L
	lda VERA_L1_hscrolllo, x
	cmp r0L
	beq @noscroll
@scrollinc:
	inc
	sta VERA_L1_hscrolllo, x
	bne @scrolled
	inc VERA_L1_hscrollhi, x
@scrolled:
	; fix the objects position now that the layers scrolled
	jsr Objects::fix_positions
	lda #01		; clear ZERO => scrolled
	rts
@noscroll:
	lda #00		; set ZERO => noscroll
	rts

;************************************************
; increase layer scrolling with a 16bits limit
;	X: : 0 = horizontal
;	   : 2 = vertical
;	r0L: limit
;
scroll_inc_16:
	lda VERA_L1_hscrolllo, x
	cmp r0L
	bne @scrollinc								; if low bits are not equals to the limit low bits => safe to increase
	tay
	lda VERA_L1_hscrollhi, x
	cmp r0H
	beq @noscroll								; if high bits are equals to the limit high bits => we reached the limit
	tya
@scrollinc:
	inc
	sta VERA_L1_hscrolllo, x
	bne @scrolled
	inc VERA_L1_hscrollhi, x
@scrolled:	
	; fix the objects position now that the layers scrolled
	jsr Objects::fix_positions
	lda #01	; clear ZERO => scrolled
	rts
@noscroll:
	lda #00	; set ZERO => noscroll
	rts

; increase a layer scroll offset but do NOT overlap
.macro VSCROLL_INC direction,limit
.if limit > 255
	LOAD_r0 limit
	ldx #direction
	jsr Layers::scroll_inc_16
.else
	ldy #limit
	ldx #direction
	jsr Layers::scroll_inc_8
.endif
.endmacro

;
;
; decrease a layer scroll offset
;	X : 0 = horizontal
;	  : 2 = vertical
;
scroll_dec:
	lda VERA_L1_hscrolllo, x
	beq @scrollHI			; 00 => decrease high bits
	dec
	sta VERA_L1_hscrolllo, x
	bra @scrolled
@scrollHI:
	ldy VERA_L1_hscrollhi, x
	beq @noscroll		; 0000 => no scrolling
	dec
	sta VERA_L1_hscrolllo, x
	dey
	tya
	sta VERA_L1_hscrollhi, x
	
@scrolled:
	; fix the objects position now that the layers scrolled
	jsr Objects::fix_positions
	lda #01		; clear ZERO => scrolled
	rts
	
@noscroll:
	lda #00		; set ZERO => noscroll
	rts

;
; force layer0 scrolling to be half of the layer1 scrolling
;
scroll_l0:
	lda VERA_L1_hscrollhi, x	; layer0 hScroll is layer 1 / 2
	lsr
	sta VERA_L0_hscrollhi, x
	lda VERA_L1_hscrolllo, x
	ror
	sta VERA_L0_hscrolllo, x
	rts
.endscope
