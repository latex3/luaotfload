=======================================================================
                            luaotfload.conf
=======================================================================

-----------------------------------------------------------------------
                     Luaotfload configuration file
-----------------------------------------------------------------------

:Date:                  2014-06-09
:Copyright:             GPL v2.0
:Version:               2.5
:Manual section:        5
:Manual group:          text processing

SYNOPSIS
=======================================================================

- **./luaotfload{.conf,rc}**
- **XDG_CONFIG_HOME/luaotfload/luaotfload{.conf,rc}**
- **~/.luaotfloadrc**

DESCRIPTION
=======================================================================

The file ``luaotfload.conf`` contains configuration options for
*Luaotfload*, a font loading and font management component for LuaTeX.


EXAMPLE
=======================================================================

* TODO, small example snippet


SYNTAX
=======================================================================

* TODO, short intro to ``.ini`` file syntax

VARIABLES
=======================================================================


* TODO, list variables


FILES
=======================================================================

Luaotfload only processes the first configuration file it encounters at
one of the search locations. The file name may be either
``luaotfload.conf`` or ``luaotfloadrc``, except for the dotfile in the
user’s home directory which is expected at ``~/.luaotfloadrc``.

Configuration files are located following a series of steps. The search
terminates as soon as a suitable file is encountered. The sequence of
locations that Luaotfload looks at is

i.    The current working directory of the LuaTeX process.
ii.   The subdirectory ``luaotfload/`` inside the XDG configuration
      tree, e. g. ``/home/oenothea/config/luaotfload/``.
iii.  The dotfile.
iv.   The *TEXMF* (using kpathsea).


SEE ALSO
=======================================================================

**luaotfload-tool** (1), **luatex** (1), **lua** (1)

* ``texdoc luaotfload`` to display the PDF manual for the *Luaotfload*
  package
* Luaotfload development `<https://github.com/lualatex/luaotfload>`_
* LuaLaTeX mailing list  `<http://tug.org/pipermail/lualatex-dev/>`_
* LuaTeX                 `<http://luatex.org/>`_
* Luaotfload on CTAN     `<http://ctan.org/pkg/luaotfload>`_


REFERENCES
=======================================================================

* The XDG base specification
  `<http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html>`_.

AUTHORS
=======================================================================

*Luaotfload* is maintained by the LuaLaTeX dev team
(`<https://github.com/lualatex/>`_).

This manual page was written by Philipp Gesang
<philipp.gesang@alumni.uni-heidelberg.de>.

