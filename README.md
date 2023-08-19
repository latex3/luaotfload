# The Luaotfload Package

![Version: 3.25](https://img.shields.io/badge/current_version-3.25-blue.svg?style=flat-square)
![Date: 2023-08-19](https://img.shields.io/badge/date-2023--08--19-blue.svg?style=flat-square)
[![License: GNU GPLv2](https://img.shields.io/badge/license-GNU_GPLv2-blue.svg?style=flat-square)](http://www.gnu.org/licenses/old-licenses/gpl-2.0.html)


Luaotfload is an adaptation of the ConTeXt font loading system for the Plain
and LaTeX formats. It allows OpenType fonts to be loaded with font features
accessible using an extended font request syntax while providing compatibility
with XeTeX. By indexing metadata in a database it facilitates loading fonts by
their proper names instead of file names.

Luaotfload may be loaded in Plain LuaTeX with `\input luaotfload.sty`. 
In LuaLaTeX it is loaded by default. LuaLaTeX users may be interested in
the fontspec package which provides a high-level interface to the functionality
provided by this package.

Please see the documentation luaotfload.pdf for more information.

## Requirements

The current luaotfload needs luatex 1.10 (present in TeXLive 2019 and a current MiKTeX). 
harfmode need luahbtex 1.11.2.
The development targets the engines luatex and luahbtex and the version
that are in TeXLive 2020. 

Other luatex versions and luatex engine variants are *not* officially supported. 

## Development versions

The main ongoing development is in the dev branch. If you clone the git and run `l3build install`
in the main folder the files will be installed in 
the latex-dev part of your TEXMFHOME or the texmf you gave as option to the command 
(see the l3build documentation for details). 
They can then be tested with [lualatex-dev](https://www.latex-project.org/news/2019/09/01/LaTeX-dev-format/).
Very experimental stuff is in the various other dev branches.  

## Pull requests

The experimental branches are normally the newest but can have a quite short life. If a pull request is made
against such a branch it gets automatically closed when the branch is closed. In general it is therefore better to make
pull requests against the dev branch.
 
## Support
[![GitHub issues](https://img.shields.io/badge/github-issues-blue.svg?style=flat-square)](https://github.com/latex3/luaotfload) 
[![mailing list](https://img.shields.io/badge/mailing_list-lualatex--dev-blue.svg?style=flat-square)](https://www.tug.org/mailman/listinfo/lualatex-dev) 


Issues can be reported at the issue tracker. 


The development for LuaLaTeX is discussed on the lualatex-dev mailing list. See
<https://www.tug.org/mailman/listinfo/lualatex-dev> for details.


## Responsible Persons

The following people have contributed to this package.

|name |contact |
|---|---|
|Khaled Hosny      |       <khaledhosny@eglug.org>            |
|Elie Roux         |       <elie.roux@telecom-bretagne.eu>    |
|Will Robertson    |       <will.robertson@latex-project.org> | 
|Philipp Gesang    |       <phg@phi-gamma.net>                |
|Dohyun Kim        |       <nomosnomos@gmail.com>             |
|Reuben Thomas     |       <https://github.com/rrthomas>      |
|Joseph Wright     |       <joseph.wright@morningstar2.co.uk> |
|Manuel Pégourié-Gonnard|  <mpg@elzevir.fr>                   |
|Olof-Joachim Frahm|       <olof@macrolet.net>                |  
|Patrick Gundlach  |       <gundlach@speedata.de>             |
|Philipp Stephani  |       <st_philipp@yahoo.de>              |
|David Carlisle    |       <d.p.carlisle@gmail.com>           |
|Yan Zhou          |       @zhouyan                           |
|Ulrike Fischer    |       <fischer@troubleshooting-tex.de>   |
|Marcel Krüger     |       <https://github.com/zauguin>       |

## Installation

Here are the recommended installation methods (preferred first).

1.  Install the current version with the package management tools of your TeX system. 

2.  If you want to try the development version download the texmf folder in the development branch. 


## License

The luaotfload bundle, as a derived work of ConTeXt, is distributed under the
GNU GPLv2 license:

   <http://www.gnu.org/licenses/old-licenses/gpl-2.0.html>

This license requires the license itself to be distributed with the work. For
its full text see the documentation in luaotfload.pdf.


##  DISCLAIMER

        This program is free software; you can redistribute it and/or
        modify it under the terms of the GNU General Public License
        as published by the Free Software Foundation; version 2.

        This program is distributed in the hope that it will be useful,
        but WITHOUT ANY WARRANTY; without even the implied warranty of
        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        GNU General Public License for more details.

        See headers of each source file for copyright details.

