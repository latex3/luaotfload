=======================================================================
                            luaotfload-tool
=======================================================================

-----------------------------------------------------------------------
         generate and query the Luaotfload font names database
-----------------------------------------------------------------------

:Date:      2013-05-06
:Copyright: GPL v2.0
:Version:   2.2
:Manual section: 1
:Manual group: text processing

SYNOPSIS
=======================================================================

**luaotfload** [ -cfFiquvVh ]

**luaotfload** --update [ --force ] [ --quiet ] [ --verbose ]

**luaotfload** --find=filename [ --fuzzy ] [ --info ]

**luaotfload** --flush-cache

**luaotfload** --help

**luaotfload** --version

DESCRIPTION
=======================================================================

luaotfload-tool accesses the font names database that is required by
the *Luaotfload* package. There are two general modes: **update** and
**query**.

+ **update**:  update the database or rebuild it entirely;
+ **query**:   resolve a font name or display close matches.

A third mode for clearing the lookup cache is currently experimental.

Note that if the script is named ``mkluatexfontdb`` it will behave like
earlier versions (<=1.3) and always update the database first. Also,
the verbosity level will be set to 2.

OPTIONS
=======================================================================

update mode
-----------------------------------------------------------------------
--update, -u            Update the database; indexes new fonts.
--force, -f             Force rebuilding of the database; re-indexes
                        all fonts.

query mode
-----------------------------------------------------------------------
--find=<name>           Resolve a font name; this looks up <name> in
                        the database and prints the file name it is
                        mapped to.
--fuzzy, -F             Show approximate matches to the file name if
                        the lookup was unsuccessful (requires ``--find``).
--info, -i              Display basic information to a resolved font
                        file (requires ``--find``).

lookup cache
-----------------------------------------------------------------------
--flush-cache           Clear font name lookup cache (experimental).

miscellaneous
-----------------------------------------------------------------------
--verbose=<n>, -v       Set verbosity level to *n* or the number of
                        repetitions of ``-v``.
--quiet                 No verbose output (log level set to zero).
--log=stdout            Redirect log output to terminal (for database
                        troubleshooting).

--version, -V           Show version number and exit.
--help, -h              Show help message and exit.


FILES
=======================================================================

The font name database is usually located in the directory
``texmf-var/luatex-cache/generic/names/`` (``$TEXMFCACHE`` as set in
``texmf.cnf``) of your *TeX Live* distribution as
``luaotfload-names.lua``.  The experimental lookup cache will be
created as ``luaotfload-lookup-cache.lua`` in the same directory.
Both files are safe to delete, at the cost of regenerating them with
the next run of *LuaTeX*.

SEE ALSO
=======================================================================

**luatex** (1), **lua** (1)

* ``texdoc luaotfload`` to display the manual for the *Luaotfload*
  package
* Luaotfload development `<https://github.com/lualatex/luaotfload>`_
* LuaLaTeX mailing list  `<http://tug.org/pipermail/lualatex-dev/>`_
* LuaTeX                 `<http://luatex.org/>`_
* ConTeXt                `<http://wiki.contextgarden.net>`_
* Luaotfload on CTAN     `<http://ctan.org/pkg/luaotfload>`_

BUGS
=======================================================================

Tons, probably.

AUTHORS
=======================================================================

*Luaotfload* is maintained by the LuaLaTeX dev team
(`<https://github.com/lualatex/>`__).
The fontloader code is provided by Hans Hagen of Pragma ADE, Hasselt
NL (`<http://pragma-ade.com/>`__).

This manual page was written by Philipp Gesang
<philipp.gesang@alumni.uni-heidelberg.de>.

