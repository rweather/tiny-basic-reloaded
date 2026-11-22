
.PHONY: all clean run

VASM = vasm6502_oldstyle
VASM_OPTIONS = -quiet -dotdir -Fbin -I.
EMULATOR = ../../emulators/6502/emulator-6502

IL_SOURCE = ../../IL/tiny-basic-reloaded.il
CONVERT_IL = python3 ../../python-tools/il-to-6502.py

TB_SOURCES = \
	tb-bytecode.s \
	tb-core.s

TARGETS = \
	target-emul.rom \
	target-eater.rom
LIST_FILES = \
	target-emul.lst \
	target-eater.lst

all: $(TARGETS)

target-emul.rom: target-emul.s $(TB_SOURCES)
	$(VASM) $(VASM_OPTIONS) -L target-emul.lst -o $@ target-emul.s

target-eater.rom: target-eater.s $(TB_SOURCES)
	$(VASM) $(VASM_OPTIONS) -c02 -L target-eater.lst -o $@ target-eater.s

tb-bytecode.s: $(IL_SOURCE)
	$(CONVERT_IL) $@ $<

run: all
	$(EMULATOR) -t target-emul.rom

clean:
	rm -f $(TARGETS) $(LIST_FILES) tb-bytecode.s
