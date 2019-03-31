SHELL := /bin/bash

LUATEX ?= luatex

.PHONY: test.pdf test-latex.pdf

all: test.pdf test-latex.pdf

test.pdf: test.tex
	time $(LUATEX) $<
	mutool clean -a -d $@ $@

test-latex.pdf: test-latex.tex
	time $(LUATEX) -fmt lualatex $<
	mutool clean -a -d $@ $@
