SHELL := /bin/bash

test.pdf: test.tex harf-base.lua harf-load.lua
	time luahbtex $<
	mutool clean -a -d $@ $@
