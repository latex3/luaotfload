#!/bin/she -e

# This script is used for testing using Travis
# It is intended to work on their VM set up: Ubuntu 12.04 LTS
# A minimal current TL is installed adding only the packages that are
# required

# See if there is a cached version of TL available
export PATH=/tmp/texlive/bin/x86_64-linux:$PATH
if ! command -v texlua > /dev/null; then
  # Obtain TeX Live
  wget http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
  tar -xzf install-tl-unx.tar.gz
  cd install-tl-20*

  # Install a minimal system
  ./install-tl --profile=../texlive.profile

  cd ..
fi

# Needed for any use of texlua even if not testing LuaTeX
tlmgr install l3build latex latex-bin  luatex  

# Required to build plain and LaTeX formats:
# TeX90 plain for unpacking, pdfLaTeX, LuaLaTeX and XeTeX for tests
tlmgr install cm etex knuth-lib tex tex-ini-files unicode-data 

# various tools / dependencies of other packages
tlmgr install ctablestack filehook ifoddpage ifxetex luatexbase trimspaces
tlmgr install oberdiek etoolbox xkeyval ucharcat xstring ifluatex  everyhook
tlmgr install svn-prov

# graphics
tlmgr install graphics xcolor graphics-def pgf

# fonts support - perhaps take here luaotfload out of the list ...
# or is it installed as dependency anyway?
tlmgr install fontspec microtype unicode-math luaotfload

# fonts
tlmgr install  sourcecodepro Asana-Math  ebgaramond  tex-gyre  amsfonts gnu-freefont  
tlmgr install  opensans fira tex-gyre-math junicode lm  lm-math amiri ipaex xits
tlmgr install  libertine coelacanth fontawesome

# languages
tlmgr install  luatexja arabluatex babel babel-english
          

# math
tlmgr install  amsmath lualatex-math  

# a few more packages
tlmgr install   luacode environ adjustbox collectbox ms varwidth geometry

 
# Assuming a 'basic' font set up, metafont is required to avoid
# warnings with some packages and errors with others
tlmgr install metafont mfware

# Keep no backups (not required, simply makes cache bigger)
tlmgr option -- autobackup 0

# Update the TL install but add nothing new
tlmgr update --self --all --no-auto-install

pwd
echo texmfhome $TEXMFHOME
