if not modules then modules = { } end modules ['font-otc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert = string.format, table.insert
local type, next = type, next

local ctxcatcodes = tex.ctxcatcodes

-- we assume that the other otf stuff is loaded already

local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

local otf = fonts.otf
local tfm = fonts.tfm

-- for good old times (usage is to be avoided)

local tlig_list = {
    endash        = "hyphen hyphen",
    emdash        = "hyphen hyphen hyphen",
--~ quotedblleft  = "quoteleft quoteleft",
--~ quotedblright = "quoteright quoteright",
--~ quotedblleft  = "grave grave",
--~ quotedblright = "quotesingle quotesingle",
--~ quotedblbase  = "comma comma",
}
local trep_list = {
--~ [0x0022] = 0x201D,
    [0x0027] = 0x2019,
--~ [0x0060] = 0x2018,
}

-- instead of "script = "DFLT", langs = { 'dflt' }" we now use wildcards (we used to
-- have always); some day we can write a "force always when true" trick for other
-- features as well

local tlig_feature = {
    features  = { { scripts = { { script = "*", langs = { "*" }, } }, tag = "tlig", comment = "added bij mkiv" }, },
    name      = "ctx_tlig",
    subtables = { { name = "ctx_tlig_1" } },
    type      = "gsub_ligature",
    flags     = { },
}
local trep_feature = {
    features  = { { scripts = { { script = "*", langs = { "*" }, } }, tag = "trep", comment = "added bij mkiv" }, },
    name      = "ctx_trep",
    subtables = { { name = "ctx_trep_1" } },
    type      = "gsub_single",
    flags     = { },
}

fonts.otf.enhancers["enrich with features"] = function(data,filename)
    local glyphs = data.glyphs
    local indices = data.map.map
    for unicode, index in next, indices do
        local glyph = glyphs[index]
        local l = tlig_list[glyph.name]
        if l then
            local o = glyph.lookups or { }
            o["ctx_tlig_1"] = { { "ligature", l, glyph.name } }
            glyph.lookups = o
        end
        local r = trep_list[unicode]
        if r then
            local replacement = indices[r]
            if replacement then
                local o = glyph.lookups or { }
                o["ctx_trep_1"] = { { "substitution", glyphs[replacement].name } } ---
                glyph.lookups = o
            end
        end
    end
    data.gsub = data.gsub or { }
    if trace_loading then
        logs.report("load otf","enhance: registering tlig feature")
    end
    insert(data.gsub,1,table.fastcopy(tlig_feature))
    if trace_loading then
        logs.report("load otf","enhance: registering trep feature")
    end
    insert(data.gsub,1,table.fastcopy(trep_feature))
end

otf.tables.features['tlig'] = 'TeX Ligatures'
otf.tables.features['trep'] = 'TeX Replacements'

otf.features.register_base_substitution('tlig')
otf.features.register_base_substitution('trep')

-- the functionality is defined elsewhere

fonts.initializers.base.otf.equaldigits = fonts.initializers.common.equaldigits
fonts.initializers.node.otf.equaldigits = fonts.initializers.common.equaldigits

fonts.initializers.base.otf.lineheight  = fonts.initializers.common.lineheight
fonts.initializers.node.otf.lineheight  = fonts.initializers.common.lineheight

fonts.initializers.base.otf.compose     = fonts.initializers.common.compose
fonts.initializers.node.otf.compose     = fonts.initializers.common.compose

-- bonus function

function otf.name_to_slot(name) -- todo: afm en tfm
    local tfmdata = fonts.ids[font.current()]
    if tfmdata and tfmdata.shared then
        local otfdata = tfmdata.shared.otfdata
        local unicode = otfdata.luatex.unicodes[name]
        if type(unicode) == "number" then
            return unicode
        else
            return unicode[1]
        end
    end
    return nil
end

function otf.char(n) -- todo: afm en tfm
    if type(n) == "string" then
        n = otf.name_to_slot(n)
    end
    if n then
        tex.sprint(ctxcatcodes,format("\\char%s ",n))
    end
end
