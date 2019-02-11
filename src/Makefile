SHELL := /bin/bash

.PHONY: test.pdf test-latex.pdf

all: test.pdf test-latex.pdf

test.pdf: test.tex
	time luatex $<
	mutool clean -a -d $@ $@

test-latex.pdf: test-latex.tex
	time lualatex $<
	mutool clean -a -d $@ $@
