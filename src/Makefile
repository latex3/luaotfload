SHELL := /bin/bash

.PHONY: test.pdf

test.pdf: test.tex harf-base.lua harf-load.lua harf-node.lua
	time luahbtex $<
	mutool clean -a -d $@ $@
