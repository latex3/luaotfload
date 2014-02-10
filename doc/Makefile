NAME				= luaotfload
DOCPDF			= $(NAME).pdf
DOCDTX			= $(NAME).dtx

SCRIPTNAME	= luaotfload-tool
MANSOURCE		= $(SCRIPTNAME).rst
MANPAGE			= $(SCRIPTNAME).1

GRAPH				= filegraph
DOTPDF			= $(GRAPH).pdf
DOT					= $(GRAPH).dot

DOCS				= $(DOTPDF) $(DOCPDF) $(MANPAGE)

DO_LATEXMK	= @latexmk -e '$$max_repeat = 5' -pdf -lualatex -silent $< >/dev/null
# latexmk does only one run on my machine, so we’re not going to rely on it
DO_LATEX		= @lualatex -interaction=batchmode $< >/dev/null
DO_GRAPHVIZ	= @dot -Tpdf -o $@ $< > /dev/null
DO_DOCUTILS	= @rst2man $< >$@ 2>/dev/null

doc: graph $(DOCPDF)
all: manual doc
graph: $(DOTPDF)
manual: $(MANPAGE)

$(DOCPDF): $(DOCDTX)
	@echo "creating PDF documentation ($(DOCPDF))"
	$(DO_LATEX)
	$(DO_LATEX)

$(MANPAGE): $(MANSOURCE)
	@echo "creating man page ($(MANPAGE))"
	$(DO_DOCUTILS)

$(DOTPDF): $(DOT)
	@echo "creating file graph ($(DOTPDF))"
	$(DO_GRAPHVIZ)

.PHONY: clean mrproper

clean:
	@$(RM) -- *.log *.aux *.toc *.idx *.ind *.ilg *.out

mrproper: clean
	@$(RM) -- $(DOCS)

