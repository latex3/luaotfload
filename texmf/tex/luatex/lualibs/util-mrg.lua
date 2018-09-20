if not modules then modules = { } end modules ['util-mrg'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- hm, quite unreadable

local gsub, format = string.gsub, string.format
local concat = table.concat
local type, next = type, next

local P, R, S, V, Ct, C, Cs, Cc, Cp, Cmt, Cb, Cg = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.Ct, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Cp, lpeg.Cmt, lpeg.Cb, lpeg.Cg
local lpegmatch, patterns = lpeg.match, lpeg.patterns

utilities             = utilities or { }
local merger          = utilities.merger or { }
utilities.merger      = merger
merger.strip_comment  = true

local report          = logs.reporter("system","merge")
utilities.report      = report

local m_begin_merge   = "begin library merge"
local m_end_merge     = "end library merge"
local m_begin_closure = "do -- create closure to overcome 200 locals limit"
local m_end_closure   = "end -- of closure"

local m_pattern =
    "%c+" ..
    "%-%-%s+" .. m_begin_merge ..
    "%c+(.-)%c+" ..
    "%-%-%s+" .. m_end_merge ..
    "%c+"

local m_format =
    "\n\n-- " .. m_begin_merge ..
    "\n%s\n" ..
    "-- " .. m_end_merge .. "\n\n"

local m_faked =
    "-- " .. "created merged file" .. "\n\n" ..
    "-- " .. m_begin_merge .. "\n\n" ..
    "-- " .. m_end_merge .. "\n\n"

local m_report = [[
-- used libraries    : %s
-- skipped libraries : %s
-- original bytes    : %s
-- stripped bytes    : %s
]]

local m_preloaded = [[package.loaded[%q] = package.loaded[%q] or true]]

local function self_fake()
    return m_faked
end

local function self_nothing()
    return ""
end

local function self_load(name)
    local data = io.loaddata(name) or ""
    if data == "" then
        report("unknown file %a",name)
    else
        report("inserting file %a",name)
    end
    return data or ""
end

-- -- saves some 20K .. scite comments
-- data = gsub(data,"%-%-~[^\n\r]*[\r\n]","")
-- -- saves some 20K .. ldx comments
-- data = gsub(data,"%-%-%[%[ldx%-%-.-%-%-ldx%]%]%-%-","")

local space           = patterns.space
local eol             = patterns.newline
local equals          = P("=")^0
local open            = P("[") * Cg(equals,"init") * P("[") * P("\n")^-1
local close           = P("]") * C(equals) * P("]")
local closeeq         = Cmt(close * Cb("init"), function(s,i,a,b) return a == b end)
local longstring      = open * (1 - closeeq)^0 * close

local quoted          = patterns.quoted
local digit           = patterns.digit
local emptyline       = space^0 * eol
local operator1       = P("<=") + P(">=") + P("~=") + P("..") + S("/^<>=*+%%")
local operator2       = S("*+/")
local operator3       = S("-")
local operator4       = P("..")
local separator       = S(",;")

local ignore          = (P("]") * space^1 * P("=") * space^1 * P("]")) / "]=[" +
                        (P("=") * space^1 * P("{")) / "={" +
                        (P("(") * space^1) / "(" +
                        (P("{") * (space+eol)^1 * P("}")) / "{}"
local strings         = quoted --  / function (s) print("<<"..s..">>") return s end
local longcmt         = (emptyline^0 * P("--") * longstring * emptyline^0) / ""
local longstr         = longstring
local comment         = emptyline^0 * P("--") * P("-")^0 * (1-eol)^0 * emptyline^1 / "\n"
local optionalspaces  = space^0 / ""
local mandatespaces   = space^1 / ""
local optionalspacing = (eol+space)^0 / ""
local mandatespacing  = (eol+space)^1 / ""
local pack            = digit * space^1 * operator4 * optionalspacing +
                        optionalspacing * operator1 * optionalspacing +
                        optionalspacing * operator2 * optionalspaces  +
                        mandatespacing  * operator3 * mandatespaces   +
                        optionalspaces  * separator * optionalspaces
local lines           = emptyline^2 / "\n"
local spaces          = (space * space) / " "
----- spaces          = ((space+eol)^1 ) / " "

local compact = Cs ( (
    ignore  +
    strings +
    longcmt +
    longstr +
    comment +
    pack    +
    lines   +
    spaces  +
    1
)^1 )

local strip       = Cs((emptyline^2/"\n" + 1)^0)
local stripreturn = Cs((1-P("return") * space^1 * P(1-space-eol)^1 * (space+eol)^0 * P(-1))^1)

function merger.compact(data)
    return lpegmatch(strip,lpegmatch(compact,data))
end

local function self_compact(data)
    local delta = 0
    if merger.strip_comment then
        local before = #data
        data = lpegmatch(compact,data)
        data = lpegmatch(strip,data) -- also strips in longstrings ... alas
     -- data = string.strip(data)
        local after = #data
        delta = before - after
        report("original size %s, compacted to %s, stripped %s",before,after,delta)
        data = format("-- original size: %s, stripped down to: %s\n\n%s",before,after,data)
    end
    return lpegmatch(stripreturn,data) or data, delta
end

local function self_save(name, data)
    if data ~= "" then
        io.savedata(name,data)
        report("saving %s with size %s",name,#data)
    end
end

local function self_swap(data,code)
    return data ~= "" and (gsub(data,m_pattern, function() return format(m_format,code) end, 1)) or ""
end

local function self_libs(libs,list)
    local result, f, frozen, foundpath = { }, nil, false, nil
    result[#result+1] = "\n"
    if type(libs) == 'string' then libs = { libs } end
    if type(list) == 'string' then list = { list } end
    for i=1,#libs do
        local lib = libs[i]
        for j=1,#list do
            local pth = gsub(list[j],"\\","/") -- file.clean_path
            report("checking library path %a",pth)
            local name = pth .. "/" .. lib
            if lfs.isfile(name) then
                foundpath = pth
            end
        end
        if foundpath then break end
    end
    if foundpath then
        report("using library path %a",foundpath)
        local right, wrong, original, stripped = { }, { }, 0, 0
        for i=1,#libs do
            local lib = libs[i]
            local fullname = foundpath .. "/" .. lib
            if lfs.isfile(fullname) then
                report("using library %a",fullname)
                local preloaded = file.nameonly(lib)
                local data = io.loaddata(fullname,true)
                original = original + #data
                local data, delta = self_compact(data)
                right[#right+1] = lib
                result[#result+1] = m_begin_closure
                result[#result+1] = format(m_preloaded,preloaded,preloaded)
                result[#result+1] = data
                result[#result+1] = m_end_closure
                stripped = stripped + delta
            else
                report("skipping library %a",fullname)
                wrong[#wrong+1] = lib
            end
        end
        right = #right > 0 and concat(right," ") or "-"
        wrong = #wrong > 0 and concat(wrong," ") or "-"
        report("used libraries: %a",right)
        report("skipped libraries: %a",wrong)
        report("original bytes: %a",original)
        report("stripped bytes: %a",stripped)
        result[#result+1] = format(m_report,right,wrong,original,stripped)
    else
        report("no valid library path found")
    end
    return concat(result, "\n\n")
end

function merger.selfcreate(libs,list,target)
    if target then
        self_save(target,self_swap(self_fake(),self_libs(libs,list)))
    end
end

function merger.selfmerge(name,libs,list,target)
    self_save(target or name,self_swap(self_load(name),self_libs(libs,list)))
end

function merger.selfclean(name)
    self_save(name,self_swap(self_load(name),self_nothing()))
end
