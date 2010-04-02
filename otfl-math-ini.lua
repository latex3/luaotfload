if not modules then modules = { } end modules ['math-ext'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- if needed we can use the info here to set up xetex definition files
-- the "8000 hackery influences direct characters (utf) as indirect \char's

local utf = unicode.utf8

local texsprint, format, utfchar, utfbyte = tex.sprint, string.format, utf.char, utf.byte

local trace_defining = false  trackers.register("math.defining", function(v) trace_defining = v end)

mathematics = mathematics or { }

mathematics.extrabase   = 0xFE000 -- here we push some virtuals
mathematics.privatebase = 0xFF000 -- here we push the ex

local families = {
    tf = 0, it = 1, sl = 2, bf = 3, bi = 4, bs = 5, -- virtual fonts or unicode otf
}

local classes = {
    ord       =  0,  -- mathordcomm     mathord
    op        =  1,  -- mathopcomm      mathop
    bin       =  2,  -- mathbincomm     mathbin
    rel       =  3,  -- mathrelcomm     mathrel
    open      =  4,  -- mathopencomm    mathopen
    close     =  5,  -- mathclosecomm   mathclose
    punct     =  6,  -- mathpunctcomm   mathpunct
    alpha     =  7,  -- mathalphacomm   firstofoneargument
    accent    =  8,  -- class 0
    radical   =  9,
    xaccent   = 10,  -- class 3
    topaccent = 11,  -- class 0
    botaccent = 12,  -- class 0
    under     = 13,
    over      = 14,
    delimiter = 15,
    inner     =  0,  -- mathinnercomm   mathinner
    nothing   =  0,  -- mathnothingcomm firstofoneargument
    choice    =  0,  -- mathchoicecomm  @@mathchoicecomm
    box       =  0,  -- mathboxcomm     @@mathboxcomm
    limop     =  1,  -- mathlimopcomm   @@mathlimopcomm
    nolop     =  1,  -- mathnolopcomm   @@mathnolopcomm
}

mathematics.families = families
mathematics.classes  = classes

classes.alphabetic  = classes.alpha
classes.unknown     = classes.nothing
classes.default     = classes.nothing
classes.punctuation = classes.punct
classes.normal      = classes.nothing
classes.opening     = classes.open
classes.closing     = classes.close
classes.binary      = classes.bin
classes.relation    = classes.rel
classes.fence       = classes.unknown
classes.diacritic   = classes.accent
classes.large       = classes.op
classes.variable    = classes.alphabetic
classes.number      = classes.alphabetic

-- there will be proper functions soon (and we will move this code in-line)
-- no need for " in class and family (saves space)

local function delcode(target,family,slot)
    return format('\\Udelcode%s="%X "%X ',target,family,slot)
end
local function mathchar(class,family,slot)
    return format('\\Umathchar "%X "%X "%X ',class,family,slot)
end
local function mathaccent(class,family,slot)
    return format('\\Umathaccent "%X "%X "%X ',0,family,slot) -- no class
end
local function delimiter(class,family,slot)
    return format('\\Udelimiter "%X "%X "%X ',class,family,slot)
end
local function radical(family,slot)
    return format('\\Uradical "%X "%X ',family,slot)
end
local function mathchardef(name,class,family,slot)
    return format('\\Umathchardef\\%s "%X "%X "%X ',name,class,family,slot)
end
local function mathcode(target,class,family,slot)
    return format('\\Umathcode%s="%X "%X "%X ',target,class,family,slot)
end
local function mathtopaccent(class,family,slot)
    return format('\\Umathaccent "%X "%X "%X ',0,family,slot) -- no class
end
local function mathbotaccent(class,family,slot)
    return format('\\Umathbotaccent "%X "%X "%X ',0,family,slot) -- no class
end
local function mathtopdelimiter(class,family,slot)
    return format('\\Uoverdelimiter "%X "%X ',0,family,slot) -- no class
end
local function mathbotdelimiter(class,family,slot)
    return format('\\Uunderdelimiter "%X "%X ',0,family,slot) -- no class
end

local escapes = characters.filters.utf.private.escapes

local function setmathsymbol(name,class,family,slot)
    if class == classes.accent then
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,mathaccent(class,family,slot)))
    elseif class == classes.topaccent then
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,mathtopaccent(class,family,slot)))
    elseif class == classes.botaccent then
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,mathbotaccent(class,family,slot)))
    elseif class == classes.over then
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,mathtopdelimiter(class,family,slot)))
    elseif class == classes.under then
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,mathbotdelimiter(class,family,slot)))
    elseif class == classes.open or class == classes.close then
        texsprint(delcode(slot,family,slot))
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,delimiter(class,family,slot)))
    elseif class == classes.delimiter then
        texsprint(delcode(slot,family,slot))
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,delimiter(0,family,slot)))
    elseif class == classes.radical then
        texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,radical(family,slot)))
    else
        -- beware, open/close and other specials should not end up here
--~         local ch = utfchar(slot)
--~         if escapes[ch] then
--~             texsprint(format("\\xdef\\%s{\\char%s }",name,slot))
--~         else
            texsprint(format("\\unexpanded\\xdef\\%s{%s}",name,mathchar(class,family,slot)))
--~         end
    end
end

local function setmathcharacter(class,family,slot,unicode,firsttime)
    if not firsttime and class <= 7 then
        texsprint(mathcode(slot,class,family,unicode or slot))
    end
end

local function setmathsynonym(class,family,slot,unicode,firsttime)
    if not firsttime and class <= 7 then
        texsprint(mathcode(slot,class,family,unicode))
    end
    if class == classes.open or class == classes.close then
        texsprint(delcode(slot,family,unicode))
    end
end

local function report(class,family,unicode,name)
    local nametype = type(name)
    if nametype == "string" then
        logs.report("mathematics","%s:%s %s U+%05X (%s) => %s",classname,class,family,unicode,utfchar(unicode),name)
    elseif nametype == "number" then
        logs.report("mathematics","%s:%s %s U+%05X (%s) => U+%05X",classname,class,family,unicode,utfchar(unicode),name)
    else
        logs.report("mathematics","%s:%s %s U+%05X (%s)", classname,class,family,unicode,utfchar(unicode))
    end
end

-- there will be a combined \(math)chardef

function mathematics.define(slots,family)
    family = family or 0
    family = families[family] or family
    local data = characters.data
    for unicode, character in next, data do
        local symbol = character.mathsymbol
        if symbol then
            local other = data[symbol]
            local class = other.mathclass
            if class then
                class = classes[class] or class -- no real checks needed
                if trace_defining then
                    report(class,family,unicode,symbol)
                end
                setmathsynonym(class,family,unicode,symbol)
            end
            local spec = other.mathspec
            if spec then
                for i, m in next, spec do
                    local class = m.class
                    if class then
                        class = classes[class] or class -- no real checks needed
                        setmathsynonym(class,family,unicode,symbol,i)
                    end
                end
            end
        end
        local mathclass = character.mathclass
        local mathspec = character.mathspec
        if mathspec then
            for i, m in next, mathspec do
                local name = m.name
                local class = m.class
                if not class then
                    class = mathclass
                elseif not mathclass then
                    mathclass = class
                end
                if class then
                    class = classes[class] or class -- no real checks needed
                    if name then
                        if trace_defining then
                            report(class,family,unicode,name)
                        end
                        setmathsymbol(name,class,family,unicode)
                    -- setmathcharacter(class,family,unicode,unicode,i)
                    else
                        name = class == classes.variable or class == classes.number and character.adobename
                        if name then
                            if trace_defining then
                                report(class,family,unicode,name)
                            end
                        --  setmathcharacter(class,family,unicode,unicode,i)
                        end
                    end
                    setmathcharacter(class,family,unicode,unicode,i)
                end
            end
        end
        if mathclass then
            local name = character.mathname
            local class = classes[mathclass] or mathclass -- no real checks needed
            if name == false then
                if trace_defining then
                    report(class,family,unicode,name)
                end
                setmathcharacter(class,family,unicode)
            else
                name = name or character.contextname
                if name then
                    if trace_defining then
                        report(class,family,unicode,name)
                    end
                    setmathsymbol(name,class,family,unicode)
                else
                    if trace_defining then
                        report(class,family,unicode,character.adobename)
                    end
                end
                setmathcharacter(class,family,unicode,unicode)
            end
        end
    end
end

-- needed for mathml analysis

function mathematics.utfmathclass(chr, default)
    local cd = characters.data[utfbyte(chr)]
    return (cd and cd.mathclass) or default or "unknown"
end
function mathematics.utfmathstretch(chr, default) -- "h", "v", "b", ""
    local cd = characters.data[utfbyte(chr)]
    return (cd and cd.mathstretch) or default or ""
end
function mathematics.utfmathcommand(chr, default)
    local cd = characters.data[utfbyte(chr)]
    local cmd = cd and cd.mathname
    tex.sprint(cmd or default or "")
end
function mathematics.utfmathfiller(chr, default)
    local cd = characters.data[utfbyte(chr)]
    local cmd = cd and (cd.mathfiller or cd.mathname)
    tex.sprint(cmd or default or "")
end

mathematics.entities = mathematics.entities or { }

function mathematics.register_xml_entities()
    local entities = xml.entities
    for name, unicode in pairs(mathematics.entities) do
        if not entities[name] then
            entities[name] = utfchar(unicode)
        end
    end
end

-- helpers

function mathematics.big(tfmdata,unicode,n)
    local t = tfmdata.characters
    local c = t[unicode]
    if c then
        local next = c.next
        while next do
            if n <= 1 then
                return next
            else
                n = n - 1
                next = t[next].next
            end
        end
    end
    return unicode
end

-- plugins

local hvars = table.tohash {
    --~ "RadicalKernBeforeDegree",
    --~ "RadicalKernAfterDegree",
}

function mathematics.scaleparameters(t,tfmtable,delta,hdelta,vdelta)
    local math_parameters = tfmtable.math_parameters
    if math_parameters and next(math_parameters) then
        delta = delta or 1
        hdelta, vdelta = hdelta or delta, vdelta or delta
        local _, mp = mathematics.dimensions(math_parameters)
        for name, value in next, mp do
            if name == "RadicalDegreeBottomRaisePercent" then
                mp[name] = value
            elseif hvars[name] then
                mp[name] = hdelta * value
            else
                mp[name] = vdelta * value
            end
        end
        t.MathConstants = mp
    end
end

table.insert(fonts.tfm.mathactions,mathematics.scaleparameters)
