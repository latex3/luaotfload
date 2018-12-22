SHELL := /bin/bash

.PHONY: test.pdf test-latex.pdf

all: test.pdf test-latex.pdf

test.pdf: test.tex
	time luahbtex $<
	mutool clean -a -d $@ $@

test-latex.pdf: test-latex.tex
	time luahblatex $<
	mutool clean -a -d $@ $@
