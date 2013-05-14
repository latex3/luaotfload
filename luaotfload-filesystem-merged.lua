-- merged file : luaotfload-filesystem-merged.lua
-- parent file : luaotfload-filesystem.lua
-- merge date  : Tue May 14 12:12:07 2013

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-lua']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local major,minor=string.match(_VERSION,"^[^%d]+(%d+)%.(%d+).*$")
_MAJORVERSION=tonumber(major) or 5
_MINORVERSION=tonumber(minor) or 1
_LUAVERSION=_MAJORVERSION+_MINORVERSION/10
if not lpeg then
  lpeg=require("lpeg")
end
if loadstring then
  local loadnormal=load
  function load(first,...)
    if type(first)=="string" then
      return loadstring(first,...)
    else
      return loadnormal(first,...)
    end
  end
else
  loadstring=load
end
if not ipairs then
  local function iterate(a,i)
    i=i+1
    local v=a[i]
    if v~=nil then
      return i,v 
    end
  end
  function ipairs(a)
    return iterate,a,0
  end
end
if not pairs then
  function pairs(t)
    return next,t 
  end
end
if not table.unpack then
  table.unpack=_G.unpack
elseif not unpack then
  _G.unpack=table.unpack
end
if not package.loaders then 
  package.loaders=package.searchers
end
local print,select,tostring=print,select,tostring
local inspectors={}
function setinspector(inspector) 
  inspectors[#inspectors+1]=inspector
end
function inspect(...) 
  for s=1,select("#",...) do
    local value=select(s,...)
    local done=false
    for i=1,#inspectors do
      done=inspectors[i](value)
      if done then
        break
      end
    end
    if not done then
      print(tostring(value))
    end
  end
end
local dummy=function() end
function optionalrequire(...)
  local ok,result=xpcall(require,dummy,...)
  if ok then
    return result
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-lpeg']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
lpeg=require("lpeg")
local type,next,tostring=type,next,tostring
local byte,char,gmatch,format=string.byte,string.char,string.gmatch,string.format
local floor=math.floor
local P,R,S,V,Ct,C,Cs,Cc,Cp,Cmt=lpeg.P,lpeg.R,lpeg.S,lpeg.V,lpeg.Ct,lpeg.C,lpeg.Cs,lpeg.Cc,lpeg.Cp,lpeg.Cmt
local lpegtype,lpegmatch,lpegprint=lpeg.type,lpeg.match,lpeg.print
setinspector(function(v) if lpegtype(v) then lpegprint(v) return true end end)
lpeg.patterns=lpeg.patterns or {} 
local patterns=lpeg.patterns
local anything=P(1)
local endofstring=P(-1)
local alwaysmatched=P(true)
patterns.anything=anything
patterns.endofstring=endofstring
patterns.beginofstring=alwaysmatched
patterns.alwaysmatched=alwaysmatched
local digit,sign=R('09'),S('+-')
local cr,lf,crlf=P("\r"),P("\n"),P("\r\n")
local newline=crlf+S("\r\n") 
local escaped=P("\\")*anything
local squote=P("'")
local dquote=P('"')
local space=P(" ")
local utfbom_32_be=P('\000\000\254\255')
local utfbom_32_le=P('\255\254\000\000')
local utfbom_16_be=P('\255\254')
local utfbom_16_le=P('\254\255')
local utfbom_8=P('\239\187\191')
local utfbom=utfbom_32_be+utfbom_32_le+utfbom_16_be+utfbom_16_le+utfbom_8
local utftype=utfbom_32_be*Cc("utf-32-be")+utfbom_32_le*Cc("utf-32-le")+utfbom_16_be*Cc("utf-16-be")+utfbom_16_le*Cc("utf-16-le")+utfbom_8*Cc("utf-8")+alwaysmatched*Cc("utf-8") 
local utfoffset=utfbom_32_be*Cc(4)+utfbom_32_le*Cc(4)+utfbom_16_be*Cc(2)+utfbom_16_le*Cc(2)+utfbom_8*Cc(3)+Cc(0)
local utf8next=R("\128\191")
patterns.utf8one=R("\000\127")
patterns.utf8two=R("\194\223")*utf8next
patterns.utf8three=R("\224\239")*utf8next*utf8next
patterns.utf8four=R("\240\244")*utf8next*utf8next*utf8next
patterns.utfbom=utfbom
patterns.utftype=utftype
patterns.utfoffset=utfoffset
local utf8char=patterns.utf8one+patterns.utf8two+patterns.utf8three+patterns.utf8four
local validutf8char=utf8char^0*endofstring*Cc(true)+Cc(false)
local utf8character=P(1)*R("\128\191")^0 
patterns.utf8=utf8char
patterns.utf8char=utf8char
patterns.utf8character=utf8character 
patterns.validutf8=validutf8char
patterns.validutf8char=validutf8char
local eol=S("\n\r")
local spacer=S(" \t\f\v") 
local whitespace=eol+spacer
local nonspacer=1-spacer
local nonwhitespace=1-whitespace
patterns.eol=eol
patterns.spacer=spacer
patterns.whitespace=whitespace
patterns.nonspacer=nonspacer
patterns.nonwhitespace=nonwhitespace
local stripper=spacer^0*C((spacer^0*nonspacer^1)^0)
local collapser=Cs(spacer^0/""*nonspacer^0*((spacer^0/" "*nonspacer^1)^0))
patterns.stripper=stripper
patterns.collapser=collapser
patterns.digit=digit
patterns.sign=sign
patterns.cardinal=sign^0*digit^1
patterns.integer=sign^0*digit^1
patterns.unsigned=digit^0*P('.')*digit^1
patterns.float=sign^0*patterns.unsigned
patterns.cunsigned=digit^0*P(',')*digit^1
patterns.cfloat=sign^0*patterns.cunsigned
patterns.number=patterns.float+patterns.integer
patterns.cnumber=patterns.cfloat+patterns.integer
patterns.oct=P("0")*R("07")^1
patterns.octal=patterns.oct
patterns.HEX=P("0x")*R("09","AF")^1
patterns.hex=P("0x")*R("09","af")^1
patterns.hexadecimal=P("0x")*R("09","AF","af")^1
patterns.lowercase=R("az")
patterns.uppercase=R("AZ")
patterns.letter=patterns.lowercase+patterns.uppercase
patterns.space=space
patterns.tab=P("\t")
patterns.spaceortab=patterns.space+patterns.tab
patterns.newline=newline
patterns.emptyline=newline^1
patterns.equal=P("=")
patterns.comma=P(",")
patterns.commaspacer=P(",")*spacer^0
patterns.period=P(".")
patterns.colon=P(":")
patterns.semicolon=P(";")
patterns.underscore=P("_")
patterns.escaped=escaped
patterns.squote=squote
patterns.dquote=dquote
patterns.nosquote=(escaped+(1-squote))^0
patterns.nodquote=(escaped+(1-dquote))^0
patterns.unsingle=(squote/"")*patterns.nosquote*(squote/"") 
patterns.undouble=(dquote/"")*patterns.nodquote*(dquote/"") 
patterns.unquoted=patterns.undouble+patterns.unsingle 
patterns.unspacer=((patterns.spacer^1)/"")^0
patterns.singlequoted=squote*patterns.nosquote*squote
patterns.doublequoted=dquote*patterns.nodquote*dquote
patterns.quoted=patterns.doublequoted+patterns.singlequoted
patterns.propername=R("AZ","az","__")*R("09","AZ","az","__")^0*P(-1)
patterns.somecontent=(anything-newline-space)^1 
patterns.beginline=#(1-newline)
patterns.longtostring=Cs(whitespace^0/""*nonwhitespace^0*((whitespace^0/" "*(patterns.quoted+nonwhitespace)^1)^0))
local function anywhere(pattern) 
  return P { P(pattern)+1*V(1) }
end
lpeg.anywhere=anywhere
function lpeg.instringchecker(p)
  p=anywhere(p)
  return function(str)
    return lpegmatch(p,str) and true or false
  end
end
function lpeg.splitter(pattern,action)
  return (((1-P(pattern))^1)/action+1)^0
end
function lpeg.tsplitter(pattern,action)
  return Ct((((1-P(pattern))^1)/action+1)^0)
end
local splitters_s,splitters_m,splitters_t={},{},{}
local function splitat(separator,single)
  local splitter=(single and splitters_s[separator]) or splitters_m[separator]
  if not splitter then
    separator=P(separator)
    local other=C((1-separator)^0)
    if single then
      local any=anything
      splitter=other*(separator*C(any^0)+"") 
      splitters_s[separator]=splitter
    else
      splitter=other*(separator*other)^0
      splitters_m[separator]=splitter
    end
  end
  return splitter
end
local function tsplitat(separator)
  local splitter=splitters_t[separator]
  if not splitter then
    splitter=Ct(splitat(separator))
    splitters_t[separator]=splitter
  end
  return splitter
end
lpeg.splitat=splitat
lpeg.tsplitat=tsplitat
function string.splitup(str,separator)
  if not separator then
    separator=","
  end
  return lpegmatch(splitters_m[separator] or splitat(separator),str)
end
local cache={}
function lpeg.split(separator,str)
  local c=cache[separator]
  if not c then
    c=tsplitat(separator)
    cache[separator]=c
  end
  return lpegmatch(c,str)
end
function string.split(str,separator)
  if separator then
    local c=cache[separator]
    if not c then
      c=tsplitat(separator)
      cache[separator]=c
    end
    return lpegmatch(c,str)
  else
    return { str }
  end
end
local spacing=patterns.spacer^0*newline 
local empty=spacing*Cc("")
local nonempty=Cs((1-spacing)^1)*spacing^-1
local content=(empty+nonempty)^1
patterns.textline=content
local linesplitter=tsplitat(newline)
patterns.linesplitter=linesplitter
function string.splitlines(str)
  return lpegmatch(linesplitter,str)
end
local cache={}
function lpeg.checkedsplit(separator,str)
  local c=cache[separator]
  if not c then
    separator=P(separator)
    local other=C((1-separator)^1)
    c=Ct(separator^0*other*(separator^1*other)^0)
    cache[separator]=c
  end
  return lpegmatch(c,str)
end
function string.checkedsplit(str,separator)
  local c=cache[separator]
  if not c then
    separator=P(separator)
    local other=C((1-separator)^1)
    c=Ct(separator^0*other*(separator^1*other)^0)
    cache[separator]=c
  end
  return lpegmatch(c,str)
end
local function f2(s) local c1,c2=byte(s,1,2) return  c1*64+c2-12416 end
local function f3(s) local c1,c2,c3=byte(s,1,3) return (c1*64+c2)*64+c3-925824 end
local function f4(s) local c1,c2,c3,c4=byte(s,1,4) return ((c1*64+c2)*64+c3)*64+c4-63447168 end
local utf8byte=patterns.utf8one/byte+patterns.utf8two/f2+patterns.utf8three/f3+patterns.utf8four/f4
patterns.utf8byte=utf8byte
local cache={}
function lpeg.stripper(str)
  if type(str)=="string" then
    local s=cache[str]
    if not s then
      s=Cs(((S(str)^1)/""+1)^0)
      cache[str]=s
    end
    return s
  else
    return Cs(((str^1)/""+1)^0)
  end
end
local cache={}
function lpeg.keeper(str)
  if type(str)=="string" then
    local s=cache[str]
    if not s then
      s=Cs((((1-S(str))^1)/""+1)^0)
      cache[str]=s
    end
    return s
  else
    return Cs((((1-str)^1)/""+1)^0)
  end
end
function lpeg.frontstripper(str) 
  return (P(str)+P(true))*Cs(anything^0)
end
function lpeg.endstripper(str) 
  return Cs((1-P(str)*endofstring)^0)
end
function lpeg.replacer(one,two,makefunction,isutf) 
  local pattern
  local u=isutf and utf8char or 1
  if type(one)=="table" then
    local no=#one
    local p=P(false)
    if no==0 then
      for k,v in next,one do
        p=p+P(k)/v
      end
      pattern=Cs((p+u)^0)
    elseif no==1 then
      local o=one[1]
      one,two=P(o[1]),o[2]
      pattern=Cs((one/two+u)^0)
    else
      for i=1,no do
        local o=one[i]
        p=p+P(o[1])/o[2]
      end
      pattern=Cs((p+u)^0)
    end
  else
    pattern=Cs((P(one)/(two or "")+u)^0)
  end
  if makefunction then
    return function(str)
      return lpegmatch(pattern,str)
    end
  else
    return pattern
  end
end
function lpeg.finder(lst,makefunction)
  local pattern
  if type(lst)=="table" then
    pattern=P(false)
    if #lst==0 then
      for k,v in next,lst do
        pattern=pattern+P(k) 
      end
    else
      for i=1,#lst do
        pattern=pattern+P(lst[i])
      end
    end
  else
    pattern=P(lst)
  end
  pattern=(1-pattern)^0*pattern
  if makefunction then
    return function(str)
      return lpegmatch(pattern,str)
    end
  else
    return pattern
  end
end
local splitters_f,splitters_s={},{}
function lpeg.firstofsplit(separator) 
  local splitter=splitters_f[separator]
  if not splitter then
    separator=P(separator)
    splitter=C((1-separator)^0)
    splitters_f[separator]=splitter
  end
  return splitter
end
function lpeg.secondofsplit(separator) 
  local splitter=splitters_s[separator]
  if not splitter then
    separator=P(separator)
    splitter=(1-separator)^0*separator*C(anything^0)
    splitters_s[separator]=splitter
  end
  return splitter
end
function lpeg.balancer(left,right)
  left,right=P(left),P(right)
  return P { left*((1-left-right)+V(1))^0*right }
end
local nany=utf8char/""
function lpeg.counter(pattern)
  pattern=Cs((P(pattern)/" "+nany)^0)
  return function(str)
    return #lpegmatch(pattern,str)
  end
end
utf=utf or (unicode and unicode.utf8) or {}
local utfcharacters=utf and utf.characters or string.utfcharacters
local utfgmatch=utf and utf.gmatch
local utfchar=utf and utf.char
lpeg.UP=lpeg.P
if utfcharacters then
  function lpeg.US(str)
    local p=P(false)
    for uc in utfcharacters(str) do
      p=p+P(uc)
    end
    return p
  end
elseif utfgmatch then
  function lpeg.US(str)
    local p=P(false)
    for uc in utfgmatch(str,".") do
      p=p+P(uc)
    end
    return p
  end
else
  function lpeg.US(str)
    local p=P(false)
    local f=function(uc)
      p=p+P(uc)
    end
    lpegmatch((utf8char/f)^0,str)
    return p
  end
end
local range=utf8byte*utf8byte+Cc(false) 
function lpeg.UR(str,more)
  local first,last
  if type(str)=="number" then
    first=str
    last=more or first
  else
    first,last=lpegmatch(range,str)
    if not last then
      return P(str)
    end
  end
  if first==last then
    return P(str)
  elseif utfchar and (last-first<8) then 
    local p=P(false)
    for i=first,last do
      p=p+P(utfchar(i))
    end
    return p 
  else
    local f=function(b)
      return b>=first and b<=last
    end
    return utf8byte/f 
  end
end
function lpeg.is_lpeg(p)
  return p and lpegtype(p)=="pattern"
end
function lpeg.oneof(list,...) 
  if type(list)~="table" then
    list={ list,... }
  end
  local p=P(list[1])
  for l=2,#list do
    p=p+P(list[l])
  end
  return p
end
local sort=table.sort
local function copyindexed(old)
  local new={}
  for i=1,#old do
    new[i]=old
  end
  return new
end
local function sortedkeys(tab)
  local keys,s={},0
  for key,_ in next,tab do
    s=s+1
    keys[s]=key
  end
  sort(keys)
  return keys
end
function lpeg.append(list,pp,delayed,checked)
  local p=pp
  if #list>0 then
    local keys=copyindexed(list)
    sort(keys)
    for i=#keys,1,-1 do
      local k=keys[i]
      if p then
        p=P(k)+p
      else
        p=P(k)
      end
    end
  elseif delayed then 
    local keys=sortedkeys(list)
    if p then
      for i=1,#keys,1 do
        local k=keys[i]
        local v=list[k]
        p=P(k)/list+p
      end
    else
      for i=1,#keys do
        local k=keys[i]
        local v=list[k]
        if p then
          p=P(k)+p
        else
          p=P(k)
        end
      end
      if p then
        p=p/list
      end
    end
  elseif checked then
    local keys=sortedkeys(list)
    for i=1,#keys do
      local k=keys[i]
      local v=list[k]
      if p then
        if k==v then
          p=P(k)+p
        else
          p=P(k)/v+p
        end
      else
        if k==v then
          p=P(k)
        else
          p=P(k)/v
        end
      end
    end
  else
    local keys=sortedkeys(list)
    for i=1,#keys do
      local k=keys[i]
      local v=list[k]
      if p then
        p=P(k)/v+p
      else
        p=P(k)/v
      end
    end
  end
  return p
end
local function make(t)
  local p
  local keys=sortedkeys(t)
  for i=1,#keys do
    local k=keys[i]
    local v=t[k]
    if not p then
      if next(v) then
        p=P(k)*make(v)
      else
        p=P(k)
      end
    else
      if next(v) then
        p=p+P(k)*make(v)
      else
        p=p+P(k)
      end
    end
  end
  return p
end
function lpeg.utfchartabletopattern(list) 
  local tree={}
  for i=1,#list do
    local t=tree
    for c in gmatch(list[i],".") do
      if not t[c] then
        t[c]={}
      end
      t=t[c]
    end
  end
  return make(tree)
end
patterns.containseol=lpeg.finder(eol)
local function nextstep(n,step,result)
  local m=n%step   
  local d=floor(n/step) 
  if d>0 then
    local v=V(tostring(step))
    local s=result.start
    for i=1,d do
      if s then
        s=v*s
      else
        s=v
      end
    end
    result.start=s
  end
  if step>1 and result.start then
    local v=V(tostring(step/2))
    result[tostring(step)]=v*v
  end
  if step>0 then
    return nextstep(m,step/2,result)
  else
    return result
  end
end
function lpeg.times(pattern,n)
  return P(nextstep(n,2^16,{ "start",["1"]=pattern }))
end
local digit=R("09")
local period=P(".")
local zero=P("0")
local trailingzeros=zero^0*-digit 
local case_1=period*trailingzeros/""
local case_2=period*(digit-trailingzeros)^1*(trailingzeros/"")
local number=digit^1*(case_1+case_2)
local stripper=Cs((number+1)^0)
lpeg.patterns.stripzeros=stripper

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-file']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
file=file or {}
local file=file
if not lfs then
  lfs=optionalrequire("lfs")
end
if not lfs then
  lfs={
    getcurrentdir=function()
      return "."
    end,
    attributes=function()
      return nil
    end,
    isfile=function(name)
      local f=io.open(name,'rb')
      if f then
        f:close()
        return true
      end
    end,
    isdir=function(name)
      print("you need to load lfs")
      return false
    end
  }
elseif not lfs.isfile then
  local attributes=lfs.attributes
  function lfs.isdir(name)
    return attributes(name,"mode")=="directory"
  end
  function lfs.isfile(name)
    return attributes(name,"mode")=="file"
  end
end
local insert,concat=table.insert,table.concat
local match,find=string.match,string.find
local lpegmatch=lpeg.match
local getcurrentdir,attributes=lfs.currentdir,lfs.attributes
local checkedsplit=string.checkedsplit
local P,R,S,C,Cs,Cp,Cc,Ct=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Cs,lpeg.Cp,lpeg.Cc,lpeg.Ct
local colon=P(":")
local period=P(".")
local periods=P("..")
local fwslash=P("/")
local bwslash=P("\\")
local slashes=S("\\/")
local noperiod=1-period
local noslashes=1-slashes
local name=noperiod^1
local suffix=period/""*(1-period-slashes)^1*-1
local pattern=C((1-(slashes^1*noslashes^1*-1))^1)*P(1) 
local function pathpart(name,default)
  return name and lpegmatch(pattern,name) or default or ""
end
local pattern=(noslashes^0*slashes)^1*C(noslashes^1)*-1
local function basename(name)
  return name and lpegmatch(pattern,name) or name
end
local pattern=(noslashes^0*slashes^1)^0*Cs((1-suffix)^1)*suffix^0
local function nameonly(name)
  return name and lpegmatch(pattern,name) or name
end
local pattern=(noslashes^0*slashes)^0*(noperiod^1*period)^1*C(noperiod^1)*-1
local function suffixonly(name)
  return name and lpegmatch(pattern,name) or ""
end
file.pathpart=pathpart
file.basename=basename
file.nameonly=nameonly
file.suffixonly=suffixonly
file.suffix=suffixonly
file.dirname=pathpart  
file.extname=suffixonly
local drive=C(R("az","AZ"))*colon
local path=C((noslashes^0*slashes)^0)
local suffix=period*C(P(1-period)^0*P(-1))
local base=C((1-suffix)^0)
local rest=C(P(1)^0)
drive=drive+Cc("")
path=path+Cc("")
base=base+Cc("")
suffix=suffix+Cc("")
local pattern_a=drive*path*base*suffix
local pattern_b=path*base*suffix
local pattern_c=C(drive*path)*C(base*suffix) 
local pattern_d=path*rest
function file.splitname(str,splitdrive)
  if not str then
  elseif splitdrive then
    return lpegmatch(pattern_a,str) 
  else
    return lpegmatch(pattern_b,str) 
  end
end
function file.splitbase(str)
  return str and lpegmatch(pattern_d,str) 
end
function file.nametotable(str,splitdrive)
  if str then
    local path,drive,subpath,name,base,suffix=lpegmatch(pattern_c,str)
    if splitdrive then
      return {
        path=path,
        drive=drive,
        subpath=subpath,
        name=name,
        base=base,
        suffix=suffix,
      }
    else
      return {
        path=path,
        name=name,
        base=base,
        suffix=suffix,
      }
    end
  end
end
local pattern=Cs(((period*(1-period-slashes)^1*-1)/""+1)^1)
function file.removesuffix(name)
  return name and lpegmatch(pattern,name)
end
local suffix=period/""*(1-period-slashes)^1*-1
local pattern=Cs((noslashes^0*slashes^1)^0*((1-suffix)^1))*Cs(suffix)
function file.addsuffix(filename,suffix,criterium)
  if not filename or not suffix or suffix=="" then
    return filename
  elseif criterium==true then
    return filename.."."..suffix
  elseif not criterium then
    local n,s=lpegmatch(pattern,filename)
    if not s or s=="" then
      return filename.."."..suffix
    else
      return filename
    end
  else
    local n,s=lpegmatch(pattern,filename)
    if s and s~="" then
      local t=type(criterium)
      if t=="table" then
        for i=1,#criterium do
          if s==criterium[i] then
            return filename
          end
        end
      elseif t=="string" then
        if s==criterium then
          return filename
        end
      end
    end
    return (n or filename).."."..suffix
  end
end
local suffix=period*(1-period-slashes)^1*-1
local pattern=Cs((1-suffix)^0)
function file.replacesuffix(name,suffix)
  if name and suffix and suffix~="" then
    return lpegmatch(pattern,name).."."..suffix
  else
    return name
  end
end
local reslasher=lpeg.replacer(P("\\"),"/")
function file.reslash(str)
  return str and lpegmatch(reslasher,str)
end
function file.is_writable(name)
  if not name then
  elseif lfs.isdir(name) then
    name=name.."/m_t_x_t_e_s_t.tmp"
    local f=io.open(name,"wb")
    if f then
      f:close()
      os.remove(name)
      return true
    end
  elseif lfs.isfile(name) then
    local f=io.open(name,"ab")
    if f then
      f:close()
      return true
    end
  else
    local f=io.open(name,"ab")
    if f then
      f:close()
      os.remove(name)
      return true
    end
  end
  return false
end
local readable=P("r")*Cc(true)
function file.is_readable(name)
  if name then
    local a=attributes(name)
    return a and lpegmatch(readable,a.permissions) or false
  else
    return false
  end
end
file.isreadable=file.is_readable 
file.iswritable=file.is_writable 
function file.size(name)
  if name then
    local a=attributes(name)
    return a and a.size or 0
  else
    return 0
  end
end
function file.splitpath(str,separator) 
  return str and checkedsplit(lpegmatch(reslasher,str),separator or io.pathseparator)
end
function file.joinpath(tab,separator) 
  return tab and concat(tab,separator or io.pathseparator) 
end
local stripper=Cs(P(fwslash)^0/""*reslasher)
local isnetwork=fwslash*fwslash*(1-fwslash)+(1-fwslash-colon)^1*colon
local isroot=fwslash^1*-1
local hasroot=fwslash^1
local deslasher=lpeg.replacer(S("\\/")^1,"/")
function file.join(...)
  local lst={... }
  local one=lst[1]
  if lpegmatch(isnetwork,one) then
    local two=lpegmatch(deslasher,concat(lst,"/",2))
    return one.."/"..two
  elseif lpegmatch(isroot,one) then
    local two=lpegmatch(deslasher,concat(lst,"/",2))
    if lpegmatch(hasroot,two) then
      return two
    else
      return "/"..two
    end
  elseif one=="" then
    return lpegmatch(stripper,concat(lst,"/",2))
  else
    return lpegmatch(deslasher,concat(lst,"/"))
  end
end
local drivespec=R("az","AZ")^1*colon
local anchors=fwslash+drivespec
local untouched=periods+(1-period)^1*P(-1)
local splitstarter=(Cs(drivespec*(bwslash/"/"+fwslash)^0)+Cc(false))*Ct(lpeg.splitat(S("/\\")^1))
local absolute=fwslash
function file.collapsepath(str,anchor) 
  if not str then
    return
  end
  if anchor==true and not lpegmatch(anchors,str) then
    str=getcurrentdir().."/"..str
  end
  if str=="" or str=="." then
    return "."
  elseif lpegmatch(untouched,str) then
    return lpegmatch(reslasher,str)
  end
  local starter,oldelements=lpegmatch(splitstarter,str)
  local newelements={}
  local i=#oldelements
  while i>0 do
    local element=oldelements[i]
    if element=='.' then
    elseif element=='..' then
      local n=i-1
      while n>0 do
        local element=oldelements[n]
        if element~='..' and element~='.' then
          oldelements[n]='.'
          break
        else
          n=n-1
        end
       end
      if n<1 then
        insert(newelements,1,'..')
      end
    elseif element~="" then
      insert(newelements,1,element)
    end
    i=i-1
  end
  if #newelements==0 then
    return starter or "."
  elseif starter then
    return starter..concat(newelements,'/')
  elseif lpegmatch(absolute,str) then
    return "/"..concat(newelements,'/')
  else
    newelements=concat(newelements,'/')
    if anchor=="." and find(str,"^%./") then
      return "./"..newelements
    else
      return newelements
    end
  end
end
local validchars=R("az","09","AZ","--","..")
local pattern_a=lpeg.replacer(1-validchars)
local pattern_a=Cs((validchars+P(1)/"-")^1)
local whatever=P("-")^0/""
local pattern_b=Cs(whatever*(1-whatever*-1)^1)
function file.robustname(str,strict)
  if str then
    str=lpegmatch(pattern_a,str) or str
    if strict then
      return lpegmatch(pattern_b,str) or str 
    else
      return str
    end
  end
end
file.readdata=io.loaddata
file.savedata=io.savedata
function file.copy(oldname,newname)
  if oldname and newname then
    local data=io.loaddata(oldname)
    if data and data~="" then
      file.savedata(newname,data)
    end
  end
end
local letter=R("az","AZ")+S("_-+")
local separator=P("://")
local qualified=period^0*fwslash+letter*colon+letter^1*separator+letter^1*fwslash
local rootbased=fwslash+letter*colon
lpeg.patterns.qualified=qualified
lpeg.patterns.rootbased=rootbased
function file.is_qualified_path(filename)
  return filename and lpegmatch(qualified,filename)~=nil
end
function file.is_rootbased_path(filename)
  return filename and lpegmatch(rootbased,filename)~=nil
end
function file.strip(name,dir)
  if name then
    local b,a=match(name,"^(.-)"..dir.."(.*)$")
    return a~="" and a or name
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-dir']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local type,select=type,select
local find,gmatch,match,gsub=string.find,string.gmatch,string.match,string.gsub
local concat,insert,remove,unpack=table.concat,table.insert,table.remove,table.unpack
local lpegmatch=lpeg.match
local P,S,R,C,Cc,Cs,Ct,Cv,V=lpeg.P,lpeg.S,lpeg.R,lpeg.C,lpeg.Cc,lpeg.Cs,lpeg.Ct,lpeg.Cv,lpeg.V
dir=dir or {}
local dir=dir
local lfs=lfs
local attributes=lfs.attributes
local walkdir=lfs.dir
local isdir=lfs.isdir
local isfile=lfs.isfile
local currentdir=lfs.currentdir
local chdir=lfs.chdir
if not isdir then
  function isdir(name)
    local a=attributes(name)
    return a and a.mode=="directory"
  end
  lfs.isdir=isdir
end
if not isfile then
  function isfile(name)
    local a=attributes(name)
    return a and a.mode=="file"
  end
  lfs.isfile=isfile
end
function dir.current()
  return (gsub(currentdir(),"\\","/"))
end
local lfsisdir=isdir
local function isdir(path)
  path=gsub(path,"[/\\]+$","")
  return lfsisdir(path)
end
lfs.isdir=isdir
local function globpattern(path,patt,recurse,action)
  if path=="/" then
    path=path.."."
  elseif not find(path,"/$") then
    path=path..'/'
  end
  if isdir(path) then 
    for name in walkdir(path) do 
      local full=path..name
      local mode=attributes(full,'mode')
      if mode=='file' then
        if find(full,patt) then
          action(full)
        end
      elseif recurse and (mode=="directory") and (name~='.') and (name~="..") then
        globpattern(full,patt,recurse,action)
      end
    end
  end
end
dir.globpattern=globpattern
local function collectpattern(path,patt,recurse,result)
  local ok,scanner
  result=result or {}
  if path=="/" then
    ok,scanner,first=xpcall(function() return walkdir(path..".") end,function() end) 
  else
    ok,scanner,first=xpcall(function() return walkdir(path)   end,function() end) 
  end
  if ok and type(scanner)=="function" then
    if not find(path,"/$") then path=path..'/' end
    for name in scanner,first do
      local full=path..name
      local attr=attributes(full)
      local mode=attr.mode
      if mode=='file' then
        if find(full,patt) then
          result[name]=attr
        end
      elseif recurse and (mode=="directory") and (name~='.') and (name~="..") then
        attr.list=collectpattern(full,patt,recurse)
        result[name]=attr
      end
    end
  end
  return result
end
dir.collectpattern=collectpattern
local pattern=Ct {
  [1]=(C(P(".")+P("/")^1)+C(R("az","AZ")*P(":")*P("/")^0)+Cc("./"))*V(2)*V(3),
  [2]=C(((1-S("*?/"))^0*P("/"))^0),
  [3]=C(P(1)^0)
}
local filter=Cs ((
  P("**")/".*"+P("*")/"[^/]*"+P("?")/"[^/]"+P(".")/"%%."+P("+")/"%%+"+P("-")/"%%-"+P(1)
)^0 )
local function glob(str,t)
  if type(t)=="function" then
    if type(str)=="table" then
      for s=1,#str do
        glob(str[s],t)
      end
    elseif isfile(str) then
      t(str)
    else
      local split=lpegmatch(pattern,str) 
      if split then
        local root,path,base=split[1],split[2],split[3]
        local recurse=find(base,"%*%*")
        local start=root..path
        local result=lpegmatch(filter,start..base)
        globpattern(start,result,recurse,t)
      end
    end
  else
    if type(str)=="table" then
      local t=t or {}
      for s=1,#str do
        glob(str[s],t)
      end
      return t
    elseif isfile(str) then
      if t then
        t[#t+1]=str
        return t
      else
        return { str }
      end
    else
      local split=lpegmatch(pattern,str) 
      if split then
        local t=t or {}
        local action=action or function(name) t[#t+1]=name end
        local root,path,base=split[1],split[2],split[3]
        local recurse=find(base,"%*%*")
        local start=root..path
        local result=lpegmatch(filter,start..base)
        globpattern(start,result,recurse,action)
        return t
      else
        return {}
      end
    end
  end
end
dir.glob=glob
local function globfiles(path,recurse,func,files) 
  if type(func)=="string" then
    local s=func
    func=function(name) return find(name,s) end
  end
  files=files or {}
  local noffiles=#files
  for name in walkdir(path) do
    if find(name,"^%.") then
    else
      local mode=attributes(name,'mode')
      if mode=="directory" then
        if recurse then
          globfiles(path.."/"..name,recurse,func,files)
        end
      elseif mode=="file" then
        if not func or func(name) then
          noffiles=noffiles+1
          files[noffiles]=path.."/"..name
        end
      end
    end
  end
  return files
end
dir.globfiles=globfiles
function dir.ls(pattern)
  return concat(glob(pattern),"\n")
end
local make_indeed=true 
local onwindows=os.type=="windows" or find(os.getenv("PATH"),";")
if onwindows then
  function dir.mkdirs(...)
    local str,pth="",""
    for i=1,select("#",...) do
      local s=select(i,...)
      if s=="" then
      elseif str=="" then
        str=s
      else
        str=str.."/"..s
      end
    end
    local first,middle,last
    local drive=false
    first,middle,last=match(str,"^(//)(//*)(.*)$")
    if first then
    else
      first,last=match(str,"^(//)/*(.-)$")
      if first then
        middle,last=match(str,"([^/]+)/+(.-)$")
        if middle then
          pth="//"..middle
        else
          pth="//"..last
          last=""
        end
      else
        first,middle,last=match(str,"^([a-zA-Z]:)(/*)(.-)$")
        if first then
          pth,drive=first..middle,true
        else
          middle,last=match(str,"^(/*)(.-)$")
          if not middle then
            last=str
          end
        end
      end
    end
    for s in gmatch(last,"[^/]+") do
      if pth=="" then
        pth=s
      elseif drive then
        pth,drive=pth..s,false
      else
        pth=pth.."/"..s
      end
      if make_indeed and not isdir(pth) then
        lfs.mkdir(pth)
      end
    end
    return pth,(isdir(pth)==true)
  end
else
  function dir.mkdirs(...)
    local str,pth="",""
    for i=1,select("#",...) do
      local s=select(i,...)
      if s and s~="" then 
        if str~="" then
          str=str.."/"..s
        else
          str=s
        end
      end
    end
    str=gsub(str,"/+","/")
    if find(str,"^/") then
      pth="/"
      for s in gmatch(str,"[^/]+") do
        local first=(pth=="/")
        if first then
          pth=pth..s
        else
          pth=pth.."/"..s
        end
        if make_indeed and not first and not isdir(pth) then
          lfs.mkdir(pth)
        end
      end
    else
      pth="."
      for s in gmatch(str,"[^/]+") do
        pth=pth.."/"..s
        if make_indeed and not isdir(pth) then
          lfs.mkdir(pth)
        end
      end
    end
    return pth,(isdir(pth)==true)
  end
end
dir.makedirs=dir.mkdirs
if onwindows then
  function dir.expandname(str) 
    local first,nothing,last=match(str,"^(//)(//*)(.*)$")
    if first then
      first=dir.current().."/" 
    end
    if not first then
      first,last=match(str,"^(//)/*(.*)$")
    end
    if not first then
      first,last=match(str,"^([a-zA-Z]:)(.*)$")
      if first and not find(last,"^/") then
        local d=currentdir()
        if chdir(first) then
          first=dir.current()
        end
        chdir(d)
      end
    end
    if not first then
      first,last=dir.current(),str
    end
    last=gsub(last,"//","/")
    last=gsub(last,"/%./","/")
    last=gsub(last,"^/*","")
    first=gsub(first,"/*$","")
    if last=="" or last=="." then
      return first
    else
      return first.."/"..last
    end
  end
else
  function dir.expandname(str) 
    if not find(str,"^/") then
      str=currentdir().."/"..str
    end
    str=gsub(str,"//","/")
    str=gsub(str,"/%./","/")
    str=gsub(str,"(.)/%.$","%1")
    return str
  end
end
file.expandname=dir.expandname 
local stack={}
function dir.push(newdir)
  insert(stack,currentdir())
  if newdir and newdir~="" then
    chdir(newdir)
  end
end
function dir.pop()
  local d=remove(stack)
  if d then
    chdir(d)
  end
  return d
end
local function found(...) 
  for i=1,select("#",...) do
    local path=select(i,...)
    local kind=type(path)
    if kind=="string" then
      if isdir(path) then
        return path
      end
    elseif kind=="table" then
      local path=found(unpack(path))
      if path then
        return path
      end
    end
  end
end
dir.found=found

end -- closure
