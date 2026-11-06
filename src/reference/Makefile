
.PHONY: all clean

CFLAGS = -Wall -Wextra -g

OBJECTS = \
	tb-main.o \
	tb-exec.o \
	tb-program.o \
	tb-state.o
TARGET = tiny-basic-redux

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $(TARGET) $(OBJECTS)

tb-main.o: tb-main.c tb.h
	$(CC) $(CFLAGS) -o tb-main.o -c tb-main.c

tb-exec.o: tb-exec.c tb.h
	$(CC) $(CFLAGS) -o tb-exec.o -c tb-exec.c

tb-program.o: tb-program.c tb.h
	$(CC) $(CFLAGS) -o tb-program.o -c tb-program.c

tb-state.o: tb-state.c tb.h
	$(CC) $(CFLAGS) -o tb-state.o -c tb-state.c

clean:
	rm -f $(TARGET) $(OBJECTS)
