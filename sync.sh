#!/bin/bash
CTX_TEXFM=$1
CTX_FILES=`grep -o "loadmodule('....-....lua')" $CTX_TEXFM/tex/generic/context/luatex-fonts.lua |\
           sed -e "s/loadmodule('\(....-....lua\)')/\1/" | sort | uniq`

echo $CTX_FILES
for i in $CTX_FILES; do
	cp -v $CTX_TEXFM/tex/context/base/$i otfl-$i
done
