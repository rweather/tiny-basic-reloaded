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

# 'code'        Bytecode value for the instruction
# 'args'        Arguments in the assembly code form
# 'ctl_stack'   Effect on the control stack (IL subroutine calls)
# 'sub_stack'   Effect on the subroutine stack (BASIC subroutine calls)
# 'ae_stack'    Effect on the arithmetic expression stack
# 'change_flow' True if the instruction jumps elsewhere and doesn't come back

instructions = {
    # Instructions for the original Tiny BASIC design.
    'TST':      { 'code': 0x00, 'args': ['label8', 'string'] },
    'CALL':     { 'code': 0x01, 'args': ['label16'], 'ctl_stack': ['push'] },
    'JMP':      { 'code': 0x02, 'args': ['label16'], 'change_flow': True },
    'HOP':      { 'code': 0x02, 'args': ['label16'], 'change_flow': True }, # alias for 'JMP'
    'RTN':      { 'code': 0x03, 'ctl_stack': ['pop'], 'change_flow': True },
    'DONE':     { 'code': 0x04 },
    'PRS':      { 'code': 0x05 },
    'PRN':      { 'code': 0x06, 'ae_stack': ['pop'] },
    'SPC':      { 'code': 0x07 },
    'NLINE':    { 'code': 0x08 },
    'NXT':      { 'code': 0x09, 'change_flow': True },
    'RNXT':     { 'code': 0x0A, 'change_flow': True },
    'XFER':     { 'code': 0x0B, 'ae_stack': ['pop'] },
    'SAV':      { 'code': 0x0C, 'sub_stack': ['push'] },
    'RSTR':     { 'code': 0x0D, 'sub_stack': ['pop'], 'change_flow': True },
    'CMPR':     { 'code': 0x0E, 'ae_stack': ['pop3'] },
    'INNUM':    { 'code': 0x0F, 'ae_stack': ['push'] },
    'FIN':      { 'code': 0x10, 'change_flow': True },
    'ERR':      { 'code': 0x11, 'change_flow': True },
    'ADD':      { 'code': 0x12, 'ae_stack': ['pop2', 'push'] },
    'SUB':      { 'code': 0x13, 'ae_stack': ['pop2', 'push'] },
    'NEG':      { 'code': 0x14, 'ae_stack': ['pop', 'push'] },
    'MPY':      { 'code': 0x15, 'ae_stack': ['pop2', 'push'] },
    'DIV':      { 'code': 0x16, 'ae_stack': ['pop2', 'push'] },
    'LIT':      { 'code': 0x17, 'args': ['literal8'] },
    'STORE':    { 'code': 0x18, 'ae_stack': ['pop2'] },
    'TSTV':     { 'code': 0x19, 'args': ['label8'], 'ae_stack': ['push'] },
    'TSTN':     { 'code': 0x1A, 'args': ['label8'], 'ae_stack': ['push'] },
    'TSTL':     { 'code': 0x1B, 'args': ['label8'], 'ae_stack': ['push'] },
    'INSRT':    { 'code': 0x1C, 'ae_stack': ['pop'] },
    'INIT':     { 'code': 0x1D },
    'XINIT':    { 'code': 0x1E },
    'GETLN':    { 'code': 0x1F },
    'LST':      { 'code': 0x20 },
    'IND':      { 'code': 0x21, 'ae_stack': ['pop', 'push'] },

    # Instructions for Tiny BASIC Extended / TBX.
    'ARRAY1':   { 'code': 0x30, 'ae_stack': ['pop2', 'push'] },
    'ARRAY2':   { 'code': 0x31, 'ae_stack': ['pop3', 'push'] },
    'DIM1':     { 'code': 0x32, 'ae_stack': ['pop2'] },
    'DIM2':     { 'code': 0x33, 'ae_stack': ['pop3'] },
    'DONEX':    { 'code': 0x34 },
    'FOR':      { 'code': 0x35, 'ae_stack': ['push'] },
    'NEXT':     { 'code': 0x36 },
    'NXTX':     { 'code': 0x37 },
    'LIST0':    { 'code': 0x38 },
    'LIST1':    { 'code': 0x39, 'ae_stack': ['pop'] },
    'LIST2':    { 'code': 0x3A, 'ae_stack': ['pop2'] },
    'RANDOM':   { 'code': 0x3B, 'ae_stack': ['push'] },
    'SIZE':     { 'code': 0x3C },
    'SPCONE':   { 'code': 0x3D },
    'TAB':      { 'code': 0x3E, 'ae_stack': ['pop'] },
    'TSTA':     { 'code': 0x3F, 'args': ['label8'], 'ae_stack': ['push'] },
}
