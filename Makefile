# Makefile for luaotfload

NAME		= luaotfload

DOCSRCDIR	= ./doc
SCRIPTSRCDIR	= ./scripts
SRCSRCDIR	= ./src
BUILDDIR	= ./build
MISCDIR		= ./misc

SRC		= $(wildcard $(SRCSRCDIR)/luaotfload-*.lua)
SRC		+= $(SRCSRCDIR)/luaotfload.sty
SRC		+= $(MISCDIR)/luaotfload-blacklist.cnf

GLYPHSCRIPT	= $(SCRIPTSRCDIR)/mkglyphlist
CHARSCRIPT	= $(SCRIPTSRCDIR)/mkcharacters
STATUSSCRIPT	= $(SCRIPTSRCDIR)/mkstatus

GLYPHSOURCE	= $(BUILDDIR)/glyphlist.txt

RESOURCESCRIPTS = $(GLYPHSCRIPT) $(CHARSCRIPT) $(STATUSSCRIPT)

TOOLNAME	= luaotfload-tool
TOOL		= $(SRCSRCDIR)/$(TOOLNAME).lua

GRAPH		= filegraph
DOCSRC		= $(DOCSRCDIR)/$(NAME).dtx
GRAPHSRC	= $(DOCSRCDIR)/$(GRAPH).dot
MANSRC		= $(DOCSRCDIR)/$(TOOLNAME).rst

DOCPDF		= $(DOCSRCDIR)/$(NAME).pdf
DOTPDF		= $(DOCSRCDIR)/$(GRAPH).pdf
MANPAGE		= $(DOCSRCDIR)/$(TOOLNAME).1

DOCS		= $(DOCPDF) $(DOTPDF) $(MANPAGE)

# Files grouped by generation mode
GLYPHS		= $(BUILDDIR)/$(NAME)-glyphlist.lua
CHARS		= $(BUILDDIR)/$(NAME)-characters.lua
STATUS		= $(BUILDDIR)/$(NAME)-status.lua
RESOURCES	= $(GLYPHS) $(CHARS) $(STATUS)
SOURCE		= $(DOCSRC) $(MANSRC) $(SRC) README Makefile NEWS $(RESOURCESCRIPTS)

# Files grouped by installation location
SCRIPTSTATUS	= $(TOOL) $(RESOURCESCRIPTS)
RUNSTATUS	= $(filter-out $(SCRIPTSTATUS),$(SRC))
DOCSTATUS	= $(DOCPDF) $(DOTPDF) README NEWS
MANSTATUS	= $(MANPAGE)
SRCSTATUS	= $(DOCSRC) $(MANSRC) $(GRAPHSRC) Makefile

# The following definitions should be equivalent
# ALL_STATUS = $(RUNSTATUS) $(DOCSTATUS) $(SRCSTATUS)
ALL_STATUS 	= $(RESOURCES) $(SOURCE)

# Installation locations
FORMAT 		= luatex
SCRIPTDIR	= $(TEXMFROOT)/scripts/$(NAME)
RUNDIR		= $(TEXMFROOT)/tex/$(FORMAT)/$(NAME)
DOCDIR		= $(TEXMFROOT)/doc/$(FORMAT)/$(NAME)
MANDIR		= $(TEXMFROOT)/doc/man/man1/
SRCDIR		= $(TEXMFROOT)/source/$(FORMAT)/$(NAME)
TEXMFROOT	= $(shell kpsewhich --var-value TEXMFHOME)

# CTAN-friendly subdirectory for packaging
DISTDIR		= $(BUILDDIR)/$(NAME)

CTAN_ZIP	= $(BUILDDIR)/$(NAME).zip
TDS_ZIP		= $(BUILDDIR)/$(NAME).tds.zip
ZIPS		= $(CTAN_ZIP) $(TDS_ZIP)

LUA		= texlua

## For now the $(BUILDDIR) is hardcoded in the scripts
## but we might just as well pass it to them by as environment
## variables.
DO_GLYPHS	= $(LUA) $(GLYPHSCRIPT) > /dev/null
DO_CHARS	= $(LUA) $(CHARSCRIPT)  > /dev/null
DO_STATUS	= $(LUA) $(STATUSSCRIPT)  > /dev/null

all: $(GENERATED)
builddir: $(BUILDDIR)
resources: $(RESOURCES)
chars: $(CHARS)
status: $(STATUS)
ctan: $(CTAN_ZIP)
tds: $(TDS_ZIP)
world: all ctan

graph: $(DOTPDF)
doc: $(DOCS)
pdf: $(DOCPDF)
manual: $(MANPAGE)

$(DOTPDF):
	@$(MAKE) -C $(DOCSRCDIR) graph

$(DOCPDF):
	@$(MAKE) -C $(DOCSRCDIR) doc

$(MANPAGE):
	@$(MAKE) -C $(DOCSRCDIR) manual

$(GLYPHS): builddir
	$(DO_GLYPHS)

$(CHARS): builddir
	$(DO_CHARS)

$(STATUS): builddir
	$(DO_STATUS)

$(BUILDDIR): /dev/null
	mkdir -p $(BUILDDIR)

define make-ctandir
@$(RM) -rf $(DISTDIR)
@mkdir -p $(DISTDIR) && cp $(SOURCE) $(COMPILED) $(DISTDIR)
endef

$(CTAN_ZIP): $(DOCS) $(SOURCE) $(COMPILED) $(TDS_ZIP)
	@echo "Making $@ for CTAN upload."
	@$(RM) -- $@
	$(make-ctandir)
	@zip -r -9 $@ $(TDS_ZIP) $(DISTDIR) >/dev/null

define run-install-doc
@mkdir -p $(DOCDIR) && cp -- $(DOCSTATUS) $(DOCDIR)
@mkdir -p $(SRCDIR) && cp -- $(SRCSTATUS) $(SRCDIR)
@mkdir -p $(MANDIR) && cp -- $(MANSTATUS) $(MANDIR)
endef

define run-install
@mkdir -p $(SCRIPTDIR) && cp -- $(SCRIPTSTATUS) $(SCRIPTDIR)
@mkdir -p $(RUNDIR)    && cp -- $(RESOURCES) $(RUNSTATUS) $(RUNDIR)
endef

$(TDS_ZIP): TEXMFROOT=./tmp-texmf
$(TDS_ZIP): $(DOCS) $(ALL_STATUS)
	@echo "Making TDS-ready archive $@."
	@$(RM) -- $@
	$(run-install-doc)
	$(run-install)
	@cd $(TEXMFROOT) && zip -9 ../$@ -r . >/dev/null
	@$(RM) -r -- $(TEXMFROOT)

.PHONY: install manifest clean mrproper

install: $(ALL_STATUS)
	@echo "Installing in '$(TEXMFROOT)'."
	$(run-install-docs)
	$(run-install)

manifest:
	@echo "Source files:"
	@for f in $(SOURCE); do echo $$f; done
	@echo ""
	@echo "Derived files:"
	@for f in $(GENERATED); do echo $$f; done

CLEANEXTS	= log aux toc idx ind ilg out
CLEANME		= $(foreach ext,$(CLEANEXTS),$(wildcard *.$(ext)))
CLEANME		+= $(foreach ext,$(CLEANEXTS),$(wildcard $(BUILDDIR)/*$(ext)))

clean:
	$(MAKE) -C $(DOCSRCDIR) $@
	@$(RM) -- $(CLEANME)

mrproper: clean
	$(MAKE) -C $(DOCSRCDIR) $@
	@$(RM) -- $(GENERATED) $(ZIPS) $(GLYPHSOURCE)
	@$(RM) -r -- $(BUILDDIR)

# vim:noexpandtab:tabstop=8:shiftwidth=2
