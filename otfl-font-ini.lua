if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- basemethods    -> can also be in list
-- presetcontext  -> defaults
-- hashfeatures   -> ctx version

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local lower = string.lower
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local report_defining = logs.reporter("fonts","defining")

fontloader.totable = fontloader.to_table

fonts               = fonts or { } -- already defined in context
local fonts         = fonts

-- some of these might move to where they are used first:

fonts.hashes        = { identifiers = allocate() }
fonts.analyzers     = { } -- not needed here
fonts.readers       = { }
fonts.tables        = { }
fonts.definers      = { methods = { } }
fonts.specifiers    = fonts.specifiers or { } -- in format !
fonts.loggers       = { register = function() end }
fonts.helpers       = { }

fonts.tracers       = { } -- for the moment till we have move to moduledata
