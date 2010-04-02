if not modules then modules = { } end modules ['math-dim'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Beware: only Taco really understands in depth what these dimensions do so
-- if you run into problems ...

local abs, next = math.abs, next

mathematics = mathematics or { }

local defaults = {
    ['axis']={
        ['default']={ "AxisHeight", "axis_height" },
    },
    ['accent_base_height']={
        ['default']={ "AccentBaseHeight", "x_height" },
    },
    ['fraction_del_size']={
        ['default']={ "FractionDelimiterSize", "delim2" },
        ['cramped_display_style']={ "FractionDelimiterDisplayStyleSize", "delim1" },
        ['display_style']={ "FractionDelimiterDisplayStyleSize", "delim1" },
     },
    ['fraction_denom_down']={
        ['default']={ "FractionDenominatorShiftDown", "denom2" },
        ['cramped_display_style']={ "FractionDenominatorDisplayStyleShiftDown", "denom1" },
        ['display_style']={ "FractionDenominatorDisplayStyleShiftDown", "denom1" },
     },
    ['fraction_denom_vgap']={
        ['default']={ "FractionDenominatorGapMin", "default_rule_thickness" },
        ['cramped_display_style']={ "FractionDenominatorDisplayStyleGapMin", "3*default_rule_thickness" },
        ['display_style']={ "FractionDenominatorDisplayStyleGapMin", "3*default_rule_thickness" },
     },
    ['fraction_num_up']={
        ['default']={ "FractionNumeratorShiftUp", "num2" },
        ['cramped_display_style']={ "FractionNumeratorDisplayStyleShiftUp", "num1" },
        ['display_style']={ "FractionNumeratorDisplayStyleShiftUp", "num1" },
     },
     ['fraction_num_vgap']={
        ['default']={ "FractionNumeratorGapMin", "default_rule_thickness" },
        ['cramped_display_style']={ "FractionNumeratorDisplayStyleGapMin", "3*default_rule_thickness" },
        ['display_style']={ "FractionNumeratorDisplayStyleGapMin", "3*default_rule_thickness" },
     },
    ['fraction_rule']={
        ['default']={ "FractionRuleThickness", "default_rule_thickness" },
     },
    ['limit_above_bgap']={
        ['default']={ "UpperLimitBaselineRiseMin", "big_op_spacing3" },
     },
    ['limit_above_kern']={
        ['default']={ "0", "big_op_spacing5" },
     },
    ['limit_above_vgap']={
        ['default']={ "UpperLimitGapMin", "big_op_spacing1" },
     },
    ['limit_below_bgap']={
        ['default']={ "LowerLimitBaselineDropMin", "big_op_spacing4" },
     },
    ['limit_below_kern']={
        ['default']={ "0", "big_op_spacing5" },
     },
    ['limit_below_vgap']={
        ['default']={ "LowerLimitGapMin", "big_op_spacing2" },
     },

--~     ['....']={
--~         ['default']={ "DisplayOperatorMinHeight", "....." },
--~     },

    ['overbar_kern']={
        ['default']={ "OverbarExtraAscender", "default_rule_thickness" },
     },
    ['overbar_rule']={
        ['default']={ "OverbarRuleThickness", "default_rule_thickness" },
     },
    ['overbar_vgap']={
        ['default']={ "OverbarVerticalGap", "3*default_rule_thickness" },
     },
    ['quad']={
        ['default']={ "font_size(f)", "math_quad" },
     },
    ['radical_kern']={
        ['default']={ "RadicalExtraAscender", "default_rule_thickness" },
     },
    ['radical_rule']={
        ['default']={ "RadicalRuleThickness", "<not set>" },
     },
    ['radical_vgap']={
        ['default']={ "RadicalVerticalGap", "default_rule_thickness+(abs(default_rule_thickness)/4)" },
        ['display_style']={ "RadicalDisplayStyleVerticalGap", "default_rule_thickness+(abs(math_x_height)/4)" },
     },
    ['space_after_script']={
        ['default']={ "SpaceAfterScript", "script_space" },
     },
    ['stack_denom_down']={
        ['default']={ "StackBottomShiftDown", "denom2" },
        ['cramped_display_style']={ "StackBottomDisplayStyleShiftDown", "denom1" },
        ['display_style']={ "StackBottomDisplayStyleShiftDown", "denom1" },
     },
    ['stack_num_up']={
        ['default']={ "StackTopShiftUp", "num3" },
        ['cramped_display_style']={ "StackTopDisplayStyleShiftUp", "num1" },
        ['display_style']={ "StackTopDisplayStyleShiftUp", "num1" },
     },
    ['stack_vgap']={
        ['default']={ "StackGapMin", "3*default_rule_thickness" },
        ['cramped_display_style']={ "StackDisplayStyleGapMin", "7*default_rule_thickness" },
        ['display_style']={ "StackDisplayStyleGapMin", "7*default_rule_thickness" },
     },
    ['sub_shift_down']={
        ['default']={ "SubscriptShiftDown", "sub1" },
     },
    ['sub_shift_drop']={
        ['default']={ "SubscriptBaselineDropMin", "sub_drop" },
     },
    ['sub_sup_shift_down']={
        ['default']={ "SubscriptShiftDown", "sub2" }, -- todo
     },
    ['sub_top_max']={
        ['default']={ "SubscriptTopMax", "abs(math_x_height*4)/5" },
     },
    ['subsup_vgap']={
        ['default']={ "SubSuperscriptGapMin", "4*default_rule_thickness" },
     },
    ['sup_bottom_min']={
        ['default']={ "SuperscriptBottomMin", "abs(math_x_height)/4" },
     },
    ['sup_shift_drop']={
        ['default']={ "SuperscriptBaselineDropMax", "sup_drop" },
     },
    ['sup_shift_up']={
        ['cramped_display_style']={ "SuperscriptShiftUpCramped", "sup3" },
        ['cramped_script_script_style']={ "SuperscriptShiftUpCramped", "sup3" },
        ['cramped_script_style']={ "SuperscriptShiftUpCramped", "sup3" },
        ['cramped_text_style']={ "SuperscriptShiftUpCramped", "sup3" },
        ['display_style']={ "SuperscriptShiftUp", "sup1" },
        ['script_script_style']={ "SuperscriptShiftUp", "sup2" },
        ['script_style']={ "SuperscriptShiftUp", "sup2" },
        ['text_style']={ "SuperscriptShiftUp", "sup2" },
     },
    ['sup_sub_bottom_max']={
        ['default']={ "SuperscriptBottomMaxWithSubscript", "abs(math_x_height*4)/5" },
     },
    ['underbar_kern']={
        ['default']={ "UnderbarExtraDescender", "0" },
     },
    ['underbar_rule']={
        ['default']={ "UnderbarRuleThickness", "default_rule_thickness" },
    },
    ['underbar_vgap']={
        ['default']={ "UnderbarVerticalGap", "3*default_rule_thickness" },
    },
    ['connector_overlap_min']={
        ['default']={ "MinConnectorOverlap", "0.25*default_rule_thickness" },
     },
    ['over_delimiter_vgap']={
        ['default']={ "StretchStackGapBelowMin", "big_op_spacing1" },
    },
    ['over_delimiter_bgap']={
        ['default']={ "StretchStackTopShiftUp", "big_op_spacing3" },
    },
    ['under_delimiter_vgap']={
        ['default']={ "StretchStackGapAboveMin", "big_op_spacing2" },
    },
    ['under_delimiter_bgap']={
        ['default']={ "StretchStackBottomShiftDown", "big_op_spacing4" },
    },
    ['radical_degree_before']={
        ['default']={ "RadicalKernBeforeDegree", "(5/18)*quad" },
    },
    ['radical_degree_after']={
        ['default']={ "RadicalKernAfterDegree", "(-10/18)*quad" },
    },
    ['radical_degree_raise']={
        ['default']={ "RadicalDegreeBottomRaisePercent", "60" },
    },
}

local styles = {
    'cramped_display_style',
    'cramped_script_script_style',
    'cramped_script_style',
    'cramped_text_style',
    'display_style',
    'script_script_style',
    'script_style',
    'text_style',
}

for k, v in next, defaults do
    for _, s in next, styles do
        if not v[s] then
            v[s] = v.default
        end
    end
end

-- we cannot use a metatable because we do a copy (takes a bit more work)
--
-- local mt = { }  setmetatable(defaults,mt)
--
-- mt.__index = function(t,s)
--     return t.default or t.text_style or 0
-- end

function mathematics.dimensions(dimens)
    if dimens.SpaceAfterScript then
        dimens.SubscriptShiftDownWithSuperscript = dimens.SubscriptShiftDown * 1.5
        return { }, table.fastcopy(dimens)
    elseif dimens.AxisHeight or dimens.axis_height then
        local t = { }
        local math_x_height = dimens.x_height or 10*65526
        local math_quad = dimens.quad or 10*65526
        local default_rule_thickness = dimens.FractionDenominatorGapMin or dimens.default_rule_thickness or 0.4*65526
        dimens["0"] = 0
        dimens["60"] = 60
        dimens["0.25*default_rule_thickness"] = default_rule_thickness / 4
        dimens["3*default_rule_thickness"] = 3 * default_rule_thickness
        dimens["4*default_rule_thickness"] = 4 * default_rule_thickness
        dimens["7*default_rule_thickness"] = 7 * default_rule_thickness
        dimens["(5/18)*quad"] = (math_quad * 5) / 18
        dimens["(-10/18)*quad"] = - (math_quad * 10) / 18
        dimens["abs(math_x_height*4)/5"] = abs(math_x_height * 4) / 5
        dimens["default_rule_thickness+(abs(default_rule_thickness)/4)"] = default_rule_thickness+(abs(default_rule_thickness) / 4)
        dimens["default_rule_thickness+(abs(math_x_height)/4)"] = default_rule_thickness+(abs(math_x_height) / 4)
        dimens["abs(math_x_height)/4"] = abs(math_x_height) / 4
        dimens["abs(math_x_height*4)/5"] = abs(math_x_height * 4) / 5
        dimens["<not set>"] = false
        dimens["script_space"] = false -- at macro level
        for variable, styles in next, defaults do
            local tt = { }
            for style, default in next, styles do
                local one, two = default[1], default[2]
                local value = dimens[one]
                if value then
                    tt[style] = value
                else
                    value = dimens[two]
                    if value == false then
                        tt[style] = nil
                    else
                        tt[style] = value or 0
                    end
                end
            end
            t[variable] = tt
        end
--~ logs.report("warning", "version 0.47 is needed for proper delimited math")
        local d = {
            AxisHeight                                  = t . axis                  . text_style,
            AccentBaseHeight                            = t . accent_base_height    . text_style,
            FractionDenominatorDisplayStyleGapMin       = t . fraction_denom_vgap   . display_style,
            FractionDenominatorDisplayStyleShiftDown    = t . fraction_denom_down   . display_style,
            FractionDenominatorGapMin                   = t . fraction_denom_vgap   . text_style,
            FractionDenominatorShiftDown                = t . fraction_denom_down   . text_style,
            FractionNumeratorDisplayStyleGapMin         = t . fraction_num_vgap     . display_style,
            FractionNumeratorDisplayStyleShiftUp        = t . fraction_num_up       . display_style,
            FractionNumeratorGapMin                     = t . fraction_num_vgap     . text_style,
            FractionNumeratorShiftUp                    = t . fraction_num_up       . text_style,
            FractionRuleThickness                       = t . fraction_rule         . text_style,
            FractionDelimiterSize                       = t . fraction_del_size     . text_style,
            FractionDelimiterDisplayStyleSize           = t . fraction_del_size     . display_style,
            LowerLimitBaselineDropMin                   = t . limit_below_bgap      . text_style,
            LowerLimitGapMin                            = t . limit_below_vgap      . text_style,
            OverbarExtraAscender                        = t . overbar_kern          . text_style,
            OverbarRuleThickness                        = t . overbar_rule          . text_style,
            OverbarVerticalGap                          = t . overbar_vgap          . text_style,
            RadicalDisplayStyleVerticalGap              = t . radical_vgap          . display_style,
            RadicalExtraAscender                        = t . radical_kern          . text_style,
            RadicalRuleThickness                        = t . radical_rule          . text_style,
            RadicalVerticalGap                          = t . radical_vgap          . text_style,
            RadicalKernBeforeDegree                     = t . radical_degree_before . display_style,
            RadicalKernAfterDegree                      = t . radical_degree_after  . display_style,
            RadicalDegreeBottomRaisePercent             = t . radical_degree_raise  . display_style,
            SpaceAfterScript                            = t . space_after_script    . text_style,
            StackBottomDisplayStyleShiftDown            = t . stack_denom_down      . display_style,
            StackBottomShiftDown                        = t . stack_denom_down      . text_style,
            StackDisplayStyleGapMin                     = t . stack_vgap            . display_style,
            StackGapMin                                 = t . stack_vgap            . text_style,
            StackTopDisplayStyleShiftUp                 = t . stack_num_up          . display_style,
            StackTopShiftUp                             = t . stack_num_up          . text_style,
            SubscriptBaselineDropMin                    = t . sub_shift_drop        . text_style,
            SubscriptShiftDown                          = t . sub_shift_down        . text_style,
            SubscriptShiftDownWithSuperscript           = t . sub_sup_shift_down    . text_style,
            SubscriptTopMax                             = t . sub_top_max           . text_style,
            SubSuperscriptGapMin                        = t . subsup_vgap           . text_style,
            SuperscriptBaselineDropMax                  = t . sup_shift_drop        . text_style,
            SuperscriptBottomMaxWithSubscript           = t . sup_sub_bottom_max    . text_style,
            SuperscriptBottomMin                        = t . sup_bottom_min        . text_style,
            SuperscriptShiftUp                          = t . sup_shift_up          . text_style,
            SuperscriptShiftUpCramped                   = t . sup_shift_up          . cramped_text_style,
            UnderbarExtraDescender                      = t . underbar_kern         . text_style,
            UnderbarRuleThickness                       = t . underbar_rule         . text_style,
            UnderbarVerticalGap                         = t . underbar_vgap         . text_style,
            UpperLimitBaselineRiseMin                   = t . limit_above_bgap      . text_style,
            UpperLimitGapMin                            = t . limit_above_vgap      . text_style,
            MinConnectorOverlap                         = t . connector_overlap_min . text_style,
            StretchStackGapBelowMin                     = t . over_delimiter_vgap   . text_style,
            StretchStackTopShiftUp                      = t . over_delimiter_bgap   . text_style,
            StretchStackGapAboveMin                     = t . under_delimiter_vgap  . text_style,
            StretchStackBottomShiftDown                 = t . under_delimiter_bgap  . text_style,
        }
        d.AccentBaseHeight = 0
        return t, d -- this might change
    else
        return { }, { }
    end
end

