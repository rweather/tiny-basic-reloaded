
.PHONY: all clean

ILTOBYTECODE = python3 ../python-tools/il-to-bytecode.py

CFLAGS = -Wall -Wextra -g

OBJECTS = \
	tb-main.o \
	tb-exec.o \
	tb-program.o \
	tb-state.o \
	tb-vars.o
TARGET = tiny-basic-reloaded

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJECTS)

tb-main.o: tb-main.c tb.h tb-bytecode-original.h tb-bytecode-extended.h
	$(CC) $(CFLAGS) -o tb-main.o -c tb-main.c

tb-exec.o: tb-exec.c tb.h
	$(CC) $(CFLAGS) -o tb-exec.o -c tb-exec.c

tb-program.o: tb-program.c tb.h
	$(CC) $(CFLAGS) -o tb-program.o -c tb-program.c

tb-state.o: tb-state.c tb.h
	$(CC) $(CFLAGS) -o tb-state.o -c tb-state.c

tb-vars.o: tb-vars.c tb.h
	$(CC) $(CFLAGS) -o tb-vars.o -c tb-vars.c

tb-bytecode-original.h: ../IL/tiny-basic-original.il
	$(ILTOBYTECODE) -c tb_original tb-bytecode-original.h ../IL/tiny-basic-original.il

tb-bytecode-extended.h: ../IL/tiny-basic-extended.il
	$(ILTOBYTECODE) -c tb_extended tb-bytecode-extended.h ../IL/tiny-basic-extended.il

clean:
	rm -f $(TARGET) $(OBJECTS)
	rm -f tb-bytecode-original.h tb-bytecode-extended.h
