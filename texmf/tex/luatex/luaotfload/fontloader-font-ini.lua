if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local allocate    = utilities.storage.allocate
local sortedhash  = table.sortedhash

fonts             = fonts or { }
local fonts       = fonts

local identifiers = allocate()

fonts.hashes      = fonts.hashes     or { identifiers = identifiers }
fonts.tables      = fonts.tables     or { }
fonts.helpers     = fonts.helpers    or { }
fonts.tracers     = fonts.tracers    or { } -- for the moment till we have move to moduledata
fonts.specifiers  = fonts.specifiers or { } -- in format !

fonts.analyzers   = { } -- not needed here
fonts.readers     = { }
fonts.definers    = { methods = { } }
fonts.loggers     = { register = function() end }

if context then

    font.originaleach = font.each

    function font.each()
        return sortedhash(identifiers)
    end

    fontloader = nil

end
