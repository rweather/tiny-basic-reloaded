;
; Copyright (C) 2026 Rhys Weatherley
;
; Permission is hereby granted, free of charge, to any person obtaining a
; copy of this software and associated documentation files (the "Software"),
; to deal in the Software without restriction, including without limitation
; the rights to use, copy, modify, merge, publish, distribute, sublicense,
; and/or sell copies of the Software, and to permit persons to whom the
; Software is furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included
; in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
; OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
; DEALINGS IN THE SOFTWARE.
;

;---------------------------------------------------------------------------
;
; ANSI escape sequence handling for 6502 platforms.
;
;---------------------------------------------------------------------------

;
; Wait for a character from the console and read it into A.
;
; Preserves X and Y.  Modifies A.
;
CIN:
    jsr     CIN_SYS             ; Get a raw character from the system.
    cmp     #$1B                ; Is it ESC?
    beq     CIN_ESC
CIN_NO_ESC:
    rts                         ; No, then return it as is.
;
; Wait for a character with a timeout in X.  Modifies A.  Preserves X and Y.
; Carry set if a character is available, carry clear on timeout.
;
CIN_T:
    jsr     CIN_T_SYS           ; Wait for a raw character from the system.
    bcc     CIN_NO_ESC          ; If no character, nothing more do to.
    cmp     #$1B                ; Was the character ESC?
    beq     CIN_ESC
    sec                         ; If not, return it as-is.
    rts
;
; Process input ANSI key sequences to produce platform-independent codes.
;
CIN_ESC:
    stx     ANSITMP             ; Save X for later.
    ldx     #50                 ; Wait 50ms for another character to arrive.
    jsr     CIN_T_SYS
    bcc     CIN_ESC_ONLY
    cmp     #"["                ; Check for ESC [
    beq     CIN_ESC_SQUARE
    cmp     #"O"                ; Check for ESC O
    beq     CIN_ESC_O
CIN_ESC_ONLY:
    lda     #$1B                ; Escape sequence not recognized.
CIN_ESC_DONE:
    ldx     ANSITMP             ; Return ESC on its own to the caller.
    sec
    rts
;
CIN_ESC_O:                      ; Process a ESC O escape sequence.
    jsr     CIN_T_SYS           ; Get the next character after ESC O
    bcc     CIN_ESC_ONLY        ; On timeout, sequence not recognized.
CIN_ESC_ALPHA:
    ldx     #KEY_DEFS_ALPHA_END-KEY_DEFS_ALPHA-2
CIN_ESC_ALPHA_LOOP:
    cmp     KEY_DEFS_ALPHA,x    ; Search for an alphabetic escape.
    beq     CIN_ESC_ALPHA_DONE
    dex
    dex
    bpl     CIN_ESC_ALPHA_LOOP
    bmi     CIN_ESC_ONLY        ; Alpha escape not recognized.
CIN_ESC_ALPHA_DONE:
    lda     KEY_DEFS_ALPHA+1,x  ; Get the keycode to return.
    jmp     CIN_ESC_DONE
;
CIN_ESC_SQUARE:
    jsr     CIN_T_SYS           ; Get the next character after ESC [
    bcc     CIN_ESC_ONLY        ; On timeout, sequence not recognized.
    cmp     #"A"                ; Is this an alphabetic escape?
    bcs     CIN_ESC_ALPHA
    cmp     #$30                ; Expect ESC [ followed by 1 or 2 digits.
    bcc     CIN_ESC_ONLY
    cmp     #$3A
    bcs     CIN_ESC_ONLY
    and     #$0F
    sta     ANSITMP+1
    jsr     CIN_T_SYS           ; Get another character: expect digit or ~
    bcc     CIN_ESC_ONLY        ; On timeout, sequence not recognized.
    cmp     #"~"
    beq     CIN_ESC_TILDE
    cmp     #$30
    bcc     CIN_ESC_ONLY
    cmp     #$3A
    bcs     CIN_ESC_ONLY
    asl     ANSITMP+1
    asl     ANSITMP+1
    asl     ANSITMP+1
    asl     ANSITMP+1
    and     #$0F
    ora     ANSITMP+1
    sta     ANSITMP+1
    jsr     CIN_T_SYS           ; Get another character: expect ~
    bcc     CIN_ESC_ONLY        ; On timeout, sequence not recognized.
    cmp     #"~"
    bne     CIN_ESC_ONLY
CIN_ESC_TILDE:
    ldx     #KEY_DEFS_NUMERIC_END-KEY_DEFS_NUMERIC-2
    lda     ANSITMP+1
CIN_ESC_NUMERIC_LOOP:
    cmp     KEY_DEFS_NUMERIC,x  ; Search for a numeric escape.
    beq     CIN_ESC_NUMERIC_DONE
    dex
    dex
    bpl     CIN_ESC_NUMERIC_LOOP
    bmi     CIN_ESC_ONLY        ; Numeric escape not recognized.
CIN_ESC_NUMERIC_DONE:
    lda     KEY_DEFS_NUMERIC+1,x ; Get the keycode to return.
    jmp     CIN_ESC_DONE
;
; Clear the screen.
;
CLS:
    pha
    txa
    pha
    ldx     #0
CLS_LOOP:
    lda     CLS_STR,x
    beq     CLS_DONE
    jsr     COUT
    inx
    bne     CLS_LOOP
CLS_DONE:
    pla
    tax
    pla
    rts
CLS_STR:
    db      $1B, "[H", $1B, "[2J", $1B, "[0m", 0
;
; Key definitions for letter-based escape sequences, either ESC [ x or ESC O x.
;
KEY_DEFS_ALPHA:
    .db     $41,TB_K_UP         ; ESC [ A
    .db     $42,TB_K_DOWN       ; ESC [ B
    .db     $43,TB_K_RIGHT      ; ESC [ C
    .db     $44,TB_K_LEFT       ; ESC [ D
    .db     $46,TB_K_END        ; ESC [ F
    .db     $48,TB_K_HOME       ; ESC [ H
    .db     $50,TB_K_F1         ; ESC [ P or ESC O P
    .db     $51,TB_K_F2         ; ESC [ Q or ESC O Q
    .db     $52,TB_K_F3         ; ESC [ R or ESC O R
    .db     $53,TB_K_F4         ; ESC [ S or ESC O S
KEY_DEFS_ALPHA_END:
;
; Key defintions for number-based escape sequences.
;
KEY_DEFS_NUMERIC:
    .db     $01,TB_K_HOME       ; ESC [ 1 ~
    .db     $02,TB_K_INSERT     ; ESC [ 2 ~
    .db     $03,TB_K_DELETE     ; ESC [ 3 ~
    .db     $04,TB_K_END        ; ESC [ 4 ~
    .db     $05,TB_K_PGUP       ; ESC [ 5 ~
    .db     $06,TB_K_PGDN       ; ESC [ 6 ~
    .db     $11,TB_K_F1         ; ESC [ 11 ~
    .db     $12,TB_K_F2         ; ESC [ 12 ~
    .db     $13,TB_K_F3         ; ESC [ 13 ~
    .db     $14,TB_K_F4         ; ESC [ 14 ~
    .db     $15,TB_K_F5         ; ESC [ 15 ~
    .db     $16,TB_K_F5         ; ESC [ 16 ~ (alternate F5)
    .db     $17,TB_K_F6         ; ESC [ 17 ~
    .db     $18,TB_K_F7         ; ESC [ 18 ~
    .db     $19,TB_K_F8         ; ESC [ 19 ~
    .db     $20,TB_K_F9         ; ESC [ 20 ~
    .db     $21,TB_K_F10        ; ESC [ 21 ~
    .db     $23,TB_K_F11        ; ESC [ 23 ~
    .db     $24,TB_K_F12        ; ESC [ 24 ~
KEY_DEFS_NUMERIC_END:
