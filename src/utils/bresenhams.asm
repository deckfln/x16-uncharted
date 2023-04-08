;/* Code Fragment 3 - Generalised Bresenham for arbitrary start and finish pixels */
.scope Utils

;************************************************
; init all attributes of an entity
;   input: r10 = x0, r11=y0
;          r12 = x1, r13 = y1
;   void line(int x0, int y0, int x1, int y1)
;
;    int px, py
;    int dx, dy
;    int sx, sy
;    int err, e2
sx: .byte 0
sy: .byte 0
err = r14
e2 = r15
dx = r8
dy = r9
px: .word 0
py: .word 0

line:
    x0 = r10
    y0 = r11
    x1 = r12
    y1 = r13

    stz sx
    stz sy

    ; if x1 > = x0:
    ;   dx = x1 - x0
    ;   sx = 1
    ; else
    ;   dx = x0 - x1
    ;   sx = -1
    sec
    lda x1
    sbc x0
    sta dx
    lda x1 + 1
    sbc x0 + 1
    sta dx + 1
    bmi @negx
@posx:          ; x1 >= x0
    lda #01
    sta sx      ; sx = 1
    bra @next
@negx:          ; x1 < x0
    clc
    lda dx
    eor #$ff
    adc #01
    sta dx
    lda dx + 1
    eor #$ff
    adc #00
    sta dx + 1  ; dx = -dx
    lda #$ff    ; sx = -1
    sta sx

@next:
    ; if y1 > = y0:
    ;   dy = y0 - y1
    ;   sy = 1
    ; else
    ;   dy = y1 - y0
    ;   sy = -1
    sec
    lda y0
    sbc y1
    sta dy
    lda y0 + 1
    sbc y1 + 1
    sta dy + 1
    bpl @negy
@posy:          ; y1 >= y0
    lda #$01
    sta sy      ; sy = -1
    bra @init_err
@negy:          ; x1 < x0
    clc
    lda dy
    eor #$ff
    adc #01
    sta dy
    lda dy + 1
    eor #$ff
    adc #00
    sta dy + 1  ; dy = -dy
    lda #$ff    
    sta sy      ; sy = 1

@init_err:  
    clc         ; err = dx + dy
    lda dx
    adc dy
    sta err
    lda dx + 1
    adc dy + 1
    sta err +1
  
    lda x0      ; px = x0
    sta px
    lda x0 + 1
    sta px + 1

    lda y0      ; py = y0
    sta py
    lda y0 + 1
    sta py + 1

;    while true
loop:
;        plot(x, y);
;        if px == x1 && py == y1 break;
    lda px
    cmp x1
    bne continue
    lda px + 1
    cmp x1 + 1
    bne continue
    lda py
    cmp y1
    bne continue
    lda py + 1
    cmp y1 + 1
    bne continue
    rts

continue:
    lda err     ; e2 = 2 * err;
    asl
    sta e2
    lda err + 1
    rol
    sta e2 + 1

;       if e2 >= dy             if dy < e2
;            err += dy   <=>        err += dy
;            px += sx               px += sx
    sec
    lda dy + 1      ; compare high bytes
    sbc e2 + 1
    bvc :+          ; the equality comparison is in the Z flag here
    eor #$80        ; the Z flag is affected here
:   bmi dy_lt_e2   ; if NUM1H < NUM2H then NUM1 < NUM2
    bvc :+          ; the Z flag was affected only if V is 1
    eor #$80        ; restore the Z flag to the value it had after SBC NUM2H
:   bne check_vs_dx  ; if NUM1H <> NUM2H then NUM1 > NUM2 (so NUM1 >= NUM2)
    lda dy          ; compare low bytes
    sbc e2
    beq check_vs_dx    ; if NUM1L == NUM2L
    bcc dy_lt_e2       ; if NUM1L < NUM2L then NUM1 < NUM2
    bra check_vs_dx
dy_lt_e2:
    clc
    lda err
    adc dy
    sta err
    lda err + 1
    adc dy + 1
    sta err + 1     ; err += dy

    lda sx
    bmi :+          
    clc             ; if sx >= 0 : x += 1
    lda px
    adc #01
    sta px
    lda px + 1
    adc #00
    sta px + 1
xright:
    jsr 0000
    bra check_vs_dx
:
    sec             ; if sx < 0 : x -= 1
    lda px
    sbc #01
    sta px
    lda px + 1
    sbc #00
    sta px + 1
xleft:
    jsr 0000


;        if e2 <= dx
;            err += dx 
;            py += sy
check_vs_dx:
    sec
    lda e2 + 1      ; compare high bytes
    sbc dx + 1
    bvc :+          ; the equality comparison is in the Z flag here
    eor #$80        ; the Z flag is affected here
:   bmi e2_le_dx   ; if NUM1H < NUM2H then NUM1 < NUM2
    bvc :+          ; the Z flag was affected only if V is 1
    eor #$80        ; restore the Z flag to the value it had after SBC NUM2H
:   bne e2_gt_dx   ; if NUM1H <> NUM2H then NUM1 > NUM2 (so NUM1 >= NUM2)
    lda e2          ; compare low bytes
    sbc dx
    beq e2_le_dx   ; the equality comparison is in the Z flag here
    bcc e2_le_dx   ; if NUM1L < NUM2L then NUM1 < NUM2
    bra e2_gt_dx

e2_le_dx:    
    clc
    lda err
    adc dx
    sta err
    lda err + 1
    adc dx + 1
    sta err + 1

    lda sy
    bmi :+          
    clc             ; if sy >= 0 : y += 1
    lda py
    adc #01
    sta py
    lda py + 1
    adc #00
    sta py + 1
yup:
    jsr 0000
    bne return
    bra next_loop
:
    sec             ; if sy < 0 : y -= 1
    lda py
    sbc #01
    sta py
    lda py + 1
    sbc #00
    sta py + 1
ydown:
    jsr 0000
    bne return
next_loop:
e2_gt_dx:
    jmp loop
return:
    rts
.endscope