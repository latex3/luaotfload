if not modules then modules = { } end modules ["features"] = {
    version   = 1.000,
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert = string.format, table.insert
local type, next = type, next
local lpegmatch = lpeg.match

---[[ begin included font-ltx.lua ]]
--- this appears to be based in part on luatex-fonts-def.lua

local fonts = fonts

-- A bit of tuning for definitions.

fonts.constructors.namemode = "specification" -- somehow latex needs this (changed name!) => will change into an overload

--[[HH--
    tricky: we sort of bypass the parser and directly feed all into
    the sub parser
--HH]]--

function fonts.definers.getspecification(str)
    return "", str, "", ":", str
end

local old_feature_list = { }

local report = logs.names_report

local stringlower      = string.lower
local stringgsub       = string.gsub
local stringis_empty   = string.is_empty

--- this parses the optional flags after the slash
--- the original behavior is that multiple slashes
--- are valid but they might cancel prior settings
--- example: {name:Antykwa Torunska/I/B} -> bold

--- TODO an option to dump the default features for a script would make
---      a nice addition to luaotfload-tool

local defaults = {
    dflt = {
        "ccmp", "locl", "rlig", "liga", "clig",
        "kern", "mark", "mkmk", 'itlc',
    },
    arab = {
        "ccmp", "locl", "isol", "fina", "fin2",
        "fin3", "medi", "med2", "init", "rlig",
        "calt", "liga", "cswh", "mset", "curs",
        "kern", "mark", "mkmk",
    },
    deva = {
        "ccmp", "locl", "init", "nukt", "akhn",
        "rphf", "blwf", "half", "pstf", "vatu",
        "pres", "blws", "abvs", "psts", "haln",
        "calt", "blwm", "abvm", "dist", "kern",
        "mark", "mkmk",
    },
    khmr = {
        "ccmp", "locl", "pref", "blwf", "abvf",
        "pstf", "pres", "blws", "abvs", "psts",
        "clig", "calt", "blwm", "abvm", "dist",
        "kern", "mark", "mkmk",
    },
    thai = {
        "ccmp", "locl", "liga", "kern", "mark",
        "mkmk",
    },
    hang = {
        "ccmp", "ljmo", "vjmo", "tjmo",
    },
}

local global_defaults = { mode = "node" }

defaults.beng = defaults.deva
defaults.guru = defaults.deva
defaults.gujr = defaults.deva
defaults.orya = defaults.deva
defaults.taml = defaults.deva
defaults.telu = defaults.deva
defaults.knda = defaults.deva
defaults.mlym = defaults.deva
defaults.sinh = defaults.deva

defaults.syrc = defaults.arab
defaults.mong = defaults.arab
defaults.nko  = defaults.arab

defaults.tibt = defaults.khmr

defaults.lao  = defaults.thai

--[[doc--
Which features are active by default depends on the script requested.
--doc]]--

--- (string, string) dict -> (string, string) dict
local set_default_features = function (speclist)
    speclist = speclist or { }
    local script = speclist.script or "dflt"

    report("log", 0, "load",
        "auto-selecting default features for script: %s",
        script)

    local requested = defaults[script]
    if not requested then
        report("log", 0, "load",
            "no defaults for script “%s”, falling back to “dflt”",
            script)
        requested = defaults.dflt
    end

    for i=1, #requested do
        local feat = requested[i]
        if speclist[feat] ~= false then speclist[feat] = true end
    end

    for feat, state in next, global_defaults do
        --- This is primarily intended for setting node
        --- mode unless “base” is requested, as stated
        --- in the manual.
        if not speclist[feat] then speclist[feat] = state end
    end
    return speclist
end

-----------------------------------------------------------------------
---                    request syntax parser 2.2
-----------------------------------------------------------------------
--- the luaotfload font request syntax (see manual)
--- has a canonical form:
---
---     \font<csname>=<prefix>:<identifier>:<features>
---
--- where
---   <csname> is the control sequence that activates the font
---   <prefix> is either “file” or “name”, determining the lookup
---   <identifer> is either a file name (no path) or a font
---               name, depending on the lookup
---   <features> is a list of switches or options, separated by
---              semicolons or commas; a switch is of the form “+” foo
---              or “-” foo, options are of the form lhs “=” rhs
---
--- however, to ensure backward compatibility we also have
--- support for Xetex-style requests.
---
--- for the Xetex emulation see:
--- · The XeTeX Reference Guide by Will Robertson, 2011
--- · The XeTeX Companion by Michel Goosens, 2010
--- · About XeTeX by Jonathan Kew, 2005
---
---
--- caueat emptor.
---     the request is parsed into one of **four** different
---     lookup categories: the regular ones, file and name,
---     as well as the Xetex compatibility ones, path and anon.
---     (maybe a better choice of identifier would be “ambig”.)
---
---     according to my reconstruction, the correct chaining
---     of the lookups for each category is as follows:
---
---     | File -> ( db/filename lookup;
---                 db/basename lookup;
---                 kpse.find_file() )
---     | Name -> ( names.resolve() )
---     | Path -> ( db/filename lookup;
---                 db/basename lookup;
---                 kpse.find_file();
---                 fullpath lookup )
---     | Anon -> ( names.resolve();      (* most general *)
---                 db/filename lookup;
---                 db/basename lookup;
---                 kpse.find_file();
---                 fullpath lookup )
---
---     the database should be generated only if the chain has
---     been completed, and then only once.
---
---     caching of successful lookups is essential. we need
---     an additional subtable "cached" in the database. it
---     should be nil’able by issuing luaotfload-tool --flush or
---     something. if a cache miss is followed by a successful
---     lookup, then it will be counted as new addition to the
---     cache. we also need a config option to ignore caching.
---
---     also everything has to be finished by tomorrow at noon.
---
-----------------------------------------------------------------------


local toboolean = function (s)
  if s == "true"  then return true  end
  if s == "false" then return false end
--if s == "yes"   then return true  end --- Context style
--if s == "no"    then return false end
  return s
end

local lpegmatch = lpeg.match
local P, S, R   = lpeg.P, lpeg.S, lpeg.R
local C, Cc, Cf, Cg, Cs, Ct
    = lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Cs, lpeg.Ct

--- terminals and low-level classes -----------------------------------
--- note we could use the predefined ones from lpeg.patterns
local dot         = P"."
local colon       = P":"
local featuresep  = S",;"
local slash       = P"/"
local equals      = P"="
local lbrk, rbrk  = P"[", P"]"

local spacing     = S" \t\v"
local ws          = spacing^0

local digit       = R"09"
local alpha       = R("az", "AZ")
local anum        = alpha + digit
local decimal     = digit^1 * (dot * digit^0)^-1

--- modifiers ---------------------------------------------------------
--[[doc--
    The slash notation: called “modifiers” (Kew) or “font options”
    (Robertson, Goosens)
    we only support the shorthands for italic / bold / bold italic
    shapes, the rest is ignored.
--doc]]--
local style_modifier    = (P"BI" + P"IB" + P"bi" + P"ib" + S"biBI")
                        / stringlower
local size_modifier     = S"Ss" * P"="    --- optical size
                        * Cc"optsize" * C(decimal)
local other_modifier    = P"AAT" + P"aat" --- apple stuff;  unsupported
                        + P"ICU" + P"icu" --- not applicable
                        + P"GR"  + P"gr"  --- sil stuff;    unsupported
local garbage_modifier  = ((1 - colon - slash)^0 * Cc(false))
local modifier          = slash * (other_modifier      --> ignore
                                 + Cs(style_modifier)  --> collect
                                 + Ct(size_modifier)   --> collect
                                 + garbage_modifier)   --> warn
local modifier_list     = Cg(Ct(modifier^0), "modifiers")

--- lookups -----------------------------------------------------------
local fontname          = C((1-S"/:(")^1) --- like luatex-fonts
local prefixed          = P"name:" * ws * Cg(fontname, "name")
                        + P"file:" * ws * Cg(fontname, "file")
local unprefixed        = Cg(fontname, "anon")
local path_lookup       = lbrk * Cg(C((1-rbrk)^1), "path") * rbrk

--- features ----------------------------------------------------------
local field             = (anum + S"+-.")^1 --- sic!
--- assignments are “lhs=rhs”
--- switches    are “+key” | “-key”
local assignment        = C(field) * ws * equals * ws * (field / toboolean)
local switch            = P"+" * ws * C(field) * Cc(true)
                        + P"-" * ws * C(field) * Cc(false)
                        +             C(field) * Cc(true) -- catch crap
local feature_expr      = ws * Cg(assignment + switch) * ws
local feature_list      = Cf(Ct""
                           * feature_expr
                           * (featuresep * feature_expr)^0
                           , rawset)
                        * featuresep^-1

--- other -------------------------------------------------------------
--- This rule is present in the original parser. It sets the “sub”
--- field of the specification which allows addressing a specific
--- font inside a TTC container. Neither in Luatex-Fonts nor in
--- Luaotfload is this documented, so we might as well silently drop
--- it. However, as backward compatibility is one of our prime goals we
--- just insert it here and leave it undocumented until someone cares
--- to ask. (Note: afair subfonts are numbered, but this rule matches a
--- string; I won’t mess with it though until someone reports a
--- problem.)
--- local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
---                                                                 Who’s Kim?
--- Note to self: subfonts apparently start at index 0. Tested with
--- Cambria.ttc that includes “Cambria Math” at 0 and “Cambria” at 1.
--- Other values cause luatex to segfault.
local subfont           = P"(" * Cg((1 - S"()")^1, "sub") * P")"
--- top-level rules ---------------------------------------------------
--- \font\foo=<specification>:<features>
local features          = Cg(feature_list, "features")
local specification     = (prefixed + unprefixed)
                        * subfont^-1
                        * modifier_list^-1
local font_request      = Ct(path_lookup   * (colon^-1 * features)^-1
                           + specification * (colon    * features)^-1)

-- lpeg.print(font_request)
--- new parser: 632 rules
--- old parser: 230 rules

local import_values = {
    --- That’s what the 1.x parser did, not quite as graciously,
    --- with an array of branch expressions.
    -- "style", "optsize",--> from slashed notation; handled otherwise
    "lookup", "sub" --[[‽]], "mode",
}

local lookup_types = { "anon", "file", "name", "path" }

local select_lookup = function (request)
    for i=1, #lookup_types do
        local lookup = lookup_types[i]
        local value  = request[lookup]
        if value then
            return lookup, value
        end
    end
end

local supported = {
    b    = "bold",
    i    = "italic",
    bi   = "bolditalic",
    aat  = false,
    icu  = false,
    gr   = false,
}

local handle_slashed = function (modifiers)
    local style, optsize
    for i=1, #modifiers do
        local mod  = modifiers[i]
        if type(mod) == "table" and mod[1] == "optsize" then --> optical size
            optsize = tonumber(mod[2])
        elseif supported[mod] then
            style = supported[mod]
        elseif stylename == false then
            report("log", 0,
                "load", "unsupported font option: %s", v)
        elseif not stringis_empty(v) then
            style = stringgsub(v, "[^%a%d]", "")
        end
    end
    return style, optsize
end

--- spec -> spec
local handle_request = function (specification)
    local request = lpegmatch(font_request,
                              specification.specification)
    if not request then
        --- happens when called with an absolute path
        --- in an anonymous lookup;
        --- we try to behave as friendly as possible
        --- just go with it ...
        report("log", 0, "load", "invalid request “%s” of type anon",
            specification.specification)
        report("log", 0, "load", "use square bracket syntax or consult the documentation.")
        specification.name      = specification.specification
        specification.lookup    = "file"
        return specification
    end
    local lookup, name = select_lookup(request)
    request.features  = set_default_features(request.features)

    if name then
        specification.name    = name
        specification.lookup  = lookup or specification.lookup
    end

    if request.modifiers then
        local style, optsize = handle_slashed(request.modifiers)
        specification.style, specification.optsize = style, optsize
    end

    for n=1, #import_values do
        local feat       = import_values[n]
        local newvalue   = request.features[feat]
        if newvalue then
            specification[feat]    = request.features[feat]
            request.features[feat] = nil
        end
    end

    --- The next line sets the “rand” feature to “random”; I haven’t
    --- investigated it any further (luatex-fonts-ext), so it will
    --- just stay here.
    specification.features.normal
        = fonts.handlers.otf.features.normalize(request.features)
    return specification
end

local compare_requests = function (spec)
    local old = old_behavior(spec)
    local new = handle_request(spec)
    return new
end

fonts.definers.registersplit(":", handle_request, "cryptic")
fonts.definers.registersplit("",  handle_request, "more cryptic") -- catches \font\text=[names]

---[[ end included font-ltx.lua ]]

--[[doc--
This uses the code from luatex-fonts-merged (<- font-otc.lua) instead
of the removed luaotfload-font-otc.lua.

TODO find out how far we get setting features without these lines,
relying on luatex-fonts only (it *does* handle features somehow, after
all).
--doc]]--

-- we assume that the other otf stuff is loaded already

---[[ begin snippet from font-otc.lua ]]
local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

local otf                 = fonts.handlers.otf
local registerotffeature  = otf.features.register
local setmetatableindex   = table.setmetatableindex

-- In the userdata interface we can not longer tweak the loaded font as
-- conveniently as before. For instance, instead of pushing extra data in
-- in the table using the original structure, we now have to operate on
-- the mkiv representation. And as the fontloader interface is modelled
-- after fontforge we cannot change that one too much either.

local types = {
    substitution = "gsub_single",
    ligature     = "gsub_ligature",
    alternate    = "gsub_alternate",
}

setmetatableindex(types, function(t,k) t[k] = k return k end) -- "key"

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { }

local function addfeature(data,feature,specifications)
    local descriptions = data.descriptions
    local resources    = data.resources
    local lookups      = resources.lookups
    local gsubfeatures = resources.features.gsub
    if gsubfeatures and gsubfeatures[feature] then
        -- already present
    else
        local sequences    = resources.sequences
        local fontfeatures = resources.features
        local unicodes     = resources.unicodes
        local lookuptypes  = resources.lookuptypes
        local splitter     = lpeg.splitter(" ",unicodes)
        local done         = 0
        local skip         = 0
        if not specifications[1] then
            -- so we accept a one entry specification
            specifications = { specifications }
        end
        -- subtables are tables themselves but we also accept flattened singular subtables
        for s=1,#specifications do
            local specification = specifications[s]
            local valid         = specification.valid
            if not valid or valid(data,specification,feature) then
                local initialize = specification.initialize
                if initialize then
                    -- when false is returned we initialize only once
                    specification.initialize = initialize(specification) and initialize or nil
                end
                local askedfeatures = specification.features or everywhere
                local subtables     = specification.subtables or { specification.data } or { }
                local featuretype   = types[specification.type or "substitution"]
                local featureflags  = specification.flags or noflags
                local added         = false
                local featurename   = format("ctx_%s_%s",feature,s)
                local st = { }
                for t=1,#subtables do
                    local list = subtables[t]
                    local full = format("%s_%s",featurename,t)
                    st[t] = full
                    if featuretype == "gsub_ligature" then
                        lookuptypes[full] = "ligature"
                        for code, ligature in next, list do
                            local unicode = tonumber(code) or unicodes[code]
                            local description = descriptions[unicode]
                            if description then
                                local slookups = description.slookups
                                if type(ligature) == "string" then
                                    ligature = { lpegmatch(splitter,ligature) }
                                end
                                local present = true
                                for i=1,#ligature do
                                    if not descriptions[ligature[i]] then
                                        present = false
                                        break
                                    end
                                end
                                if present then
                                    if slookups then
                                        slookups[full] = ligature
                                    else
                                        description.slookups = { [full] = ligature }
                                    end
                                    done, added = done + 1, true
                                else
                                    skip = skip + 1
                                end
                            end
                        end
                    elseif featuretype == "gsub_single" then
                        lookuptypes[full] = "substitution"
                        for code, replacement in next, list do
                            local unicode = tonumber(code) or unicodes[code]
                            local description = descriptions[unicode]
                            if description then
                                local slookups = description.slookups
                                replacement = tonumber(replacement) or unicodes[replacement]
                                if descriptions[replacement] then
                                    if slookups then
                                        slookups[full] = replacement
                                    else
                                        description.slookups = { [full] = replacement }
                                    end
                                    done, added = done + 1, true
                                end
                            end
                        end
                    end
                end
                if added then
                    -- script = { lang1, lang2, lang3 } or script = { lang1 = true, ... }
                    for k, v in next, askedfeatures do
                        if v[1] then
                            askedfeatures[k] = table.tohash(v)
                        end
                    end
                    sequences[#sequences+1] = {
                        chain     = 0,
                        features  = { [feature] = askedfeatures },
                        flags     = featureflags,
                        name      = featurename,
                        subtables = st,
                        type      = featuretype,
                    }
                    -- register in metadata (merge as there can be a few)
                    if not gsubfeatures then
                        gsubfeatures  = { }
                        fontfeatures.gsub = gsubfeatures
                    end
                    local k = gsubfeatures[feature]
                    if not k then
                        k = { }
                        gsubfeatures[feature] = k
                    end
                    for script, languages in next, askedfeatures do
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
        end
        if trace_loading then
            report_otf("registering feature %a, affected glyphs %a, skipped glyphs %a",feature,done,skip)
        end
    end
end

otf.enhancers.addfeature = addfeature

local extrafeatures = { }

function otf.addfeature(name,specification)
    extrafeatures[name] = specification
end

local function enhance(data,filename,raw)
    for feature, specification in next, extrafeatures do
        addfeature(data,feature,specification)
    end
end

otf.enhancers.register("check extra features",enhance)

---[[ end snippet from font-otc.lua ]]

local tlig = {
    {
        type      = "substitution",
        features  = everywhere,
        data      = {
            [0x0022] = 0x201D,                   -- quotedblright
            [0x0027] = 0x2019,                   -- quoteleft
            [0x0060] = 0x2018,                   -- quoteright
        },
        flags     = { },
    },
    {
        type     = "ligature",
        features = everywhere,
        data     = {
            [0x2013] = {0x002D, 0x002D},         -- endash
            [0x2014] = {0x002D, 0x002D, 0x002D}, -- emdash
            [0x201C] = {0x2018, 0x2018},         -- quotedblleft
            [0x201D] = {0x2019, 0x2019},         -- quotedblright
            [0x201E] = {0x002C, 0x002C},         -- quotedblbase
            [0x00A1] = {0x0021, 0x2018},         -- exclamdown
            [0x00BF] = {0x003F, 0x2018},         -- questiondown
        },
        flags    = { },
    },
    {
        type     = "ligature",
        features = everywhere,
        data     = {
            [0x201C] = {0x0060, 0x0060},         -- quotedblleft
            [0x201D] = {0x0027, 0x0027},         -- quotedblright
            [0x00A1] = {0x0021, 0x0060},         -- exclamdown
            [0x00BF] = {0x003F, 0x0060},         -- questiondown
        },
        flags    = { },
    },
}

otf.addfeature("tlig", tlig)
otf.addfeature("trep", { }) -- empty, all in tlig now

local anum_arabic = { --- these are the same as in font-otc
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
}

local anum_persian = {--- these are the same as in font-otc
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
}

local function valid(data)
    local features = data.resources.features
    if features then
        for k, v in next, features do
            for k, v in next, v do
                if v.arab then
                    return true
                end
            end
        end
    end
end

local anum_specification = {
    {
        type     = "substitution",
        features = { arab = { far = true, urd = true, snd = true } },
        data     = anum_persian,
        flags    = { },
        valid    = valid,
    },
    {
        type     = "substitution",
        features = { arab = { ["*"] = true } },
        data     = anum_arabic,
        flags    = { },
        valid    = valid,
    },
}

--- below the specifications as given in the removed font-otc.lua
--- the rest was identical to what this file had from the beginning
--- both make the “anum.tex” test pass anyways
--
--local anum_specification = {
--    {
--        type     = "substitution",
--        features = { arab = { urd = true, dflt = true } },
--        data     = anum_arabic,
--        flags    = noflags, -- { },
--        valid    = valid,
--    },
--    {
--        type     = "substitution",
--        features = { arab = { urd = true } },
--        data     = anum_persian,
--        flags    = noflags, -- { },
--        valid    = valid,
--    },
--}
--
otf.addfeature("anum",anum_specification)

registerotffeature {
    name        = 'anum',
    description = 'arabic digits',
}

if characters.combined then

    local tcom = { }

    local function initialize()
        characters.initialize()
        for first, seconds in next, characters.combined do
            for second, combination in next, seconds do
                tcom[combination] = { first, second }
            end
        end
        -- return false
    end

    local tcom_specification = {
        type       = "ligature",
        features   = everywhere,
        data       = tcom,
        flags      = noflags,
        initialize = initialize,
    }

    otf.addfeature("tcom",tcom_specification)

    registerotffeature {
        name        = 'tcom',
        description = 'tex combinations',
    }

end

-- vim:tw=71:sw=4:ts=4:expandtab
