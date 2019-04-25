SHELL := /bin/bash

.PHONY: test.pdf test-latex.pdf

all: test.pdf test-latex.pdf

test.pdf: test.tex
	time harftex $<
	mutool clean -a -d $@ $@

test-latex.pdf: test-latex.tex
	time harflatex $<
	mutool clean -a -d $@ $@
