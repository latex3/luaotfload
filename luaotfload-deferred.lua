--- TODO integrate into luaotfload.dtx
--- this part is loaded after luatexbase
luaotfload.loadmodule("lib-dir.lua")    -- required by font-nms; will change with lualibs update
luaotfload.loadmodule("font-nms.lua")
luaotfload.loadmodule("font-clr.lua")

luatexbase.create_callback("luaotfload.patch_font", "simple", function() end)

local function def_font(...)
    local fontdata = fonts.define.read(...)
    if type(fontdata) == "table" and fontdata.shared then
        local otfdata = fontdata.shared.otfdata
        if otfdata.metadata.math then
            local mc = { }
            for k,v in next, otfdata.metadata.math do
                if k:find("Percent") then
                    -- keep percent values as is
                    mc[k] = v
                else
                    mc[k] = v / fontdata.units * fontdata.size
                end
            end
            -- for \overwithdelims
            mc.FractionDelimiterSize             = 1.01 * fontdata.size
            mc.FractionDelimiterDisplayStyleSize = 2.39 * fontdata.size

            fontdata.MathConstants = mc
        end
        luatexbase.call_callback("luaotfload.patch_font", fontdata)
    end
    return fontdata
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

--luaotfload.loadmodule("font-otc.lua") -- broken

--luatexbase.create_callback("luaotfload.patch_font", "simple", function() end)

--local function def_font(...)
    --local fontdata = fonts.define.read(...)
    --if type(fontdata) == "table" and fontdata.shared then
        --local otfdata = fontdata.shared.otfdata
        --if otfdata.metadata.math then
            --local mc = { }
            --for k,v in next, otfdata.metadata.math do
                --if k:find("Percent") then
                    ---- keep percent values as is
                    --mc[k] = v
                --else
                    --mc[k] = v / fontdata.units * fontdata.size
                --end
            --end
            ---- for \overwithdelims
            --mc.FractionDelimiterSize             = 1.01 * fontdata.size
            --mc.FractionDelimiterDisplayStyleSize = 2.39 * fontdata.size

            --fontdata.MathConstants = mc
        --end
        --luatexbase.call_callback("luaotfload.patch_font", fontdata)
    --end
    --return fontdata
--end
--fonts.mode = "node"

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
--luatexbase.add_to_callback("pre_linebreak_filter",
                            --nodes.simple_font_handler,
                           --"luaotfload.pre_linebreak_filter")
--luatexbase.add_to_callback("hpack_filter",
                            --nodes.simple_font_handler,
                           --"luaotfload.hpack_filter")
--luatexbase.reset_callback("define_font")
--luatexbase.add_to_callback("define_font",
                            --def_font,
                           --"luaotfload.define_font", 1)
--luatexbase.add_to_callback("find_vf_file",
                            --fonts.vf.find,
                           --"luaotfload.find_vf_file")
--local function set_sscale_diments(fontdata)
    --local mc = fontdata.MathConstants
    --if mc then
        --if mc["ScriptPercentScaleDown"] then
            --fontdata.parameters[10] = mc.ScriptPercentScaleDown
        --else -- resort to plain TeX default
            --fontdata.parameters[10] = 70
        --end
        --if mc["ScriptScriptPercentScaleDown"] then
            --fontdata.parameters[11] = mc.ScriptScriptPercentScaleDown
        --else -- resort to plain TeX default
            --fontdata.parameters[11] = 50
        --end
    --end
--end

--luatexbase.add_to_callback("luaotfload.patch_font", set_sscale_diments, "unicodemath.set_sscale_diments")
-- 
--  End of File `luaotfload.lua'.
