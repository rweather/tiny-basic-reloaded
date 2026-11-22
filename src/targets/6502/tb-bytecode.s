; Automatically generated; do not edit.

TB_IL_START:
    jsr     TB_OP_INIT
TB_IL_ERRENT:
    jsr     TB_OP_NLINE
TB_IL_C0:
    jsr     TB_OP_GETLN
    jsr     TB_OP_TSTCR
    bne     TB_IL_C1
    jmp     TB_IL_C0
TB_IL_C1:
    jsr     TB_OP_TSTL
    bne     TB_IL_XEC
    jsr     TB_OP_INSRT
    jmp     TB_IL_C0
TB_IL_XEC:
    jsr     TB_OP_XINIT
TB_IL_LET:
    jsr     TB_OP_TSTA
    bne     TB_IL_LET1
    jsr     TB_IL_ARRAY
    jmp     TB_IL_LET2
TB_IL_LET1:
    jsr     TB_OP_TSTV
    bne     TB_IL_LET3
TB_IL_LET2:
    lda     #61
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
    jsr     TB_OP_STORE
    jmp     TB_OP_END
TB_IL_LET3:
    ldx     #0
    jsr     TB_OP_TST
    bne     TB_IL_STMT
    jsr     TB_IL_VARRAY
    jmp     TB_IL_LET2
TB_IL_STMT:
    ldx     #3
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_GOTO
    ldx     #7
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_GOSUB
    ldx     #12
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_IF
    ldx     #14
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_FOR
    ldx     #17
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_NEXT
    ldx     #21
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_PRINT
    ldx     #26
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_INPUT
    ldx     #31
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_RETURN
    ldx     #37
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_POKE
    ldx     #41
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_CALL
    ldx     #45
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_REM
    ldx     #48
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_POP
    ldx     #51
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_END
    ldx     #54
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_DIM
    ldx     #57
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_LIST
    ldx     #61
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_RUN
    ldx     #64
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_CLR
    ldx     #67
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_NEW
    ldx     #70
    jsr     TB_OP_TST
    bne     *+5
    jmp     TB_IL_SIZE
    lda     #63
    jsr     TB_OP_TST1
    bne     *+5
    jmp     TB_IL_PRINT
    jmp     TB_OP_ERR
TB_IL_IF:
    jsr     TB_IL_EXPR
    ldx     #3
    jsr     TB_OP_TST
    beq     TB_IL_IF3
TB_IL_IF1:
    ldx     #74
    jsr     TB_OP_TST_SYNTAX
    jsr     TB_OP_IF
    jsr     TB_OP_TSTN
    bne     TB_IL_IF2
    jsr     TB_OP_DONE
    jmp     TB_OP_XFER
TB_IL_IF2:
    jmp     TB_IL_XEC
TB_IL_IF3:
    jsr     TB_OP_IF
TB_IL_GOTO:
    jsr     TB_IL_EXPR
    jsr     TB_OP_DONE
    jmp     TB_OP_XFER
TB_IL_GOSUB:
    jsr     TB_IL_EXPR
    jsr     TB_OP_DONE
    jsr     TB_OP_SAV
    jmp     TB_OP_XFER
TB_IL_RETURN:
    jsr     TB_OP_DONE
    jmp     TB_OP_RSTR
TB_IL_POKE:
    jsr     TB_IL_EXPR
TB_IL_POKE1:
    lda     #44
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
    jsr     TB_OP_POKE
    jmp     TB_OP_END
TB_IL_CALL:
    jsr     TB_IL_EXPR
    jsr     TB_OP_MCALL
    jmp     TB_OP_END
TB_IL_REM:
    jmp     TB_OP_NXT
TB_IL_POP:
    jsr     TB_OP_POP
    jmp     TB_OP_END
TB_IL_FOR:
    jsr     TB_OP_TSTV_SYNTAX
TB_IL_FOR1:
    lda     #61
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
    jsr     TB_OP_STOREV
TB_IL_FOR2:
    ldx     #78
    jsr     TB_OP_TST_SYNTAX
    jsr     TB_IL_EXPR
    ldx     #80
    jsr     TB_OP_TST
    bne     TB_IL_FOR3
    jsr     TB_IL_EXPR
    jmp     TB_IL_FOR4
TB_IL_FOR3:
    lda     #1
    ldy     #0
    jsr     TB_PUSH_LITERAL
TB_IL_FOR4:
    jsr     TB_OP_DONE
    jsr     TB_OP_FOR
    jmp     TB_OP_NXT
TB_IL_NEXT:
    jsr     TB_OP_TSTEND
    bne     TB_IL_NEXT1
    lda     #0
    ldy     #0
    jsr     TB_PUSH_LITERAL
    jmp     TB_IL_NEXT2
TB_IL_NEXT1:
    jsr     TB_OP_TSTV_SYNTAX
TB_IL_NEXT2:
    jsr     TB_OP_DONE
    jsr     TB_OP_NEXT
TB_IL_PRINT:
    jsr     TB_OP_TSTEND
    bne     TB_IL_PRINT0
    jmp     TB_IL_PRINT3
TB_IL_PRINT0:
    lda     #34
    jsr     TB_OP_TST1
    bne     TB_IL_PRINT4
    jsr     TB_OP_PRS
TB_IL_PRINT1:
    lda     #59
    jsr     TB_OP_TST1
    beq     TB_IL_PRINT2
    lda     #44
    jsr     TB_OP_TST1
    bne     TB_IL_PRINT3
    jsr     TB_OP_SPC
TB_IL_PRINT2:
    jsr     TB_OP_TSTEND
    bne     TB_IL_PRINT0
    jmp     TB_OP_END
TB_IL_PRINT3:
    jsr     TB_OP_NLINE
    jmp     TB_OP_END
TB_IL_PRINT4:
    ldx     #84
    jsr     TB_OP_TST
    bne     TB_IL_PRINT7
TB_IL_PRINT5:
    jsr     TB_IL_BEXPR
    jsr     TB_OP_PRC
    jmp     TB_IL_PRINT1
TB_IL_PRINT7:
    ldx     #88
    jsr     TB_OP_TST
    bne     TB_IL_PRINT8
    jsr     TB_IL_BEXPR
    jsr     TB_OP_TAB
    jmp     TB_IL_PRINT1
TB_IL_PRINT8:
    jsr     TB_IL_EXPR
    jsr     TB_OP_PRN
    jmp     TB_IL_PRINT1
TB_IL_INPUT:
    lda     #34
    jsr     TB_OP_TST1
    bne     TB_IL_INPUT2
    jsr     TB_OP_PRS
TB_IL_INPUT1:
    lda     #59
    jsr     TB_OP_TST1_SYNTAX
TB_IL_INPUT2:
    jsr     TB_IL_VARRAY
    jsr     TB_OP_INNUM
    jsr     TB_OP_STORE
    lda     #44
    jsr     TB_OP_TST1
    bne     TB_IL_INPUT3
    jmp     TB_IL_INPUT2
TB_IL_INPUT3:
    jmp     TB_OP_END
TB_IL_END:
    jsr     TB_OP_NLINE
    jmp     TB_OP_FIN
TB_IL_DIM:
    jsr     TB_OP_TSTA_SYNTAX
TB_IL_DIM1:
    lda     #40
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
    lda     #44
    jsr     TB_OP_TST1
    bne     TB_IL_DIM4
    jsr     TB_IL_EXPR
TB_IL_DIM2:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_OP_DIM2
TB_IL_DIM3:
    lda     #44
    jsr     TB_OP_TST1
    bne     TB_IL_INPUT3
    jmp     TB_IL_DIM
TB_IL_DIM4:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_OP_DIM1
    jmp     TB_IL_DIM3
TB_IL_LIST:
    jsr     TB_OP_TSTCR
    bne     TB_IL_LIST1
    jsr     TB_OP_LIST0
    jmp     TB_IL_LIST7
TB_IL_LIST1:
    lda     #45
    jsr     TB_OP_TST1
    bne     TB_IL_LIST3
    lda     #1
    ldy     #0
    jsr     TB_PUSH_LITERAL
TB_IL_LIST2:
    jsr     TB_OP_TSTN_SYNTAX
    jsr     TB_OP_LIST2
    jmp     TB_IL_LIST7
TB_IL_LIST3:
    jsr     TB_OP_TSTN_SYNTAX
    lda     #44
    jsr     TB_OP_TST1
    beq     TB_IL_LIST4
    lda     #45
    jsr     TB_OP_TST1
    bne     TB_IL_LIST6
TB_IL_LIST4:
    jsr     TB_OP_TSTN
    bne     TB_IL_LIST5
    jsr     TB_OP_LIST2
    jmp     TB_IL_LIST7
TB_IL_LIST5:
    lda     #255
    ldy     #124
    jsr     TB_PUSH_LITERAL
    jsr     TB_OP_LIST2
    jmp     TB_IL_LIST7
TB_IL_LIST6:
    jsr     TB_OP_LIST1
TB_IL_LIST7:
    jsr     TB_OP_LST
    jmp     TB_OP_END
TB_IL_RUN:
    jsr     TB_OP_DONE
    jmp     TB_OP_RNXT
TB_IL_CLR:
    jsr     TB_OP_CLEAR
    jmp     TB_OP_END
TB_IL_NEW:
    jsr     TB_OP_DONE
    jmp     TB_IL_START
TB_IL_SIZE:
    jsr     TB_OP_SIZE
    jmp     TB_OP_END
TB_IL_VARRAY:
    jsr     TB_OP_TSTA
    bne     TB_IL_V0
    jmp     TB_IL_ARRAY
TB_IL_V0:
    jsr     TB_OP_TSTV_SYNTAX
    rts
TB_IL_ARRAY:
    lda     #40
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
    lda     #44
    jsr     TB_OP_TST1
    bne     TB_IL_X0
    jsr     TB_IL_EXPR
TB_IL_X1:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    jmp     TB_OP_ARRAY2
TB_IL_X0:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    jmp     TB_OP_ARRAY1
TB_IL_EXPR:
    jsr     TB_OP_CHKSTK
    jsr     TB_IL_AEXPR
TB_IL_EXPR1:
    ldx     #91
    jsr     TB_OP_TST
    bne     TB_IL_EXPR2
    jsr     TB_IL_AEXPR
    jsr     TB_OP_LOR
    jmp     TB_IL_EXPR1
TB_IL_EXPR2:
    rts
TB_IL_AEXPR:
    ldx     #93
    jsr     TB_OP_TST
    beq     TB_IL_AEXPR1
    jsr     TB_IL_REXPR
    jmp     TB_IL_AEXPR2
TB_IL_AEXPR1:
    jsr     TB_IL_REXPR
    jsr     TB_OP_LNOT
TB_IL_AEXPR2:
    ldx     #96
    jsr     TB_OP_TST
    bne     TB_IL_EXPR2
    ldx     #93
    jsr     TB_OP_TST
    beq     TB_IL_AEXPR4
    jsr     TB_IL_REXPR
TB_IL_AEXPR3:
    jsr     TB_OP_LAND
    jmp     TB_IL_AEXPR2
TB_IL_AEXPR4:
    jsr     TB_IL_REXPR
    jsr     TB_OP_LNOT
    jmp     TB_IL_AEXPR3
TB_IL_REXPR:
    jsr     TB_IL_ASEXPR
    ldx     #99
    ldy     #0
    jsr     TB_OP_TSTOP
    beq     TB_IL_REXPR1
    ldx     #101
    ldy     #2
    jsr     TB_OP_TSTOP
    beq     TB_IL_REXPR1
    ldx     #103
    ldy     #4
    jsr     TB_OP_TSTOP
    beq     TB_IL_REXPR1
    ldx     #105
    ldy     #6
    jsr     TB_OP_TSTOP
    beq     TB_IL_REXPR1
    ldx     #107
    ldy     #8
    jsr     TB_OP_TSTOP
    beq     TB_IL_REXPR1
    ldx     #109
    ldy     #10
    jsr     TB_OP_TSTOP
    beq     TB_IL_REXPR1
    rts
TB_IL_REXPR1:
    jsr     TB_IL_ASEXPR
    jmp     TB_OP_APPLY
TB_IL_ASEXPR:
    jsr     TB_IL_MEXPR
TB_IL_ASEXPR1:
    ldx     #111
    ldy     #12
    jsr     TB_OP_TSTOP
    beq     TB_IL_ASEXPR2
    ldx     #113
    ldy     #14
    jsr     TB_OP_TSTOP
    beq     TB_IL_ASEXPR2
    ldx     #115
    ldy     #16
    jsr     TB_OP_TSTOP
    beq     TB_IL_ASEXPR2
    ldx     #118
    ldy     #18
    jsr     TB_OP_TSTOP
    beq     TB_IL_ASEXPR2
    rts
TB_IL_ASEXPR2:
    jsr     TB_IL_MEXPR
    jsr     TB_OP_APPLY
    jmp     TB_IL_ASEXPR1
TB_IL_MEXPR:
    jsr     TB_IL_UEXPR
TB_IL_MEXPR1:
    ldx     #121
    ldy     #20
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    ldx     #123
    ldy     #22
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    ldx     #125
    ldy     #24
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    ldx     #128
    ldy     #26
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    ldx     #131
    ldy     #28
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    ldx     #134
    ldy     #30
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    ldx     #137
    ldy     #32
    jsr     TB_OP_TSTOP
    beq     TB_IL_MEXPR2
    rts
TB_IL_MEXPR2:
    jsr     TB_IL_UEXPR
    jsr     TB_OP_APPLY
    jmp     TB_IL_MEXPR1
TB_IL_UEXPR:
    lda     #43
    jsr     TB_OP_TST1
    beq     TB_IL_SEXPR
    lda     #45
    jsr     TB_OP_TST1
    beq     TB_IL_UEXPR1
    ldx     #141
    jsr     TB_OP_TST
    bne     TB_IL_SEXPR
    jsr     TB_IL_SEXPR
    jmp     TB_OP_BNOT
TB_IL_UEXPR1:
    jsr     TB_IL_SEXPR
    jmp     TB_OP_NEG
TB_IL_SEXPR:
    jsr     TB_OP_TSTA
    bne     TB_IL_SEXPR1
    jsr     TB_IL_ARRAY
    jmp     TB_OP_IND
TB_IL_SEXPR1:
    jsr     TB_OP_TSTV
    bne     TB_IL_SEXPR2
    jmp     TB_OP_IND
TB_IL_SEXPR2:
    jsr     TB_OP_TSTN
    bne     TB_IL_SEXPR4
    rts
TB_IL_SEXPR3:
    jsr     TB_IL_BEXPR
    jmp     TB_OP_APPLYFN
TB_IL_ASC:
    lda     #40
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_OP_ASC
TB_IL_ASC1:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    rts
TB_IL_INKEY:
    lda     #40
    jsr     TB_OP_TST1
    beq     TB_IL_INKEY1
    lda     #0
    ldy     #0
    jsr     TB_PUSH_LITERAL
    jmp     TB_OP_INKEY
TB_IL_INKEY1:
    jsr     TB_IL_BEXPR1
    jmp     TB_OP_INKEY
TB_IL_SEXPR4:
    ldx     #145
    jsr     TB_OP_TST
    beq     TB_IL_ASC
    ldx     #148
    jsr     TB_OP_TST
    beq     TB_IL_INKEY
    ldx     #153
    jsr     TB_OP_TST
    beq     TB_IL_FPMUL
    ldx     #158
    ldy     #34
    jsr     TB_OP_TSTOP
    beq     TB_IL_SEXPR3
    ldx     #161
    ldy     #36
    jsr     TB_OP_TSTOP
    beq     TB_IL_SEXPR3
    ldx     #165
    ldy     #38
    jsr     TB_OP_TSTOP
    beq     TB_IL_SEXPR3
TB_IL_BEXPR:
    lda     #40
    jsr     TB_OP_TST1_SYNTAX
TB_IL_BEXPR1:
    jsr     TB_IL_EXPR
TB_IL_BEXPR2:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    rts
TB_IL_FPMUL:
    lda     #40
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
TB_IL_FPMUL1:
    lda     #44
    jsr     TB_OP_TST1_SYNTAX
    jsr     TB_IL_EXPR
TB_IL_FPMUL2:
    lda     #44
    jsr     TB_OP_TST1_SYNTAX
TB_IL_FPMUL3:
    jsr     TB_OP_TSTB_SYNTAX
TB_IL_FPMUL4:
    lda     #41
    jsr     TB_OP_TST1_SYNTAX
    jmp     TB_OP_FPMUL
TB_TOKTAB:
    .db     "LE", $D4
    .db     "GOT", $CF
    .db     "GOSU", $C2
    .db     "I", $C6
    .db     "FO", $D2
    .db     "NEX", $D4
    .db     "PRIN", $D4
    .db     "INPU", $D4
    .db     "RETUR", $CE
    .db     "POK", $C5
    .db     "CAL", $CC
    .db     "RE", $CD
    .db     "PO", $D0
    .db     "EN", $C4
    .db     "DI", $CD
    .db     "LIS", $D4
    .db     "RU", $CE
    .db     "CL", $D2
    .db     "NE", $D7
    .db     "SIZ", $C5
    .db     "THE", $CE
    .db     "T", $CF
    .db     "STE", $D0
    .db     "CHR", $A4
    .db     "SP", $C3
    .db     "O", $D2
    .db     "NO", $D4
    .db     "AN", $C4
    .db     "=", 0
    .db     "<", $BD
    .db     "<", $BE
    .db     ">", $BD
    .db     "<", 0
    .db     ">", 0
    .db     "+", 0
    .db     "-", 0
    .db     "BO", $D2
    .db     "XO", $D2
    .db     "*", 0
    .db     "/", 0
    .db     "MO", $C4
    .db     "SH", $CC
    .db     "SH", $D2
    .db     "LS", $D2
    .db     "BAN", $C4
    .db     "BNO", $D4
    .db     "AS", $C3
    .db     "INKE", $D9
    .db     "FPMU", $CC
    .db     "RN", $C4
    .db     "PEE", $CB
    .db     "AB", $D3
TB_TOKHAND:
    .dw     TB_OP_CMPEQ_APPLY
    .dw     TB_OP_CMPLE_APPLY
    .dw     TB_OP_CMPNE_APPLY
    .dw     TB_OP_CMPGE_APPLY
    .dw     TB_OP_CMPLT_APPLY
    .dw     TB_OP_CMPGT_APPLY
    .dw     TB_OP_ADD_APPLY
    .dw     TB_OP_SUB_APPLY
    .dw     TB_OP_BOR_APPLY
    .dw     TB_OP_BXOR_APPLY
    .dw     TB_OP_MPY_APPLY
    .dw     TB_OP_DIV_APPLY
    .dw     TB_OP_MOD_APPLY
    .dw     TB_OP_SHL_APPLY
    .dw     TB_OP_SHR_APPLY
    .dw     TB_OP_LSR_APPLY
    .dw     TB_OP_BAND_APPLY
    .dw     TB_OP_RANDOM_APPLY
    .dw     TB_OP_PEEK_APPLY
    .dw     TB_OP_ABS_APPLY
