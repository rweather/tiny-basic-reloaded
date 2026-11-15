IL Bytecode Reference
=====================

This document describes the behaviour of all bytecode instructions to
aid implementation on a target platform.

Instructions make use of three stacks:

* Control stack (CTLSTK)
* Subroutine stack (SUBSTK)
* Arithmetic expression stack (AESTK)

Some of the instructions below jump to "XEC".  That indicates that
control continues with the next BASIC statement after the instruction
rather than continuing.

* [Initialization instructions](#init)
* [Test instructions](#test)
* [Control flow instructions](#ctrl-flow)
* [Printing instructions](#print)
* [Input instructions](#input)
* [Arithmetic instructions](#arith)
* [Logical instructions](#logic)
* [Bitwise instructions](#bitwise)
* [Comparison instructions](#compare)
* [Variable handling instructions](#var)
* [Array handling instructions](#array)
* [Apply instructions](#apply)
* [Random number generation instructions](#random)
* [Program management instructions](#program)
* [Other instructions](#other)

<a name="init"/>
## Initialization instructions

### INIT

Initializes the BASIC environment.  The program and variable storage
areas are cleared.  CTLSTK, SUBSTK, and AESTK are emptied.

The "NEW" statement in BASIC uses this opcode.

### XINIT

Initializes to execute the next BASIC command.  CTLSTK and AESTK are emptied.
The program and variable storage areas are not affected.

The XINIT instruction is a good place to put BREAK / CTRL-C detection
because every command will return to "XEC" at some point.

### CLEAR

Clears all variables from memory.

<a name="test"/>
## Test instructions

The main core of the BASIC parser and interpreter is "TST" and its
variants.  These instructions skip whitespace and then match the
following text.  If the text does or does not match, control will either
pass to a label or continue execution with the next instruction.

Except for "TSTJ", all test instructions use a short 8-bit offset to
peform the jump.  The destination must be close to the test point.

### TST label string

Check if the supplied string matches the following text.  If it does
match, skip the string in the input text and continue with the next
instruction.  If it does not match, then leave the input positioned
where it was before and jump to the "label".  Examples:

    TST S8 'PRINT'          ; Jump to S8 if not 'PRINT'
    TST S6 ','              ; Jump to S6 if not a comma

If "label" refers to the current instruction, then a syntax error
is reported instead of jumping to "label":

    S8A: TST S8A 'THEN'     ; Syntax error if the next keyword is not 'THEN'

The other test instructions are similar in that a self-referential
jump causes a syntax error.

### TSTJ label string

"Test and jump" instruction.  Same as "TST", but jumps to the "label" on a
match or continues with the next instruction for no match.

This instruction takes a long 16-bit offset to the destination so it can
jump to anywhere in the IL program.

### TSTV label

Test if the next token is a plain variable name A-Z.  Jump to "label" if not.
If it is a variable name, then push a pointer to the variable onto AESTK
and continue with the next instruction.

### TSTA label

Test if the next token is an array variable name A-Z followed by a
left parenthesis.  Jump to "label" if not.

If it is an array name, then skip the name but not the parenthesis,
push a pointer to the array header onto AESTK, and continue with the
next instruction.

### TSTN label

Test if the next token is a number.  Jump to "label" if not.  If it is a
number, then push the value onto AESTK and continue with the next instruction.

### TSTL label

Special case of "TSTN" that also checks that the number is between
1 and 31999 for a line number.

### TSTCR label

Skip whitespace and check if we are at the end of the current program line.
Jumps to "label" if not at the end of the line.

### TSTEND label

Skip whitespace and check if we are at the end of the current statement.
Jumps to "label" if not at the end of the statement.

Either end of line or ":" indicates the end of a statement.

### TSTOP label opcode string

Test if the next token is the string.  If it is, then push a pointer to the
handler for "opcode" onto AESTK and jump to "label".

"TSTOP" is usually combined with "APPLY" or "APPLYFN" to apply the
effect of the opcode once its parameters have been parsed.

<a name="ctrl-flow"/>
## Control flow instructions

### CALL label

Calls the IL subroutine at "label".  The return address is pushed onto CTLSTK.

### RTN

Return from an IL subroutine.  The return address is popped from CTLSTK.

### JMP label

Jumps to "label".

In the original version of Tiny BASIC, "HOP label" could also be used
for short jumps.

### DONE

Check if we are at the end of the current statement.  Raises a
syntax error if not.

Tiny BASIC Extended also had "DONEX".  This implementation treats
"DONEX" the same as "DONE".

### NXT

Move to the next statement.  If preceded by DONE, then this will
check for ":" or end of line.  If not preceded by DONE, then "NXT"
will ignore all remaining statements and go to the next line.

Jumps to "XEC".

Tiny BASIC Extended also had "NXTX".  This implementation treats
"NXTX" the same as "NXT".

### END

Shortcut that combines the effect of DONE and NXT to end the
current statement.

Jumps to "XEC".

### RNXT

Special case of "NXT" that resets the program pointer to the start of
the program, clears all variables, and starts running the program.

Jumps to "XEC".

### XFER

Pop the value at the top of AESTK and use it as a line number for "GOTO".
Continue execution with the next instruction.

Jumps to "XEC".

### SAV

Saves the current BASIC program location on SUBSTK for "GOSUB".

This opcode does not work in direct mode.

### RSTR

Restores the BASIC program location from SUBSTK for "RETURN".

Any "FOR" contexts on SUBSTK before the next "RETURN" context will
be discarded.

Jumps to "XEC".

This opcode does not work in direct mode.

### POP

Pops the top-most "RETURN" context from SUBSTK.  If there were
"FOR" contexts on the stack above the "RETURN" context, they
will be discarded.

### CHKSTK

Check if CTLSTK is full, indicating that recursion during expression
evaluation is too deep.  Raise "FORMULA TOO COMPLEX" if CTLSTK is full.

The implementation can alternatively check the size of CTLSTK during "CALL".

### IF

Pop the value at the top of AESTK.  If the value is zero, then
go to the next line in the program and jump to "XEC".  Otherwise,
continue execution with the next instruction.

### FOR

Pops the top three values from AESTK which are the variable pointer,
the stop value for the loop, and the step value for the loop.
The step value is top-most before the pop.

Push a "FOR" context onto SUBSTK for use by a subsequent "NEXT",
which includes the variable pointer, stop value, step value, and the
location in the BASIC program to return back to for "NEXT".

This opcode does not work in direct mode.

### NEXT

Pops the value at the top of AESTK, which is either a pointer to the
loop variable or zero for "NEXT" without an explicit loop variable.

Find the "FOR" context on SUBSTK that matches the loop variable,
or the first "FOR" context on SUBSTK if the value on AESTK was zero.
Any other "FOR" contexts in the way are discarded.

If a "RETURN" context is encounted on SUBSTK, then report a
"NEXT WITHOUT FOR" error and stop.

Once the matching "FOR" context is found, then add the step value to the
loop variable.  If the loop variable's value has exceeded the stop value,
then continue with the next instruction.  Otherwise, jump to the top
of the "FOR" loop.

This opcode does not work in direct mode.

### ERR

Report a syntax error and stop.  This is not used much as the "TST"
instructions usually handle syntax errors.

### FIN

Aborts BASIC program execution and returns to the top-most command loop;
i.e. "direct mode".  This is used for the BASIC command "END".

### EXIT

Aborts BASIC program execution and returns control to the
operating system, passing the status code on the top of AESTK.

This opcode is for versions of BASIC that are running inside a larger
system.  If BASIC is the operating system and there is no way to
exit it, then the handler for this opcode should report a syntax error.

<a name="print"/>
## Printing instructions

### PRS

Print the string at the current location in the BASIC program.
It is assumed that the leading double quote (") has already been
recognised with a test instruction.

Printing continues until the next double quote (").  If the end of the
line is reached, a syntax error will result.

### PRN

Pop a value from AESTK and print it as a decimal number.

### PRC

Pop a value from AESTK and print it as an ASCII character.  Only the
bottom 8 bits of the value are significant; the rest is ignored.

### NLINE

Prints a carriage return and line feed.

### SPC

Spaces over to the next print zone / tab stop.

### SPCONE

Prints a single space.  This was used by Tiny BASIC Extended for ";" in
PRINT statements.  Tiny BASIC Reloaded does not print a space for ";".

### TAB

Pops a value from AESTK and prints that many spaces.

<a name="input"/>
## Input instructions

### INNUM

Inputs a number and pushes the value onto AESTK.

### INKEY

If a key is available, push its ASCII character code onto AESTK.
Otherwise push -1 onto AESTK if a key is not currently available.

<a name="arith"/>
## Arithmetic instructions

### LIT n

Pushes a 16-bit literal onto AESTK.

### ADD, SUB, MPY

Pops the top two values from AESTK and pushes their sum, difference, or
product.

### DIV, MOD

Pops the top two values from AESTK, divides them, and pushes their
quotient or remainder.  Raises a "DIVISION BY ZERO" error if the
second value is zero.

## FPMUL

Pops the top three values from AESTK and performs a fixed-point
multiplication.  The values from bottom to top are x, y, and bits.
The effect is to compute (x &#42; y) &gt;&gt; bits in double
precision.  If the result is outside the range of a signed integer,
report "OVERFLOW ERROR".

<a name="logic"/>
## Logical instructions

### LAND

Pops the top two values from AESTK.  If both are non-zero, then
push 1 onto AESTK.  Otherwise push 0 onto AESTK.

### LOR

Pops the top two values from AESTK.  If either is non-zero, then
push 1 onto AESTK.  Otherwise push 0 onto AESTK.

### LNOT

Pops the top value from AESTK.  If the value is non-zero, then
push 0 onto AESTK.  Otherwise push 1 onto AESTK.

<a name="bitwise"/>
## Bitwise instructions

### BAND

Pops the top two values from AESTK and push their bitwise AND.

### BOR

Pops the top two values from AESTK and push their bitwise OR.

### BXOR

Pops the top two values from AESTK and push their bitwise XOR.

### BNOT

Pops the top value from AESTK and pushes its bitwise NOT.

### SHL

Pops the top two values from AESTK and pushes the first shifted
left by the number of bits given in the second.

If the bit count is negative, the effect is the same as zero.
If the bit count is beyond the size of integers on the platform,
the result will be zero.

### SHR

Pops the top two values from AESTK and pushes the first shifted
right by the number of bits given in the second.

This performs an arithmetic shift which duplicates the sign bit
into the bits that are shifted in at the top.

### LSR

Pops the top two values from AESTK and pushes the first shifted
right by the number of bits given in the second.

This performs a logical shift which shifts in zero bits at the top.

<a name="compare"/>
## Comparison instructions

### CMPEQ, CMPNE, CMPLT, CMPGT, CMPLE, CMPGE

Pop two values from AESTK and compare them for equal, not equal,
less than, greater than, less than or equal, or greater than or
equal respectively.

If the comparison succeeds, 1 is pushed onto AESTK.  If the comparison
fails, 0 is pushed onto AESTK.

### CMPR

Pops three values from AESTK and performs a comparison.  The middle value
must be one of the following, indicating the type of comparison to perform:

* 0 - Equal
* 1 - Less than
* 2 - Less than or equal
* 3 - Not equal
* 4 - Greater than
* 5 - Greater than or equal

If the comparison fails, go to the next line.  Otherwise continue
execution on the current line.

This opcode was used by the original Tiny BASIC and by Tiny BASIC Extended to
implement "IF" statements.  Only a single relational expression was allowed.

Tiny BASIC Reloaded uses CMPEQ, CMPNE, CMPLT, CMPGT, CMPLE, CMPGE, and IF.
This allows multiple relational expressions to be combined with logical AND,
OR, and NOT.

<a name="var"/>
## Variable handling instructions

### STORE

Pops two values from AESTK.  Stores the top-most value into the
variable pointer given by the lower value.

Variable pointers result from TSTV, ARRAY1, and ARRAY2 instructions.

### STOREV

Same as STORE but do not pop the variable pointer from AESTK.

### IND

Pops a variable pointer from the AESTK.  Pushes the value at that
pointer onto AESTK.

<a name="array"/>
## Array handling instructions

### ARRAY1

Pops the top two values from AESTK, which are a pointer to an
array header for a 1D array and the subscript into the array.  Finds the
element at that subscript and pushes a pointer to it onto AESTK.

If the array is not defined or not 1-dimensional, then report the
"NOT AN ARRAY" error and stop.  If the subscript is out of range,
then report the "SUBSCRIPT OUT OF RANGE" error and stop.

### ARRAY2

Pops the top three values from AESTK, which are a pointer to an
array header for a 2D array and the subscripts into the array.  Finds the
element at those subscripts and pushes a pointer to it onto AESTK.

If the array is not defined or not 2-dimensional, then report the
"NOT AN ARRAY" error and stop.  If either of the subscripts is out of
range, then report the "SUBSCRIPT OUT OF RANGE" error and stop.

### DIM1

Pops the top two values from AESTK, which are a pointer to an
array header and the maximum subscript of the 1D array to create.
Array headers are created by the TSTA instruction.

If the array is not currently dimensioned, then allocate memory for the
array and initialize the array header for a 1-dimensional array.

If the array has already been dimensioned, then report the
"REDIMENSIONED ARRAY" error and stop.

If the maximum subscript is negative, then report the
"INVALID ARRAY DIMENSION" error and stop.

If there is insufficient memory to allocate the new array, then report the
"OUT OF MEMORY" error and stop.

### DIM2

Pops the top three values from AESTK, which are a pointer to an
array header and the maximum subscripts of the 2D array to create.
Array headers are created by the TSTA instruction.

If the array is not currently dimensioned, then allocate memory for the
array and initialize the array header for a 2-dimensional array.

See DIM1 above for the error cases.

<a name="apply"/>
## Apply instructions

### APPLY

Pops three values from AESTK and applies the opcode whose pointer is in
the middle.  Pushes the result onto AESTK.  The pointer comes from a
previous "TSTOP" instruction.

### APPLYFN

Pops two values from AESTK and applies the opcode whose pointer is
lower down on the stack.  Pushes the result onto AESTK.  The pointer
comes from a previous "TSTOP" instruction.

<a name="random"/>
## Random number generation instructions

### RANDOM

Pops the top value n from AESTK.  If n is zero or negative, then report
the "ILLEGAL FUNCTION CALL" error.  Otherwise, generate a random integer
between 0 and n-1 and push it onto AESTK.

<a name="program"/>
## Program management instructions

### INSRT

Inserts the current line into the BASIC program at the line number on AESTK.
If the current line is empty, then delete the line from the program instead.

The line number is assumed to be the result of the TSTL instruction which
verifies that the value is between 1 and 31999.

May report "OUT OF MEMORY" if the program is too large.

### LIST0

Set up to list the entire BASIC program.

### LIST1

Set up to list a specific line of the BASIC program that is on AESTK.

### LIST2

Set up to list a range of lines of the BASIC program, where the first and
last line numbers are on AESTK.

### LST

List the portion of the BASIC program that was specified by a previous
LIST0, LIST1, or LIST2 instruction.

<a name="other"/>
## Other instructions

### ASC

Parses a string in double-quotes from the program text.  If the string is
empty, push 0 onto AESTK.  Otherwise push the ASCII character code of the
first character onto AESTK.

### PEEK

Pops the top value from AESTK and interprets it as a memory address.
Read the value at the memory address and push it onto AESTK.

### POKE

Pops the top two values from AESTK and writes to memory.

### MCALL

Pops the top value from AESTK and interprets it as a memory address.
Calls the machine language routine at that memory address.

### CUSTOM

Handles custom statements that extend the BASIC language.  If there are
none, raise a syntax error.

### CUSTFN label

Handles custom functions that extend the BASIC language.  Jump to
"label" if a custom function name is found.

### LOAD

Loads a program from secondary storage.  If the implementation needs a
filename, it should appear next in the program text.

### SAVE

Saves the program to secondary storage.  If the implementation needs a
filename, it should appear next in the program text.

### SIZE

Prints memory size information for the program and variables.
