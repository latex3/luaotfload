# Makefile for luaotfload

NAME         = luaotfload
DOC          = $(NAME).pdf
DTX          = $(NAME).dtx
OTFL         = $(wildcard luaotfload-*.lua) luaotfload-blacklist.cnf

GLYPHSCRIPT  = mkglyphlist
GLYPHSOURCE  = glyphlist.txt
CHARSCRIPT   = mkcharacters
STATUSSCRIPT = mkstatus

RESOURCESCRIPTS = $(GLYPHSCRIPT) $(CHARSCRIPT) $(STATUSSCRIPT)

SCRIPTNAME   = luaotfload-tool
SCRIPT       = $(SCRIPTNAME).lua
MANSOURCE	 = $(SCRIPTNAME).rst
MANPAGE   	 = $(SCRIPTNAME).1
OLDSCRIPT    = luaotfload-legacy-tool.lua

GRAPH  		 = filegraph
DOTPDF 		 = $(GRAPH).pdf
DOT    		 = $(GRAPH).dot

# Files grouped by generation mode
GLYPHS      = luaotfload-glyphlist.lua
CHARS       = luaotfload-characters.lua
STATUS      = luaotfload-status.lua
RESOURCES	= $(GLYPHS) $(CHARS) $(STATUS)
GRAPHED     = $(DOTPDF)
MAN			= $(MANPAGE)
COMPILED    = $(DOC)
UNPACKED    = luaotfload.sty luaotfload.lua
GENERATED   = $(GRAPHED) $(UNPACKED) $(COMPILED) $(RESOURCES) $(MAN)
SOURCE 		= $(DTX) $(MANSOURCE) $(OTFL) README Makefile NEWS $(RESOURCESCRIPTS)

# test files
TESTDIR 		= tests
TESTSTATUS 		= $(wildcard $(TESTDIR)/*.tex $(TESTDIR)/*.ltx)
TESTSTATUS_SYS 	= $(TESTDIR)/systemfonts.tex $(TESTDIR)/fontconfig_conf_reading.tex
TESTSTATUS_TL 	= $(filter-out $(TESTSTATUS_SYS), $(TESTSTATUS))

# Files grouped by installation location
SCRIPTSTATUS = $(SCRIPT) $(OLDSCRIPT) $(RESOURCESCRIPTS)
RUNSTATUS    = $(UNPACKED) $(filter-out $(SCRIPTSTATUS),$(OTFL))
DOCSTATUS    = $(DOC) $(DOTPDF) README NEWS
MANSTATUS	= $(MANPAGE)
SRCSTATUS    = $(DTX) Makefile

# The following definitions should be equivalent
# ALL_STATUS = $(RUNSTATUS) $(DOCSTATUS) $(SRCSTATUS)
ALL_STATUS = $(GENERATED) $(SOURCE)

# Installation locations
FORMAT = luatex
SCRIPTDIR = $(TEXMFROOT)/scripts/$(NAME)
RUNDIR    = $(TEXMFROOT)/tex/$(FORMAT)/$(NAME)
DOCDIR    = $(TEXMFROOT)/doc/$(FORMAT)/$(NAME)
MANDIR    = $(TEXMFROOT)/doc/man/man1/
SRCDIR    = $(TEXMFROOT)/source/$(FORMAT)/$(NAME)
TEXMFROOT = $(shell kpsewhich --var-value TEXMFHOME)

CTAN_ZIP = $(NAME).zip
TDS_ZIP  = $(NAME).tds.zip
ZIPS 	 = $(CTAN_ZIP) $(TDS_ZIP)

LUA	= texlua

DO_TEX 		  	= luatex --interaction=batchmode $< >/dev/null
# (with the next version of latexmk: -pdf -pdflatex=lualatex)
DO_LATEX 	  	= latexmk -pdf -e '$$pdflatex = q(lualatex %O %S)' -silent $< >/dev/null
DO_GRAPHVIZ 	= dot -Tpdf -o $@ $< > /dev/null
DO_GLYPHS 		= $(LUA) $(GLYPHSCRIPT) > /dev/null
DO_CHARS 		= $(LUA) $(CHARSCRIPT)  > /dev/null
DO_STATUS 		= $(LUA) $(STATUSSCRIPT)  > /dev/null
DO_DOCUTILS 	= rst2man $< >$@ 2>/dev/null

all: $(GENERATED)
graph: $(GRAPHED)
doc: $(GRAPHED) $(COMPILED) $(MAN)
manual: $(MAN)
unpack: $(UNPACKED)
resources: $(RESOURCES)
chars: $(CHARS)
status: $(STATUS)
ctan: $(CTAN_ZIP)
tds: $(TDS_ZIP)
world: all ctan

$(GLYPHS): /dev/null
	$(DO_GLYPHS)

$(CHARS): /dev/null
	$(DO_CHARS)

$(STATUS): /dev/null
	$(DO_STATUS)

$(GRAPHED): $(DOT)
	$(DO_GRAPHVIZ)

$(COMPILED): $(DTX)
	$(DO_LATEX)

$(UNPACKED): $(DTX)
	$(DO_TEX)

$(MAN): $(MANSOURCE)
	$(DO_DOCUTILS)

$(CTAN_ZIP): $(SOURCE) $(COMPILED) $(TDS_ZIP)
	@echo "Making $@ for CTAN upload."
	@$(RM) -- $@
	@zip -9 $@ $^ >/dev/null

define run-install
@mkdir -p $(SCRIPTDIR) && cp $(SCRIPTSTATUS) $(SCRIPTDIR)
@mkdir -p $(RUNDIR) && cp $(RUNSTATUS) $(RUNDIR)
@mkdir -p $(DOCDIR) && cp $(DOCSTATUS) $(DOCDIR)
@mkdir -p $(SRCDIR) && cp $(SRCSTATUS) $(SRCDIR)
@mkdir -p $(MANDIR) && cp $(MANSTATUS) $(MANDIR)
endef

$(TDS_ZIP): TEXMFROOT=./tmp-texmf
$(TDS_ZIP): $(ALL_STATUS)
	@echo "Making TDS-ready archive $@."
	@$(RM) -- $@
	$(run-install)
	@cd $(TEXMFROOT) && zip -9 ../$@ -r . >/dev/null
	@$(RM) -r -- $(TEXMFROOT)

.PHONY: install manifest clean mrproper

install: $(ALL_STATUS)
	@echo "Installing in '$(TEXMFROOT)'."
	$(run-install)

check: $(RUNSTATUS) $(TESTSTATUS_TL)
	@rm -rf var
	@for f in $(TESTSTATUS_TL); do \
	    echo "check: luatex $$f"; \
	    luatex --interaction=batchmode $$f \
	    > /dev/null || exit $$?; \
	    done

check-all: $(TESTSTATUS_SYS) check
	@cd $(TESTDIR); for f in $(TESTSTATUS_SYS); do \
	    echo "check: luatex $$f"; \
	    $(TESTENV) luatex --interaction=batchmode ../$$f \
	    > /dev/null || exit $$?; \
	    done

manifest: 
	@echo "Source files:"
	@for f in $(SOURCE); do echo $$f; done
	@echo ""
	@echo "Derived files:"
	@for f in $(GENERATED); do echo $$f; done

clean: 
	@$(RM) -- *.log *.aux *.toc *.idx *.ind *.ilg *.out $(TESTDIR)/*.log

mrproper: clean
	@$(RM) -- $(GENERATED) $(ZIPS) $(GLYPHSOURCE) $(TESTDIR)/*.pdf

