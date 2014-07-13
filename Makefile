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

VGND		= $(MISCDIR)/valgrind-kpse-suppression.sup

GLYPHSCRIPT	= $(SCRIPTSRCDIR)/mkglyphlist
CHARSCRIPT	= $(SCRIPTSRCDIR)/mkcharacters
STATUSSCRIPT	= $(SCRIPTSRCDIR)/mkstatus

GLYPHSOURCE	= $(BUILDDIR)/glyphlist.txt

RESOURCESCRIPTS = $(GLYPHSCRIPT) $(CHARSCRIPT) $(STATUSSCRIPT)

TOOLNAME	= luaotfload-tool
TOOL		= $(SRCSRCDIR)/$(TOOLNAME).lua

CONFNAME	= luaotfload.conf

GRAPH		= filegraph
DOCSRC		= $(addprefix $(DOCSRCDIR)/$(NAME), -main.tex -latex.tex)
GRAPHSRC	= $(DOCSRCDIR)/$(GRAPH).dot
MANSRC		= $(DOCSRCDIR)/$(TOOLNAME).rst $(DOCSRCDIR)/$(CONFNAME).rst

DOCPDF		= $(DOCSRCDIR)/$(NAME).pdf
DOTPDF		= $(DOCSRCDIR)/$(GRAPH).pdf
TOOLMAN 	= $(DOCSRCDIR)/$(TOOLNAME).1
CONFMAN		= $(DOCSRCDIR)/$(CONFNAME).5
MANPAGES	= $(TOOLMAN) $(CONFMAN)

DOCS		= $(DOCPDF) $(DOTPDF) $(MANPAGES)

# Files grouped by generation mode
GLYPHS		= $(BUILDDIR)/$(NAME)-glyphlist.lua
CHARS		= $(BUILDDIR)/$(NAME)-characters.lua
STATUS		= $(BUILDDIR)/$(NAME)-status.lua
RESOURCES	= $(GLYPHS) $(CHARS) $(STATUS)
SOURCE		= $(DOCSRC) $(MANSRC) $(SRC) README COPYING Makefile NEWS $(RESOURCESCRIPTS)

# Files grouped by installation location
SCRIPTSTATUS	= $(TOOL) $(RESOURCESCRIPTS)
RUNSTATUS	= $(filter-out $(SCRIPTSTATUS),$(SRC))
DOCSTATUS	= $(DOCPDF) $(DOTPDF) README NEWS COPYING
SRCSTATUS	= $(DOCSRC) $(MANSRC) $(GRAPHSRC) Makefile

# The following definitions should be equivalent
# ALL_STATUS = $(RUNSTATUS) $(DOCSTATUS) $(SRCSTATUS)
ALL_STATUS 	= $(RESOURCES) $(SOURCE)

# Installation locations
FORMAT 		= luatex
SCRIPTDIR	= $(TEXMFROOT)/scripts/$(NAME)
RUNDIR		= $(TEXMFROOT)/tex/$(FORMAT)/$(NAME)
DOCDIR		= $(TEXMFROOT)/doc/$(FORMAT)/$(NAME)
MAN1DIR		= $(TEXMFROOT)/doc/man/man1/
MAN5DIR		= $(TEXMFROOT)/doc/man/man5/
SRCDIR		= $(TEXMFROOT)/source/$(FORMAT)/$(NAME)
TEXMFROOT	= $(shell kpsewhich --var-value TEXMFHOME)

# CTAN-friendly subdirectory for packaging
DISTDIR		= $(BUILDDIR)/$(NAME)

CTAN_ZIPFILE	= $(NAME).zip
TDS_ZIPFILE	= $(NAME).tds.zip
CTAN_ZIP	= $(BUILDDIR)/$(CTAN_ZIPFILE)
TDS_ZIP		= $(BUILDDIR)/$(TDS_ZIPFILE)
ZIPS		= $(CTAN_ZIP) $(TDS_ZIP)

LUA		= texlua

## For now the $(BUILDDIR) is hardcoded in the scripts
## but we might just as well pass it to them by as environment
## variables.
DO_GLYPHS	= $(LUA) $(GLYPHSCRIPT) > /dev/null
DO_CHARS	= $(LUA) $(CHARSCRIPT)  > /dev/null
DO_STATUS	= $(LUA) $(STATUSSCRIPT)  > /dev/null

show: showtargets

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
manual: $(MANPAGES)

$(DOTPDF):
	@$(MAKE) -C $(DOCSRCDIR) graph

$(DOCPDF):
	@$(MAKE) -C $(DOCSRCDIR) doc

$(MANPAGES):
	@$(MAKE) -C $(DOCSRCDIR) manuals

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
@mkdir -p $(DISTDIR) && cp $(VGND) $(SOURCE) $(COMPILED) $(DISTDIR)
endef

$(CTAN_ZIP): $(DOCS) $(SOURCE) $(COMPILED) $(TDS_ZIP)
	@echo "Making $@ for CTAN upload."
	@$(RM) -- $@
	$(make-ctandir)
	cd $(BUILDDIR) && zip -r -9 $(CTAN_ZIPFILE) $(TDS_ZIPFILE) $(NAME) >/dev/null

define run-install-doc
@mkdir -p $(DOCDIR) && cp -- $(DOCSTATUS) $(VGND) $(DOCDIR)
@mkdir -p $(SRCDIR) && cp -- $(SRCSTATUS) $(SRCDIR)
@mkdir -p $(MAN1DIR) && cp -- $(TOOLMAN) $(MAN1DIR)
@mkdir -p $(MAN5DIR) && cp -- $(CONFMAN) $(MAN5DIR)
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

.PHONY: install manifest clean mrproper show showtargets

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

###############################################################################
showtargets:
	@echo "Available targets:"
	@echo
	@echo "       all         build everything: documentation, resources,"
	@echo "       world       build everything and package zipballs"
	@echo "       doc         compile PDF documentation"
	@echo "       resources   generate resource files (chars, glyphs)"
	@echo
	@echo "       pdf         build luaotfload.pdf"
	@echo "       manual      crate manpages for luaotfload-tool(1) and"
	@echo "                   luaotfload.conf(5) (requires Docutils)"
	@echo "       graph       generate file graph (requires GraphViz)"
	@echo
	@echo "       chars       import char-def.lua as luaotfload-characters.lua"
	@echo "       status      create repository info (luaotfload-status.lua)"
	@echo
	@echo "       tds         package a zipball according to the TDS"
	@echo "       ctan        package a zipball for uploading to CTAN"
	@echo

# vim:noexpandtab:tabstop=8:shiftwidth=2
