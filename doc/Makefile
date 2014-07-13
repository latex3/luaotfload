NAME		= luaotfload
DOCPDF		= $(NAME).pdf
DOCSRC		= $(NAME)-latex.tex

SCRIPTNAME	= luaotfload-tool
TOOLMANSRC	= $(SCRIPTNAME).rst
TOOLMAN		= $(SCRIPTNAME).1

CONFNAME	= luaotfload.conf
CONFMANSRC	= $(CONFNAME).rst
CONFMAN		= $(CONFNAME).5

MANPAGES	= $(TOOLMAN) $(CONFMAN)

GRAPH		= filegraph
DOTPDF		= $(GRAPH).pdf
DOT		= $(GRAPH).dot

DOCS		= $(DOTPDF) $(DOCPDF) $(MANPAGES)

DO_LATEXMK	= @latexmk -e '$$max_repeat = 5' -pdf -lualatex -silent $< >/dev/null
# latexmk does only one run on my machine, so we’re not going to rely on it
DO_LATEX	= @lualatex -interaction=batchmode $< >/dev/null
DO_GRAPHVIZ	= @dot -Tpdf -o $@ $< > /dev/null
DO_DOCUTILS	= @rst2man $< >$@ 2>/dev/null

doc: graph $(DOCPDF)
all: manuals doc
graph: $(DOTPDF)
manuals: $(TOOLMAN) $(CONFMAN)

$(DOCPDF): $(DOCSRC)
	@echo "creating PDF documentation ($@)"
	$(DO_LATEX)
	$(DO_LATEX)
	mv -f -- $(<:tex=pdf) $@

$(TOOLMAN): $(TOOLMANSRC)
	@echo "creating man page ($(TOOLMAN))"
	$(DO_DOCUTILS)

$(CONFMAN): $(CONFMANSRC)
	@echo "creating man page ($(CONFMAN))"
	$(DO_DOCUTILS)

$(DOTPDF): $(DOT)
	@echo "creating file graph ($(DOTPDF))"
	$(DO_GRAPHVIZ)

.PHONY: clean mrproper

clean:
	@$(RM) -- *.log *.aux *.toc *.idx *.ind *.ilg *.out

mrproper: clean
	@$(RM) -- $(DOCS)

# vim:noexpandtab:tabstop=8:shiftwidth=2
