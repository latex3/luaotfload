# Makefile for luaotfload

NAME		= luaotfload
LUAOTFLOAD	= $(wildcard luaotfload-*.lua) luaotfload-blacklist.cnf

GLYPHSCRIPT	= mkglyphlist
GLYPHSOURCE	= glyphlist.txt
CHARSCRIPT	= mkcharacters
STATUSSCRIPT	= mkstatus

RESOURCESCRIPTS = $(GLYPHSCRIPT) $(CHARSCRIPT) $(STATUSSCRIPT)

SCRIPTNAME	= luaotfload-tool
SCRIPT		= $(SCRIPTNAME).lua

DOCSRCDIR	= ./doc
GRAPH		= filegraph
DOCSRC		= $(DOCSRCDIR)/$(NAME).dtx
GRAPHSRC	= $(DOCSRCDIR)/$(GRAPH).dot
MANSRC		= $(DOCSRCDIR)/$(SCRIPTNAME).rst

DOCPDF		= $(DOCSRCDIR)/$(NAME).pdf
DOTPDF		= $(DOCSRCDIR)/$(GRAPH).pdf
MANPAGE		= $(DOCSRCDIR)/$(SCRIPTNAME).1

DOCS		= $(DOCPDF) $(DOTPDF) $(MANPAGE)

# Files grouped by generation mode
GLYPHS		= luaotfload-glyphlist.lua
CHARS		= luaotfload-characters.lua
STATUS		= luaotfload-status.lua
RESOURCES	= $(GLYPHS) $(CHARS) $(STATUS)
SOURCE		= $(DOCSRC) $(MANSRC) $(LUAOTFLOAD) README Makefile NEWS $(RESOURCESCRIPTS)

# Files grouped by installation location
SCRIPTSTATUS	= $(SCRIPT) $(OLDSCRIPT) $(RESOURCESCRIPTS)
RUNSTATUS	= $(UNPACKED) $(filter-out $(SCRIPTSTATUS),$(LUAOTFLOAD))
DOCSTATUS	= $(DOCPDF) $(DOTPDF) README NEWS
MANSTATUS	= $(MANPAGE)
SRCSTATUS	= $(DOCSRC) $(MANSRC) $(GRAPHSRC) Makefile

# The following definitions should be equivalent
# ALL_STATUS = $(RUNSTATUS) $(DOCSTATUS) $(SRCSTATUS)
ALL_STATUS = $(RESOURCES) $(SOURCE)

# Installation locations
FORMAT = luatex
SCRIPTDIR	= $(TEXMFROOT)/scripts/$(NAME)
RUNDIR		= $(TEXMFROOT)/tex/$(FORMAT)/$(NAME)
DOCDIR		= $(TEXMFROOT)/doc/$(FORMAT)/$(NAME)
MANDIR		= $(TEXMFROOT)/doc/man/man1/
SRCDIR		= $(TEXMFROOT)/source/$(FORMAT)/$(NAME)
TEXMFROOT	= $(shell kpsewhich --var-value TEXMFHOME)

# CTAN-friendly subdirectory for packaging
DISTDIR		= ./$(NAME)

CTAN_ZIP	= $(NAME).zip
TDS_ZIP		= $(NAME).tds.zip
ZIPS		= $(CTAN_ZIP) $(TDS_ZIP)

LUA		= texlua

DO_GLYPHS	= $(LUA) $(GLYPHSCRIPT) > /dev/null
DO_CHARS	= $(LUA) $(CHARSCRIPT)  > /dev/null
DO_STATUS	= $(LUA) $(STATUSSCRIPT)  > /dev/null

all: $(GENERATED)
unpack: $(UNPACKED)
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

$(GLYPHS): /dev/null
	$(DO_GLYPHS)

$(CHARS): /dev/null
	$(DO_CHARS)

$(STATUS): /dev/null
	$(DO_STATUS)

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
@mkdir -p $(RUNDIR) && cp -- $(RUNSTATUS) $(RUNDIR)
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

clean:
	$(MAKE) -C $(DOCSRCDIR) $@
	@$(RM) -- *.log *.aux *.toc *.idx *.ind *.ilg *.out

mrproper: clean
	$(MAKE) -C $(DOCSRCDIR) $@
	@$(RM) -- $(GENERATED) $(ZIPS) $(GLYPHSOURCE)
	@$(RM) -r -- $(DISTDIR)

# vim:set noexpandtab:tabstop=8:shiftwidth=2
