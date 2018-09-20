if not modules then modules = { } end modules ['util-sci'] = {
    version   = 1.001,
    comment   = "companion to m-scite.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gsub, sub, find = string.gsub, string.sub, string.find
local concat = table.concat
local formatters = string.formatters
local lpegmatch = lpeg.match
local setmetatableindex = table.setmetatableindex

local scite     = scite or { }
utilities.scite = scite

local report = logs.reporter("scite")

do
    local lexerroot = "c:/data/system/scite/wscite/context/lexers"
    if not lexerroot then
        lexerroot = file.dirname(resolvers.find_file("scite-context-lexer.lua"))
    end
    if lfs.isdir(lexerroot) then
        package.extraluapath(lexerroot)
        package.extraluapath(lexerroot.."/themes")
        package.extraluapath(lexerroot.."/data")
        report("using lexer root %a",lexerroot)
    else
        report("no valid lexer root")
    end
end

local knownlexers  = {
    tex  = "tex", mkiv = "tex", mkvi = "tex", mkxi = "tex", mkix = "tex", mkii = "tex", cld  = "tex",
    lua  = "lua", lfg  = "lua", lus = "lua",
    mp = "mps", mpiv = "mps", mpii = "mps",
    w = "web", ww = "web",
    c = "cpp", h = "cpp", cpp = "cpp", hpp = "cpp", cxx = "cpp", hxx = "cpp",
    xml = "xml", lmx  = "xml", ctx = "xml", xsl = "xml", xsd = "xml", rlx = "xml", css = "xml", dtd = "xml",
    bib = "bibtex",
    rme = "txt",
 -- todo: pat/hyp ori
}

lexer = nil -- main lexer, global (for the moment needed for themes)

local function loadscitelexer()
    if not lexer then
        lexer = require("scite-context-lexer")
        require("scite-context-theme") -- uses lexer
        if lexer then
            lexer.context.disablewordcheck()
        end
    end
    return lexer
end

local loadedlexers = setmetatableindex(function(t,k)
    local l = knownlexers[k] or k
    loadscitelexer()
    local v = lexer.load(formatters["scite-context-lexer-%s"](l))
    t[l] = v
    t[k] = v
    return v
end)

scite.loadedlexers   = loadedlexers
scite.knownlexers    = knownlexers
scite.loadscitelexer = loadscitelexer

local f_fore_bold  = formatters['.%s { display: inline ; font-weight: bold   ; color: #%02X%02X%02X ; }']
local f_fore_none  = formatters['.%s { display: inline ; font-weight: normal ; color: #%02X%02X%02X ; }']
local f_none_bold  = formatters['.%s { display: inline ; font-weight: bold   ; }']
local f_none_none  = formatters['.%s { display: inline ; font-weight: normal ; }']
local f_div_class  = formatters['<div class="%s">%s</div>']
local f_linenumber = formatters['<div class="linenumber">%s</div>\n']
local f_div_number = formatters['.linenumber { display: inline-block ; font-weight: normal ; width: %sem ; margin-right: 2em ; padding-right: .25em ; text-align: right ; background-color: #C7C7C7 ; }']

local replacer_regular = lpeg.replacer {
    ["<"]  = "&lt;",
    [">"]  = "&gt;",
    ["&"]  = "&amp;",
}

local linenumber  = 0
local linenumbers = { }

local replacer_numbered = lpeg.replacer {
    ["<"]  = "&lt;",
    [">"]  = "&gt;",
    ["&"]  = "&amp;",
    [lpeg.patterns.newline] = function()
        linenumber = linenumber + 1
        linenumbers[linenumber] = f_linenumber(linenumber)
        return "\n"
    end,
}

local css = nil

local function exportcsslexing()
    if not css then
        loadscitelexer()
        local function black(f)
            return (#f == 0 and f[1] == 0) or ((f[1] == f[2]) and (f[2] == f[3]) and (f[3] == 0))
        end
        local result, r = { }, 0
        for k, v in table.sortedhash(lexer.context.styles) do
            local bold = v.bold
            local fore = v.fore
            r = r + 1
            if fore and not black(fore) then
                local cr, cg, cb = fore[1], fore[2], fore[3]
                result[r] = (bold and f_fore_bold or f_fore_none)(k,cr,cg or cr,cb or cr)
            else
                result[r] = (bold and f_none_bold or f_none_none)(k)
            end
        end
        css = concat(result,"\n")
    end
    return css
end

local function exportwhites()
    return setmetatableindex(function(t,k)
        local v = find(k,"white",1,true) and true or false
        t[k] = v
        return v
    end)
end

local function exportstyled(lexer,text,numbered)
    local result = lexer.lex(lexer,text,0)
    local start  = 1
    local whites = exportwhites()
    local buffer = { }
    local b      = 0
    linenumber   = 0
    linenumbers  = { }
    local replacer = numbered and replacer_numbered or replacer_regular
    local n = #result
    for i=1,n,2 do
        local ii = i + 1
        local style = result[i]
        local position = result[ii]
        local txt = sub(text,start,position-1)
        txt = lpegmatch(replacer,txt)
        b = b + 1
        if whites[style] then
            buffer[b] = txt
        else
            buffer[b] = f_div_class(style,txt)
        end
        start = position
    end
    buffer = concat(buffer)
    return buffer, concat(linenumbers)
end

local function exportcsslinenumber()
    return f_div_number(#tostring(linenumber)/2+1)
end

local htmlfile = utilities.templates.replacer([[
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <title>%title%</title>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8"/>
    <style type="text/css"><!--
%lexingstyles%
%numberstyles%
    --></style>
    <body>
        <table style="padding:0; margin:0;">
            <tr>
                <td><pre>%linenumbers%</pre></td>
                <td><pre>%lexedcontent%</pre></td>
            </tr>
        </table>
    </body>
</html>
]])

function scite.tohtml(data,lexname,numbered,title)
    local source, lines = exportstyled(loadedlexers[lexname],data or "",numbered)
    return htmlfile {
        lexedcontent = source, -- before numberstyles
        lexingstyles = exportcsslexing(),
        numberstyles = exportcsslinenumber(),
        title        = title or "context source file",
        linenumbers  = lines,
    }
end

local function maketargetname(name)
    if name then
        return file.removesuffix(name) .. "-" .. file.suffix(name) .. ".html"
    else
        return "util-sci.html"
    end
end

function scite.filetohtml(filename,lexname,targetname,numbered,title)
    io.savedata(targetname or "util-sci.html",scite.tohtml(io.loaddata(filename),lexname or file.suffix(filename),numbered,title or filename))
end

function scite.css()
    return exportcsslexing() .. "\n" .. exportcsslinenumber()
end

function scite.html(data,lexname,numbered)
    return exportstyled(loadedlexers[lexname],data or "",numbered)
end

local f_tree_entry = formatters['<a href="%s" class="dir-entry">%s</a>']

local htmlfile = utilities.templates.replacer([[
<?xml version="1.0"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <title>%title%</title>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8"/>
    <style type="text/css"><!--
%styles%
    --></style>
    <body>
        <pre>
%dirlist%
        </pre>
    </body>
</html>
]])

function scite.converttree(sourceroot,targetroot,numbered)
    if lfs.isdir(sourceroot) then
        statistics.starttiming()
        local skipped = { }
        local noffiles = 0
        dir.makedirs(targetroot)
        local function scan(sourceroot,targetroot,subpath)
            local tree = { }
            for name in lfs.dir(sourceroot) do
                if name ~= "." and name ~= ".." then
                    local sourcename = file.join(sourceroot,name)
                    local targetname = file.join(targetroot,name)
                    local mode = lfs.attributes(sourcename,'mode')
                    local path = subpath and file.join(subpath,name) or name
                    if mode == 'file' then
                        local filetype   = file.suffix(sourcename)
                        local basename   = file.basename(name)
                        local targetname = maketargetname(targetname)
                        local fullname   = file.join(path,name)
                        if knownlexers[filetype] then
                            report("converting file %a to %a",sourcename,targetname)
                            scite.filetohtml(sourcename,nil,targetname,numbered,fullname)
                            noffiles = noffiles + 1
                            tree[#tree+1] = f_tree_entry(file.basename(targetname),basename)
                        else
                            skipped[filetype] = true
                            report("no lexer for %a",sourcename)
                        end
                    else
                        dir.makedirs(targetname)
                        scan(sourcename,targetname,path)
                        tree[#tree+1] = f_tree_entry(file.join(name,"files.html"),name)
                    end
                end
            end
            report("saving tree in %a",targetroot)
            local htmldata = htmlfile {
                dirlist = concat(tree,"\n"),
                styles  = "",
                title   = path or "context dir listing",
            }
            io.savedata(file.join(targetroot,"files.html"),htmldata)
        end
        scan(sourceroot,targetroot)
        if next(skipped) then
            report("skipped filetypes: %a",table.concat(table.sortedkeys(skipped)," "))
        end
        statistics.stoptiming()
        report("conversion time for %s files: %s",noffiles,statistics.elapsedtime())
    end
end

-- scite.filetohtml("strc-sec.mkiv",nil,"e:/tmp/util-sci.html",true)
-- scite.filetohtml("syst-aux.mkiv",nil,"e:/tmp/util-sci.html",true)

-- scite.converttree("t:/texmf/tex/context","e:/tmp/html/context",true)

return scite
