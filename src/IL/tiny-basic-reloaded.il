;-----------------------------------------------------------------------------
;
; This is the IL implementation of "Tiny BASIC Reloaded", which is
; forked off "Tiny BASIC Extended" / TBX from the February 1976 issue of
; Doctor Dobb's Journal.
;
; The language here is richer than TBX and closer to regular BASIC.
;
; Original version of TBX by Dick Whipple and John Arnold, 1976
; Tiny BASIC Reloaded fork by Rhys Weatherley, 2026
;
; https://archive.org/details/dr_dobbs_journal_vol_01
;
;-----------------------------------------------------------------------------
;
; Language grammar:
;
; line ::= number statement-list <CR> | statement-list <CR>
; statement-list ::= statement (":" statement)*
; statement ::=
;       ["LET"] array-var "=" expression
;     | "CALL" expression
;     | "CLR"
;     | "DIM" array-var-list
;     | "END"
;     | "FOR" var "=" expression "TO" expression ["STEP" expression]
;     | "GOSUB" expression
;     | "GOTO" expression
;     | "IF" expression "THEN" statement-list
;     | "IF" expression "GOTO" expression
;     | "INPUT" [string ';'] array-var-list
;     | "LIST" [list-range]
;     | "LOAD"
;     | "NEXT" [var]
;     | "POKE" expression "," expression
;     | "POP"
;     | "PRINT" [print-list] ["," | ";"]
;     | "?" print-list          ; Alias for 'PRINT'
;     | "REM" (any character except <CR>)* <CR>
;     | "RETURN"
;     | "RUN" [number]
;     | "SAVE"
;     | "SIZE"
;
; print-list ::= print-expression (("," | ";") print-expression)*
; print-expression ::=
;       string
;     | expression
;     | "CHR$" "(" expression ")"
;     | "SPC" "(" expression ")"
;
; expression ::= and-expression ("OR" and-expression)*
; and-expression ::=
;       ["NOT"] relational-expression ("AND" ["NOT"] relational-expression)*
; relational-expression ::= arithmetic-expression relop arithmetic-expression
; arithmetic-expression ::=
;       mul-expression (("+" | "-" | "XOR" | "BOR") mul-expression)*
; mul-expression ::= unary-expression (mulop unary-expression)*
; unary-expression ::= ["+" | "-" | "BNOT"] simple-expression
; simple-expression ::=
;       var
;     | array-var
;     | number
;     | "(" expression ")"
;     | ASC "(" string ")"
;     | RND "(" expression ")"
;     | PEEK "(" expression ")"
;     | INKEY
; relop ::= "<" | "<=" | "<>" | ">" | ">=" | "><" | "="
; mulop ::= "*" | "/" | "MOD" | "SHL" | "SHR" | "LSR" | "BAND"
;
; var-list ::= var ("," var)*
; var ::= var-name | array-var
; var-name ::= "A" | "B" | "C" | ... | "Y" | "Z"
;
; array-var-list ::= array-var ("," array-var)*
; array-var ::=
;       var-name "(" expression ")"
;     | var-name "(" expression "," expression ")"
;
; list-range ::= number | number "-" | number "-" number | "-" number
;
; number ::= digit digit*
; digit ::= "0" | "1" | "2" | ... | "8" | "9"
; string ::= '"' (any character except " or <CR>)* '"'
;
;-----------------------------------------------------------------------------
;
; Main command-line loop.
;
START:      INIT                ; Initialize, clear program from mmemory
ERRENT:     NLINE               ; Write a CR-LF
C0:         GETLN               ; Write prompt and get a line
            TSTCR   C1          ; Is the line completely empty?
            JMP     C0          ; Ignore the line if it is empty
C1:         TSTL    XEC         ; If no line number, go execute the line
            INSRT               ; Insert into the program or delete the line
            JMP     C0          ; Go back for another line
;
;-----------------------------------------------------------------------------
;
; Statement execution.
;
XEC:        XINIT               ; Initialize AESTK for statement execution
;
; Assignment statements: "var = value" and "LET var = value"
;
LET:        TSTA    LET1        ; Do we have a "X(" array reference?
            CALL    ARRAY       ; Find the array element to assign
            JMP     LET2        ; Parse the rest of the 'LET' statement
LET1:       TSTV    LET3        ; Check for plain variables
LET2:       TST     LET2 '='    ; Variable must be followed by '='
            CALL    EXPR        ; Then an expression
            STORE               ; Store the value
            END                 ; End of statement
LET3:       TST     STMT 'LET'  ; Test for the 'LET keyword
            CALL    VARRAY      ; Expect an array reference or plain variable
            JMP     LET2        ; Parse the rest of the 'LET' statement
;
; Dispatch the statements of the language (other than "LET").
;
; Sort this list in rough order from most common to least common statements.
;
STMT:       TSTJ    GOTO 'GOTO'
            TSTJ    GOSUB 'GOSUB'
            TSTJ    IF 'IF'
            TSTJ    FOR 'FOR'
            TSTJ    NEXT 'NEXT'
            TSTJ    PRINT 'PRINT'
            TSTJ    INPUT 'INPUT'
            TSTJ    RETURN 'RETURN'
            TSTJ    POKE 'POKE'
            TSTJ    CALL 'CALL'
            TSTJ    REM 'REM'
            TSTJ    POP 'POP'
            TSTJ    END 'END'
            TSTJ    DIM 'DIM'
            TSTJ    LIST 'LIST'
            TSTJ    RUN 'RUN'
            TSTJ    CLR 'CLR'
            TSTJ    NEW 'NEW'
            TSTJ    SIZE 'SIZE'
            TSTJ    LOAD 'LOAD'
            TSTJ    SAVE 'SAVE'
            TSTJ    PRINT '?'   ; Alias for 'PRINT'
;
; If we get here, the statement is not part of the standard language.
; Dispatch any custom commands that have been added to the interpreter.
; If there are no custom commands, this will report a syntax error.
;
            CUSTOM
;
; IF statement.
;
IF:         CALL    EXPR        ; Parse and evaluate the boolean condition
            TSTJ    IF2 'GOTO'  ; Check for 'GOTO' after the condition
IF1:        TST     IF1 'THEN'  ; If not 'GOTO', must be 'THEN'
            IF                  ; If expression is false, go to the next line
            JMP     XEC         ; Execute the rest of the line for 'THEN'
IF2:        IF                  ; If expression is false, go to the next line
            ; Fall through to the 'GOTO' handler.
;
; GOTO statement.
;
GOTO:       CALL    EXPR        ; Get the line number to jump to
            DONE                ; Check for end of statement
            XFER                ; Transfer execution to the line number
;
; GOSUB statement.
;
GOSUB:      CALL    EXPR        ; Get the line number to jump to
            DONE                ; Check for end of statement
            SAV                 ; Save the next address in the program
            XFER                ; Transfer execution to the line number
;
; RETURN statement.
;
RETURN:     DONE                ; Check for the end of the statement
            RSTR                ; Restore return address from SUBSTK
;
; POKE statement.
;
POKE:       CALL    EXPR        ; Get the address to POKE into
POKE1:      TST     POKE1 ','   ; Must be followed by a comma
            CALL    EXPR        ; Get the value to POKE
            POKE                ; Do the POKE
            END                 ; End of statement
;
; CALL statement.
;
CALL:       CALL    EXPR        ; Get the address to CALL
            MCALL               ; Perform the machine-language CALL
            END                 ; End of statement
;
; REM statement.
;
REM:        NXT                 ; Just go to the next line
;
; POP statement.
;
POP:        POP                 ; Pop the top-most RETURN address from SUBSTK
            END                 ; End of statement
;
; FOR statement.
;
FOR:        TSTV    FOR         ; Get the name of the loop variable
FOR1:       TST     FOR1 '='    ; Loop variable must be followed by '='
            CALL    EXPR        ; Get the starting value for the loop
            STOREV              ; Store to the variable, but don't pop the var
FOR2:       TST     FOR2 'TO'   ; Check for 'TO'
            CALL    EXPR        ; Get the ending value for the loop
            TST     FOR3 'STEP' ; Do we have a step value?
            CALL    EXPR        ; Get the step value for the loop
            JMP     FOR4        ; Ready to go with from, to, and step values
FOR3:       LIT     1           ; Push the default STEP of 1
FOR4:       DONE                ; Check for end of statement
            FOR                 ; Push a FOR loop context onto SUBSTK
            NXT                 ; Continue with the next statement
;
; NEXT statement.
;
NEXT:       TSTEND  NEXT1       ; Do we have a loop variable?
            LIT     0           ; If not, push 0 as the variable identifier
            JMP     NEXT2
NEXT1:      TSTV    NEXT1       ; Get the name of the for loop variable
NEXT2:      DONE                ; Check for end of statement
            NEXT                ; Perform the NEXT operation
;
; PRINT statement.
;
PRINT:      TSTEND  PRINT0      ; Is it just "PRINT" on its own?
            JMP     PRINT3      ; If yes, write a CR-LF and end the statement
PRINT0:     TST     PRINT4 '"'  ; Do we have a string?
            PRS                 ; Print characters up to the next "
PRINT1:     TSTJ    PRINT2 ';'  ; Is the field followed by ';'?
            TST     PRINT3 ','  ; Is the field followed by ','?
            SPC                 ; Space across to the next zone
PRINT2:     TSTEND  PRINT0      ; Go back for more if not at end of statement
            END                 ; Print ended in ';' or ',', nothing more to do
PRINT3:     NLINE               ; At the end of the PRINT with no ';'
            END                 ; End of statement
PRINT4:     TST     PRINT7 'CHR$' ; Is this a literal character print?
PRINT5:     CALL    BEXPR       ; Get the character expression
            PRC                 ; Print the character
            JMP     PRINT1      ; Check for ';' or ',' after CHR$
PRINT7:     TST     PRINT8 'SPC'; SPC prints a number of spaces
            CALL    BEXPR       ; Get the number of spaces
            TAB                 ; Print the spaces
            JMP     PRINT1      ; Check for ';' or ',' after the spaces
PRINT8:     CALL    EXPR        ; Must be a numeric expression if we get here
            PRN                 ; Print the number
            JMP     PRINT1      ; Check for ';' or ',' after the number
;
; INPUT statement.
;
INPUT:      TST     INPUT2 '"'  ; Is there a prompt string?
            PRS                 ; Yes, so print it
INPUT1:     TST     INPUT1 ';'  ; Prompt must be followed by ';'
INPUT2:     CALL    VARRAY      ; Get the variable to input into
            INNUM               ; Input a number
            STORE               ; Store the number to the variable
            TST     INPUT3 ','  ; Comma means there are more input variables
            JMP     INPUT2      ; Back around for more
INPUT3:     END                 ; End of statement
;
; END statement.
;
END:        NLINE               ; Write a CR-LF
            FIN                 ; Exit back to direct mode
;
; DIM statement.
;
DIM:        TSTA    DIM         ; Get the next variable to dimension
DIM1:       TST     DIM1 '('    ; Opening bracket after the array name
            CALL    EXPR        ; Get the outer dimension
            TST     DIM4 ','    ; Do we have an inner dimension?
            CALL    EXPR        ; Get the inner dimension
DIM2:       TST     DIM2 ')'    ; Closing bracket after the two dimensions
            DIM2                ; Dimension the 2D array
DIM3:       TST     INPUT3 ','  ; More arrays to dimension after the comma
            JMP     DIM         ; Go back for more
DIM4:       TST     DIM4 ')'    ; Closing bracket after the single dimension
            DIM1                ; Dimension the 1D array
            JMP     DIM3        ; Are there more arrays to dimension?
;
; LIST statement.
;
LIST:       TSTCR LIST1         ; Is it just 'LIST' on its own?
            LIST0               ; List the entire program
            JMP LIST6
LIST1:      TST LIST3 "-"       ; Is it "LIST -n"?
            LIT 1               ; List from line 1 to "n"
LIST2:      TSTN LIST2
            LIST2
            JMP LIST6
LIST3:      TSTN LIST3          ; Is it "LIST n" or "LIST n-" or "LIST n-m"?
            TST LIST5 "-"
            TSTN LIST4          ; Is it "LIST n-?" or "LIST n-m"?
            LIST2
            JMP LIST6
LIST4:      LIT16 31999         ; List from "n" to the maximum line
            LIST2
            JMP LIST6
LIST5:      LIST1               ; Just "LIST n"
LIST6:      LST
            END
;
; RUN statement.
;
RUN:        TSTN    RUN1        ; Do we have a starting line number?
            DONE                ; Check for the end of the statement
            CLEAR               ; Clear all variables
            XFER                ; GOTO the line we want to start running from
RUN1:       DONE                ; Check for the end of the statement
            RNXT                ; Select the first program line and execute it
;
; CLR statement.
;
CLR:        CLEAR               ; Clear all variables
            END                 ; End of statement
;
; NEW statement.
;
NEW:        DONE                ; Check for the end of the statement
            JMP     START       ; Reinitialize everything!
;
; SIZE statement.
;
SIZE:       SIZE                ; Print the sizes
            END                 ; End of statement
;
; LOAD statement.
;
LOAD:       LOAD                ; Perform the load
            END                 ; End of statement
;
; SAVE statement.
;
SAVE:       SAVE                ; Perform the save
            END                 ; End of statement
;
;-----------------------------------------------------------------------------
;
; Variables and arrays
;
; Test to see if the next token is a variable or array reference and
; push a pointer to the variable or array element.
;
VARRAY:     TSTA    V0          ; Do we have 'X(' for an array variable?
            JMP     ARRAY       ; Get the pointer to the array element
V0:         TSTV    V0          ; Do we have a regular variable name?
            RTN                 ; Return to caller
;
; Resolve a reference to an array element.  On entry, the pointer to the
; base of the array is on the top of AESTK.
;
ARRAY:      TST     ARRAY '('   ; Expect '(' after the name of the array
            CALL    EXPR        ; Get the first dimension's index
            TST     X0 ','      ; 1D or 2D array reference?
            CALL    EXPR        ; Get the second dimension's index
X1:         TST     X1 ')'      ; Expect ')' after the second index
            ARRAY2              ; Find the element in a 2D array
            RTN                 ; Return to caller
X0:         TST     X0 ')'      ; Expect ')' after the first index
            ARRAY1              ; Find the element in a 1D array
            RTN                 ; Return to caller
;
;-----------------------------------------------------------------------------
;
; Expression parsing and evaluation
;
EXPR:       CHKSTK              ; Check CTLSTK for deep recursion
            CALL    AEXPR       ; Get an 'AND' subexpression
EXPR1:      TST     EXPR2 'OR'  ; Do we have an 'OR' operator?
            CALL    AEXPR       ; Get another 'AND' subexpression
            LOR                 ; Peform a logical OR
            JMP     EXPR1       ; More OR operators?
EXPR2:      RTN
;
; Logical AND expression
;
AEXPR:      TSTJ    AEXPR1 'NOT' ; Check for a 'NOT' prefix
            CALL    REXPR       ; Get a relational expression
            JMP     AEXPR2      ; Go look for the 'AND' operator
AEXPR1:     CALL    REXPR       ; Get the relational expression to NOT
            LNOT                ; Perform a logical NOT
AEXPR2:     TST     EXPR2 'AND' ; Do we have an 'AND' operator?
            TSTJ    AEXPR4 'NOT' ; Is the next subexpression NOT'ed?
            CALL    REXPR       ; Get a relational expression
AEXPR3:     LAND                ; Perform a logical AND
            JMP     AEXPR2      ; Go around for another subexpression
AEXPR4:     CALL    REXPR       ; Get the relational expression to NOT
            LNOT                ; Perform a logical NOT
            JMP     AEXPR3      ; Perform the logical AND
;
; Relational expression
;
REXPR:      CALL    ASEXPR      ; Get first subexpression
            TSTOP   REXPR1 CMPEQ '=' ; Figure out which comparison to do
            TSTOP   REXPR1 CMPLE '<='
            TSTOP   REXPR1 CMPNE '<>'
            TSTOP   REXPR1 CMPGE '>='
            TSTOP   REXPR1 CMPNE '><'
            TSTOP   REXPR1 CMPLT '<'
            TSTOP   REXPR1 CMPGT '>'
            RTN                 ; Relational expression is done
REXPR1:     CALL    ASEXPR      ; Get the second subexpression
            APPLY               ; Apply the comparison operator
            RTN                 ; Relational expression is done
;
; Additive or subtractive expression
;
ASEXPR:     CALL    MEXPR       ; Get the first subexpression
ASEXPR1:    TSTOP   ASEXPR2 ADD '+' ; Figure out which operator we have
            TSTOP   ASEXPR2 SUB '-'
            TSTOP   ASEXPR2 BOR 'BOR'
            TSTOP   ASEXPR2 BXOR 'BXOR'
            RTN                 ; Additive or subtractive expression is done
ASEXPR2:    CALL    MEXPR       ; Get the second subexpression
            APPLY               ; Apply the binary operator
            JMP     ASEXPR1     ; Go back for more subexpressions
;
; Multiplicative expression
;
MEXPR:      CALL    UEXPR       ; Get the first subexpression
MEXPR1:     TSTOP   MEXPR2 MPY '*' ; Figure out which operator we have
            TSTOP   MEXPR2 DIV '/'
            TSTOP   MEXPR2 MOD 'MOD'
            TSTOP   MEXPR2 SHL 'SHL'
            TSTOP   MEXPR2 SHR 'SHR'
            TSTOP   MEXPR2 LSR 'LSR'
            TSTOP   MEXPR2 BAND 'BAND'
            RTN                 ; Multiplicative expression is done
MEXPR2:     CALL    UEXPR       ; Get the second subexpression
            APPLY               ; Apply the binary operator
            JMP     MEXPR1      ; Go back for more subexpressions
;
; Unary expression
;
UEXPR:      TSTJ    SEXPR '+'   ; Unary plus?
            TSTJ    UEXPR1 '-'  ; Unary minus?
            TST     SEXPR 'BNOT' ; Bitwise NOT?
            CALL    SEXPR       ; Get the subexpression for bitwise NOT
            BNOT                ; Perform the bitwise NOT
            RTN                 ; Done with the unary expression
UEXPR1:     CALL    SEXPR       ; Get the subexpression for the negation
            NEG                 ; Perform the negation
            RTN                 ; Done with the unary expression
;
; Simple expression
;
SEXPR:      TSTA    SEXPR1      ; Test for an array
            CALL    ARRAY       ; Parse the dimensions to the array
            IND                 ; Index into the array and get the value
            RTN                 ; Return to the caller
SEXPR1:     TSTV    SEXPR2      ; Test for a plain variable
            IND                 ; Load the variable's value onto AESTK
            RTN                 ; Return to the caller
SEXPR2:     TSTN    SEXPR4      ; Test for a number and push it onto AESTK
            RTN                 ; Return to the caller
SEXPR3:     CALL    BEXPR       ; Parse the argument to the function
            APPLYFN             ; Apply the function
            RTN                 ; Return to the caller
ASC:        TST     ASC '('     ; Opening bracket after 'ASC'
            ASC                 ; Expect a string and convert to ASCII
ASC1:       TST     ASC1 ')'    ; Closing bracket
            RTN                 ; Return to the caller
INKEY:      INKEY               ; Input a keystroke without waiting
            RTN                 ; Return to the caller
SEXPR4:     TSTJ    ASC 'ASC'   ; Check for 'ASC' which needs special handling
            TSTJ    INKEY 'INKEY' ; 'INKEY' also needs special handling
            TSTOP   SEXPR3 RND 'RND' ; Check for other built-in functions
            TSTOP   SEXPR3 PEEK 'PEEK'
            CUSTFN  SEXPR3      ; Check for custom functions that extend BASIC
            ; Fall through to BEXPR
;
; Bracketed expression
;
BEXPR:      TST     BEXPR '('   ; Must start with '('
            CALL    EXPR        ; Parse the expression inside the brackets
BEXPR1:     TST     BEXPR1 ')'  ; Must end with ')'
            RTN
