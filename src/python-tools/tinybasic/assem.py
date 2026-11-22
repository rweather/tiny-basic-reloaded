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

'''
Assemble IL bytecode into an internal form suitable for code generation.
'''
class Assembler:
    '''
    Initialize the assembler.
    '''
    def __init__(self, filename):
        self.code = []
        self.labels = {}
        self.errors = False
        self.linenum = 1
        self.filename = filename
        self.currlabels = []

    '''
    Parse a line from the assembly input.
    '''
    def parse(self, line):
        # Get and increment the line number.
        linenum = self.linenum
        self.linenum += 1

        # Strip out comments.
        comment = line.find(';')
        if comment > 0 and line[comment - 1] == "'" and line[comment + 1] == "'":
            # We may have the token ';' on the line, which is not a comment.
            comment = line.find(';', comment + 2)
        if comment != -1:
            line = line[:comment]

        # Split the line into separate fields based on whitespace.
        fields = line.strip().split()
        if len(fields) == 0:
            # Empty line, nothing to do.
            return

        # Does the line start with one or more labels?
        label_name = ''
        while len(fields) > 0 and fields[0].endswith(':'):
            label_name = fields[0][:-1].upper()
            if len(label_name) == 0:
                self.error(self.filename, linenum, 'label name is empty')
                return
            if not self.set_label(label_name, linenum):
                self.error(self.filename, linenum, 'label "%s" already defined' % label_name)
                return
            self.currlabels.append(label_name)
            fields = fields[1:]

        # If nothing left after the labels, then we're done with the line.
        if len(fields) == 0:
            return

        # Find the information about the instruction.
        currlabels = self.currlabels
        self.currlabels = []
        opcode = fields[0].upper()
        if not opcode in insn.instructions:
            self.error(self.filename, linenum, 'unknown opcode "%s"' % opcode)
            return
        info = insn.instructions[opcode]

        # Start building the code for this instruction.
        icode = {
            'location': len(self.code),
            'opcode': opcode,
            'info': info,
            'filename': self.filename,
            'line': linenum,
            'labels': currlabels
        }

        # Parse the arguments to the instruction.
        fields = fields[1:]
        if 'args' in info:
            for arg_type in info['args']:
                if len(fields) == 0:
                    self.error(self.filename, linenum, 'missing argument')
                    return
                if arg_type == 'label8' or arg_type == 'label16':
                    # Reference to a label.
                    label = self.ref_label(fields[0].upper(), linenum)
                    icode[arg_type] = label
                    if opcode == 'CALL':
                        # Remember that CALL refers to this label.
                        label['call_target'] = True
                elif arg_type == 'string':
                    # Literal string.  It is possible that there were
                    # embedded spaces in the original.  Restore them.
                    s = " ".join(fields)
                    fields = fields[-1:]
                    if s.startswith("'") and s.endswith("'"):
                        s = s[1:-1]
                    elif s.startswith('"') and s.endswith('"'):
                        s = s[1:-1]
                    else:
                        self.error(self.filename, linenum, 'invalid string format')
                        return
                    icode[arg_type] = s
                elif arg_type == 'opcode':
                    # Opcode name.
                    opcode_name = fields[0].upper()
                    if opcode_name in insn.instructions:
                        icode['operator_id'] = insn.instructions[opcode_name]['code']
                        icode['operator_name'] = opcode_name
                    else:
                        self.error(self.filename, linenum, 'invalid opcode name')
                        return
                elif arg_type == 'literal8':
                    try:
                        val = int(fields[0], 0)
                        if val < 0 or val > 255:
                            self.error(self.filename, linenum, 'literal byte value out of range')
                        icode[arg_type] = val
                    except (ValueError, TypeError):
                        self.error(self.filename, linenum, 'invalid number "%s"' % fields[0])
                        return
                elif arg_type == 'literal16':
                    try:
                        val = int(fields[0], 0)
                        if val < -32768 or val > 32767:
                            self.error(self.filename, linenum, 'literal value out of range')
                        icode[arg_type] = val
                    except (ValueError, TypeError):
                        self.error(self.filename, linenum, 'invalid number "%s"' % fields[0])
                        return
                else:
                    self.error(self.filename, linenum, 'unknown argument type "%s"' % arg_type)
                    return
                fields = fields[1:]

        # There should be nothing left on the line.
        if len(fields) != 0:
            self.error(self.filename, linenum, 'extra arguments on line')
            return

        # Add the instruction to the in-progress code and we're done!
        self.code.append(icode)

    '''
    Check for labels that were not defined in the source.
    '''
    def check_undef(self):
        for label in self.labels.values():
            if not label['is_defined']:
                self.error(label['filename'], label['linenum'], 'label "%s" is not defined' % label['name'])

    '''
    Report an error on a specific line of the file.
    '''
    def error(self, filename, linenum, text):
        print('%s:%d: %s' % (filename, linenum, text), file=sys.stderr)
        self.errors = True

    '''
    Set a label for the current line of the file.  Returns False if the
    label was already defined.
    '''
    def set_label(self, name, linenum):
        if name in self.labels:
            # Label already exists.  Bail out if we already defined it.
            label = self.labels[name]
            if label['is_defined']:
                return False

            # Define it now.
            label['location'] = len(self.code)
            label['filename'] = self.filename
            label['linenum'] = linenum
            label['is_defined'] = True
        else:
            # New label that we have not seen before.
            label = {
                'name': name,
                'location': len(self.code),
                'filename': self.filename,
                'line': linenum,
                'is_defined': True
            }
            self.labels[name] = label
        return True

    '''
    Get a reference to a label, either forwards or reverse.
    '''
    def ref_label(self, name, linenum):
        if name in self.labels:
            # Label already exists, so return it.
            return self.labels[name]
        else:
            # Forward reference to a label that we have not seen before.
            label = {
                'name': name,
                'filename': self.filename,
                'line': linenum,
                'is_defined': False
            }
            self.labels[name] = label
            return label

    '''
    Converts the code into raw IL bytecode for the reference interpreter.
    '''
    def to_bytecode(self):
        # Compute the physical address of all instructions.
        address = 0
        for icode in self.code:
            if 'labels' in icode:
                # Assign the current physical address to the labels.
                for label_name in icode['labels']:
                    label = self.labels[label_name]
                    label['address'] = address
            icode['address'] = address
            info = icode['info']
            size = 1
            if 'args' in info:
                for arg_type in info['args']:
                    if arg_type == 'label8' or arg_type == 'literal8' or arg_type == 'opcode':
                        size += 1
                    elif arg_type == 'label16' or arg_type == 'literal16':
                        size += 2
                    elif arg_type == 'string':
                        size += len(icode['string'])
            address += size

        # Generate the bytecode.
        bytecode = []
        for icode in self.code:
            info = icode['info']
            bytecode.append(info['code'])
            if 'args' in info:
                for arg_type in info['args']:
                    if arg_type == 'label8':
                        # Short branch.
                        offset = icode['label8']['address'] - icode['address']
                        if offset < -128 or offset > 127:
                            self.error(icode['filename'], icode['linenum'], 'branch out of range')
                            offset = 0
                        if offset < 0:
                            offset += 256
                        bytecode.append(offset & 0xFF)
                    elif arg_type == 'label16':
                        # Long branch.
                        offset = icode['label16']['address'] - icode['address']
                        if offset < 0:
                            offset += 65536
                        bytecode.append(offset & 0xFF)
                        bytecode.append((offset >> 8) & 0xFF)
                    elif arg_type == 'string':
                        # String argument.
                        s = icode['string']
                        for index in range(0, len(s)):
                            c = ord(s[index])
                            if index == (len(s) - 1):
                                # Last character has the high bit set.
                                c += 128
                            bytecode.append(c)
                    elif arg_type == 'opcode':
                        # Opcode number.
                        bytecode.append(icode['operator_id'])
                    elif arg_type == 'literal8':
                        # Literal 8-bit constant.
                        bytecode.append(icode['literal8'])
                    elif arg_type == 'literal16':
                        # Literal 16-bit constant.
                        lit = icode['literal16']
                        bytecode.append(lit & 255)
                        bytecode.append((lit >> 8) & 255)
        return bytecode

    '''
    Get the address of a specific label.
    '''
    def get_label_address(self, name):
        if name in self.labels:
            return self.labels[name]['address']
        return -1
