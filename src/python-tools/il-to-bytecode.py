#!/usr/bin/python3
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

import argparse
import sys
import tinybasic.assem as assem
import tinybasic.insn as insn

# Parse the command-line arguments.
parser = argparse.ArgumentParser(
    prog='il-to-bytecode',
    description='Assembler for IL bytecode'
)
parser.add_argument(
    'output_filename',
    help='name of the output file from the assembler'
)
parser.add_argument(
    'input_filename',
    help='name of the input assembly source file'
)
parser.add_argument(
    '-c', '--c-source',
    type=str,
    default='',
    help='output C source code instead of binary, arg is the variable name'
)
args = parser.parse_args()

# Assemble the input source.
assem = assem.Assembler(args.input_filename)
with open(args.input_filename, 'r') as file:
    for line in file:
        assem.parse(line)
    assem.check_undef()
if assem.errors:
    sys.exit(1)

# Generate the raw IL bytecode and write it to the output file.
bytecode = assem.to_bytecode()
if args.c_source:
    # Output reference C definitions for the bytecode.
    name = args.c_source
    with open(args.output_filename, 'w') as file:
        file.write('/* Automatically generated, do not edit */\n\n')
        file.write('static uint8_t const %s_code[] = {\n' % name)
        offset = 0
        for code in bytecode:
            if (offset % 12) == 0:
                file.write('    0x%02X,' % code)
            elif (offset % 12) == 11:
                file.write(' 0x%02X,\n' % code)
            else:
                file.write(' 0x%02X,' % code)
            offset += 1
        if (offset % 12) != 0:
            file.write('\n')
        file.write('};\n')
        file.write('static tb_il_program_t const %s = {\n' % name);
        file.write('    .start  = %s_code,\n' % name)
        file.write('    .direct = %s_code + %d,\n' % (name, assem.get_label_address('C0')))
        file.write('    .error  = %s_code + %d,\n' % (name, assem.get_label_address('ERRENT')))
        file.write('    .next   = %s_code + %d\n' % (name, assem.get_label_address('XEC')))
        file.write('};\n')
else:
    # Output the IL in binary.
    with open(args.output_filename, 'wb') as file:
        file.write(bytes(bytecode))
