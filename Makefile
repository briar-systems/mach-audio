# mach-audio build helpers.
#
# the pure-mach layer builds with `mach` alone. the device layer additionally
# needs the vendored miniaudio translation unit (vendor/mad.c) compiled to a
# shared library, which `mach` then links by name (`[os.linux] libs`). that C
# compile is the one step outside `mach`, so it lives here.
#
# the library is shared (not a static archive) for the same reason mach-glfw
# links a shared GLFW: it keeps miniaudio's own libc/pthread/dl/m dependencies
# inside the .so, resolved by the dynamic loader at run time, instead of
# surfacing them into every mach binary. builds pass `-L $(BUILD)` so `mach`
# finds it; running needs it on the loader path (LD_LIBRARY_PATH=$(BUILD)).

CC      ?= cc
CFLAGS  ?= -O2 -fPIC -w
LDLIBS  ?= -lpthread -lm -ldl

BUILD   := build
SHARED  := $(BUILD)/libminiaudio.so

MACHFLAGS := -L $(BUILD)

.PHONY: all lib build test play clean

# build the miniaudio shared library, then every mach artifact.
all: build

# compile the vendored miniaudio device shim into a shared library.
lib: $(SHARED)

$(SHARED): vendor/mad.c vendor/miniaudio.h
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -shared vendor/mad.c -o $(SHARED) $(LDLIBS)

# build all mach artifacts (the shared library is a link input, so build it first).
build: $(SHARED)
	mach build . $(MACHFLAGS)

# run the display-free test suite (links the shared library; the tests open no device).
test: $(SHARED)
	LD_LIBRARY_PATH=$(BUILD) mach test . --lib audio $(MACHFLAGS)

# build and run the decode-mix-play example on a WAV file: `make play WAV=foo.wav`.
play: $(SHARED)
	LD_LIBRARY_PATH=$(BUILD) mach run . --bin play $(MACHFLAGS) -- $(WAV)

clean:
	rm -rf $(BUILD) out
