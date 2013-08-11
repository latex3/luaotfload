if not modules then modules = { } end modules ["loaders"] = {
    version   = "2.4",
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fonts           = fonts
local readers         = fonts.readers
local handlers        = fonts.handlers
local formats         = fonts.formats

local lfsisfile       = lfs.isfile
local fileaddsuffix   = file.addsuffix
local filebasename    = file.basename
local stringsub       = string.sub
local stringlower     = string.lower
local stringupper     = string.upper

local lpeg            = require "lpeg"
local lpegmatch       = lpeg.match
local P, S, Cp        = lpeg.P, lpeg.S, lpeg.Cp

resolvers.openbinfile = function (filename)
    if filename and filename ~= "" then
        local f = io.open(filename,"rb")
        if f then
            --logs.show_load(filename)
            local s = f:read("*a") -- io.readall(f) is faster but we never have large files here
            if checkgarbage then
                checkgarbage(#s)
            end
            f:close()
            if s then
                return true, s, #s
            end
        end
    end
    return loaders.notfound()
end

resolvers.loadbinfile = function (filename, filetype)

    local fname = kpse.find_file (filename, filetype)

    if fname and fname ~= "" then
        return resolvers.openbinfile(fname)
    else
        return resolvers.loaders.notfound()
    end

end

--[[ <EXPERIMENTAL> ]]

--[[doc--

  Here we load extra AFM libraries from Context.
  In fact, part of the AFM support is contained in font-ext.lua, for
  which the font loader has a replacement: luatex-fonts-ext.lua.
  However, this is only a stripped down version with everything AFM
  removed. For example, it lacks definitions of several AFM features
  like italic correction, protrusion, expansion and so on. In order to
  achieve full-fledged AFM support we will either have to implement our
  own version of these or consult with Hans whether he would consider
  including the AFM code with the font loader.

  For the time being we stick with two AFM-specific libraries:
  font-afm.lua and font-afk.lua. When combined, these already supply us
  with basic features like kerning and ligatures. The rest can be added
  in due time.

--doc]]--

require "luaotfload-font-afm.lua"
require "luaotfload-font-afk.lua"

--[[ </EXPERIMENTAL> ]]

--[[doc--

    The PFB/PFA reader checks whether there is a corresponding AFM file
    and hands the spec over to the AFM loader if appropriate.  Context
    uses string.gsub() to accomplish this but that can cause collateral
    damage.

--doc]]--

local mk_type1_reader = function (format)

  format          = stringlower (format)
  local first     = stringsub (format, 1, 1)
  local second    = stringsub (format, 2, 2)
  local third     = stringsub (format, 3, 3)

  local p_format      = P"."
                      * (P(first)   + P(stringupper (first)))
                      * (P(second)  + P(stringupper (second)))
                      * (P(third)   + P(stringupper (third)))
  ---                  we have to be careful here so we don’t affect
  ---                  harmless substrings
                      * (P"("    --- subfont
                       + P":"    --- feature list
                       + P(-1))  --- end of string
  local no_format     = 1 - p_format
  local p_format_file = no_format^1 * Cp() * p_format * Cp()

  local reader = function (specification, method)

    local afmfile = fileaddsuffix (specification.name, "afm")

    if lfsisfile (afmfile) then
      --- switch to afm reader
      logs.names_report ("log", 0, "type1",
                         "Found corresponding AFM file %s, using that.",
                         filebasename (afmfile))
      local oldspec = specification.specification
      local before, after = lpegmatch (p_format_file, oldspec)
      specification.specification = stringsub (oldspec, 1, before)
                                 .. "afm"
                                 .. stringsub (oldspec, after - 1)
      specification.forced = "afm"
      return readers.afm (specification, method)
    end

    --- else read pfb via opentype mechanism
    return readers.opentype (specification, format, "type1")
  end

  return reader
end

formats.pfa  = "type1"
readers.pfa  = mk_type1_reader "pfa"
handlers.pfa = { }

formats.pfb  = "type1"
readers.pfb  = mk_type1_reader "pfb"
handlers.pfb = { }  --- empty, as with tfm

-- vim:tw=71:sw=2:ts=2:expandtab
