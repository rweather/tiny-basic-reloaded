" Syntax highlighting for Tiny BASIC Intermediate Language (IL)

" Quit when a syntax file was already loaded.
if exists("b:current_syntax")
  finish
endif

" Tiny BASIC IL is case-insensitive.
syn case ignore

" Match syntactic elements.
syn match   ilComment           /;.*$/
syn match   ilLabel             /[A-Za-z_][A-Za-z0-9_]*:/
syn match   ilVariable          /[A-Za-z_][A-Za-z0-9_]*/
syn match   ilConstant          /[0-9][0-9]*/

syn match   ilOpcode            "\<TST\>"
syn match   ilOpcode            "\<CALL\>"
syn match   ilOpcode            "\<JMP\>"
syn match   ilOpcode            "\<HOP\>"
syn match   ilOpcode            "\<RTN\>"
syn match   ilOpcode            "\<DONE\>"
syn match   ilOpcode            "\<PRS\>"
syn match   ilOpcode            "\<PRN\>"
syn match   ilOpcode            "\<SPC\>"
syn match   ilOpcode            "\<NLINE\>"
syn match   ilOpcode            "\<NXT\>"
syn match   ilOpcode            "\<RNXT\>"
syn match   ilOpcode            "\<XFER\>"
syn match   ilOpcode            "\<SAV\>"
syn match   ilOpcode            "\<RSTR\>"
syn match   ilOpcode            "\<CMPR\>"
syn match   ilOpcode            "\<INNUM\>"
syn match   ilOpcode            "\<FIN\>"
syn match   ilOpcode            "\<ERR\>"
syn match   ilOpcode            "\<ADD\>"
syn match   ilOpcode            "\<SUB\>"
syn match   ilOpcode            "\<NEG\>"
syn match   ilOpcode            "\<MPY\>"
syn match   ilOpcode            "\<DIV\>"
syn match   ilOpcode            "\<LIT\>"
syn match   ilOpcode            "\<STORE\>"
syn match   ilOpcode            "\<TSTV\>"
syn match   ilOpcode            "\<TSTN\>"
syn match   ilOpcode            "\<TSTL\>"
syn match   ilOpcode            "\<INSRT\>"
syn match   ilOpcode            "\<INIT\>"
syn match   ilOpcode            "\<XINIT\>"
syn match   ilOpcode            "\<GETLN\>"
syn match   ilOpcode            "\<LST\>"
syn match   ilOpcode            "\<IND\>"

syn match   ilOpcode            "\<ARRAY1\>"
syn match   ilOpcode            "\<ARRAY2\>"
syn match   ilOpcode            "\<DIM1\>"
syn match   ilOpcode            "\<DIM2\>"
syn match   ilOpcode            "\<DONEX\>"
syn match   ilOpcode            "\<FOR\>"
syn match   ilOpcode            "\<NEXT\>"
syn match   ilOpcode            "\<NXTX\>"
syn match   ilOpcode            "\<LIST0\>"
syn match   ilOpcode            "\<LIST1\>"
syn match   ilOpcode            "\<LIST2\>"
syn match   ilOpcode            "\<RANDOM\>"
syn match   ilOpcode            "\<SIZE\>"
syn match   ilOpcode            "\<SPCONE\>"
syn match   ilOpcode            "\<TAB\>"
syn match   ilOpcode            "\<TSTA\>"
syn match   ilOpcode            "\<TSTCR\>"
syn match   ilOpcode            "\<STOREV\>"

syn match   ilOpcode            "\<END\>"
syn match   ilOpcode            "\<CHKSTK\>"
syn match   ilOpcode            "\<TSTJ\>"
syn match   ilOpcode            "\<IF\>"
syn match   ilOpcode            "\<CUSTOM\>"
syn match   ilOpcode            "\<PRC\>"
syn match   ilOpcode            "\<TSTEND\>"
syn match   ilOpcode            "\<TSTOP\>"
syn match   ilOpcode            "\<APPLY\>"
syn match   ilOpcode            "\<APPLYFN\>"
syn match   ilOpcode            "\<CUSTFN\>"
syn match   ilOpcode            "\<ASC\>"
syn match   ilOpcode            "\<POKE\>"
syn match   ilOpcode            "\<POP\>"
syn match   ilOpcode            "\<MCALL\>"
syn match   ilOpcode            "\<CLEAR\>"
syn match   ilOpcode            "\<LOAD\>"
syn match   ilOpcode            "\<SAVE\>"
syn match   ilOpcode            "\<INKEY\>"
syn match   ilOpcode            "\<TSTB\>"
syn match   ilOpcode            "\<FPMUL\>"
syn match   ilOpcode            "\<PRHEX\>"

syn match   ilOpcode            "\<BAND\>"
syn match   ilOpcode            "\<BOR\>"
syn match   ilOpcode            "\<BXOR\>"
syn match   ilOpcode            "\<BNOT\>"
syn match   ilOpcode            "\<LAND\>"
syn match   ilOpcode            "\<LOR\>"
syn match   ilOpcode            "\<LNOT\>"
syn match   ilOpcode            "\<MOD\>"
syn match   ilOpcode            "\<SHL\>"
syn match   ilOpcode            "\<SHR\>"
syn match   ilOpcode            "\<LSR\>"
syn match   ilOpcode            "\<CMPEQ\>"
syn match   ilOpcode            "\<CMPNE\>"
syn match   ilOpcode            "\<CMPLT\>"
syn match   ilOpcode            "\<CMPGT\>"
syn match   ilOpcode            "\<CMPLE\>"
syn match   ilOpcode            "\<CMPGE\>"
syn match   ilOpcode            "\<PEEK\>"

syn match   ilString            /'[^']*'/

" Set the highlighting categories.
hi def link ilComment           Comment
hi def link ilLabel             Define
hi def link ilOpcode            Statement
hi def link ilConstant          Number
hi def link ilVariable          Type
hi def link ilString            String

" Activate the language.
let b:current_syntax = "tiny-basic-il"
