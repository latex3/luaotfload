luaotfload          = { }

luaotfload.module = {
    name          = "luaotfload",
    version       = 1.001,
    date          = "2009/04/08",
    description   = "ConTeXt font loading system.",
    author        = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright     = "PRAGMA ADE / ConTeXt Development Team",
    license       = "see context related readme files"
}

luatextra.provides_module(luaotfload.module)

function luaotfload.loadmodule(name)
    local foundname = kpse.find_file('otfl-'..name,"tex")
    if not foundname then
      luatextra.module_error('luaotfload', string.format('file otf-%s not found.', name))
      return 
    end
    dofile(foundname)
end

-- The following functions are made to map ConTeXt functions to luaextra functions.

string.strip = string.stripspaces

local splitters_s, splitters_m = { }, { }

function lpeg.splitat(separator,single)
    local splitter = (single and splitters_s[separator]) or splitters_m[separator]
    if not splitter then
        separator = lpeg.P(separator)
        if single then
            local other, any = lpeg.C((1 - separator)^0), lpeg.P(1)
            splitter = other * (separator * lpeg.C(any^0) + "")
            splitters_s[separator] = splitter
        else
            local other = lpeg.C((1 - separator)^0)
            splitter = other * (separator * other)^0
            splitters_m[separator] = splitter
        end
    end
    return splitter
end

file = fpath
file.extname = fpath.suffix

function table.compact(t)
    if t then
        for k,v in next, t do
            if not next(v) then
                t[k] = nil
            end
        end
    end
end

function table.sortedhashkeys(tab) -- fast one
    local srt = { }
    for key,_ in next, tab do
        srt[#srt+1] = key
    end
    table.sort(srt)
    return srt
end

-- The following modules contain code that is either not used
-- at all outside ConTeXt or will fail when enabled due to
-- lack of other modules.

-- First we load a few helper modules. This is about the miminum
-- needed to let the font modules do theuir work.

luaotfload.loadmodule('luat-dum.lua') -- not used in context at all
luaotfload.loadmodule('luat-con.lua') -- maybe some day we don't need this one

-- We do need some basic node support although the following
-- modules contain a little bit of code that is not used. It's
-- not worth weeding.

luaotfload.loadmodule('node-ini.lua')

-- function to set the good attribute numbers, they are not arbitrary values 
-- between 127 and 255 like in the ConTeXt base code

function attributes.private(name)
    local number = tex.attributenumber['otfl@'..name]
    if not number then 
        luatextra.module_error('luaotfload', string.format('asking for attribute %s, but not declared. Please report to the maintainer of luaotfload.', name))
    end
    return number
end

luaotfload.loadmodule('node-inj.lua') -- will be replaced (luatex > .50)
luaotfload.loadmodule('node-fnt.lua')
luaotfload.loadmodule('node-dum.lua')

-- Now come the font modules that deal with traditional TeX fonts
-- as well as open type fonts. We don't load the afm related code
-- from font-enc.lua and font-afm.lua as only ConTeXt deals with
-- it.
--
-- The font database file (if used at all) must be put someplace
-- visible for kpse and is not shared with ConTeXt. The mtx-fonts
-- script can be used to genate this file (using the --names
-- option).

luaotfload.loadmodule('font-ini.lua')
luaotfload.loadmodule('font-tfm.lua') -- will be split (we may need font-log)
--loadmodule('font-ott.lua') -- might be split
luaotfload.loadmodule('font-otf.lua')
luaotfload.loadmodule('font-otb.lua')
luaotfload.loadmodule('font-cid.lua')
luaotfload.loadmodule('font-otn.lua')
luaotfload.loadmodule('font-ota.lua') -- might be split
luaotfload.loadmodule('font-otc.lua')
do
  local temp = callback.register
  callback.register = function (...)
    return
  end 
  luaotfload.loadmodule('font-def.lua')
  callback.register = temp
end
luaotfload.loadmodule('font-xtx.lua')
luaotfload.loadmodule('font-dum.lua')

function luaotfload.register_callbacks()
    callback.add('ligaturing',           nodes.simple_font_dummy, 'nodes.simple_font_dummy')
    callback.add('kerning',              nodes.simple_font_dummy, 'nodes.simple_font_dummy')
    callback.add('pre_linebreak_filter', nodes.simple_font_handler, 'nodes.simple_font_handler')
    callback.add('hpack_filter',         nodes.simple_font_handler, 'nodes.simple_font_handler')
    callback.reset('define_font')
    callback.add('define_font' ,         fonts.define.read, 'fonts.define.read', 1)
    callback.add('find_vf_file',         fonts.vf.find, 'fonts.vf.find')
end

function luaotfload.unregister_callbacks()
    callback.remove('ligaturing', 'nodes.simple_font_dummy')
    callback.remove('kerning', 'nodes.simple_font_dummy')
    callback.remove('pre_linebreak_filter', 'nodes.simple_font_handler')
    callback.remove('hpack_filter', 'nodes.simple_font_handler')
    callback.reset('define_font')
    callback.remove('find_vf_file', 'fonts.vf.find')
end
