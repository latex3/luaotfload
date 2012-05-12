# Makefile for luaotfload

NAME = luaotfload
DOC = $(NAME).pdf
DTX = $(NAME).dtx
OTFL = $(wildcard otfl-*.lua) otfl-blacklist.cnf font-age.lua
SCRIPT = mkluatexfontdb.lua

# Files grouped by generation mode
COMPILED = $(DOC)
UNPACKED = luaotfload.sty luaotfload.lua
GENERATED = $(COMPILED) $(UNPACKED)
SOURCE = $(DTX) $(OTFL) README Makefile NEWS $(SCRIPT)

# test files
TESTDIR = tests
TESTFILES = $(wildcard $(TESTDIR)/*.tex)
TESTFILES_SYS = $(TESTDIR)/systemfonts.tex $(TESTDIR)/fontconfig_conf_reading.tex
TESTFILES_TL = $(filter-out $(TESTFILES_SYS), $(TESTFILES))
TESTENV = env TEXINPUTS='.;..;$$TEXMF/tex/{luatex,plain,generic,}//' TEXMFVAR='../var'

# Files grouped by installation location
SCRIPTFILES = $(SCRIPT)
RUNFILES    = $(UNPACKED) $(OTFL)
DOCFILES    = $(DOC) README NEWS
SRCFILES    = $(DTX) Makefile

# The following definitions should be equivalent
# ALL_FILES = $(RUNFILES) $(DOCFILES) $(SRCFILES)
ALL_FILES = $(GENERATED) $(SOURCE)

# Installation locations
FORMAT = luatex
SCRIPTDIR = $(TEXMFROOT)/scripts/$(NAME)
RUNDIR    = $(TEXMFROOT)/tex/$(FORMAT)/$(NAME)
DOCDIR    = $(TEXMFROOT)/doc/$(FORMAT)/$(NAME)
SRCDIR    = $(TEXMFROOT)/source/$(FORMAT)/$(NAME)
TEXMFROOT = $(shell kpsewhich --var-value TEXMFHOME)

CTAN_ZIP = $(NAME).zip
TDS_ZIP = $(NAME).tds.zip
ZIPS = $(CTAN_ZIP) $(TDS_ZIP)

DO_TEX = tex --interaction=batchmode $< >/dev/null
DO_LATEX = latexmk -pdf -pdflatex=lualatex -silent $< >/dev/null

all: $(GENERATED)
doc: $(COMPILED)
unpack: $(UNPACKED)
ctan: check $(CTAN_ZIP)
tds: $(TDS_ZIP)
world: all ctan

$(COMPILED): $(DTX)
	$(DO_LATEX)

$(UNPACKED): $(DTX)
	$(DO_TEX)

$(CTAN_ZIP): $(SOURCE) $(COMPILED) $(TDS_ZIP)
	@echo "Making $@ for CTAN upload."
	@$(RM) -- $@
	@zip -9 $@ $^ >/dev/null

define run-install
@mkdir -p $(SCRIPTDIR) && cp $(SCRIPTFILES) $(SCRIPTDIR)
@mkdir -p $(RUNDIR) && cp $(RUNFILES) $(RUNDIR)
@mkdir -p $(DOCDIR) && cp $(DOCFILES) $(DOCDIR)
@mkdir -p $(SRCDIR) && cp $(SRCFILES) $(SRCDIR)
endef

$(TDS_ZIP): TEXMFROOT=./tmp-texmf
$(TDS_ZIP): $(ALL_FILES)
	@echo "Making TDS-ready archive $@."
	@$(RM) -- $@
	$(run-install)
	@cd $(TEXMFROOT) && zip -9 ../$@ -r . >/dev/null
	@$(RM) -r -- $(TEXMFROOT)

.PHONY: install manifest clean mrproper

install: $(ALL_FILES)
	@echo "Installing in '$(TEXMFROOT)'."
	$(run-install)

check: $(RUNFILES) $(TESTFILES_TL)
	@rm -rf var
	@cd $(TESTDIR); for f in $(TESTFILES_TL); do \
	    echo "check: luatex $$f"; \
	    $(TESTENV) luatex --interaction=batchmode ../$$f \
	    > /dev/null || exit $$?; \
	    done

check-all: $(TESTFILES_SYS) check
	@cd $(TESTDIR); for f in $(TESTFILES_SYS); do \
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
	@$(RM) -- $(GENERATED) $(ZIPS) $(TESTDIR)/*.pdf

