;-----------------------------------------------------------------------------
; Extra BASIC commands for operating system functions:
;
; LOAD [string]
;       Loads the BASIC program from secondary storage.  If a string is
;       supplied, then it indicates a filename.  Otherwise load from the
;       default source such as cassette tape.  Should report a syntax
;       error if loading is not possible.
;
; SAVE [string]
;       Saves the BASIC program to secondary storage.  If a string is
;       supplied, then it indicates a filename.  Otherwise save to the
;       default source such as cassette tape.  Should report a syntax
;       error if loading is not possible.
;
; EXIT [expression]
;       Exits back to the operating system.  If an expression is supplied,
;       then it indicates the exit status.  Otherwise exit status is zero.
;       Report a syntax error if existing back to the OS is not possible.
;
;-----------------------------------------------------------------------------

CUSTOM-STATEMENTS
            TSTJ    LOAD 'LOAD'
            TSTJ    SAVE 'SAVE'
            TSTJ    EXIT 'EXIT'
CUSTOM-STATEMENTS-END

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
; EXIT statement to quit BASIC back to the operating system.
;
EXIT:       TSTEND  EXIT1       ; Do we have an argument?
            LIT     0           ; Default exit status of zero
            EXIT                ; Exit back to the operating system
EXIT1:      CALL    EXPR        ; Evaluate the exit status
            EXIT                ; Exit back to the operating system
