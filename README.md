# The Luaotfload Package

![Version: 2.9802](https://img.shields.io/badge/current_version-2.9802-blue.svg?style=flat-square)
![Date: 2019-05-18](https://img.shields.io/badge/date-2019--05--18-blue.svg?style=flat-square)
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

## Versions

[![Version: 2.9802](https://img.shields.io/badge/version-2.9802-blue.svg?style=flat-square)](https://travis-ci.com/u-fischer/luaotfload/)
![Travis CI for 2.9802](https://img.shields.io/travis/com/u-fischer/luaotfload/master.svg?style=flat-square)
[![Version: development](https://img.shields.io/badge/version-dev-blue.svg?style=flat-square)](https://travis-ci.com/u-fischer/luaotfload/branches)
![Travis CI for dev](https://img.shields.io/travis/com/u-fischer/luaotfload/dev.svg?style=flat-square)


The version will be uploaded to CTAN shortly.  

The ongoing development is in the dev branch and in branches referring to the dates of the import of the context files. 
 
## Support
[![GitHub issues](https://img.shields.io/badge/github-issues-blue.svg?style=flat-square)](https://github.com/u-fischer/luaotfload/issues) 
[![mailing list](https://img.shields.io/badge/mailing_list-lualatex--dev-blue.svg?style=flat-square)](https://www.tug.org/mailman/listinfo/lualatex-dev) 


Issues can be reported at the issue tracker or at the old issue tracker on 
<https://github.com/lualatex/luaotfload>. 


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

