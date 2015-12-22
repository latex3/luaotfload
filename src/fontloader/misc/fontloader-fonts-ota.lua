if not modules then modules = { } end modules ['luatex-fonts-ota'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (analysing)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type = type

if not trackers then trackers = { register = function() end } end

----- trace_analyzing = false  trackers.register("otf.analyzing",  function(v) trace_analyzing = v end)

local fonts, nodes, node = fonts, nodes, node

local allocate            = utilities.storage.allocate

local otf                 = fonts.handlers.otf

local analyzers           = fonts.analyzers
local initializers        = allocate()
local methods             = allocate()

analyzers.initializers    = initializers
analyzers.methods         = methods

local a_state             = attributes.private('state')

local nuts                = nodes.nuts
local tonut               = nuts.tonut

local getfield            = nuts.getfield
local getnext             = nuts.getnext
local getprev             = nuts.getprev
local getid               = nuts.getid
local getprop             = nuts.getprop
local setprop             = nuts.setprop
local getfont             = nuts.getfont
local getsubtype          = nuts.getsubtype
local getchar             = nuts.getchar

local traverse_id         = nuts.traverse_id
local traverse_node_list  = nuts.traverse
local end_of_math         = nuts.end_of_math

local nodecodes           = nodes.nodecodes
local glyph_code          = nodecodes.glyph
local disc_code           = nodecodes.disc
local math_code           = nodecodes.math

local fontdata            = fonts.hashes.identifiers
local categories          = characters and characters.categories or { } -- sorry, only in context

local otffeatures         = fonts.constructors.newfeatures("otf")
local registerotffeature  = otffeatures.register

--[[ldx--
<p>Analyzers run per script and/or language and are needed in order to
process features right.</p>
--ldx]]--

-- never use these numbers directly

local s_init = 1    local s_rphf =  7
local s_medi = 2    local s_half =  8
local s_fina = 3    local s_pref =  9
local s_isol = 4    local s_blwf = 10
local s_mark = 5    local s_pstf = 11
local s_rest = 6

local states = {
    init = s_init,
    medi = s_medi,
    fina = s_fina,
    isol = s_isol,
    mark = s_mark,
    rest = s_rest,
    rphf = s_rphf,
    half = s_half,
    pref = s_pref,
    blwf = s_blwf,
    pstf = s_pstf,
}

local features = {
    init = s_init,
    medi = s_medi,
    fina = s_fina,
    isol = s_isol,
 -- mark = s_mark,
 -- rest = s_rest,
    rphf = s_rphf,
    half = s_half,
    pref = s_pref,
    blwf = s_blwf,
    pstf = s_pstf,
}

analyzers.states          = states
analyzers.features        = features
analyzers.useunicodemarks = false

-- todo: analyzers per script/lang, cross font, so we need an font id hash -> script
-- e.g. latin -> hyphenate, arab -> 1/2/3 analyze -- its own namespace

function analyzers.setstate(head,font)
    local useunicodemarks  = analyzers.useunicodemarks
    local tfmdata = fontdata[font]
    local descriptions = tfmdata.descriptions
    local first, last, current, n, done = nil, nil, head, 0, false -- maybe make n boolean
    current = tonut(current)
    while current do
        local id = getid(current)
        if id == glyph_code and getfont(current) == font then
            done = true
            local char = getchar(current)
            local d = descriptions[char]
            if d then
                if d.class == "mark" then
                    done = true
                    setprop(current,a_state,s_mark)
                elseif useunicodemarks and categories[char] == "mn" then
                    done = true
                    setprop(current,a_state,s_mark)
                elseif n == 0 then
                    first, last, n = current, current, 1
                    setprop(current,a_state,s_init)
                else
                    last, n = current, n+1
                    setprop(current,a_state,s_medi)
                end
            else -- finish
                if first and first == last then
                    setprop(last,a_state,s_isol)
                elseif last then
                    setprop(last,a_state,s_fina)
                end
                first, last, n = nil, nil, 0
            end
        elseif id == disc_code then
            -- always in the middle .. it doesn't make much sense to assign a property
            -- here ... we might at some point decide to flag the components when present
            -- but even then it's kind of bogus
            setprop(current,a_state,s_medi)
            last = current
        else -- finish
            if first and first == last then
                setprop(last,a_state,s_isol)
            elseif last then
                setprop(last,a_state,s_fina)
            end
            first, last, n = nil, nil, 0
            if id == math_code then
                current = end_of_math(current)
            end
        end
        current = getnext(current)
    end
    if first and first == last then
        setprop(last,a_state,s_isol)
    elseif last then
        setprop(last,a_state,s_fina)
    end
    return head, done
end

-- in the future we will use language/script attributes instead of the
-- font related value, but then we also need dynamic features which is
-- somewhat slower; and .. we need a chain of them

local function analyzeinitializer(tfmdata,value) -- attr
    local script, language = otf.scriptandlanguage(tfmdata) -- attr
    local action = initializers[script]
    if not action then
        -- skip
    elseif type(action) == "function" then
        return action(tfmdata,value)
    else
        local action = action[language]
        if action then
            return action(tfmdata,value)
        end
    end
end

local function analyzeprocessor(head,font,attr)
    local tfmdata = fontdata[font]
    local script, language = otf.scriptandlanguage(tfmdata,attr)
    local action = methods[script]
    if not action then
        -- skip
    elseif type(action) == "function" then
        return action(head,font,attr)
    else
        action = action[language]
        if action then
            return action(head,font,attr)
        end
    end
    return head, false
end

registerotffeature {
    name         = "analyze",
    description  = "analysis of character classes",
    default      = true,
    initializers = {
        node     = analyzeinitializer,
    },
    processors = {
        position = 1,
        node     = analyzeprocessor,
    }
}

-- latin

methods.latn = analyzers.setstate


local tatweel = 0x0640
local zwnj    = 0x200C
local zwj     = 0x200D

local isolated = { -- isol
    [0x0600] = true, [0x0601] = true, [0x0602] = true, [0x0603] = true,
    [0x0604] = true,
    [0x0608] = true, [0x060B] = true, [0x0621] = true, [0x0674] = true,
    [0x06DD] = true,
    -- mandaic
    [0x0856] = true, [0x0858] = true, [0x0857] = true,
    -- n'ko
    [0x07FA] = true,
    -- also here:
    [zwnj]   = true,
    -- 7
    [0x08AD] = true,
}

local final = { -- isol_fina
    [0x0622] = true, [0x0623] = true, [0x0624] = true, [0x0625] = true,
    [0x0627] = true, [0x0629] = true, [0x062F] = true, [0x0630] = true,
    [0x0631] = true, [0x0632] = true, [0x0648] = true, [0x0671] = true,
    [0x0672] = true, [0x0673] = true, [0x0675] = true, [0x0676] = true,
    [0x0677] = true, [0x0688] = true, [0x0689] = true, [0x068A] = true,
    [0x068B] = true, [0x068C] = true, [0x068D] = true, [0x068E] = true,
    [0x068F] = true, [0x0690] = true, [0x0691] = true, [0x0692] = true,
    [0x0693] = true, [0x0694] = true, [0x0695] = true, [0x0696] = true,
    [0x0697] = true, [0x0698] = true, [0x0699] = true, [0x06C0] = true,
    [0x06C3] = true, [0x06C4] = true, [0x06C5] = true, [0x06C6] = true,
    [0x06C7] = true, [0x06C8] = true, [0x06C9] = true, [0x06CA] = true,
    [0x06CB] = true, [0x06CD] = true, [0x06CF] = true, [0x06D2] = true,
    [0x06D3] = true, [0x06D5] = true, [0x06EE] = true, [0x06EF] = true,
    [0x0759] = true, [0x075A] = true, [0x075B] = true, [0x076B] = true,
    [0x076C] = true, [0x0771] = true, [0x0773] = true, [0x0774] = true,
    [0x0778] = true, [0x0779] = true,
    [0x08AA] = true, [0x08AB] = true, [0x08AC] = true,
    [0xFEF5] = true, [0xFEF7] = true, [0xFEF9] = true, [0xFEFB] = true,
    -- syriac
    [0x0710] = true, [0x0715] = true, [0x0716] = true, [0x0717] = true,
    [0x0718] = true, [0x0719] = true, [0x0728] = true, [0x072A] = true,
    [0x072C] = true, [0x071E] = true,
    [0x072F] = true, [0x074D] = true,
    -- mandaic
    [0x0840] = true, [0x0849] = true, [0x0854] = true, [0x0846] = true,
    [0x084F] = true,
    -- 7
    [0x08AE] = true, [0x08B1] = true, [0x08B2] = true,
}

local medial = { -- isol_fina_medi_init
    [0x0626] = true, [0x0628] = true, [0x062A] = true, [0x062B] = true,
    [0x062C] = true, [0x062D] = true, [0x062E] = true, [0x0633] = true,
    [0x0634] = true, [0x0635] = true, [0x0636] = true, [0x0637] = true,
    [0x0638] = true, [0x0639] = true, [0x063A] = true, [0x063B] = true,
    [0x063C] = true, [0x063D] = true, [0x063E] = true, [0x063F] = true,
    [0x0641] = true, [0x0642] = true, [0x0643] = true,
    [0x0644] = true, [0x0645] = true, [0x0646] = true, [0x0647] = true,
    [0x0649] = true, [0x064A] = true, [0x066E] = true, [0x066F] = true,
    [0x0678] = true, [0x0679] = true, [0x067A] = true, [0x067B] = true,
    [0x067C] = true, [0x067D] = true, [0x067E] = true, [0x067F] = true,
    [0x0680] = true, [0x0681] = true, [0x0682] = true, [0x0683] = true,
    [0x0684] = true, [0x0685] = true, [0x0686] = true, [0x0687] = true,
    [0x069A] = true, [0x069B] = true, [0x069C] = true, [0x069D] = true,
    [0x069E] = true, [0x069F] = true, [0x06A0] = true, [0x06A1] = true,
    [0x06A2] = true, [0x06A3] = true, [0x06A4] = true, [0x06A5] = true,
    [0x06A6] = true, [0x06A7] = true, [0x06A8] = true, [0x06A9] = true,
    [0x06AA] = true, [0x06AB] = true, [0x06AC] = true, [0x06AD] = true,
    [0x06AE] = true, [0x06AF] = true, [0x06B0] = true, [0x06B1] = true,
    [0x06B2] = true, [0x06B3] = true, [0x06B4] = true, [0x06B5] = true,
    [0x06B6] = true, [0x06B7] = true, [0x06B8] = true, [0x06B9] = true,
    [0x06BA] = true, [0x06BB] = true, [0x06BC] = true, [0x06BD] = true,
    [0x06BE] = true, [0x06BF] = true, [0x06C1] = true, [0x06C2] = true,
    [0x06CC] = true, [0x06CE] = true, [0x06D0] = true, [0x06D1] = true,
    [0x06FA] = true, [0x06FB] = true, [0x06FC] = true, [0x06FF] = true,
    [0x0750] = true, [0x0751] = true, [0x0752] = true, [0x0753] = true,
    [0x0754] = true, [0x0755] = true, [0x0756] = true, [0x0757] = true,
    [0x0758] = true, [0x075C] = true, [0x075D] = true, [0x075E] = true,
    [0x075F] = true, [0x0760] = true, [0x0761] = true, [0x0762] = true,
    [0x0763] = true, [0x0764] = true, [0x0765] = true, [0x0766] = true,
    [0x0767] = true, [0x0768] = true, [0x0769] = true, [0x076A] = true,
    [0x076D] = true, [0x076E] = true, [0x076F] = true, [0x0770] = true,
    [0x0772] = true, [0x0775] = true, [0x0776] = true, [0x0777] = true,
    [0x077A] = true, [0x077B] = true, [0x077C] = true, [0x077D] = true,
    [0x077E] = true, [0x077F] = true,
    [0x08A0] = true, [0x08A2] = true, [0x08A4] = true, [0x08A5] = true,
    [0x08A6] = true, [0x0620] = true, [0x08A8] = true, [0x08A9] = true,
    [0x08A7] = true, [0x08A3] = true,
    -- syriac
    [0x0712] = true, [0x0713] = true, [0x0714] = true, [0x071A] = true,
    [0x071B] = true, [0x071C] = true, [0x071D] = true, [0x071F] = true,
    [0x0720] = true, [0x0721] = true, [0x0722] = true, [0x0723] = true,
    [0x0724] = true, [0x0725] = true, [0x0726] = true, [0x0727] = true,
    [0x0729] = true, [0x072B] = true, [0x072D] = true, [0x072E] = true,
    [0x074E] = true, [0x074F] = true,
    -- mandaic
    [0x0841] = true, [0x0842] = true, [0x0843] = true, [0x0844] = true,
    [0x0845] = true, [0x0847] = true, [0x0848] = true, [0x0855] = true,
    [0x0851] = true, [0x084E] = true, [0x084D] = true, [0x084A] = true,
    [0x084B] = true, [0x084C] = true, [0x0850] = true, [0x0852] = true,
    [0x0853] = true,
    -- n'ko
    [0x07D7] = true, [0x07E8] = true, [0x07D9] = true, [0x07EA] = true,
    [0x07CA] = true, [0x07DB] = true, [0x07CC] = true, [0x07DD] = true,
    [0x07CE] = true, [0x07DF] = true, [0x07D4] = true, [0x07E5] = true,
    [0x07E9] = true, [0x07E7] = true, [0x07E3] = true, [0x07E2] = true,
    [0x07E0] = true, [0x07E1] = true, [0x07DE] = true, [0x07DC] = true,
    [0x07D1] = true, [0x07DA] = true, [0x07D8] = true, [0x07D6] = true,
    [0x07D2] = true, [0x07D0] = true, [0x07CF] = true, [0x07CD] = true,
    [0x07CB] = true, [0x07D3] = true, [0x07E4] = true, [0x07D5] = true,
    [0x07E6] = true,
    -- also here:
    [tatweel]= true, [zwj]    = true,
    -- 7
    [0x08A1] = true, [0x08AF] = true, [0x08B0] = true,
}

local arab_warned = { }

local function warning(current,what)
    local char = getchar(current)
    if not arab_warned[char] then
        log.report("analyze","arab: character %C has no %a class",char,what)
        arab_warned[char] = true
    end
end

-- potential optimization: local medial_final = table.merged(medial,final)

local function finish(first,last)
    if last then
        if first == last then
            local fc = getchar(first)
            if medial[fc] or final[fc] then
                setprop(first,a_state,s_isol)
            else
                warning(first,"isol")
                setprop(first,a_state,s_error)
            end
        else
            local lc = getchar(last)
            if medial[lc] or final[lc] then
             -- if laststate == 1 or laststate == 2 or laststate == 4 then
                setprop(last,a_state,s_fina)
            else
                warning(last,"fina")
                setprop(last,a_state,s_error)
            end
        end
        first, last = nil, nil
    elseif first then
        -- first and last are either both set so we never com here
        local fc = getchar(first)
        if medial[fc] or final[fc] then
            setprop(first,a_state,s_isol)
        else
            warning(first,"isol")
            setprop(first,a_state,s_error)
        end
        first = nil
    end
    return first, last
end

function methods.arab(head,font,attr)
    local useunicodemarks = analyzers.useunicodemarks
    local tfmdata = fontdata[font]
    local marks = tfmdata.resources.marks
    local first, last, current, done = nil, nil, head, false
    current = tonut(current)
    while current do
        local id = getid(current)
        if id == glyph_code and getfont(current) == font and getsubtype(current)<256 and not getprop(current,a_state) then
            done = true
            local char = getchar(current)
            if marks[char] or (useunicodemarks and categories[char] == "mn") then
                setprop(current,a_state,s_mark)
            elseif isolated[char] then -- can be zwj or zwnj too
                first, last = finish(first,last)
                setprop(current,a_state,s_isol)
                first, last = nil, nil
            elseif not first then
                if medial[char] then
                    setprop(current,a_state,s_init)
                    first, last = first or current, current
                elseif final[char] then
                    setprop(current,a_state,s_isol)
                    first, last = nil, nil
                else -- no arab
                    first, last = finish(first,last)
                end
            elseif medial[char] then
                first, last = first or current, current
                setprop(current,a_state,s_medi)
            elseif final[char] then
                if getprop(last,a_state) ~= s_init then
                    -- tricky, we need to check what last may be !
                    setprop(last,a_state,s_medi)
                end
                setprop(current,a_state,s_fina)
                first, last = nil, nil
            elseif char >= 0x0600 and char <= 0x06FF then -- needs checking
                setprop(current,a_state,s_rest)
                first, last = finish(first,last)
            else -- no
                first, last = finish(first,last)
            end
        else
            if first or last then
                first, last = finish(first,last)
            end
            if id == math_code then
                current = end_of_math(current)
            end
        end
        current = getnext(current)
    end
    if first or last then
        finish(first,last)
    end
    return head, done
end

methods.syrc = methods.arab
methods.mand = methods.arab
methods.nko  = methods.arab

directives.register("otf.analyze.useunicodemarks",function(v)
    analyzers.useunicodemarks = v
end)
