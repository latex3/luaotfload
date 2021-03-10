#!/bin/she -e

# This script is used for testing using Travis
# It is intended to work on their VM set up: Ubuntu 12.04 LTS
# A minimal current TL is installed adding only the packages that are
# required

# See if there is a cached version of TL available
export PATH=/tmp/texlive/bin/x86_64-linux:$PATH
if ! command -v texlua > /dev/null; then
  # Obtain TeX Live
  wget http://pretest.math.hamburg/install-tl-unx.tar.gz
  tar -xzf install-tl-unx.tar.gz
  cd install-tl-20*

  # Install a minimal system
  ./install-tl --profile=../texlive.profile -repository https://pretest.math.hamburg

  cd ..
fi
tlmgr update --self

(
# Needed for any use of texlua even if not testing LuaTeX
echo l3build latex latex-bin luatex latex-bin-dev

# Required to build plain and LaTeX formats:
# TeX90 plain for unpacking, pdfLaTeX, LuaLaTeX and XeTeX for tests
echo cm etex knuth-lib tex tex-ini-files unicode-data

# various tools / dependencies of other packages
echo ctablestack filehook ifoddpage iftex luatexbase trimspaces
echo oberdiek etoolbox xkeyval ucharcat xstring everyhook
echo svn-prov setspace csquotes

# slices from oberdiek
echo atbegshi atveryend bigintcalc bitset bookmark epstopdf-pkg etexcmds
echo gettitlestring hologo hycolor intcalc kvdefinekeys kvsetkeys
echo letltxmacro ltxcmds luacolor pdfescape pdflscape pdftexcmds refcount
echo rerunfilecheck uniquecounter

# graphics
echo graphics xcolor graphics-def pgf

# fonts support - perhaps take here luaotfload out of the list ...
# or is it installed as dependency anyway?
echo fontspec microtype unicode-math luaotfload ttfutils

# fonts
echo sourcecodepro Asana-Math  ebgaramond  tex-gyre  amsfonts gnu-freefont
echo opensans fira tex-gyre-math junicode lm  lm-math amiri ipaex xits
echo libertine coelacanth fontawesome stix2-otf dejavu
echo luatexko unfonts-core cjk-ko iwona libertinus-fonts fandol
echo cm-unicode noto cuprum

# languages
echo luatexja arabluatex babel babel-english


# math
echo amsmath lualatex-math latex-amsmath-dev

# a few more packages
echo luacode environ adjustbox collectbox ms varwidth geometry url ulem lua-ul

# some packages for the documentation
echo caption fancyvrb hyperref inconsolata listings luatex85 mdwtools
echo metalogo pdfpages pgf-blur standalone tikzducks tikzlings titlesec
echo tocloft tools


# Assuming a 'basic' font set up, metafont is required to avoid
# warnings with some packages and errors with others
echo metafont mfware texlive-scripts
) | xargs tlmgr install

# Keep no backups (not required, simply makes cache bigger)
tlmgr option -- autobackup 0

# Update the TL install but add nothing new
tlmgr update --self --all --no-auto-install

