;-----------------------------------------------------------------------------
;/////////////////////////////////////////////////////////////////////////////
; START Layers code
;\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;-----------------------------------------------------------------------------

.scope Layers

LAYERS_ZP = $0055
wHScroll = LAYERS_ZP
wVScroll = LAYERS_ZP + 2
bDirty = LAYERS_ZP + 4

HSCROLL = 0
VSCROLL = 2

;************************************************
; init layers module
;
initModule:
	stz wHScroll
	stz wHScroll + 1

	stz wVScroll
	stz wVScroll + 1

	stz bDirty
	rts

;************************************************
; set layer1 X position
; input: X = xLO
;		 Y = xHI
set_x:
	; is a real change requested ?
	cpy wHScroll + 1
	bne @dirty
	cpx wHScroll
	bne @dirty
	rts
@dirty:
	stx wHScroll
	stx VERA_L1_hscrolllo
	sty wHScroll + 1
	sty VERA_L1_hscrollhi

	lda #01
	sta bDirty
	rts

;************************************************
; set layer1 y position
; input: X = yLO
;		 Y = yHI
set_y:
	; is a real change requested ?
	cpy wVScroll + 1
	bne @dirty
	cpx wVScroll
	bne @dirty
	rts
@dirty:
	stx wVScroll
	stx VERA_L1_vscrolllo
	sty wVScroll + 1
	sty VERA_L1_vscrollhi

	lda #01
	sta bDirty
	rts

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
	jsr Entities::fix_positions
	lda #01		; clear ZERO => scrolled
	rts
	
@noscroll:
	lda #00		; set ZERO => noscroll
	rts

;************************************************
; refresh layers 
;		layer 0 : scrolling to be half of the layer1 scrolling
;		entities : screen position = entity position - layers1 position
;
update:
	lda bDirty
	beq @return

	lda wHScroll + 1		; layer0 hScroll is layer 1 / 2
	lsr
	sta VERA_L0_hscrollhi
	lda wHScroll
	ror
	sta VERA_L0_hscrolllo

	lda wVScroll + 1		; layer0 hScroll is layer 1 / 2
	lsr
	sta VERA_L0_vscrollhi
	lda wVScroll
	ror
	sta VERA_L0_vscrolllo

	; fix the objects position now that the layers scrolled
	jsr Entities::fix_positions

	; clear dirty flag
	stz bDirty
@return:
	rts
.endscope
