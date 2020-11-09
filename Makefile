#
# Makefile
#
# Copyright (C) 2010 Creytiv.com
#

# Master version number
VER_MAJOR := 1
VER_MINOR := 1
VER_PATCH := 0
VER_ABI   := 1

PROJECT   := re
VERSION   := $(VER_MAJOR).$(VER_MINOR).$(VER_PATCH)

MK	:= mk/re.mk

include $(MK)

# List of modules
MODULES += sip sipevent sipreg sipsess
MODULES += uri http httpauth msg websock
MODULES += stun turn ice
MODULES += natbd
MODULES += rtp sdp jbuf telev
MODULES += dns
MODULES += md5 crc32 sha hmac base64
MODULES += udp sa net tcp tls
MODULES += list mbuf hash
MODULES += fmt tmr main mem dbg sys lock mqueue
MODULES += mod conf
MODULES += bfcp
MODULES += aes srtp
MODULES += odict
MODULES += json
MODULES += rtmp

INSTALL := install
ifeq ($(DESTDIR),)
PREFIX  ?= /usr/local
else
PREFIX  ?= /usr
endif
ifeq ($(LIBDIR),)
LIBDIR  := $(PREFIX)/lib
endif
INCDIR  := $(PREFIX)/include/re
MKDIR   := $(PREFIX)/share/re
CFLAGS	+= -Iinclude

MODMKS         := $(patsubst %,src/%/mod.mk,$(MODULES))
SHARED         := libre$(LIB_SUFFIX)
SHARED_SONAME  := libre$(LIB_SUFFIX).$(VER_ABI)
STATIC         := libre.a

ifeq ($(OS),linux)
SH_LFLAGS      += -Wl,-soname,$(SHARED_SONAME)
endif

include $(MODMKS)


OBJS	?= $(patsubst %.c,$(BUILD)/%.o,$(SRCS))


all: $(SHARED) $(STATIC)


-include $(OBJS:.o=.d)


$(SHARED): $(OBJS)
	@echo "  LD      $@"
	@$(LD) $(LFLAGS) $(SH_LFLAGS) $^ $(LIBS) -o $@


$(STATIC): $(OBJS)
	@echo "  AR      $@"
	@$(AR) $(AFLAGS) $@ $^
ifneq ($(RANLIB),)
	@$(RANLIB) $@
endif

libre.pc:
	@echo 'prefix='$(PREFIX) > libre.pc
	@echo 'exec_prefix=$${prefix}' >> libre.pc
	@echo 'libdir=$(LIBDIR)' >> libre.pc
	@echo 'includedir=$${prefix}/include/re' >> libre.pc
	@echo '' >> libre.pc
	@echo 'Name: libre' >> libre.pc
	@echo 'Description: ' >> libre.pc
	@echo 'Version: '$(VERSION) >> libre.pc
	@echo 'URL: http://creytiv.com/re.html' >> libre.pc
	@echo 'Libs: -L$${libdir} -lre' >> libre.pc
	@echo 'Libs.private: -L$${libdir} -lre ${LIBS}' >> libre.pc
	@echo 'Cflags: -I$${includedir}' >> libre.pc

$(BUILD)/%.o: src/%.c $(BUILD) Makefile $(MK) $(MODMKS)
	@echo "  CC      $@"
	@$(CC) $(CFLAGS) -c $< -o $@ $(DFLAGS)


$(BUILD): Makefile $(MK) $(MODMKS)
	@mkdir -p $(patsubst %,$(BUILD)/%,$(sort $(dir $(SRCS))))
	@touch $@


.PHONY: clean
clean:
	@rm -rf $(SHARED) $(STATIC) libre.pc test.d test.o test $(BUILD)


install: $(SHARED) $(STATIC) libre.pc
	@mkdir -p $(DESTDIR)$(LIBDIR) $(DESTDIR)$(LIBDIR)/pkgconfig \
		$(DESTDIR)$(INCDIR) $(DESTDIR)$(MKDIR)
	$(INSTALL) -m 0644 $(shell find include -name "*.h") \
		$(DESTDIR)$(INCDIR)
ifeq ($(OS),linux)
	$(INSTALL) -m 0755 $(SHARED) $(DESTDIR)$(LIBDIR)/$(SHARED_SONAME)
	cd $(DESTDIR)$(LIBDIR) && ln -sf $(SHARED_SONAME) $(SHARED)
else
	$(INSTALL) -m 0755 $(SHARED) $(DESTDIR)$(LIBDIR)
endif
	$(INSTALL) -m 0755 $(STATIC) $(DESTDIR)$(LIBDIR)
	$(INSTALL) -m 0644 libre.pc $(DESTDIR)$(LIBDIR)/pkgconfig
	$(INSTALL) -m 0644 $(MK) $(DESTDIR)$(MKDIR)

uninstall:
	@rm -rf $(DESTDIR)$(INCDIR)
	@rm -rf $(DESTDIR)$(MKDIR)
	@rm -f $(DESTDIR)$(LIBDIR)/$(SHARED)
	@rm -f $(DESTDIR)$(LIBDIR)/$(SHARED_SONAME)
	@rm -f $(DESTDIR)$(LIBDIR)/$(STATIC)
	@rm -f $(DESTDIR)$(LIBDIR)/pkgconfig/libre.pc

-include test.d

test.o:	test.c Makefile $(MK)
	@echo "  CC      $@"
	@$(CC) $(CFLAGS) -c $< -o $@ $(DFLAGS)

test$(BIN_SUFFIX): test.o $(SHARED) $(STATIC)
	@echo "  LD      $@"
	@$(LD) $(LFLAGS) $< -L. -lre $(LIBS) -o $@

sym:	$(SHARED)
	@nm $(SHARED) | grep " U " | perl -pe 's/\s*U\s+(.*)/$${1}/' \
		> docs/symbols.txt
	@echo "$(SHARED) is using `cat docs/symbols.txt | wc -l ` symbols"
