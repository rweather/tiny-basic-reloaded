;-----------------------------------------------------------------------------
;
; This is the "corrected" IL implementation of Tiny BASIC with some
; additional corrections to fix some bugs.
;
; Original version of Tiny BASIC by Dennis Allison and others, 1975
; Fixups and commentary by Rhys Weatherley, 2026
;
; https://archive.org/details/dr_dobbs_journal_vol_01
;
;-----------------------------------------------------------------------------
;
; Language grammar:
;
; line ::= number statement <CR> | statement <CR>
; statement ::=
;       "PRINT" expr-list
;     | "IF" expression relop expression THEN statement
;     | "GOTO" expression
;     | "INPUT" var-list
;     | "LET" var "=" expression
;     | "GOSUB" expression
;     | "RETURN"
;     | "CLEAR"         ; Equivalent to "NEW" in other BASIC's
;     | "LIST"
;     | "RUN"
;     | "END"
; expr-list ::= (string | expression) ("," (string | expression))*
; var-list ::= var ("," var)*
; expression ::= ["+" | "-"] term (("+" | "-") term)*
; term ::= factor (("*" | "/") factor)*
; factor ::= var | number | "(" expression ")"
; var ::= "A" | "B" | "C" | ... | "Y" | "Z"
; number ::= digit digit*
; digit ::= "0" | "1" | "2" | ... | "8" | "9"
; relop ::= "<" | "<=" | "<>" | ">" | ">=" | "><" | "="
; string ::= '"' (any character except " or <CR>)* '"'
;
;-----------------------------------------------------------------------------
;
; Statement executor written in IL (Interpretive Language)
;
; Control Section
;
START:      INIT                ; Initialize
ERRENT:     NLINE               ; Write a CR-LF
C0:         GETLN               ; Write prompt and get a line
            TSTL    XEC         ; If no line number, go execute it
            INSRT               ; Insert or delete the line
            JMP     C0          ; Loop for another line
XEC:        XINIT               ; Initialize for execution
;
;
; Statement Executor
;
STMT:       TST     S1 'LET'    ; Check for 'LET'
SE1:        TSTV    SE1         ; Error if no variable!
SE2:        TST     SE2 '='     ; Error if no "="
            CALL    EXPR        ; Put expression on AESTK
            DONE                ; Check for CR line terminator
            STORE               ; Put value of expression in its cell
            NXT                 ; Continue next line
;
;
S1:         TST     S3 'GO'     ; Check for 'GO'
            TST     S2 'TO'     ; Check for 'GOTO'
            CALL    EXPR        ; Get the label
            DONE                ; Check for CR line terminator
            XFER                ; Do a 'GOTO' to the label
;
;
S2:         TST     S2 'SUB'    ; Check for 'GOSUB', failure is an error!
            CALL    EXPR        ; Put expression on AESTK
            DONE                ; Check for CR line terminator
            SAV                 ; Save next line number in BASIC text
            XFER                ; Do a 'GOSUB' to the label
;
;
S3:         TST     S8 'PRINT'  ; Check for 'PRINT'
S4:         TST     S7 '"'      ; Check for " to begin a string
            PRS                 ; Print the data enclosed in quotes
S5:         TST     S6 ','      ; ',' means more to come
            SPC                 ; Space to next zone
            HOP     S4          ; Go back for more
S6:         DONE                ; Check for CR line terminator
            NLINE               ; Write a CR-LF
            NXT                 ; Continue next line
S7:         CALL    EXPR        ; Get the numeric value to print
            PRN                 ; Print the number
            HOP     S5          ; Go back for more
;
;
S8:         TST     S9 'IF'     ; Check for 'IF'
            CALL    EXPR        ; Get the first expression
            CALL    RELOP       ; Get the relational operator
            CALL    EXPR        ; Get the second expression
S8A:        TST     S8A 'THEN'  ; Check for 'THEN'
            CMPR                ; If not true continue next line
            JMP     STMT        ; If true process the rest of this line
;
;
S9:         TST     S12 'INPUT' ; Check for 'INPUT'
S10:        TSTV    S10         ; Get the variable's index
            INNUM               ; Get the number from the teletype
            STORE               ; Put the value of the variable in its cell
            TST     S11 ','     ; ',' means more data
            JMP     S10
S11:        DONE                ; Check for CR line terminator
            NXT                 ; Continue next line
;
;
S12:        TST     S13 'RETURN' ; Check for 'RETURN'
            DONE                ; Check for CR line terminator
            RSTR                ; Return to caller
;
;
S13:        TST     S14 'END'   ; Check for 'END'
            FIN                 ; Go back to control mode
;
;
S14:        TST     S15 'LIST'  ; Check for 'LIST'
            DONE                ; Check for CR line terminator
            LST                 ; Type out the BASIC program
            NXT                 ; Continue next line
;
;
S15:        TST     S16 'RUN'   ; Check for 'RUN'
            DONE                ; Check for CR line terminator
            RNXT                ; Select the first program line and execute it
;
;
S16:        TST     S16 'CLEAR' ; Check for 'CLEAR'
            JMP     START       ; Reinitialize everything!
;
; ***
;
; Interpretive language subroutines
;
EXPR:       CHKSTK              ; Check for deep recursion
            TST     E0 '-'      ; Test for unary '-'
            CALL    TERM        ; Put term on AESTK
            NEG                 ; Negate value on AESTK
            HOP     E1          ; Go get a term
;
E0:         TST     E01 '+'     ; Test for unary '+'
E01:        CALL    TERM        ; Put term on AESTK
E1:         TST     E2 '+'      ; Test for addition
            CALL    TERM        ; Get second term
            ADD                 ; Put sum of terms on AESTK
            HOP     E1          ; Loop around for more
;
E2:         TST     E3 '-'      ; Test for subtraction
            CALL    TERM        ; Get second term
            SUB                 ; Put difference of terms on AESTK
            HOP     E1          ; Loop around for more
;
E3:         RTN                 ; This can be recursive
;
;
;
TERM:       CALL    FACT        ; Get one factor
T0:         TST     T1 '*'      ; Test for multiplication
            CALL    FACT        ; Get a factor
            MPY                 ; Put the product on AESTK
            HOP     T0          ; Loop around for more
;
T1:         TST     T2 '/'      ; Test for division
            CALL    FACT        ; Get a factor
            DIV                 ; Put quotient on AESTK
            HOP     T0          ; Loop around for more
;
T2:         RTN                 ; Return to caller
;
;
;
FACT:       TSTV    F0          ; Test for variable
            IND                 ; Load the variable's value onto the stack
            RTN
F0:         TSTN    F1          ; Test for number
            RTN
F1:         TST     F1 '('      ; Error if its not a '('
            CALL    EXPR        ; This is a recursive process
;
FE1:        TST     FE1 ')'     ; Every '(' has to have a ')'
            RTN
;
; RELOP parses the relational operator that follows and returns
; one of the following comparison values depending on the operator:
;
;   0       Equal
;   1       Less than
;   2       Less than or equal
;   3       Not equal
;   4       Greater than
;   5       Greater than or equal
;
RELOP:      TST     R0 '='      ; Check for '='
            LIT     0
            RTN
;
R0:         TST     R4 '<'      ; Check for '<'
            TST     R1 '='      ; Check for '<='
            LIT     2
            RTN
;
R1:         TST     R3 '>'      ; Check for '<>'
            LIT     3
            RTN
;
R3:         LIT     1
            RTN
;
R4:         TST     R4 '>'      ; Check for '>'
            TST     R5 '='      ; Check for '>='
            LIT     5
            RTN
;
R5:         TST     R6 '<'      ; Check for '><'
            LIT     3
            RTN
;
R6:         LIT     4
            RTN
