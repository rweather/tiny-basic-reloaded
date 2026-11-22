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
; Tiny BASIC Reloaded for Ben Eater's 6502 Breadboard Computer.
;

;
; Configure the Tiny BASIC Reloaded core.
;
KEYBUF          .equ    $0200
BASIC_MEM       .equ    $0300
BASIC_MEM_END   .equ    $3F00
;
; Include the Tiny BASIC Reloaded implementation.
;
    .org $8000
    .db 0
    .org $E000
    .include tb-core.s
    .include tb-bytecode.s
;
; The rest of this file contains the ROM monitor support routines for BASIC.
;
    .org $FC00
;
; Zero page variables.
;
SERWR   .equ    $10         ; Serial buffer write position.
SERRD   .equ    $11         ; Serial buffer read position.
SYSTICK .equ    $12         ; 16-bit millisecond tick counter.
TIMEOUT .equ    $14         ; Start of a timeout period.
;
; Location of the 256-byte serial input buffer in RAM.
;
SERBUF  .equ    $3F00
;
; Number of T2 counts for a millisecond at 1MHz.  Adjust for other speeds.
;
T2COUNT .equ    1000
;
; I/O ports on the 6551 Asynchronous Communications Interface Adapter
; https://www.westerndesigncenter.com/wdc/documentation/w65c51n.pdf
;
ACIA_DATA           .equ    $5000
ACIA_STATUS         .equ    $5001
ACIA_CMD            .equ    $5002
ACIA_CTRL           .equ    $5003
;
; Bits of interest in the ACIA registers.
;
ACIA_IRQ            .equ    %10000000   ; ACIA_STATUS register.
ACIA_DSR            .equ    %01000000
ACIA_DCDB           .equ    %00100000
ACIA_TDRE           .equ    %00010000
ACIA_RDRF           .equ    %00001000
ACIA_OVRN           .equ    %00000100
ACIA_FE             .equ    %00000010
ACIA_PE             .equ    %00000001
ACIA_ERR            .equ    %00000111   ; Error bits.
ACIA_SBN            .equ    %10000000   ; ACIA_CTRL register.
ACIA_WL1            .equ    %01000000
ACIA_WL0            .equ    %00100000
ACIA_RCS            .equ    %00010000
ACIA_BPS_115200     .equ    %00000000
ACIA_BPS_300        .equ    %00000110
ACIA_BPS_1200       .equ    %00001000
ACIA_BPS_2400       .equ    %00001010
ACIA_BPS_9600       .equ    %00001110
ACIA_BPS_19200      .equ    %00001111
ACIA_PMC1           .equ    %10000000   ; ACIA_CMD register.
ACIA_PMC0           .equ    %01000000
ACIA_PME            .equ    %00100000
ACIA_REM            .equ    %00010000
ACIA_TIC1           .equ    %00001000
ACIA_TIC0           .equ    %00000100
ACIA_IRD            .equ    %00000010
ACIA_DTR            .equ    %00000001
;
; I/O ports on the 6522 Versatile Interface Adapter.
; https://eater.net/datasheets/w65c22.pdf
;
VIA_PORTB           .equ    $6000
VIA_PORTA           .equ    $6001
VIA_DDRB            .equ    $6002
VIA_DDRA            .equ    $6003
VIA_T1CL            .equ    $6004
VIA_T1CH            .equ    $6005
VIA_T1LL            .equ    $6006
VIA_T1LH            .equ    $6007
VIA_T2CL            .equ    $6008
VIA_T2CH            .equ    $6009
VIA_SR              .equ    $600A
VIA_ACR             .equ    $600B
VIA_PCR             .equ    $600C
VIA_IFR             .equ    $600D
VIA_IER             .equ    $600E
VIA_PORTA_NO_HAND   .equ    $600F
;
; Bits of interest in the VIA's Auxiliary Control Register (ACR).
;
VIA_ACR_T1_ONE_SHOT .equ    %00000000   ; T1 timer one-shot mode.
VIA_ACR_T1_FREE_RUN .equ    %01000000   ; T1 timer free-run mode.
VIA_ACR_T1_ONE_OUT  .equ    %10000000   ; T1 timer one-shot output on PB7.
VIA_ACR_T1_SQUARE   .equ    %11000000   ; T1 timer square wave output on PB7.
VIA_ACR_T1_BITS     .equ    %11000000   ; Bit mask for T1 control bits.
VIA_ACR_T2_ONE_SHOT .equ    %00000000   ; T2 timer one-shot mode.
VIA_ACR_T2_PULSE    .equ    %00100000   ; T2 timer pulse counting on PB6.
VIA_ACR_T2_BITS     .equ    %00100000   ; Bit mask for T2 control bits.
VIA_ACR_SR_DISABLE  .equ    %00000000   ; Shift register is disabled.
VIA_ACR_SR_SI_T2    .equ    %00000100   ; Shift in under control of T2.
VIA_ACR_SR_SI_PHI2  .equ    %00001000   ; Shift in under control of PHI2.
VIA_ACR_SR_SI_EXT   .equ    %00001100   ; Shift in under control of ext clock.
VIA_ACR_SR_SO_FREE  .equ    %00010000   ; Shift out free-running at T2 rate.
VIA_ACR_SR_SO_T2    .equ    %00010100   ; Shift out under control of T2.
VIA_ACR_SR_SO_PHI2  .equ    %00011000   ; Shift out under control of PHI2.
VIA_ACR_SR_SO_EXT   .equ    %00011100   ; Shift out under control of ext clock.
VIA_ACR_SR_BITS     .equ    %00011100   ; Bit mask for SR control bits.
VIA_ACR_PA_LATCH    .equ    %00000010   ; Enable latching on PORTA.
VIA_ACR_PB_LATCH    .equ    %00000001   ; Enable latching on PORTB.
;
; Bits of interest in the VIA's Peripheral Control Register (PCR).
;
VIA_PCR_CB2_NEG     .equ    %00000000   ; CB2 negative active edge.
VIA_PCR_CB2_INEG    .equ    %00100000   ; CB2 independent negative edge.
VIA_PCR_CB2_POS     .equ    %01000000   ; CB2 positive active edge.
VIA_PCR_CB2_IPOS    .equ    %01100000   ; CB2 independent positive edge.
VIA_PCR_CB2_HAND    .equ    %10000000   ; CB2 handshake output.
VIA_PCR_CB2_PULSE   .equ    %10100000   ; CB2 pulse output.
VIA_PCR_CB2_LOW     .equ    %11000000   ; CB2 low output.
VIA_PCR_CB2_HIGH    .equ    %11100000   ; CB2 high output.
VIA_PCR_CB1_NEG     .equ    %00000000   ; CB1 negative active edge.
VIA_PCR_CB1_POS     .equ    %00010000   ; CB1 positive active edge.
VIA_PCR_CA2_NEG     .equ    %00000000   ; CB2 negative active edge.
VIA_PCR_CA2_INEG    .equ    %00000010   ; CA2 independent negative edge.
VIA_PCR_CA2_POS     .equ    %00000100   ; CA2 positive active edge.
VIA_PCR_CA2_IPOS    .equ    %00000110   ; CA2 independent positive edge.
VIA_PCR_CA2_HAND    .equ    %00001000   ; CA2 handshake output.
VIA_PCR_CA2_PULSE   .equ    %00001010   ; CA2 pulse output.
VIA_PCR_CA2_LOW     .equ    %00001100   ; CA2 low output.
VIA_PCR_CA2_HIGH    .equ    %00001110   ; CA2 high output.
VIA_PCR_CA1_NEG     .equ    %00000000   ; CA1 negative active edge.
VIA_PCR_CA1_POS     .equ    %00000001   ; CA1 positive active edge.
;
; Bits of interest in the VIA's Interrupt Flag Register (IFR).
;
VIA_IFR_IRQ         .equ    %10000000   ; Any enabled interrupt.
VIA_IFR_T1          .equ    %01000000   ; T1 timer interrupt.
VIA_IFR_T2          .equ    %00100000   ; T2 timer interrupt.
VIA_IFR_CB1         .equ    %00010000   ; CB1 input edge interrupt.
VIA_IFR_CB2         .equ    %00001000   ; CB2 input edge interrupt.
VIA_IFR_SR          .equ    %00000100   ; Shift register interrupt.
VIA_IFR_CA1         .equ    %00000010   ; CA1 input edge interrupt.
VIA_IFR_CA2         .equ    %00000001   ; CA2 input edge interrupt.
;
; Bits of interest in the VIA's Interrupt Enable Register (IER).
;
VIA_IER_SET         .equ    %10000000   ; Set ints specified in low bits.
VIA_IER_CLEAR       .equ    %00000000   ; Clear ints specified in low bits.
VIA_IER_T1          .equ    %01000000   ; T1 timer interrupt.
VIA_IER_T2          .equ    %00100000   ; T2 timer interrupt.
VIA_IER_CB1         .equ    %00010000   ; CB1 input edge interrupt.
VIA_IER_CB2         .equ    %00001000   ; CB2 input edge interrupt.
VIA_IER_SR          .equ    %00000100   ; Shift register interrupt.
VIA_IER_CA1         .equ    %00000010   ; CA1 input edge interrupt.
VIA_IER_CA2         .equ    %00000001   ; CA2 input edge interrupt.
;
; Reset vector for the system.
;
RESET:
    cld                 ; Make sure that D is off.
    sei                 ; Disable interrupts until we are ready.
    ldx     #$FF        ; Set up the initial stack pointer.
    txs
;
; Delay at startup to let the power rails settle.  Otherwise the
; VIA and ACIA may not reset correctly.
;
    ldy     #0
    lda     #0
STARTUP_DELAY:
    adc     #1
    bne     STARTUP_DELAY
    dey
    bne     STARTUP_DELAY
;
; Initialize the serial port.
;
    stz     SERWR       ; Reset the write and read pointers.
    stz     SERRD
    lda     ACIA_STATUS ; Clear spurious status bits.
    lda     ACIA_DATA   ; Empty the receive buffer.
    stz     ACIA_STATUS ; Force the ACIA to reset itself.
    lda     #(ACIA_BPS_19200 | ACIA_RCS)
    sta     ACIA_CTRL
    lda     #(ACIA_TIC1 | ACIA_DTR)
    sta     ACIA_CMD
;
; Initialize the T2 timer in the VIA to provide a 1ms timebase.
;
    lda     #(VIA_IER_SET | VIA_IER_T2)
    sta     VIA_IER
    lda     #(VIA_ACR_T2_ONE_SHOT | VIA_ACR_SR_SO_PHI2)
    sta     VIA_ACR
    lda     #<T2COUNT   ; T2 interrupt every T2COUNT clock ticks.
    sta     VIA_T2CL
    lda     #>T2COUNT
    sta     VIA_T2CH
;
; Zero out the system millisecond tick counter.
;
    stz     SYSTICK
    stz     SYSTICK+1
;
; It is now safe to turn interrupts on.
;
    cli
;
; Jump to the BASIC warm start vector.  If we are actually starting
; from cold, the warm start vector will force a cold start.
;
    jmp     TB_START_WARM
;
; Wait for a character from the serial port and read it into A.
;
; Preserves X and Y.  Modifies A.
;
CIN:
    jsr     CIN_NOWAIT
    bcs     CIN_READY
    inc     TB_SEED     ; Increment the random number seed while waiting.
    bne     CIN
    inc     TB_SEED+1
    bra     CIN
CIN_READY:
    rts
;
; Read a character from the serial port into A.  Zero if no character.
; Z is also set if there is no character.
;
; Preserves X and Y.  Modifies A.
;
CIN_NOWAIT:
    phx
    ldx     SERRD       ; Is there a character in the serial buffer?
    cpx     SERWR
    beq     CIN_NONE    ; If not, then return zero and exit.
    lda     SERBUF,x    ; Get the character.
    pha
    inc     SERRD       ; Increment the buffer's read pointer.
    lda     SERWR
    sec
    sbc     SERRD
    cmp     #224        ; Are we below the low water mark?
    bge     CIN_DONE
    lda     #$09        ; If yes, turn receive interrupts back on.
    sta     ACIA_CMD
CIN_DONE:
    pla
    plx
    sec
    rts
CIN_NONE:
    plx
    lda     #0
    clc
    rts
;
; Get a character from the serial port with a timeout in milliseconds.
;
CIN_T:
    cpx     #0
    beq     CIN_NOWAIT
    phy
    php
    txa
    clc
    cli
    adc     SYSTICK
    sta     TIMEOUT
    lda     SYSTICK+1
    adc     #0
    sta     TIMEOUT+1
    plp
CIN_T_LOOP:
    jsr     CIN_NOWAIT
    bcs     CIN_T_DONE
    inc     TB_SEED     ; Increment the random number seed while waiting.
    bne     CIN_T_CHECK
    inc     TB_SEED+1
CIN_T_CHECK:
    php
    cli
    lda     SYSTICK
    sec
    sbc     TIMEOUT
    lda     SYSTICK+1
    sbc     TIMEOUT+1
    bpl     CIN_T_TIMEOUT
    plp
    jmp     CIN_T_LOOP
CIN_T_TIMEOUT:
    plp
    ply
    clc
    rts
CIN_T_DONE:
    ply
    sec
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
; Write a character to the serial port.
;
; Preserves A, X, and Y.
;
COUT:
    phx
    sta     ACIA_DATA   ; Write the character to the serial port.
    ldx     #$80        ; Delay to wait for the character to be sent.
COUT_delay:
    dex
    bne     COUT_delay
    plx
    rts
;
; Clear the screen.
;
CLS:
    pha
    phx
    ldx     #0
CLS_LOOP:
    lda     CLS_STR,x
    beq     CLS_DONE
    jsr     COUT
    inx
    bne     CLS_LOOP
CLS_DONE:
    plx
    pla
    rts
CLS_STR:
    db      $1B, "[H", $1B, "[2J", $1B, "[0m", 0
;
; Peek at the input to see if it is CTRL-S or CTRL-C.  Preserves X and Y.
; Sets Z if CTRL-C is pressed.
;
CBREAK:
    jsr     CIN_NOWAIT
    beq     CBREAK_no
    cmp     #$03        ; Is it CTRL-C?
    beq     CBREAK_yes
    cmp     #$13        ; Is it CTRL-S?
    bne     CBREAK_no
    jsr     CIN         ; Paused - wait for the user to press a key.
    cmp     #$03        ; Did the user press CTRL-C?
    bne     CBREAK_no   ; Any other key resumes output.
CBREAK_yes:
    lda     #0          ; Set Z on exit for CTRL-C.
    rts
CBREAK_no:
    lda     #1          ; Clear Z on exit for not CTRL-C.
    rts
;
; Interrupt handler.
;
IRQBRK:
    cld                 ; Make sure that D is off during the handler.
    pha                 ; Save the A and X registers on the stack.
    phx
    lda     ACIA_STATUS ; Did we receive a character via the ACIA?
    and     #ACIA_RDRF
    beq     IRQVIA
    lda     ACIA_DATA   ; Get the received byte into A.
    phx
    ldx     SERWR       ; Get the serial buffer write pointer.
    sta     SERBUF,x    ; Store A into the serial buffer.
    plx
    inc     SERWR       ; Increment the write pointer.
    lda     SERWR       ; Is the buffer almost full?
    sec
    sbc     SERRD 
    cmp     #240
    blt     IRQVIA      ; If not, then leave interrupts on for now.
    lda     #ACIA_DTR   ; Disable serial receive interrupts.
    sta     ACIA_CMD
IRQVIA:
    lda     VIA_IFR     ; Has the T2 timer expired?
    and     #VIA_IFR_T2
    beq     IRQDONE
    inc     SYSTICK     ; Increment the millisecond tick counter.
    bne     RESET_T2
    inc     SYSTICK+1
RESET_T2:
    ldx     VIA_T2CH    ; Restart the one-shot T2 timer.
    lda     VIA_T2CL
    cpx     VIA_T2CH    ; Has the high byte changed?
    bne     RESET_T2    ; If yes, we need to read T2CL/T2CH again.
    clc
    adc     #<(T2COUNT - 24) ; Adjust the T2 deadline for the elapsed ticks.
    sta     VIA_T2CL
    txa
    adc     #>(T2COUNT - 24)
    sta     VIA_T2CH
IRQDONE:
    plx                 ; Restore the registers and return.
    pla
NMIADR:
    rti
;
; Operating system specific opcodes that are not supported on this platform.
;
EXIT:
TB_OP_LOAD:
TB_OP_SAVE:
    jmp     TB_OP_ERR   ; Report a syntax error and stop.
;
; System vectors.
;
    .org    $FFFA
    dw      NMIADR
    dw      RESET
    dw      IRQBRK
