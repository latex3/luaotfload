--
-----------------------------------------------------------------------
--         FILE:  luaotfload-package.lua
--  DESCRIPTION:  Luatex fontloader packaging
-- REQUIREMENTS:  luatex
--       AUTHOR:  Philipp Gesang
--      LICENSE:  GNU GPL v2.0
--      CREATED:  2015-03-29 12:07:33+0200
-----------------------------------------------------------------------
--

--- The original initialization sequence by Hans Hagen, see the file
--- luatex-fonts.lua for details:
---
---   [01] l-lua.lua
---   [02] l-lpeg.lua
---   [03] l-function.lua
---   [04] l-string.lua
---   [05] l-table.lua
---   [06] l-io.lua
---   [07] l-file.lua
---   [08] l-boolean.lua
---   [09] l-math.lua
---   [10] util-str.lua
---   [11] luatex-basics-gen.lua
---   [12] data-con.lua
---   [13] luatex-basics-nod.lua
---   [14] font-ini.lua
---   [15] font-con.lua
---   [16] luatex-fonts-enc.lua
---   [17] font-cid.lua
---   [18] font-map.lua
---   [19] luatex-fonts-syn.lua
---   [20] font-tfm.lua
---   [21] font-afm.lua
---   [22] font-afk.lua
---   [23] luatex-fonts-tfm.lua
---   [24] font-oti.lua
---   [25] font-otf.lua
---   [26] font-otb.lua
---   [27] luatex-fonts-inj.lua
---   [28] luatex-fonts-ota.lua
---   [29] luatex-fonts-otn.lua
---   [30] font-otp.lua
---   [31] luatex-fonts-lua.lua
---   [32] font-def.lua
---   [33] luatex-fonts-def.lua
---   [34] luatex-fonts-ext.lua
---   [35] luatex-fonts-cbk.lua
---
--- Of these, nos. 01--10 are provided by the Lualibs. Keeping them
--- around in the Luaotfload fontloader is therefore unnecessary.
--- Packaging needs to account for this difference.

loadmodule "l-lua.lua"
loadmodule "l-lpeg.lua"
loadmodule "l-function.lua"
loadmodule "l-string.lua"
loadmodule "l-table.lua"
loadmodule "l-io.lua"
loadmodule "l-file.lua"
loadmodule "l-boolean.lua"
loadmodule "l-math.lua"
loadmodule "util-str.lua"

--- Another file containing auxiliary definitions must be present
--- prior to initialization of the configuration.

loadmodule "luatex-basics-gen.lua"

--- The files below constitute the “fontloader proper”. Some of the
--- functionality like file resolvers is overloaded later by
--- Luaotfload. Consequently, the resulting package is pretty
--- bare-bones and not usable independently.

loadmodule("data-con.lua")
loadmodule("luatex-basics-nod.lua")
loadmodule("font-ini.lua")
loadmodule("font-con.lua")
loadmodule("luatex-fonts-enc.lua")
loadmodule("font-cid.lua")
loadmodule("font-map.lua")
loadmodule("luatex-fonts-syn.lua")
loadmodule("font-tfm.lua")
loadmodule("font-afm.lua")
loadmodule("font-afk.lua")
loadmodule("luatex-fonts-tfm.lua")
loadmodule("font-oti.lua")
loadmodule("font-otf.lua")
loadmodule("font-otb.lua")
loadmodule("luatex-fonts-inj.lua")
loadmodule("luatex-fonts-ota.lua")
loadmodule("luatex-fonts-otn.lua")
loadmodule("font-otp.lua")
loadmodule("luatex-fonts-lua.lua")
loadmodule("font-def.lua")
loadmodule("luatex-fonts-def.lua")
loadmodule("luatex-fonts-ext.lua")
loadmodule("luatex-fonts-cbk.lua")

