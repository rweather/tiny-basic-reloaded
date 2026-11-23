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
; Core implementation of Tiny BASIC Reloaded.  It is assumed that the origin
; has been set before including this file, and that the following are defined:
;
; BASIC_MEM
;       Start of RAM for Tiny BASIC program and variable memory.
; BASIC_MEM_END
;       End of RAM for Tiny BASIC program and variable memory + 1.
;       Needs 256 bytes of this memory for system housekeeping.
;       Recommend at least 1K of RAM, ideally more, a lot more.
; KEYBUF
;       256-byte region in RAM that can be used as a keyboard buffer.
; CIN
;       Wait for a character from the input device and return it in A.
;       Must preserve X and Y.  While waiting, CIN should increment
;       TB_SEED to provide some randomness when the program starts.
; CIN_T
;       Wait for a character up to a specific timeout in milliseconds in X.
;       X = 0 means return immediately if no character is available.
;       On exit, A contains the character and carry is set if a character
;       is available.  Otherwise A is zero and carry is clear on timeout.
;       Must preserve Y.
; CBREAK
;       Check for the BREAK / CTRL-C key sequence in the input buffer.
;       Removes it and returns with zero set if BREAK is present.
;       Otherwise leave the next character in place for CIN or CIN_T.
;       This function can also handle CTRL-S to pause output if necessary.
;       May destroy A, X, and Y.
; COUT
;       Prints the character in A to the output device.  Must preserve A, X, Y.
; CRLF
;       Prints a CR-LF sequence to the output device.  Must preserve A, X, Y.
; CLS
;       Initialize text screen mode and clear the screen.
;
; The following may be optionally defined:
;
; TB_SHORT_ERRORS
;       Define this to use short two-letter error messages like "SN",
;       instead of long error messages like "SYNTAX ERROR".  Saves about
;       400 bytes of ROM space.
;
; Tiny BASIC Reloaded uses the zero page between $40 and $9F.
; The system monitor and other routines can use anything else.
;
;---------------------------------------------------------------------------
;
; Memory regions between BASIC_MEM and BASIC_MEM_END.
;
TB_AESTK            .equ    BASIC_MEM
TB_SUBSTK           .equ    BASIC_MEM+128
TB_PROGMEM          .equ    BASIC_MEM+256
;
; Error codes.
;
TB_E_NONE           .equ    0       ; No error
TB_E_NEXTFOR        .equ    1       ; NEXT without FOR
TB_E_SYNTAX         .equ    2       ; Syntax error
TB_E_RETURN         .equ    3       ; RETURN without GOSUB
TB_E_NODATA         .equ    4       ; Out of data on INPUT or READ
TB_E_ILLFUNC        .equ    5       ; Illegal function call
TB_E_OVERFLOW       .equ    6       ; Overflow error
TB_E_MEMORY         .equ    7       ; Out of memory
TB_E_INVLINE        .equ    8       ; Invalid line number
TB_E_SUBSCRIPT      .equ    9       ; Subscript out of range
TB_E_REDIM          .equ    10      ; Redimensioned array
TB_E_DIVZERO        .equ    11      ; Division by zero
TB_E_DIRECT         .equ    12      ; Illegal direct
TB_E_TYPE           .equ    13      ; Type mismatch
TB_E_STRSPC         .equ    14      ; Out of string space
TB_E_STRLONG        .equ    15      ; String too long
TB_E_EXPR           .equ    16      ; Formula too complex
TB_E_CANTCONT       .equ    17      ; Cannot continue
TB_E_NORESUME       .equ    18      ; No RESUME
TB_E_BADRESUME      .equ    19      ; RESUME without error
TB_E_UNPRINT        .equ    20      ; Unprintable error
TB_E_MISSING        .equ    21      ; Missing operand
TB_E_BADFILE        .equ    22      ; Bad file data
TB_E_DISKERR        .equ    23      ; Disk BASIC error
TB_E_GOSUB          .equ    24      ; Too many GOSUBs
TB_E_FOR            .equ    25      ; Too many FORs
TB_E_INVDIM         .equ    26      ; Invalid array dimension
TB_E_NOTARRAY       .equ    27      ; Not an array
TB_E_INVFILENAME    .equ    28      ; Invalid filename
TB_E_UNKNOWN        .equ    29      ; Unknown error
;
; Special key values.  The third-party I/O routines must decode escape
; sequences to produce the following values.  Not all of them may be
; supported by the third-party I/O routines.
;
TB_K_BREAK          .equ    $03     ; BREAK key (CTRL-C)
TB_K_BS             .equ    $08     ; Backspace key (CTRL-H)
TB_K_TAB            .equ    $09     ; TAB key
TB_K_ENTER          .equ    $0D     ; Enter key
TB_K_ESC            .equ    $1B     ; ESC key
TB_K_DEL            .equ    $7F     ; Backspace (DEL)
TB_K_LEFT           .equ    $80     ; Left arrow
TB_K_RIGHT          .equ    $81     ; Right arrow
TB_K_UP             .equ    $82     ; Up arrow
TB_K_DOWN           .equ    $83     ; Down arrow
TB_K_HOME           .equ    $84     ; Home key
TB_K_END            .equ    $85     ; End key
TB_K_PGUP           .equ    $86     ; Page up key
TB_K_PGDN           .equ    $87     ; Page down key
TB_K_INSERT         .equ    $88     ; Insert key
TB_K_DELETE         .equ    $89     ; Delete key
TB_K_F1             .equ    $91     ; F1 key
TB_K_F2             .equ    $92     ; F2 key
TB_K_F3             .equ    $93     ; F3 key
TB_K_F4             .equ    $94     ; F4 key
TB_K_F5             .equ    $95     ; F5 key
TB_K_F6             .equ    $96     ; F6 key
TB_K_F7             .equ    $97     ; F7 key
TB_K_F8             .equ    $98     ; F8 key
TB_K_F9             .equ    $99     ; F9 key
TB_K_F10            .equ    $9A     ; F10 key
TB_K_F11            .equ    $9B     ; F11 key
TB_K_F12            .equ    $9C     ; F12 key
;
; Maximum size of a program line.
;
TB_MAX_LINESZ       .equ    252
;
; Separator between statements.
;
TB_SEP              .equ    ":"
;
; Program and array memory.  TB_HIMEM - TB_LOMEM is the size of program memory.
;
TB_LOMEM            .equ    $40     ; Points to the start of program memory.
TB_HIMEM            .equ    $42     ; Points to the end of program memory.
TB_ASTART           .equ    $44     ; End of program, start of arrays.
TB_ANEXT            .equ    $46     ; Next free location for array allocation.
;
; Stack management.
;
TB_AESTK_TOP        .equ    $48     ; Offset to the top of AESTK.
TB_SUBSTK_TOP       .equ    $49     ; Offset to the top of SUBSTK.
TB_STACK_SAVE       .equ    $4A     ; Saved CPU stack posn for the top level.
;
; Current location in the program while executing it.
;
TB_LINEPOS          .equ    $4B     ; Position in the current line.
TB_LINEPTR          .equ    $4C     ; Points to the start of the current line.
TB_LINENUM          .equ    $4E     ; Line number or zero for direct mode.
;
; Temporary working variables.
;
TB_ACCUM            .equ    $50     ; 2-byte accumulator; cached top of AESTK.
TB_TEMP             .equ    $52     ; 2-byte temporary.
TB_TEMP2            .equ    $54     ; 2-byte temporary.
TB_TEMP3            .equ    $56     ; 4-byte temporary.
TB_BCD              .equ    $5A     ; 3-byte buffer for BCD conversions.
TB_COLON_MODE       .equ    $5D     ; Non-zero if the statement ends in a colon.
TB_PROGPTR          .equ    $5E     ; Program line pointer for listings.
TB_DIMENSION1       .equ    $60     ; Array outer dimension.
TB_DIMENSION2       .equ    $62     ; Array inner dimension.
TB_INPOS            .equ    $64     ; Buffer position for INPUT commands.
;
; Random number generation.
;
TB_SEED             .equ    $65     ; 4-byte random number seed.
;
; Cold / warm start marker.
;
TB_WARM_MARKER      .equ    $69     ; 3 bytes.
;
; Storage for the 26 plain integer variables A-Z.  Array variables are
; stored starting at ASTART.
;
TB_VARS             .equ    $6C     ; Extends from $6C to $9F.
;
; Cold start entry point.
;
TB_START_COLD:
    jsr     TB_OP_INIT          ; Initialize program and variable memory.
    ; Fall through.
;
; Warm start entry point.
;
TB_START_WARM:
;
; Do a check on the warm start marker just in case the caller entered at
; the wrong point and we need to do a cold start.
;
    lda     TB_WARM_MARKER
    clc
    adc     TB_WARM_MARKER+1
    eor     #$AA
    cmp     TB_WARM_MARKER+2
    bne     TB_START_COLD
;
; Save the current location of the stack pointer for unwinding the
; stack when an error occurs.
;
    tsx
    stx     TB_STACK_SAVE
;
; Print the welcome banner.
;
    jsr     TB_WELCOME
;
; Set up for direct mode.
;
    jsr     TB_DIRECT
;
; Jump to the converted bytecode program at the C0 entry point.
;
    jmp     TB_IL_C0
;
; Print the welcome banner.
;
TB_WELCOME:
    jsr     CLS
    ldx     #TB_MSG_WELCOME-TB_MSGS
    jsr     TB_MSG_PRINT
    jsr     CRLF
;
    lda     #<BASIC_MEM_END     ; Print the number of bytes that are free.
    sec
    sbc     TB_ANEXT
    sta     TB_ACCUM
    lda     #>BASIC_MEM_END
    sbc     TB_ANEXT+1
    sta     TB_ACCUM+1
    jsr     TB_PRU
;
    ldx     #TB_MSG_BYTES_FREE-TB_MSGS
    jsr     TB_MSG_PRINT
    jsr     CRLF
    jmp     CRLF
;
; "INIT" opcode handler.
;
; Clears program memory and all variables.
;
TB_OP_INIT:
    lda     #<TB_PROGMEM        ; Initialize TB_LOMEM and TB_HIMEM.
    sta     TB_LOMEM
    lda     #>TB_PROGMEM
    sta     TB_LOMEM+1
    lda     #<BASIC_MEM_END
    sta     TB_HIMEM
    lda     #>BASIC_MEM_END
    sta     TB_HIMEM+1
;
    lda     #0
    tay
    sta     (TB_LOMEM),y        ; An empty program contains four zero bytes.
    iny
    sta     (TB_LOMEM),y
    iny
    sta     (TB_LOMEM),y
    iny
    sta     (TB_LOMEM),y
;
    lda     TB_LOMEM            ; Set ASTART = LOMEM + 4
    clc
    adc     #4
    sta     TB_ASTART
    lda     TB_LOMEM+1
    adc     #0
    sta     TB_ASTART+1
;
    lda     TB_ASTART           ; Set ANEXT = ASTART + 26 * 6
    clc
    adc     #156
    sta     TB_ANEXT
    lda     TB_ASTART+1
    adc     #0
    sta     TB_ANEXT+1
;
    jsr     TB_DIRECT           ; Set up for direct mode.
;
    jsr     TB_OP_CLEAR         ; Clear all variables.
;
    lda     #$BA                ; Set up the warm start marker.
    sta     TB_WARM_MARKER
    lda     #$DB
    sta     TB_WARM_MARKER+1
    lda     #$3F                ; ($BA + $DB) XOR $AA
    sta     TB_WARM_MARKER+2
    rts
;
; Set up for direct mode.
;
TB_DIRECT:
    lda     #0                  ; Empty AESTK and SUBSTK.
    sta     TB_AESTK_TOP
    sta     TB_SUBSTK_TOP
    sta     TB_COLON_MODE       ; No longer in colon mode.
    sta     TB_LINEPOS          ; Position on the line is zero.
    sta     TB_LINENUM          ; Line number is zero for direct mode.
    sta     TB_LINENUM+1
    sta     TB_ACCUM            ; Zero the cached top of AESTK.
    sta     TB_ACCUM+1
    lda     #<KEYBUF            ; Line pointer is the keyboard buffer.
    sta     TB_LINEPTR
    lda     #>KEYBUF
    sta     TB_LINEPTR+1
    rts
;
; Re-initalize AESTK and CTLSTK when returning back to the execution loop.
;
TB_OP_XINIT:
    pla                         ; Save the return address.
    tay
    pla
;
    ldx     #0                  ; Clear AESTK.
    stx     TB_AESTK_TOP
;
    stx     TB_COLON_MODE       ; Clear colon mode.
;
    stx     TB_ACCUM            ; Clear the top-of-AESTK accumulator.
    stx     TB_ACCUM+1
;
    ldx     TB_STACK_SAVE       ; Unwind the CPU stack as we might be
    txs                         ; several levels deep.
    pha                         ; Restore the return address to the stack.
    tya
    pha
;
    jsr     CBREAK              ; Has a BREAK / CTRL-C occurred?
    beq     TB_OP_XINIT_BREAK
    rts
TB_OP_XINIT_BREAK:
    jmp     TB_BREAK
;
; "CHKSTK" opcode handler.
;
; Check for stack overflow during expression evaluation.
;
TB_OP_CHKSTK:
    tsx
    cpx     #32                 ; Need at least 32 bytes of CPU stack.
    bcc     TB_TOO_COMPLEX
    rts
TB_TOO_COMPLEX:
    ldx     #TB_E_EXPR
    jmp     TB_ERROR
;
;---------------------------------------------------------------------------
;
; System message printing.
;
;---------------------------------------------------------------------------
;
; Print the message at TB_MSGS+X, which is assumed to be terminated
; with a character with the high bit set.  Destroys A and X.
;
TB_MSG_PRINT:
    lda     TB_MSGS,x
    bmi     TB_MSG_PRINT1
    jsr     COUT
    inx
    bne     TB_MSG_PRINT
TB_MSG_PRINT1:
    and     #$7F
    jmp     COUT
;
; Table of system messages.
;
TB_MSGS:
TB_MSG_WELCOME:
    .db     "TINY BASIC RELOADED V1.", $B0
TB_MSG_BYTES:
    .db     " BYTE", $D3
TB_MSG_BYTES_FREE:
    .db     " BYTES FRE", $C5
TB_MSG_ERROR:
  .ifdef TB_SHORT_ERRORS
    .db     " ERRO", $D2
  .endif
TB_MSG_BREAK:
    .db     "BREA", $CB
TB_MSG_IN_LINE:
    .db     " IN LINE", $A0
TB_MSG_PROG_SIZE:
    .db     "PROG:", $A0
TB_MSG_VARS_SIZE:
    .db     "VARS:", $A0
TB_MSG_FREE_SIZE:
    .db     "FREE:", $A0
;
;---------------------------------------------------------------------------
;
; Error handling.
;
;---------------------------------------------------------------------------
;
; Report an error and jump back to the direct command loop.
;
TB_OP_ERR:
    ldx     #TB_E_SYNTAX        ; "ERR" opcode always reports a syntax error.
TB_ERROR:
    jsr     CRLF
    cpx     #TB_E_UNKNOWN       ; Range-check the error code.
    bcc     TB_ERROR1
    ldx     #TB_E_UNKNOWN
TB_ERROR1:
  .ifdef TB_SHORT_ERRORS
    lda     TB_ERRTBL_1,x       ; Print the two-character error message.
    jsr     COUT
    lda     TB_ERRTBL_2,x
    jsr     COUT
    ldx     #TB_MSG_ERROR-TB_MSGS ; Print " ERROR"
    jsr     TB_MSG_PRINT
  .else
    lda     TB_ERRTBL_L,x       ; Find the long error message.
    sta     TB_TEMP2
    lda     TB_ERRTBL_H,x
    sta     TB_TEMP2+1
    ldy     #0
TB_ERROR2:
    lda     (TB_TEMP2),y        ; Print the long error message.
    bmi     TB_ERROR3
    jsr     COUT
    iny
    bne     TB_ERROR2
TB_ERROR3:
    and     #$7F
    jsr     COUT
  .endif
;
TB_ERROR_LINE:
    lda     TB_LINENUM          ; Are we in direct mode?
    ora     TB_LINENUM+1
    beq     TB_ERROR_DONE
;
    ldx     #TB_MSG_IN_LINE-TB_MSGS ; Print the string " IN LINE ".
    jsr     TB_MSG_PRINT
;
    lda     TB_LINENUM          ; Print the current line number.
    sta     TB_ACCUM
    lda     TB_LINENUM+1
    sta     TB_ACCUM+1
    jsr     TB_PRU
;
TB_ERROR_DONE:
    jsr     CRLF                ; Terminate the error message with CR-LF.
    jsr     TB_DIRECT           ; Set up for direct mode.
    jmp     TB_IL_ERRENT        ; Jump to the direct command loop.
;
; Handle the BREAK / CTRL-C key.
;
TB_BREAK:
    jsr     CRLF
    ldx     #TB_MSG_BREAK-TB_MSGS
    jsr     TB_MSG_PRINT
    jmp     TB_ERROR_LINE
;
; Short error message table, split into first and second characters.
;
  .ifdef TB_SHORT_ERRORS
TB_ERRTBL_1:
    .db     "NNSROFOOUBD/ITOLSCNRUMFLTTINI?"
TB_ERRTBL_2:
    .db     "EFNGDCVMLSD0DMSSTNRWEOD3GFAAF?"
  .else
;
; Long error message table.  Each message ends with a character
; with the high bit set.  This saves 30 NUL bytes from the image.
;
TB_ERR_0:   .db "NO ERRO", $D2
TB_ERR_1:   .db "NEXT WITHOUT FO", $D2
TB_ERR_2:   .db "SYNTAX ERRO", $D2
TB_ERR_3:   .db "RETURN WITHOUT GOSU", $C2
TB_ERR_4:   .db "OUT OF DAT", $C1
TB_ERR_5:   .db "ILLEGAL FUNCTION CAL", $CC
TB_ERR_6:   .db "OVERFLOW ERRO", $D2
TB_ERR_7:   .db "OUT OF MEMOR", $D9
TB_ERR_8:   .db "INVALID LINE NUMBE", $D2
TB_ERR_9:   .db "SUBSCRIPT OUT OF RANG", $C5
TB_ERR_10:  .db "REDIMENSIONED ARRA", $D9
TB_ERR_11:  .db "DIVISION BY ZER", $CF
TB_ERR_12:  .db "ILLEGAL DIREC", $D4
TB_ERR_13:  .db "TYPE MISMATC", $C8
TB_ERR_14:  .db "OUT OF STRING SPAC", $C5
TB_ERR_15:  .db "STRING TOO LON", $C7
TB_ERR_16:  .db "FORMULA TOO COMPLE", $D8
TB_ERR_17:  .db "CANNOT CONTINU", $C5
TB_ERR_18:  .db "NO RESUM", $C5
TB_ERR_19:  .db "RESUME WITHOUT ERRO", $D2
TB_ERR_20:  .db "UNPRINTABLE ERRO", $D2
TB_ERR_21:  .db "MISSING OPERAN", $C4
TB_ERR_22:  .db "BAD FILE DAT", $C1
TB_ERR_23:  .db "DISK BASIC ERRO", $D2
TB_ERR_24:  .db "TOO MANY GOSUB", $D3
TB_ERR_25:  .db "TOO MANY FOR", $D3
TB_ERR_26:  .db "INVALID ARRAY DIMENSIO", $4E
TB_ERR_27:  .db "NOT AN ARRA", $D9
TB_ERR_28:  .db "INVALID FILENAM", $C5
TB_ERR_29:  .db "UNKNOWN ERRO", $D2
;
; Long error message table index, split into low and high bytes.
;
TB_ERRTBL_L:
    .db     <TB_ERR_0
    .db     <TB_ERR_1
    .db     <TB_ERR_2
    .db     <TB_ERR_3
    .db     <TB_ERR_4
    .db     <TB_ERR_5
    .db     <TB_ERR_6
    .db     <TB_ERR_7
    .db     <TB_ERR_8
    .db     <TB_ERR_9
    .db     <TB_ERR_10
    .db     <TB_ERR_11
    .db     <TB_ERR_12
    .db     <TB_ERR_13
    .db     <TB_ERR_14
    .db     <TB_ERR_15
    .db     <TB_ERR_16
    .db     <TB_ERR_17
    .db     <TB_ERR_18
    .db     <TB_ERR_19
    .db     <TB_ERR_20
    .db     <TB_ERR_21
    .db     <TB_ERR_22
    .db     <TB_ERR_23
    .db     <TB_ERR_24
    .db     <TB_ERR_25
    .db     <TB_ERR_26
    .db     <TB_ERR_27
    .db     <TB_ERR_28
    .db     <TB_ERR_29
TB_ERRTBL_H:
    .db     >TB_ERR_0
    .db     >TB_ERR_1
    .db     >TB_ERR_2
    .db     >TB_ERR_3
    .db     >TB_ERR_4
    .db     >TB_ERR_5
    .db     >TB_ERR_6
    .db     >TB_ERR_7
    .db     >TB_ERR_8
    .db     >TB_ERR_9
    .db     >TB_ERR_10
    .db     >TB_ERR_11
    .db     >TB_ERR_12
    .db     >TB_ERR_13
    .db     >TB_ERR_14
    .db     >TB_ERR_15
    .db     >TB_ERR_16
    .db     >TB_ERR_17
    .db     >TB_ERR_18
    .db     >TB_ERR_19
    .db     >TB_ERR_20
    .db     >TB_ERR_21
    .db     >TB_ERR_22
    .db     >TB_ERR_23
    .db     >TB_ERR_24
    .db     >TB_ERR_25
    .db     >TB_ERR_26
    .db     >TB_ERR_27
    .db     >TB_ERR_28
    .db     >TB_ERR_29
  .endif
;
;---------------------------------------------------------------------------
;
; TST? opcode handlers.  Each TB_OP_TST?  handler returns with zero
; set to continue execution or zero clear to jump on a mismatch.
;
;---------------------------------------------------------------------------
;
; Skip whitespace in the current line.  On exit, A contains the
; character just after skipping the whitespace and Y contains the
; offset into the current line of the character in A.
;
TB_SKIPWS:
    ldy     TB_LINEPOS
TB_SKIPWS_LOOP:                 ; Y has already been preloaded.
    lda     (TB_LINEPTR),y
    cmp     #$20
    bne     TB_SKIPWS_DONE
    iny
    bne     TB_SKIPWS_LOOP
TB_SKIPWS_DONE:
    sty     TB_LINEPOS          ; Save Y so the next TB_SKIPWS call is quicker.
    rts
;
; Skip more whitespace starting at Y but don't update TB_LINEPOS.
;
TB_SKIPWS_MORE_LOOP:
    iny
TB_SKIPWS_MORE:
    lda     (TB_LINEPTR),y
    cmp     #$20
    beq     TB_SKIPWS_MORE_LOOP
    rts
;
; "TST" opcode handler for a string.  On entry, X is the offset into
; TB_TOKTAB of the NUL-terminated or high bit terminated token to match.
; The first character of the token must not have the high bit set, so
; single-character tokens must have NUL-termination.
;
; This is also the opcode handler for "TSTJ".  The caller inverts the
; check on the zero flag to jump to the label on a match instead of
; "TST"'s behaviour which jumps to the label on a mismatch.
;
TB_OP_TST:
    jsr     TB_SKIPWS           ; Load Y from TB_LINEPOS and skip whitespace.
    cmp     TB_TOKTAB,x         ; Does the first character match?
    bne     TB_OP_TST_FAIL      ; No, then we're done.
TB_OP_TST_LOOP:
    inx                         ; Move onto the next character.
    iny
    lda     TB_TOKTAB,x         ; Are we at the end of the token?
    beq     TB_OP_TST_SUCCESS
    bmi     TB_OP_TST_LAST
    cmp     (TB_LINEPTR),y      ; Do we still have a match?
    beq     TB_OP_TST_LOOP      ; If yes, go around again.
TB_OP_TST_FAIL:
    rts
TB_OP_TST_LAST:
    and     #$7F                ; Handle last character with the high bit set.
    cmp     (TB_LINEPTR),y
    bne     TB_OP_TST_FAIL
TB_OP_TST1_SUCCESS:
    iny
TB_OP_TST_SUCCESS:
    sty     TB_LINEPOS          ; Skip past the token on success.
    lda     #0                  ; Force the zero flag on.
    rts
;
; Special case of "TST" for a single-character token.  Token is in A on entry.
;
TB_OP_TST1:
    sta     TB_TEMP2            ; Save A, skip whitespace, then check.
    jsr     TB_SKIPWS
    cmp     TB_TEMP2
    beq     TB_OP_TST1_SUCCESS
    rts
;
; "TSTOP" opcode handler for an operator.  On entry, X is the offset
; into TB_TOKTAB of the NUL-terminated token to match, and Y is the
; offset into TB_OPHAND of the operator handler to push onto AESTK.
;
TB_OP_TSTOP:
    sty     TB_TEMP2            ; Save Y for later.
    jsr     TB_OP_TST           ; Recognise the operator.
    bne     TB_OP_TSTOP_FAIL
    jsr     TB_PUSH_DOWN_AESTK  ; Push the operator handler onto AESTK.
    ldy     TB_TEMP2
    lda     TB_TOKHAND,y
    sta     TB_ACCUM
    lda     TB_TOKHAND+1,y
    sta     TB_ACCUM+1
    lda     #0                  ; Zero flag set to indicate a match.
TB_OP_TSTOP_FAIL:
    rts
;
; "TSTV" opcode handler.
;
; Test for a variable name and push its address onto AESTK.
;
TB_OP_TSTV:
    jsr     TB_SKIPWS           ; Load Y from TB_LINEPOS and skip whitespace.
    cmp     #$41                ; Is this a letter A-Z?
    bcc     TB_OP_TSTV_FAIL
    cmp     #$5B
    bcs     TB_OP_TSTV_FAIL
    pha                         ; Save the letter for later.
    iny                         ; Skip past the letter.
    lda     (TB_LINEPTR),y      ; Must not be followed by a letter or digit.
    cmp     #$30
    bcc     TB_OP_TSTV_SUCCESS
    cmp     #$3A
    bcc     TB_OP_TSTV_FAIL_POP
    cmp     #$41
    bcc     TB_OP_TSTV_SUCCESS
    cmp     #$5B
    bcc     TB_OP_TSTV_FAIL_POP
TB_OP_TSTV_SUCCESS:
    jsr     TB_PUSH_DOWN_AESTK  ; Make room on AESTK.
    pla
    and     #$1F                ; Convert the letter into a variable pointer.
    asl     a
    adc     #TB_VARS-2
    sta     TB_ACCUM            ; The variable pointer ends up in TB_ACCUM.
    lda     #0
    sta     TB_ACCUM+1
    sty     TB_LINEPOS          ; Save the final line position.
    lda     #0                  ; Zero flag set to keep executing code.
    rts
TB_OP_TSTV_FAIL_POP:
    pla
TB_OP_TSTV_FAIL:
    lda     #$FF                ; Zero flag clear to jump on TSTV failure.
    rts
;
; "TSTA" opcode handler.
;
; Test for an array name and push its address onto AESTK.
;
TB_OP_TSTA:
    jsr     TB_SKIPWS           ; Load Y from LINEPOS and skip whitespace.
    cmp     #$41                ; Is this a letter A-Z?
    bcc     TB_OP_TSTV_FAIL
    cmp     #$5B
    bcs     TB_OP_TSTV_FAIL
    pha                         ; Save the letter for later.
    iny                         ; Skip past the letter.
    jsr     TB_SKIPWS_MORE      ; Skip more whitespace.
    cmp     #"("                ; Is the next character '('?
    bne     TB_OP_TSTV_FAIL_POP ; Otherwise this is not an array.
    sty     TB_LINEPOS
    jsr     TB_PUSH_DOWN_AESTK  ; Make room on AESTK.
    pla
    and     #$1F                ; Compute the address of the array header.
    sec                         ; ASTART + (((ch & 0x1F) - 1)  * 6)
    sbc     #1
    sta     TB_ACCUM            ; The array header pointer ends up in TB_ACCUM.
    asl     a
    adc     TB_ACCUM
    asl     a
    adc     TB_ASTART
    sta     TB_ACCUM
    lda     TB_ASTART+1
    adc     #0
    sta     TB_ACCUM+1
    lda     #0                  ; Set the zero flag on success.
    rts
;
; "TSTCR" opcode handler.  Skip whitespace and check for end of line.
;
TB_OP_TSTCR:
    jsr     TB_SKIPWS
    cmp     #0
    rts
;
; "TSTEND" opcode handler.  Skip whitespace and check for end of statement.
;
TB_OP_TSTEND:
    jsr     TB_SKIPWS
    cmp     #0                  ; Does the statement end with end of line?
    beq     TB_OP_TSTEND_SUCCESS
    cmp     #TB_SEP             ; Does the statement end with a colon?
TB_OP_TSTEND_SUCCESS:
    rts
;
; "TSTN" opcode handler.
;
; Skip whitespace and check for a decimal number.
;
TB_OP_TSTN:
    jsr     TB_SKIPWS           ; Skip whitespace.
    cmp     #$30                ; Do we have a decimal digit?
    bcc     TB_OP_TSTN_FAIL
    cmp     #$3A
    bcs     TB_OP_TSTN_FAIL
    pha
    jsr     TB_PUSH_DOWN_AESTK  ; Make room on AESTK.
    pla
    and     #$0F
    sta     TB_ACCUM            ; Initialize TB_ACCUM with the first digit.
    lda     #0
    sta     TB_ACCUM+1
    iny
TB_OP_TSTN_NEXT:
    lda     (TB_LINEPTR),y      ; Do we have another digit?
    cmp     #$30
    bcc     TB_OP_TSTN_DONE
    cmp     #$3A
    bcs     TB_OP_TSTN_DONE
    jsr     TB_MUL10
    iny                         ; Go around for the next digit.
    jmp     TB_OP_TSTN_NEXT
TB_OP_TSTN_DONE:
    sty     TB_LINEPOS          ; Save the final Y after parsing the number.
    lda     #0                  ; Zero flag set to keep executing code.
    rts
TB_OP_TSTN_FAIL:
    lda     #$FF                ; Zero flag clear to jump on TSTN failure.
    rts
TB_OP_TSTN_OV:
    ldx     #TB_E_OVERFLOW      ; Number overflowed past 65535.
    jmp     TB_ERROR
;
; Multiply the value in TB_ACCUM by 10 and add the digit in A.
;
TB_MUL10:
    and     #$0F
    pha                         ; Save the digit for later.
    asl     TB_ACCUM            ; Multiply TB_ACCUM by 10.
    rol     TB_ACCUM+1
    bcs     TB_OP_TSTN_OV
    lda     TB_ACCUM
    asl     a
    sta     TB_TEMP2
    lda     TB_ACCUM+1
    rol     a
    bcs     TB_OP_TSTN_OV
    sta     TB_TEMP2+1
    asl     TB_TEMP2
    rol     TB_TEMP2+1
    bcs     TB_OP_TSTN_OV
    lda     TB_ACCUM
    clc
    adc     TB_TEMP2
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    adc     TB_TEMP2+1
    bcs     TB_OP_TSTN_OV
    sta     TB_ACCUM+1
    pla                         ; Add the new digit to TB_ACCUM.
    clc
    adc     TB_ACCUM
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    adc     #0
    bcs     TB_OP_TSTN_OV
    sta     TB_ACCUM+1
    rts
;
; "TSTL" opcode handler.  Skip whitespace and check for a line number.
;
TB_OP_TSTL:
    jsr     TB_OP_TSTN          ; Parse a regular number first.
    bne     TB_OP_TSTL_DONE
    lda     TB_ACCUM+1          ; Range-check the value: 1 to 31999,
    bne     TB_OP_TSTL_HIGH     ; or alternatively $0001 to $7CFF.
    lda     TB_ACCUM
    beq     TB_OP_TSTL_FAIL
TB_OP_TSTL_SUCCESS:
    lda     #0                  ; Zero flag set to indicate a match.
TB_OP_TSTL_DONE:
    rts
TB_OP_TSTL_HIGH:
    cmp     #$7D
    bcc     TB_OP_TSTL_SUCCESS
TB_OP_TSTL_FAIL:
    ldx     #TB_E_INVLINE
    jmp     TB_ERROR
;
; "TSTB" opcode handler.  Skip whitespace and check for a FPMUL bit count.
;
TB_OP_TSTB:
    jsr     TB_OP_TSTN          ; Parse a regular number first.
    bne     TB_OP_TSTB_DONE
    lda     TB_ACCUM+1          ; Range-check the value: 0 to 14.
    bne     TB_OP_TSTB_FAIL
    lda     TB_ACCUM
    cmp     #15
    bcs     TB_OP_TSTB_FAIL
TB_OP_TSTB_SUCCESS:
    lda     #0                  ; Zero flag set to indicate a match.
TB_OP_TSTB_DONE:
    rts
TB_OP_TSTB_FAIL:
    ldx     #TB_E_ILLFUNC
    jmp     TB_ERROR
;
; Versions of "TST", "TST1", etc that report a syntax error on no match.
; This is used for the case of self-referential labels.
;
TB_OP_TST_SYNTAX:
    jsr     TB_OP_TST
    bne     TB_OP_TST_ERR
    rts
TB_OP_TST_ERR:
    jmp     TB_OP_ERR
TB_OP_TST1_SYNTAX:
    jsr     TB_OP_TST1
    bne     TB_OP_TST_ERR
    rts
TB_OP_TSTV_SYNTAX:
    jsr     TB_OP_TSTV
    bne     TB_OP_TST_ERR
    rts
TB_OP_TSTA_SYNTAX:
    jsr     TB_OP_TSTA
    bne     TB_OP_TST_ERR
    rts
TB_OP_TSTN_SYNTAX:
    jsr     TB_OP_TSTN
    bne     TB_OP_TST_ERR
    rts
TB_OP_TSTL_SYNTAX:
    jsr     TB_OP_TSTL
    bne     TB_OP_TST_ERR
    rts
TB_OP_TSTB_SYNTAX:
    jsr     TB_OP_TSTB
    bne     TB_OP_TST_ERR
    rts
;
;---------------------------------------------------------------------------
;
; Arithemtic expression stack (AESTK) handling.
;
;---------------------------------------------------------------------------
;
; Push TB_ACCUM onto AESTK to free up TB_ACCUM for something new.
;
TB_PUSH_DOWN_AESTK:
    ldx     TB_AESTK_TOP
    bmi     TB_AESTK_FULL
    lda     TB_ACCUM
    sta     TB_AESTK,x
    inx
    lda     TB_ACCUM+1
    sta     TB_AESTK,x
    inx
    stx     TB_AESTK_TOP
    rts
TB_AESTK_FULL:
    jmp     TB_TOO_COMPLEX
;
; Push the literal 16-bit value in Y:A onto AESTK.  A is the low byte.
; This sets TB_ACCUM to the value after pushing down AESTK to make room.
;
TB_PUSH_LITERAL:
    ldx     TB_AESTK_TOP
    bmi     TB_AESTK_FULL
    pha
    lda     TB_ACCUM
    sta     TB_AESTK,x
    inx
    lda     TB_ACCUM+1
    sta     TB_AESTK,x
    inx
    stx     TB_AESTK_TOP
    pla
    sta     TB_ACCUM
    sty     TB_ACCUM+1
    rts
;
; Pop the top of AESTK into TB_TEMP.
;
TB_POP_AESTK:
    ldx     TB_AESTK_TOP
    beq     TB_POP_FAIL         ; Report an error on stack underflow.
    dex
    lda     TB_AESTK,x
    sta     TB_TEMP+1
    dex
    lda     TB_AESTK,x
    sta     TB_TEMP
    stx     TB_AESTK_TOP
    rts
TB_POP_FAIL:
    ldx     #TB_E_ILLFUNC
    jmp     TB_ERROR
;
; Pop the top of AESTK into TB_TEMP2.
;
TB_POP2_AESTK:
    ldx     TB_AESTK_TOP
    beq     TB_POP_FAIL         ; Report an error on stack underflow.
    dex
    lda     TB_AESTK,x
    sta     TB_TEMP2+1
    dex
    lda     TB_AESTK,x
    sta     TB_TEMP2
    stx     TB_AESTK_TOP
    rts
;
; Pop the top of AESTK into TB_BCD.
;
TB_POPB_AESTK:
    ldx     TB_AESTK_TOP
    beq     TB_POP_FAIL         ; Report an error on stack underflow.
    dex
    lda     TB_AESTK,x
    sta     TB_BCD+1
    dex
    lda     TB_AESTK,x
    sta     TB_BCD
    stx     TB_AESTK_TOP
    rts
;
; Pop the top of AESTK into TB_ACCUM.
;
TB_POP_UP_AESTK:
    ldx     TB_AESTK_TOP
    beq     TB_POP_FAIL         ; Report an error on stack underflow.
    dex
    lda     TB_AESTK,x
    sta     TB_ACCUM+1
    dex
    lda     TB_AESTK,x
    sta     TB_ACCUM
    stx     TB_AESTK_TOP
    rts
;
;---------------------------------------------------------------------------
;
; Printing.
;
;---------------------------------------------------------------------------
;
; "PRN" opcode handler.
;
; Print the integer in TB_ACCUM.
;
TB_OP_PRN:
    lda     TB_ACCUM+1          ; Is the value positive or negative?
    bpl     TB_PRU
    lda     #"-"                ; Print the minus sign.
    jsr     COUT
    jsr     TB_OP_NEG           ; Negate TB_ACCUM.
    ; Fall through to TB_PRU.
;
; Print the 16-bit unsigned integer in TB_ACCUM.
;
TB_PRU:
;
; Convert the value into BCD.
;
    lda     #0
    sta     TB_BCD
    sta     TB_BCD+1
    sta     TB_BCD+2
    ldx     #16
    sed
TB_PRU_BCD:
    asl     TB_ACCUM            ; Get the high bit of TB_ACCUM into carry bit.
    rol     TB_ACCUM+1
    lda     TB_BCD              ; Add the carry bit to TB_BCD in BCD mode.
    adc     TB_BCD              ; TB_BCD = TB_BCD * 2 + C.
    sta     TB_BCD
    lda     TB_BCD+1
    adc     TB_BCD+1
    sta     TB_BCD+1
    lda     TB_BCD+2
    adc     TB_BCD+2
    sta     TB_BCD+2
    dex
    bne     TB_PRU_BCD
    cld
;
; Figure out how many digits we have and print them.
;
    lda     TB_BCD+2
    bne     TB_PRU_5_DIGITS
    lda     TB_BCD+1
    bne     TB_PRU_3OR4_DIGITS
    lda     TB_BCD
    cmp     #$10
    bcc     TB_PRU_1_DIGIT
    bcs     TB_PRU_2_DIGITS
TB_PRU_3OR4_DIGITS:
    cmp     #$10
    bcc     TB_PRU_3_DIGITS
    bcs     TB_PRU_4_DIGITS
TB_PRU_5_DIGITS:
    ora     #$30
    jsr     COUT
TB_PRU_4_DIGITS:
    lda     TB_BCD+1
    lsr     a
    lsr     a
    lsr     a
    lsr     a
    ora     #$30
    jsr     COUT
TB_PRU_3_DIGITS:
    lda     TB_BCD+1
    and     #$0F
    ora     #$30
    jsr     COUT
TB_PRU_2_DIGITS:
    lda     TB_BCD
    lsr     a
    lsr     a
    lsr     a
    lsr     a
    ora     #$30
    jsr     COUT
TB_PRU_1_DIGIT:
    lda     TB_BCD
    and     #$0F
    ora     #$30
    jmp     COUT
;
; "PRHEX" opcode handler.
;
; Print the integer in TB_ACCUM in hexadecimal.
;
TB_OP_PRHEX:
    lda     TB_ACCUM+1
    jsr     TB_OP_PRHEX_BYTE
    lda     TB_ACCUM
TB_OP_PRHEX_BYTE:
    pha
    lsr     a
    lsr     a
    lsr     a
    lsr     a
    jsr     TB_OP_PRHEX_BYTE2
    pla
TB_OP_PRHEX_BYTE2:
    and     #$0F
    ora     #$30
    cmp     #$3A
    bcc     TB_OP_PRHEX_BYTE3
    adc     #6
TB_OP_PRHEX_BYTE3:
    jmp     COUT
;
; "PRS" opcode handler.
;
; Print a string from the program text, terminated by a double-quote.
; On entry, we have already skipped past the leading double-quote.
;
TB_OP_PRS:
    ldy     TB_LINEPOS          ; Get the current position in the line.
TB_OP_PRS1:
    lda     (TB_LINEPTR),y      ; Get the next character.
    beq     TB_OP_PRS_ERROR     ; If we hit the NUL, we have a syntax error.
    iny
    cmp     #$22                ; Do we have the terminating double-quote?
    beq     TB_OP_PRS_DONE      ; Yes, we're done.
    jsr     COUT                ; Print the character.
    jmp     TB_OP_PRS1          ; Back around for more.
TB_OP_PRS_DONE:
    sty     TB_LINEPOS          ; Save the final position in the line.
    rts
TB_OP_PRS_ERROR:
    jmp     TB_OP_ERR
;
; "PRC" opcode handler.
;
; Print the character in TB_ACCUM.
;
TB_OP_PRC:
    lda     TB_ACCUM
    jmp     COUT
;
; "NLINE" opcode handler.
;
; Print a newline.
;
TB_OP_NLINE .equ CRLF
;
; "SPC" opcode handler that TAB's over to the next display field.
; This is used to implement the "," separator in PRINT statements.
;
TB_OP_SPC:
    lda     #TB_K_TAB
    jmp     COUT
;
; "TAB" opcode handler that prints a specified number of spaces.
; This is used to implement the "SPC" function in PRINT statements.
;
TB_OP_TAB:
    lda     TB_ACCUM+1          ; Fail if the number is negative or > 255.
    bne     TB_OP_TAB_FAIL
    ldx     TB_ACCUM
    beq     TB_OP_TAB_DONE
    lda     #$20
TB_OP_TAB_LOOP:
    jsr     COUT
    dex
    bne     TB_OP_TAB_LOOP
TB_OP_TAB_DONE:
    rts
TB_OP_TAB_FAIL:
    ldx     #TB_E_ILLFUNC
    jmp     TB_ERROR

;
;---------------------------------------------------------------------------
;
; Arithmetic, bitwise, and logical expression operators.
;
; Some of these are used directly and some are activated via "APPLY".
; Opcode handlers whose name ends in "APPLY" are for the latter.
;
;---------------------------------------------------------------------------
;
; "APPLYFN" opcode handler.
;
; Apply a unary function.  The argument is in TB_ACCUM and the
; operator function pointer is on the top of AESTK.
;
TB_OP_APPLYFN:
    jsr     TB_POP_AESTK        ; Pop the function to apply into TB_TEMP.
    jmp     (TB_TEMP)           ; Jump to the APPLYFN handler for the operator.
;
; "APPLY" opcode handler.
;
; Apply a binary operator.  The second argument is in TB_ACCUM,
; with the operator function pointer on the top of AESTK, and the
; first argument below that on the AESTK.
;
; When the operator function pointer is called, the two arguments are in
; TB_TEMP2 and TB_ACCUM.  The result should be in TB_ACCUM.
;
TB_OP_APPLY:
    jsr     TB_POP_AESTK        ; Pop the function to apply into TB_TEMP.
    dex
    lda     TB_AESTK,x          ; Pop the first argument into TB_TEMP2.
    sta     TB_TEMP2+1
    dex
    lda     TB_AESTK,x
    sta     TB_TEMP2
    stx     TB_AESTK_TOP
    jmp     (TB_TEMP)           ; Jump to the APPLY handler for the operator.
;
; "ADD" opcode handler.
;
TB_OP_ADD_APPLY:
    lda     TB_TEMP2
    clc
    adc     TB_ACCUM
    sta     TB_ACCUM
    lda     TB_TEMP2+1
    adc     TB_ACCUM+1
    sta     TB_ACCUM+1
    rts
;
; "SUB" opcode handler.
;
TB_OP_SUB_APPLY:
    lda     TB_TEMP2
    sec
    sbc     TB_ACCUM
    sta     TB_ACCUM
    lda     TB_TEMP2+1
    sbc     TB_ACCUM+1
    sta     TB_ACCUM+1
    rts
;
; "MPY" opcode handler.
;
; Multiply two 16-bit integers to get a truncated 16-bit result.
; The arguments are in TB_TEMP2 and TB_ACCUM.  Result in TB_ACCUM.
;
TB_OP_MPY_APPLY:
TB_MUL16:
    lda     #0                  ; Zero the result.
    sta     TB_TEMP3
    sta     TB_TEMP3+1
    ldy     #16
TB_MUL16_LOOP:
    asl     TB_TEMP3            ; Rotate the result left.
    rol     TB_TEMP3+1
    asl     TB_ACCUM            ; Get the high bit of TB_ACCUM.
    rol     TB_ACCUM+1
    bcc     TB_MUL16_LOOP_END   ; Skip the add if the next bit is zero.
    lda     TB_TEMP3            ; Add TB_TEMP2 to TB_TEMP3 on a 1 bit.
    clc
    adc     TB_TEMP2
    sta     TB_TEMP3
    lda     TB_TEMP3+1
    adc     TB_TEMP2+1
    sta     TB_TEMP3+1
TB_MUL16_LOOP_END:
    dey                         ; Have we completed all 16 iterations?
    bne     TB_MUL16_LOOP
    lda     TB_TEMP3            ; Copy the result back to TB_ACCUM.
    sta     TB_ACCUM
    lda     TB_TEMP3+1
    sta     TB_ACCUM+1
    rts
;
; "FPMUL" opcode handler.
;
; Performs a fixed-point multiplication of two 16-bit values,
; producing a 32-bit intermediate result and then shifting it
; back into position by a given constant bit count.
;
TB_OP_FPMUL:
    jsr     TB_POP_AESTK        ; Get the values to multiply into
    jsr     TB_POP2_AESTK       ; TB_TEMP and TB_TEMP2.
    lda     TB_TEMP+1           ; TB_BCD stores the final sign.
    eor     TB_TEMP2+1
    sta     TB_BCD
;
    jsr     TB_ABS_TEMP         ; Compute the absolute values of TB_TEMP
    jsr     TB_ABS_TEMP2        ; and TB_TEMP2.
;
    jsr     TB_MUL32            ; Multiply the values and get a 32-bit result.
;
    ldy     TB_ACCUM            ; Shift down by the bit count.
    beq     TB_OP_FPMUL_NO_SHIFT
TB_OP_FPMUL_SHIFT:
    lsr     TB_TEMP3+3
    ror     TB_TEMP3+2
    ror     TB_TEMP3+1
    ror     TB_TEMP3
    dey
    bne     TB_OP_FPMUL_SHIFT
;
TB_OP_FPMUL_NO_SHIFT:
    lda     TB_TEMP3+2          ; Overflow if the high bytes are non-zero.
    bne     TB_OP_FPMUL_OV
    lda     TB_TEMP3+3
    bne     TB_OP_FPMUL_OV
    bit     TB_BCD              ; Do we need to negate the result?
    bpl     TB_OP_FPMUL_POS
;
TB_OP_FPMUL_NEG:
    lda     TB_TEMP3            ; Result is negative.
    eor     #$FF
    clc
    adc     #1
    sta     TB_ACCUM
    lda     TB_TEMP3+1
    eor     #$FF
    adc     #0
    ;;bpl   TB_OP_FPMUL_OV      ; Overflow if the negated value has high bit 0.
    sta     TB_ACCUM+1
    rts
;
TB_OP_FPMUL_POS:
    lda     TB_TEMP3+1          ; Result is positive.
    bmi     TB_OP_FPMUL_OV      ; Overflow if the positive value has high bit 1.
    sta     TB_ACCUM+1
    lda     TB_TEMP3
    sta     TB_ACCUM
    rts
;
TB_OP_FPMUL_OV:
    ldx     #TB_E_OVERFLOW      ; The FPMUL result overflowed signed 16-bit.
    jmp     TB_ERROR
;
; Multiply the two 16-bit unsigned values in TB_TEMP and TB_TEMP2,
; producing a 32-bit unsigned result in TB_TEMP3.
;
TB_MUL32:
    lda     #0                  ; Zero the result.
    sta     TB_TEMP3
    sta     TB_TEMP3+1
    sta     TB_TEMP3+2
    sta     TB_TEMP3+3
    ldy     #16
TB_MUL32_LOOP:
    asl     TB_TEMP3            ; Rotate the result left.
    rol     TB_TEMP3+1
    rol     TB_TEMP3+2
    rol     TB_TEMP3+3
    asl     TB_TEMP             ; Get the high bit of TB_TEMP.
    rol     TB_TEMP+1
    bcc     TB_MUL32_LOOP_END   ; Skip the add if the next bit is zero.
    lda     TB_TEMP3            ; Add TB_TEMP2 to TB_TEMP3 on a 1 bit.
    clc
    adc     TB_TEMP2
    sta     TB_TEMP3
    lda     TB_TEMP3+1
    adc     TB_TEMP2+1
    sta     TB_TEMP3+1
    lda     TB_TEMP3+2
    adc     #0
    sta     TB_TEMP3+2
    lda     TB_TEMP3+3
    adc     #0
    sta     TB_TEMP3+3
TB_MUL32_LOOP_END:
    dey                         ; Have we completed all 16 iterations?
    bne     TB_MUL32_LOOP
    rts
;
; "DIV" opcode handler.
;
; Divide two 16-bit integers to get a quotient.  The arguments are in
; TB_TEMP2 and TB_ACCUM.  Result in TB_ACCUM.
;
TB_OP_DIV_APPLY:
    jsr     TB_DIV
    bit     TB_BCD              ; Do we need to negate the quotient?
    bpl     TB_OP_DIV_APPLY1
    jsr     TB_NEG_TEMP2        ; Negate the quotient.
TB_OP_DIV_APPLY1:
    lda     TB_TEMP2            ; Put the quotient into TB_ACCUM.
    sta     TB_ACCUM
    lda     TB_TEMP2+1
    sta     TB_ACCUM+1
    rts
;
; "MOD" opcode handler.
;
; Divide two 16-bit integers to get a remainder.  The arguments are in
; TB_TEMP2 and TB_ACCUM.  Result in TB_ACCUM.
;
TB_OP_MOD_APPLY:
    jsr     TB_DIV
    bit     TB_BCD              ; Do we need to negate the remainder?
    bpl     TB_OP_MOD_APPLY1
    lda     TB_TEMP3            ; Negate the remainder.
    eor     #$FF
    clc
    adc     #1
    sta     TB_ACCUM
    lda     TB_TEMP3+1
    eor     #$FF
    adc     #0
    sta     TB_ACCUM+1
    rts
TB_OP_MOD_APPLY1:
    lda     TB_TEMP3            ; Put the remainder back onto AESTK.
    sta     TB_ACCUM
    lda     TB_TEMP3+1
    sta     TB_ACCUM+1
    rts
;
; Divide the TB_TEMP2 by TB_ACCUM, with the quotient in TB_TEMP2
; and the remainder in TB_TEMP3.
;
TB_DIV:
    lda     TB_ACCUM            ; Is the divisor zero?
    ora     TB_ACCUM+1
    beq     TB_DIV_BY_ZERO
;
    lda     TB_ACCUM+1          ; Get the sign of the result.
    eor     TB_TEMP2+1
    sta     TB_BCD
;
    jsr     TB_OP_ABS_APPLY     ; Compute the absolute values of TB_ACCUM
    jsr     TB_ABS_TEMP2        ; and TB_TEMP2.
;
    lda     #0
    sta     TB_TEMP3            ; Zero the remainder.
    sta     TB_TEMP3+1
;
    ldy     #16
TB_DIV_LOOP:
    asl     TB_TEMP2            ; Rotate TB_TEMP2 into remainder in TB_TEMP3.
    rol     TB_TEMP2+1
    rol     TB_TEMP3
    rol     TB_TEMP3+1
;
    lda     TB_TEMP3            ; Subtract TB_ACCUM from the remainder.
    sec
    sbc     TB_ACCUM
    tax
    lda     TB_TEMP3+1
    sbc     TB_ACCUM+1
    bcc     TB_DIV_NEXT_BIT     ; If there was a borrow, quotient bit is 0.
;
    inc     TB_TEMP2            ; Set the next quotient bit to 1.
    sta     TB_TEMP3+1          ; Update the remainder.
    stx     TB_TEMP3
;
TB_DIV_NEXT_BIT:
    dey
    bne     TB_DIV_LOOP         ; Go around again for the next bit.
    rts
;
TB_DIV_BY_ZERO:
    lda     #TB_E_DIVZERO
    jmp     TB_ERROR
;
; Computes the absolute value of TB_TEMP.
;
TB_ABS_TEMP:
    bit     TB_TEMP+1
    bpl     TB_ABS_TEMP_DONE
TB_NEG_TEMP:
    lda     TB_TEMP
    eor     #$FF
    clc
    adc     #1
    sta     TB_TEMP
    lda     TB_TEMP+1
    eor     #$FF
    adc     #0
    sta     TB_TEMP+1
TB_ABS_TEMP_DONE:
    rts
;
; Computes the absolute value of TB_TEMP2.
;
TB_ABS_TEMP2:
    bit     TB_TEMP2+1
    bpl     TB_ABS_TEMP_DONE
TB_NEG_TEMP2:
    lda     TB_TEMP2
    eor     #$FF
    clc
    adc     #1
    sta     TB_TEMP2
    lda     TB_TEMP2+1
    eor     #$FF
    adc     #0
    sta     TB_TEMP2+1
TB_ABS_TEMP2_DONE:
    rts
;
; "ABS" opcode handler that computes the absolute value of TB_ACCUM.
;
TB_OP_ABS_APPLY:
    bit     TB_ACCUM+1
    bpl     TB_OP_ABS_DONE
    ; Fall through to TB_OP_NEG.
;
; "NEG" opcode handler that negates TB_ACCUM.
;
TB_OP_NEG:
    lda     TB_ACCUM
    eor     #$FF
    clc
    adc     #1
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    eor     #$FF
    adc     #0
    sta     TB_ACCUM+1
TB_OP_ABS_DONE:
    rts
;
; "BAND" opcode handler.
;
TB_OP_BAND_APPLY:
    lda     TB_ACCUM
    and     TB_TEMP2
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    and     TB_TEMP2+1
    sta     TB_ACCUM+1
    rts
;
; "BOR" opcode handler.
;
TB_OP_BOR_APPLY:
    lda     TB_ACCUM
    ora     TB_TEMP2
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    ora     TB_TEMP2+1
    sta     TB_ACCUM+1
    rts
;
; "BXOR" opcode handler.
;
TB_OP_BXOR_APPLY:
    lda     TB_ACCUM
    eor     TB_TEMP2
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    eor     TB_TEMP2+1
    sta     TB_ACCUM+1
    rts
;
; "BNOT" opcode handler.
;
TB_OP_BNOT:
    lda     TB_ACCUM
    eor     #$FF
    sta     TB_ACCUM
    lda     TB_ACCUM+1
    eor     #$FF
    sta     TB_ACCUM+1
    rts
;
; "SHL" opcode handler.
;
TB_OP_SHL_APPLY:
    jsr     TB_VERIFY_SHIFT_BIT
TB_OP_SHL1:
    asl     TB_ACCUM
    rol     TB_ACCUM+1
    dey
    bne     TB_OP_SHL1
    rts
;
; "SHR" opcode handler.
;
; Both SHR and LSR require that "ror" works properly.  Must have
; at least a 6502A.  The original 6502 will malfunction.
;
TB_OP_SHR_APPLY:
    jsr     TB_VERIFY_SHIFT_BIT
TB_OP_SHR1:
    lda     TB_ACCUM+1          ; Get the high bit of the value into C.
    asl     a
    ror     TB_ACCUM+1          ; Shift it back in for the arithmetic shift.
    ror     TB_ACCUM
    dey
    bne     TB_OP_SHR1
    rts
;
; "LSR" opcode handler.
;
TB_OP_LSR_APPLY:
    jsr     TB_VERIFY_SHIFT_BIT
TB_OP_LSR1:
    lsr     TB_ACCUM
    ror     TB_ACCUM+1
    dey
    bne     TB_OP_LSR1
    rts
;
; Verify the bit count for "SHL", "SHR", and "LSR".
;
; On exit, Y will be the bit count between 1 and 16.  If the bit
; count is less than or equal to zero, then the return address is
; popped and control returns to our caller's caller.
;
; On exit, the value to shift has been moved from TB_TEMP2 to TB_ACCUM.
;
TB_VERIFY_SHIFT_BIT:
    ldy     TB_ACCUM+1
    bmi     TB_VERIFY_SHIFT_NONE
    bne     TB_VERIFY_SHIFT_FULL
    ldy     TB_ACCUM
    beq     TB_VERIFY_SHIFT_NONE
    cpy     #17
    bcc     TB_VERIFY_SHIFT_NORMAL
TB_VERIFY_SHIFT_FULL:
    ldy     #16
TB_VERIFY_SHIFT_NORMAL:
    lda     TB_TEMP2            ; Move TB_TEMP2 to TB_ACCUM.
    sta     TB_ACCUM
    lda     TB_TEMP2+1
    sta     TB_ACCUM+1
    rts
TB_VERIFY_SHIFT_NONE:
    pla                         ; Shift <= 0, nothing to do.
    pla
    jmp     TB_VERIFY_SHIFT_NORMAL
;
; "LAND" opcode handler.
;
TB_OP_LAND:
    jsr     TB_POP_AESTK
    lda     TB_TEMP
    ora     TB_TEMP+1
    beq     TB_SET_FALSE
    lda     TB_ACCUM
    ora     TB_ACCUM+1
    bne     TB_SET_TRUE
    beq     TB_SET_FALSE
;
; "LOR" opcode handler.
;
TB_OP_LOR:
    jsr     TB_POP_AESTK
    lda     TB_TEMP
    ora     TB_TEMP+1
    bne     TB_SET_TRUE
    lda     TB_ACCUM
    ora     TB_ACCUM+1
    bne     TB_SET_TRUE
    beq     TB_SET_FALSE
;
; "LNOT" opcode handler.
;
TB_OP_LNOT:
    lda     TB_ACCUM
    ora     TB_ACCUM+1
    bne     TB_SET_FALSE
TB_SET_TRUE:
    lda     #1
    sta     TB_ACCUM
    lda     #0
    sta     TB_ACCUM+1
    rts
TB_SET_FALSE:
    lda     #0
    sta     TB_ACCUM
    sta     TB_ACCUM+1
    rts
;
;---------------------------------------------------------------------------
;
; Comparison operators.
;
;---------------------------------------------------------------------------
;
; "CMPEQ" opcode handler.
;
TB_OP_CMPEQ_APPLY:
    jsr     TB_COMPARE
    beq     TB_SET_TRUE
    bne     TB_SET_FALSE
;
; "CMPNE" opcode handler.
;
TB_OP_CMPNE_APPLY:
    jsr     TB_COMPARE
    beq     TB_SET_FALSE
    bne     TB_SET_TRUE
;
; "CMPLT" opcode handler.
;
TB_OP_CMPLT_APPLY:
    jsr     TB_COMPARE
    bcc     TB_SET_TRUE
    bcs     TB_SET_FALSE
;
; "CMPGT" opcode handler.
;
TB_OP_CMPGT_APPLY:
    jsr     TB_COMPARE
    bcc     TB_SET_FALSE
    beq     TB_SET_FALSE
    bcs     TB_SET_TRUE
;
; "CMPLE" opcode handler.
;
TB_OP_CMPLE_APPLY:
    jsr     TB_COMPARE
    bcc     TB_SET_TRUE
    beq     TB_SET_TRUE
    bcs     TB_SET_FALSE
;
; "CMPGE" opcode handler.
;
TB_OP_CMPGE_APPLY:
    jsr     TB_COMPARE
    bcs     TB_SET_TRUE
    bcc     TB_SET_FALSE
;
; Compares two signed integer values for less than, equal, or greater than.
; Sets the zero and carry flags appropriately.
;
TB_COMPARE:
    lda     TB_ACCUM+1
    eor     #$80                ; Invert the high bits to make it easier to
    sta     TB_ACCUM+1          ; compare the signed values as unsigned.
    lda     TB_TEMP2+1
    eor     #$80
    cmp     TB_ACCUM+1
    bne     TB_COMPARE1
    lda     TB_TEMP2
    cmp     TB_ACCUM
TB_COMPARE1:
    rts
;
;---------------------------------------------------------------------------
;
; Random number generation.
;
;---------------------------------------------------------------------------
;
; "RANDOM" opcode handler.
;
TB_OP_RANDOM_APPLY:
    lda     TB_ACCUM+1          ; Argument less than or equal to 0 is invalid.
    bmi     TB_OP_RANDOM_FAIL
    ora     TB_ACCUM
    beq     TB_OP_RANDOM_FAIL
;
; Generates a random number using the cc65 algorithm:
;
; seed = (seed * 16843009 + 826366247) mod 2^32
;
;  16843009 = 0x01010101
; 826366247 = 0x31415927
;
    lda     TB_SEED             ; TEMP = SEED + (SEED << 8)
    sta     TB_TEMP3
    lda     TB_SEED+1
    clc
    adc     TB_SEED
    sta     TB_TEMP3+1
    lda     TB_SEED+2
    adc     TB_SEED+1
    sta     TB_TEMP3+2
    lda     TB_SEED+3
    adc     TB_SEED+2
    sta     TB_TEMP3+3
;
    lda     TB_TEMP3+2          ; TEMP += (TB_SEED << 16)
    clc
    adc     TB_SEED
    sta     TB_TEMP3+2
    lda     TB_TEMP3+3
    adc     TB_SEED+1
    clc                         ; TEMP += (TB_SEED << 24)
    adc     TB_SEED
    sta     TB_TEMP3+3
;
    lda     TB_TEMP3            ; TEMP += 0x31415927
    clc
    adc     #$27
    sta     TB_SEED
    lda     TB_TEMP3+1
    adc     #$59
    sta     TB_SEED+1
    lda     TB_TEMP3+2
    adc     #$41
    sta     TB_SEED+2
    lda     TB_TEMP3+3
    adc     #$31
    sta     TB_SEED+3
;
; Take the top 2 bytes of TB_SEED and multiply them by the argument.
; Then take the top 2 bytes of the 32-bit product as the random result.
;
    lda     TB_ACCUM
    sta     TB_TEMP
    lda     TB_ACCUM+1
    sta     TB_TEMP+1
    lda     TB_SEED+2
    sta     TB_TEMP2
    lda     TB_SEED+3
    sta     TB_TEMP2+1
    jsr     TB_MUL32
    lda     TB_TEMP3+2
    sta     TB_ACCUM
    lda     TB_TEMP3+3
    sta     TB_ACCUM+1
    rts
;
TB_OP_RANDOM_FAIL:
    ldx     #TB_E_ILLFUNC
    jmp     TB_ERROR
;
;---------------------------------------------------------------------------
;
; Machine code level handling.
;
;---------------------------------------------------------------------------
;
; "MCALL" opcode handler.
;
; Perform a machine language subroutine call.
;
TB_OP_MCALL:
    lda     #0                  ; Clear the A, X, and Y registers.
    tax
    tay
    jmp     (TB_ACCUM)          ; Call the address and hope it doesn't crash!
;
; "PEEK" opcode handler to peek at locations in memory.
;
TB_OP_PEEK_APPLY:
    ldy     #0
    lda     (TB_ACCUM),y        ; PEEK at the value in memory.
    sta     TB_ACCUM
    sty     TB_ACCUM+1
    rts
;
; "POKE" opcode handler to poke at locations in memory.
;
TB_OP_POKE:
    ldx     TB_AESTK_TOP        ; Pop the address to poke into.
    lda     TB_ACCUM            ; The value to poke is in TB_ACCUM.
    ldy     #0
    sta     (TB_TEMP),y
    rts
;
;---------------------------------------------------------------------------
;
; Program memory management.
;
;---------------------------------------------------------------------------
;
; "INSRT" opcode handler.
;
; Insert the input line into the BASIC program, or delete it.
;
TB_OP_INSRT:
    jsr     TB_OP_CLEAR         ; Clear all variables on a program change.
    jsr     TB_SKIPWS           ; Skip whitespace and find the next character.
    cmp     #0                  ; Are we already at the end of the line?
    bne     TB_INPUT_LINE_INSERT
    jmp     TB_DELETE_LINE      ; If no text on the line, delete it.
;
TB_INPUT_LINE_INSERT:
    ldx     #0                  ; Count the number of chars in the input line.
    stx     TB_TEMP3+1
TB_INPUT_LINE_SIZE:
    inx
    iny
    lda     (TB_LINEPTR),y
    bne     TB_INPUT_LINE_SIZE
    txa
    clc
    adc     #4
    sta     TB_TEMP3
    rol     TB_TEMP3+1          ; Total input line size is now in TB_TEMP3.
;
    jsr     TB_FIND_LINE        ; Find the existing line, or the insert point.
    bcc     TB_INSERT_LINE      ; If no existing line, only need the insert.
    jsr     TB_DELETE_CURRENT   ; Delete the existing line.
;
; Insert into the program at the current location.
;
TB_INSERT_LINE:
    lda     TB_ANEXT            ; Is there enough room for the new line?
    clc
    adc     TB_TEMP3
    tay
    lda     TB_ANEXT+1
    adc     TB_TEMP3+1
    cmp     TB_HIMEM+1          ; Check if the insert will go past HIMEM.
    bcc     TB_INSERT_LINE2
    bne     TB_INSERT_FAIL
    tya
    cmp     TB_HIMEM
    beq     TB_INSERT_LINE2
    bcc     TB_INSERT_LINE2
TB_INSERT_FAIL:
    ldx     #TB_E_MEMORY        ; Not enough memory for the new line.
    jmp     TB_ERROR
TB_INSERT_LINE2:
    jsr     TB_FIND_LINE        ; Find the position to insert at.
;
    lda     TB_ASTART           ; Prepare to shift everything up to make room.
    sta     TB_BCD              ; BCD is the original ASTART.
    clc
    adc     TB_TEMP3
    sta     TB_TEMP2            ; TEMP2 is the new ASTART and also
    sta     TB_ASTART           ; update ASTART.
    lda     TB_ASTART+1
    sta     TB_BCD+1
    adc     TB_TEMP3+1
    sta     TB_TEMP2+1
    sta     TB_ASTART+1
;
    ldy     #0                  ; Move everything up.
TB_INSERT_LINE3:
    lda     TB_TEMP2            ; Decrement TEMP2.
    sec
    sbc     #1
    sta     TB_TEMP2
    lda     TB_TEMP2+1
    sbc     #0
    sta     TB_TEMP2+1
;
    lda     TB_BCD              ; Decrement BCD.
    sec
    sbc     #1
    sta     TB_BCD
    lda     TB_BCD+1
    sbc     #0
    sta     TB_BCD+1
;
    lda     (TB_BCD),y          ; Transfer a byte up from BCD to TEMP2.
    sta     (TB_TEMP2),y
;
    lda     TB_BCD+1            ; Stop when BCD = PROGPTR.
    cmp     TB_PROGPTR+1
    bne     TB_INSERT_LINE3
    lda     TB_BCD
    cmp     TB_PROGPTR
    bne     TB_INSERT_LINE3
;
    lda     TB_ACCUM            ; Write the line number to the new line.
    sta     (TB_BCD),y
    iny
    lda     TB_ACCUM+1
    sta     (TB_BCD),y
    iny
;
    lda     TB_TEMP3            ; Write the length of the line.
    sec
    sbc     #4
    sta     (TB_BCD),y
    iny
;
    ldx     TB_LINEPOS          ; Copy the line from KEYBUF to the program.
TB_INSERT_LINE4:
    lda     KEYBUF,x
    beq     TB_INSERT_LINE5
    sta     (TB_BCD),y
    iny
    inx
    bne     TB_INSERT_LINE4
;
TB_INSERT_LINE5:
    lda     #0                  ; Terminate the line with a NUL.
    sta     (TB_BCD),y
;
    jmp     TB_OP_CLEAR         ; Clear all variables on a program change.
;
; Delete a line from the program.
;
TB_DELETE_LINE:
    jsr     TB_FIND_LINE        ; Find the line to delete.
    bcc     TB_DELETE_NO_LINE   ; If it doesn't exist, nothing to do.
TB_DELETE_CURRENT:
    lda     TB_PROGPTR          ; Copy current program position to TB_TEMP3+2.
    sta     TB_TEMP3+2
    lda     TB_PROGPTR+1
    sta     TB_TEMP3+3
    ldy     #2                  ; Get the addres of the next line into TB_BCD+1.
    lda     (TB_PROGPTR),y
    clc
    adc     #4
    beq     TB_DELETE_CURRENT1
    clc
    adc     TB_PROGPTR
    sta     TB_BCD+1
    lda     TB_PROGPTR+1
    adc     #0
    sta     TB_BCD+2
    jmp     TB_DELETE_CURRENT2
TB_DELETE_CURRENT1:
    lda     TB_PROGPTR          ; Deleted line size is 256 bytes.
    sta     TB_BCD+1
    lda     TB_PROGPTR+1
    sta     TB_BCD+2
    inc     TB_BCD+2
TB_DELETE_CURRENT2:
    ldy     #0
TB_DELETE_CURRENT3:
    lda     (TB_BCD+1),y         ; Move everything down until program end.
    sta     (TB_TEMP3+2),y
    inc     TB_TEMP3+2
    bne     TB_DELETE_CURRENT4
    inc     TB_TEMP3+2
TB_DELETE_CURRENT4:
    inc     TB_BCD+1
    bne     TB_DELETE_CURRENT5
    inc     TB_BCD+2
TB_DELETE_CURRENT5:
    lda     TB_BCD+2
    cmp     TB_ASTART+1         ; Have we reached the end of the program?
    bcc     TB_DELETE_CURRENT3
    bne     TB_DELETE_CURRENT6
    lda     TB_BCD+1
    cmp     TB_ASTART
    bcc     TB_DELETE_CURRENT3
TB_DELETE_CURRENT6:
    lda     TB_TEMP3+2          ; Rebuild the array section after the program.
    sta     TB_ASTART
    lda     TB_TEMP3+3
    sta     TB_ASTART+1
    jmp     TB_OP_CLEAR
TB_DELETE_NO_LINE:
    rts
;
; "LIST0" opcode handler.
;
; Set up to list the entire program.
;
TB_OP_LIST0:
    lda     TB_LOMEM            ; Point at the first line in the program.
    sta     TB_PROGPTR
    lda     TB_LOMEM+1
    sta     TB_PROGPTR+1
    lda     #$FF                ; List up to line $FFFF; i.e. everything.
    sta     TB_TEMP2
    sta     TB_TEMP2+1
    rts
;
; "LIST1" opcode handler.
;
; Set up to list a single line in the program.
;
TB_OP_LIST1:
    lda     TB_ACCUM
    sta     TB_TEMP2
    lda     TB_ACCUM+1
    sta     TB_TEMP2+1
    jsr     TB_FIND_LINE
    bcc     TB_OP_LIST_INVALID
    rts
TB_OP_LIST_INVALID:
    ldx     #TB_E_INVLINE
    jmp     TB_ERROR
;
; "LIST2" opcode handler.
;
; Set up to list a range of lines in the program.
;
TB_OP_LIST2:
    lda     TB_ACCUM            ; Get the ending line into TB_TEMP2.
    sta     TB_TEMP2
    lda     TB_ACCUM+1
    sta     TB_TEMP2+1
    jsr     TB_POP_UP_AESTK     ; Get the starting line into TB_ACCUM.
    jmp     TB_FIND_LINE        ; Find the first line, or the one after it.
;
; "LST" opcode handler.
;
; List the lines that were set up by a previous "LIST0", "LIST1", or
; "LIST2" instruction.
;
; The first line is pointed to by TB_PROGPTR.  The last line is in TB_TEMP2.
;
TB_OP_LST:
    ldy     #1
    lda     (TB_PROGPTR),y      ; Have we gone past line number TB_TEMP2?
    cmp     TB_TEMP2+1
    bcc     TB_OP_LST1
    bne     TB_OP_LST_DONE
    dey
    lda     (TB_PROGPTR),y
    cmp     TB_TEMP2
    bcc     TB_OP_LST1
    bne     TB_OP_LST_DONE
TB_OP_LST1:
    ldy     #0                  ; Print the line number.
    lda     (TB_PROGPTR),y
    sta     TB_ACCUM
    iny
    lda     (TB_PROGPTR),y
    sta     TB_ACCUM+1
    ora     TB_ACCUM
    beq     TB_OP_LST_DONE      ; Line number zero means "end of program".
    jsr     TB_PRU
    lda     #" "                ; Print a space.
    jsr     COUT
    ldy     #3                  ; Print the rest of the line.
TB_OP_LST2:
    lda     (TB_PROGPTR),y
    beq     TB_OP_LST3
    jsr     COUT
    iny
    bne     TB_OP_LST2
TB_OP_LST3:
    jsr     CRLF                ; Print CR-LF to terminate the line.
    jsr     TB_FIND_NEXT        ; Move forward to the next line
    jmp     TB_OP_LST           ; and back around again.
TB_OP_LST_DONE:
    rts
;
; Finds the line with number TB_ACCUM.  On exit, TB_PROGPTR will point to the
; line.  Carry set if the exact number was found.  Carry clear if found
; the next line number in sequence or the end of the program.
;
TB_FIND_LINE:
    lda     TB_LOMEM            ; Reset TB_PROGPTR to the start of the program.
    sta     TB_PROGPTR
    lda     TB_LOMEM+1
    sta     TB_PROGPTR+1
;
TB_FIND_FROM_CURRENT:
    ldy     #0                  ; Are we at the end of the program?
    lda     (TB_PROGPTR),y
    iny
    ora     (TB_PROGPTR),y
    beq     TB_FOUND_NEXT
    lda     TB_ACCUM+1          ; Check the line number we are looking for.
    cmp     (TB_PROGPTR),y
    bcc     TB_FOUND_NEXT
    bne     TB_FIND_FROM_NEXT
    dey
    lda     TB_ACCUM
    cmp     (TB_PROGPTR),y
    beq     TB_FOUND_EXACT
    bcc     TB_FOUND_NEXT
;
TB_FIND_FROM_NEXT:
    jsr     TB_FIND_NEXT        ; Skip forward to the next line.
    jmp     TB_FIND_FROM_CURRENT
;
TB_FOUND_NEXT:
    clc
TB_FOUND_EXACT:
    rts
;
; Find the next line in the program after TB_PROGPTR.
;
TB_FIND_NEXT:
    ldy     #2                  ; Get the length of the current line.
    lda     (TB_PROGPTR),y
    clc
    adc     #4
    beq     TB_FIND_NEXT1
    clc
    adc     TB_PROGPTR
    sta     TB_PROGPTR
    lda     TB_PROGPTR+1
    adc     #0
    sta     TB_PROGPTR+1
    rts
TB_FIND_NEXT1:
    inc     TB_PROGPTR+1        ; Line length + header is 256 bytes exactly.
    rts
;
; "SIZE" opcode handler.
;
; Print memory size information for the program and variables.
;
TB_OP_SIZE:
    ldx     #TB_MSG_PROG_SIZE-TB_MSGS
    jsr     TB_MSG_PRINT
    lda     TB_ASTART
    sec
    sbc     TB_LOMEM
    sta     TB_ACCUM
    lda     TB_ASTART+1
    sbc     TB_LOMEM+1
    sta     TB_ACCUM+1
    jsr     TB_PRU
    jsr     TB_PRINT_BYTES
;
    ldx     #TB_MSG_VARS_SIZE-TB_MSGS
    jsr     TB_MSG_PRINT
    lda     TB_ANEXT
    sec
    sbc     TB_ASTART
    sta     TB_ACCUM
    lda     TB_ANEXT+1
    sbc     TB_ASTART+1
    sta     TB_ACCUM+1
    jsr     TB_PRU
    jsr     TB_PRINT_BYTES
;
    ldx     #TB_MSG_FREE_SIZE-TB_MSGS
    jsr     TB_MSG_PRINT
    lda     TB_HIMEM
    sec
    sbc     TB_ANEXT
    sta     TB_ACCUM
    lda     TB_HIMEM+1
    sbc     TB_ANEXT+1
    sta     TB_ACCUM+1
    jsr     TB_PRU
;
TB_PRINT_BYTES:
    ldx     #TB_MSG_BYTES-TB_MSGS
    jsr     TB_MSG_PRINT
    jmp     CRLF
;
;---------------------------------------------------------------------------
;
; Program control flow.
;
;---------------------------------------------------------------------------
;
; "DONE" opcode handler.
;
; Check if we are done with the current statement and there are no
; more tokens on the line before the end of line or colon separator.
;
TB_OP_DONE:
    jsr     TB_SKIPWS           ; Skip whitespace and get the next character.
    cmp     #0                  ; At the end of the line?
    bne     TB_OP_DONE1
    sta     TB_COLON_MODE       ; Clear colon mode at end of line.
    rts
TB_OP_DONE1:
    cmp     #TB_SEP             ; Do we have a colon separator?
    bne     TB_OP_DONE2
    iny                         ; Skip past the colon.
    sty     TB_LINEPOS
    sta     TB_COLON_MODE       ; Remember that we saw the colon.
    rts
TB_OP_DONE2:
    jmp     TB_OP_ERR           ; Syntax error if not end of line or a colon.
;
; "END" opcode handler, which combines "DONE" and "NXT".
;
TB_OP_END:
    jsr     TB_OP_DONE
    ; Fall through to TB_OP_NXT.
;
; "NXT" opcode handler, which moves onto the next statement or line.
;
TB_OP_NXT:
    lda     TB_COLON_MODE       ; Did we encounter a colon statement separator?
    bne     TB_OP_NXT2          ; Yes, so start executing the next statement.
;
    lda     TB_LINENUM          ; Are we at the end of the line in direct mode?
    ora     TB_LINENUM+1
    beq     TB_OP_FIN
;
    ldy     #2                  ; Get the length of the current line.
    lda     (TB_LINEPTR),y
    clc
    adc     #4                  ; Add 4 for the line number, length, and NUL.
    beq     TB_OP_NXT3
    clc
    adc     TB_LINEPTR
    sta     TB_LINEPTR
    lda     TB_LINEPTR+1
    adc     #0
    sta     TB_LINEPTR+1
TB_OP_NXT1:
    ldy     #0                  ; Fetch the new line number.
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM
    iny
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM+1
    ora     TB_LINENUM          ; Line number 0 means "direct mode",
    beq     TB_OP_FIN           ; i.e. we ran off the end of the program.
TB_OP_RUN1:
    ldy     #3
    sty     TB_LINEPOS
TB_OP_NXT2:
    jmp     TB_IL_XEC           ; Start executing the new line.
TB_OP_NXT3:
    inc     TB_LINEPTR+1        ; Special case for line length = 252.
    jmp     TB_OP_NXT1
;
; "FIN" opcode handler.
;
; END the program and go back to direct mode.
;
TB_OP_FIN:
    jsr     TB_DIRECT           ; Go back to direct mode.
    jmp     TB_IL_C0
;
; "RNXT" opcode handler.
;
; Reset everything and start running the program from the start.
;
TB_OP_RNXT:
    jsr     TB_OP_CLEAR         ; Clear all variables from memory.
    lda     TB_LOMEM            ; Point to the start of the program.
    sta     TB_LINEPTR
    lda     TB_LOMEM+1
    sta     TB_LINEPTR+1
    lda     #3
    sta     TB_LINEPOS
    ldy     #0
    sty     KEYBUF              ; Clear the keyboard buffer for INPUT parsing.
    sty     TB_INPOS
    lda     (TB_LINEPTR),y      ; Fetch the line number of the first line.
    sta     TB_LINENUM
    iny
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM+1
    ora     TB_LINENUM          ; Is the first line number zero?
    bne     TB_OP_RUN1          ; If not, start running the program.
    beq     TB_OP_FIN           ; Otherwise go back to direct mode.
;
; "XFER" opcode handler.
;
; GOTO the line number in TB_ACCUM.
;
TB_OP_XFER:
    jsr     TB_FIND_LINE        ; Find the relevant line in the program.
    bcc     TB_LINE_NOT_FOUND   ; Carry is clear if the line was not found.
    lda     TB_PROGPTR          ; Switch to the new line.
    sta     TB_LINEPTR
    lda     TB_PROGPTR+1
    sta     TB_LINEPTR+1
    lda     #0
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM
    iny
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM+1
    ldy     #3
    sty     TB_LINEPOS
    jmp     TB_IL_XEC           ; Start executing the new line.
TB_LINE_NOT_FOUND:
    ldx     #TB_E_INVLINE
    jmp     TB_ERROR
;
; "SAV" opcode handler.
;
; Saves the current program location on SUBSTK for a "GOSUB" statement.
;
TB_OP_SAV:
    lda     TB_LINENUM          ; Cannot do this in direct mode.
    ora     TB_LINENUM+1
    beq     TB_OP_SAV_INVALID
;
    lda     TB_SUBSTK_TOP       ; Will a RETURN frame fit on SUBSTK?
    tax
    clc
    adc     #6
    bmi     TB_OP_SAV_FULL
    sta     TB_SUBSTK_TOP       ; Update the top of stack for the pushed frame.
;
    jsr     TB_ADVANCE          ; Advance to the next statement before saving.
;
    lda     TB_LINENUM          ; Save the line number, pointer, and position.
    sta     TB_SUBSTK,x
    lda     TB_LINENUM+1
    sta     TB_SUBSTK+1,x
    lda     TB_LINEPTR
    sta     TB_SUBSTK+2,x
    lda     TB_LINEPTR+1
    sta     TB_SUBSTK+3,x
    lda     TB_LINEPOS
    sta     TB_SUBSTK+4,x
    lda     #6                  ; Size and type of the RETURN frame.
    sta     TB_SUBSTK+5,x
    rts
;
TB_OP_SAV_FULL:
    ldx     #TB_E_GOSUB         ; SUBSTK is full, TOO MANY GOSUBS.
    jmp     TB_ERROR
;
TB_OP_SAV_INVALID:
    ldx     #TB_E_DIRECT        ; Cannot use GOSUB or FOR in direct mode.
    jmp     TB_ERROR
;
TB_OP_FOR_FULL:
    ldx     #TB_E_FOR           ; SUBSTK is full, TOO MANY FORS.
    jmp     TB_ERROR
;
; "FOR" opcode handler.
;
TB_OP_FOR:
    lda     TB_LINENUM          ; Cannot do this in direct mode.
    ora     TB_LINENUM+1
    beq     TB_OP_SAV_INVALID
;
    lda     TB_SUBSTK_TOP       ; Will a FOR frame fit on SUBSTK?
    tax
    clc
    adc     #12
    bmi     TB_OP_FOR_FULL
    sta     TB_SUBSTK_TOP       ; Update the top of stack for the pushed frame.
;
    ldy     TB_AESTK_TOP        ; Copy step, stop, and var from AESTK to SUBSTK.
    lda     TB_ACCUM+1
    sta     TB_SUBSTK+5,x
    lda     TB_ACCUM
    sta     TB_SUBSTK+4,x
    dey
    lda     TB_AESTK,y
    eor     #$80                ; Invert sign bit of the stop value to help
    sta     TB_SUBSTK+3,x       ; with signed comparison during "NEXT".
    dey
    lda     TB_AESTK,y
    sta     TB_SUBSTK+2,x
    dey
    lda     TB_AESTK,y
    sta     TB_SUBSTK+1,x
    dey
    lda     TB_AESTK,y
    sta     TB_SUBSTK,x
    sty     TB_AESTK_TOP
;
    jsr     TB_ADVANCE          ; Advance to the next statement before saving.
;
    lda     TB_LINENUM          ; Save the line number, pointer, and position.
    sta     TB_SUBSTK+6,x
    lda     TB_LINENUM+1
    sta     TB_SUBSTK+7,x
    lda     TB_LINEPTR
    sta     TB_SUBSTK+8,x
    lda     TB_LINEPTR+1
    sta     TB_SUBSTK+9,x
    lda     TB_LINEPOS
    sta     TB_SUBSTK+10,x
    lda     #12                 ; Size and type of the FOR frame.
    sta     TB_SUBSTK+11,x
    rts
;
; "RSTR" opcode handler.
;
; Restores the program location from SUBSTK for a "RETURN" statement.
;
TB_OP_RSTR:
    ldx     TB_SUBSTK_TOP       ; Is SUBSTK empty?
    beq     TB_OP_RSTR_FAIL
    lda     TB_SUBSTK-1,x       ; Get the frame size / type.
    cmp     #6
    beq     TB_OP_RSTR_FOUND    ; Type 6 means we found a RETURN frame.
    eor     #$FF
    sec
    adc     TB_SUBSTK_TOP       ; Pop the FOR frame.
    sta     TB_SUBSTK_TOP
    jmp     TB_OP_RSTR          ; Try again to find a RETURN frame.
;
TB_OP_RSTR_FOUND:
    lda     TB_SUBSTK_TOP       ; Pop the RETURN frame.
    sec
    sbc     #6
    sta     TB_SUBSTK_TOP
    tax
;
TB_OP_LOOP_BACK:
    lda     TB_SUBSTK,x         ; Restore the original program position.
    sta     TB_LINENUM
    lda     TB_SUBSTK+1,x
    sta     TB_LINENUM+1
    lda     TB_SUBSTK+2,x
    sta     TB_LINEPTR
    lda     TB_SUBSTK+3,x
    sta     TB_LINEPTR+1
    lda     TB_SUBSTK+4,x
    sta     TB_LINEPOS
;
    lda     TB_LINENUM          ; Did we run off the end of the program?
    ora     TB_LINENUM+1
    beq     TB_OP_RSTR_END
;
    jmp     TB_IL_XEC           ; Resume execution after the GOSUB.
;
TB_OP_RSTR_FAIL:
    ldx     #TB_E_RETURN        ; SUBSTK is empty, RETURN WITHOUT GOSUB.
    jmp     TB_ERROR
;
TB_OP_NEXT_FAIL:
    ldx     #TB_E_NEXTFOR       ; SUBSTK is empty or we found a RETURN frame.
    jmp     TB_ERROR
;
TB_OP_RSTR_END:
    jmp     TB_OP_FIN           ; Ran off the end of the program for RETURN.
;
; "NEXT" opcode handler.
;
; Loop around for the "FOR" statement whose variable pointer is in TB_ACCUM.
; If TB_ACCUM 1s zero, then find the inner-most "FOR" loop.
;
TB_OP_NEXT:
    ldx     TB_SUBSTK_TOP       ; Is SUBSTK empty?
    beq     TB_OP_NEXT_FAIL
    lda     TB_SUBSTK-1,x       ; Get the frame size / type.
    cmp     #12
    bne     TB_OP_NEXT_FAIL     ; Not type 12 means we found a RETURN frame.
;
    eor     #$FF                ; Find the start of the FOR frame.
    sec
    adc     TB_SUBSTK_TOP
    tax
;
    lda     TB_ACCUM            ; Is the variable we are looking for NULL?
    ora     TB_ACCUM+1
    beq     TB_OP_THIS_FOR      ; If yes, use the frame we just found.
;
    lda     TB_ACCUM            ; Is this FOR frame for the right variable?
    cmp     TB_SUBSTK,x
    bne     TB_OP_NOT_THIS_FOR
    lda     TB_ACCUM+1
    cmp     TB_SUBSTK+1,x
    bne     TB_OP_NOT_THIS_FOR
;
TB_OP_THIS_FOR:
    lda     TB_SUBSTK,x         ; Step this FOR loop's variable.
    sta     TB_TEMP2
    lda     TB_SUBSTK+1,x
    sta     TB_TEMP2+1
    ldy     #0
    lda     (TB_TEMP2),y
    clc
    adc     TB_SUBSTK+4,x
    sta     (TB_TEMP2),y
    sta     TB_TEMP3
    iny
    lda     (TB_TEMP2),y
    adc     TB_SUBSTK+5,x
    sta     (TB_TEMP2),y
    sta     TB_TEMP3+1
;
    lda     TB_SUBSTK+5,x       ; Are we stepping up or down?
    bmi     TB_OP_FOR_DOWN
;
    lda     TB_TEMP3+1          ; Stepping up, check for greater than.
    eor     #$80                ; Invert high bit to help with signed compare.
    cmp     TB_SUBSTK+3,x
    bcc     TB_OP_FOR_NEXT
    bne     TB_OP_FOR_DONE
    lda     TB_TEMP3
    cmp     TB_SUBSTK+2,x
    bcc     TB_OP_FOR_NEXT
    beq     TB_OP_FOR_NEXT
;
TB_OP_FOR_DONE:
    stx     TB_SUBSTK_TOP       ; Loop done, so pop the FOR frame.
    jmp     TB_OP_NXT
;
TB_OP_FOR_DOWN:
    lda     TB_TEMP3+1          ; Stepping down, check for less than.
    eor     #$80                ; Invert high bit to help with signed compare.
    cmp     TB_SUBSTK+3,x
    bcc     TB_OP_FOR_DONE
    bne     TB_OP_FOR_NEXT
    lda     TB_TEMP3
    cmp     TB_SUBSTK+2,x
    bcc     TB_OP_FOR_DONE
;
TB_OP_FOR_NEXT:
    txa                         ; Adjust the SUBSTK pointer and then
    clc                         ; loop back to the top of the FOR loop.
    adc     #6
    tax
    jmp     TB_OP_LOOP_BACK
;
TB_OP_NOT_THIS_FOR:
    stx     TB_SUBSTK_TOP       ; Pop the current FOR frame.
    jmp     TB_OP_NEXT          ; Try again with the next one up.
;
; "POP" opcode handler.
;
; Pop the top-most RETURN frame from SUBSTK.
;
TB_OP_POP:
    ldx     TB_SUBSTK_TOP       ; Is SUBSTK empty?
    beq     TB_OP_POP_FAIL
    lda     TB_SUBSTK-1,x       ; Get the frame size / type.
    cmp     #6
    beq     TB_OP_POP_DONE      ; Type 6 means we found a RETURN frame.
    eor     #$FF
    sec
    adc     TB_SUBSTK_TOP       ; Pop the FOR frame.
    sta     TB_SUBSTK_TOP
    jmp     TB_OP_POP           ; Try again to find a RETURN frame.
;
TB_OP_POP_DONE:
    lda     TB_SUBSTK_TOP       ; Pop and discard the RETURN frame.
    sec
    sbc     #6
    sta     TB_SUBSTK_TOP
    rts
;
TB_OP_POP_FAIL:
    jmp     TB_OP_RSTR_FAIL
;
; Advance to the next line if currently at the end of the line.
; This is used when saving the jump-back positions for GOSUB and FOR.
;
TB_ADVANCE:
    ldy     TB_LINEPOS
    lda     (TB_LINEPTR),y
    bne     TB_ADVANCE_NONE
    ldy     #2                  ; Advance to the next line
    lda     (TB_LINEPTR),y
    clc
    adc     #4
    beq     TB_ADVANCE2
    clc
    adc     TB_LINEPTR
    sta     TB_LINEPTR
    lda     TB_LINEPTR+1
    adc     #0
    sta     TB_LINEPTR+1
;
TB_ADVANCE1:
    ldy     #0                  ; Load the new line number.
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM
    iny
    lda     (TB_LINEPTR),y
    sta     TB_LINENUM+1
    ldy     #3                  ; Reset to the start of the next line.
    sty     TB_LINEPOS
    sty     TB_COLON_MODE       ; Activate colon mode if we advance.
    rts
;
TB_ADVANCE2:
    inc     TB_LINEPTR+1        ; Line is 256 bytes long.
    jmp     TB_ADVANCE1
;
TB_ADVANCE_NONE:
    rts
;
; "IF" opcode handler.
;
; Jump to the next line if the value in TB_ACCUM is zero.
;
TB_OP_IF:
    lda     TB_ACCUM
    ora     TB_ACCUM+1
    bne     TB_OP_IF1
    jmp     TB_OP_NXT
TB_OP_IF1:
    rts
;
;---------------------------------------------------------------------------
;
; Input handling.
;
;---------------------------------------------------------------------------
;
; "GETLN" opcode handler.
;
; Get a line of input in direct mode and normalize the line to remove
; duplicate spaces and convert unquoted text to upper case.
;
TB_OP_GETLN:
    pla                         ; Unwind the CPU stack when in direct mode.
    tay                         ; Pop the return address, unwind, re-push.
    pla
    ldx     TB_STACK_SAVE
    txs
    pha
    tya
    pha
;
    jsr     TB_GETLINE          ; Get a line of input.
;
    ldx     #0
    stx     TB_INPOS            ; Reset the INPUT line position.
    ldy     #0
TB_NORMALIZE:
    lda     KEYBUF,x            ; Get the next character.
    beq     TB_NORMALIZE_DONE
    cmp     #$20                ; Space?
    beq     TB_NORMALIZE_SPACE
    cmp     #$22                ; Double quote?
    beq     TB_NORMALIZE_QUOTE
    cmp     #$61                ; Lower case letter?
    bcc     TB_NORMALIZE1
    cmp     #$7B
    bcs     TB_NORMALIZE1
    and     #$5F                ; Convert lower case to upper case.
TB_NORMALIZE1:
    sta     KEYBUF,y            ; Add the character to the output buffer.
    inx
    iny
    cmp     #"R"                ; Is this possibly the start of "REM"?
    beq     TB_NORMALIZE_REM
    jmp     TB_NORMALIZE
TB_NORMALIZE_DONE:
    lda     #0                  ; Fix the NUL terminator at the end.
    sta     KEYBUF,y
;
    sta     TB_LINENUM          ; Reset the line for direct mode parsing.
    sta     TB_LINENUM+1
    sta     TB_LINEPOS
    lda     #<KEYBUF
    sta     TB_LINEPTR
    lda     #>KEYBUF
    sta     TB_LINEPTR+1
    rts
;
; Normalize multiple spaces into a single space.
;
TB_NORMALIZE_SPACE:
    inx
    cpy     #0
    beq     TB_NORMALIZE        ; Remove leading spaces entirely.
    lda     KEYBUF-1,y          ; Do we already have a space?
    cmp     #$20
    beq     TB_NORMALIZE
    lda     #$20
    sta     KEYBUF,y            ; Add the space to the line.
    iny
    jmp     TB_NORMALIZE
;
; Normalize quoted strings by copying them as-is.
;
TB_NORMALIZE_QUOTE:
    sta     KEYBUF,y
    inx
    iny
    lda     KEYBUF,x
    beq     TB_NORMALIZE_QUOTE_DONE
    cmp     #$22
    bne     TB_NORMALIZE_QUOTE
    sta     KEYBUF,y
    iny
    inx
TB_NORMALIZE_QUOTE_DONE:
    jmp     TB_NORMALIZE
;
; Normalize "REM" by copying the rest of the line as-is.
;
TB_NORMALIZE_REM:
    lda     KEYBUF,x            ; Is the next character 'E'?
    cmp     #"E"
    beq     TB_NORMALIZE_REM1
    cmp     #"e"
    bne     TB_NORMALIZE
TB_NORMALIZE_REM1:
    lda     KEYBUF+1,x          ; Is the next character after that 'M'?
    cmp     #"M"
    beq     TB_NORMALIZE_REM2
    cmp     #"m"
    bne     TB_NORMALIZE
TB_NORMALIZE_REM2:
    lda     #"E"                ; Copy "EM" to the output.
    sta     KEYBUF,y
    iny
    inx
    lda     #"M"
    sta     KEYBUF,y
    iny
    inx
TB_NORMALIZE_REM3:              ; Copy the rest of the line after "REM".
    lda     KEYBUF,x
    beq     TB_NORMALIZE_DONE
    sta     KEYBUF,y
    iny
    inx
    jmp     TB_NORMALIZE_REM3
;
; Get a line of input into KEYBUF with some basic line editing.
;
TB_GETLINE_BREAK:
    jmp     TB_BREAK
TB_GETLINE:
    ldx     #0
    stx     TB_TEMP             ; TB_TEMP is the current length of the line.
TB_GETLINE_LOOP:
    jsr     CIN                 ; Get the next input character.
;
    cmp     #TB_K_ENTER         ; Enter?
    beq     TB_GETLINE_DONE
    cmp     #TB_K_DEL           ; Backspace?
    beq     TB_GETLINE_BACK
    cmp     #TB_K_BS
    beq     TB_GETLINE_BACK
    cmp     #TB_K_TAB           ; TAB?
    beq     TB_GETLINE_TAB
    cmp     #TB_K_LEFT          ; Left arrow?
    beq     TB_GETLINE_LEFT
    cmp     #TB_K_RIGHT         ; Right arrow?
    beq     TB_GETLINE_RIGHT
    cmp     #TB_K_BREAK         ; BREAK?
    beq     TB_GETLINE_BREAK
;
    cmp     #$20                ; Is the key printable ASCII?
    bcc     TB_GETLINE_LOOP     ; If not, ignore the key.
    cmp     #$80                ; Is the key a special key?
    bcs     TB_GETLINE_LOOP     ; If it is, ignore the key.
;
    ldy     TB_TEMP             ; Is the line already full?
    cpy     #TB_MAX_LINESZ
    bcs     TB_GETLINE_LOOP
;
    jsr     TB_GETLINE_INSERT   ; Insert the character into the line.
    jmp     TB_GETLINE_LOOP     ; Go back for more.
;
; Enter pressed, so end the line.
;
TB_GETLINE_DONE:
    jsr     TB_GETLINE_REPRINT  ; Re-print the rest of the line.
    jsr     CRLF                ; Print CR-LF to terminate the line.
    lda     #0                  ; Make sure the line is NUL-terminated.
    ldx     TB_TEMP
    sta     KEYBUF,x
    rts
;
TB_GETLINE_BACK:
    cpx     #0                  ; Are we already at the start of the line?
    beq     TB_GETLINE_LOOP
    lda     #TB_K_BS            ; Backspace over the character.
    jsr     COUT
    dex
    jsr     TB_GETLINE_DELETE   ; Delete the current character.
    jmp     TB_GETLINE_LOOP
;
; Insert spaces until the next TAB stop.
;
TB_GETLINE_TAB:
    lda     TB_TEMP             ; Is the line already full?
    cmp     #TB_MAX_LINESZ
    bcs     TB_GETLINE_LOOP     ; If it is, stop inserting spaces.
    lda     #$20                ; Insert another space.
    jsr     TB_GETLINE_INSERT
    txa                         ; Have we reached the next TAB stop?
    and     #$07
    bne     TB_GETLINE_TAB
    beq     TB_GETLINE_LOOP
;
; Move left on the line without removing characters.
;
TB_GETLINE_LEFT:
    cpx     #0
    beq     TB_GETLINE_LOOP
    dex
    lda     #TB_K_BS
    jsr     COUT
    jmp     TB_GETLINE_LOOP
;
; Move right on the line over characters that were already typed.
;
TB_GETLINE_RIGHT:
    cpx     TB_TEMP
    bcs     TB_GETLINE_LOOP
    lda     KEYBUF,x            ; Re-print the character under the cursor.
    jsr     COUT
    inx
    jmp     TB_GETLINE_LOOP
;
; Insert a character into the input line buffer.
;
TB_GETLINE_INSERT:
    ldy     KEYBUF,x            ; Replace the current character in the line.
    sta     KEYBUF,x
    jsr     COUT                ; Print the new character.
    inx                         ; One extra character in the line.
    inc     TB_TEMP
    stx     TB_TEMP+1
TB_GETLINE_INSERT1:             ; Move the characters on the rest of the line.
    cpx     TB_TEMP
    bcs     TB_GETLINE_INSERT2
    tya
    ldy     KEYBUF,x
    sta     KEYBUF,x
    jsr     COUT                ; Re-print the character we have moved.
    inx
    bne     TB_GETLINE_INSERT1
TB_GETLINE_INSERT2:
    cpx     TB_TEMP+1           ; Backspace to the original insert position.
    beq     TB_GETLINE_INSERT3
    lda     #TB_K_BS
    jsr     COUT
    dex
    bne     TB_GETLINE_INSERT2
TB_GETLINE_INSERT3:
    rts
;
; Delete the current character from the line and re-print the rest.
;
TB_GETLINE_DELETE:
    stx     TB_TEMP+1
TB_GETLINE_DELETE1:
    inx
    cpx     TB_TEMP
    bcs     TB_GETLINE_DELETE2
    lda     KEYBUF,x            ; Move the character back one place.
    sta     KEYBUF-1,x
    jsr     COUT                ; Re-print the moved character.
    jmp     TB_GETLINE_DELETE1
TB_GETLINE_DELETE2:
    dec     TB_TEMP             ; Line is now one character shorter.
    dex
    lda     #$20                ; Erase the previous last character.
    jsr     COUT
    lda     #TB_K_BS
    jsr     COUT
    jmp     TB_GETLINE_INSERT2  ; Move back to the insertion point.
;
; Re-prints the rest of the line between the insertion point in X and the
; total length of the line in TB_TEMP.
;
TB_GETLINE_REPRINT:
    txa
    tay
TB_GETLINE_REPRINT1:
    cpy     TB_TEMP
    beq     TB_GETLINE_REPRINT2
    lda     KEYBUF,y
    jsr     COUT
    iny
    bne     TB_GETLINE_REPRINT1
TB_GETLINE_REPRINT2:
    rts
;
; "INNUM" opcode handler.
;
TB_OP_INNUM_FAIL:
    ldx     #TB_E_DIRECT        ; Cannot use INNUM in direct mode.
    jmp     TB_ERROR
TB_OP_INNUM:
    lda     TB_LINENUM          ; Are we in direct mode?
    ora     TB_LINENUM+1
    beq     TB_OP_INNUM_FAIL
;
    jsr     TB_PUSH_DOWN_AESTK  ; Make room for a new value in TB_ACCUM.
;
    ldx     TB_INPOS
TB_OP_INNUM_SKIPWS:
    lda     KEYBUF,x            ; Skip whitespace in KEYBUF.
    beq     TB_OP_INNUM_NEWLINE ; If no text on the line, get a new line.
    inx
    cmp     #$20
    beq     TB_OP_INNUM_SKIPWS
    dex
    sta     TB_TEMP             ; Remember the negative flag for later.
    cmp     #"-"                ; Negative number?
    bne     TB_OP_INNUM_NOTNEG
    inx
    lda     KEYBUF,x
;
TB_OP_INNUM_NOTNEG:
    cmp     #$30                ; Do we have an initial digit?
    bcc     TB_OP_INNUM_INVALID ; If not, then fail the INPUT operation.
    cmp     #$3A
    bcs     TB_OP_INNUM_INVALID
    and     #$0F
    sta     TB_ACCUM            ; Initialize TB_ACCUM with the first digit.
    lda     #0
    sta     TB_ACCUM+1
;
TB_OP_INNUM_DIGIT:
    inx
    lda     KEYBUF,x            ; Do we have another digit?
    cmp     #$30
    bcc     TB_OP_INNUM_DONE
    cmp     #$3A
    bcs     TB_OP_INNUM_DONE
    jsr     TB_MUL10            ; Multiply TB_ACCUM by 10 and add the digit.
    jmp     TB_OP_INNUM_DIGIT   ; Go around again for another digit.
;
TB_OP_INNUM_DONE:
    stx     TB_INPOS            ; Save the input position for next time.
    lda     TB_TEMP             ; Was the number supposed to be negative?
    cmp     #"-"
    bne     TB_OP_INNUM_POS
    jmp     TB_OP_NEG           ; Negate TB_ACCUM.
TB_OP_INNUM_POS:
    rts
;
TB_OP_INNUM_NEWLINE:
    jsr     TB_GETLINE          ; Get a new line of input.
    ldx     #0                  ; Reset to the start of the line.
    stx     TB_INPOS
    beq     TB_OP_INNUM_SKIPWS
;
TB_OP_INNUM_INVALID:
    stx     TB_INPOS
    ldx     #TB_E_TYPE          ; Type mismatch if the input is not numeric.
    jmp     TB_ERROR
;
; "INKEY" opcode handler.
;
; Wait for a key up until the timeout in milliseconds in TB_ACCUM.
;
TB_OP_INKEY:
    lda     TB_ACCUM+1
    bmi     TB_OP_INKEY_FOREVER
    bne     TB_OP_INKEY_LONG
;
TB_OP_INKEY_SHORT:
    ldx     TB_ACCUM            ; Timeout is 0-255 milliseconds.
    jsr     CIN_T
    bcc     TB_OP_INKEY_TIMEOUT
TB_OP_INKEY_DONE:
    cmp     #TB_K_BREAK
    beq     TB_OP_INKEY_BREAK
    sta     TB_ACCUM            ; Set TB_ACCUM to the keycode.
    lda     #0
    sta     TB_ACCUM+1
    rts
;
TB_OP_INKEY_FOREVER:
    jsr     CIN                 ; Wait for a key forever.
    jmp     TB_OP_INKEY_DONE
;
TB_OP_INKEY_TIMEOUT:
    lda     #$FF                ; Timed out while waiting for a key.
    sta     TB_ACCUM
    sta     TB_ACCUM+1
    rts
;
TB_OP_INKEY_BREAK:
    jmp     TB_BREAK            ; The user pressed CTRL-C.
;
; Handle a long timeout >= 256 milliseconds.
;
TB_OP_INKEY_LONG:
    tay                         ; High byte of the timeout period.
TB_OP_INKEY_LONG1:
    ldx     #128                ; Handle the high byte timeout 128ms at a time.
    jsr     CIN_T
    bcs     TB_OP_INKEY_DONE
    ldx     #128
    jsr     CIN_T
    bcs     TB_OP_INKEY_DONE
    dey
    bne     TB_OP_INKEY_LONG1
    beq     TB_OP_INKEY_SHORT   ; Now deal with the left-over low byte.
;
;---------------------------------------------------------------------------
;
; Variables and arrays.
;
;---------------------------------------------------------------------------
;
; "STORE" opcode handler.
;
; Store the value in TB_ACCUM to the pointer at the top of AESTK.
;
TB_OP_STORE:
    jsr     TB_POP_AESTK        ; Get the variable's pointer into TB_TEMP.
    ldy     #0                  ; Do the store.
    lda     TB_ACCUM
    sta     (TB_TEMP),y
    iny
    lda     TB_ACCUM+1
    sta     (TB_TEMP),y
    rts
;
; "STOREV" opcode handler.
;
; Same as "STORE" but do not pop the variable pointer, only the value.
;
TB_OP_STOREV:
    jsr     TB_POP_AESTK        ; Get the variable's pointer into TB_TEMP.
    ldy     #0                  ; Do the store.
    lda     TB_ACCUM
    sta     (TB_TEMP),y
    iny
    lda     TB_ACCUM+1
    sta     (TB_TEMP),y
    lda     TB_TEMP             ; Transfer TB_TEMP to TB_ACCUM for the
    sta     TB_ACCUM            ; new cached top of stack.
    lda     TB_TEMP+1
    sta     TB_ACCUM+1
    rts
;
; "IND" opcode handler.
;
; Index into the variable pointer in TB_ACCUM and get the value into TB_ACCUM.
;
TB_OP_IND:
    ldy     #0
    lda     (TB_ACCUM),y
    tax
    iny
    lda     (TB_ACCUM),y
    sta     TB_ACCUM+1
    stx     TB_ACCUM
    rts
;
; "ARRAY1" opcode handler.
;
; Index into a 1-dimensional array and get the element pointer.
; TB_ACCUM is the array index and the array pointer is on AESTK.
; At the end of this, TB_ACCUM will point to the element in the array.
;
TB_OP_ARRAY1:
    jsr     TB_POP_AESTK        ; Pop the array pointer into TB_TEMP.
;
    ldy     #3                  ; Check that we have a dimensioned 1D array.
    lda     (TB_TEMP),y
    dey
    ora     (TB_TEMP),y
    bne     TB_NOT_ARRAY
    dey
    lda     (TB_TEMP),y
    dey
    ora     (TB_TEMP),y
    beq     TB_NOT_ARRAY
;
    lda     TB_ACCUM+1          ; Check the array bounds.
    bmi     TB_ARRAY_BOUNDS     ; Negative indexes are not allowed.
    iny
    cmp     (TB_TEMP),y
    bcc     TB_OP_ARRAY1_OK
    bne     TB_ARRAY_BOUNDS
    dey
    lda     TB_ACCUM
    cmp     (TB_TEMP),y
    bcs     TB_ARRAY_BOUNDS
;
TB_OP_ARRAY1_OK:
    asl     TB_ACCUM            ; Multiply the index by 2.
    rol     TB_ACCUM+1
    ldy     #4
    lda     (TB_TEMP),y         ; Calculate the address of the element
    clc                         ; which will end up in TB_ACCUM.
    adc     TB_ACCUM
    sta     TB_ACCUM
    iny
    lda     (TB_TEMP),y
    adc     TB_ACCUM+1
    sta     TB_ACCUM+1
    rts
;
TB_ARRAY_BOUNDS:
    ldx     #TB_E_SUBSCRIPT     ; Subscript is out of bounds.
    jmp     TB_ERROR
;
TB_NOT_ARRAY:
    ldx     #TB_E_NOTARRAY      ; Array is not dimensioned correctly.
    jmp     TB_ERROR
;
; "ARRAY2" opcode handler.
;
; Index into a 2-dimensional array and get the element pointer.
; TB_ACCUM is the inner array index and the outer index and array
; pointer are on AESTK.  At the end of this, TB_ACCUM will point
; to the element in the array.
;
TB_OP_ARRAY2:
    jsr     TB_POP2_AESTK       ; Pop the outer array index into TB_TEMP2.
    jsr     TB_POPB_AESTK       ; Pop the array pointer into TB_BCD.
;
    ldy     #2                  ; Check that we have a dimensioned 2D array.
    lda     (TB_BCD),y
    iny
    ora     (TB_BCD),y
    beq     TB_NOT_ARRAY
;
    lda     TB_ACCUM+1          ; Check the array bounds.
    bmi     TB_ARRAY_BOUNDS     ; Negative indexes are not allowed.
    cmp     (TB_BCD),y
    bcc     TB_OP_ARRAY2_INNER_OK
    bne     TB_ARRAY_BOUNDS
    dey
    lda     TB_ACCUM
    cmp     (TB_BCD),y
    bcs     TB_ARRAY_BOUNDS
;
TB_OP_ARRAY2_INNER_OK:
    lda     TB_TEMP2+1          ; Check the array bounds.
    bmi     TB_ARRAY_BOUNDS     ; Negative indexes are not allowed.
    dey
    cmp     (TB_BCD),y
    bcc     TB_OP_ARRAY2_OK
    bne     TB_ARRAY_BOUNDS
    dey
    lda     TB_TEMP2
    cmp     (TB_BCD),y
    bcs     TB_ARRAY_BOUNDS
;
TB_OP_ARRAY2_OK:
    ldy     #2                  ; Get the inner array dimension into TB_TEMP.
    lda     (TB_BCD),y
    sta     TB_TEMP
    iny
    lda     (TB_BCD),y
    sta     TB_TEMP+1
    jsr     TB_MUL16            ; TB_TEMP3 = TB_TEMP * TB_TEMP2.
    lda     TB_TEMP3            ; TB_TEMP3 += TB_ACCUM
    clc
    adc     TB_ACCUM
    sta     TB_TEMP3
    lda     TB_TEMP3+1
    adc     TB_ACCUM+1
    sta     TB_TEMP3+1
    asl     TB_TEMP3            ; TB_TEMP3 *= 2 for the element size.
    rol     TB_TEMP3+1
    ldy     #4
    lda     (TB_BCD),y          ; Calculate the address of the element
    clc                         ; which will end up in TB_ACCUM.
    adc     TB_TEMP3
    sta     TB_ACCUM
    iny
    lda     (TB_BCD),y
    adc     TB_TEMP3+1
    sta     TB_ACCUM+1
    rts
;
; "DIM1" opcode handler.
;
; Dimension a 1-dimensional array.  TB_ACCUM is the size and the
; top of AESTK is a pointer to the array header.
;
TB_OP_DIM1:
    jsr     TB_POPB_AESTK       ; Pop the array pointer into TB_BCD.
;
    ldy     #0
    lda     (TB_BCD),y          ; Is the array already dimensioned?
    iny
    ora     (TB_BCD),y
    bne     TB_ARRAY_REDIM
;
    lda     TB_ACCUM+1          ; Dimension may not be negative or zero.
    bmi     TB_ARRAY_INVALID_DIM
    ora     TB_ACCUM
    beq     TB_ARRAY_INVALID_DIM
;
    inc     TB_ACCUM            ; Increment for the actual dimension.
    bne     TB_OP_DIM1_1
    inc     TB_ACCUM+1
TB_OP_DIM1_1:
    lda     TB_ACCUM            ; Allocate array memory, 2 bytes per element.
    asl     a
    sta     TB_TEMP3
    lda     TB_ACCUM+1
    rol     a
    sta     TB_TEMP3+1
    jsr     TB_MALLOC
;
    ldy     #0                  ; Populate the array header.
    lda     TB_ACCUM            ; Set the first dimension.
    sta     (TB_BCD),y
    iny
    lda     TB_ACCUM+1
    sta     (TB_BCD),y
    iny
    lda     #0                  ; Set the second dimension to zero.
    sta     (TB_BCD),y
    iny
    sta     (TB_BCD),y
    iny
    lda     TB_TEMP             ; Set the base address for the array's storage.
    sta     (TB_BCD),y
    iny
    lda     TB_TEMP+1
    sta     (TB_BCD),y
    rts
;
TB_ARRAY_REDIM:
    ldx     #TB_E_REDIM         ; Attempt to redimension an array.
    jmp     TB_ERROR
;
TB_ARRAY_INVALID_DIM:
    ldx     #TB_E_INVDIM        ; Array dimension is negative or zero.
    jmp     TB_ERROR
;
; "DIM2" opcode handler.
;
; Dimension a 2-dimensional array.  TB_ACCUM is the inner size and the
; outer size and array header pointer are on AESTK.
;
TB_OP_DIM2:
    lda     TB_ACCUM            ; Get the inner array dimension; TB_DIMENSION2
    sta     TB_DIMENSION2
    lda     TB_ACCUM+1
    sta     TB_DIMENSION2+1
;
    jsr     TB_POP_AESTK        ; Get the outer array dimension; TB_DIMENSION1.
    lda     TB_TEMP
    sta     TB_DIMENSION1
    lda     TB_TEMP+1
    sta     TB_DIMENSION1+1
;
    jsr     TB_POPB_AESTK       ; Get the array header pointer into TB_BCD.
;
    ldy     #0
    lda     (TB_BCD),y          ; Is the array already dimensioned?
    iny
    ora     (TB_BCD),y
    bne     TB_ARRAY_REDIM
;
    lda     TB_DIMENSION1+1     ; Dimensions may not be negative or zero.
    bmi     TB_ARRAY_INVALID_DIM
    ora     TB_DIMENSION1
    beq     TB_ARRAY_INVALID_DIM
    lda     TB_DIMENSION2+2
    bmi     TB_ARRAY_INVALID_DIM
    ora     TB_DIMENSION2
    beq     TB_ARRAY_INVALID_DIM
;
    inc     TB_DIMENSION1       ; Increment for the actual dimensions.
    bne     TB_OP_DIM2_1
    inc     TB_DIMENSION1+1
TB_OP_DIM2_1:
    inc     TB_DIMENSION2
    bne     TB_OP_DIM2_1
    inc     TB_DIMENSION2+1
TB_OP_DIM2_2:
;
    lda     TB_DIMENSION1       ; Calculate the total memory needed.
    sta     TB_TEMP             ; TB_DIMENSION1 * TB_DIMENSION2 * 2
    lda     TB_DIMENSION1+1
    sta     TB_TEMP+1
    lda     TB_DIMENSION2
    asl     a
    sta     TB_TEMP2
    lda     TB_DIMENSION2+1
    rol     a
    sta     TB_TEMP2+1
    jsr     TB_MUL32
    lda     TB_TEMP3+3          ; Too much memory if high bytes are non-zero.
    ora     TB_TEMP3+2
    bne     TB_NO_ARRAY_MEMORY
    jsr     TB_MALLOC           ; Allocate the array memory.
;
    ldy     #0                  ; Populate the array header.
    lda     TB_DIMENSION1       ; Set the outer dimension.
    sta     (TB_BCD),y
    iny
    lda     TB_DIMENSION1+1
    sta     (TB_BCD),y
    iny
    lda     TB_DIMENSION2       ; Set the inner dimension.
    sta     (TB_BCD),y
    iny
    lda     TB_DIMENSION2+1
    sta     (TB_BCD),y
    iny
    lda     TB_TEMP             ; Set the base address for the array's storage.
    sta     (TB_TEMP2),y
    iny
    lda     TB_TEMP+1
    sta     (TB_TEMP2),y
    rts
;
TB_NO_ARRAY_MEMORY:
    ldx     #TB_E_MEMORY        ; Out of memory error.
    jmp     TB_ERROR
;
; Allocate memory after ANEXT.  The number of bytes to allocate
; is in TB_TEMP3.  Allocated pointer is returned in TB_TEMP.
; Aborts back to direct mode if out of memory.
;
TB_MALLOC:
    lda     TB_HIMEM            ; Calculate how much memory is free.
    sec
    sbc     TB_ANEXT
    sta     TB_TEMP
    lda     TB_HIMEM+1
    sbc     TB_ANEXT+1
;
    cmp     TB_TEMP3+1          ; Do we have enough memory for the request?
    bcc     TB_MALLOC_FAIL
    bne     TB_MALLOC_OK
    lda     TB_TEMP
    cmp     TB_TEMP3
    bcc     TB_MALLOC_FAIL
;
TB_MALLOC_OK:
    lda     TB_ANEXT            ; Allocate the memory.
    sta     TB_TEMP
    sta     TB_TEMP3+2
    clc
    adc     TB_TEMP3
    sta     TB_ANEXT
    lda     TB_ANEXT+1
    sta     TB_TEMP+1
    sta     TB_TEMP3+3
    adc     TB_TEMP3+1
    sta     TB_ANEXT+1
;
    lda     #0
    ldy     TB_TEMP3            ; Zero the initial array contents.
    beq     TB_MALLOC_CLEAR_LONG
;
TB_MALLOC_CLEAR_SHORT:
    dey
    sta     (TB_TEMP3+2),y
    bne     TB_MALLOC_CLEAR_SHORT
;
TB_MALLOC_CLEAR_NEXT:
    inc     TB_TEMP3+3
TB_MALLOC_CLEAR_LONG:
    ldx     TB_TEMP3+1
    beq     TB_MALLOC_DONE
TB_MALLOC_CLEAR_LONG1:
    dey
    sta     (TB_TEMP3+2),y
    bne     TB_MALLOC_CLEAR_LONG1
    dec     TB_TEMP3+1
    jmp     TB_MALLOC_CLEAR_NEXT
;
TB_MALLOC_DONE:
    rts
;
TB_MALLOC_FAIL:
    ldx     #TB_E_MEMORY
    jmp     TB_ERROR
;
; "CLEAR" opcode handler.
;
; Clears all variables and arrays but leaves the program intact.
;
TB_OP_CLEAR:
    lda     TB_ASTART           ; Reset ANEXT to just beyond the array headers.
    clc
    adc     #156
    sta     TB_ANEXT
    lda     TB_ASTART+1
    adc     #0
    sta     TB_ANEXT+1
    ldy     #52
    lda     #0
    sta     TB_INPOS            ; Reset the INPUT line position.
    sta     KEYBUF
TB_OP_CLEAR1:
    sta     TB_VARS-1,y         ; Clear the 26 plain variables.
    dey
    bne     TB_OP_CLEAR1
    tay
TB_OP_CLEAR2:
    sta     (TB_ASTART),y       ; Clear the array headers.
    iny                         ; 26 array headers, 6 bytes in each header.
    cpy     #156
    bcc     TB_OP_CLEAR2
    rts
;
;---------------------------------------------------------------------------
;
; Other opcode handlers.
;
;---------------------------------------------------------------------------
;
; "ASC" opcode handler.
;
; Get the ASCII code for the first character in a string.
;
TB_OP_ASC:
    jsr     TB_PUSH_DOWN_AESTK  ; Make room on AESTK for the ASCII value.
    jsr     TB_SKIPWS           ; Skip whitespace.
    cmp     #$22                ; Do we have a double-quote?
    bne     TB_OP_ASC_ERROR
    iny
    lda     (TB_LINEPTR),y      ; Get the first character of the string.
    cmp     #$22                ; Is the string actually empty?
    beq     TB_OP_ASC_NUL
    sta     TB_ACCUM            ; Push the value in TB_ACCUM.
    lda     #0
    sta     TB_ACCUM+1
TB_OP_ASC_FIND_END:             ; Find the end of the string.
    iny
    lda     (TB_LINEPTR),y
    beq     TB_OP_ASC_ERROR
    cmp     #$22
    bne     TB_OP_ASC_FIND_END
    iny
    sty     TB_LINEPOS          ; Record the position after the string.
    rts
TB_OP_ASC_NUL:
    iny
    sty     TB_LINEPOS
    lda     #0                  ; Return zero for empty strings.
    sta     TB_ACCUM
    sta     TB_ACCUM+1
    rts
TB_OP_ASC_ERROR:
    jmp     TB_OP_ERR
