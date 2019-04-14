SHELL := /bin/bash

ENGINE ?= harf

.PHONY: test.pdf test-latex.pdf

all: test.pdf test-latex.pdf

test.pdf: test.tex
	time $(ENGINE)tex -fmt $(ENGINE)tex $<
	mutool clean -a -d $@ $@

test-latex.pdf: test-latex.tex
	time $(ENGINE)tex -fmt $(ENGINE)latex $<
	mutool clean -a -d $@ $@
