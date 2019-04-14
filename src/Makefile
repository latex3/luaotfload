SHELL := /bin/bash

ENGINE ?= harftex

.PHONY: test.pdf test-latex.pdf

all: test.pdf test-latex.pdf

test.pdf: test.tex
	time $(ENGINE) -fmt luatex $<
	mutool clean -a -d $@ $@

test-latex.pdf: test-latex.tex
	time $(ENGINE) -fmt lualatex $<
	mutool clean -a -d $@ $@
