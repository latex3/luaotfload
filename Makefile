# Makefile for luaotfload

NAME = luaotfload
DOC = $(NAME).pdf
DTX = $(NAME).dtx

# Files grouped by generation mode
COMPILED = $(DOC)
UNPACKED = luaotfload.sty luaotfload.lua
GENERATED = $(COMPILED) $(UNPACKED)
SOURCE = $(DTX) README Makefile

# Files grouped by installation location
RUNFILES = $(UNPACKED) $(wildcard otfl-*.lua)
DOCFILES = $(DOC) README
SRCFILES = $(DTX) Makefile

# The following definitions should be equivalent
# ALL_FILES = $(RUNFILES) $(DOCFILES) $(SRCFILES)
ALL_FILES = $(GENERATED) $(SOURCE)

# Installation locations
FORMAT = luatex
RUNDIR = tex/$(FORMAT)/$(NAME)
DOCDIR = doc/$(FORMAT)/$(NAME)
SRCDIR = source/$(FORMAT)/$(NAME)
ALL_DIRS = $(RUNDIR) $(DOCDIR) $(SRCDIR)

CTAN_ZIP = $(NAME).zip
TDS_ZIP = $(NAME).tds.zip
ZIPS = $(CTAN_ZIP) $(TDS_ZIP)

DO_TEX = tex --interaction=batchmode $< >/dev/null
DO_PDFLATEX = pdflatex --interaction=batchmode $< >/dev/null
DO_MAKEINDEX = makeindex -s gind.ist $(subst .dtx,,$<) >/dev/null 2>&1

all: $(GENERATED)
ctan: $(CTAN_ZIP)
doc: $(COMPILED)
tds: $(TDS_ZIP)
world: all ctan

$(COMPILED): $(DTX)
	$(DO_PDFLATEX)
	$(DO_MAKEINDEX)
	$(DO_PDFLATEX)
	$(DO_PDFLATEX)

$(UNPACKED): $(DTX)
	$(DO_TEX)

$(CTAN_ZIP): $(SOURCE) $(COMPILED) $(TDS_ZIP)
	@echo "Making $@ for CTAN upload."
	@$(RM) -- $@
	@zip -9 $@ $^ >/dev/null

$(TDS_ZIP): $(ALL_FILES)
	@echo "Making TDS-ready archive $@."
	@$(RM) -- $@
	@mkdir -p $(ALL_DIRS)
	@cp $(RUNFILES) $(RUNDIR)
	@cp $(DOCFILES) $(DOCDIR)
	@cp $(SRCFILES) $(SRCDIR)
	@zip -9 $@ -r $(ALL_DIRS) >/dev/null
	@$(RM) -r tex doc source

clean: 
	@$(RM) -- *.log *.aux *.toc *.idx *.ind *.ilg

mrproper: clean
	@$(RM) -- $(GENERATED) $(ZIPS)

.PHONY: clean mrproper
