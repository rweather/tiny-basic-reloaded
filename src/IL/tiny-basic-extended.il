;-----------------------------------------------------------------------------
;
; This is the IL implementation of "Tiny BASIC Extended" (TBX) from the
; February 1976 issue of Doctor Dobb's Journal with some fixups and
; lots of comments.
;
; Original version of TBX by Dick Whipple and John Arnold, 1976
; Fixups and commentary by Rhys Weatherley, 2026
;
; https://archive.org/details/dr_dobbs_journal_vol_01
;
;-----------------------------------------------------------------------------
;
; Language grammar:
;
; line ::= number statement-list <CR> | statement-list <CR>
; statement-list ::= statement ("$" statement)*
; statement ::=
;       "PR" expr-list                  ; 'PRINT'
;     | "IF" expression relop expression statement-list ; Note: No 'THEN'
;     | "FOR" var "=" expression "TO" expression
;     | "NXT" var                       ; 'NEXT'
;     | "GOTO" expression
;     | "IN" var-list                   ; 'INPUT'
;     | "LET" var "=" expression
;     | "GOSUB" expression
;     | "RET"                           ; 'RETURN'
;     | "DIM" var-list
;     | "NEW"
;     | "SZE"                           ; Print memory sizes
;     | "LST"                           ; 'LIST'
;     | "GO"                            ; Same as 'LST'
;     | "GO" expression                 ; List a single line
;     | "GO" expression '.' expression  ; List a range of lines
;     | "RUN"
;     | "END"
; expr-list ::= expr-list-prefix ["," | ";"] ["$"]
; expr-list-prefix ::=
;       (string | expression) (("," | ";") (string | expression))*
; var-list ::= var ("," var)*
; expression ::= ["+" | "-"] term (("+" | "-") term)*
; term ::= factor (("*" | "/") factor)*
; factor ::=
;       "RN"                            ; Generate a random number
;     | "TB" expression                 ; TAB across a number of spaces
;     | var
;     | number
;     | "(" expression ")"
; var ::=
;       var-name
;     | var-name "(" expression ")"
;     | var-name "(" expression "," expression ")"
; var-name ::= "A" | "B" | "C" | ... | "Y" | "Z"
; number ::= digit digit*
; digit ::= "0" | "1" | "2" | ... | "8" | "9"
; relop ::= "<" | "<=" | "<>" | ">" | ">=" | "><" | "="
; string ::= '"' (any character except " or <CR>)* '"'
;
;-----------------------------------------------------------------------------
;
; See "tiny-basic-original.il" for the original TB instructions.
; The following are the new instructions that are unique to TBX.
;
; ARRAY1
;       Get the pointer of an element to a 1D array.  The array index is
;       on AESTK and the pointer to the array is just below that.
;       Reports an error if the index is out of range.  Otherwise pops
;       the two arguments and pushes a pointer to the array element.
; ARRAY2
;       Get the pointer of an element to a 2D array.  The array indices are
;       on AESTK and the pointer to the array is just below that.
;       Reports an error if the index is out of range.  Otherwise pops
;       the three arguments and pushes a pointer to the array element.
; DIM1
;       Dimension a 1D array.  The size of the array is on the top of the
;       AESTK and the variable reference is just below that on the AESTK.
; DIM2
;       Dimension a 2D array.  The size of the two dimensions are at the
;       top of AESTK and the variable reference is just below that.
; DONEX
;       Same as "DONE", but used in "GOSUB" to indicate that control
;       will be continuing somewhere else than the next statement.
; FOR
;       Push a frame on the SUBSTK corresponding to the variable,
;       stop value, step value on the AESTK, and the address of the
;       next statement.
; LIST0
;       Set up so that when LST is invoked, the entire program is listed.
; LIST1
;       Set up so that when LST is invoked, a single line is listed.
;       The line number is on the AESTK.
; LIST2
;       Set up so that when LST is invoked, a range of lines is listed.
;       The line numbers for the range are on the AESTK.
; NEXT
;       Using the variable index on the top of the stack, find the
;       corresponding "FOR" frame on SUBSTK and process it.
; NXTX
;       Same as "NXT" but used in the implementation of "PR" for some reason.
; RANDOM
;       Generate a random number between 0 and 10000 and push it onto AESTK.
; SIZE
;       Print memory size information.
; SPCONE
;       Output a single space.
; STOREV
;       Same as "STORE" but do not pop the variable pointer from AESTK,
;       only the value.
; TAB
;       Output the number of spaces given by the top-most value on AESTK.
; TSTA label
;       Test if the source consists of a variable name followed by '('.
;       This indicates an array reference.  If found, push to pointer to the
;       start of the array onto AESTK and skip the array name but not the
;       ')'.  Jump to "label" if not an array.
; TSTCR label
;       Skip whitespace and test if we are at the end of the line.
;       Jump to "label" if not at the end of the line.
;
;-----------------------------------------------------------------------------
;
; Top-level line collection routine
;
STRT:       INIT                ; Initialize
ERRENT:     NLINE               ; Write a CR-LF
C0:         GETLN               ; Write prompt and get a line
            TSTL    XEC         ; If no line number, go execute it
            INSRT               ; Insert or delete the line
            JMP     C0          ; Loop for another line
;
; Statement executor
;
XEC:        XINIT               ; Initialize for execution
DIR:        TST     S1 'LET'    ; Check for 'LET'
            CALL    AVTEST      ; Get the variable reference
S0:         TST     S0 '='      ; Error if no '=' after the variable name
            CALL    EXPR1       ; Put expression on AESTK
            STORE               ; Put value of expression in its cell
            DONE                ; Check for end of statement
            NXT                 ; Continue with the next statement
;
; 'GOTO' and 'GOSUB'
;
S1:         TST     S3 'GO'     ; Check for 'GO'
            TST     S2 'TO'     ; Check for 'GOTO'
            CALL    EXPR        ; Get the label
            DONE                ; Check for end of statement
            XFER                ; Do a 'GOTO' to the label
;
S2:         TST     S14 'SUB'   ; Check for 'GOSUB', failure is an error!
            CALL    EXPR        ; Put expression on AESTK
            DONEX               ; Check for end of statement
            SAV                 ; Save next line number in BASIC text
            XFER                ; Do a 'GOSUB' to the label
;
; 'GO' command, which does a 'LIST' command with an optional range.
;
; GO        List the entire program
; GO n      List the single line n
; GO n,m    List the lines between n and m
;
S14:        TSTCR   S14A        ; Check for end of line; 'GO' with no arguments
            LIST0               ; Set up to list the entire program
            LST                 ; List the entire program
            NXT                 ; Continue with the next statement
;
S14A:       CALL    EXPR        ; Get the number of the first line to list
            TST     S14B ','    ; Is the line numbe followed by a comma?
            CALL    EXPR        ; Yes, so get the last line to list
            LIST2               ; Set up to list a range of lines
            LST                 ; List the range
            JMP     S8A         ; Process the end of the statement
;
S14B:       LIST1               ; Set up to list a single line
            LST                 ; List the line
            JMP     S8A         ; Process the end of the statement
;
; 'IF' statement
;
S3:         TST     S3A 'IF'    ; Check for 'IF'
            CALL    EXPR        ; Get the first expression
            CALL    RELOP       ; Get the relational operator
            CALL    EXPR        ; Get the second expression
            CMPR                ; If not true continue next line
            JMP     DIR         ; If true process the rest of this line
;
; 'FOR' statement
;
S3A:        TST     S4A 'FOR'   ; Check for 'FOR'
S3C:        TSTV    S3C         ; Get the variable index for the loop
S3D:        TST     S3D '='     ; Error if no '=' after the variable name
            CALL    EXPR        ; Get the starting value for the loop
            STOREV              ; Store to the variable, but don't pop the var
S3B:        TST     S3B 'TO'    ; Check for 'TO'
            CALL    EXPR        ; Get the ending value for the loop
            LIT     1           ; Push the default STEP of 1
            DONE                ; Check for end of statement
            FOR                 ; Push a FOR loop context onto SUBSTK
            NXT                 ; Continue with the next statement
;
; 'NXT' statement (i.e. 'NEXT')
;
S4A:        TST     S4 'NXT'    ; Check for 'NXT' (Standard BASIC: 'NEXT')
S4B:        TSTV    S4B         ; Get the name of the for loop variable
            DONE                ; Check for end of statement
            NEXT                ; Perform the NEXT operation
;
; 'PR' statement (i.e. 'PRINT')
;
S4:         TST     S9 'PR'     ; Check for 'PR'
S5:         TST     S8C '"'     ; Check for " to begin a string
            PRS                 ; Print the data enclosed in quotes
S6:         TST     S7A ','     ; ',' means more to come and space to next zone
            SPC                 ; Space to next zone
S7B:        TSTCR   S5A         ; Check for end of line
            NXT                 ; Continue with the next statement
S7A:        TST     S7 ';'      ; ';' means more to come and space once
            SPCONE              ; Output a single space
            JMP     S7B         ; Is there more to come?
S5A:        TST     S5A '$'     ; '$' at the end means no CR-LF
            NXTX                ; Continue with the next statement
S7:         NLINE               ; Write a CR-LF
            DONE                ; Check for end of statement
            NXT                 ; Continue with the next statement
S8C:        TSTCR   S8B         ; Check for end of line
            NLINE               ; Write a CR-LF
            NXT                 ; Continue with the next statement
S8B:        TST     S8 '$'      ; '$' at the start of an expression
            NLINE               ; Write a CR-LF
            NXTX                ; Continue with the next statement
S8:         CALL    EXPR        ; Get the numberic value to print
            PRN                 ; Print the number
            JMP     S6          ; Go back for more
S8A:        DONE                ; Check for end of statement
            NXT                 ; Continue with the next statement
;
; 'IN' command (i.e. 'INPUT')
;
S9:         TST     S12 'IN'    ; Check for 'IN'
S10:        CALL    AVTEST      ; Get the variable's index
            INNUM               ; Get the number from the teletype
            STORE               ; Put the value of the variable in its cell
            TST     S11 ','     ; ',' means more data
            JMP     S10
S11:        DONE                ; Check for end of statement
            NXT                 ; Continue with the next statement
;
; 'RET' command (i.e. 'RETURN')
;
S12:        TST     S13 'RET'   ; Check for 'RET'
            DONE                ; Check for CR line terminator
            RSTR                ; Return to caller
;
; 'END' command
;
S13:        TST     S13B 'END'  ; Check for 'END'
            NLINE               ; Write CR-LF
            FIN                 ; Go back to control mode
;
; 'DIM' command to dimension arrays
;
S13B:       TST     S18 'DIM'   ; Check for 'DIM'
Z0:         TSTA    Z0          ; Get the next variable to dimension
Z0A:        TST     Z0A '('     ; Opening bracket after the array name
            CALL    EXPR        ; Get the outer dimension
            TST     Z1 ','      ; Do we have an inner dimension?
            CALL    EXPR        ; Get the inner dimension
Z0B:        TST     Z0B ')'     ; Closing bracket after the two dimensions
            DIM2                ; Dimension the 2D array
Z3:         TST     S8A ','     ; More arrays to dimension after the comma
            JMP     Z0          ; Go back for more
Z1:         TST     Z1 ')'      ; Closing bracket after the single dimension
            DIM1                ; Dimension the 1D array
            JMP     Z3          ; Are there more arrays to dimension?
;
; 'LST' command (i.e. 'LIST')
;
S18:        TST     S15 'LST'   ; Check for 'LST'
            LST                 ; Type out the BASIC program
            JMP     S8A         ; Continue with next line
;
; 'RUN' command
;
S15:        TST     S16 'RUN'   ; Check for 'RUN'
            DONE                ; Check for end of statement
            RNXT                ; Select the first program line and execute it
;
; 'NEW' command
;
S16:        TST     S17 'NEW'   ; Check for 'NEW'
            DONE                ; Check for end of statement
            JMP     STRT        ; Reinitialize everything!
;
; 'SZE' command to print the memory sizes
;
S17:        TST     S17 'SZE'   ; Check for 'SZE'
            SIZE                ; Print the memory sizes
            JMP     S8A         ; Continue with next line
;
; Parse and evaluate an expression
;
EXPR1:      TST     EXPR '+'    ; Skip unary '+' if one is present
EXPR:       CHKSTK              ; Check for deep recursion
            TST     E0 '-'      ; Test for unary '-'
            CALL    TERM        ; Put term on AESTK
            NEG                 ; Negate value on AESTK
            JMP     E1          ; Go get a term
;
E0:         CALL    TERM        ; Put term on AESTK
E1:         TST     E2 '+'      ; Test for addition
            CALL    TERM        ; Get second term
            ADD                 ; Put sum of terms on AESTK
            JMP     E1          ; Loop around for more
;
E2:         TST     T2 '-'      ; Test for subtraction
            CALL    TERM        ; Get second term
            SUB                 ; Put difference of terms on AESTK
            JMP     E1          ; Loop around for more
;
TERM:       CALL    FACT        ; Get one factor
T0:         TST     T1 '*'      ; Test for multiplication
            CALL    FACT        ; Get a factor
            MPY                 ; Put the product on AESTK
            JMP     T0          ; Loop around for more
;
T1:         TST     T2 '/'      ; Test for division
            CALL    FACT        ; Get a factor
            DIV                 ; Put quotient on AESTK
            JMP     T0          ; Loop around for more
;
FACT:       TST     FN1 'RN'    ; Call to the random function?
            RANDOM              ; Generate a random number
            RTN                 ; Return to caller
;
FN1:        TST     F4 'TB'     ; Call to the tab function?
            CALL    EXPR        ; Get the number of spaces to output
            TAB                 ; Tab across using spaces
            RTN                 ; Return to caller
;
F4:         TSTA    F0          ; Do we have 'X(' for an array variable?
            CALL    ARRAY       ; Get the pointer to the array element
            IND                 ; Index into the array and get the value
T2:         RTN                 ; Return to caller
;
F0:         TSTV    F1          ; Test for variable
            IND                 ; Load the variable's value onto the stack
            RTN
;
F1:         TSTN    F2          ; Test for number
            RTN
;
F2:         TST     F2 '('      ; Error if its not a '('
            CALL    EXPR        ; This is a recursive process
;
F3:         TST     F3 ')'      ; Every '(' has to have a ')'
            RTN
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
; Test to see if the next token is a variable or array reference and
; push a pointer to the variable or array element.
;
AVTEST:     TSTA    V0          ; Do we have 'X(' for an array variable?
            JMP     ARRAY       ; Get the pointer to the array element
V0:         TSTV    V0          ; Do we have a regular variable name?
            RTN                 ; Return to caller
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
