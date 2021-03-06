ifeq ($(OS), Windows_NT)

PLAT=win
EXE=.exe
ROOT64=$(shell stack path --programs)\..\x86_64-windows\ghc-8.6.5\mingw
ROOT32=$(shell stack path --programs)\..\i386-windows\ghc-8.6.5\mingw
CC=$(ROOT64)\bin\gcc
CC32=$(ROOT32)\bin\gcc
CPPFLAGS=-D_WIN32_WINNT=0x600 -DIS32=0 -isystem$(ROOT64)\x86_64-w64-mingw32\include\ddk
CPPFLAGS32=-D_WIN32_WINNT=0x600 -DIS32=1 -isystem$(ROOT32)\i686-w64-mingw32\include\ddk
OSSRCS=src/win/inject.c src/win/dbg.c
LDOBJS=$(ROOT64)\x86_64-w64-mingw32\lib\CRT_noglob.o
INSTALLDIR=$(APPDATA)\local\bin

else

PLAT=unix
CPPFLAGS=-D_GNU_SOURCE -D_DEFAULT_SOURCE=1
LDFLAGS=-g

OS=$(shell uname -s)
LS=$(shell which ls)

ifeq ($(OS),Linux)
LDLIBS=-ldl -lrt
endif

INSTALLDIR=$(HOME)/.local/bin

endif

CFLAGS+= -g -std=c99 -Wall -O0 -fno-omit-frame-pointer -fno-stack-protector -MMD

SRCS=src/fsatrace.c src/$(PLAT)/proc.c src/$(PLAT)/shm.c $(OSSRCS)

all: fsatrace$(EXE) lib fsatest$(EXE) fsatest32$(EXE)

fsatrace$(EXE): $(patsubst %.c,%.o,$(SRCS))
	$(CC) $(LDFLAGS) $(LDOBJS) $^ $(LDLIBS) -o $@

fsatest$(EXE): src/fsatest.o
	$(CC) $^ -o $@

dumpargs$(EXE): dumpargs.o
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

install: fsatrace$(EXE) libinstall
	cp $< $(INSTALLDIR)

clean: cleanlib
	rm -f fsatrace$(EXE) $(patsubst %.c,%.o,$(SRCS)) $(patsubst %.c,%.d,$(SRCS))

test: all
	./fsatrace$(EXE) wrmdqt - -- cp $(LS) /tmp/foo
	./fsatrace$(EXE) wrmdqt - -- mv -f /tmp/foo /tmp/bar
	./fsatrace$(EXE) wrmdqt - -- gzip -f /tmp/bar
	./fsatrace$(EXE) wrmdqt - -- touch /tmp/bar
	./fsatrace$(EXE) wrmdqt - -- rm -f /tmp/bar
	./fsatrace$(EXE) wrmdqt - -- $(CC) -c -D_GNU_SOURCE -D_BSD_SOURCE=1 -std=c99 -Wall src/fsatrace.c -o /tmp/fsatrace.o
	./fsatrace$(EXE) wrmdqt - -- sh -c "cp $(LS) /tmp/foo && mv -f /tmp/foo /tmp/bar && rm -f /tmp/bar"
	./fsatrace$(EXE) wrmdqt - -- sh -c "cp $(LS) /tmp/foo && mv -f /tmp/foo /tmp/bar && rm -f /tmp/bar" # twice, when dst exists it might use another path

htest: all
	cd test && stack install && stack test


-include $(patsubst %.c,%.d,$(SRCS))

include $(PLAT).mk
