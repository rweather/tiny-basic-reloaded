Tiny BASIC Reloaded Language Reference
======================================

Tiny BASIC Reloaded borrows a number of features from other BASIC's to
provide a reasonable set of capabilities in an integer-only BASIC.

Inspiration was taken from Tiny BASIC, Tiny BASIC Extended,
AppleSoft BASIC, Apple II Integer BASIC, and TRS-80 Level II BASIC.
The syntax mostly follows AppleSoft except where AppleSoft was
missing something like INKEY.

## Expressions

Expressions are at the heart of BASIC.  The simplest expressions are
numbers, variables, and array element references:

    -42
    X
    A(6)

There are 26 variables named **A** to **Z** which contain an
integer value.  On 8-bit and 16-bit systems, integers range between
-32768 and 32767.  It is possible to enter numbers up to 65535,
but the numbers 32768 to 65535 will wrap around to the negative side.
Operations on integers that overflow will do the same thing.

There are 26 arrays also named **A** to **Z**, which may have
1 or 2 dimensions.  The array elements are integers.  Arrays must be
dimensioned before use:

    DIM A(100),B(4,6)

When an array is dimensioned to size 100 say, the array actually has
101 elements numbered 0 to 100.  The dimension value is the maximum
subscript, not the number of elements.

Tiny BASIC Reloaded provides a rich set of operators for performing
integer arithmetic, including bitwise operations.  The following table
shows the operator precedence from highest to lowest:

<table border="1">
<tr><td><b>Operator</b></td><td><b>Description</b></td></tr>
<tr><td>( )</td><td>Parentheses for grouping</td></tr>
<tr><td>-<br/>+<br/>BNOT</td><td>Negation<br/>Unary plus<br/>Bitwise NOT</td></tr>
<tr><td>&#42;<br/>/<br/>MOD<br/>SHL<br/>SHR<br/>LSR<br/>BAND</td><td>Multiplication<br/>Division giving a quotient<br/>Division giving a remainder<br/>Bitwise shift left<br/>Bitwise arithmetic shift right<br/>Bitwise logical shift right<br/>Bitwise AND</td></tr>
<tr><td>+<br/>-<br/>XOR<br/>BOR</td><td>Addition<br/>Subtraction<br/>Bitwise XOR<br/>Bitwise OR</td></tr>
<tr><td>=<br/>&lt;&gt;<br/>&lt;<br/>&gt;<br/>&lt;=<br/>&gt;=</td><td>Equality<br/>Inequality<br/>Less than<br/>Greater than<br/>Less than or equal to<br/>Greater than or equal to</td></tr>
<tr><td>NOT</td><td>Logical NOT</td></tr>
<tr><td>AND</td><td>Logical AND</td></tr>
<tr><td>OR</td><td>Logical OR</td></tr>
</table>

## Command index

* [CALL](#call) - Calls a machine language subroutine.
* [CLR](#clr) - Clears all variables and arrays from memory.
* [DIM](#dim) - Dimensions arrays and allocates the memory for them.
* [END](#end) - Ends program execution and return to direct command mode.
* [EXIT](#exit) - Exits BASIC back to the surrounding operating system.
* [FOR...NEXT](#fornext) - Loops around a given number of times.
* [FPMUL](#fpmul) - Performs fixed-point multiplication.
* [GOSUB...RETURN](#gosub) - Calls and returns from subroutines.
* [GOTO](#goto) - Redirects program flow to another line in the program.
* [IF...THEN](#ifthen) - Redirecting program flow based on a condition.
* [INPUT](#input) - Enter numeric values from the keyboard.
* [LET](#let) - Assigns values to variables or array elements.
* [LIST](#list) - List program lines.
* [LOAD](#load) - Loads a program from secondary storage.
* [POKE](#poke) - Pokes a value into a memory location.
* [POP](#pop) - Pops a subroutine return address from the subroutine stack.
* [PRINT](#print) - Prints characters to the output device.
* [REM](#rem) - Adds a comment, remark, or reminder to the code.
* [RUN](#run) - Starts running the program.
* [SAVE](#save) - Saves the program to secondary storage.
* [SIZE](#size) - Prints memory size information for the program and variables.

## Function index

* [ASC](#asc) - Converts the first character of a string into its ASCII code.
* [CHR$](#chrs) - Prints a character by its ASCII code.
* [INKEY](#inkey) - Gets input a key at a time without waiting.
* [PEEK](#peek) - Peeks at the value in a memory location.
* [RND](#rnd) - Generates a random number.
* [SPC](#spc) - Prints a specified number of spaces.

---

<a name="asc"/>
### ASC

**Purpose:** Converts the first character of a string into its ASCII code.

**Format:**
> **ASC**("_string_")

**Description:**
> If _string_ is empty, then the result of the **ASC** function is zero.
Otherwise, the result is the ASCII code for the first character of _string_.

**Examples:**

    10 LET A = ASC("A")
    20 PRINT A
    RUN
    65

---

<a name="call"/>
### CALL

**Purpose:** Calls a machine language subroutine.

**Format:**
> **CALL** _expression_

**Description:**
> Evaluates the _expression_ and then interprets it as the address
of a machine language subroutine.  Calls the subroutine.  Continues
executing BASIC code when the machine language subroutine returns.

> If the _expression_ address points to invalid code, the behaviour
is undefined.

**Examples:**

    CALL -151

---

<a name="chrs"/>
### CHR$

**Purpose:** Prints a character by its ASCII code.

**Format:**
> **PRINT CHR$**(_expression_)

**Description:**
> **CHR$**(_expression_) evaluates the _expression_ and prints the
ASCII character corresponding to the low 8 bits of the value.
The upper bits are discarded.

> **CHR$** can only be used from within a **PRINT** statement as the
language does not support string variables.

**Examples:**

    PRINT "Print a double-quote: ";CHR$(34)

---

<a name="clr"/>
### CLR

**Purpose:** Clears all variables and arrays from memory.

**Format:**
> **CLR**

**Description:**
> Plain variables **A** to **Z** are set to zero.  The memory for
array variables **A** to **Z** is deallocated.

**Examples:**

    LET X = 42
    PRINT X
    42
    CLR
    PRINT X
    0

---

<a name="dim"/>
### DIM

**Purpose:** Dimensions arrays and allocates the memory for them.

**Format:**
> **DIM** _variable_ ( _subscripts_ ) [, _variable_ ( _subscripts_ ), ...]

**Description:**
> **DIM** allocates space for 1-dimensional and 2-dimensional arrays
of integers.  The subscripts indicate the maximum subscript index that
may be used for that dimension.

> **DIM A**(_n_) allocates space for a 1-dimensional array called **A**
with subscripts 0 to n.  **DIM B**(_n_, _m_) allocates space for a
2-dimensional array called **B** with outer subscripts 0 to n and
inner subscripts 0 to m.

> Up to 26 arrays may be dimensioned with the names **A** to **Z**.

**Examples:**
> The following example dimensions an array with maximum subscript 100.
It then fills the array with the squares of the integers 1 to 100.
Finally, the squares are printed.

    10 DIM A(100)
    20 FOR I = 1 TO 100
    30 A(I) = I * I
    40 NEXT I
    50 FOR J = 1 TO 100
    60 PRINT A(J)
    70 NEXT J
    RUN
    1
    4
    9
    16
    ...

**Errors**:
> `REDIMENSIONED ARRAY` - Array was already dimensioned by a previous `DIM` command.<br/>
`OUT OF MEMORY` - Insufficient memory to satisfy the allocation request.<br/>
`INVALID ARRAY DIMENSION` - Maximum subscript is negative or zero.<br/>
`SUBSCRIPT OUT OF RANGE` - Access to a subscript that is not in range for the selected array.

---

<a name="end"/>
### END

**Purpose:** Ends program execution and return to direct command mode.

**Format:**
> **END**

**Description:**
> **END** may appear anywhere in the program.  When encountered,
program execution stops and control returns to direct command mode.

**Examples:**

    60 IF X > 0 GOTO 80
    70 END
    80 ...

---

<a name="exit"/>
### EXIT

**Purpose:** Exits BASIC back to the surrounding operating system.

**Format:**
> **EXIT** [_expression_]

**Description:**
> **EXIT** exits BASIC and returns control back to the surrounding
operating system.  If BASIC itself is the operating system,
then **EXIT** will report a syntax error and do nothing.

> The value of _expression_ is passed back to the operating system
as the exit status of the BASIC process.  If _expression_ is not
present, the default exit status is zero.

**Examples:**

    EXIT
    EXIT 1

---

<a name="fornext"/>
### FOR...NEXT

**Purpose:** Loops around a given number of times.

**Format:**
> **FOR** _var_ = _n_ **TO** _m_ [**STEP** _s_]<br/>
**NEXT** _var_

**Description:**
> **FOR** sets up a loop where the variable _var_ iterates from
_n_ to _m_ in steps of _s_.  If **STEP** is omitted, _s_ will be 1.

> _n_ is the initial value for _var_.  Each time around the loop,
_s_ is added to _var_.  The loop stops if the new value of _var_ has
moved beyond _m_.  If _s_ is positive, then the loop stops when
_var_ is greater than _m_.  If _s_ is negative, then the loop stops when
_var_ is less than _m_.

> **NEXT** marks the end of the loop where _var_ is incremented and
tested.  If _var_ is still between _n_ and _m_, then control returns
to the command just after the corresponding **FOR**.  Otherwise,
control continues with the command after the **NEXT**.

> **FOR...NEXT** loops can be nested inside each other.  The variable
for each nested loop must be different, and the **NEXT** variables
must be in reverse order of the corresponding **FOR**'s.  Otherwise the
control flow will get very confusing.

> The variable can be omitted from **NEXT** to return back to the
most recent **FOR**.  It is good practice to always include the
variable name.

**Examples:**

    10 FOR N = 0 TO 100 STEP 2
    20 PRINT N;" IS EVEN"
    30 NEXT

    40 FOR I = 1 TO 5
    50 FOR J = 5 TO 1 STEP -1
    60 PRINT I*J
    70 NEXT J
    80 NEXT I

**Errors**:
> `NEXT WITHOUT FOR` - Could not find a **FOR** statement with a matching variable.<br/>
`TOO MANY FORS` - The stack of open **FOR** loops ran out of space.  This may happen if **FOR** is executed repeatedly without a matching **NEXT**.

---

<a name="fpmul"/>
### FPMUL

**Purpose:** Performs fixed-point multiplication.

**Format:**
> LET _result_ = **FPMUL**(_x_, _y_, _bits_)

**Description:**
> **FPMUL** performs fixed-point multiplication.  The expressions
_x_ and _y_ are evaluated and multiplied to produce a double-precision
integer intermediate result.  The intermediate result is then
shifted right by _bits_ bit positions.

> The _bits_ parameter must be a literal number between 1 and 14.
It cannot be a variable or a complex expression.

> Fixed-point multiplication is provided to make up for the lack of
floating-point.  It can help with certain algorithms where only a
certain number of bits of precision are required and a normal
16-bit multiplication would overflow the intermediate result.

> Fixed-point addition and subtraction are the same as regular integer
addition and subtraction.  Fixed-point division is not currently
supported.

**Examples:**

> In the example below, the fixed-point number 240 is equivalent to
240 / 2<sup>5</sup> = 7.5 and -1234 is equivalent to -38.5625.
The result -9255 is equivalent to -289.21875 = 7.5 &#42; -38.5625.

> 240 &#42; -1234 = -296160 is outside the range of a 16-bit signed integer,
but 240 &#42; -1234 / 2<sup>5</sup> = -9255 is in range.  The correct result
cannot be computed with regular 16-bit multiplication and division.

    PRINT 230 * -1234 / 32
    -677
    PRINT FPMUL(240, -1234, 5)
    -9255

**Errors**:
> `OVERFLOW ERROR` - The final result does not fit in a 16-bit integer.<br/>
`ILLEGAL FUNCTION CALL` - The number of _bits_ is outside the range 1 to 14.

---

<a name="gosub"/>
### GOSUB...RETURN

**Purpose:** Calls and returns from subroutines

**Format:**
> **GOSUB** _expression_<br/>
...<br/>
**RETURN**

**Description:**
> **GOSUB** calls a subroutine at the line number corresponding to the
value of _expression_.  The current location in the program is saved
on the subroutine stack so that **RETURN** can come back to the original
location after the subroutine ends.

> **RETURN** ends execution of the subroutine and returns to the location
after the corresponding **GOSUB**.

> The _expression_ can be an arbitrary expression, which can be used
to compute the line number at runtime.  This has a similar effect to
**ON GOSUB** in other dialects of BASIC.

**Examples:**

    10 INPUT "ENTER A NUMBER: ";A
    20 GOSUB 50
    30 PRINT A
    40 GOTO 10
    50 IF A < 100 GOTO 80
    60 A = A * 2
    70 RETURN
    80 A = A + 200
    90 RETURN
    RUN
    ENTER A NUMBER: 49
    98
    ENTER A NUMBER: 100
    300

**Errors**:
> `INVALID LINE NUMBER` - The line number corresponding to _expression_ does not exist in the program.<br/>
`RETURN WITHOUT GOSUB` - **RETURN** encountered without a corresponding **GOSUB**.<br/>
`TOO MANY GOSUBS` - The stack of active **GOSUB** calls ran out of space.  This may happen if subroutine recursion is too deep.

---

<a name="goto"/>
### GOTO

**Purpose:** Directs program flow to another line in the program.

**Format:**
> **GOTO** _expression_

**Description:**
> **GOTO** redirects program execution to the line number corresponding
to _expression_.

> The _expression_ can be an arbitrary expression, which can be used
to compute the line number at runtime.  This has a similar effect to
**ON GOTO** in other dialects of BASIC.

**Examples:**

    10 PRINT "Hello World!"
    20 GOTO 10

    10 X = 20
    20 GOTO X + 20
    30 PRINT "Will not see this"
    40 PRINT "Will see this"
    RUN
    Will see this

**Errors**:
> `INVALID LINE NUMBER` - The line number corresponding to _expression_ does not exist in the program.<br/>

---

<a name="ifthen"/>
### IF...THEN and IF...GOTO

**Purpose:** Redirecting program flow based on a condition.

**Format:**
> **IF** _condition_ **THEN** _statement_<br/>
**IF** _condition_ **THEN** _number_<br/>
**IF** _condition_ **GOTO** _expression_ <br/>

**Description:**
> **IF** redirects program execution based on the _condition_.
If the _condition_ is non-zero, then execution continues on the
same line as the **IF**.  If the _condition_ is zero, then
execution continues with the next line in the program.

> The first form of **IF** can execute any arbitrary _statement_ or
sequence of statements separated by colons.  The second and third
forms of **IF** transfer execution to a specific line number when the
_condition_ is non-zero.

**Examples:**

    50 IF X < 1 OR X > 100 THEN PRINT "OUT OF RANGE":END
    60 IF Y THEN PRINT "Y IS TRUE"

**Errors**:
> `INVALID LINE NUMBER` - The line number corresponding to _number_ or
_expression_ does not exist in the program.<br/>

---

<a name="inkey"/>
### INKEY

**Purpose:** Gets input a key at a time without waiting.

**Format:**
> **INKEY**<br/>
**INKEY**(_timeout_)

**Description:**
> **INKEY** first checks if a key is available in the input buffer.
If a key is available, **INKEY** returns the ASCII code of that key.
If a key is not available, **INKEY** returns -1.  The key is not
echo'ed to the screen.

> The optional _timeout_ specifies how many milliseconds to wait
for the key before returning -1.  If _timeout_ is zero, then
return immediately if there is no key available.  If _timeout_ is
negative, then wait indefinitely (BREAK will abort).  If _timeout_
is not supplied, the default value is zero.

**Examples:**

    10 K = INKEY(1000)
    20 IF K = ASC("A") THEN 60
    30 IF K = ASC("B") THEN 80
    40 IF K = -1 THEN PRINT "TIMEOUT"
    50 GOTO 10
    60 PRINT "A WAS PRESSED"
    70 GOTO 10
    80 PRINT "B WAS PRESSED"
    90 GOTO 10

---

<a name="input"/>
### INPUT

**Purpose:** Enter numeric values from the keyboard.

**Format:**
> **INPUT** ["_prompt_";] _var1_ [, _var2_, ...]

**Description:**
> **INPUT** prints the _prompt_ and then waits for the user to enter
one or more numbers, separated by whitespace.  The numbers are
written to _var1_, _var2_, etc.

**Examples:**

    10 INPUT "A,B = ";A,B

**Errors**:
> `OUT OF DATA` - User pressed ENTER without providing a number.

---

<a name="let"/>
### LET

**Purpose:** Assigns values to variables or array elements.

**Format:**
> [**LET**] _var_ = _expression_

**Description:**
> **LET** evaluates the value of _expression_ and assigns it to _var_.
The **LET** keyword is optional.

**Examples:**

    10 DIM C(100)
    20 LET A = 10
    30 B = A * 8
    40 C(B) = 72

**Errors**:
`SUBSCRIPT OUT OF RANGE` - Access to a subscript that is not in range for the selected array.

---

<a name="list"/>
### LIST

**Purpose:** List program lines.

**Format:**
> **LIST**<br/>
**LIST** _line1_ , _line2_<br/>
**LIST** _line1_ - _line2_<br/>
**LIST** _line1_ -<br/>
**LIST** _line1_ ,<br/>
**LIST** - _line1_<br/>
**LIST** _line1_<br/>

**Description:**
> **LIST** lists the range of lines given as operands.  With no operands,
list the entire program.  Comma or dash may be used to specify the range.
Only numeric _line1_ and _line2_ values are allowed.

**Examples:**

    LIST
    LIST 10-50
    LIST 10,50
    LIST 100-
    LIST 100,
    LIST -100
    LIST 50

**Errors**:
> `INVALID LINE NUMBER` - Line number is not between 1 and 31999.

---

<a name="load"/>
### LOAD

**Purpose:** Loads a program from secondary storage.

**Format:**
> **LOAD** ["_filename_"]

**Description:**
> Loads a program into memory from secondary storage.
Without a _filename_, usually loads from a default source like a
cassette tape.  With a _filename_, loads from a file on disk.

**Examples:**

    LOAD
    LOAD "hello.bas"

**Errors**:
> `SYNTAX ERROR` - Syntax error while trying to load the program.<br/>
`MISSING OPERAND` - The _filename_ is required but was not supplied.<br/>
`INVALID FILENAME` - The _filename_ is not valid or could not be found.<br/>
`BAD FILE DATA` - The format of the program on the storage was invalid.<br/>

---

<a name="peek"/>
### PEEK

**Purpose:** Peeks at a value in a memory location.

**Format:**
> **PEEK**(_address_)

**Description:**
> **PEEK** evaluates the _address_ and returns the value at that address.

> If the system does not support peeking into memory, this command
will always return zero.

**Examples:**

    X = PEEK(12345)

---

<a name="poke"/>
### POKE

**Purpose:** Pokes a value into a memory location.

**Format:**
> **POKE** _address_, _value_

**Description:**
> **POKE** evaluates the _address_ and _value_ expressions and then
pokes _value_ into the specified _address_.

> If the system does not support poking into memory, this command
does nothing.

**Examples:**

    POKE 12345,67

---

<a name="pop"/>
### POP

**Purpose:** Pops a subroutine return address from the subroutine stack.

**Format:**
> **POP**

**Description:**
> **POP** removes the top-most return address for a previous
**GOSUB** command from the subroutine stack.  **RETURN** will no
longer return to that point.

**Examples:**

    10 GOSUB 40
    20 PRINT "I am here"
    30 END
    40 GOSUB 70
    50 PRINT "This will not happen"
    60 RETURN
    70 POP
    80 RETURN
    RUN
    I am here

---

<a name="print"/>
### PRINT

**Purpose:** Prints characters to the output device.

**Format:**
> **PRINT** [_list_] [;]<br/>
**?** [_list_] [;]

**Description:**
> **PRINT** prints the contents of _list_ to the output device.
Multiple items may be separated by semi-colons or commas.
A semi-colon continues printing the following items on the same
line without a CR-LF.  A comma will move over to the next TAB stop.

> Items to print may be a literal string in double-quotes, an
integer expression to print a number, a **CHR$** expression or a
**SPC** expression.

> **CHR$**(_expression_) evaluates the _expression_ and prints the
ASCII character corresponding to the low 8 bits of the value.
The upper bits are discarded.

> **SPC**(_expression_) evaluates the _expression_ and prints
that may spaces.

> **?** may be used as an abbreviation for **PRINT**.

**Examples:**

    PRINT "The value of A is ";A
    PRINT 10,20
    PRINT "Print a double-quote: ";CHR$(34)
    PRINT SPC(20);

---

<a name="rnd"/>
### RND

**Purpose:** Generates a random number.

**Format:**
> **RND**(_expression_)

**Description:**
> **RND** evaluates the _expression_ and generates a random integer
between 0 and _expression_ - 1.

> If _expression_ is zero or negative, an error will be reported.

**Examples:**

    10 REM ROLL TWO DICE 3 TIMES
    20 FOR I = 1 TO 3
    30 PRINT RND(6)+1,RND(6)+1
    40 NEXT I
    RUN
    4       6
    1       2
    3       1

    PRINT RND(0)
    ILLEGAL FUNCTION CALL

**Errors**:
> `ILLEGAL FUNCTION CALL` - The value of _expression_ was zero or negative.

---

<a name="rem"/>
### REM

**Purpose:** Adds a comment, remark, or reminder to the code.

**Format:**
> **REM** _remark_

**Description:**
> **REM** skips the rest of the current line and resumes execution
with the next line.  It is used to add comments to the code.

**Examples:**

    10 REM THIS IS A COMMENT
    20 K = 1024 : REM NUMBER OF BYTES IN A KB

---

<a name="run"/>
### RUN

**Purpose:** Starts running the program.

**Format:**
> **RUN** [_linenumber_]

**Description:**
> **RUN** clears all variables to zero and starts running the program.
If _linenumber_ is supplied, then the program starts running at that line.

**Examples:**

    RUN
    RUN 100

**Errors**:
> `INVALID LINE NUMBER` - The _linenumber_ is not between 1 and 31999.

---

<a name="save"/>
### SAVE

**Purpose:** Saves the program to secondary storage.

**Format:**
> **SAVE** ["_filename_"]

**Description:**
> Saves the program in memory to secondary storage.  Without a _filename_,
usually saves to a default source like a cassette tape.  With a _filename_,
saves to a file on disk.

**Examples:**

    SAVE
    SAVE "hello.bas"

**Errors**:
> `MISSING OPERAND` - The _filename_ is required but was not supplied.<br/>
`INVALID FILENAME` - The _filename_ is not valid or could not be created.

---

<a name="size"/>
### SIZE

**Purpose:** Prints memory size information for the program and variables.

**Format:**
> **SIZE**

**Description:**
> Prints memory size information.

**Examples:**

    SIZE
    PROG:   796 BYTES
    VARS:   484 BYTES
    FREE: 31488 BYTES

---

<a name="spc"/>
### SPC

**Purpose:** Prints a specified number of spaces.

**Format:**
> **PRINT SPC**(_expression_)

**Description:**
> **SPC**(_expression_) evaluates the _expression_ and prints
that may spaces.  If _expression_ is negative, it will be
treated the same as zero.

> **SPC** can only be used from within a **PRINT** statement as the
language does not support string variables.

**Examples:**

    10 PRINT "A";SPC(5);"B"
    RUN
    A     B

---
