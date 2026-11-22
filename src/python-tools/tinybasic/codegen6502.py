#
# Copyright (C) 2026 Rhys Weatherley
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.
#

import sys
import tinybasic.insn as insn
import tinybasic.assem as assem

'''
Determine if a label for a TST instruction is self-referential.
Self-referential labels cause a syntax error.
'''
def is_self_ref(ins):
    if 'label8' in ins:
        label = ins['label8']
    elif 'label16' in ins:
        label = ins['label16']
    else:
        return False
    if 'labels' in ins:
        return label['name'] in ins['labels']
    else:
        return False

'''
Get the native 6502 name of the label associated with an instruction.
'''
def get_label_name(ins):
    if 'label8' in ins:
        label = ins['label8']
    elif 'label16' in ins:
        label = ins['label16']
    else:
        return 'TB_OP_ERR'
    return 'TB_IL_' + label['name']

'''
Backend code generator for 6502.
'''
class CodeGenerator6502:
    '''
    Initializes the code generator.
    '''
    def __init__(self, code_assem):
        self.code = code_assem
        self.lines = []
        self.tokens = []
        self.handlers = []

    '''
    Generate the lines of code for all instructions in the IL program.
    '''
    def generate(self):
        index = 0
        suppress = False
        stmt_index = 0
        func_index = 0
        for ins in self.code.code:
            # Suppress this instruction if requested.
            if suppress:
                suppress = False
                index += 1
                continue

            # Find the next instruction for look-ahead optimisation of a
            # call to an opcode handler immediately followed by "RTN".
            maybe_suppress = False
            if (index + 1) < len(self.code.code):
                next_ins = self.code.code[index + 1]
                if next_ins['opcode'] == 'RTN' and len(next_ins['labels']) == 0:
                    # May be able to suppress the next RTN.
                    maybe_suppress = True
            index += 1

            # Output the labels for the instruction.
            for label_name in ins['labels']:
                self.generate_label('TB_IL_' + label_name)

            # Output the instruction itself.
            match ins['opcode']:
                case 'CALL':
                    # JSR label.
                    self.generate_insn('jsr', get_label_name(ins))

                case 'JMP' | 'HOP':
                    # JMP label.
                    self.generate_insn('jmp', get_label_name(ins))

                case 'TST':
                    # Test for a token string.
                    token = ins['string']
                    if len(token) == 1:
                        test = 'TB_OP_TST1'
                        self.generate_insn('lda', '#' + str(ord(token)))
                    else:
                        test = 'TB_OP_TST'
                        tokid = str(self.get_token_id(token))
                        self.generate_insn('ldx', '#' + tokid)
                    if is_self_ref(ins):
                        # Self-referential label for syntax error on failure.
                        test += '_SYNTAX'
                    self.generate_insn('jsr', test)
                    if not is_self_ref(ins):
                        self.generate_insn('bne', get_label_name(ins))

                case 'TSTJ':
                    # Test for a token string with a long jump on match.
                    token = ins['string']
                    if len(token) == 1:
                        self.generate_insn('lda', '#' + str(ord(token)))
                        self.generate_insn('jsr', 'TB_OP_TST1')
                    else:
                        tokid = self.get_token_id(token)
                        self.generate_insn('ldx', '#' + str(tokid))
                        self.generate_insn('jsr', 'TB_OP_TST')
                    loc1 = ins['location']
                    loc2 = ins['label16']['location']
                    if abs(loc1 - loc2) < 15:
                        # Probably can reach the destination with a short jump.
                        self.generate_insn('beq', get_label_name(ins))
                    else:
                        self.generate_insn('bne', '*+5')
                        self.generate_insn('jmp', get_label_name(ins))

                case 'TSTV' | 'TSTA' | 'TSTN' | 'TSTL' | 'TSTB' | 'TSTCR' | 'TSTEND':
                    # Test for a variable, array, number, or other.
                    if is_self_ref(ins):
                        # Self-referential label for syntax error on failure.
                        self.generate_insn('jsr', 'TB_OP_' + ins['opcode'] + '_SYNTAX')
                    else:
                        self.generate_insn('jsr', 'TB_OP_' + ins['opcode'])
                        self.generate_insn('bne', get_label_name(ins))

                case 'TSTOP':
                    # Test for an operator.
                    tokid = self.get_token_id(ins['string'])
                    opid = self.get_token_handler('TB_OP_' + ins['operator_name'] + '_APPLY')
                    self.generate_insn('ldx', '#' + str(tokid))
                    self.generate_insn('ldy', '#' + str(opid))
                    self.generate_insn('jsr', 'TB_OP_TSTOP')
                    self.generate_insn('beq', get_label_name(ins))

                case 'RTN':
                    # RTS instruction only.
                    self.generate_simple('rts')

                case 'LIT':
                    # Load a 16-bit literal onto AESTK.
                    val = ins['literal16']
                    self.generate_insn('lda', '#' + str(val & 0xFF))
                    self.generate_insn('ldy', '#' + str((val >> 8) & 0xFF))
                    self.generate_insn('jsr', 'TB_PUSH_LITERAL')

                case 'CUSTOM':
                    # Custom statement handlers go here.
                    if stmt_index < len(self.code.customstmts):
                        self.generate_insn('jmp', 'TB_IL_' + self.code.customstmts[stmt_index])
                        stmt_index += 1
                    else:
                        self.generate_insn('jmp', 'TB_OP_ERR')

                case 'CUSTFN':
                    # Custom function handlers go here.
                    if len(self.code.customfuncs) != 0:
                        if func_index < len(self.code.customfuncs):
                            self.generate_insn('jmp', 'TB_IL_' + self.code.customfuncs[func_index])
                            func_index += 1
                        else:
                            # Jump to 'BEXPR' once we run out of custom
                            # function handlers.
                            self.generate_insn('jmp', 'TB_IL_BEXPR')

                case _:
                    # Default is a JSR or JMP to the opcode handler only.
                    info = ins['info']
                    if 'change_flow' in info and info['change_flow']:
                        # This instruction jumps rather than falls through.
                        op = 'jmp'
                    elif maybe_suppress:
                        # Instruction is followed by 'RTN', so we can
                        # change to a JMP and suppress the 'RTN'.
                        op = 'jmp'
                        suppress = True
                    else:
                        op = 'jsr'
                    self.generate_insn(op, 'TB_OP_' + ins['opcode'])

    '''
    Generates a label into the final code.
    '''
    def generate_label(self, name):
        self.lines.append(name + ':')

    '''
    Generates a standard instruction into the final code.
    '''
    def generate_insn(self, name, arg):
        self.lines.append('    ' + name + '     ' + arg)

    '''
    Generates a simple 1-word instruction into the final code.
    '''
    def generate_simple(self, name):
        self.lines.append('    ' + name)

    '''
    Add a token to the token table and return its offset.
    '''
    def get_token_id(self, name):
        tokid = 0
        for n in self.tokens:
            if n == name:
                return tokid
            if len(n) == 1:
                tokid += len(n) + 1
            else:
                tokid += len(n)
        self.tokens.append(name)
        if (tokid + len(name)) > 255:
            raise ValueError('token id is too big')
        return tokid

    '''
    Add a token handler to the handler table and return its offset.
    '''
    def get_token_handler(self, name):
        if name in self.handlers:
            return self.handlers.index(name) * 2
        self.handlers.append(name)
        return (len(self.handlers) - 1) * 2

    '''
    Writes the code to an output assembly file.
    '''
    def write(self, filename):
        with open(filename, 'w') as file:
            file.write('; Automatically generated; do not edit.\n\n')
            for line in self.lines:
                file.write(line + '\n')
            file.write('TB_TOKTAB:\n')
            for token in self.tokens:
                if len(token) == 1:
                    # Single-character tokens need to be NUL-terminated.
                    file.write('    .db     "%s", 0\n' % token)
                else:
                    # Multi-character tokens are high bit terminated.
                    file.write('    .db     "%s", $%02X\n' % (token[:-1], ord(token[-1:]) + 128))
            file.write('TB_TOKHAND:\n')
            for name in self.handlers:
                file.write('    .dw     %s\n' % name)
