# Fluxfonts – a continual font generator for increased privacy
# Copyright 2012–2016, Daniel Aleksandersen
# All rights reserved.
#
# This file is part of Fluxfonts.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# • Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
#
# • Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

SHELL = /bin/sh

NAME  = Fluxfonts
LNAME = fluxfonts
PROGRAM = fluxfontd
REVERSE_DOMAIN = no.priv.daniel.$(LNAME)
SHORTDESC = $(NAME), a continual font generator for increased privacy.
LONGDDESC = The $(PROGRAM) daemon for $(SHORTDESC)

VERSION = 1.1
AUTHOR = Daniel Aleksandersen

SRCS = main.c $(wildcard lib/*.c) $(wildcard lib/tables/*.c)
DOCS = AUTHORS COPYING README

# directories
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/$(LNAME)
TEMPDIR = /var/tmp
LAUNCHDDIR = /Library/LaunchDaemons
LAUNCHDCONF = $(LAUNCHDDIR)/$(LNAME).plist
SYSTEMDDIR = /usr/lib/systemd/system
SYSTEMDCONF = $(SYSTEMDDIR)/$(LNAME).system
DISTROOTDIR = $(TEMPDIR)/$(LNAME).dist
DISTPKGDIR = $(DISTROOTDIR)/dest_root
DISTSCRIPTSDIR = $(DISTROOTDIR)/scripts
OSXPKGPOSTINSTALL = $(DISTSCRIPTSDIR)/postinstall

# OS differences from GNU/Linuses
ifeq ($(shell sh -c 'uname -s'),FreeBSD)
INSTALLFLAGS = -S
LDFLAGS += -liconv -L/usr/local/lib
CFLAGS += -I/usr/local/include
endif
ifeq ($(shell sh -c 'uname -s'),Darwin)
INSTALLFLAGS = -S
LDFLAGS += -liconv
OTHARCH = -arch x86_64 -arch i386
PACKAGE_OSX = $(NAME)-$(VERSION).pkg
TEMPDIR = /private/var/tmp
endif

# programs and compiler
INSTALL_PROGRAM = /usr/bin/install
LAUNCHDUTIL = /bin/launchctl
DEFAULTSUTIL = /usr/bin/defaults
SERVICEUTIL = /usr/sbin/service
INITDEFUTIL = /sbin/insserv
OSXPKGBUILD = /usr/bin/pkgbuild
CC ?= clang
CFLAGS += -Wall -std=c99 -g

# launchd or systemd based on available directories
ifneq ($(wildcard $(SYSTEMDDIR)),)
CONFIG_SYSTEMD = install-systemd
DECONFIG_SYSTEMD = deconfigure-systemd
endif

ifneq ($(wildcard $(LAUNCHDDIR)),)
CONFIG_LAUNCHD = install-launchd
DECONFIG_LAUNCHD = deconfigure-launchd
endif


# sources for daemon configuration files
define newline


endef

define LAUNCHDCONF-SRC
$(DEFAULTSUTIL) write $(DISTPKGDIR)$(LAUNCHDCONF) RunAtLoad -boolean TRUE
$(DEFAULTSUTIL) write $(DISTPKGDIR)$(LAUNCHDCONF) Label -string $(REVERSE_DOMAIN)
$(DEFAULTSUTIL) write $(DISTPKGDIR)$(LAUNCHDCONF) ProgramArguments -array-add $(BINDIR)/$(PROGRAM)

endef

define SYSTEMDCONF-SRC
[Unit]
Description=$(SHORTDESC)

[Service]
Type=forking
ExecStart=$(BINDIR)/$(PROGRAM)

[Install]
WantedBy=multi-user.target

endef

all: build

build: $(SRCS)
	$(CC) $(LDFLAGS) $(CFLAGS) $(OTHARCH) $(SRCS) -o $(PROGRAM) -lm

install: build
	$(INSTALL_PROGRAM) -d $(DESTDIR)$(BINDIR)
	$(INSTALL_PROGRAM) $(INSTALLFLAGS) $(PROGRAM) $(DESTDIR)$(BINDIR)

install-all: build install install-doc install-daemon

install-doc:
	$(INSTALL_PROGRAM) -d $(DESTDIR)$(DOCDIR)
	$(INSTALL_PROGRAM) $(INSTALLFLAGS) $(DOCS) $(DESTDIR)$(DOCDIR)

install-daemon: $(CONFIG_LAUNCHD) $(CONFIG_SYSTEMD)

install-dist-osx: $(NAME)-$(VERSION).pkg
	/usr/sbin/installer --pkg $(NAME)-$(VERSION).pkg --PROGRAM /

uninstall: $(DECONFIG_LAUNCHD) $(DECONFIG_SYSTEMD)
	rm $(BINDIR)/$(PROGRAM)
	rm -rf $(DOCDIR)

configure-launchd:
	-rm $(DISTPKGDIR)$(LAUNCHDCONF)
	$(INSTALL_PROGRAM) -d $(DISTPKGDIR)$(LAUNCHDDIR)
	$(LAUNCHDCONF-SRC)

install-launchd: configure-launchd
	$(INSTALL_PROGRAM) -d $(DESTDIR)$(LAUNCHDDIR)
	$(INSTALL_PROGRAM) $(DISTPKGDIR)$(LAUNCHDCONF) $(DESTDIR)$(LAUNCHDDIR)
	$(LAUNCHDUTIL) load $(DESTDIR)$(LAUNCHDCONF)

deconfigure-launchd:
	-$(LAUNCHDUTIL) unload $(LAUNCHDCONF)
	-rm $(LAUNCHDCONF)

configure-systemd:
	-rm $(DISTPKGDIR)$(SYSTEMDCONF)
	$(INSTALL_PROGRAM) -d $(DISTPKGDIR)$(SYSTEMDDIR)
	printf '$(subst $(newline),\n,${SYSTEMDCONF-SRC})' > $(DISTPKGDIR)$(SYSTEMDCONF)

install-systemd: configure-systemd
	$(INSTALL_PROGRAM) -d $(DESTDIR)$(SYSTEMDDIR)
	$(INSTALL_PROGRAM) $(DISTPKGDIR)$(SYSTEMDCONF) $(DESTDIR)$(SYSTEMDDIR)

deconfigure-systemd:
	-rm $(SYSTEMDCONF)

dist: $(PACKAGE_OSX)

$(NAME)-$(VERSION).pkg: all configure-launchd
	-rm $(NAME)-$(VERSION).pkg
	$(INSTALL_PROGRAM) -d $(DISTPKGDIR)$(BINDIR)
	$(INSTALL_PROGRAM) -d $(DISTPKGDIR)$(LAUNCHDDIR)
	$(INSTALL_PROGRAM) -d $(DISTSCRIPTSDIR)
	$(INSTALL_PROGRAM) -d $(DISTPKGDIR)$(DOCDIR)
	$(INSTALL_PROGRAM) $(INSTALLFLAGS) $(PROGRAM) $(DISTPKGDIR)$(BINDIR)
	$(INSTALL_PROGRAM) $(INSTALLFLAGS) $(DOCS) $(DISTPKGDIR)$(DOCDIR)
	echo "#!$(SHELL)\n$(LAUNCHDUTIL) load $(LAUNCHDCONF)\nexit 0" > $(OSXPKGPOSTINSTALL)
	chmod +x $(OSXPKGPOSTINSTALL)
	$(OSXPKGBUILD) --identifier $(REVERSE_DOMAIN) --version $(VERSION) --root $(DISTPKGDIR) --ownership recommended --scripts $(DISTSCRIPTSDIR) $(NAME)-$(VERSION).pkg

$(LNAME)-$(VERSION).tar.gz: maintainer-clean
	mkdir $(TEMPDIR)/$(LNAME)-$(VERSION)
	cp -r . $(TEMPDIR)/$(LNAME)-$(VERSION)
	-rm -rf $(TEMPDIR)/$(LNAME)-$(VERSION)/.*
	mv $(TEMPDIR)/$(LNAME)-$(VERSION) ./
	tar -c -z -f $(LNAME)-$(VERSION).tar.gz $(LNAME)-$(VERSION)

clean:
	-rm -rf $(PROGRAM).dSYM

distclean:
	-rm -rf $(DISTROOTDIR) $(TEMPDIR)/$(NAME)-$(VERSION) $(LNAME)-$(VERSION)/ $(NAME)-$(VERSION).pkg $(LNAME)-$(VERSION).tar.gz

maintainer-clean: clean distclean
	-rm -rf $(PROGRAM) *~ */*~ */*/*~
