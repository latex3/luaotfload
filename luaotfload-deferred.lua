--- TODO integrate into luaotfload.dtx

local type, next = type, next

local stringfind = string.find
--- this part is loaded after luatexbase
local loadmodule      = luaotfload.loadmodule
local luatexbase      = luatexbase
local generic_context = generic_context --- from fontloader

local add_to_callback, create_callback =
      luatexbase.add_to_callback, luatexbase.create_callback
local reset_callback, call_callback =
      luatexbase.reset_callback, luatexbase.call_callback

--[[doc--
We do our own callback handling with the means provided by luatexbase.

Note: \verb|pre_linebreak_filter| and \verb|hpack_filter| are coupled
in \CONTEXT\ in the concept of \emph{node processor}.
--doc]]--

add_to_callback("pre_linebreak_filter",
                generic_context.callback_pre_linebreak_filter,
                "luaotfload.node_processor",
                1)
add_to_callback("hpack_filter",
                generic_context.callback_hpack_filter,
                "luaotfload.node_processor",
                1)

loadmodule("lib-dir.lua")    -- required by font-nms; will change with lualibs update
loadmodule("font-nms.lua")
loadmodule("font-clr.lua")
--loadmodule("font-ovr.lua")
loadmodule("font-ltx.lua")

local dummy_function = function ( ) end --- upvalue more efficient than lambda
create_callback("luaotfload.patch_font", "simple", dummy_function)

--[[doc--
This is a wrapper for the imported font loader.
As of 2013, everything it does appears to be redundand, so we won’t use
it.
Nevertheless, it has been adapted to work with the current structure of
font data objects and will stay here for reference / until somebody
reports breakage.

TODO
This one also enables patching fonts.
The current fontloader apparently comes with a dedicated mechanism for
that already: enhancers.
How those work remains to be figured out.
--doc]]--
local define_font_wrapper = function (...)
    --- we use “tfmdata” (not “fontdata”) for consistency with the
    --- font loader
    local tfmdata = fonts.definers.read(...)
    if type(tfmdata) == "table" and tfmdata.shared then
        local metadata = tfmdata.shared.rawdata.metadata
        local mathdata = metadata.math --- do all fonts have this field?
        if mathdata then
            local mathconstants = { } --- why new hash, not modify in place?
            local units_per_em  = metadata.units_per_em
            local size          = tfmdata.size
            for k,v in next, mathdata do
                --- afaics this is alread taken care of by
                --- definers.read
                if stringfind(k, "Percent") then
                    -- keep percent values as is
                    print(k,v)
                    mathconstants[k] = v
                else
                    mathconstants[k] = v / units_per_em * size
                end
            end
            --- for \overwithdelims
            --- done by definers.read as well
            mathconstants.FractionDelimiterSize             = 1.01 * size
            --- fontloader has 2.4 × size
            mathconstants.FractionDelimiterDisplayStyleSize = 2.39 * size
            tfmdata.MathConstants = mathconstants
        end
        call_callback("luaotfload.patch_font", tfmdata)
    end
    return tfmdata
end

--[[doc--
We provide a simplified version of the original font definition
callback.
--doc]]--
local patch_defined_font = function (...)
    local tfmdata = fonts.definers.read(...)
    if type(tfmdata) == "table" and tfmdata.shared then
        call_callback("luaotfload.patch_font", tfmdata)
    end
    return tfmdata
end

fonts.mode = "node"

function attributes.private(name)
    local attr   = "otfl@" .. name
    local number = luatexbase.attributes[attr]
    if not number then
        number = luatexbase.new_attribute(attr)
    end
    return number
end

reset_callback("define_font")

if luaotfload.font_definer == "old"  then
  add_to_callback("define_font",
                  old_define_font_wrapper,
                  "luaotfload.define_font",
                  1)
elseif luaotfload.font_definer == "generic"  then
  add_to_callback("define_font",
                  generic_context.callback_define_font,
                  "luaotfload.define_font",
                  1)
elseif luaotfload.font_definer == "patch"  then
  add_to_callback("define_font",
                  patch_defined_font,
                  "luaotfload.define_font",
                  1)
end

--luaotfload.loadmodule("font-otc.lua") -- broken

--local register_base_sub = fonts.otf.features.register_base_substitution
--local gsubs = {
    --"ss01", "ss02", "ss03", "ss04", "ss05",
    --"ss06", "ss07", "ss08", "ss09", "ss10",
    --"ss11", "ss12", "ss13", "ss14", "ss15",
    --"ss16", "ss17", "ss18", "ss19", "ss20",
--}

--for _,v in next, gsubs do
    --register_base_sub(v)
--end
--add_to_callback("find_vf_file",
                 --fonts.vf.find,
                --"luaotfload.find_vf_file")

local set_sscale_diments = function (tfmdata)
    local mathconstants = tfmdata.MathConstants
    if mathconstants then
        local tfmparameters = tfmdata.parameters
        if mathconstants.ScriptPercentScaleDown then
            tfmparameters[10] = mathconstants.ScriptPercentScaleDown
        else -- resort to plain TeX default
            tfmparameters[10] = 70
        end
        if mathconstants.ScriptScriptPercentScaleDown then
            tfmparameters[11] = mathconstants.ScriptScriptPercentScaleDown
        else -- resort to plain TeX default
            tfmparameters[11] = 50
        end
    end
end

add_to_callback("luaotfload.patch_font",
                set_sscale_diments,
                "unicodemath.set_sscale_diments")

-- vim:tw=71:sw=2:ts=2:expandtab

--  End of File `luaotfload.lua'.
