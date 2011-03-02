if not modules then modules = { } end modules ['font-otc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert = string.format, table.insert
local type, next = type, next

-- we assume that the other otf stuff is loaded already

local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

local fonts = fonts
local otf   = fonts.otf

local report_otf = logs.reporter("fonts","otf loading")

-- instead of "script = "DFLT", langs = { 'dflt' }" we now use wildcards (we used to
-- have always); some day we can write a "force always when true" trick for other
-- features as well
--
-- we could have a tnum variant as well

-- In the userdata interface we can not longer tweak the loaded font as
-- conveniently as before. For instance, instead of pushing extra data in
-- in the table using the original structure, we now have to operate on
-- the mkiv representation. And as the fontloader interface is modelled
-- after fontforge we cannot change that one too much either.

local extra_lists = {
    tlig = {
        {
            endash        = "hyphen hyphen",
            emdash        = "hyphen hyphen hyphen",
         -- quotedblleft  = "quoteleft quoteleft",
         -- quotedblright = "quoteright quoteright",
         -- quotedblleft  = "grave grave",
         -- quotedblright = "quotesingle quotesingle",
         -- quotedblbase  = "comma comma",
        },
    },
    trep = {
        {
         -- [0x0022] = 0x201D,
            [0x0027] = 0x2019,
         -- [0x0060] = 0x2018,
        },
    },
    anum = {
        { -- arabic
            [0x0030] = 0x0660,
            [0x0031] = 0x0661,
            [0x0032] = 0x0662,
            [0x0033] = 0x0663,
            [0x0034] = 0x0664,
            [0x0035] = 0x0665,
            [0x0036] = 0x0666,
            [0x0037] = 0x0667,
            [0x0038] = 0x0668,
            [0x0039] = 0x0669,
        },
        { -- persian
            [0x0030] = 0x06F0,
            [0x0031] = 0x06F1,
            [0x0032] = 0x06F2,
            [0x0033] = 0x06F3,
            [0x0034] = 0x06F4,
            [0x0035] = 0x06F5,
            [0x0036] = 0x06F6,
            [0x0037] = 0x06F7,
            [0x0038] = 0x06F8,
            [0x0039] = 0x06F9,
        },
    },
}

local extra_features = { -- maybe just 1..n so that we prescribe order
    tlig = {
        {
            features  = { ["*"] = { ["*"] = true } },
            name      = "ctx_tlig_1",
            subtables = { "ctx_tlig_1_s" },
            type      = "gsub_ligature",
            flags     = { },
        },
    },
    trep = {
        {
            features  = { ["*"] = { ["*"] = true } },
            name      = "ctx_trep_1",
            subtables = { "ctx_trep_1_s" },
            type      = "gsub_single",
            flags     = { },
        },
    },
    anum = {
        {
            features  = { arab = { URD = true, dflt = true } },
            name      = "ctx_anum_1",
            subtables = { "ctx_anum_1_s" },
            type      = "gsub_single",
            flags     = { },
        },
        {
            features  = { arab = { URD = true } },
            name      = "ctx_anum_2",
            subtables = { "ctx_anum_2_s" },
            type      = "gsub_single",
            flags     = { },
        },
    },
}

local function enhancedata(data,filename,raw)
    local luatex = data.luatex
    local lookups = luatex.lookups
    local sequences = luatex.sequences
    local glyphs = data.glyphs
    local indices = luatex.indices
    local gsubfeatures = luatex.features.gsub
    for kind, specifications in next, extra_features do
        if gsub and gsub[kind] then
            -- already present
        else
            local done = 0
            for s=1,#specifications do
                local added = false
                local specification = specifications[s]
                local features, subtables = specification.features, specification.subtables
                local name, type, flags = specification.name, specification.type, specification.flags
                local full = subtables[1]
                local list = extra_lists[kind][s]
                if type == "gsub_ligature" then
                    -- inefficient loop
                    for unicode, index in next, indices do
                        local glyph = glyphs[index]
                        local ligature = list[glyph.name]
                        if ligature then
                            if glyph.slookups then
                                glyph.slookups     [full] = { "ligature", ligature, glyph.name }
                            else
                                glyph.slookups = { [full] = { "ligature", ligature, glyph.name } }
                            end
                            done, added = done+1, true
                        end
                    end
                elseif type == "gsub_single" then
                    -- inefficient loop
                    for unicode, index in next, indices do
                        local glyph = glyphs[index]
                        local r = list[unicode]
                        if r then
                            local replacement = indices[r]
                            if replacement and glyphs[replacement] then
                                if glyph.slookups then
                                    glyph.slookups     [full] = { "substitution", glyphs[replacement].name }
                                else
                                    glyph.slookups = { [full] = { "substitution", glyphs[replacement].name } }
                                end
                                done, added = done+1, true
                            end
                        end
                    end
                end
                if added then
                    sequences[#sequences+1] = {
                        chain     = 0,
                        features  = { [kind] = features },
                        flags     = flags,
                        name      = name,
                        subtables = subtables,
                        type      = type,
                    }
                    -- register in metadata (merge as there can be a few)
                    if not gsubfeatures then
                        gsubfeatures = { }
                        luatex.features.gsub = gsubfeatures
                    end
                    local k = gsubfeatures[kind]
                    if not k then
                        k = { }
                        gsubfeatures[kind] = k
                    end
                    for script, languages in next, features do
                        local kk = k[script]
                        if not kk then
                            kk = { }
                            k[script] = kk
                        end
                        for language, value in next, languages do
                            kk[language] = value
                        end
                    end
                end
            end
            if done > 0 then
                if trace_loading then
                    report_otf("enhance: registering %s feature (%s glyphs affected)",kind,done)
                end
            end
        end
    end
end

otf.enhancers.register("check extra features",enhancedata)

local features = otf.tables.features

features['tlig'] = 'TeX Ligatures'
features['trep'] = 'TeX Replacements'
features['anum'] = 'Arabic Digits'

local registerbasesubstitution = otf.features.registerbasesubstitution

registerbasesubstitution('tlig')
registerbasesubstitution('trep')
registerbasesubstitution('anum')

-- the functionality is defined elsewhere

local initializers        = fonts.initializers
local common_initializers = initializers.common
local base_initializers   = initializers.base.otf
local node_initializers   = initializers.node.otf

base_initializers.equaldigits = common_initializers.equaldigits
node_initializers.equaldigits = common_initializers.equaldigits

base_initializers.lineheight  = common_initializers.lineheight
node_initializers.lineheight  = common_initializers.lineheight

base_initializers.compose     = common_initializers.compose
node_initializers.compose     = common_initializers.compose
