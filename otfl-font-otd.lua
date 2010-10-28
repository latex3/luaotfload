if not modules then modules = { } end modules ['font-otd'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_dynamics = false  trackers.register("otf.dynamics", function(v) trace_dynamics = v end)

local report_otf = logs.new("load otf")

local fonts          = fonts
local otf            = fonts.otf
local fontdata       = fonts.ids

otf.features         = otf.features         or { }
otf.features.default = otf.features.default or { }

local definers       = fonts.definers
local contextsetups  = definers.specifiers.contextsetups
local contextnumbers = definers.specifiers.contextnumbers

-- todo: dynamics namespace

local a_to_script   = { }
local a_to_language = { }

function otf.setdynamics(font,dynamics,attribute)
    local features = contextsetups[contextnumbers[attribute]] -- can be moved to caller
    if features then
        local script   = features.script   or 'dflt'
        local language = features.language or 'dflt'
        local ds = dynamics[script]
        if not ds then
            ds = { }
            dynamics[script] = ds
        end
        local dsl = ds[language]
        if not dsl then
            dsl = { }
            ds[language] = dsl
        end
        local dsla = dsl[attribute]
        if dsla then
        --  if trace_dynamics then
        --      report_otf("using dynamics %s: attribute %s, script %s, language %s",contextnumbers[attribute],attribute,script,language)
        --  end
            return dsla
        else
            local tfmdata = fontdata[font]
            a_to_script  [attribute] = script
            a_to_language[attribute] = language
            -- we need to save some values
            local saved = {
                script    = tfmdata.script,
                language  = tfmdata.language,
                mode      = tfmdata.mode,
                features  = tfmdata.shared.features
            }
            tfmdata.mode     = "node"
            tfmdata.dynamics = true -- handy for tracing
            tfmdata.language = language
            tfmdata.script   = script
            tfmdata.shared.features = { }
            -- end of save
            local set = definers.check(features,otf.features.default)
            dsla = otf.setfeatures(tfmdata,set)
            if trace_dynamics then
                report_otf("setting dynamics %s: attribute %s, script %s, language %s, set: %s",contextnumbers[attribute],attribute,script,language,table.sequenced(set))
            end
            -- we need to restore some values
            tfmdata.script          = saved.script
            tfmdata.language        = saved.language
            tfmdata.mode            = saved.mode
            tfmdata.shared.features = saved.features
            -- end of restore
            dynamics[script][language][attribute] = dsla -- cache
            return dsla
        end
    end
    return nil -- { }
end

function otf.scriptandlanguage(tfmdata,attr)
    if attr and attr > 0 then
        return a_to_script[attr] or tfmdata.script, a_to_language[attr] or tfmdata.language
    else
        return tfmdata.script, tfmdata.language
    end
end
