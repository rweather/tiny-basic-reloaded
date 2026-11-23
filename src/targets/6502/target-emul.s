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

;
; Emulator target for testing purposes.
;

;
; Configure the Tiny BASIC Reloaded core.
;
KEYBUF          .equ    $0200
BASIC_MEM       .equ    $0300
BASIC_MEM_END   .equ    $C000
;
; Include the Tiny BASIC Reloaded implementation.
;
    .org $E000
    .include tb-core.s
    .include tb-bytecode.s

    .org $FC00
;
; Reset vector for the system.
;
RESET:
    cld
    cli
    jmp     TB_START_WARM
;
; Wait for a character from the console and read it into A.
;
; Preserves X and Y.  Modifies A.
;
CIN_SYS:
    lda     $C7E7       ; Wait for a key in the emulator.
    and     #$7F
    rts
;
; Wait for a character with a timeout.  Modifies A.  Preserves X and Y.
;
CIN_T_SYS:
    stx     $C7E9       ; Set the emulator's key timeout.
    lda     $C7E8       ; Wait for the key up till the timeout.
    bpl     CIN_timeout
    and     #$7F        ; We have a key.
    sec
    rts
CIN_timeout:
    lda     #0          ; We don't have a key.
    clc
    rts
;
; Print a carriage return and line feed.
;
CRLF:
    lda     #$0D
    jsr     COUT
    lda     #$0A
    ; Fall through.
;
; Write a character to the output device.
;
; Preserves A, X, and Y.
;
COUT:
    sta     $C7EA               ; Write to the TTY.
    rts
;
; Peek at the input to see if it is CTRL-S or CTRL-C.  Preserves X and Y.
; Sets Z if CTRL-C is pressed.
;
CBREAK:
    lda     $C7E0               ; Peek at the keyboard.
    bpl     CBREAK_no
    bit     $C7E2               ; Take the key.
    cmp     #$83                ; Is it CTRL-C?
    beq     CBREAK_yes
    cmp     #$93                ; Is it CTRL-S?
    bne     CBREAK_no
    jsr     CIN                 ; Paused - wait for the user to press a key.
    cmp     #$03                ; Did the user press CTRL-C?
    bne     CBREAK_no           ; Any other key resumes output.
CBREAK_yes:
    lda     #0                  ; Set Z on exit for CTRL-C.
    rts
CBREAK_no:
    lda     #1                  ; Clear Z on exit for not CTRL-C.
    rts
;
; Include the ANSI escape handling code.
;
ANSITMP .equ    $16             ; Temporaries for ANSI escape code handling.
    .include ansi-escapes.s
;
; System vectors.
;
    .org    $FFFA
    dw      0
    dw      RESET
    dw      0
