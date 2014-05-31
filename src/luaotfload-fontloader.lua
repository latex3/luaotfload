-- merged file : luatex-fonts-merged.lua
-- parent file : luatex-fonts.lua
-- merge date  : 05/30/14 23:26:41

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
if lua then
  lua.mask=load([[τεχ = 1]]) and "utf" or "ascii"
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
if not lpeg.print then function lpeg.print(...) print(lpeg.pcode(...)) end end
local type,next,tostring=type,next,tostring
local byte,char,gmatch,format=string.byte,string.char,string.gmatch,string.format
local floor=math.floor
local P,R,S,V,Ct,C,Cs,Cc,Cp,Cmt=lpeg.P,lpeg.R,lpeg.S,lpeg.V,lpeg.Ct,lpeg.C,lpeg.Cs,lpeg.Cc,lpeg.Cp,lpeg.Cmt
local lpegtype,lpegmatch,lpegprint=lpeg.type,lpeg.match,lpeg.print
if setinspector then
  setinspector(function(v) if lpegtype(v) then lpegprint(v) return true end end)
end
lpeg.patterns=lpeg.patterns or {} 
local patterns=lpeg.patterns
local anything=P(1)
local endofstring=P(-1)
local alwaysmatched=P(true)
patterns.anything=anything
patterns.endofstring=endofstring
patterns.beginofstring=alwaysmatched
patterns.alwaysmatched=alwaysmatched
local sign=S('+-')
local zero=P('0')
local digit=R('09')
local octdigit=R("07")
local lowercase=R("az")
local uppercase=R("AZ")
local underscore=P("_")
local hexdigit=digit+lowercase+uppercase
local cr,lf,crlf=P("\r"),P("\n"),P("\r\n")
local newline=P("\r")*(P("\n")+P(true))+P("\n")
local escaped=P("\\")*anything
local squote=P("'")
local dquote=P('"')
local space=P(" ")
local period=P(".")
local comma=P(",")
local utfbom_32_be=P('\000\000\254\255') 
local utfbom_32_le=P('\255\254\000\000') 
local utfbom_16_be=P('\254\255')     
local utfbom_16_le=P('\255\254')     
local utfbom_8=P('\239\187\191')   
local utfbom=utfbom_32_be+utfbom_32_le+utfbom_16_be+utfbom_16_le+utfbom_8
local utftype=utfbom_32_be*Cc("utf-32-be")+utfbom_32_le*Cc("utf-32-le")+utfbom_16_be*Cc("utf-16-be")+utfbom_16_le*Cc("utf-16-le")+utfbom_8*Cc("utf-8")+alwaysmatched*Cc("utf-8") 
local utfstricttype=utfbom_32_be*Cc("utf-32-be")+utfbom_32_le*Cc("utf-32-le")+utfbom_16_be*Cc("utf-16-be")+utfbom_16_le*Cc("utf-16-le")+utfbom_8*Cc("utf-8")
local utfoffset=utfbom_32_be*Cc(4)+utfbom_32_le*Cc(4)+utfbom_16_be*Cc(2)+utfbom_16_le*Cc(2)+utfbom_8*Cc(3)+Cc(0)
local utf8next=R("\128\191")
patterns.utfbom_32_be=utfbom_32_be
patterns.utfbom_32_le=utfbom_32_le
patterns.utfbom_16_be=utfbom_16_be
patterns.utfbom_16_le=utfbom_16_le
patterns.utfbom_8=utfbom_8
patterns.utf_16_be_nl=P("\000\r\000\n")+P("\000\r")+P("\000\n") 
patterns.utf_16_le_nl=P("\r\000\n\000")+P("\r\000")+P("\n\000") 
patterns.utf8one=R("\000\127")
patterns.utf8two=R("\194\223")*utf8next
patterns.utf8three=R("\224\239")*utf8next*utf8next
patterns.utf8four=R("\240\244")*utf8next*utf8next*utf8next
patterns.utfbom=utfbom
patterns.utftype=utftype
patterns.utfstricttype=utfstricttype
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
local fullstripper=whitespace^0*C((whitespace^0*nonwhitespace^1)^0)
local collapser=Cs(spacer^0/""*nonspacer^0*((spacer^0/" "*nonspacer^1)^0))
patterns.stripper=stripper
patterns.fullstripper=fullstripper
patterns.collapser=collapser
patterns.lowercase=lowercase
patterns.uppercase=uppercase
patterns.letter=patterns.lowercase+patterns.uppercase
patterns.space=space
patterns.tab=P("\t")
patterns.spaceortab=patterns.space+patterns.tab
patterns.newline=newline
patterns.emptyline=newline^1
patterns.equal=P("=")
patterns.comma=comma
patterns.commaspacer=comma*spacer^0
patterns.period=period
patterns.colon=P(":")
patterns.semicolon=P(";")
patterns.underscore=underscore
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
patterns.digit=digit
patterns.octdigit=octdigit
patterns.hexdigit=hexdigit
patterns.sign=sign
patterns.cardinal=digit^1
patterns.integer=sign^-1*digit^1
patterns.unsigned=digit^0*period*digit^1
patterns.float=sign^-1*patterns.unsigned
patterns.cunsigned=digit^0*comma*digit^1
patterns.cfloat=sign^-1*patterns.cunsigned
patterns.number=patterns.float+patterns.integer
patterns.cnumber=patterns.cfloat+patterns.integer
patterns.oct=zero*octdigit^1
patterns.octal=patterns.oct
patterns.HEX=zero*P("X")*(digit+uppercase)^1
patterns.hex=zero*P("x")*(digit+lowercase)^1
patterns.hexadecimal=zero*S("xX")*hexdigit^1
patterns.hexafloat=sign^-1*zero*S("xX")*(hexdigit^0*period*hexdigit^1+hexdigit^1*period*hexdigit^0+hexdigit^1)*(S("pP")*sign^-1*hexdigit^1)^-1
patterns.decafloat=sign^-1*(digit^0*period*digit^1+digit^1*period*digit^0+digit^1)*S("eE")*sign^-1*digit^1
patterns.propername=(uppercase+lowercase+underscore)*(uppercase+lowercase+underscore+digit)^0*endofstring
patterns.somecontent=(anything-newline-space)^1 
patterns.beginline=#(1-newline)
patterns.longtostring=Cs(whitespace^0/""*((patterns.quoted+nonwhitespace^1+whitespace^1/""*(P(-1)+Cc(" ")))^0))
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
function lpeg.finder(lst,makefunction,isutf) 
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
  if isutf then
    pattern=((utf8char or 1)-pattern)^0*pattern
  else
    pattern=(1-pattern)^0*pattern
  end
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
    local pattern=P(separator)
    splitter=C((1-pattern)^0)
    splitters_f[separator]=splitter
  end
  return splitter
end
function lpeg.secondofsplit(separator) 
  local splitter=splitters_s[separator]
  if not splitter then
    local pattern=P(separator)
    splitter=(1-pattern)^0*pattern*C(anything^0)
    splitters_s[separator]=splitter
  end
  return splitter
end
local splitters_s,splitters_p={},{}
function lpeg.beforesuffix(separator) 
  local splitter=splitters_s[separator]
  if not splitter then
    local pattern=P(separator)
    splitter=C((1-pattern)^0)*pattern*endofstring
    splitters_s[separator]=splitter
  end
  return splitter
end
function lpeg.afterprefix(separator) 
  local splitter=splitters_p[separator]
  if not splitter then
    local pattern=P(separator)
    splitter=pattern*C(anything^0)
    splitters_p[separator]=splitter
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
local trailingzeros=zero^0*-digit 
local case_1=period*trailingzeros/""
local case_2=period*(digit-trailingzeros)^1*(trailingzeros/"")
local number=digit^1*(case_1+case_2)
local stripper=Cs((number+1)^0)
lpeg.patterns.stripzeros=stripper

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-functions']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
functions=functions or {}
function functions.dummy() end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-string']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local string=string
local sub,gmatch,format,char,byte,rep,lower=string.sub,string.gmatch,string.format,string.char,string.byte,string.rep,string.lower
local lpegmatch,patterns=lpeg.match,lpeg.patterns
local P,S,C,Ct,Cc,Cs=lpeg.P,lpeg.S,lpeg.C,lpeg.Ct,lpeg.Cc,lpeg.Cs
local unquoted=patterns.squote*C(patterns.nosquote)*patterns.squote+patterns.dquote*C(patterns.nodquote)*patterns.dquote
function string.unquoted(str)
  return lpegmatch(unquoted,str) or str
end
function string.quoted(str)
  return format("%q",str) 
end
function string.count(str,pattern) 
  local n=0
  for _ in gmatch(str,pattern) do 
    n=n+1
  end
  return n
end
function string.limit(str,n,sentinel) 
  if #str>n then
    sentinel=sentinel or "..."
    return sub(str,1,(n-#sentinel))..sentinel
  else
    return str
  end
end
local stripper=patterns.stripper
local fullstripper=patterns.fullstripper
local collapser=patterns.collapser
local longtostring=patterns.longtostring
function string.strip(str)
  return lpegmatch(stripper,str) or ""
end
function string.fullstrip(str)
  return lpegmatch(fullstripper,str) or ""
end
function string.collapsespaces(str)
  return lpegmatch(collapser,str) or ""
end
function string.longtostring(str)
  return lpegmatch(longtostring,str) or ""
end
local pattern=P(" ")^0*P(-1)
function string.is_empty(str)
  if str=="" then
    return true
  else
    return lpegmatch(pattern,str) and true or false
  end
end
local anything=patterns.anything
local allescapes=Cc("%")*S(".-+%?()[]*") 
local someescapes=Cc("%")*S(".-+%()[]")  
local matchescapes=Cc(".")*S("*?")     
local pattern_a=Cs ((allescapes+anything )^0 )
local pattern_b=Cs ((someescapes+matchescapes+anything )^0 )
local pattern_c=Cs (Cc("^")*(someescapes+matchescapes+anything )^0*Cc("$") )
function string.escapedpattern(str,simple)
  return lpegmatch(simple and pattern_b or pattern_a,str)
end
function string.topattern(str,lowercase,strict)
  if str=="" or type(str)~="string" then
    return ".*"
  elseif strict then
    str=lpegmatch(pattern_c,str)
  else
    str=lpegmatch(pattern_b,str)
  end
  if lowercase then
    return lower(str)
  else
    return str
  end
end
function string.valid(str,default)
  return (type(str)=="string" and str~="" and str) or default or nil
end
string.itself=function(s) return s end
local pattern=Ct(C(1)^0) 
function string.totable(str)
  return lpegmatch(pattern,str)
end
local replacer=lpeg.replacer("@","%%") 
function string.tformat(fmt,...)
  return format(lpegmatch(replacer,fmt),...)
end
string.quote=string.quoted
string.unquote=string.unquoted

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-table']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local type,next,tostring,tonumber,ipairs,select=type,next,tostring,tonumber,ipairs,select
local table,string=table,string
local concat,sort,insert,remove=table.concat,table.sort,table.insert,table.remove
local format,lower,dump=string.format,string.lower,string.dump
local getmetatable,setmetatable=getmetatable,setmetatable
local getinfo=debug.getinfo
local lpegmatch,patterns=lpeg.match,lpeg.patterns
local floor=math.floor
local stripper=patterns.stripper
function table.strip(tab)
  local lst,l={},0
  for i=1,#tab do
    local s=lpegmatch(stripper,tab[i]) or ""
    if s=="" then
    else
      l=l+1
      lst[l]=s
    end
  end
  return lst
end
function table.keys(t)
  if t then
    local keys,k={},0
    for key,_ in next,t do
      k=k+1
      keys[k]=key
    end
    return keys
  else
    return {}
  end
end
local function compare(a,b)
  local ta,tb=type(a),type(b) 
  if ta==tb then
    return a<b
  else
    return tostring(a)<tostring(b)
  end
end
local function sortedkeys(tab)
  if tab then
    local srt,category,s={},0,0 
    for key,_ in next,tab do
      s=s+1
      srt[s]=key
      if category==3 then
      else
        local tkey=type(key)
        if tkey=="string" then
          category=(category==2 and 3) or 1
        elseif tkey=="number" then
          category=(category==1 and 3) or 2
        else
          category=3
        end
      end
    end
    if category==0 or category==3 then
      sort(srt,compare)
    else
      sort(srt)
    end
    return srt
  else
    return {}
  end
end
local function sortedhashonly(tab)
  if tab then
    local srt,s={},0
    for key,_ in next,tab do
      if type(key)=="string" then
        s=s+1
        srt[s]=key
      end
    end
    sort(srt)
    return srt
  else
    return {}
  end
end
local function sortedindexonly(tab)
  if tab then
    local srt,s={},0
    for key,_ in next,tab do
      if type(key)=="number" then
        s=s+1
        srt[s]=key
      end
    end
    sort(srt)
    return srt
  else
    return {}
  end
end
local function sortedhashkeys(tab,cmp) 
  if tab then
    local srt,s={},0
    for key,_ in next,tab do
      if key then
        s=s+1
        srt[s]=key
      end
    end
    sort(srt,cmp)
    return srt
  else
    return {}
  end
end
function table.allkeys(t)
  local keys={}
  for k,v in next,t do
    for k,v in next,v do
      keys[k]=true
    end
  end
  return sortedkeys(keys)
end
table.sortedkeys=sortedkeys
table.sortedhashonly=sortedhashonly
table.sortedindexonly=sortedindexonly
table.sortedhashkeys=sortedhashkeys
local function nothing() end
local function sortedhash(t,cmp)
  if t then
    local s
    if cmp then
      s=sortedhashkeys(t,function(a,b) return cmp(t,a,b) end)
    else
      s=sortedkeys(t) 
    end
    local n=0
    local m=#s
    local function kv(s)
      if n<m then
        n=n+1
        local k=s[n]
        return k,t[k]
      end
    end
    return kv,s
  else
    return nothing
  end
end
table.sortedhash=sortedhash
table.sortedpairs=sortedhash 
function table.append(t,list)
  local n=#t
  for i=1,#list do
    n=n+1
    t[n]=list[i]
  end
  return t
end
function table.prepend(t,list)
  local nl=#list
  local nt=nl+#t
  for i=#t,1,-1 do
    t[nt]=t[i]
    nt=nt-1
  end
  for i=1,#list do
    t[i]=list[i]
  end
  return t
end
function table.merge(t,...) 
  t=t or {}
  for i=1,select("#",...) do
    for k,v in next,(select(i,...)) do
      t[k]=v
    end
  end
  return t
end
function table.merged(...)
  local t={}
  for i=1,select("#",...) do
    for k,v in next,(select(i,...)) do
      t[k]=v
    end
  end
  return t
end
function table.imerge(t,...)
  local nt=#t
  for i=1,select("#",...) do
    local nst=select(i,...)
    for j=1,#nst do
      nt=nt+1
      t[nt]=nst[j]
    end
  end
  return t
end
function table.imerged(...)
  local tmp,ntmp={},0
  for i=1,select("#",...) do
    local nst=select(i,...)
    for j=1,#nst do
      ntmp=ntmp+1
      tmp[ntmp]=nst[j]
    end
  end
  return tmp
end
local function fastcopy(old,metatabletoo) 
  if old then
    local new={}
    for k,v in next,old do
      if type(v)=="table" then
        new[k]=fastcopy(v,metatabletoo) 
      else
        new[k]=v
      end
    end
    if metatabletoo then
      local mt=getmetatable(old)
      if mt then
        setmetatable(new,mt)
      end
    end
    return new
  else
    return {}
  end
end
local function copy(t,tables) 
  tables=tables or {}
  local tcopy={}
  if not tables[t] then
    tables[t]=tcopy
  end
  for i,v in next,t do 
    if type(i)=="table" then
      if tables[i] then
        i=tables[i]
      else
        i=copy(i,tables)
      end
    end
    if type(v)~="table" then
      tcopy[i]=v
    elseif tables[v] then
      tcopy[i]=tables[v]
    else
      tcopy[i]=copy(v,tables)
    end
  end
  local mt=getmetatable(t)
  if mt then
    setmetatable(tcopy,mt)
  end
  return tcopy
end
table.fastcopy=fastcopy
table.copy=copy
function table.derive(parent) 
  local child={}
  if parent then
    setmetatable(child,{ __index=parent })
  end
  return child
end
function table.tohash(t,value)
  local h={}
  if t then
    if value==nil then value=true end
    for _,v in next,t do 
      h[v]=value
    end
  end
  return h
end
function table.fromhash(t)
  local hsh,h={},0
  for k,v in next,t do 
    if v then
      h=h+1
      hsh[h]=k
    end
  end
  return hsh
end
local noquotes,hexify,handle,reduce,compact,inline,functions
local reserved=table.tohash { 
  'and','break','do','else','elseif','end','false','for','function','if',
  'in','local','nil','not','or','repeat','return','then','true','until','while',
  'NaN','goto',
}
local function simple_table(t)
  if #t>0 then
    local n=0
    for _,v in next,t do
      n=n+1
    end
    if n==#t then
      local tt,nt={},0
      for i=1,#t do
        local v=t[i]
        local tv=type(v)
        if tv=="number" then
          nt=nt+1
          if hexify then
            tt[nt]=format("0x%04X",v)
          else
            tt[nt]=tostring(v) 
          end
        elseif tv=="string" then
          nt=nt+1
          tt[nt]=format("%q",v)
        elseif tv=="boolean" then
          nt=nt+1
          tt[nt]=v and "true" or "false"
        else
          tt=nil
          break
        end
      end
      return tt
    end
  end
  return nil
end
local propername=patterns.propername 
local function dummy() end
local function do_serialize(root,name,depth,level,indexed)
  if level>0 then
    depth=depth.." "
    if indexed then
      handle(format("%s{",depth))
    else
      local tn=type(name)
      if tn=="number" then
        if hexify then
          handle(format("%s[0x%04X]={",depth,name))
        else
          handle(format("%s[%s]={",depth,name))
        end
      elseif tn=="string" then
        if noquotes and not reserved[name] and lpegmatch(propername,name) then
          handle(format("%s%s={",depth,name))
        else
          handle(format("%s[%q]={",depth,name))
        end
      elseif tn=="boolean" then
        handle(format("%s[%s]={",depth,name and "true" or "false"))
      else
        handle(format("%s{",depth))
      end
    end
  end
  if root and next(root) then
    local first,last=nil,0
    if compact then
      last=#root
      for k=1,last do
        if root[k]==nil then
          last=k-1
          break
        end
      end
      if last>0 then
        first=1
      end
    end
    local sk=sortedkeys(root)
    for i=1,#sk do
      local k=sk[i]
      local v=root[k]
      local tv,tk=type(v),type(k)
      if compact and first and tk=="number" and k>=first and k<=last then
        if tv=="number" then
          if hexify then
            handle(format("%s 0x%04X,",depth,v))
          else
            handle(format("%s %s,",depth,v)) 
          end
        elseif tv=="string" then
          if reduce and tonumber(v) then
            handle(format("%s %s,",depth,v))
          else
            handle(format("%s %q,",depth,v))
          end
        elseif tv=="table" then
          if not next(v) then
            handle(format("%s {},",depth))
          elseif inline then 
            local st=simple_table(v)
            if st then
              handle(format("%s { %s },",depth,concat(st,", ")))
            else
              do_serialize(v,k,depth,level+1,true)
            end
          else
            do_serialize(v,k,depth,level+1,true)
          end
        elseif tv=="boolean" then
          handle(format("%s %s,",depth,v and "true" or "false"))
        elseif tv=="function" then
          if functions then
            handle(format('%s load(%q),',depth,dump(v))) 
          else
            handle(format('%s "function",',depth))
          end
        else
          handle(format("%s %q,",depth,tostring(v)))
        end
      elseif k=="__p__" then 
        if false then
          handle(format("%s __p__=nil,",depth))
        end
      elseif tv=="number" then
        if tk=="number" then
          if hexify then
            handle(format("%s [0x%04X]=0x%04X,",depth,k,v))
          else
            handle(format("%s [%s]=%s,",depth,k,v)) 
          end
        elseif tk=="boolean" then
          if hexify then
            handle(format("%s [%s]=0x%04X,",depth,k and "true" or "false",v))
          else
            handle(format("%s [%s]=%s,",depth,k and "true" or "false",v)) 
          end
        elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
          if hexify then
            handle(format("%s %s=0x%04X,",depth,k,v))
          else
            handle(format("%s %s=%s,",depth,k,v)) 
          end
        else
          if hexify then
            handle(format("%s [%q]=0x%04X,",depth,k,v))
          else
            handle(format("%s [%q]=%s,",depth,k,v)) 
          end
        end
      elseif tv=="string" then
        if reduce and tonumber(v) then
          if tk=="number" then
            if hexify then
              handle(format("%s [0x%04X]=%s,",depth,k,v))
            else
              handle(format("%s [%s]=%s,",depth,k,v))
            end
          elseif tk=="boolean" then
            handle(format("%s [%s]=%s,",depth,k and "true" or "false",v))
          elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
            handle(format("%s %s=%s,",depth,k,v))
          else
            handle(format("%s [%q]=%s,",depth,k,v))
          end
        else
          if tk=="number" then
            if hexify then
              handle(format("%s [0x%04X]=%q,",depth,k,v))
            else
              handle(format("%s [%s]=%q,",depth,k,v))
            end
          elseif tk=="boolean" then
            handle(format("%s [%s]=%q,",depth,k and "true" or "false",v))
          elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
            handle(format("%s %s=%q,",depth,k,v))
          else
            handle(format("%s [%q]=%q,",depth,k,v))
          end
        end
      elseif tv=="table" then
        if not next(v) then
          if tk=="number" then
            if hexify then
              handle(format("%s [0x%04X]={},",depth,k))
            else
              handle(format("%s [%s]={},",depth,k))
            end
          elseif tk=="boolean" then
            handle(format("%s [%s]={},",depth,k and "true" or "false"))
          elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
            handle(format("%s %s={},",depth,k))
          else
            handle(format("%s [%q]={},",depth,k))
          end
        elseif inline then
          local st=simple_table(v)
          if st then
            if tk=="number" then
              if hexify then
                handle(format("%s [0x%04X]={ %s },",depth,k,concat(st,", ")))
              else
                handle(format("%s [%s]={ %s },",depth,k,concat(st,", ")))
              end
            elseif tk=="boolean" then
              handle(format("%s [%s]={ %s },",depth,k and "true" or "false",concat(st,", ")))
            elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
              handle(format("%s %s={ %s },",depth,k,concat(st,", ")))
            else
              handle(format("%s [%q]={ %s },",depth,k,concat(st,", ")))
            end
          else
            do_serialize(v,k,depth,level+1)
          end
        else
          do_serialize(v,k,depth,level+1)
        end
      elseif tv=="boolean" then
        if tk=="number" then
          if hexify then
            handle(format("%s [0x%04X]=%s,",depth,k,v and "true" or "false"))
          else
            handle(format("%s [%s]=%s,",depth,k,v and "true" or "false"))
          end
        elseif tk=="boolean" then
          handle(format("%s [%s]=%s,",depth,tostring(k),v and "true" or "false"))
        elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
          handle(format("%s %s=%s,",depth,k,v and "true" or "false"))
        else
          handle(format("%s [%q]=%s,",depth,k,v and "true" or "false"))
        end
      elseif tv=="function" then
        if functions then
          local f=getinfo(v).what=="C" and dump(dummy) or dump(v)
          if tk=="number" then
            if hexify then
              handle(format("%s [0x%04X]=load(%q),",depth,k,f))
            else
              handle(format("%s [%s]=load(%q),",depth,k,f))
            end
          elseif tk=="boolean" then
            handle(format("%s [%s]=load(%q),",depth,k and "true" or "false",f))
          elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
            handle(format("%s %s=load(%q),",depth,k,f))
          else
            handle(format("%s [%q]=load(%q),",depth,k,f))
          end
        end
      else
        if tk=="number" then
          if hexify then
            handle(format("%s [0x%04X]=%q,",depth,k,tostring(v)))
          else
            handle(format("%s [%s]=%q,",depth,k,tostring(v)))
          end
        elseif tk=="boolean" then
          handle(format("%s [%s]=%q,",depth,k and "true" or "false",tostring(v)))
        elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
          handle(format("%s %s=%q,",depth,k,tostring(v)))
        else
          handle(format("%s [%q]=%q,",depth,k,tostring(v)))
        end
      end
    end
  end
  if level>0 then
    handle(format("%s},",depth))
  end
end
local function serialize(_handle,root,name,specification) 
  local tname=type(name)
  if type(specification)=="table" then
    noquotes=specification.noquotes
    hexify=specification.hexify
    handle=_handle or specification.handle or print
    reduce=specification.reduce or false
    functions=specification.functions
    compact=specification.compact
    inline=specification.inline and compact
    if functions==nil then
      functions=true
    end
    if compact==nil then
      compact=true
    end
    if inline==nil then
      inline=compact
    end
  else
    noquotes=false
    hexify=false
    handle=_handle or print
    reduce=false
    compact=true
    inline=true
    functions=true
  end
  if tname=="string" then
    if name=="return" then
      handle("return {")
    else
      handle(name.."={")
    end
  elseif tname=="number" then
    if hexify then
      handle(format("[0x%04X]={",name))
    else
      handle("["..name.."]={")
    end
  elseif tname=="boolean" then
    if name then
      handle("return {")
    else
      handle("{")
    end
  else
    handle("t={")
  end
  if root then
    if getmetatable(root) then 
      local dummy=root._w_h_a_t_e_v_e_r_
      root._w_h_a_t_e_v_e_r_=nil
    end
    if next(root) then
      do_serialize(root,name,"",0)
    end
  end
  handle("}")
end
function table.serialize(root,name,specification)
  local t,n={},0
  local function flush(s)
    n=n+1
    t[n]=s
  end
  serialize(flush,root,name,specification)
  return concat(t,"\n")
end
table.tohandle=serialize
local maxtab=2*1024
function table.tofile(filename,root,name,specification)
  local f=io.open(filename,'w')
  if f then
    if maxtab>1 then
      local t,n={},0
      local function flush(s)
        n=n+1
        t[n]=s
        if n>maxtab then
          f:write(concat(t,"\n"),"\n") 
          t,n={},0 
        end
      end
      serialize(flush,root,name,specification)
      f:write(concat(t,"\n"),"\n")
    else
      local function flush(s)
        f:write(s,"\n")
      end
      serialize(flush,root,name,specification)
    end
    f:close()
    io.flush()
  end
end
local function flattened(t,f,depth) 
  if f==nil then
    f={}
    depth=0xFFFF
  elseif tonumber(f) then
    depth=f
    f={}
  elseif not depth then
    depth=0xFFFF
  end
  for k,v in next,t do
    if type(k)~="number" then
      if depth>0 and type(v)=="table" then
        flattened(v,f,depth-1)
      else
        f[#f+1]=v
      end
    end
  end
  for k=1,#t do
    local v=t[k]
    if depth>0 and type(v)=="table" then
      flattened(v,f,depth-1)
    else
      f[#f+1]=v
    end
  end
  return f
end
table.flattened=flattened
local function unnest(t,f) 
  if not f then     
    f={}      
  end
  for i=1,#t do
    local v=t[i]
    if type(v)=="table" then
      if type(v[1])=="table" then
        unnest(v,f)
      else
        f[#f+1]=v
      end
    else
      f[#f+1]=v
    end
  end
  return f
end
function table.unnest(t) 
  return unnest(t)
end
local function are_equal(a,b,n,m) 
  if a and b and #a==#b then
    n=n or 1
    m=m or #a
    for i=n,m do
      local ai,bi=a[i],b[i]
      if ai==bi then
      elseif type(ai)=="table" and type(bi)=="table" then
        if not are_equal(ai,bi) then
          return false
        end
      else
        return false
      end
    end
    return true
  else
    return false
  end
end
local function identical(a,b) 
  for ka,va in next,a do
    local vb=b[ka]
    if va==vb then
    elseif type(va)=="table" and type(vb)=="table" then
      if not identical(va,vb) then
        return false
      end
    else
      return false
    end
  end
  return true
end
table.identical=identical
table.are_equal=are_equal
function table.compact(t) 
  if t then
    for k,v in next,t do
      if not next(v) then 
        t[k]=nil
      end
    end
  end
end
function table.contains(t,v)
  if t then
    for i=1,#t do
      if t[i]==v then
        return i
      end
    end
  end
  return false
end
function table.count(t)
  local n=0
  for k,v in next,t do
    n=n+1
  end
  return n
end
function table.swapped(t,s) 
  local n={}
  if s then
    for k,v in next,s do
      n[k]=v
    end
  end
  for k,v in next,t do
    n[v]=k
  end
  return n
end
function table.mirrored(t) 
  local n={}
  for k,v in next,t do
    n[v]=k
    n[k]=v
  end
  return n
end
function table.reversed(t)
  if t then
    local tt,tn={},#t
    if tn>0 then
      local ttn=0
      for i=tn,1,-1 do
        ttn=ttn+1
        tt[ttn]=t[i]
      end
    end
    return tt
  end
end
function table.reverse(t)
  if t then
    local n=#t
    for i=1,floor(n/2) do
      local j=n-i+1
      t[i],t[j]=t[j],t[i]
    end
    return t
  end
end
function table.sequenced(t,sep,simple) 
  if not t then
    return ""
  end
  local n=#t
  local s={}
  if n>0 then
    for i=1,n do
      s[i]=tostring(t[i])
    end
  else
    n=0
    for k,v in sortedhash(t) do
      if simple then
        if v==true then
          n=n+1
          s[n]=k
        elseif v and v~="" then
          n=n+1
          s[n]=k.."="..tostring(v)
        end
      else
        n=n+1
        s[n]=k.."="..tostring(v)
      end
    end
  end
  return concat(s,sep or " | ")
end
function table.print(t,...)
  if type(t)~="table" then
    print(tostring(t))
  else
    serialize(print,t,...)
  end
end
if setinspector then
  setinspector(function(v) if type(v)=="table" then serialize(print,v,"table") return true end end)
end
function table.sub(t,i,j)
  return { unpack(t,i,j) }
end
function table.is_empty(t)
  return not t or not next(t)
end
function table.has_one_entry(t)
  return t and not next(t,next(t))
end
function table.loweredkeys(t) 
  local l={}
  for k,v in next,t do
    l[lower(k)]=v
  end
  return l
end
function table.unique(old)
  local hash={}
  local new={}
  local n=0
  for i=1,#old do
    local oi=old[i]
    if not hash[oi] then
      n=n+1
      new[n]=oi
      hash[oi]=true
    end
  end
  return new
end
function table.sorted(t,...)
  sort(t,...)
  return t 
end
function table.values(t,s) 
  if t then
    local values,keys,v={},{},0
    for key,value in next,t do
      if not keys[value] then
        v=v+1
        values[v]=value
        keys[k]=key
      end
    end
    if s then
      sort(values)
    end
    return values
  else
    return {}
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-io']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local io=io
local byte,find,gsub,format=string.byte,string.find,string.gsub,string.format
local concat=table.concat
local floor=math.floor
local type=type
if string.find(os.getenv("PATH"),";",1,true) then
  io.fileseparator,io.pathseparator="\\",";"
else
  io.fileseparator,io.pathseparator="/",":"
end
local function readall(f)
  return f:read("*all")
end
local function readall(f)
  local size=f:seek("end")
  if size==0 then
    return ""
  elseif size<1024*1024 then
    f:seek("set",0)
    return f:read('*all')
  else
    local done=f:seek("set",0)
    local step
    if size<1024*1024 then
      step=1024*1024
    elseif size>16*1024*1024 then
      step=16*1024*1024
    else
      step=floor(size/(1024*1024))*1024*1024/8
    end
    local data={}
    while true do
      local r=f:read(step)
      if not r then
        return concat(data)
      else
        data[#data+1]=r
      end
    end
  end
end
io.readall=readall
function io.loaddata(filename,textmode) 
  local f=io.open(filename,(textmode and 'r') or 'rb')
  if f then
    local data=readall(f)
    f:close()
    if #data>0 then
      return data
    end
  end
end
function io.savedata(filename,data,joiner)
  local f=io.open(filename,"wb")
  if f then
    if type(data)=="table" then
      f:write(concat(data,joiner or ""))
    elseif type(data)=="function" then
      data(f)
    else
      f:write(data or "")
    end
    f:close()
    io.flush()
    return true
  else
    return false
  end
end
function io.loadlines(filename,n) 
  local f=io.open(filename,'r')
  if not f then
  elseif n then
    local lines={}
    for i=1,n do
      local line=f:read("*lines")
      if line then
        lines[#lines+1]=line
      else
        break
      end
    end
    f:close()
    lines=concat(lines,"\n")
    if #lines>0 then
      return lines
    end
  else
    local line=f:read("*line") or ""
    f:close()
    if #line>0 then
      return line
    end
  end
end
function io.loadchunk(filename,n)
  local f=io.open(filename,'rb')
  if f then
    local data=f:read(n or 1024)
    f:close()
    if #data>0 then
      return data
    end
  end
end
function io.exists(filename)
  local f=io.open(filename)
  if f==nil then
    return false
  else
    f:close()
    return true
  end
end
function io.size(filename)
  local f=io.open(filename)
  if f==nil then
    return 0
  else
    local s=f:seek("end")
    f:close()
    return s
  end
end
function io.noflines(f)
  if type(f)=="string" then
    local f=io.open(filename)
    if f then
      local n=f and io.noflines(f) or 0
      f:close()
      return n
    else
      return 0
    end
  else
    local n=0
    for _ in f:lines() do
      n=n+1
    end
    f:seek('set',0)
    return n
  end
end
local nextchar={
  [ 4]=function(f)
    return f:read(1,1,1,1)
  end,
  [ 2]=function(f)
    return f:read(1,1)
  end,
  [ 1]=function(f)
    return f:read(1)
  end,
  [-2]=function(f)
    local a,b=f:read(1,1)
    return b,a
  end,
  [-4]=function(f)
    local a,b,c,d=f:read(1,1,1,1)
    return d,c,b,a
  end
}
function io.characters(f,n)
  if f then
    return nextchar[n or 1],f
  end
end
local nextbyte={
  [4]=function(f)
    local a,b,c,d=f:read(1,1,1,1)
    if d then
      return byte(a),byte(b),byte(c),byte(d)
    end
  end,
  [3]=function(f)
    local a,b,c=f:read(1,1,1)
    if b then
      return byte(a),byte(b),byte(c)
    end
  end,
  [2]=function(f)
    local a,b=f:read(1,1)
    if b then
      return byte(a),byte(b)
    end
  end,
  [1]=function (f)
    local a=f:read(1)
    if a then
      return byte(a)
    end
  end,
  [-2]=function (f)
    local a,b=f:read(1,1)
    if b then
      return byte(b),byte(a)
    end
  end,
  [-3]=function(f)
    local a,b,c=f:read(1,1,1)
    if b then
      return byte(c),byte(b),byte(a)
    end
  end,
  [-4]=function(f)
    local a,b,c,d=f:read(1,1,1,1)
    if d then
      return byte(d),byte(c),byte(b),byte(a)
    end
  end
}
function io.bytes(f,n)
  if f then
    return nextbyte[n or 1],f
  else
    return nil,nil
  end
end
function io.ask(question,default,options)
  while true do
    io.write(question)
    if options then
      io.write(format(" [%s]",concat(options,"|")))
    end
    if default then
      io.write(format(" [%s]",default))
    end
    io.write(format(" "))
    io.flush()
    local answer=io.read()
    answer=gsub(answer,"^%s*(.*)%s*$","%1")
    if answer=="" and default then
      return default
    elseif not options then
      return answer
    else
      for k=1,#options do
        if options[k]==answer then
          return answer
        end
      end
      local pattern="^"..answer
      for k=1,#options do
        local v=options[k]
        if find(v,pattern) then
          return v
        end
      end
    end
  end
end
local function readnumber(f,n,m)
  if m then
    f:seek("set",n)
    n=m
  end
  if n==1 then
    return byte(f:read(1))
  elseif n==2 then
    local a,b=byte(f:read(2),1,2)
    return 256*a+b
  elseif n==3 then
    local a,b,c=byte(f:read(3),1,3)
    return 256*256*a+256*b+c
  elseif n==4 then
    local a,b,c,d=byte(f:read(4),1,4)
    return 256*256*256*a+256*256*b+256*c+d
  elseif n==8 then
    local a,b=readnumber(f,4),readnumber(f,4)
    return 256*a+b
  elseif n==12 then
    local a,b,c=readnumber(f,4),readnumber(f,4),readnumber(f,4)
    return 256*256*a+256*b+c
  elseif n==-2 then
    local b,a=byte(f:read(2),1,2)
    return 256*a+b
  elseif n==-3 then
    local c,b,a=byte(f:read(3),1,3)
    return 256*256*a+256*b+c
  elseif n==-4 then
    local d,c,b,a=byte(f:read(4),1,4)
    return 256*256*256*a+256*256*b+256*c+d
  elseif n==-8 then
    local h,g,f,e,d,c,b,a=byte(f:read(8),1,8)
    return 256*256*256*256*256*256*256*a+256*256*256*256*256*256*b+256*256*256*256*256*c+256*256*256*256*d+256*256*256*e+256*256*f+256*g+h
  else
    return 0
  end
end
io.readnumber=readnumber
function io.readstring(f,n,m)
  if m then
    f:seek("set",n)
    n=m
  end
  local str=gsub(f:read(n),"\000","")
  return str
end
if not io.i_limiter then function io.i_limiter() end end 
if not io.o_limiter then function io.o_limiter() end end

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
local match,find,gmatch=string.match,string.find,string.gmatch
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
local pattern=(noslashes^0*slashes)^0*noperiod^1*((period*C(noperiod^1))^1)*-1+Cc("")
local function suffixesonly(name)
  if name then
    return lpegmatch(pattern,name)
  else
    return ""
  end
end
file.pathpart=pathpart
file.basename=basename
file.nameonly=nameonly
file.suffixonly=suffixonly
file.suffix=suffixonly
file.suffixesonly=suffixesonly
file.suffixes=suffixesonly
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
  if str then
    return lpegmatch(pattern_d,str) 
  else
    return "",str 
  end
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
local someslash=S("\\/")
local stripper=Cs(P(fwslash)^0/""*reslasher)
local isnetwork=someslash*someslash*(1-someslash)+(1-fwslash-colon)^1*colon
local isroot=fwslash^1*-1
local hasroot=fwslash^1
local reslasher=lpeg.replacer(S("\\/"),"/")
local deslasher=lpeg.replacer(S("\\/")^1,"/")
function file.join(...)
  local lst={... }
  local one=lst[1]
  if lpegmatch(isnetwork,one) then
    local one=lpegmatch(reslasher,one)
    local two=lpegmatch(deslasher,concat(lst,"/",2))
    if lpegmatch(hasroot,two) then
      return one..two
    else
      return one.."/"..two
    end
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
local mswindrive=Cs(drivespec*(bwslash/"/"+fwslash)^0)
local mswinuncpath=(bwslash+fwslash)*(bwslash+fwslash)*Cc("//")
local splitstarter=(mswindrive+mswinuncpath+Cc(false))*Ct(lpeg.splitat(S("/\\")^1))
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
function lfs.mkdirs(path)
  local full=""
  for sub in gmatch(path,"(/*[^\\/]+)") do 
    full=full..sub
    lfs.mkdir(full)
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-boolean']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local type,tonumber=type,tonumber
boolean=boolean or {}
local boolean=boolean
function boolean.tonumber(b)
  if b then return 1 else return 0 end 
end
function toboolean(str,tolerant) 
  if str==nil then
    return false
  elseif str==false then
    return false
  elseif str==true then
    return true
  elseif str=="true" then
    return true
  elseif str=="false" then
    return false
  elseif not tolerant then
    return false
  elseif str==0 then
    return false
  elseif (tonumber(str) or 0)>0 then
    return true
  else
    return str=="yes" or str=="on" or str=="t"
  end
end
string.toboolean=toboolean
function string.booleanstring(str)
  if str=="0" then
    return false
  elseif str=="1" then
    return true
  elseif str=="" then
    return false
  elseif str=="false" then
    return false
  elseif str=="true" then
    return true
  elseif (tonumber(str) or 0)>0 then
    return true
  else
    return str=="yes" or str=="on" or str=="t"
  end
end
function string.is_boolean(str,default)
  if type(str)=="string" then
    if str=="true" or str=="yes" or str=="on" or str=="t" or str=="1" then
      return true
    elseif str=="false" or str=="no" or str=="off" or str=="f" or str=="0" then
      return false
    end
  end
  return default
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-math']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local floor,sin,cos,tan=math.floor,math.sin,math.cos,math.tan
if not math.round then
  function math.round(x) return floor(x+0.5) end
end
if not math.div then
  function math.div(n,m) return floor(n/m) end
end
if not math.mod then
  function math.mod(n,m) return n%m end
end
local pipi=2*math.pi/360
if not math.sind then
  function math.sind(d) return sin(d*pipi) end
  function math.cosd(d) return cos(d*pipi) end
  function math.tand(d) return tan(d*pipi) end
end
if not math.odd then
  function math.odd (n) return n%2~=0 end
  function math.even(n) return n%2==0 end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['util-str']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
utilities=utilities or {}
utilities.strings=utilities.strings or {}
local strings=utilities.strings
local format,gsub,rep,sub=string.format,string.gsub,string.rep,string.sub
local load,dump=load,string.dump
local tonumber,type,tostring=tonumber,type,tostring
local unpack,concat=table.unpack,table.concat
local P,V,C,S,R,Ct,Cs,Cp,Carg,Cc=lpeg.P,lpeg.V,lpeg.C,lpeg.S,lpeg.R,lpeg.Ct,lpeg.Cs,lpeg.Cp,lpeg.Carg,lpeg.Cc
local patterns,lpegmatch=lpeg.patterns,lpeg.match
local utfchar,utfbyte=utf.char,utf.byte
local loadstripped=nil
if _LUAVERSION<5.2 then
  loadstripped=function(str,shortcuts)
    return load(str)
  end
else
  loadstripped=function(str,shortcuts)
    if shortcuts then
      return load(dump(load(str),true),nil,nil,shortcuts)
    else
      return load(dump(load(str),true))
    end
  end
end
if not number then number={} end 
local stripper=patterns.stripzeros
local function points(n)
  n=tonumber(n)
  return (not n or n==0) and "0pt" or lpegmatch(stripper,format("%.5fpt",n/65536))
end
local function basepoints(n)
  n=tonumber(n)
  return (not n or n==0) and "0bp" or lpegmatch(stripper,format("%.5fbp",n*(7200/7227)/65536))
end
number.points=points
number.basepoints=basepoints
local rubish=patterns.spaceortab^0*patterns.newline
local anyrubish=patterns.spaceortab+patterns.newline
local anything=patterns.anything
local stripped=(patterns.spaceortab^1/"")*patterns.newline
local leading=rubish^0/""
local trailing=(anyrubish^1*patterns.endofstring)/""
local redundant=rubish^3/"\n"
local pattern=Cs(leading*(trailing+redundant+stripped+anything)^0)
function strings.collapsecrlf(str)
  return lpegmatch(pattern,str)
end
local repeaters={} 
function strings.newrepeater(str,offset)
  offset=offset or 0
  local s=repeaters[str]
  if not s then
    s={}
    repeaters[str]=s
  end
  local t=s[offset]
  if t then
    return t
  end
  t={}
  setmetatable(t,{ __index=function(t,k)
    if not k then
      return ""
    end
    local n=k+offset
    local s=n>0 and rep(str,n) or ""
    t[k]=s
    return s
  end })
  s[offset]=t
  return t
end
local extra,tab,start=0,0,4,0
local nspaces=strings.newrepeater(" ")
string.nspaces=nspaces
local pattern=Carg(1)/function(t)
    extra,tab,start=0,t or 7,1
  end*Cs((
   Cp()*patterns.tab/function(position)
     local current=(position-start+1)+extra
     local spaces=tab-(current-1)%tab
     if spaces>0 then
       extra=extra+spaces-1
       return nspaces[spaces] 
     else
       return ""
     end
   end+patterns.newline*Cp()/function(position)
     extra,start=0,position
   end+patterns.anything
 )^1)
function strings.tabtospace(str,tab)
  return lpegmatch(pattern,str,1,tab or 7)
end
local newline=patterns.newline
local endofstring=patterns.endofstring
local whitespace=patterns.whitespace
local spacer=patterns.spacer
local space=spacer^0
local nospace=space/""
local endofline=nospace*newline
local stripend=(whitespace^1*endofstring)/""
local normalline=(nospace*((1-space*(newline+endofstring))^1)*nospace)
local stripempty=endofline^1/""
local normalempty=endofline^1
local singleempty=endofline*(endofline^0/"")
local doubleempty=endofline*endofline^-1*(endofline^0/"")
local stripstart=stripempty^0
local p_prune_normal=Cs (stripstart*(stripend+normalline+normalempty )^0 )
local p_prune_collapse=Cs (stripstart*(stripend+normalline+doubleempty )^0 )
local p_prune_noempty=Cs (stripstart*(stripend+normalline+singleempty )^0 )
local p_retain_normal=Cs ((normalline+normalempty )^0 )
local p_retain_collapse=Cs ((normalline+doubleempty )^0 )
local p_retain_noempty=Cs ((normalline+singleempty )^0 )
local striplinepatterns={
  ["prune"]=p_prune_normal,
  ["prune and collapse"]=p_prune_collapse,
  ["prune and no empty"]=p_prune_noempty,
  ["retain"]=p_retain_normal,
  ["retain and collapse"]=p_retain_collapse,
  ["retain and no empty"]=p_retain_noempty,
}
strings.striplinepatterns=striplinepatterns
function strings.striplines(str,how)
  return str and lpegmatch(how and striplinepatterns[how] or p_prune_collapse,str) or str
end
strings.striplong=strings.striplines
function strings.nice(str)
  str=gsub(str,"[:%-+_]+"," ") 
  return str
end
local n=0
local sequenced=table.sequenced
function string.autodouble(s,sep)
  if s==nil then
    return '""'
  end
  local t=type(s)
  if t=="number" then
    return tostring(s) 
  end
  if t=="table" then
    return ('"'..sequenced(s,sep or ",")..'"')
  end
  return ('"'..tostring(s)..'"')
end
function string.autosingle(s,sep)
  if s==nil then
    return "''"
  end
  local t=type(s)
  if t=="number" then
    return tostring(s) 
  end
  if t=="table" then
    return ("'"..sequenced(s,sep or ",").."'")
  end
  return ("'"..tostring(s).."'")
end
local tracedchars={}
string.tracedchars=tracedchars
strings.tracers=tracedchars
function string.tracedchar(b)
  if type(b)=="number" then
    return tracedchars[b] or (utfchar(b).." (U+"..format('%05X',b)..")")
  else
    local c=utfbyte(b)
    return tracedchars[c] or (b.." (U+"..format('%05X',c)..")")
  end
end
function number.signed(i)
  if i>0 then
    return "+",i
  else
    return "-",-i
  end
end
local zero=P("0")^1/""
local plus=P("+")/""
local minus=P("-")
local separator=S(".")
local digit=R("09")
local trailing=zero^1*#S("eE")
local exponent=(S("eE")*(plus+Cs((minus*zero^0*P(-1))/"")+minus)*zero^0*(P(-1)*Cc("0")+P(1)^1))
local pattern_a=Cs(minus^0*digit^1*(separator/""*trailing+separator*(trailing+digit)^0)*exponent)
local pattern_b=Cs((exponent+P(1))^0)
function number.sparseexponent(f,n)
  if not n then
    n=f
    f="%e"
  end
  local tn=type(n)
  if tn=="string" then 
    local m=tonumber(n)
    if m then
      return lpegmatch((f=="%e" or f=="%E") and pattern_a or pattern_b,format(f,m))
    end
  elseif tn=="number" then
    return lpegmatch((f=="%e" or f=="%E") and pattern_a or pattern_b,format(f,n))
  end
  return tostring(n)
end
local template=[[
%s
%s
return function(%s) return %s end
]]
local preamble,environment="",{}
if _LUAVERSION<5.2 then
  preamble=[[
local lpeg=lpeg
local type=type
local tostring=tostring
local tonumber=tonumber
local format=string.format
local concat=table.concat
local signed=number.signed
local points=number.points
local basepoints= number.basepoints
local utfchar=utf.char
local utfbyte=utf.byte
local lpegmatch=lpeg.match
local nspaces=string.nspaces
local tracedchar=string.tracedchar
local autosingle=string.autosingle
local autodouble=string.autodouble
local sequenced=table.sequenced
local formattednumber=number.formatted
local sparseexponent=number.sparseexponent
    ]]
else
  environment={
    global=global or _G,
    lpeg=lpeg,
    type=type,
    tostring=tostring,
    tonumber=tonumber,
    format=string.format,
    concat=table.concat,
    signed=number.signed,
    points=number.points,
    basepoints=number.basepoints,
    utfchar=utf.char,
    utfbyte=utf.byte,
    lpegmatch=lpeg.match,
    nspaces=string.nspaces,
    tracedchar=string.tracedchar,
    autosingle=string.autosingle,
    autodouble=string.autodouble,
    sequenced=table.sequenced,
    formattednumber=number.formatted,
    sparseexponent=number.sparseexponent,
  }
end
local arguments={ "a1" } 
setmetatable(arguments,{ __index=function(t,k)
    local v=t[k-1]..",a"..k
    t[k]=v
    return v
  end
})
local prefix_any=C((S("+- .")+R("09"))^0)
local prefix_tab=P("{")*C((1-P("}"))^0)*P("}")+C((1-R("az","AZ","09","%%"))^0)
local format_s=function(f)
  n=n+1
  if f and f~="" then
    return format("format('%%%ss',a%s)",f,n)
  else 
    return format("(a%s or '')",n) 
  end
end
local format_S=function(f) 
  n=n+1
  if f and f~="" then
    return format("format('%%%ss',tostring(a%s))",f,n)
  else
    return format("tostring(a%s)",n)
  end
end
local format_q=function()
  n=n+1
  return format("(a%s and format('%%q',a%s) or '')",n,n) 
end
local format_Q=function() 
  n=n+1
  return format("format('%%q',tostring(a%s))",n)
end
local format_i=function(f)
  n=n+1
  if f and f~="" then
    return format("format('%%%si',a%s)",f,n)
  else
    return format("format('%%i',a%s)",n) 
  end
end
local format_d=format_i
local format_I=function(f)
  n=n+1
  return format("format('%%s%%%si',signed(a%s))",f,n)
end
local format_f=function(f)
  n=n+1
  return format("format('%%%sf',a%s)",f,n)
end
local format_F=function()
  n=n+1
  if not f or f=="" then
    return format("(((a%s > -0.0000000005 and a%s < 0.0000000005) and '0') or format((a%s %% 1 == 0) and '%%i' or '%%.9f',a%s))",n,n,n,n)
  else
    return format("format((a%s %% 1 == 0) and '%%i' or '%%%sf',a%s)",n,f,n)
  end
end
local format_g=function(f)
  n=n+1
  return format("format('%%%sg',a%s)",f,n)
end
local format_G=function(f)
  n=n+1
  return format("format('%%%sG',a%s)",f,n)
end
local format_e=function(f)
  n=n+1
  return format("format('%%%se',a%s)",f,n)
end
local format_E=function(f)
  n=n+1
  return format("format('%%%sE',a%s)",f,n)
end
local format_j=function(f)
  n=n+1
  return format("sparseexponent('%%%se',a%s)",f,n)
end
local format_J=function(f)
  n=n+1
  return format("sparseexponent('%%%sE',a%s)",f,n)
end
local format_x=function(f)
  n=n+1
  return format("format('%%%sx',a%s)",f,n)
end
local format_X=function(f)
  n=n+1
  return format("format('%%%sX',a%s)",f,n)
end
local format_o=function(f)
  n=n+1
  return format("format('%%%so',a%s)",f,n)
end
local format_c=function()
  n=n+1
  return format("utfchar(a%s)",n)
end
local format_C=function()
  n=n+1
  return format("tracedchar(a%s)",n)
end
local format_r=function(f)
  n=n+1
  return format("format('%%%s.0f',a%s)",f,n)
end
local format_h=function(f)
  n=n+1
  if f=="-" then
    f=sub(f,2)
    return format("format('%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  else
    return format("format('0x%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  end
end
local format_H=function(f)
  n=n+1
  if f=="-" then
    f=sub(f,2)
    return format("format('%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  else
    return format("format('0x%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  end
end
local format_u=function(f)
  n=n+1
  if f=="-" then
    f=sub(f,2)
    return format("format('%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  else
    return format("format('u+%%%sx',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  end
end
local format_U=function(f)
  n=n+1
  if f=="-" then
    f=sub(f,2)
    return format("format('%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  else
    return format("format('U+%%%sX',type(a%s) == 'number' and a%s or utfbyte(a%s))",f=="" and "05" or f,n,n,n)
  end
end
local format_p=function()
  n=n+1
  return format("points(a%s)",n)
end
local format_b=function()
  n=n+1
  return format("basepoints(a%s)",n)
end
local format_t=function(f)
  n=n+1
  if f and f~="" then
    return format("concat(a%s,%q)",n,f)
  else
    return format("concat(a%s)",n)
  end
end
local format_T=function(f)
  n=n+1
  if f and f~="" then
    return format("sequenced(a%s,%q)",n,f)
  else
    return format("sequenced(a%s)",n)
  end
end
local format_l=function()
  n=n+1
  return format("(a%s and 'true' or 'false')",n)
end
local format_L=function()
  n=n+1
  return format("(a%s and 'TRUE' or 'FALSE')",n)
end
local format_N=function() 
  n=n+1
  return format("tostring(tonumber(a%s) or a%s)",n,n)
end
local format_a=function(f)
  n=n+1
  if f and f~="" then
    return format("autosingle(a%s,%q)",n,f)
  else
    return format("autosingle(a%s)",n)
  end
end
local format_A=function(f)
  n=n+1
  if f and f~="" then
    return format("autodouble(a%s,%q)",n,f)
  else
    return format("autodouble(a%s)",n)
  end
end
local format_w=function(f) 
  n=n+1
  f=tonumber(f)
  if f then 
    return format("nspaces[%s+a%s]",f,n) 
  else
    return format("nspaces[a%s]",n) 
  end
end
local format_W=function(f) 
  return format("nspaces[%s]",tonumber(f) or 0)
end
local digit=patterns.digit
local period=patterns.period
local three=digit*digit*digit
local splitter=Cs (
  (((1-(three^1*period))^1+C(three))*(Carg(1)*three)^1+C((1-period)^1))*(P(1)/""*Carg(2))*C(2)
)
patterns.formattednumber=splitter
function number.formatted(n,sep1,sep2)
  local s=type(s)=="string" and n or format("%0.2f",n)
  if sep1==true then
    return lpegmatch(splitter,s,1,".",",")
  elseif sep1=="." then
    return lpegmatch(splitter,s,1,sep1,sep2 or ",")
  elseif sep1=="," then
    return lpegmatch(splitter,s,1,sep1,sep2 or ".")
  else
    return lpegmatch(splitter,s,1,sep1 or ",",sep2 or ".")
  end
end
local format_m=function(f)
  n=n+1
  if not f or f=="" then
    f=","
  end
  return format([[formattednumber(a%s,%q,".")]],n,f)
end
local format_M=function(f)
  n=n+1
  if not f or f=="" then
    f="."
  end
  return format([[formattednumber(a%s,%q,",")]],n,f)
end
local format_z=function(f)
  n=n+(tonumber(f) or 1)
  return "''" 
end
local format_rest=function(s)
  return format("%q",s) 
end
local format_extension=function(extensions,f,name)
  local extension=extensions[name] or "tostring(%s)"
  local f=tonumber(f) or 1
  if f==0 then
    return extension
  elseif f==1 then
    n=n+1
    local a="a"..n
    return format(extension,a,a) 
  elseif f<0 then
    local a="a"..(n+f+1)
    return format(extension,a,a)
  else
    local t={}
    for i=1,f do
      n=n+1
      t[#t+1]="a"..n
    end
    return format(extension,unpack(t))
  end
end
local builder=Cs { "start",
  start=(
    (
      P("%")/""*(
        V("!") 
+V("s")+V("q")+V("i")+V("d")+V("f")+V("F")+V("g")+V("G")+V("e")+V("E")+V("x")+V("X")+V("o")
+V("c")+V("C")+V("S") 
+V("Q") 
+V("N")
+V("r")+V("h")+V("H")+V("u")+V("U")+V("p")+V("b")+V("t")+V("T")+V("l")+V("L")+V("I")+V("w") 
+V("W") 
+V("a") 
+V("A") 
+V("j")+V("J") 
+V("m")+V("M") 
+V("z")
+V("*") 
      )+V("*")
    )*(P(-1)+Carg(1))
  )^0,
  ["s"]=(prefix_any*P("s"))/format_s,
  ["q"]=(prefix_any*P("q"))/format_q,
  ["i"]=(prefix_any*P("i"))/format_i,
  ["d"]=(prefix_any*P("d"))/format_d,
  ["f"]=(prefix_any*P("f"))/format_f,
  ["F"]=(prefix_any*P("F"))/format_F,
  ["g"]=(prefix_any*P("g"))/format_g,
  ["G"]=(prefix_any*P("G"))/format_G,
  ["e"]=(prefix_any*P("e"))/format_e,
  ["E"]=(prefix_any*P("E"))/format_E,
  ["x"]=(prefix_any*P("x"))/format_x,
  ["X"]=(prefix_any*P("X"))/format_X,
  ["o"]=(prefix_any*P("o"))/format_o,
  ["S"]=(prefix_any*P("S"))/format_S,
  ["Q"]=(prefix_any*P("Q"))/format_S,
  ["N"]=(prefix_any*P("N"))/format_N,
  ["c"]=(prefix_any*P("c"))/format_c,
  ["C"]=(prefix_any*P("C"))/format_C,
  ["r"]=(prefix_any*P("r"))/format_r,
  ["h"]=(prefix_any*P("h"))/format_h,
  ["H"]=(prefix_any*P("H"))/format_H,
  ["u"]=(prefix_any*P("u"))/format_u,
  ["U"]=(prefix_any*P("U"))/format_U,
  ["p"]=(prefix_any*P("p"))/format_p,
  ["b"]=(prefix_any*P("b"))/format_b,
  ["t"]=(prefix_tab*P("t"))/format_t,
  ["T"]=(prefix_tab*P("T"))/format_T,
  ["l"]=(prefix_any*P("l"))/format_l,
  ["L"]=(prefix_any*P("L"))/format_L,
  ["I"]=(prefix_any*P("I"))/format_I,
  ["w"]=(prefix_any*P("w"))/format_w,
  ["W"]=(prefix_any*P("W"))/format_W,
  ["j"]=(prefix_any*P("j"))/format_j,
  ["J"]=(prefix_any*P("J"))/format_J,
  ["m"]=(prefix_tab*P("m"))/format_m,
  ["M"]=(prefix_tab*P("M"))/format_M,
  ["z"]=(prefix_any*P("z"))/format_z,
  ["a"]=(prefix_any*P("a"))/format_a,
  ["A"]=(prefix_any*P("A"))/format_A,
  ["*"]=Cs(((1-P("%"))^1+P("%%")/"%%")^1)/format_rest,
  ["!"]=Carg(2)*prefix_any*P("!")*C((1-P("!"))^1)*P("!")/format_extension,
}
local direct=Cs (
  P("%")*(S("+- .")+R("09"))^0*S("sqidfgGeExXo")*P(-1)/[[local format = string.format return function(str) return format("%0",str) end]]
)
local function make(t,str)
  local f
  local p
  local p=lpegmatch(direct,str)
  if p then
    f=loadstripped(p)()
  else
    n=0
    p=lpegmatch(builder,str,1,t._connector_,t._extensions_) 
    if n>0 then
      p=format(template,preamble,t._preamble_,arguments[n],p)
      f=loadstripped(p,t._environment_)() 
    else
      f=function() return str end
    end
  end
  t[str]=f
  return f
end
local function use(t,fmt,...)
  return t[fmt](...)
end
strings.formatters={}
if _LUAVERSION<5.2 then
  function strings.formatters.new(noconcat)
    local t={ _type_="formatter",_connector_=noconcat and "," or "..",_extensions_={},_preamble_=preamble,_environment_={} }
    setmetatable(t,{ __index=make,__call=use })
    return t
  end
else
  function strings.formatters.new(noconcat)
    local e={} 
    for k,v in next,environment do
      e[k]=v
    end
    local t={ _type_="formatter",_connector_=noconcat and "," or "..",_extensions_={},_preamble_="",_environment_=e }
    setmetatable(t,{ __index=make,__call=use })
    return t
  end
end
local formatters=strings.formatters.new() 
string.formatters=formatters 
string.formatter=function(str,...) return formatters[str](...) end 
local function add(t,name,template,preamble)
  if type(t)=="table" and t._type_=="formatter" then
    t._extensions_[name]=template or "%s"
    if type(preamble)=="string" then
      t._preamble_=preamble.."\n"..t._preamble_ 
    elseif type(preamble)=="table" then
      for k,v in next,preamble do
        t._environment_[k]=v
      end
    end
  end
end
strings.formatters.add=add
patterns.xmlescape=Cs((P("<")/"&lt;"+P(">")/"&gt;"+P("&")/"&amp;"+P('"')/"&quot;"+P(1))^0)
patterns.texescape=Cs((C(S("#$%\\{}"))/"\\%1"+P(1))^0)
patterns.luaescape=Cs(((1-S('"\n'))^1+P('"')/'\\"'+P('\n')/'\\n"')^0) 
patterns.luaquoted=Cs(Cc('"')*((1-S('"\n'))^1+P('"')/'\\"'+P('\n')/'\\n"')^0*Cc('"'))
if _LUAVERSION<5.2 then
  add(formatters,"xml",[[lpegmatch(xmlescape,%s)]],"local xmlescape = lpeg.patterns.xmlescape")
  add(formatters,"tex",[[lpegmatch(texescape,%s)]],"local texescape = lpeg.patterns.texescape")
  add(formatters,"lua",[[lpegmatch(luaescape,%s)]],"local luaescape = lpeg.patterns.luaescape")
else
  add(formatters,"xml",[[lpegmatch(xmlescape,%s)]],{ xmlescape=lpeg.patterns.xmlescape })
  add(formatters,"tex",[[lpegmatch(texescape,%s)]],{ texescape=lpeg.patterns.texescape })
  add(formatters,"lua",[[lpegmatch(luaescape,%s)]],{ luaescape=lpeg.patterns.luaescape })
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luat-basics-gen']={
  version=1.100,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local dummyfunction=function()
end
local dummyreporter=function(c)
  return function(...)
    (texio.reporter or texio.write_nl)(c.." : "..string.formatters(...))
  end
end
statistics={
  register=dummyfunction,
  starttiming=dummyfunction,
  stoptiming=dummyfunction,
  elapsedtime=nil,
}
directives={
  register=dummyfunction,
  enable=dummyfunction,
  disable=dummyfunction,
}
trackers={
  register=dummyfunction,
  enable=dummyfunction,
  disable=dummyfunction,
}
experiments={
  register=dummyfunction,
  enable=dummyfunction,
  disable=dummyfunction,
}
storage={ 
  register=dummyfunction,
  shared={},
}
logs={
  new=dummyreporter,
  reporter=dummyreporter,
  messenger=dummyreporter,
  report=dummyfunction,
}
callbacks={
  register=function(n,f) return callback.register(n,f) end,
}
utilities={
  storage={
    allocate=function(t) return t or {} end,
    mark=function(t) return t or {} end,
  },
}
characters=characters or {
  data={}
}
texconfig.kpse_init=true
resolvers=resolvers or {} 
local remapper={
  otf="opentype fonts",
  ttf="truetype fonts",
  ttc="truetype fonts",
  dfont="truetype fonts",
  cid="cid maps",
  cidmap="cid maps",
  fea="font feature files",
  pfa="type1 fonts",
  pfb="type1 fonts",
  afm="afm",
}
function resolvers.findfile(name,fileformat)
  name=string.gsub(name,"\\","/")
  if not fileformat or fileformat=="" then
    fileformat=file.suffix(name)
    if fileformat=="" then
      fileformat="tex"
    end
  end
  fileformat=string.lower(fileformat)
  fileformat=remapper[fileformat] or fileformat
  local found=kpse.find_file(name,fileformat)
  if not found or found=="" then
    found=kpse.find_file(name,"other text files")
  end
  return found
end
resolvers.findbinfile=resolvers.findfile
function resolvers.loadbinfile(filename,filetype)
  local data=io.loaddata(filename)
  return true,data,#data
end
function resolvers.resolve(s)
  return s
end
function resolvers.unresolve(s)
  return s
end
caches={}
local writable=nil
local readables={}
local usingjit=jit
if not caches.namespace or caches.namespace=="" or caches.namespace=="context" then
  caches.namespace='generic'
end
do
  local cachepaths=kpse.expand_var('$TEXMFCACHE') or ""
  if cachepaths=="" or cachepaths=="$TEXMFCACHE" then
    cachepaths=kpse.expand_var('$TEXMFVAR') or ""
  end
  if cachepaths=="" or cachepaths=="$TEXMFVAR" then
    cachepaths=kpse.expand_var('$VARTEXMF') or ""
  end
  if cachepaths=="" then
    local fallbacks={ "TMPDIR","TEMPDIR","TMP","TEMP","HOME","HOMEPATH" }
    for i=1,#fallbacks do
      cachepaths=os.getenv(fallbacks[i]) or ""
      if cachepath~="" and lfs.isdir(cachepath) then
        break
      end
    end
  end
  if cachepaths=="" then
    cachepaths="."
  end
  cachepaths=string.split(cachepaths,os.type=="windows" and ";" or ":")
  for i=1,#cachepaths do
    local cachepath=cachepaths[i]
    if not lfs.isdir(cachepath) then
      lfs.mkdirs(cachepath) 
      if lfs.isdir(cachepath) then
        texio.write(string.format("(created cache path: %s)",cachepath))
      end
    end
    if file.is_writable(cachepath) then
      writable=file.join(cachepath,"luatex-cache")
      lfs.mkdir(writable)
      writable=file.join(writable,caches.namespace)
      lfs.mkdir(writable)
      break
    end
  end
  for i=1,#cachepaths do
    if file.is_readable(cachepaths[i]) then
      readables[#readables+1]=file.join(cachepaths[i],"luatex-cache",caches.namespace)
    end
  end
  if not writable then
    texio.write_nl("quiting: fix your writable cache path")
    os.exit()
  elseif #readables==0 then
    texio.write_nl("quiting: fix your readable cache path")
    os.exit()
  elseif #readables==1 and readables[1]==writable then
    texio.write(string.format("(using cache: %s)",writable))
  else
    texio.write(string.format("(using write cache: %s)",writable))
    texio.write(string.format("(using read cache: %s)",table.concat(readables," ")))
  end
end
function caches.getwritablepath(category,subcategory)
  local path=file.join(writable,category)
  lfs.mkdir(path)
  path=file.join(path,subcategory)
  lfs.mkdir(path)
  return path
end
function caches.getreadablepaths(category,subcategory)
  local t={}
  for i=1,#readables do
    t[i]=file.join(readables[i],category,subcategory)
  end
  return t
end
local function makefullname(path,name)
  if path and path~="" then
    return file.addsuffix(file.join(path,name),"lua"),file.addsuffix(file.join(path,name),usingjit and "lub" or "luc")
  end
end
function caches.is_writable(path,name)
  local fullname=makefullname(path,name)
  return fullname and file.is_writable(fullname)
end
function caches.loaddata(paths,name)
  for i=1,#paths do
    local data=false
    local luaname,lucname=makefullname(paths[i],name)
    if lucname and not lfs.isfile(lucname) and type(caches.compile)=="function" then
      texio.write(string.format("(compiling luc: %s)",lucname))
      data=loadfile(luaname)
      if data then
        data=data()
      end
      if data then
        caches.compile(data,luaname,lucname)
        return data
      end
    end
    if lucname and lfs.isfile(lucname) then 
      texio.write(string.format("(load luc: %s)",lucname))
      data=loadfile(lucname)
      if data then
        data=data()
      end
      if data then
        return data
      else
        texio.write(string.format("(loading failed: %s)",lucname))
      end
    end
    if luaname and lfs.isfile(luaname) then
      texio.write(string.format("(load lua: %s)",luaname))
      data=loadfile(luaname)
      if data then
        data=data()
      end
      if data then
        return data
      end
    end
  end
end
function caches.savedata(path,name,data)
  local luaname,lucname=makefullname(path,name)
  if luaname then
    texio.write(string.format("(save: %s)",luaname))
    table.tofile(luaname,data,true)
    if lucname and type(caches.compile)=="function" then
      os.remove(lucname) 
      texio.write(string.format("(save: %s)",lucname))
      caches.compile(data,luaname,lucname)
    end
  end
end
function caches.compile(data,luaname,lucname)
  local d=io.loaddata(luaname)
  if not d or d=="" then
    d=table.serialize(data,true) 
  end
  if d and d~="" then
    local f=io.open(lucname,'wb')
    if f then
      local s=loadstring(d)
      if s then
        f:write(string.dump(s,true))
      end
      f:close()
    end
  end
end
function table.setmetatableindex(t,f)
  setmetatable(t,{ __index=f })
end
arguments={}
if arg then
  for i=1,#arg do
    local k,v=string.match(arg[i],"^%-%-([^=]+)=?(.-)$")
    if k and v then
      arguments[k]=v
    end
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['data-con']={
  version=1.100,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local format,lower,gsub=string.format,string.lower,string.gsub
local trace_cache=false trackers.register("resolvers.cache",function(v) trace_cache=v end)
local trace_containers=false trackers.register("resolvers.containers",function(v) trace_containers=v end)
local trace_storage=false trackers.register("resolvers.storage",function(v) trace_storage=v end)
containers=containers or {}
local containers=containers
containers.usecache=true
local report_containers=logs.reporter("resolvers","containers")
local allocated={}
local mt={
  __index=function(t,k)
    if k=="writable" then
      local writable=caches.getwritablepath(t.category,t.subcategory) or { "." }
      t.writable=writable
      return writable
    elseif k=="readables" then
      local readables=caches.getreadablepaths(t.category,t.subcategory) or { "." }
      t.readables=readables
      return readables
    end
  end,
  __storage__=true
}
function containers.define(category,subcategory,version,enabled)
  if category and subcategory then
    local c=allocated[category]
    if not c then
      c={}
      allocated[category]=c
    end
    local s=c[subcategory]
    if not s then
      s={
        category=category,
        subcategory=subcategory,
        storage={},
        enabled=enabled,
        version=version or math.pi,
        trace=false,
      }
      setmetatable(s,mt)
      c[subcategory]=s
    end
    return s
  end
end
function containers.is_usable(container,name)
  return container.enabled and caches and caches.is_writable(container.writable,name)
end
function containers.is_valid(container,name)
  if name and name~="" then
    local storage=container.storage[name]
    return storage and storage.cache_version==container.version
  else
    return false
  end
end
function containers.read(container,name)
  local storage=container.storage
  local stored=storage[name]
  if not stored and container.enabled and caches and containers.usecache then
    stored=caches.loaddata(container.readables,name)
    if stored and stored.cache_version==container.version then
      if trace_cache or trace_containers then
        report_containers("action %a, category %a, name %a","load",container.subcategory,name)
      end
    else
      stored=nil
    end
    storage[name]=stored
  elseif stored then
    if trace_cache or trace_containers then
      report_containers("action %a, category %a, name %a","reuse",container.subcategory,name)
    end
  end
  return stored
end
function containers.write(container,name,data)
  if data then
    data.cache_version=container.version
    if container.enabled and caches then
      local unique,shared=data.unique,data.shared
      data.unique,data.shared=nil,nil
      caches.savedata(container.writable,name,data)
      if trace_cache or trace_containers then
        report_containers("action %a, category %a, name %a","save",container.subcategory,name)
      end
      data.unique,data.shared=unique,shared
    end
    if trace_cache or trace_containers then
      report_containers("action %a, category %a, name %a","store",container.subcategory,name)
    end
    container.storage[name]=data
  end
  return data
end
function containers.content(container,name)
  return container.storage[name]
end
function containers.cleanname(name)
  return (gsub(lower(name),"[^%w\128-\255]+","-")) 
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-fonts-nod']={
  version=1.001,
  comment="companion to luatex-fonts.lua",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
if tex.attribute[0]~=0 then
  texio.write_nl("log","!")
  texio.write_nl("log","! Attribute 0 is reserved for ConTeXt's font feature management and has to be")
  texio.write_nl("log","! set to zero. Also, some attributes in the range 1-255 are used for special")
  texio.write_nl("log","! purposes so setting them at the TeX end might break the font handler.")
  texio.write_nl("log","!")
  tex.attribute[0]=0 
end
attributes=attributes or {}
attributes.unsetvalue=-0x7FFFFFFF
local numbers,last={},127
attributes.private=attributes.private or function(name)
  local number=numbers[name]
  if not number then
    if last<255 then
      last=last+1
    end
    number=last
    numbers[name]=number
  end
  return number
end
nodes={}
nodes.pool={}
nodes.handlers={}
local nodecodes={} for k,v in next,node.types  () do nodecodes[string.gsub(v,"_","")]=k end
local whatcodes={} for k,v in next,node.whatsits() do whatcodes[string.gsub(v,"_","")]=k end
local glyphcodes={ [0]="character","glyph","ligature","ghost","left","right" }
local disccodes={ [0]="discretionary","explicit","automatic","regular","first","second" }
nodes.nodecodes=nodecodes
nodes.whatcodes=whatcodes
nodes.whatsitcodes=whatcodes
nodes.glyphcodes=glyphcodes
nodes.disccodes=disccodes
local free_node=node.free
local remove_node=node.remove
local new_node=node.new
local traverse_id=node.traverse_id
nodes.handlers.protectglyphs=node.protect_glyphs
nodes.handlers.unprotectglyphs=node.unprotect_glyphs
local math_code=nodecodes.math
local end_of_math=node.end_of_math
function node.end_of_math(n)
  if n.id==math_code and n.subtype==1 then
    return n
  else
    return end_of_math(n)
  end
end
function nodes.remove(head,current,free_too)
  local t=current
  head,current=remove_node(head,current)
  if t then
    if free_too then
      free_node(t)
      t=nil
    else
      t.next,t.prev=nil,nil
    end
  end
  return head,current,t
end
function nodes.delete(head,current)
  return nodes.remove(head,current,true)
end
function nodes.pool.kern(k)
  local n=new_node("kern",1)
  n.kern=k
  return n
end
local getfield=node.getfield or function(n,tag)    return n[tag] end
local setfield=node.setfield or function(n,tag,value) n[tag]=value end
nodes.getfield=getfield
nodes.setfield=setfield
nodes.getattr=getfield
nodes.setattr=setfield
if node.getid   then nodes.getid=node.getid   else function nodes.getid   (n) return getfield(n,"id")   end end
if node.getsubtype then nodes.getsubtype=node.getsubtype else function nodes.getsubtype(n) return getfield(n,"subtype") end end
if node.getnext  then nodes.getnext=node.getnext  else function nodes.getnext  (n) return getfield(n,"next")  end end
if node.getprev  then nodes.getprev=node.getprev  else function nodes.getprev  (n) return getfield(n,"prev")  end end
if node.getchar  then nodes.getchar=node.getchar  else function nodes.getchar  (n) return getfield(n,"char")  end end
if node.getfont  then nodes.getfont=node.getfont  else function nodes.getfont  (n) return getfield(n,"font")  end end
if node.getlist  then nodes.getlist=node.getlist  else function nodes.getlist  (n) return getfield(n,"list")  end end
function nodes.tonut (n) return n end
function nodes.tonode(n) return n end
nodes.tostring=node.tostring or tostring
nodes.copy=node.copy
nodes.copy_list=node.copy_list
nodes.delete=node.delete
nodes.dimensions=node.dimensions
nodes.end_of_math=node.end_of_math
nodes.flush_list=node.flush_list
nodes.flush_node=node.flush_node
nodes.free=node.free
nodes.insert_after=node.insert_after
nodes.insert_before=node.insert_before
nodes.hpack=node.hpack
nodes.new=node.new
nodes.tail=node.tail
nodes.traverse=node.traverse
nodes.traverse_id=node.traverse_id
nodes.slide=node.slide
nodes.vpack=node.vpack
nodes.first_glyph=node.first_glyph
nodes.first_character=node.first_character
nodes.has_glyph=node.has_glyph or node.first_glyph
nodes.current_attr=node.current_attr
nodes.do_ligature_n=node.do_ligature_n
nodes.has_field=node.has_field
nodes.last_node=node.last_node
nodes.usedlist=node.usedlist
nodes.protrusion_skippable=node.protrusion_skippable
nodes.write=node.write
nodes.has_attribute=node.has_attribute
nodes.set_attribute=node.set_attribute
nodes.unset_attribute=node.unset_attribute
nodes.protect_glyphs=node.protect_glyphs
nodes.unprotect_glyphs=node.unprotect_glyphs
nodes.kerning=node.kerning
nodes.ligaturing=node.ligaturing
nodes.mlist_to_hlist=node.mlist_to_hlist
nodes.nuts=nodes

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-ini']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local allocate=utilities.storage.allocate
local report_defining=logs.reporter("fonts","defining")
fonts=fonts or {}
local fonts=fonts
fonts.hashes={ identifiers=allocate() }
fonts.tables=fonts.tables   or {}
fonts.helpers=fonts.helpers  or {}
fonts.tracers=fonts.tracers  or {} 
fonts.specifiers=fonts.specifiers or {} 
fonts.analyzers={} 
fonts.readers={}
fonts.definers={ methods={} }
fonts.loggers={ register=function() end }
fontloader.totable=fontloader.to_table

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-con']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,tostring,rawget=next,tostring,rawget
local format,match,lower,gsub=string.format,string.match,string.lower,string.gsub
local utfbyte=utf.byte
local sort,insert,concat,sortedkeys,serialize,fastcopy=table.sort,table.insert,table.concat,table.sortedkeys,table.serialize,table.fastcopy
local derivetable=table.derive
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local trace_scaling=false trackers.register("fonts.scaling",function(v) trace_scaling=v end)
local report_defining=logs.reporter("fonts","defining")
local fonts=fonts
local constructors=fonts.constructors or {}
fonts.constructors=constructors
local handlers=fonts.handlers or {} 
fonts.handlers=handlers
local allocate=utilities.storage.allocate
local setmetatableindex=table.setmetatableindex
constructors.dontembed=allocate()
constructors.autocleanup=true
constructors.namemode="fullpath" 
constructors.version=1.01
constructors.cache=containers.define("fonts","constructors",constructors.version,false)
constructors.privateoffset=0xF0000
constructors.keys={
  properties={
    encodingbytes="number",
    embedding="number",
    cidinfo={},
    format="string",
    fontname="string",
    fullname="string",
    filename="filename",
    psname="string",
    name="string",
    virtualized="boolean",
    hasitalics="boolean",
    autoitalicamount="basepoints",
    nostackmath="boolean",
    noglyphnames="boolean",
    mode="string",
    hasmath="boolean",
    mathitalics="boolean",
    textitalics="boolean",
    finalized="boolean",
  },
  parameters={
    mathsize="number",
    scriptpercentage="float",
    scriptscriptpercentage="float",
    units="cardinal",
    designsize="scaledpoints",
    expansion={
                  stretch="integerscale",
                  shrink="integerscale",
                  step="integerscale",
                  auto="boolean",
                 },
    protrusion={
                  auto="boolean",
                 },
    slantfactor="float",
    extendfactor="float",
    factor="float",
    hfactor="float",
    vfactor="float",
    size="scaledpoints",
    units="scaledpoints",
    scaledpoints="scaledpoints",
    slantperpoint="scaledpoints",
    spacing={
                  width="scaledpoints",
                  stretch="scaledpoints",
                  shrink="scaledpoints",
                  extra="scaledpoints",
                 },
    xheight="scaledpoints",
    quad="scaledpoints",
    ascender="scaledpoints",
    descender="scaledpoints",
    synonyms={
                  space="spacing.width",
                  spacestretch="spacing.stretch",
                  spaceshrink="spacing.shrink",
                  extraspace="spacing.extra",
                  x_height="xheight",
                  space_stretch="spacing.stretch",
                  space_shrink="spacing.shrink",
                  extra_space="spacing.extra",
                  em="quad",
                  ex="xheight",
                  slant="slantperpoint",
                 },
  },
  description={
    width="basepoints",
    height="basepoints",
    depth="basepoints",
    boundingbox={},
  },
  character={
    width="scaledpoints",
    height="scaledpoints",
    depth="scaledpoints",
    italic="scaledpoints",
  },
}
local designsizes=allocate()
constructors.designsizes=designsizes
local loadedfonts=allocate()
constructors.loadedfonts=loadedfonts
local factors={
  pt=65536.0,
  bp=65781.8,
}
function constructors.setfactor(f)
  constructors.factor=factors[f or 'pt'] or factors.pt
end
constructors.setfactor()
function constructors.scaled(scaledpoints,designsize) 
  if scaledpoints<0 then
    if designsize then
      local factor=constructors.factor
      if designsize>factor then 
        return (- scaledpoints/1000)*designsize 
      else
        return (- scaledpoints/1000)*designsize*factor
      end
    else
      return (- scaledpoints/1000)*10*factor
    end
  else
    return scaledpoints
  end
end
function constructors.cleanuptable(tfmdata)
  if constructors.autocleanup and tfmdata.properties.virtualized then
    for k,v in next,tfmdata.characters do
      if v.commands then v.commands=nil end
    end
  end
end
function constructors.calculatescale(tfmdata,scaledpoints)
  local parameters=tfmdata.parameters
  if scaledpoints<0 then
    scaledpoints=(- scaledpoints/1000)*(tfmdata.designsize or parameters.designsize) 
  end
  return scaledpoints,scaledpoints/(parameters.units or 1000) 
end
local unscaled={
  ScriptPercentScaleDown=true,
  ScriptScriptPercentScaleDown=true,
  RadicalDegreeBottomRaisePercent=true
}
function constructors.assignmathparameters(target,original)
  local mathparameters=original.mathparameters
  if mathparameters and next(mathparameters) then
    local targetparameters=target.parameters
    local targetproperties=target.properties
    local targetmathparameters={}
    local factor=targetproperties.math_is_scaled and 1 or targetparameters.factor
    for name,value in next,mathparameters do
      if unscaled[name] then
        targetmathparameters[name]=value
      else
        targetmathparameters[name]=value*factor
      end
    end
    if not targetmathparameters.FractionDelimiterSize then
      targetmathparameters.FractionDelimiterSize=1.01*targetparameters.size
    end
    if not mathparameters.FractionDelimiterDisplayStyleSize then
      targetmathparameters.FractionDelimiterDisplayStyleSize=2.40*targetparameters.size
    end
    target.mathparameters=targetmathparameters
  end
end
function constructors.beforecopyingcharacters(target,original)
end
function constructors.aftercopyingcharacters(target,original)
end
constructors.sharefonts=false
constructors.nofsharedfonts=0
local sharednames={}
function constructors.trytosharefont(target,tfmdata)
  if constructors.sharefonts then 
    local characters=target.characters
    local n=1
    local t={ target.psname }
    local u=sortedkeys(characters)
    for i=1,#u do
      local k=u[i]
      n=n+1;t[n]=k
      n=n+1;t[n]=characters[k].index or k
    end
    local h=md5.HEX(concat(t," "))
    local s=sharednames[h]
    if s then
      if trace_defining then
        report_defining("font %a uses backend resources of font %a",target.fullname,s)
      end
      target.fullname=s
      constructors.nofsharedfonts=constructors.nofsharedfonts+1
      target.properties.sharedwith=s
    else
      sharednames[h]=target.fullname
    end
  end
end
function constructors.enhanceparameters(parameters)
  local xheight=parameters.x_height
  local quad=parameters.quad
  local space=parameters.space
  local stretch=parameters.space_stretch
  local shrink=parameters.space_shrink
  local extra=parameters.extra_space
  local slant=parameters.slant
  parameters.xheight=xheight
  parameters.spacestretch=stretch
  parameters.spaceshrink=shrink
  parameters.extraspace=extra
  parameters.em=quad
  parameters.ex=xheight
  parameters.slantperpoint=slant
  parameters.spacing={
    width=space,
    stretch=stretch,
    shrink=shrink,
    extra=extra,
  }
end
function constructors.scale(tfmdata,specification)
  local target={}
  if tonumber(specification) then
    specification={ size=specification }
  end
  target.specification=specification
  local scaledpoints=specification.size
  local relativeid=specification.relativeid
  local properties=tfmdata.properties   or {}
  local goodies=tfmdata.goodies    or {}
  local resources=tfmdata.resources   or {}
  local descriptions=tfmdata.descriptions  or {} 
  local characters=tfmdata.characters   or {} 
  local changed=tfmdata.changed    or {} 
  local shared=tfmdata.shared     or {}
  local parameters=tfmdata.parameters   or {}
  local mathparameters=tfmdata.mathparameters or {}
  local targetcharacters={}
  local targetdescriptions=derivetable(descriptions)
  local targetparameters=derivetable(parameters)
  local targetproperties=derivetable(properties)
  local targetgoodies=goodies            
  target.characters=targetcharacters
  target.descriptions=targetdescriptions
  target.parameters=targetparameters
  target.properties=targetproperties
  target.goodies=targetgoodies
  target.shared=shared
  target.resources=resources
  target.unscaled=tfmdata
  local mathsize=tonumber(specification.mathsize) or 0
  local textsize=tonumber(specification.textsize) or scaledpoints
  local forcedsize=tonumber(parameters.mathsize  ) or 0
  local extrafactor=tonumber(specification.factor ) or 1
  if (mathsize==2 or forcedsize==2) and parameters.scriptpercentage then
    scaledpoints=parameters.scriptpercentage*textsize/100
  elseif (mathsize==3 or forcedsize==3) and parameters.scriptscriptpercentage then
    scaledpoints=parameters.scriptscriptpercentage*textsize/100
  elseif forcedsize>1000 then 
    scaledpoints=forcedsize
  end
  targetparameters.mathsize=mathsize  
  targetparameters.textsize=textsize  
  targetparameters.forcedsize=forcedsize 
  targetparameters.extrafactor=extrafactor
  local tounicode=resources.tounicode
  local defaultwidth=resources.defaultwidth or 0
  local defaultheight=resources.defaultheight or 0
  local defaultdepth=resources.defaultdepth or 0
  local units=parameters.units or 1000
  if target.fonts then
    target.fonts=fastcopy(target.fonts) 
  end
  targetproperties.language=properties.language or "dflt" 
  targetproperties.script=properties.script  or "dflt" 
  targetproperties.mode=properties.mode   or "base"
  local askedscaledpoints=scaledpoints
  local scaledpoints,delta=constructors.calculatescale(tfmdata,scaledpoints,nil,specification)
  local hdelta=delta
  local vdelta=delta
  target.designsize=parameters.designsize 
  target.units_per_em=units
  local direction=properties.direction or tfmdata.direction or 0 
  target.direction=direction
  properties.direction=direction
  target.size=scaledpoints
  target.encodingbytes=properties.encodingbytes or 1
  target.embedding=properties.embedding or "subset"
  target.tounicode=1
  target.cidinfo=properties.cidinfo
  target.format=properties.format
  local fontname=properties.fontname or tfmdata.fontname 
  local fullname=properties.fullname or tfmdata.fullname 
  local filename=properties.filename or tfmdata.filename 
  local psname=properties.psname  or tfmdata.psname  
  local name=properties.name   or tfmdata.name
  if not psname or psname=="" then
    psname=fontname or (fullname and fonts.names.cleanname(fullname))
  end
  target.fontname=fontname
  target.fullname=fullname
  target.filename=filename
  target.psname=psname
  target.name=name
  properties.fontname=fontname
  properties.fullname=fullname
  properties.filename=filename
  properties.psname=psname
  properties.name=name
  local expansion=parameters.expansion
  if expansion then
    target.stretch=expansion.stretch
    target.shrink=expansion.shrink
    target.step=expansion.step
    target.auto_expand=expansion.auto
  end
  local protrusion=parameters.protrusion
  if protrusion then
    target.auto_protrude=protrusion.auto
  end
  local extendfactor=parameters.extendfactor or 0
  if extendfactor~=0 and extendfactor~=1 then
    hdelta=hdelta*extendfactor
    target.extend=extendfactor*1000 
  else
    target.extend=1000 
  end
  local slantfactor=parameters.slantfactor or 0
  if slantfactor~=0 then
    target.slant=slantfactor*1000
  else
    target.slant=0
  end
  targetparameters.factor=delta
  targetparameters.hfactor=hdelta
  targetparameters.vfactor=vdelta
  targetparameters.size=scaledpoints
  targetparameters.units=units
  targetparameters.scaledpoints=askedscaledpoints
  local isvirtual=properties.virtualized or tfmdata.type=="virtual"
  local hasquality=target.auto_expand or target.auto_protrude
  local hasitalics=properties.hasitalics
  local autoitalicamount=properties.autoitalicamount
  local stackmath=not properties.nostackmath
  local nonames=properties.noglyphnames
  local nodemode=properties.mode=="node"
  if changed and not next(changed) then
    changed=false
  end
  target.type=isvirtual and "virtual" or "real"
  target.postprocessors=tfmdata.postprocessors
  local targetslant=(parameters.slant     or parameters[1] or 0)*factors.pt 
  local targetspace=(parameters.space     or parameters[2] or 0)*hdelta
  local targetspace_stretch=(parameters.space_stretch or parameters[3] or 0)*hdelta
  local targetspace_shrink=(parameters.space_shrink or parameters[4] or 0)*hdelta
  local targetx_height=(parameters.x_height   or parameters[5] or 0)*vdelta
  local targetquad=(parameters.quad     or parameters[6] or 0)*hdelta
  local targetextra_space=(parameters.extra_space  or parameters[7] or 0)*hdelta
  targetparameters.slant=targetslant 
  targetparameters.space=targetspace
  targetparameters.space_stretch=targetspace_stretch
  targetparameters.space_shrink=targetspace_shrink
  targetparameters.x_height=targetx_height
  targetparameters.quad=targetquad
  targetparameters.extra_space=targetextra_space
  local ascender=parameters.ascender
  if ascender then
    targetparameters.ascender=delta*ascender
  end
  local descender=parameters.descender
  if descender then
    targetparameters.descender=delta*descender
  end
  constructors.enhanceparameters(targetparameters)
  local protrusionfactor=(targetquad~=0 and 1000/targetquad) or 0
  local scaledwidth=defaultwidth*hdelta
  local scaledheight=defaultheight*vdelta
  local scaleddepth=defaultdepth*vdelta
  local hasmath=(properties.hasmath or next(mathparameters)) and true
  if hasmath then
    constructors.assignmathparameters(target,tfmdata) 
    properties.hasmath=true
    target.nomath=false
    target.MathConstants=target.mathparameters
  else
    properties.hasmath=false
    target.nomath=true
    target.mathparameters=nil 
  end
  local italickey="italic"
  local useitalics=true
  if hasmath then
    autoitalicamount=false 
  elseif properties.textitalics then
    italickey="italic_correction"
    useitalics=false
    if properties.delaytextitalics then
      autoitalicamount=false
    end
  end
  if trace_defining then
    report_defining("defining tfm, name %a, fullname %a, filename %a, hscale %a, vscale %a, math %a, italics %a",
      name,fullname,filename,hdelta,vdelta,
      hasmath and "enabled" or "disabled",useitalics and "enabled" or "disabled")
  end
  constructors.beforecopyingcharacters(target,tfmdata)
  local sharedkerns={}
  for unicode,character in next,characters do
    local chr,description,index,touni
    if changed then
      local c=changed[unicode]
      if c then
        local ligatures=character.ligatures 
        description=descriptions[c] or descriptions[unicode] or character
        character=characters[c] or character
        index=description.index or c
        if tounicode then
          touni=tounicode[index] 
          if not touni then 
            local d=descriptions[unicode] or characters[unicode]
            local i=d.index or unicode
            touni=tounicode[i] 
          end
        end
        if ligatures and not character.ligatures then
          character.ligatures=ligatures 
        end
      else
        description=descriptions[unicode] or character
        index=description.index or unicode
        if tounicode then
          touni=tounicode[index] 
        end
      end
    else
      description=descriptions[unicode] or character
      index=description.index or unicode
      if tounicode then
        touni=tounicode[index] 
      end
    end
    local width=description.width
    local height=description.height
    local depth=description.depth
    if width then width=hdelta*width else width=scaledwidth end
    if height then height=vdelta*height else height=scaledheight end
    if depth and depth~=0 then
      depth=delta*depth
      if nonames then
        chr={
          index=index,
          height=height,
          depth=depth,
          width=width,
        }
      else
        chr={
          name=description.name,
          index=index,
          height=height,
          depth=depth,
          width=width,
        }
      end
    else
      if nonames then
        chr={
          index=index,
          height=height,
          width=width,
        }
      else
        chr={
          name=description.name,
          index=index,
          height=height,
          width=width,
        }
      end
    end
    if touni then
      chr.tounicode=touni
    end
    if hasquality then
      local ve=character.expansion_factor
      if ve then
        chr.expansion_factor=ve*1000 
      end
      local vl=character.left_protruding
      if vl then
        chr.left_protruding=protrusionfactor*width*vl
      end
      local vr=character.right_protruding
      if vr then
        chr.right_protruding=protrusionfactor*width*vr
      end
    end
    if autoitalicamount then
      local vi=description.italic
      if not vi then
        local vi=description.boundingbox[3]-description.width+autoitalicamount
        if vi>0 then 
          chr[italickey]=vi*hdelta
        end
      elseif vi~=0 then
        chr[italickey]=vi*hdelta
      end
    elseif hasitalics then
      local vi=description.italic
      if vi and vi~=0 then
        chr[italickey]=vi*hdelta
      end
    end
    if hasmath then
      local vn=character.next
      if vn then
        chr.next=vn
      else
        local vv=character.vert_variants
        if vv then
          local t={}
          for i=1,#vv do
            local vvi=vv[i]
            t[i]={
              ["start"]=(vvi["start"]  or 0)*vdelta,
              ["end"]=(vvi["end"]   or 0)*vdelta,
              ["advance"]=(vvi["advance"] or 0)*vdelta,
              ["extender"]=vvi["extender"],
              ["glyph"]=vvi["glyph"],
            }
          end
          chr.vert_variants=t
        else
          local hv=character.horiz_variants
          if hv then
            local t={}
            for i=1,#hv do
              local hvi=hv[i]
              t[i]={
                ["start"]=(hvi["start"]  or 0)*hdelta,
                ["end"]=(hvi["end"]   or 0)*hdelta,
                ["advance"]=(hvi["advance"] or 0)*hdelta,
                ["extender"]=hvi["extender"],
                ["glyph"]=hvi["glyph"],
              }
            end
            chr.horiz_variants=t
          end
        end
      end
      local va=character.top_accent
      if va then
        chr.top_accent=vdelta*va
      end
      if stackmath then
        local mk=character.mathkerns 
        if mk then
          local kerns={}
          local v=mk.top_right  if v then local k={} for i=1,#v do local vi=v[i]
            k[i]={ height=vdelta*vi.height,kern=vdelta*vi.kern }
          end   kerns.top_right=k end
          local v=mk.top_left   if v then local k={} for i=1,#v do local vi=v[i]
            k[i]={ height=vdelta*vi.height,kern=vdelta*vi.kern }
          end   kerns.top_left=k end
          local v=mk.bottom_left if v then local k={} for i=1,#v do local vi=v[i]
            k[i]={ height=vdelta*vi.height,kern=vdelta*vi.kern }
          end   kerns.bottom_left=k end
          local v=mk.bottom_right if v then local k={} for i=1,#v do local vi=v[i]
            k[i]={ height=vdelta*vi.height,kern=vdelta*vi.kern }
          end   kerns.bottom_right=k end
          chr.mathkern=kerns 
        end
      end
    end
    if not nodemode then
      local vk=character.kerns
      if vk then
        local s=sharedkerns[vk]
        if not s then
          s={}
          for k,v in next,vk do s[k]=v*hdelta end
          sharedkerns[vk]=s
        end
        chr.kerns=s
      end
      local vl=character.ligatures
      if vl then
        if true then
          chr.ligatures=vl 
        else
          local tt={}
          for i,l in next,vl do
            tt[i]=l
          end
          chr.ligatures=tt
        end
      end
    end
    if isvirtual then
      local vc=character.commands
      if vc then
        local ok=false
        for i=1,#vc do
          local key=vc[i][1]
          if key=="right" or key=="down" then
            ok=true
            break
          end
        end
        if ok then
          local tt={}
          for i=1,#vc do
            local ivc=vc[i]
            local key=ivc[1]
            if key=="right" then
              tt[i]={ key,ivc[2]*hdelta }
            elseif key=="down" then
              tt[i]={ key,ivc[2]*vdelta }
            elseif key=="rule" then
              tt[i]={ key,ivc[2]*vdelta,ivc[3]*hdelta }
            else 
              tt[i]=ivc 
            end
          end
          chr.commands=tt
        else
          chr.commands=vc
        end
        chr.index=nil
      end
    end
    targetcharacters[unicode]=chr
  end
  constructors.aftercopyingcharacters(target,tfmdata)
  constructors.trytosharefont(target,tfmdata)
  return target
end
function constructors.finalize(tfmdata)
  if tfmdata.properties and tfmdata.properties.finalized then
    return
  end
  if not tfmdata.characters then
    return nil
  end
  if not tfmdata.goodies then
    tfmdata.goodies={} 
  end
  local parameters=tfmdata.parameters
  if not parameters then
    return nil
  end
  if not parameters.expansion then
    parameters.expansion={
      stretch=tfmdata.stretch   or 0,
      shrink=tfmdata.shrink   or 0,
      step=tfmdata.step    or 0,
      auto=tfmdata.auto_expand or false,
    }
  end
  if not parameters.protrusion then
    parameters.protrusion={
      auto=auto_protrude
    }
  end
  if not parameters.size then
    parameters.size=tfmdata.size
  end
  if not parameters.extendfactor then
    parameters.extendfactor=tfmdata.extend or 0
  end
  if not parameters.slantfactor then
    parameters.slantfactor=tfmdata.slant or 0
  end
  if not parameters.designsize then
    parameters.designsize=tfmdata.designsize or (factors.pt*10)
  end
  if not parameters.units then
    parameters.units=tfmdata.units_per_em or 1000
  end
  if not tfmdata.descriptions then
    local descriptions={} 
    setmetatableindex(descriptions,function(t,k) local v={} t[k]=v return v end)
    tfmdata.descriptions=descriptions
  end
  local properties=tfmdata.properties
  if not properties then
    properties={}
    tfmdata.properties=properties
  end
  if not properties.virtualized then
    properties.virtualized=tfmdata.type=="virtual"
  end
  if not tfmdata.properties then
    tfmdata.properties={
      fontname=tfmdata.fontname,
      filename=tfmdata.filename,
      fullname=tfmdata.fullname,
      name=tfmdata.name,
      psname=tfmdata.psname,
      encodingbytes=tfmdata.encodingbytes or 1,
      embedding=tfmdata.embedding   or "subset",
      tounicode=tfmdata.tounicode   or 1,
      cidinfo=tfmdata.cidinfo    or nil,
      format=tfmdata.format    or "type1",
      direction=tfmdata.direction   or 0,
    }
  end
  if not tfmdata.resources then
    tfmdata.resources={}
  end
  if not tfmdata.shared then
    tfmdata.shared={}
  end
  if not properties.hasmath then
    properties.hasmath=not tfmdata.nomath
  end
  tfmdata.MathConstants=nil
  tfmdata.postprocessors=nil
  tfmdata.fontname=nil
  tfmdata.filename=nil
  tfmdata.fullname=nil
  tfmdata.name=nil 
  tfmdata.psname=nil
  tfmdata.encodingbytes=nil
  tfmdata.embedding=nil
  tfmdata.tounicode=nil
  tfmdata.cidinfo=nil
  tfmdata.format=nil
  tfmdata.direction=nil
  tfmdata.type=nil
  tfmdata.nomath=nil
  tfmdata.designsize=nil
  tfmdata.size=nil
  tfmdata.stretch=nil
  tfmdata.shrink=nil
  tfmdata.step=nil
  tfmdata.auto_expand=nil
  tfmdata.auto_protrude=nil
  tfmdata.extend=nil
  tfmdata.slant=nil
  tfmdata.units_per_em=nil
  properties.finalized=true
  return tfmdata
end
local hashmethods={}
constructors.hashmethods=hashmethods
function constructors.hashfeatures(specification) 
  local features=specification.features
  if features then
    local t,tn={},0
    for category,list in next,features do
      if next(list) then
        local hasher=hashmethods[category]
        if hasher then
          local hash=hasher(list)
          if hash then
            tn=tn+1
            t[tn]=category..":"..hash
          end
        end
      end
    end
    if tn>0 then
      return concat(t," & ")
    end
  end
  return "unknown"
end
hashmethods.normal=function(list)
  local s={}
  local n=0
  for k,v in next,list do
    if not k then
    elseif k=="number" or k=="features" then
    else
      n=n+1
      s[n]=k
    end
  end
  if n>0 then
    sort(s)
    for i=1,n do
      local k=s[i]
      s[i]=k..'='..tostring(list[k])
    end
    return concat(s,"+")
  end
end
function constructors.hashinstance(specification,force)
  local hash,size,fallbacks=specification.hash,specification.size,specification.fallbacks
  if force or not hash then
    hash=constructors.hashfeatures(specification)
    specification.hash=hash
  end
  if size<1000 and designsizes[hash] then
    size=math.round(constructors.scaled(size,designsizes[hash]))
    specification.size=size
  end
  if fallbacks then
    return hash..' @ '..tostring(size)..' @ '..fallbacks
  else
    return hash..' @ '..tostring(size)
  end
end
function constructors.setname(tfmdata,specification) 
  if constructors.namemode=="specification" then
    local specname=specification.specification
    if specname then
      tfmdata.properties.name=specname
      if trace_defining then
        report_otf("overloaded fontname %a",specname)
      end
    end
  end
end
function constructors.checkedfilename(data)
  local foundfilename=data.foundfilename
  if not foundfilename then
    local askedfilename=data.filename or ""
    if askedfilename~="" then
      askedfilename=resolvers.resolve(askedfilename) 
      foundfilename=resolvers.findbinfile(askedfilename,"") or ""
      if foundfilename=="" then
        report_defining("source file %a is not found",askedfilename)
        foundfilename=resolvers.findbinfile(file.basename(askedfilename),"") or ""
        if foundfilename~="" then
          report_defining("using source file %a due to cache mismatch",foundfilename)
        end
      end
    end
    data.foundfilename=foundfilename
  end
  return foundfilename
end
local formats=allocate()
fonts.formats=formats
setmetatableindex(formats,function(t,k)
  local l=lower(k)
  if rawget(t,k) then
    t[k]=l
    return l
  end
  return rawget(t,file.suffix(l))
end)
local locations={}
local function setindeed(mode,target,group,name,action,position)
  local t=target[mode]
  if not t then
    report_defining("fatal error in setting feature %a, group %a, mode %a",name,group,mode)
    os.exit()
  elseif position then
    insert(t,position,{ name=name,action=action })
  else
    for i=1,#t do
      local ti=t[i]
      if ti.name==name then
        ti.action=action
        return
      end
    end
    insert(t,{ name=name,action=action })
  end
end
local function set(group,name,target,source)
  target=target[group]
  if not target then
    report_defining("fatal target error in setting feature %a, group %a",name,group)
    os.exit()
  end
  local source=source[group]
  if not source then
    report_defining("fatal source error in setting feature %a, group %a",name,group)
    os.exit()
  end
  local node=source.node
  local base=source.base
  local position=source.position
  if node then
    setindeed("node",target,group,name,node,position)
  end
  if base then
    setindeed("base",target,group,name,base,position)
  end
end
local function register(where,specification)
  local name=specification.name
  if name and name~="" then
    local default=specification.default
    local description=specification.description
    local initializers=specification.initializers
    local processors=specification.processors
    local manipulators=specification.manipulators
    local modechecker=specification.modechecker
    if default then
      where.defaults[name]=default
    end
    if description and description~="" then
      where.descriptions[name]=description
    end
    if initializers then
      set('initializers',name,where,specification)
    end
    if processors then
      set('processors',name,where,specification)
    end
    if manipulators then
      set('manipulators',name,where,specification)
    end
    if modechecker then
      where.modechecker=modechecker
    end
  end
end
constructors.registerfeature=register
function constructors.getfeatureaction(what,where,mode,name)
  what=handlers[what].features
  if what then
    where=what[where]
    if where then
      mode=where[mode]
      if mode then
        for i=1,#mode do
          local m=mode[i]
          if m.name==name then
            return m.action
          end
        end
      end
    end
  end
end
function constructors.newhandler(what) 
  local handler=handlers[what]
  if not handler then
    handler={}
    handlers[what]=handler
  end
  return handler
end
function constructors.newfeatures(what) 
  local handler=handlers[what]
  local features=handler.features
  if not features then
    local tables=handler.tables   
    local statistics=handler.statistics 
    features=allocate {
      defaults={},
      descriptions=tables and tables.features or {},
      used=statistics and statistics.usedfeatures or {},
      initializers={ base={},node={} },
      processors={ base={},node={} },
      manipulators={ base={},node={} },
    }
    features.register=function(specification) return register(features,specification) end
    handler.features=features 
  end
  return features
end
function constructors.checkedfeatures(what,features)
  local defaults=handlers[what].features.defaults
  if features and next(features) then
    features=fastcopy(features) 
    for key,value in next,defaults do
      if features[key]==nil then
        features[key]=value
      end
    end
    return features
  else
    return fastcopy(defaults) 
  end
end
function constructors.initializefeatures(what,tfmdata,features,trace,report)
  if features and next(features) then
    local properties=tfmdata.properties or {} 
    local whathandler=handlers[what]
    local whatfeatures=whathandler.features
    local whatinitializers=whatfeatures.initializers
    local whatmodechecker=whatfeatures.modechecker
    local mode=properties.mode or (whatmodechecker and whatmodechecker(tfmdata,features,features.mode)) or features.mode or "base"
    properties.mode=mode 
    features.mode=mode
    local done={}
    while true do
      local redo=false
      local initializers=whatfeatures.initializers[mode]
      if initializers then
        for i=1,#initializers do
          local step=initializers[i]
          local feature=step.name
          local value=features[feature]
          if not value then
          elseif done[feature] then
          else
            local action=step.action
            if trace then
              report("initializing feature %a to %a for mode %a for font %a",feature,
                value,mode,tfmdata.properties.fullname)
            end
            action(tfmdata,value,features) 
            if mode~=properties.mode or mode~=features.mode then
              if whatmodechecker then
                properties.mode=whatmodechecker(tfmdata,features,properties.mode) 
                features.mode=properties.mode
              end
              if mode~=properties.mode then
                mode=properties.mode
                redo=true
              end
            end
            done[feature]=true
          end
          if redo then
            break
          end
        end
        if not redo then
          break
        end
      else
        break
      end
    end
    properties.mode=mode 
    return true
  else
    return false
  end
end
function constructors.collectprocessors(what,tfmdata,features,trace,report)
  local processes,nofprocesses={},0
  if features and next(features) then
    local properties=tfmdata.properties
    local whathandler=handlers[what]
    local whatfeatures=whathandler.features
    local whatprocessors=whatfeatures.processors
    local mode=properties.mode
    local processors=whatprocessors[mode]
    if processors then
      for i=1,#processors do
        local step=processors[i]
        local feature=step.name
        if features[feature] then
          local action=step.action
          if trace then
            report("installing feature processor %a for mode %a for font %a",feature,mode,tfmdata.properties.fullname)
          end
          if action then
            nofprocesses=nofprocesses+1
            processes[nofprocesses]=action
          end
        end
      end
    elseif trace then
      report("no feature processors for mode %a for font %a",mode,properties.fullname)
    end
  end
  return processes
end
function constructors.applymanipulators(what,tfmdata,features,trace,report)
  if features and next(features) then
    local properties=tfmdata.properties
    local whathandler=handlers[what]
    local whatfeatures=whathandler.features
    local whatmanipulators=whatfeatures.manipulators
    local mode=properties.mode
    local manipulators=whatmanipulators[mode]
    if manipulators then
      for i=1,#manipulators do
        local step=manipulators[i]
        local feature=step.name
        local value=features[feature]
        if value then
          local action=step.action
          if trace then
            report("applying feature manipulator %a for mode %a for font %a",feature,mode,properties.fullname)
          end
          if action then
            action(tfmdata,feature,value)
          end
        end
      end
    end
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-font-enc']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
fonts.encodings={}
fonts.encodings.agl={}
fonts.encodings.known={}
setmetatable(fonts.encodings.agl,{ __index=function(t,k)
  if k=="unicodes" then
    texio.write(" <loading (extended) adobe glyph list>")
    local unicodes=dofile(resolvers.findfile("font-age.lua"))
    fonts.encodings.agl={ unicodes=unicodes }
    return unicodes
  else
    return nil
  end
end })

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-cid']={
  version=1.001,
  comment="companion to font-otf.lua (cidmaps)",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local format,match,lower=string.format,string.match,string.lower
local tonumber=tonumber
local P,S,R,C,V,lpegmatch=lpeg.P,lpeg.S,lpeg.R,lpeg.C,lpeg.V,lpeg.match
local fonts,logs,trackers=fonts,logs,trackers
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
local report_otf=logs.reporter("fonts","otf loading")
local cid={}
fonts.cid=cid
local cidmap={}
local cidmax=10
local number=C(R("09","af","AF")^1)
local space=S(" \n\r\t")
local spaces=space^0
local period=P(".")
local periods=period*period
local name=P("/")*C((1-space)^1)
local unicodes,names={},{} 
local function do_one(a,b)
  unicodes[tonumber(a)]=tonumber(b,16)
end
local function do_range(a,b,c)
  c=tonumber(c,16)
  for i=tonumber(a),tonumber(b) do
    unicodes[i]=c
    c=c+1
  end
end
local function do_name(a,b)
  names[tonumber(a)]=b
end
local grammar=P { "start",
  start=number*spaces*number*V("series"),
  series=(spaces*(V("one")+V("range")+V("named")))^1,
  one=(number*spaces*number)/do_one,
  range=(number*periods*number*spaces*number)/do_range,
  named=(number*spaces*name)/do_name
}
local function loadcidfile(filename)
  local data=io.loaddata(filename)
  if data then
    unicodes,names={},{}
    lpegmatch(grammar,data)
    local supplement,registry,ordering=match(filename,"^(.-)%-(.-)%-()%.(.-)$")
    return {
      supplement=supplement,
      registry=registry,
      ordering=ordering,
      filename=filename,
      unicodes=unicodes,
      names=names
    }
  end
end
cid.loadfile=loadcidfile 
local template="%s-%s-%s.cidmap"
local function locate(registry,ordering,supplement)
  local filename=format(template,registry,ordering,supplement)
  local hashname=lower(filename)
  local found=cidmap[hashname]
  if not found then
    if trace_loading then
      report_otf("checking cidmap, registry %a, ordering %a, supplement %a, filename %a",registry,ordering,supplement,filename)
    end
    local fullname=resolvers.findfile(filename,'cid') or ""
    if fullname~="" then
      found=loadcidfile(fullname)
      if found then
        if trace_loading then
          report_otf("using cidmap file %a",filename)
        end
        cidmap[hashname]=found
        found.usedname=file.basename(filename)
      end
    end
  end
  return found
end
function cid.getmap(specification)
  if not specification then
    report_otf("invalid cidinfo specification, table expected")
    return
  end
  local registry=specification.registry
  local ordering=specification.ordering
  local supplement=specification.supplement
  local filename=format(registry,ordering,supplement)
  local found=cidmap[lower(filename)]
  if found then
    return found
  end
  if trace_loading then
    report_otf("cidmap needed, registry %a, ordering %a, supplement %a",registry,ordering,supplement)
  end
  found=locate(registry,ordering,supplement)
  if not found then
    local supnum=tonumber(supplement)
    local cidnum=nil
    if supnum<cidmax then
      for s=supnum+1,cidmax do
        local c=locate(registry,ordering,s)
        if c then
          found,cidnum=c,s
          break
        end
      end
    end
    if not found and supnum>0 then
      for s=supnum-1,0,-1 do
        local c=locate(registry,ordering,s)
        if c then
          found,cidnum=c,s
          break
        end
      end
    end
    registry=lower(registry)
    ordering=lower(ordering)
    if found and cidnum>0 then
      for s=0,cidnum-1 do
        local filename=format(template,registry,ordering,s)
        if not cidmap[filename] then
          cidmap[filename]=found
        end
      end
    end
  end
  return found
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-map']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local tonumber=tonumber
local match,format,find,concat,gsub,lower=string.match,string.format,string.find,table.concat,string.gsub,string.lower
local P,R,S,C,Ct,Cc,lpegmatch=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Ct,lpeg.Cc,lpeg.match
local utfbyte=utf.byte
local floor=math.floor
local trace_loading=false trackers.register("fonts.loading",function(v) trace_loading=v end)
local trace_mapping=false trackers.register("fonts.mapping",function(v) trace_unimapping=v end)
local report_fonts=logs.reporter("fonts","loading") 
local fonts=fonts or {}
local mappings=fonts.mappings or {}
fonts.mappings=mappings
local function loadlumtable(filename) 
  local lumname=file.replacesuffix(file.basename(filename),"lum")
  local lumfile=resolvers.findfile(lumname,"map") or ""
  if lumfile~="" and lfs.isfile(lumfile) then
    if trace_loading or trace_mapping then
      report_fonts("loading map table %a",lumfile)
    end
    lumunic=dofile(lumfile)
    return lumunic,lumfile
  end
end
local hex=R("AF","09")
local hexfour=(hex*hex*hex*hex)/function(s) return tonumber(s,16) end
local hexsix=(hex*hex*hex*hex*hex*hex)/function(s) return tonumber(s,16) end
local dec=(R("09")^1)/tonumber
local period=P(".")
local unicode=P("uni")*(hexfour*(period+P(-1))*Cc(false)+Ct(hexfour^1)*Cc(true))
local ucode=P("u")*(hexsix*(period+P(-1))*Cc(false)+Ct(hexsix^1)*Cc(true))
local index=P("index")*dec*Cc(false)
local parser=unicode+ucode+index
local parsers={}
local function makenameparser(str)
  if not str or str=="" then
    return parser
  else
    local p=parsers[str]
    if not p then
      p=P(str)*period*dec*Cc(false)
      parsers[str]=p
    end
    return p
  end
end
local function tounicode16(unicode,name)
  if unicode<0x10000 then
    return format("%04X",unicode)
  elseif unicode<0x1FFFFFFFFF then
    return format("%04X%04X",floor(unicode/1024),unicode%1024+0xDC00)
  else
    report_fonts("can't convert %a in %a into tounicode",unicode,name)
  end
end
local function tounicode16sequence(unicodes,name)
  local t={}
  for l=1,#unicodes do
    local unicode=unicodes[l]
    if unicode<0x10000 then
      t[l]=format("%04X",unicode)
    elseif unicode<0x1FFFFFFFFF then
      t[l]=format("%04X%04X",floor(unicode/1024),unicode%1024+0xDC00)
    else
      report_fonts ("can't convert %a in %a into tounicode",unicode,name)
    end
  end
  return concat(t)
end
local function fromunicode16(str)
  if #str==4 then
    return tonumber(str,16)
  else
    local l,r=match(str,"(....)(....)")
    return (tonumber(l,16))*0x400+tonumber(r,16)-0xDC00
  end
end
mappings.loadlumtable=loadlumtable
mappings.makenameparser=makenameparser
mappings.tounicode16=tounicode16
mappings.tounicode16sequence=tounicode16sequence
mappings.fromunicode16=fromunicode16
local ligseparator=P("_")
local varseparator=P(".")
local namesplitter=Ct(C((1-ligseparator-varseparator)^1)*(ligseparator*C((1-ligseparator-varseparator)^1))^0)
function mappings.addtounicode(data,filename)
  local resources=data.resources
  local properties=data.properties
  local descriptions=data.descriptions
  local unicodes=resources.unicodes
  if not unicodes then
    return
  end
  unicodes['space']=unicodes['space'] or 32
  unicodes['hyphen']=unicodes['hyphen'] or 45
  unicodes['zwj']=unicodes['zwj']  or 0x200D
  unicodes['zwnj']=unicodes['zwnj']  or 0x200C
  local private=fonts.constructors.privateoffset
  local unknown=format("%04X",utfbyte("?"))
  local unicodevector=fonts.encodings.agl.unicodes 
  local tounicode={}
  local originals={}
  resources.tounicode=tounicode
  resources.originals=originals
  local lumunic,uparser,oparser
  local cidinfo,cidnames,cidcodes,usedmap
  if false then 
    lumunic=loadlumtable(filename)
    lumunic=lumunic and lumunic.tounicode
  end
  cidinfo=properties.cidinfo
  usedmap=cidinfo and fonts.cid.getmap(cidinfo)
  if usedmap then
    oparser=usedmap and makenameparser(cidinfo.ordering)
    cidnames=usedmap.names
    cidcodes=usedmap.unicodes
  end
  uparser=makenameparser()
  local ns,nl=0,0
  for unic,glyph in next,descriptions do
    local index=glyph.index
    local name=glyph.name
    if unic==-1 or unic>=private or (unic>=0xE000 and unic<=0xF8FF) or unic==0xFFFE or unic==0xFFFF then
      local unicode=lumunic and lumunic[name] or unicodevector[name]
      if unicode then
        originals[index]=unicode
        tounicode[index]=tounicode16(unicode,name)
        ns=ns+1
      end
      if (not unicode) and usedmap then
        local foundindex=lpegmatch(oparser,name)
        if foundindex then
          unicode=cidcodes[foundindex] 
          if unicode then
            originals[index]=unicode
            tounicode[index]=tounicode16(unicode,name)
            ns=ns+1
          else
            local reference=cidnames[foundindex] 
            if reference then
              local foundindex=lpegmatch(oparser,reference)
              if foundindex then
                unicode=cidcodes[foundindex]
                if unicode then
                  originals[index]=unicode
                  tounicode[index]=tounicode16(unicode,name)
                  ns=ns+1
                end
              end
              if not unicode or unicode=="" then
                local foundcodes,multiple=lpegmatch(uparser,reference)
                if foundcodes then
                  originals[index]=foundcodes
                  if multiple then
                    tounicode[index]=tounicode16sequence(foundcodes)
                    nl=nl+1
                    unicode=true
                  else
                    tounicode[index]=tounicode16(foundcodes,name)
                    ns=ns+1
                    unicode=foundcodes
                  end
                end
              end
            end
          end
        end
      end
      if not unicode or unicode=="" then
        local split=lpegmatch(namesplitter,name)
        local nsplit=split and #split or 0
        local t,n={},0
        unicode=true
        for l=1,nsplit do
          local base=split[l]
          local u=unicodes[base] or unicodevector[base]
          if not u then
            break
          elseif type(u)=="table" then
            if u[1]>=private then
              unicode=false
              break
            end
            n=n+1
            t[n]=u[1]
          else
            if u>=private then
              unicode=false
              break
            end
            n=n+1
            t[n]=u
          end
        end
        if n==0 then
        elseif n==1 then
          originals[index]=t[1]
          tounicode[index]=tounicode16(t[1],name)
        else
          originals[index]=t
          tounicode[index]=tounicode16sequence(t)
        end
        nl=nl+1
      end
      if not unicode or unicode=="" then
        local foundcodes,multiple=lpegmatch(uparser,name)
        if foundcodes then
          if multiple then
            originals[index]=foundcodes
            tounicode[index]=tounicode16sequence(foundcodes,name)
            nl=nl+1
            unicode=true
          else
            originals[index]=foundcodes
            tounicode[index]=tounicode16(foundcodes,name)
            ns=ns+1
            unicode=foundcodes
          end
        end
      end
    end
  end
  if trace_mapping then
    for unic,glyph in table.sortedhash(descriptions) do
      local name=glyph.name
      local index=glyph.index
      local toun=tounicode[index]
      if toun then
        report_fonts("internal slot %U, name %a, unicode %U, tounicode %a",index,name,unic,toun)
      else
        report_fonts("internal slot %U, name %a, unicode %U",index,name,unic)
      end
    end
  end
  if trace_loading and (ns>0 or nl>0) then
    report_fonts("%s tounicode entries added, ligatures %s",nl+ns,ns)
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-fonts-syn']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
fonts.names=fonts.names or {}
fonts.names.version=1.001 
fonts.names.basename="luatex-fonts-names"
fonts.names.new_to_old={}
fonts.names.old_to_new={}
fonts.names.cache=containers.define("fonts","data",fonts.names.version,true)
local data,loaded=nil,false
local fileformats={ "lua","tex","other text files" }
function fonts.names.reportmissingbase()
  texio.write("<missing font database, run: mtxrun --script fonts --reload --simple>")
  fonts.names.reportmissingbase=nil
end
function fonts.names.reportmissingname()
  texio.write("<unknown font in database, run: mtxrun --script fonts --reload --simple>")
  fonts.names.reportmissingname=nil
end
function fonts.names.resolve(name,sub)
  if not loaded then
    local basename=fonts.names.basename
    if basename and basename~="" then
      data=containers.read(fonts.names.cache,basename)
      if not data then
        basename=file.addsuffix(basename,"lua")
        for i=1,#fileformats do
          local format=fileformats[i]
          local foundname=resolvers.findfile(basename,format) or ""
          if foundname~="" then
            data=dofile(foundname)
            texio.write("<font database loaded: ",foundname,">")
            break
          end
        end
      end
    end
    loaded=true
  end
  if type(data)=="table" and data.version==fonts.names.version then
    local condensed=string.gsub(string.lower(name),"[^%a%d]","")
    local found=data.mappings and data.mappings[condensed]
    if found then
      local fontname,filename,subfont=found[1],found[2],found[3]
      if subfont then
        return filename,fontname
      else
        return filename,false
      end
    elseif fonts.names.reportmissingname then
      fonts.names.reportmissingname()
      return name,false 
    end
  elseif fonts.names.reportmissingbase then
    fonts.names.reportmissingbase()
  end
end
fonts.names.resolvespec=fonts.names.resolve 
function fonts.names.getfilename(askedname,suffix) 
  return ""
end
function fonts.names.ignoredfile(filename) 
  return false 
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-tfm']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next=next
local match=string.match
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local trace_features=false trackers.register("tfm.features",function(v) trace_features=v end)
local report_defining=logs.reporter("fonts","defining")
local report_tfm=logs.reporter("fonts","tfm loading")
local findbinfile=resolvers.findbinfile
local fonts=fonts
local handlers=fonts.handlers
local readers=fonts.readers
local constructors=fonts.constructors
local encodings=fonts.encodings
local tfm=constructors.newhandler("tfm")
local tfmfeatures=constructors.newfeatures("tfm")
local registertfmfeature=tfmfeatures.register
constructors.resolvevirtualtoo=false 
fonts.formats.tfm="type1"
function tfm.setfeatures(tfmdata,features)
  local okay=constructors.initializefeatures("tfm",tfmdata,features,trace_features,report_tfm)
  if okay then
    return constructors.collectprocessors("tfm",tfmdata,features,trace_features,report_tfm)
  else
    return {} 
  end
end
local function read_from_tfm(specification)
  local filename=specification.filename
  local size=specification.size
  if trace_defining then
    report_defining("loading tfm file %a at size %s",filename,size)
  end
  local tfmdata=font.read_tfm(filename,size) 
  if tfmdata then
    local features=specification.features and specification.features.normal or {}
    local resources=tfmdata.resources or {}
    local properties=tfmdata.properties or {}
    local parameters=tfmdata.parameters or {}
    local shared=tfmdata.shared   or {}
    properties.name=tfmdata.name
    properties.fontname=tfmdata.fontname
    properties.psname=tfmdata.psname
    properties.filename=specification.filename
    parameters.size=size
    shared.rawdata={}
    shared.features=features
    shared.processes=next(features) and tfm.setfeatures(tfmdata,features) or nil
    tfmdata.properties=properties
    tfmdata.resources=resources
    tfmdata.parameters=parameters
    tfmdata.shared=shared
    parameters.slant=parameters.slant     or parameters[1] or 0
    parameters.space=parameters.space     or parameters[2] or 0
    parameters.space_stretch=parameters.space_stretch or parameters[3] or 0
    parameters.space_shrink=parameters.space_shrink  or parameters[4] or 0
    parameters.x_height=parameters.x_height    or parameters[5] or 0
    parameters.quad=parameters.quad      or parameters[6] or 0
    parameters.extra_space=parameters.extra_space  or parameters[7] or 0
    constructors.enhanceparameters(parameters)
    if constructors.resolvevirtualtoo then
      fonts.loggers.register(tfmdata,file.suffix(filename),specification) 
      local vfname=findbinfile(specification.name,'ovf')
      if vfname and vfname~="" then
        local vfdata=font.read_vf(vfname,size) 
        if vfdata then
          local chars=tfmdata.characters
          for k,v in next,vfdata.characters do
            chars[k].commands=v.commands
          end
          properties.virtualized=true
          tfmdata.fonts=vfdata.fonts
        end
      end
    end
    local allfeatures=tfmdata.shared.features or specification.features.normal
    constructors.applymanipulators("tfm",tfmdata,allfeatures.normal,trace_features,report_tfm)
    if not features.encoding then
      local encoding,filename=match(properties.filename,"^(.-)%-(.*)$") 
      if filename and encoding and encodings.known and encodings.known[encoding] then
        features.encoding=encoding
      end
    end
    return tfmdata
  end
end
local function check_tfm(specification,fullname) 
  local foundname=findbinfile(fullname,'tfm') or ""
  if foundname=="" then
    foundname=findbinfile(fullname,'ofm') or "" 
  end
  if foundname=="" then
    foundname=fonts.names.getfilename(fullname,"tfm") or ""
  end
  if foundname~="" then
    specification.filename=foundname
    specification.format="ofm"
    return read_from_tfm(specification)
  elseif trace_defining then
    report_defining("loading tfm with name %a fails",specification.name)
  end
end
readers.check_tfm=check_tfm
function readers.tfm(specification)
  local fullname=specification.filename or ""
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      fullname=specification.name.."."..forced
    else
      fullname=specification.name
    end
  end
  return check_tfm(specification,fullname)
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-afm']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local fonts,logs,trackers,containers,resolvers=fonts,logs,trackers,containers,resolvers
local next,type,tonumber=next,type,tonumber
local format,match,gmatch,lower,gsub,strip=string.format,string.match,string.gmatch,string.lower,string.gsub,string.strip
local abs=math.abs
local P,S,C,R,lpegmatch,patterns=lpeg.P,lpeg.S,lpeg.C,lpeg.R,lpeg.match,lpeg.patterns
local derivetable=table.derive
local trace_features=false trackers.register("afm.features",function(v) trace_features=v end)
local trace_indexing=false trackers.register("afm.indexing",function(v) trace_indexing=v end)
local trace_loading=false trackers.register("afm.loading",function(v) trace_loading=v end)
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local report_afm=logs.reporter("fonts","afm loading")
local findbinfile=resolvers.findbinfile
local definers=fonts.definers
local readers=fonts.readers
local constructors=fonts.constructors
local afm=constructors.newhandler("afm")
local pfb=constructors.newhandler("pfb")
local afmfeatures=constructors.newfeatures("afm")
local registerafmfeature=afmfeatures.register
afm.version=1.410 
afm.cache=containers.define("fonts","afm",afm.version,true)
afm.autoprefixed=true 
afm.helpdata={} 
afm.syncspace=true 
afm.addligatures=true 
afm.addtexligatures=true 
afm.addkerns=true 
local applyruntimefixes=fonts.treatments and fonts.treatments.applyfixes
local function setmode(tfmdata,value)
  if value then
    tfmdata.properties.mode=lower(value)
  end
end
registerafmfeature {
  name="mode",
  description="mode",
  initializers={
    base=setmode,
    node=setmode,
  }
}
local comment=P("Comment")
local spacing=patterns.spacer 
local lineend=patterns.newline 
local words=C((1-lineend)^1)
local number=C((R("09")+S("."))^1)/tonumber*spacing^0
local data=lpeg.Carg(1)
local pattern=(
  comment*spacing*(
      data*(
        ("CODINGSCHEME"*spacing*words                   )/function(fd,a)                   end+("DESIGNSIZE"*spacing*number*words               )/function(fd,a)   fd[ 1]=a    end+("CHECKSUM"*spacing*number*words               )/function(fd,a)   fd[ 2]=a    end+("SPACE"*spacing*number*"plus"*number*"minus"*number)/function(fd,a,b,c) fd[ 3],fd[ 4],fd[ 5]=a,b,c end+("QUAD"*spacing*number                   )/function(fd,a)   fd[ 6]=a    end+("EXTRASPACE"*spacing*number                   )/function(fd,a)   fd[ 7]=a    end+("NUM"*spacing*number*number*number          )/function(fd,a,b,c) fd[ 8],fd[ 9],fd[10]=a,b,c end+("DENOM"*spacing*number*number              )/function(fd,a,b ) fd[11],fd[12]=a,b  end+("SUP"*spacing*number*number*number          )/function(fd,a,b,c) fd[13],fd[14],fd[15]=a,b,c end+("SUB"*spacing*number*number              )/function(fd,a,b)  fd[16],fd[17]=a,b  end+("SUPDROP"*spacing*number                   )/function(fd,a)   fd[18]=a    end+("SUBDROP"*spacing*number                   )/function(fd,a)   fd[19]=a    end+("DELIM"*spacing*number*number              )/function(fd,a,b)  fd[20],fd[21]=a,b  end+("AXISHEIGHT"*spacing*number                   )/function(fd,a)   fd[22]=a    end
      )+(1-lineend)^0
    )+(1-comment)^1
)^0
local function scan_comment(str)
  local fd={}
  lpegmatch(pattern,str,1,fd)
  return fd
end
local keys={}
function keys.FontName  (data,line) data.metadata.fontname=strip  (line) 
                   data.metadata.fullname=strip  (line) end
function keys.ItalicAngle (data,line) data.metadata.italicangle=tonumber (line) end
function keys.IsFixedPitch(data,line) data.metadata.isfixedpitch=toboolean(line,true) end
function keys.CharWidth  (data,line) data.metadata.charwidth=tonumber (line) end
function keys.XHeight   (data,line) data.metadata.xheight=tonumber (line) end
function keys.Descender  (data,line) data.metadata.descender=tonumber (line) end
function keys.Ascender  (data,line) data.metadata.ascender=tonumber (line) end
function keys.Comment   (data,line)
  line=lower(line)
  local designsize=match(line,"designsize[^%d]*(%d+)")
  if designsize then data.metadata.designsize=tonumber(designsize) end
end
local function get_charmetrics(data,charmetrics,vector)
  local characters=data.characters
  local chr,ind={},0
  for k,v in gmatch(charmetrics,"([%a]+) +(.-) *;") do
    if k=='C' then
      v=tonumber(v)
      if v<0 then
        ind=ind+1 
      else
        ind=v
      end
      chr={
        index=ind
      }
    elseif k=='WX' then
      chr.width=tonumber(v)
    elseif k=='N' then
      characters[v]=chr
    elseif k=='B' then
      local llx,lly,urx,ury=match(v,"^ *(.-) +(.-) +(.-) +(.-)$")
      chr.boundingbox={ tonumber(llx),tonumber(lly),tonumber(urx),tonumber(ury) }
    elseif k=='L' then
      local plus,becomes=match(v,"^(.-) +(.-)$")
      local ligatures=chr.ligatures
      if ligatures then
        ligatures[plus]=becomes
      else
        chr.ligatures={ [plus]=becomes }
      end
    end
  end
end
local function get_kernpairs(data,kernpairs)
  local characters=data.characters
  for one,two,value in gmatch(kernpairs,"KPX +(.-) +(.-) +(.-)\n") do
    local chr=characters[one]
    if chr then
      local kerns=chr.kerns
      if kerns then
        kerns[two]=tonumber(value)
      else
        chr.kerns={ [two]=tonumber(value) }
      end
    end
  end
end
local function get_variables(data,fontmetrics)
  for key,rest in gmatch(fontmetrics,"(%a+) *(.-)[\n\r]") do
    local keyhandler=keys[key]
    if keyhandler then
      keyhandler(data,rest)
    end
  end
end
local function get_indexes(data,pfbname)
  data.resources.filename=resolvers.unresolve(pfbname) 
  local pfbblob=fontloader.open(pfbname)
  if pfbblob then
    local characters=data.characters
    local pfbdata=fontloader.to_table(pfbblob)
    if pfbdata then
      local glyphs=pfbdata.glyphs
      if glyphs then
        if trace_loading then
          report_afm("getting index data from %a",pfbname)
        end
        for index,glyph in next,glyphs do
          local name=glyph.name
          if name then
            local char=characters[name]
            if char then
              if trace_indexing then
                report_afm("glyph %a has index %a",name,index)
              end
              char.index=index
            end
          end
        end
      elseif trace_loading then
        report_afm("no glyph data in pfb file %a",pfbname)
      end
    elseif trace_loading then
      report_afm("no data in pfb file %a",pfbname)
    end
    fontloader.close(pfbblob)
  elseif trace_loading then
    report_afm("invalid pfb file %a",pfbname)
  end
end
local function readafm(filename)
  local ok,afmblob,size=resolvers.loadbinfile(filename) 
  if ok and afmblob then
    local data={
      resources={
        filename=resolvers.unresolve(filename),
        version=afm.version,
        creator="context mkiv",
      },
      properties={
        hasitalics=false,
      },
      goodies={},
      metadata={
        filename=file.removesuffix(file.basename(filename))
      },
      characters={
      },
      descriptions={
      },
    }
    afmblob=gsub(afmblob,"StartCharMetrics(.-)EndCharMetrics",function(charmetrics)
      if trace_loading then
        report_afm("loading char metrics")
      end
      get_charmetrics(data,charmetrics,vector)
      return ""
    end)
    afmblob=gsub(afmblob,"StartKernPairs(.-)EndKernPairs",function(kernpairs)
      if trace_loading then
        report_afm("loading kern pairs")
      end
      get_kernpairs(data,kernpairs)
      return ""
    end)
    afmblob=gsub(afmblob,"StartFontMetrics%s+([%d%.]+)(.-)EndFontMetrics",function(version,fontmetrics)
      if trace_loading then
        report_afm("loading variables")
      end
      data.afmversion=version
      get_variables(data,fontmetrics)
      data.fontdimens=scan_comment(fontmetrics) 
      return ""
    end)
    return data
  else
    if trace_loading then
      report_afm("no valid afm file %a",filename)
    end
    return nil
  end
end
local addkerns,addligatures,addtexligatures,unify,normalize 
function afm.load(filename)
  filename=resolvers.findfile(filename,'afm') or ""
  if filename~="" and not fonts.names.ignoredfile(filename) then
    local name=file.removesuffix(file.basename(filename))
    local data=containers.read(afm.cache,name)
    local attr=lfs.attributes(filename)
    local size,time=attr.size or 0,attr.modification or 0
    local pfbfile=file.replacesuffix(name,"pfb")
    local pfbname=resolvers.findfile(pfbfile,"pfb") or ""
    if pfbname=="" then
      pfbname=resolvers.findfile(file.basename(pfbfile),"pfb") or ""
    end
    local pfbsize,pfbtime=0,0
    if pfbname~="" then
      local attr=lfs.attributes(pfbname)
      pfbsize=attr.size or 0
      pfbtime=attr.modification or 0
    end
    if not data or data.size~=size or data.time~=time or data.pfbsize~=pfbsize or data.pfbtime~=pfbtime then
      report_afm("reading %a",filename)
      data=readafm(filename)
      if data then
        if pfbname~="" then
          get_indexes(data,pfbname)
        elseif trace_loading then
          report_afm("no pfb file for %a",filename)
        end
        report_afm("unifying %a",filename)
        unify(data,filename)
        if afm.addligatures then
          report_afm("add ligatures")
          addligatures(data)
        end
        if afm.addtexligatures then
          report_afm("add tex ligatures")
          addtexligatures(data)
        end
        if afm.addkerns then
          report_afm("add extra kerns")
          addkerns(data)
        end
        normalize(data)
        report_afm("add tounicode data")
        fonts.mappings.addtounicode(data,filename)
        data.size=size
        data.time=time
        data.pfbsize=pfbsize
        data.pfbtime=pfbtime
        report_afm("saving %a in cache",name)
        data=containers.write(afm.cache,name,data)
        data=containers.read(afm.cache,name)
      end
      if applyruntimefixes and data then
        applyruntimefixes(filename,data)
      end
    end
    return data
  else
    return nil
  end
end
local uparser=fonts.mappings.makenameparser()
unify=function(data,filename)
  local unicodevector=fonts.encodings.agl.unicodes 
  local unicodes,names={},{}
  local private=constructors.privateoffset
  local descriptions=data.descriptions
  for name,blob in next,data.characters do
    local code=unicodevector[name] 
    if not code then
      code=lpegmatch(uparser,name)
      if not code then
        code=private
        private=private+1
        report_afm("assigning private slot %U for unknown glyph name %a",code,name)
      end
    end
    local index=blob.index
    unicodes[name]=code
    names[name]=index
    blob.name=name
    descriptions[code]={
      boundingbox=blob.boundingbox,
      width=blob.width,
      kerns=blob.kerns,
      index=index,
      name=name,
    }
  end
  for unicode,description in next,descriptions do
    local kerns=description.kerns
    if kerns then
      local krn={}
      for name,kern in next,kerns do
        local unicode=unicodes[name]
        if unicode then
          krn[unicode]=kern
        else
        end
      end
      description.kerns=krn
    end
  end
  data.characters=nil
  local resources=data.resources
  local filename=resources.filename or file.removesuffix(file.basename(filename))
  resources.filename=resolvers.unresolve(filename) 
  resources.unicodes=unicodes 
  resources.marks={} 
  resources.names=names 
  resources.private=private
end
normalize=function(data)
end
local addthem=function(rawdata,ligatures)
  if ligatures then
    local descriptions=rawdata.descriptions
    local resources=rawdata.resources
    local unicodes=resources.unicodes
    local names=resources.names
    for ligname,ligdata in next,ligatures do
      local one=descriptions[unicodes[ligname]]
      if one then
        for _,pair in next,ligdata do
          local two,three=unicodes[pair[1]],unicodes[pair[2]]
          if two and three then
            local ol=one.ligatures
            if ol then
              if not ol[two] then
                ol[two]=three
              end
            else
              one.ligatures={ [two]=three }
            end
          end
        end
      end
    end
  end
end
addligatures=function(rawdata) addthem(rawdata,afm.helpdata.ligatures  ) end
addtexligatures=function(rawdata) addthem(rawdata,afm.helpdata.texligatures) end
addkerns=function(rawdata) 
  local descriptions=rawdata.descriptions
  local resources=rawdata.resources
  local unicodes=resources.unicodes
  local function do_it_left(what)
    if what then
      for unicode,description in next,descriptions do
        local kerns=description.kerns
        if kerns then
          local extrakerns
          for complex,simple in next,what do
            complex=unicodes[complex]
            simple=unicodes[simple]
            if complex and simple then
              local ks=kerns[simple]
              if ks and not kerns[complex] then
                if extrakerns then
                  extrakerns[complex]=ks
                else
                  extrakerns={ [complex]=ks }
                end
              end
            end
          end
          if extrakerns then
            description.extrakerns=extrakerns
          end
        end
      end
    end
  end
  local function do_it_copy(what)
    if what then
      for complex,simple in next,what do
        complex=unicodes[complex]
        simple=unicodes[simple]
        if complex and simple then
          local complexdescription=descriptions[complex]
          if complexdescription then 
            local simpledescription=descriptions[complex]
            if simpledescription then
              local extrakerns
              local kerns=simpledescription.kerns
              if kerns then
                for unicode,kern in next,kerns do
                  if extrakerns then
                    extrakerns[unicode]=kern
                  else
                    extrakerns={ [unicode]=kern }
                  end
                end
              end
              local extrakerns=simpledescription.extrakerns
              if extrakerns then
                for unicode,kern in next,extrakerns do
                  if extrakerns then
                    extrakerns[unicode]=kern
                  else
                    extrakerns={ [unicode]=kern }
                  end
                end
              end
              if extrakerns then
                complexdescription.extrakerns=extrakerns
              end
            end
          end
        end
      end
    end
  end
  do_it_left(afm.helpdata.leftkerned)
  do_it_left(afm.helpdata.bothkerned)
  do_it_copy(afm.helpdata.bothkerned)
  do_it_copy(afm.helpdata.rightkerned)
end
local function adddimensions(data) 
  if data then
    for unicode,description in next,data.descriptions do
      local bb=description.boundingbox
      if bb then
        local ht,dp=bb[4],-bb[2]
        if ht==0 or ht<0 then
        else
          description.height=ht
        end
        if dp==0 or dp<0 then
        else
          description.depth=dp
        end
      end
    end
  end
end
local function copytotfm(data)
  if data and data.descriptions then
    local metadata=data.metadata
    local resources=data.resources
    local properties=derivetable(data.properties)
    local descriptions=derivetable(data.descriptions)
    local goodies=derivetable(data.goodies)
    local characters={}
    local parameters={}
    local unicodes=resources.unicodes
    for unicode,description in next,data.descriptions do 
      characters[unicode]={}
    end
    local filename=constructors.checkedfilename(resources)
    local fontname=metadata.fontname or metadata.fullname
    local fullname=metadata.fullname or metadata.fontname
    local endash=unicodes['space']
    local emdash=unicodes['emdash']
    local spacer="space"
    local spaceunits=500
    local monospaced=metadata.isfixedpitch
    local charwidth=metadata.charwidth
    local italicangle=metadata.italicangle
    local charxheight=metadata.xheight and metadata.xheight>0 and metadata.xheight
    properties.monospaced=monospaced
    parameters.italicangle=italicangle
    parameters.charwidth=charwidth
    parameters.charxheight=charxheight
    if properties.monospaced then
      if descriptions[endash] then
        spaceunits,spacer=descriptions[endash].width,"space"
      end
      if not spaceunits and descriptions[emdash] then
        spaceunits,spacer=descriptions[emdash].width,"emdash"
      end
      if not spaceunits and charwidth then
        spaceunits,spacer=charwidth,"charwidth"
      end
    else
      if descriptions[endash] then
        spaceunits,spacer=descriptions[endash].width,"space"
      end
      if not spaceunits and charwidth then
        spaceunits,spacer=charwidth,"charwidth"
      end
    end
    spaceunits=tonumber(spaceunits)
    if spaceunits<200 then
    end
    parameters.slant=0
    parameters.space=spaceunits
    parameters.space_stretch=500
    parameters.space_shrink=333
    parameters.x_height=400
    parameters.quad=1000
    if italicangle and italicangle~=0 then
      parameters.italicangle=italicangle
      parameters.italicfactor=math.cos(math.rad(90+italicangle))
      parameters.slant=- math.tan(italicangle*math.pi/180)
    end
    if monospaced then
      parameters.space_stretch=0
      parameters.space_shrink=0
    elseif afm.syncspace then
      parameters.space_stretch=spaceunits/2
      parameters.space_shrink=spaceunits/3
    end
    parameters.extra_space=parameters.space_shrink
    if charxheight then
      parameters.x_height=charxheight
    else
      local x=unicodes['x']
      if x then
        local x=descriptions[x]
        if x then
          parameters.x_height=x.height
        end
      end
    end
    local fd=data.fontdimens
    if fd and fd[8] and fd[9] and fd[10] then 
      for k,v in next,fd do
        parameters[k]=v
      end
    end
    parameters.designsize=(metadata.designsize or 10)*65536
    parameters.ascender=abs(metadata.ascender or 0)
    parameters.descender=abs(metadata.descender or 0)
    parameters.units=1000
    properties.spacer=spacer
    properties.encodingbytes=2
    properties.format=fonts.formats[filename] or "type1"
    properties.filename=filename
    properties.fontname=fontname
    properties.fullname=fullname
    properties.psname=fullname
    properties.name=filename or fullname or fontname
    if next(characters) then
      return {
        characters=characters,
        descriptions=descriptions,
        parameters=parameters,
        resources=resources,
        properties=properties,
        goodies=goodies,
      }
    end
  end
  return nil
end
function afm.setfeatures(tfmdata,features)
  local okay=constructors.initializefeatures("afm",tfmdata,features,trace_features,report_afm)
  if okay then
    return constructors.collectprocessors("afm",tfmdata,features,trace_features,report_afm)
  else
    return {} 
  end
end
local function checkfeatures(specification)
end
local function afmtotfm(specification)
  local afmname=specification.filename or specification.name
  if specification.forced=="afm" or specification.format=="afm" then 
    if trace_loading then
      report_afm("forcing afm format for %a",afmname)
    end
  else
    local tfmname=findbinfile(afmname,"ofm") or ""
    if tfmname~="" then
      if trace_loading then
        report_afm("fallback from afm to tfm for %a",afmname)
      end
      return 
    end
  end
  if afmname~="" then
    local features=constructors.checkedfeatures("afm",specification.features.normal)
    specification.features.normal=features
    constructors.hashinstance(specification,true)
    specification=definers.resolve(specification) 
    local cache_id=specification.hash
    local tfmdata=containers.read(constructors.cache,cache_id) 
    if not tfmdata then
      local rawdata=afm.load(afmname)
      if rawdata and next(rawdata) then
        adddimensions(rawdata)
        tfmdata=copytotfm(rawdata)
        if tfmdata and next(tfmdata) then
          local shared=tfmdata.shared
          if not shared then
            shared={}
            tfmdata.shared=shared
          end
          shared.rawdata=rawdata
          shared.features=features
          shared.processes=afm.setfeatures(tfmdata,features)
        end
      elseif trace_loading then
        report_afm("no (valid) afm file found with name %a",afmname)
      end
      tfmdata=containers.write(constructors.cache,cache_id,tfmdata)
    end
    return tfmdata
  end
end
local function read_from_afm(specification)
  local tfmdata=afmtotfm(specification)
  if tfmdata then
    tfmdata.properties.name=specification.name
    tfmdata=constructors.scale(tfmdata,specification)
    local allfeatures=tfmdata.shared.features or specification.features.normal
    constructors.applymanipulators("afm",tfmdata,allfeatures,trace_features,report_afm)
    fonts.loggers.register(tfmdata,'afm',specification)
  end
  return tfmdata
end
local function prepareligatures(tfmdata,ligatures,value)
  if value then
    local descriptions=tfmdata.descriptions
    for unicode,character in next,tfmdata.characters do
      local description=descriptions[unicode]
      local dligatures=description.ligatures
      if dligatures then
        local cligatures=character.ligatures
        if not cligatures then
          cligatures={}
          character.ligatures=cligatures
        end
        for unicode,ligature in next,dligatures do
          cligatures[unicode]={
            char=ligature,
            type=0
          }
        end
      end
    end
  end
end
local function preparekerns(tfmdata,kerns,value)
  if value then
    local rawdata=tfmdata.shared.rawdata
    local resources=rawdata.resources
    local unicodes=resources.unicodes
    local descriptions=tfmdata.descriptions
    for u,chr in next,tfmdata.characters do
      local d=descriptions[u]
      local newkerns=d[kerns]
      if newkerns then
        local kerns=chr.kerns
        if not kerns then
          kerns={}
          chr.kerns=kerns
        end
        for k,v in next,newkerns do
          local uk=unicodes[k]
          if uk then
            kerns[uk]=v
          end
        end
      end
    end
  end
end
local list={
  [0x0027]=0x2019,
}
local function texreplacements(tfmdata,value)
  local descriptions=tfmdata.descriptions
  local characters=tfmdata.characters
  for k,v in next,list do
    characters [k]=characters [v] 
    descriptions[k]=descriptions[v] 
  end
end
local function ligatures  (tfmdata,value) prepareligatures(tfmdata,'ligatures',value) end
local function texligatures(tfmdata,value) prepareligatures(tfmdata,'texligatures',value) end
local function kerns    (tfmdata,value) preparekerns  (tfmdata,'kerns',value) end
local function extrakerns (tfmdata,value) preparekerns  (tfmdata,'extrakerns',value) end
registerafmfeature {
  name="liga",
  description="traditional ligatures",
  initializers={
    base=ligatures,
    node=ligatures,
  }
}
registerafmfeature {
  name="kern",
  description="intercharacter kerning",
  initializers={
    base=kerns,
    node=kerns,
  }
}
registerafmfeature {
  name="extrakerns",
  description="additional intercharacter kerning",
  initializers={
    base=extrakerns,
    node=extrakerns,
  }
}
registerafmfeature {
  name='tlig',
  description='tex ligatures',
  initializers={
    base=texligatures,
    node=texligatures,
  }
}
registerafmfeature {
  name='trep',
  description='tex replacements',
  initializers={
    base=texreplacements,
    node=texreplacements,
  }
}
local check_tfm=readers.check_tfm
fonts.formats.afm="type1"
fonts.formats.pfb="type1"
local function check_afm(specification,fullname)
  local foundname=findbinfile(fullname,'afm') or "" 
  if foundname=="" then
    foundname=fonts.names.getfilename(fullname,"afm") or ""
  end
  if foundname=="" and afm.autoprefixed then
    local encoding,shortname=match(fullname,"^(.-)%-(.*)$") 
    if encoding and shortname and fonts.encodings.known[encoding] then
      shortname=findbinfile(shortname,'afm') or "" 
      if shortname~="" then
        foundname=shortname
        if trace_defining then
          report_afm("stripping encoding prefix from filename %a",afmname)
        end
      end
    end
  end
  if foundname~="" then
    specification.filename=foundname
    specification.format="afm"
    return read_from_afm(specification)
  end
end
function readers.afm(specification,method)
  local fullname,tfmdata=specification.filename or "",nil
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      tfmdata=check_afm(specification,specification.name.."."..forced)
    end
    if not tfmdata then
      method=method or definers.method or "afm or tfm"
      if method=="tfm" then
        tfmdata=check_tfm(specification,specification.name)
      elseif method=="afm" then
        tfmdata=check_afm(specification,specification.name)
      elseif method=="tfm or afm" then
        tfmdata=check_tfm(specification,specification.name) or check_afm(specification,specification.name)
      else 
        tfmdata=check_afm(specification,specification.name) or check_tfm(specification,specification.name)
      end
    end
  else
    tfmdata=check_afm(specification,fullname)
  end
  return tfmdata
end
function readers.pfb(specification,method) 
  local original=specification.specification
  if trace_defining then
    report_afm("using afm reader for %a",original)
  end
  specification.specification=gsub(original,"%.pfb",".afm")
  specification.forced="afm"
  return readers.afm(specification,method)
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-afk']={
  version=1.001,
  comment="companion to font-afm.lua",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files",
  dataonly=true,
}
local allocate=utilities.storage.allocate
fonts.handlers.afm.helpdata={
  ligatures=allocate { 
    ['f']={ 
      { 'f','ff' },
      { 'i','fi' },
      { 'l','fl' },
    },
    ['ff']={
      { 'i','ffi' }
    },
    ['fi']={
      { 'i','fii' }
    },
    ['fl']={
      { 'i','fli' }
    },
    ['s']={
      { 't','st' }
    },
    ['i']={
      { 'j','ij' }
    },
  },
  texligatures=allocate {
    ['quoteleft']={
      { 'quoteleft','quotedblleft' }
    },
    ['quoteright']={
      { 'quoteright','quotedblright' }
    },
    ['hyphen']={
      { 'hyphen','endash' }
    },
    ['endash']={
      { 'hyphen','emdash' }
    }
  },
  leftkerned=allocate {
    AEligature="A",aeligature="a",
    OEligature="O",oeligature="o",
    IJligature="I",ijligature="i",
    AE="A",ae="a",
    OE="O",oe="o",
    IJ="I",ij="i",
    Ssharp="S",ssharp="s",
  },
  rightkerned=allocate {
    AEligature="E",aeligature="e",
    OEligature="E",oeligature="e",
    IJligature="J",ijligature="j",
    AE="E",ae="e",
    OE="E",oe="e",
    IJ="J",ij="j",
    Ssharp="S",ssharp="s",
  },
  bothkerned=allocate {
    Acircumflex="A",acircumflex="a",
    Ccircumflex="C",ccircumflex="c",
    Ecircumflex="E",ecircumflex="e",
    Gcircumflex="G",gcircumflex="g",
    Hcircumflex="H",hcircumflex="h",
    Icircumflex="I",icircumflex="i",
    Jcircumflex="J",jcircumflex="j",
    Ocircumflex="O",ocircumflex="o",
    Scircumflex="S",scircumflex="s",
    Ucircumflex="U",ucircumflex="u",
    Wcircumflex="W",wcircumflex="w",
    Ycircumflex="Y",ycircumflex="y",
    Agrave="A",agrave="a",
    Egrave="E",egrave="e",
    Igrave="I",igrave="i",
    Ograve="O",ograve="o",
    Ugrave="U",ugrave="u",
    Ygrave="Y",ygrave="y",
    Atilde="A",atilde="a",
    Itilde="I",itilde="i",
    Otilde="O",otilde="o",
    Utilde="U",utilde="u",
    Ntilde="N",ntilde="n",
    Adiaeresis="A",adiaeresis="a",Adieresis="A",adieresis="a",
    Ediaeresis="E",ediaeresis="e",Edieresis="E",edieresis="e",
    Idiaeresis="I",idiaeresis="i",Idieresis="I",idieresis="i",
    Odiaeresis="O",odiaeresis="o",Odieresis="O",odieresis="o",
    Udiaeresis="U",udiaeresis="u",Udieresis="U",udieresis="u",
    Ydiaeresis="Y",ydiaeresis="y",Ydieresis="Y",ydieresis="y",
    Aacute="A",aacute="a",
    Cacute="C",cacute="c",
    Eacute="E",eacute="e",
    Iacute="I",iacute="i",
    Lacute="L",lacute="l",
    Nacute="N",nacute="n",
    Oacute="O",oacute="o",
    Racute="R",racute="r",
    Sacute="S",sacute="s",
    Uacute="U",uacute="u",
    Yacute="Y",yacute="y",
    Zacute="Z",zacute="z",
    Dstroke="D",dstroke="d",
    Hstroke="H",hstroke="h",
    Tstroke="T",tstroke="t",
    Cdotaccent="C",cdotaccent="c",
    Edotaccent="E",edotaccent="e",
    Gdotaccent="G",gdotaccent="g",
    Idotaccent="I",idotaccent="i",
    Zdotaccent="Z",zdotaccent="z",
    Amacron="A",amacron="a",
    Emacron="E",emacron="e",
    Imacron="I",imacron="i",
    Omacron="O",omacron="o",
    Umacron="U",umacron="u",
    Ccedilla="C",ccedilla="c",
    Kcedilla="K",kcedilla="k",
    Lcedilla="L",lcedilla="l",
    Ncedilla="N",ncedilla="n",
    Rcedilla="R",rcedilla="r",
    Scedilla="S",scedilla="s",
    Tcedilla="T",tcedilla="t",
    Ohungarumlaut="O",ohungarumlaut="o",
    Uhungarumlaut="U",uhungarumlaut="u",
    Aogonek="A",aogonek="a",
    Eogonek="E",eogonek="e",
    Iogonek="I",iogonek="i",
    Uogonek="U",uogonek="u",
    Aring="A",aring="a",
    Uring="U",uring="u",
    Abreve="A",abreve="a",
    Ebreve="E",ebreve="e",
    Gbreve="G",gbreve="g",
    Ibreve="I",ibreve="i",
    Obreve="O",obreve="o",
    Ubreve="U",ubreve="u",
    Ccaron="C",ccaron="c",
    Dcaron="D",dcaron="d",
    Ecaron="E",ecaron="e",
    Lcaron="L",lcaron="l",
    Ncaron="N",ncaron="n",
    Rcaron="R",rcaron="r",
    Scaron="S",scaron="s",
    Tcaron="T",tcaron="t",
    Zcaron="Z",zcaron="z",
    dotlessI="I",dotlessi="i",
    dotlessJ="J",dotlessj="j",
    AEligature="AE",aeligature="ae",AE="AE",ae="ae",
    OEligature="OE",oeligature="oe",OE="OE",oe="oe",
    IJligature="IJ",ijligature="ij",IJ="IJ",ij="ij",
    Lstroke="L",lstroke="l",Lslash="L",lslash="l",
    Ostroke="O",ostroke="o",Oslash="O",oslash="o",
    Ssharp="SS",ssharp="ss",
    Aumlaut="A",aumlaut="a",
    Eumlaut="E",eumlaut="e",
    Iumlaut="I",iumlaut="i",
    Oumlaut="O",oumlaut="o",
    Uumlaut="U",uumlaut="u",
  }
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-fonts-tfm']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
local tfm={}
fonts.handlers.tfm=tfm
fonts.formats.tfm="type1" 
function fonts.readers.tfm(specification)
  local fullname=specification.filename or ""
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      fullname=specification.name.."."..forced
    else
      fullname=specification.name
    end
  end
  local foundname=resolvers.findbinfile(fullname,'tfm') or ""
  if foundname=="" then
    foundname=resolvers.findbinfile(fullname,'ofm') or ""
  end
  if foundname~="" then
    specification.filename=foundname
    specification.format="ofm"
    return font.read_tfm(specification.filename,specification.size)
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-oti']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local lower=string.lower
local fonts=fonts
local constructors=fonts.constructors
local otf=constructors.newhandler("otf")
local otffeatures=constructors.newfeatures("otf")
local otftables=otf.tables
local registerotffeature=otffeatures.register
local allocate=utilities.storage.allocate
registerotffeature {
  name="features",
  description="initialization of feature handler",
  default=true,
}
local function setmode(tfmdata,value)
  if value then
    tfmdata.properties.mode=lower(value)
  end
end
local function setlanguage(tfmdata,value)
  if value then
    local cleanvalue=lower(value)
    local languages=otftables and otftables.languages
    local properties=tfmdata.properties
    if not languages then
      properties.language=cleanvalue
    elseif languages[value] then
      properties.language=cleanvalue
    else
      properties.language="dflt"
    end
  end
end
local function setscript(tfmdata,value)
  if value then
    local cleanvalue=lower(value)
    local scripts=otftables and otftables.scripts
    local properties=tfmdata.properties
    if not scripts then
      properties.script=cleanvalue
    elseif scripts[value] then
      properties.script=cleanvalue
    else
      properties.script="dflt"
    end
  end
end
registerotffeature {
  name="mode",
  description="mode",
  initializers={
    base=setmode,
    node=setmode,
  }
}
registerotffeature {
  name="language",
  description="language",
  initializers={
    base=setlanguage,
    node=setlanguage,
  }
}
registerotffeature {
  name="script",
  description="script",
  initializers={
    base=setscript,
    node=setscript,
  }
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otf']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local utfbyte=utf.byte
local format,gmatch,gsub,find,match,lower,strip=string.format,string.gmatch,string.gsub,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring=type,next,tonumber,tostring
local abs=math.abs
local insert=table.insert
local lpegmatch=lpeg.match
local reversed,concat,remove,sortedkeys=table.reversed,table.concat,table.remove,table.sortedkeys
local ioflush=io.flush
local fastcopy,tohash,derivetable=table.fastcopy,table.tohash,table.derive
local formatters=string.formatters
local allocate=utilities.storage.allocate
local registertracker=trackers.register
local registerdirective=directives.register
local starttiming=statistics.starttiming
local stoptiming=statistics.stoptiming
local elapsedtime=statistics.elapsedtime
local findbinfile=resolvers.findbinfile
local trace_private=false registertracker("otf.private",function(v) trace_private=v end)
local trace_loading=false registertracker("otf.loading",function(v) trace_loading=v end)
local trace_features=false registertracker("otf.features",function(v) trace_features=v end)
local trace_dynamics=false registertracker("otf.dynamics",function(v) trace_dynamics=v end)
local trace_sequences=false registertracker("otf.sequences",function(v) trace_sequences=v end)
local trace_markwidth=false registertracker("otf.markwidth",function(v) trace_markwidth=v end)
local trace_defining=false registertracker("fonts.defining",function(v) trace_defining=v end)
local report_otf=logs.reporter("fonts","otf loading")
local fonts=fonts
local otf=fonts.handlers.otf
otf.glists={ "gsub","gpos" }
otf.version=2.755 
otf.cache=containers.define("fonts","otf",otf.version,true)
local fontdata=fonts.hashes.identifiers
local chardata=characters and characters.data 
local otffeatures=fonts.constructors.newfeatures("otf")
local registerotffeature=otffeatures.register
local enhancers=allocate()
otf.enhancers=enhancers
local patches={}
enhancers.patches=patches
local definers=fonts.definers
local readers=fonts.readers
local constructors=fonts.constructors
local forceload=false
local cleanup=0   
local usemetatables=false 
local packdata=true
local syncspace=true
local forcenotdef=false
local includesubfonts=false
local overloadkerns=false 
local applyruntimefixes=fonts.treatments and fonts.treatments.applyfixes
local wildcard="*"
local default="dflt"
local fontloaderfields=fontloader.fields
local mainfields=nil
local glyphfields=nil 
local formats=fonts.formats
formats.otf="opentype"
formats.ttf="truetype"
formats.ttc="truetype"
formats.dfont="truetype"
registerdirective("fonts.otf.loader.cleanup",function(v) cleanup=tonumber(v) or (v and 1) or 0 end)
registerdirective("fonts.otf.loader.force",function(v) forceload=v end)
registerdirective("fonts.otf.loader.usemetatables",function(v) usemetatables=v end)
registerdirective("fonts.otf.loader.pack",function(v) packdata=v end)
registerdirective("fonts.otf.loader.syncspace",function(v) syncspace=v end)
registerdirective("fonts.otf.loader.forcenotdef",function(v) forcenotdef=v end)
registerdirective("fonts.otf.loader.overloadkerns",function(v) overloadkerns=v end)
function otf.fileformat(filename)
  local leader=lower(io.loadchunk(filename,4))
  local suffix=lower(file.suffix(filename))
  if leader=="otto" then
    return formats.otf,suffix=="otf"
  elseif leader=="ttcf" then
    return formats.ttc,suffix=="ttc"
  elseif suffix=="ttc" then
    return formats.ttc,true
  elseif suffix=="dfont" then
    return formats.dfont,true
  else
    return formats.ttf,suffix=="ttf"
  end
end
local function otf_format(filename)
  local format,okay=otf.fileformat(filename)
  if not okay then
    report_otf("font %a is actually an %a file",filename,format)
  end
  return format
end
local function load_featurefile(raw,featurefile)
  if featurefile and featurefile~="" then
    if trace_loading then
      report_otf("using featurefile %a",featurefile)
    end
    fontloader.apply_featurefile(raw,featurefile)
  end
end
local function showfeatureorder(rawdata,filename)
  local sequences=rawdata.resources.sequences
  if sequences and #sequences>0 then
    if trace_loading then
      report_otf("font %a has %s sequences",filename,#sequences)
      report_otf(" ")
    end
    for nos=1,#sequences do
      local sequence=sequences[nos]
      local typ=sequence.type   or "no-type"
      local name=sequence.name   or "no-name"
      local subtables=sequence.subtables or { "no-subtables" }
      local features=sequence.features
      if trace_loading then
        report_otf("%3i  %-15s  %-20s  [% t]",nos,name,typ,subtables)
      end
      if features then
        for feature,scripts in next,features do
          local tt={}
          if type(scripts)=="table" then
            for script,languages in next,scripts do
              local ttt={}
              for language,_ in next,languages do
                ttt[#ttt+1]=language
              end
              tt[#tt+1]=formatters["[%s: % t]"](script,ttt)
            end
            if trace_loading then
              report_otf("       %s: % t",feature,tt)
            end
          else
            if trace_loading then
              report_otf("       %s: %S",feature,scripts)
            end
          end
        end
      end
    end
    if trace_loading then
      report_otf("\n")
    end
  elseif trace_loading then
    report_otf("font %a has no sequences",filename)
  end
end
local valid_fields=table.tohash {
  "ascent",
  "cidinfo",
  "copyright",
  "descent",
  "design_range_bottom",
  "design_range_top",
  "design_size",
  "encodingchanged",
  "extrema_bound",
  "familyname",
  "fontname",
  "fontname",
  "fontstyle_id",
  "fontstyle_name",
  "fullname",
  "hasvmetrics",
  "horiz_base",
  "issans",
  "isserif",
  "italicangle",
  "macstyle",
  "onlybitmaps",
  "origname",
  "os2_version",
  "pfminfo",
  "serifcheck",
  "sfd_version",
  "strokedfont",
  "strokewidth",
  "table_version",
  "ttf_tables",
  "uni_interp",
  "uniqueid",
  "units_per_em",
  "upos",
  "use_typo_metrics",
  "uwidth",
  "validation_state",
  "version",
  "vert_base",
  "weight",
  "weight_width_slope_only",
}
local ordered_enhancers={
  "prepare tables",
  "prepare glyphs",
  "prepare lookups",
  "analyze glyphs",
  "analyze math",
  "prepare tounicode",
  "reorganize lookups",
  "reorganize mark classes",
  "reorganize anchor classes",
  "reorganize glyph kerns",
  "reorganize glyph lookups",
  "reorganize glyph anchors",
  "merge kern classes",
  "reorganize features",
  "reorganize subtables",
  "check glyphs",
  "check metadata",
  "check extra features",
  "check encoding",
  "add duplicates",
  "cleanup tables",
}
local actions=allocate()
local before=allocate()
local after=allocate()
patches.before=before
patches.after=after
local function enhance(name,data,filename,raw)
  local enhancer=actions[name]
  if enhancer then
    if trace_loading then
      report_otf("apply enhancement %a to file %a",name,filename)
      ioflush()
    end
    enhancer(data,filename,raw)
  else
  end
end
function enhancers.apply(data,filename,raw)
  local basename=file.basename(lower(filename))
  if trace_loading then
    report_otf("%s enhancing file %a","start",filename)
  end
  ioflush() 
  for e=1,#ordered_enhancers do
    local enhancer=ordered_enhancers[e]
    local b=before[enhancer]
    if b then
      for pattern,action in next,b do
        if find(basename,pattern) then
          action(data,filename,raw)
        end
      end
    end
    enhance(enhancer,data,filename,raw)
    local a=after[enhancer]
    if a then
      for pattern,action in next,a do
        if find(basename,pattern) then
          action(data,filename,raw)
        end
      end
    end
    ioflush() 
  end
  if trace_loading then
    report_otf("%s enhancing file %a","stop",filename)
  end
  ioflush() 
end
function patches.register(what,where,pattern,action)
  local pw=patches[what]
  if pw then
    local ww=pw[where]
    if ww then
      ww[pattern]=action
    else
      pw[where]={ [pattern]=action}
    end
  end
end
function patches.report(fmt,...)
  if trace_loading then
    report_otf("patching: %s",formatters[fmt](...))
  end
end
function enhancers.register(what,action) 
  actions[what]=action
end
function otf.load(filename,sub,featurefile) 
  local base=file.basename(file.removesuffix(filename))
  local name=file.removesuffix(base)
  local attr=lfs.attributes(filename)
  local size=attr and attr.size or 0
  local time=attr and attr.modification or 0
  if featurefile then
    name=name.."@"..file.removesuffix(file.basename(featurefile))
  end
  if sub=="" then
    sub=false
  end
  local hash=name
  if sub then
    hash=hash.."-"..sub
  end
  hash=containers.cleanname(hash)
  local featurefiles
  if featurefile then
    featurefiles={}
    for s in gmatch(featurefile,"[^,]+") do
      local name=resolvers.findfile(file.addsuffix(s,'fea'),'fea') or ""
      if name=="" then
        report_otf("loading error, no featurefile %a",s)
      else
        local attr=lfs.attributes(name)
        featurefiles[#featurefiles+1]={
          name=name,
          size=attr and attr.size or 0,
          time=attr and attr.modification or 0,
        }
      end
    end
    if #featurefiles==0 then
      featurefiles=nil
    end
  end
  local data=containers.read(otf.cache,hash)
  local reload=not data or data.size~=size or data.time~=time
  if forceload then
    report_otf("forced reload of %a due to hard coded flag",filename)
    reload=true
  end
  if not reload then
    local featuredata=data.featuredata
    if featurefiles then
      if not featuredata or #featuredata~=#featurefiles then
        reload=true
      else
        for i=1,#featurefiles do
          local fi,fd=featurefiles[i],featuredata[i]
          if fi.name~=fd.name or fi.size~=fd.size or fi.time~=fd.time then
            reload=true
            break
          end
        end
      end
    elseif featuredata then
      reload=true
    end
    if reload then
      report_otf("loading: forced reload due to changed featurefile specification %a",featurefile)
    end
   end
   if reload then
    report_otf("loading %a, hash %a",filename,hash)
    local fontdata,messages
    if sub then
      fontdata,messages=fontloader.open(filename,sub)
    else
      fontdata,messages=fontloader.open(filename)
    end
    if fontdata then
      mainfields=mainfields or (fontloaderfields and fontloaderfields(fontdata))
    end
    if trace_loading and messages and #messages>0 then
      if type(messages)=="string" then
        report_otf("warning: %s",messages)
      else
        for m=1,#messages do
          report_otf("warning: %S",messages[m])
        end
      end
    else
      report_otf("loading done")
    end
    if fontdata then
      if featurefiles then
        for i=1,#featurefiles do
          load_featurefile(fontdata,featurefiles[i].name)
        end
      end
      local unicodes={
      }
      local splitter=lpeg.splitter(" ",unicodes)
      data={
        size=size,
        time=time,
        format=otf_format(filename),
        featuredata=featurefiles,
        resources={
          filename=resolvers.unresolve(filename),
          version=otf.version,
          creator="context mkiv",
          unicodes=unicodes,
          indices={
          },
          duplicates={
          },
          variants={
          },
          lookuptypes={},
        },
        metadata={
        },
        properties={
        },
        descriptions={},
        goodies={},
        helpers={ 
          tounicodelist=splitter,
          tounicodetable=lpeg.Ct(splitter),
        },
      }
      starttiming(data)
      report_otf("file size: %s",size)
      enhancers.apply(data,filename,fontdata)
      local packtime={}
      if packdata then
        if cleanup>0 then
          collectgarbage("collect")
        end
        starttiming(packtime)
        enhance("pack",data,filename,nil)
        stoptiming(packtime)
      end
      report_otf("saving %a in cache",filename)
      data=containers.write(otf.cache,hash,data)
      if cleanup>1 then
        collectgarbage("collect")
      end
      stoptiming(data)
      if elapsedtime then 
        report_otf("preprocessing and caching time %s, packtime %s",
          elapsedtime(data),packdata and elapsedtime(packtime) or 0)
      end
      fontloader.close(fontdata) 
      if cleanup>3 then
        collectgarbage("collect")
      end
      data=containers.read(otf.cache,hash) 
      if cleanup>2 then
        collectgarbage("collect")
      end
    else
      data=nil
      report_otf("loading failed due to read error")
    end
  end
  if data then
    if trace_defining then
      report_otf("loading from cache using hash %a",hash)
    end
    enhance("unpack",data,filename,nil,false)
    if applyruntimefixes then
      applyruntimefixes(filename,data)
    end
    enhance("add dimensions",data,filename,nil,false)
    if trace_sequences then
      showfeatureorder(data,filename)
    end
  end
  return data
end
local mt={
  __index=function(t,k) 
    if k=="height" then
      local ht=t.boundingbox[4]
      return ht<0 and 0 or ht
    elseif k=="depth" then
      local dp=-t.boundingbox[2]
      return dp<0 and 0 or dp
    elseif k=="width" then
      return 0
    elseif k=="name" then 
      return forcenotdef and ".notdef"
    end
  end
}
actions["prepare tables"]=function(data,filename,raw)
  data.properties.hasitalics=false
end
actions["add dimensions"]=function(data,filename)
  if data then
    local descriptions=data.descriptions
    local resources=data.resources
    local defaultwidth=resources.defaultwidth or 0
    local defaultheight=resources.defaultheight or 0
    local defaultdepth=resources.defaultdepth or 0
    local basename=trace_markwidth and file.basename(filename)
    if usemetatables then
      for _,d in next,descriptions do
        local wd=d.width
        if not wd then
          d.width=defaultwidth
        elseif trace_markwidth and wd~=0 and d.class=="mark" then
          report_otf("mark %a with width %b found in %a",d.name or "<noname>",wd,basename)
        end
        setmetatable(d,mt)
      end
    else
      for _,d in next,descriptions do
        local bb,wd=d.boundingbox,d.width
        if not wd then
          d.width=defaultwidth
        elseif trace_markwidth and wd~=0 and d.class=="mark" then
          report_otf("mark %a with width %b found in %a",d.name or "<noname>",wd,basename)
        end
        if bb then
          local ht,dp=bb[4],-bb[2]
          if ht==0 or ht<0 then
          else
            d.height=ht
          end
          if dp==0 or dp<0 then
          else
            d.depth=dp
          end
        end
      end
    end
  end
end
local function somecopy(old) 
  if old then
    local new={}
    if type(old)=="table" then
      for k,v in next,old do
        if k=="glyphs" then
        elseif type(v)=="table" then
          new[k]=somecopy(v)
        else
          new[k]=v
        end
      end
    else
      for i=1,#mainfields do
        local k=mainfields[i]
        local v=old[k]
        if k=="glyphs" then
        elseif type(v)=="table" then
          new[k]=somecopy(v)
        else
          new[k]=v
        end
      end
    end
    return new
  else
    return {}
  end
end
actions["prepare glyphs"]=function(data,filename,raw)
  local rawglyphs=raw.glyphs
  local rawsubfonts=raw.subfonts
  local rawcidinfo=raw.cidinfo
  local criterium=constructors.privateoffset
  local private=criterium
  local resources=data.resources
  local metadata=data.metadata
  local properties=data.properties
  local descriptions=data.descriptions
  local unicodes=resources.unicodes 
  local indices=resources.indices 
  local duplicates=resources.duplicates
  local variants=resources.variants
  if rawsubfonts then
    metadata.subfonts=includesubfonts and {}
    properties.cidinfo=rawcidinfo
    if rawcidinfo.registry then
      local cidmap=fonts.cid.getmap(rawcidinfo)
      if cidmap then
        rawcidinfo.usedname=cidmap.usedname
        local nofnames,nofunicodes=0,0
        local cidunicodes,cidnames=cidmap.unicodes,cidmap.names
        for cidindex=1,#rawsubfonts do
          local subfont=rawsubfonts[cidindex]
          local cidglyphs=subfont.glyphs
          if includesubfonts then
            metadata.subfonts[cidindex]=somecopy(subfont)
          end
          for index=0,subfont.glyphcnt-1 do 
            local glyph=cidglyphs[index]
            if glyph then
              local unicode=glyph.unicode
if   unicode>=0x00E000 and unicode<=0x00F8FF then
                unicode=-1
elseif unicode>=0x0F0000 and unicode<=0x0FFFFD then
                unicode=-1
elseif unicode>=0x100000 and unicode<=0x10FFFD then
                unicode=-1
end
              local name=glyph.name or cidnames[index]
              if not unicode or unicode==-1 then 
                unicode=cidunicodes[index]
              end
              if unicode and descriptions[unicode] then
                report_otf("preventing glyph %a at index %H to overload unicode %U",name or "noname",index,unicode)
                unicode=-1
              end
              if not unicode or unicode==-1 then 
                if not name then
                  name=format("u%06X",private)
                end
                unicode=private
                unicodes[name]=private
                if trace_private then
                  report_otf("glyph %a at index %H is moved to private unicode slot %U",name,index,private)
                end
                private=private+1
                nofnames=nofnames+1
              else
                if not name then
                  name=format("u%06X",unicode)
                end
                unicodes[name]=unicode
                nofunicodes=nofunicodes+1
              end
              indices[index]=unicode 
              local description={
                boundingbox=glyph.boundingbox,
                name=glyph.name or name or "unknown",
                cidindex=cidindex,
                index=index,
                glyph=glyph,
              }
              descriptions[unicode]=description
            else
            end
          end
        end
        if trace_loading then
          report_otf("cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes,nofnames,nofunicodes+nofnames)
        end
      elseif trace_loading then
        report_otf("unable to remap cid font, missing cid file for %a",filename)
      end
    elseif trace_loading then
      report_otf("font %a has no glyphs",filename)
    end
  else
    for index=0,raw.glyphcnt-1 do 
      local glyph=rawglyphs[index]
      if glyph then
        local unicode=glyph.unicode
        local name=glyph.name
        if not unicode or unicode==-1 then 
          unicode=private
          unicodes[name]=private
          if trace_private then
            report_otf("glyph %a at index %H is moved to private unicode slot %U",name,index,private)
          end
          private=private+1
        else
          unicodes[name]=unicode
        end
        indices[index]=unicode
        if not name then
          name=format("u%06X",unicode)
        end
        descriptions[unicode]={
          boundingbox=glyph.boundingbox,
          name=name,
          index=index,
          glyph=glyph,
        }
        local altuni=glyph.altuni
        if altuni then
          for i=1,#altuni do
            local a=altuni[i]
            local u=a.unicode
            local v=a.variant
            if v then
              local vv=variants[v]
              if vv then
                vv[u]=unicode
              else 
                vv={ [u]=unicode }
                variants[v]=vv
              end
            end
          end
        end
      else
        report_otf("potential problem: glyph %U is used but empty",index)
      end
    end
  end
  resources.private=private
end
actions["check encoding"]=function(data,filename,raw)
  local descriptions=data.descriptions
  local resources=data.resources
  local properties=data.properties
  local unicodes=resources.unicodes 
  local indices=resources.indices 
  local duplicates=resources.duplicates
  local mapdata=raw.map or {}
  local unicodetoindex=mapdata and mapdata.map or {}
  local indextounicode=mapdata and mapdata.backmap or {}
  local encname=lower(data.enc_name or mapdata.enc_name or "")
  local criterium=0xFFFF 
  local privateoffset=constructors.privateoffset
  if find(encname,"unicode") then 
    if trace_loading then
      report_otf("checking embedded unicode map %a",encname)
    end
    local reported={}
    for maybeunicode,index in next,unicodetoindex do
      if descriptions[maybeunicode] then
      else
        local unicode=indices[index]
        if not unicode then
        elseif maybeunicode==unicode then
        elseif unicode>privateoffset then
        else
          local d=descriptions[unicode]
          if d then
            local c=d.copies
            if c then
              c[maybeunicode]=true
            else
              d.copies={ [maybeunicode]=true }
            end
          elseif index and not reported[index] then
            report_otf("missing index %i",index)
            reported[index]=true
          end
        end
      end
    end
    for unicode,data in next,descriptions do
      local d=data.copies
      if d then
        duplicates[unicode]=sortedkeys(d)
        data.copies=nil
      end
    end
  elseif properties.cidinfo then
    report_otf("warning: no unicode map, used cidmap %a",properties.cidinfo.usedname)
  else
    report_otf("warning: non unicode map %a, only using glyph unicode data",encname or "whatever")
  end
  if mapdata then
    mapdata.map={} 
    mapdata.backmap={} 
  end
end
actions["add duplicates"]=function(data,filename,raw)
  local descriptions=data.descriptions
  local resources=data.resources
  local properties=data.properties
  local unicodes=resources.unicodes 
  local indices=resources.indices 
  local duplicates=resources.duplicates
  for unicode,d in next,duplicates do
    local nofduplicates=#d
    if nofduplicates>4 then
      if trace_loading then
        report_otf("ignoring excessive duplicates of %U (n=%s)",unicode,nofduplicates)
      end
    else
      for i=1,nofduplicates do
        local u=d[i]
        if not descriptions[u] then
          local description=descriptions[unicode]
          local n=0
          for _,description in next,descriptions do
            if kerns then
              local kerns=description.kerns
              for _,k in next,kerns do
                local ku=k[unicode]
                if ku then
                  k[u]=ku
                  n=n+1
                end
              end
            end
          end
          if u>0 then 
            local duplicate=table.copy(description) 
            duplicate.comment=format("copy of U+%05X",unicode)
            descriptions[u]=duplicate
            if trace_loading then
              report_otf("duplicating %U to %U with index %H (%s kerns)",unicode,u,description.index,n)
            end
          end
        end
      end
    end
  end
end
actions["analyze glyphs"]=function(data,filename,raw) 
  local descriptions=data.descriptions
  local resources=data.resources
  local metadata=data.metadata
  local properties=data.properties
  local hasitalics=false
  local widths={}
  local marks={} 
  for unicode,description in next,descriptions do
    local glyph=description.glyph
    local italic=glyph.italic_correction
    if not italic then
    elseif italic==0 then
    else
      description.italic=italic
      hasitalics=true
    end
    local width=glyph.width
    widths[width]=(widths[width] or 0)+1
    local class=glyph.class
    if class then
      if class=="mark" then
        marks[unicode]=true
      end
      description.class=class
    end
  end
  properties.hasitalics=hasitalics
  resources.marks=marks
  local wd,most=0,1
  for k,v in next,widths do
    if v>most then
      wd,most=k,v
    end
  end
  if most>1000 then 
    if trace_loading then
      report_otf("most common width: %s (%s times), sharing (cjk font)",wd,most)
    end
    for unicode,description in next,descriptions do
      if description.width==wd then
      else
        description.width=description.glyph.width
      end
    end
    resources.defaultwidth=wd
  else
    for unicode,description in next,descriptions do
      description.width=description.glyph.width
    end
  end
end
actions["reorganize mark classes"]=function(data,filename,raw)
  local mark_classes=raw.mark_classes
  if mark_classes then
    local resources=data.resources
    local unicodes=resources.unicodes
    local markclasses={}
    resources.markclasses=markclasses 
    for name,class in next,mark_classes do
      local t={}
      for s in gmatch(class,"[^ ]+") do
        t[unicodes[s]]=true
      end
      markclasses[name]=t
    end
  end
end
actions["reorganize features"]=function(data,filename,raw) 
  local features={}
  data.resources.features=features
  for k,what in next,otf.glists do
    local dw=raw[what]
    if dw then
      local f={}
      features[what]=f
      for i=1,#dw do
        local d=dw[i]
        local dfeatures=d.features
        if dfeatures then
          for i=1,#dfeatures do
            local df=dfeatures[i]
            local tag=strip(lower(df.tag))
            local ft=f[tag]
            if not ft then
              ft={}
              f[tag]=ft
            end
            local dscripts=df.scripts
            for i=1,#dscripts do
              local d=dscripts[i]
              local languages=d.langs
              local script=strip(lower(d.script))
              local fts=ft[script] if not fts then fts={} ft[script]=fts end
              for i=1,#languages do
                fts[strip(lower(languages[i]))]=true
              end
            end
          end
        end
      end
    end
  end
end
actions["reorganize anchor classes"]=function(data,filename,raw)
  local resources=data.resources
  local anchor_to_lookup={}
  local lookup_to_anchor={}
  resources.anchor_to_lookup=anchor_to_lookup
  resources.lookup_to_anchor=lookup_to_anchor
  local classes=raw.anchor_classes 
  if classes then
    for c=1,#classes do
      local class=classes[c]
      local anchor=class.name
      local lookups=class.lookup
      if type(lookups)~="table" then
        lookups={ lookups }
      end
      local a=anchor_to_lookup[anchor]
      if not a then
        a={}
        anchor_to_lookup[anchor]=a
      end
      for l=1,#lookups do
        local lookup=lookups[l]
        local l=lookup_to_anchor[lookup]
        if l then
          l[anchor]=true
        else
          l={ [anchor]=true }
          lookup_to_anchor[lookup]=l
        end
        a[lookup]=true
      end
    end
  end
end
actions["prepare tounicode"]=function(data,filename,raw)
  fonts.mappings.addtounicode(data,filename)
end
local g_directions={
  gsub_contextchain=1,
  gpos_contextchain=1,
  gsub_reversecontextchain=-1,
  gpos_reversecontextchain=-1,
}
actions["reorganize subtables"]=function(data,filename,raw)
  local resources=data.resources
  local sequences={}
  local lookups={}
  local chainedfeatures={}
  resources.sequences=sequences
  resources.lookups=lookups
  for _,what in next,otf.glists do
    local dw=raw[what]
    if dw then
      for k=1,#dw do
        local gk=dw[k]
        local features=gk.features
          local typ=gk.type
          local chain=g_directions[typ] or 0
          local subtables=gk.subtables
          if subtables then
            local t={}
            for s=1,#subtables do
              t[s]=subtables[s].name
            end
            subtables=t
          end
          local flags,markclass=gk.flags,nil
          if flags then
            local t={ 
              (flags.ignorecombiningmarks and "mark")   or false,
              (flags.ignoreligatures   and "ligature") or false,
              (flags.ignorebaseglyphs   and "base")   or false,
               flags.r2l                 or false,
            }
            markclass=flags.mark_class
            if markclass then
              markclass=resources.markclasses[markclass]
            end
            flags=t
          end
          local name=gk.name
          if not name then
            report_otf("skipping weird lookup number %s",k)
          elseif features then
            local f={}
            local o={}
            for i=1,#features do
              local df=features[i]
              local tag=strip(lower(df.tag))
              local ft=f[tag]
              if not ft then
                ft={}
                f[tag]=ft
                o[#o+1]=tag
              end
              local dscripts=df.scripts
              for i=1,#dscripts do
                local d=dscripts[i]
                local languages=d.langs
                local script=strip(lower(d.script))
                local fts=ft[script] if not fts then fts={} ft[script]=fts end
                for i=1,#languages do
                  fts[strip(lower(languages[i]))]=true
                end
              end
            end
            sequences[#sequences+1]={
              type=typ,
              chain=chain,
              flags=flags,
              name=name,
              subtables=subtables,
              markclass=markclass,
              features=f,
              order=o,
            }
          else
            lookups[name]={
              type=typ,
              chain=chain,
              flags=flags,
              subtables=subtables,
              markclass=markclass,
            }
          end
      end
    end
  end
end
actions["prepare lookups"]=function(data,filename,raw)
  local lookups=raw.lookups
  if lookups then
    data.lookups=lookups
  end
end
local function t_uncover(splitter,cache,covers)
  local result={}
  for n=1,#covers do
    local cover=covers[n]
    local uncovered=cache[cover]
    if not uncovered then
      uncovered=lpegmatch(splitter,cover)
      cache[cover]=uncovered
    end
    result[n]=uncovered
  end
  return result
end
local function s_uncover(splitter,cache,cover)
  if cover=="" then
    return nil
  else
    local uncovered=cache[cover]
    if not uncovered then
      uncovered=lpegmatch(splitter,cover)
      cache[cover]=uncovered
    end
    return { uncovered }
  end
end
local function t_hashed(t,cache)
  if t then
    local ht={}
    for i=1,#t do
      local ti=t[i]
      local tih=cache[ti]
      if not tih then
        tih={}
        for i=1,#ti do
          tih[ti[i]]=true
        end
        cache[ti]=tih
      end
      ht[i]=tih
    end
    return ht
  else
    return nil
  end
end
local function s_hashed(t,cache)
  if t then
    local ht={}
    local tf=t[1]
    for i=1,#tf do
      ht[i]={ [tf[i]]=true }
    end
    return ht
  else
    return nil
  end
end
local function r_uncover(splitter,cache,cover,replacements)
  if cover=="" then
    return nil
  else
    local uncovered=cover[1]
    local replaced=cache[replacements]
    if not replaced then
      replaced=lpegmatch(splitter,replacements)
      cache[replacements]=replaced
    end
    local nu,nr=#uncovered,#replaced
    local r={}
    if nu==nr then
      for i=1,nu do
        r[uncovered[i]]=replaced[i]
      end
    end
    return r
  end
end
actions["reorganize lookups"]=function(data,filename,raw)
  if data.lookups then
    local splitter=data.helpers.tounicodetable
    local t_u_cache={}
    local s_u_cache=t_u_cache 
    local t_h_cache={}
    local s_h_cache=t_h_cache 
    local r_u_cache={} 
    for _,lookup in next,data.lookups do
      local rules=lookup.rules
      if rules then
        local format=lookup.format
        if format=="class" then
          local before_class=lookup.before_class
          if before_class then
            before_class=t_uncover(splitter,t_u_cache,reversed(before_class))
          end
          local current_class=lookup.current_class
          if current_class then
            current_class=t_uncover(splitter,t_u_cache,current_class)
          end
          local after_class=lookup.after_class
          if after_class then
            after_class=t_uncover(splitter,t_u_cache,after_class)
          end
          for i=1,#rules do
            local rule=rules[i]
            local class=rule.class
            local before=class.before
            if before then
              for i=1,#before do
                before[i]=before_class[before[i]] or {}
              end
              rule.before=t_hashed(before,t_h_cache)
            end
            local current=class.current
            local lookups=rule.lookups
            if current then
              for i=1,#current do
                current[i]=current_class[current[i]] or {}
                if lookups and not lookups[i] then
                  lookups[i]="" 
                end
              end
              rule.current=t_hashed(current,t_h_cache)
            end
            local after=class.after
            if after then
              for i=1,#after do
                after[i]=after_class[after[i]] or {}
              end
              rule.after=t_hashed(after,t_h_cache)
            end
            rule.class=nil
          end
          lookup.before_class=nil
          lookup.current_class=nil
          lookup.after_class=nil
          lookup.format="coverage"
        elseif format=="coverage" then
          for i=1,#rules do
            local rule=rules[i]
            local coverage=rule.coverage
            if coverage then
              local before=coverage.before
              if before then
                before=t_uncover(splitter,t_u_cache,reversed(before))
                rule.before=t_hashed(before,t_h_cache)
              end
              local current=coverage.current
              if current then
                current=t_uncover(splitter,t_u_cache,current)
                local lookups=rule.lookups
                if lookups then
                  for i=1,#current do
                    if not lookups[i] then
                      lookups[i]="" 
                    end
                  end
                end
                rule.current=t_hashed(current,t_h_cache)
              end
              local after=coverage.after
              if after then
                after=t_uncover(splitter,t_u_cache,after)
                rule.after=t_hashed(after,t_h_cache)
              end
              rule.coverage=nil
            end
          end
        elseif format=="reversecoverage" then 
          for i=1,#rules do
            local rule=rules[i]
            local reversecoverage=rule.reversecoverage
            if reversecoverage then
              local before=reversecoverage.before
              if before then
                before=t_uncover(splitter,t_u_cache,reversed(before))
                rule.before=t_hashed(before,t_h_cache)
              end
              local current=reversecoverage.current
              if current then
                current=t_uncover(splitter,t_u_cache,current)
                rule.current=t_hashed(current,t_h_cache)
              end
              local after=reversecoverage.after
              if after then
                after=t_uncover(splitter,t_u_cache,after)
                rule.after=t_hashed(after,t_h_cache)
              end
              local replacements=reversecoverage.replacements
              if replacements then
                rule.replacements=r_uncover(splitter,r_u_cache,current,replacements)
              end
              rule.reversecoverage=nil
            end
          end
        elseif format=="glyphs" then
          for i=1,#rules do
            local rule=rules[i]
            local glyphs=rule.glyphs
            if glyphs then
              local fore=glyphs.fore
              if fore and fore~="" then
                fore=s_uncover(splitter,s_u_cache,fore)
                rule.before=s_hashed(fore,s_h_cache)
              end
              local back=glyphs.back
              if back then
                back=s_uncover(splitter,s_u_cache,back)
                rule.after=s_hashed(back,s_h_cache)
              end
              local names=glyphs.names
              if names then
                names=s_uncover(splitter,s_u_cache,names)
                rule.current=s_hashed(names,s_h_cache)
              end
              rule.glyphs=nil
            end
          end
        end
      end
    end
  end
end
local function check_variants(unicode,the_variants,splitter,unicodes)
  local variants=the_variants.variants
  if variants then 
    local glyphs=lpegmatch(splitter,variants)
    local done={ [unicode]=true }
    local n=0
    for i=1,#glyphs do
      local g=glyphs[i]
      if done[g] then
        report_otf("skipping cyclic reference %U in math variant %U",g,unicode)
      else
        if n==0 then
          n=1
          variants={ g }
        else
          n=n+1
          variants[n]=g
        end
        done[g]=true
      end
    end
    if n==0 then
      variants=nil
    end
  end
  local parts=the_variants.parts
  if parts then
    local p=#parts
    if p>0 then
      for i=1,p do
        local pi=parts[i]
        pi.glyph=unicodes[pi.component] or 0
        pi.component=nil
      end
    else
      parts=nil
    end
  end
  local italic_correction=the_variants.italic_correction
  if italic_correction and italic_correction==0 then
    italic_correction=nil
  end
  return variants,parts,italic_correction
end
actions["analyze math"]=function(data,filename,raw)
  if raw.math then
    data.metadata.math=raw.math
    local unicodes=data.resources.unicodes
    local splitter=data.helpers.tounicodetable
    for unicode,description in next,data.descriptions do
      local glyph=description.glyph
      local mathkerns=glyph.mathkern 
      local horiz_variants=glyph.horiz_variants
      local vert_variants=glyph.vert_variants
      local top_accent=glyph.top_accent
      if mathkerns or horiz_variants or vert_variants or top_accent then
        local math={}
        if top_accent then
          math.top_accent=top_accent
        end
        if mathkerns then
          for k,v in next,mathkerns do
            if not next(v) then
              mathkerns[k]=nil
            else
              for k,v in next,v do
                if v==0 then
                  k[v]=nil 
                end
              end
            end
          end
          math.kerns=mathkerns
        end
        if horiz_variants then
          math.horiz_variants,math.horiz_parts,math.horiz_italic_correction=check_variants(unicode,horiz_variants,splitter,unicodes)
        end
        if vert_variants then
          math.vert_variants,math.vert_parts,math.vert_italic_correction=check_variants(unicode,vert_variants,splitter,unicodes)
        end
        local italic_correction=description.italic
        if italic_correction and italic_correction~=0 then
          math.italic_correction=italic_correction
        end
        description.math=math
      end
    end
  end
end
actions["reorganize glyph kerns"]=function(data,filename,raw)
  local descriptions=data.descriptions
  local resources=data.resources
  local unicodes=resources.unicodes
  for unicode,description in next,descriptions do
    local kerns=description.glyph.kerns
    if kerns then
      local newkerns={}
      for k,kern in next,kerns do
        local name=kern.char
        local offset=kern.off
        local lookup=kern.lookup
        if name and offset and lookup then
          local unicode=unicodes[name]
          if unicode then
            if type(lookup)=="table" then
              for l=1,#lookup do
                local lookup=lookup[l]
                local lookupkerns=newkerns[lookup]
                if lookupkerns then
                  lookupkerns[unicode]=offset
                else
                  newkerns[lookup]={ [unicode]=offset }
                end
              end
            else
              local lookupkerns=newkerns[lookup]
              if lookupkerns then
                lookupkerns[unicode]=offset
              else
                newkerns[lookup]={ [unicode]=offset }
              end
            end
          elseif trace_loading then
            report_otf("problems with unicode %a of kern %a of glyph %U",name,k,unicode)
          end
        end
      end
      description.kerns=newkerns
    end
  end
end
actions["merge kern classes"]=function(data,filename,raw)
  local gposlist=raw.gpos
  if gposlist then
    local descriptions=data.descriptions
    local resources=data.resources
    local unicodes=resources.unicodes
    local splitter=data.helpers.tounicodetable
    local ignored=0
    local blocked=0
    for gp=1,#gposlist do
      local gpos=gposlist[gp]
      local subtables=gpos.subtables
      if subtables then
        local first_done={} 
        local split={} 
        for s=1,#subtables do
          local subtable=subtables[s]
          local kernclass=subtable.kernclass 
          local lookup=subtable.lookup or subtable.name
          if kernclass then 
            if #kernclass>0 then
              kernclass=kernclass[1]
              lookup=type(kernclass.lookup)=="string" and kernclass.lookup or lookup
              report_otf("fixing kernclass table of lookup %a",lookup)
            end
            local firsts=kernclass.firsts
            local seconds=kernclass.seconds
            local offsets=kernclass.offsets
            for n,s in next,firsts do
              split[s]=split[s] or lpegmatch(splitter,s)
            end
            local maxseconds=0
            for n,s in next,seconds do
              if n>maxseconds then
                maxseconds=n
              end
              split[s]=split[s] or lpegmatch(splitter,s)
            end
            for fk=1,#firsts do 
              local fv=firsts[fk]
              local splt=split[fv]
              if splt then
                local extrakerns={}
                local baseoffset=(fk-1)*maxseconds
                for sk=2,maxseconds do 
                  local sv=seconds[sk]
                  local splt=split[sv]
                  if splt then 
                    local offset=offsets[baseoffset+sk]
                    if offset then
                      for i=1,#splt do
                        extrakerns[splt[i]]=offset
                      end
                    end
                  end
                end
                for i=1,#splt do
                  local first_unicode=splt[i]
                  if first_done[first_unicode] then
                    report_otf("lookup %a: ignoring further kerns of %C",lookup,first_unicode)
                    blocked=blocked+1
                  else
                    first_done[first_unicode]=true
                    local description=descriptions[first_unicode]
                    if description then
                      local kerns=description.kerns
                      if not kerns then
                        kerns={} 
                        description.kerns=kerns
                      end
                      local lookupkerns=kerns[lookup]
                      if not lookupkerns then
                        lookupkerns={}
                        kerns[lookup]=lookupkerns
                      end
                      if overloadkerns then
                        for second_unicode,kern in next,extrakerns do
                          lookupkerns[second_unicode]=kern
                        end
                      else
                        for second_unicode,kern in next,extrakerns do
                          local k=lookupkerns[second_unicode]
                          if not k then
                            lookupkerns[second_unicode]=kern
                          elseif k~=kern then
                            if trace_loading then
                              report_otf("lookup %a: ignoring overload of kern between %C and %C, rejecting %a, keeping %a",lookup,first_unicode,second_unicode,k,kern)
                            end
                            ignored=ignored+1
                          end
                        end
                      end
                    elseif trace_loading then
                      report_otf("no glyph data for %U",first_unicode)
                    end
                  end
                end
              end
            end
            subtable.kernclass={}
          end
        end
      end
    end
    if ignored>0 then
      report_otf("%s kern overloads ignored",ignored)
    end
    if blocked>0 then
      report_otf("%s succesive kerns blocked",blocked)
    end
  end
end
actions["check glyphs"]=function(data,filename,raw)
  for unicode,description in next,data.descriptions do
    description.glyph=nil
  end
end
actions["check metadata"]=function(data,filename,raw)
  local metadata=data.metadata
  for _,k in next,mainfields do
    if valid_fields[k] then
      local v=raw[k]
      if not metadata[k] then
        metadata[k]=v
      end
    end
  end
  local ttftables=metadata.ttf_tables
  if ttftables then
    for i=1,#ttftables do
      ttftables[i].data="deleted"
    end
  end
  if metadata.validation_state and table.contains(metadata.validation_state,"bad_ps_fontname") then
    local name=file.nameonly(filename)
    metadata.fontname="bad-fontname-"..name
    metadata.fullname="bad-fullname-"..name
  end
end
actions["cleanup tables"]=function(data,filename,raw)
  data.resources.indices=nil 
  data.helpers=nil
end
actions["reorganize glyph lookups"]=function(data,filename,raw)
  local resources=data.resources
  local unicodes=resources.unicodes
  local descriptions=data.descriptions
  local splitter=data.helpers.tounicodelist
  local lookuptypes=resources.lookuptypes
  for unicode,description in next,descriptions do
    local lookups=description.glyph.lookups
    if lookups then
      for tag,lookuplist in next,lookups do
        for l=1,#lookuplist do
          local lookup=lookuplist[l]
          local specification=lookup.specification
          local lookuptype=lookup.type
          local lt=lookuptypes[tag]
          if not lt then
            lookuptypes[tag]=lookuptype
          elseif lt~=lookuptype then
            report_otf("conflicting lookuptypes, %a points to %a and %a",tag,lt,lookuptype)
          end
          if lookuptype=="ligature" then
            lookuplist[l]={ lpegmatch(splitter,specification.components) }
          elseif lookuptype=="alternate" then
            lookuplist[l]={ lpegmatch(splitter,specification.components) }
          elseif lookuptype=="substitution" then
            lookuplist[l]=unicodes[specification.variant]
          elseif lookuptype=="multiple" then
            lookuplist[l]={ lpegmatch(splitter,specification.components) }
          elseif lookuptype=="position" then
            lookuplist[l]={
              specification.x or 0,
              specification.y or 0,
              specification.h or 0,
              specification.v or 0
            }
          elseif lookuptype=="pair" then
            local one=specification.offsets[1]
            local two=specification.offsets[2]
            local paired=unicodes[specification.paired]
            if one then
              if two then
                lookuplist[l]={ paired,{ one.x or 0,one.y or 0,one.h or 0,one.v or 0 },{ two.x or 0,two.y or 0,two.h or 0,two.v or 0 } }
              else
                lookuplist[l]={ paired,{ one.x or 0,one.y or 0,one.h or 0,one.v or 0 } }
              end
            else
              if two then
                lookuplist[l]={ paired,{},{ two.x or 0,two.y or 0,two.h or 0,two.v or 0} } 
              else
                lookuplist[l]={ paired }
              end
            end
          end
        end
      end
      local slookups,mlookups
      for tag,lookuplist in next,lookups do
        if #lookuplist==1 then
          if slookups then
            slookups[tag]=lookuplist[1]
          else
            slookups={ [tag]=lookuplist[1] }
          end
        else
          if mlookups then
            mlookups[tag]=lookuplist
          else
            mlookups={ [tag]=lookuplist }
          end
        end
      end
      if slookups then
        description.slookups=slookups
      end
      if mlookups then
        description.mlookups=mlookups
      end
    end
  end
end
actions["reorganize glyph anchors"]=function(data,filename,raw) 
  local descriptions=data.descriptions
  for unicode,description in next,descriptions do
    local anchors=description.glyph.anchors
    if anchors then
      for class,data in next,anchors do
        if class=="baselig" then
          for tag,specification in next,data do
            for i=1,#specification do
              local si=specification[i]
              specification[i]={ si.x or 0,si.y or 0 }
            end
          end
        else
          for tag,specification in next,data do
            data[tag]={ specification.x or 0,specification.y or 0 }
          end
        end
      end
      description.anchors=anchors
    end
  end
end
function otf.setfeatures(tfmdata,features)
  local okay=constructors.initializefeatures("otf",tfmdata,features,trace_features,report_otf)
  if okay then
    return constructors.collectprocessors("otf",tfmdata,features,trace_features,report_otf)
  else
    return {} 
  end
end
local function copytotfm(data,cache_id)
  if data then
    local metadata=data.metadata
    local resources=data.resources
    local properties=derivetable(data.properties)
    local descriptions=derivetable(data.descriptions)
    local goodies=derivetable(data.goodies)
    local characters={}
    local parameters={}
    local mathparameters={}
    local pfminfo=metadata.pfminfo or {}
    local resources=data.resources
    local unicodes=resources.unicodes
    local spaceunits=500
    local spacer="space"
    local designsize=metadata.designsize or metadata.design_size or 100
    local mathspecs=metadata.math
    if designsize==0 then
      designsize=100
    end
    if mathspecs then
      for name,value in next,mathspecs do
        mathparameters[name]=value
      end
    end
    for unicode,_ in next,data.descriptions do 
      characters[unicode]={}
    end
    if mathspecs then
      for unicode,character in next,characters do
        local d=descriptions[unicode]
        local m=d.math
        if m then
          local variants=m.horiz_variants
          local parts=m.horiz_parts
          if variants then
            local c=character
            for i=1,#variants do
              local un=variants[i]
                c.next=un
                c=characters[un]
            end 
            c.horiz_variants=parts
          elseif parts then
            character.horiz_variants=parts
          end
          local variants=m.vert_variants
          local parts=m.vert_parts
          if variants then
            local c=character
            for i=1,#variants do
              local un=variants[i]
                c.next=un
                c=characters[un]
            end 
            c.vert_variants=parts
          elseif parts then
            character.vert_variants=parts
          end
          local italic_correction=m.vert_italic_correction
          if italic_correction then
            character.vert_italic_correction=italic_correction 
          end
          local top_accent=m.top_accent
          if top_accent then
            character.top_accent=top_accent
          end
          local kerns=m.kerns
          if kerns then
            character.mathkerns=kerns
          end
        end
      end
    end
    local filename=constructors.checkedfilename(resources)
    local fontname=metadata.fontname
    local fullname=metadata.fullname or fontname
    local units=metadata.units_per_em or 1000
    if units==0 then 
      units=1000 
      metadata.units_per_em=1000
      report_otf("changing %a units to %a",0,units)
    end
    local monospaced=metadata.isfixedpitch or (pfminfo.panose and pfminfo.panose.proportion=="Monospaced")
    local charwidth=pfminfo.avgwidth 
    local charxheight=pfminfo.os2_xheight and pfminfo.os2_xheight>0 and pfminfo.os2_xheight
    local italicangle=metadata.italicangle
    properties.monospaced=monospaced
    parameters.italicangle=italicangle
    parameters.charwidth=charwidth
    parameters.charxheight=charxheight
    local space=0x0020 
    local emdash=0x2014 
    if monospaced then
      if descriptions[space] then
        spaceunits,spacer=descriptions[space].width,"space"
      end
      if not spaceunits and descriptions[emdash] then
        spaceunits,spacer=descriptions[emdash].width,"emdash"
      end
      if not spaceunits and charwidth then
        spaceunits,spacer=charwidth,"charwidth"
      end
    else
      if descriptions[space] then
        spaceunits,spacer=descriptions[space].width,"space"
      end
      if not spaceunits and descriptions[emdash] then
        spaceunits,spacer=descriptions[emdash].width/2,"emdash/2"
      end
      if not spaceunits and charwidth then
        spaceunits,spacer=charwidth,"charwidth"
      end
    end
    spaceunits=tonumber(spaceunits) or 500
    parameters.slant=0
    parameters.space=spaceunits     
    parameters.space_stretch=units/2  
    parameters.space_shrink=1*units/3 
    parameters.x_height=2*units/5 
    parameters.quad=units   
    if spaceunits<2*units/5 then
    end
    if italicangle and italicangle~=0 then
      parameters.italicangle=italicangle
      parameters.italicfactor=math.cos(math.rad(90+italicangle))
      parameters.slant=- math.tan(italicangle*math.pi/180)
    end
    if monospaced then
      parameters.space_stretch=0
      parameters.space_shrink=0
    elseif syncspace then 
      parameters.space_stretch=spaceunits/2
      parameters.space_shrink=spaceunits/3
    end
    parameters.extra_space=parameters.space_shrink 
    if charxheight then
      parameters.x_height=charxheight
    else
      local x=0x78 
      if x then
        local x=descriptions[x]
        if x then
          parameters.x_height=x.height
        end
      end
    end
    parameters.designsize=(designsize/10)*65536
    parameters.ascender=abs(metadata.ascent or 0)
    parameters.descender=abs(metadata.descent or 0)
    parameters.units=units
    properties.space=spacer
    properties.encodingbytes=2
    properties.format=data.format or otf_format(filename) or formats.otf
    properties.noglyphnames=true
    properties.filename=filename
    properties.fontname=fontname
    properties.fullname=fullname
    properties.psname=fontname or fullname
    properties.name=filename or fullname
    return {
      characters=characters,
      descriptions=descriptions,
      parameters=parameters,
      mathparameters=mathparameters,
      resources=resources,
      properties=properties,
      goodies=goodies,
    }
  end
end
local function otftotfm(specification)
  local cache_id=specification.hash
  local tfmdata=containers.read(constructors.cache,cache_id)
  if not tfmdata then
    local name=specification.name
    local sub=specification.sub
    local filename=specification.filename
    local features=specification.features.normal
    local rawdata=otf.load(filename,sub,features and features.featurefile)
    if rawdata and next(rawdata) then
      local descriptions=rawdata.descriptions
      local duplicates=rawdata.resources.duplicates
      if duplicates then
        local nofduplicates,nofduplicated=0,0
        for parent,list in next,duplicates do
          for i=1,#list do
            local unicode=list[i]
            if not descriptions[unicode] then
              descriptions[unicode]=descriptions[parent] 
              nofduplicated=nofduplicated+1
            end
          end
          nofduplicates=nofduplicates+#list
        end
        if trace_otf and nofduplicated~=nofduplicates then
          report_otf("%i extra duplicates copied out of %i",nofduplicated,nofduplicates)
        end
      end
      rawdata.lookuphash={}
      tfmdata=copytotfm(rawdata,cache_id)
      if tfmdata and next(tfmdata) then
        local features=constructors.checkedfeatures("otf",features)
        local shared=tfmdata.shared
        if not shared then
          shared={}
          tfmdata.shared=shared
        end
        shared.rawdata=rawdata
        shared.dynamics={}
        tfmdata.changed={}
        shared.features=features
        shared.processes=otf.setfeatures(tfmdata,features)
      end
    end
    containers.write(constructors.cache,cache_id,tfmdata)
  end
  return tfmdata
end
local function read_from_otf(specification)
  local tfmdata=otftotfm(specification)
  if tfmdata then
    tfmdata.properties.name=specification.name
    tfmdata.properties.sub=specification.sub
    tfmdata=constructors.scale(tfmdata,specification)
    local allfeatures=tfmdata.shared.features or specification.features.normal
    constructors.applymanipulators("otf",tfmdata,allfeatures,trace_features,report_otf)
    constructors.setname(tfmdata,specification) 
    fonts.loggers.register(tfmdata,file.suffix(specification.filename),specification)
  end
  return tfmdata
end
local function checkmathsize(tfmdata,mathsize)
  local mathdata=tfmdata.shared.rawdata.metadata.math
  local mathsize=tonumber(mathsize)
  if mathdata then 
    local parameters=tfmdata.parameters
    parameters.scriptpercentage=mathdata.ScriptPercentScaleDown
    parameters.scriptscriptpercentage=mathdata.ScriptScriptPercentScaleDown
    parameters.mathsize=mathsize
  end
end
registerotffeature {
  name="mathsize",
  description="apply mathsize specified in the font",
  initializers={
    base=checkmathsize,
    node=checkmathsize,
  }
}
function otf.collectlookups(rawdata,kind,script,language)
  local sequences=rawdata.resources.sequences
  if sequences then
    local featuremap,featurelist={},{}
    for s=1,#sequences do
      local sequence=sequences[s]
      local features=sequence.features
      features=features and features[kind]
      features=features and (features[script]  or features[default] or features[wildcard])
      features=features and (features[language] or features[default] or features[wildcard])
      if features then
        local subtables=sequence.subtables
        if subtables then
          for s=1,#subtables do
            local ss=subtables[s]
            if not featuremap[s] then
              featuremap[ss]=true
              featurelist[#featurelist+1]=ss
            end
          end
        end
      end
    end
    if #featurelist>0 then
      return featuremap,featurelist
    end
  end
  return nil,nil
end
local function check_otf(forced,specification,suffix)
  local name=specification.name
  if forced then
    name=specification.forcedname 
  end
  local fullname=findbinfile(name,suffix) or ""
  if fullname=="" then
    fullname=fonts.names.getfilename(name,suffix) or ""
  end
  if fullname~="" and not fonts.names.ignoredfile(fullname) then
    specification.filename=fullname
    return read_from_otf(specification)
  end
end
local function opentypereader(specification,suffix)
  local forced=specification.forced or ""
  if formats[forced] then
    return check_otf(true,specification,forced)
  else
    return check_otf(false,specification,suffix)
  end
end
readers.opentype=opentypereader 
function readers.otf (specification) return opentypereader(specification,"otf") end
function readers.ttf (specification) return opentypereader(specification,"ttf") end
function readers.ttc (specification) return opentypereader(specification,"ttf") end
function readers.dfont(specification) return opentypereader(specification,"ttf") end
function otf.scriptandlanguage(tfmdata,attr)
  local properties=tfmdata.properties
  return properties.script or "dflt",properties.language or "dflt"
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otb']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local concat=table.concat
local format,gmatch,gsub,find,match,lower,strip=string.format,string.gmatch,string.gsub,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring=type,next,tonumber,tostring
local lpegmatch=lpeg.match
local utfchar=utf.char
local trace_baseinit=false trackers.register("otf.baseinit",function(v) trace_baseinit=v end)
local trace_singles=false trackers.register("otf.singles",function(v) trace_singles=v end)
local trace_multiples=false trackers.register("otf.multiples",function(v) trace_multiples=v end)
local trace_alternatives=false trackers.register("otf.alternatives",function(v) trace_alternatives=v end)
local trace_ligatures=false trackers.register("otf.ligatures",function(v) trace_ligatures=v end)
local trace_ligatures_detail=false trackers.register("otf.ligatures.detail",function(v) trace_ligatures_detail=v end)
local trace_kerns=false trackers.register("otf.kerns",function(v) trace_kerns=v end)
local trace_preparing=false trackers.register("otf.preparing",function(v) trace_preparing=v end)
local report_prepare=logs.reporter("fonts","otf prepare")
local fonts=fonts
local otf=fonts.handlers.otf
local otffeatures=otf.features
local registerotffeature=otffeatures.register
otf.defaultbasealternate="none" 
local wildcard="*"
local default="dflt"
local formatters=string.formatters
local f_unicode=formatters["%U"]
local f_uniname=formatters["%U (%s)"]
local f_unilist=formatters["% t (% t)"]
local function gref(descriptions,n)
  if type(n)=="number" then
    local name=descriptions[n].name
    if name then
      return f_uniname(n,name)
    else
      return f_unicode(n)
    end
  elseif n then
    local num,nam,j={},{},0
    for i=1,#n do
      local ni=n[i]
      if tonumber(ni) then 
        j=j+1
        local di=descriptions[ni]
        num[j]=f_unicode(ni)
        nam[j]=di and di.name or "-"
      end
    end
    return f_unilist(num,nam)
  else
    return "<error in base mode tracing>"
  end
end
local function cref(feature,lookupname)
  if lookupname then
    return formatters["feature %a, lookup %a"](feature,lookupname)
  else
    return formatters["feature %a"](feature)
  end
end
local function report_alternate(feature,lookupname,descriptions,unicode,replacement,value,comment)
  report_prepare("%s: base alternate %s => %s (%S => %S)",
    cref(feature,lookupname),
    gref(descriptions,unicode),
    replacement and gref(descriptions,replacement),
    value,
    comment)
end
local function report_substitution(feature,lookupname,descriptions,unicode,substitution)
  report_prepare("%s: base substitution %s => %S",
    cref(feature,lookupname),
    gref(descriptions,unicode),
    gref(descriptions,substitution))
end
local function report_ligature(feature,lookupname,descriptions,unicode,ligature)
  report_prepare("%s: base ligature %s => %S",
    cref(feature,lookupname),
    gref(descriptions,ligature),
    gref(descriptions,unicode))
end
local function report_kern(feature,lookupname,descriptions,unicode,otherunicode,value)
  report_prepare("%s: base kern %s + %s => %S",
    cref(feature,lookupname),
    gref(descriptions,unicode),
    gref(descriptions,otherunicode),
    value)
end
local basemethods={}
local basemethod="<unset>"
local function applybasemethod(what,...)
  local m=basemethods[basemethod][what]
  if m then
    return m(...)
  end
end
local basehash,basehashes,applied={},1,{}
local function registerbasehash(tfmdata)
  local properties=tfmdata.properties
  local hash=concat(applied," ")
  local base=basehash[hash]
  if not base then
    basehashes=basehashes+1
    base=basehashes
    basehash[hash]=base
  end
  properties.basehash=base
  properties.fullname=properties.fullname.."-"..base
  applied={}
end
local function registerbasefeature(feature,value)
  applied[#applied+1]=feature.."="..tostring(value)
end
local trace=false
local function finalize_ligatures(tfmdata,ligatures)
  local nofligatures=#ligatures
  if nofligatures>0 then
    local characters=tfmdata.characters
    local descriptions=tfmdata.descriptions
    local resources=tfmdata.resources
    local unicodes=resources.unicodes
    local private=resources.private
    local alldone=false
    while not alldone do
      local done=0
      for i=1,nofligatures do
        local ligature=ligatures[i]
        if ligature then
          local unicode,lookupdata=ligature[1],ligature[2]
          if trace_ligatures_detail then
            report_prepare("building % a into %a",lookupdata,unicode)
          end
          local size=#lookupdata
          local firstcode=lookupdata[1] 
          local firstdata=characters[firstcode]
          local okay=false
          if firstdata then
            local firstname="ctx_"..firstcode
            for i=1,size-1 do 
              local firstdata=characters[firstcode]
              if not firstdata then
                firstcode=private
                if trace_ligatures_detail then
                  report_prepare("defining %a as %a",firstname,firstcode)
                end
                unicodes[firstname]=firstcode
                firstdata={ intermediate=true,ligatures={} }
                characters[firstcode]=firstdata
                descriptions[firstcode]={ name=firstname }
                private=private+1
              end
              local target
              local secondcode=lookupdata[i+1]
              local secondname=firstname.."_"..secondcode
              if i==size-1 then
                target=unicode
                if not unicodes[secondname] then
                  unicodes[secondname]=unicode 
                end
                okay=true
              else
                target=unicodes[secondname]
                if not target then
                  break
                end
              end
              if trace_ligatures_detail then
                report_prepare("codes (%a,%a) + (%a,%a) -> %a",firstname,firstcode,secondname,secondcode,target)
              end
              local firstligs=firstdata.ligatures
              if firstligs then
                firstligs[secondcode]={ char=target }
              else
                firstdata.ligatures={ [secondcode]={ char=target } }
              end
              firstcode=target
              firstname=secondname
            end
          elseif trace_ligatures_detail then
            report_prepare("no glyph (%a,%a) for building %a",firstname,firstcode,target)
          end
          if okay then
            ligatures[i]=false
            done=done+1
          end
        end
      end
      alldone=done==0
    end
    if trace_ligatures_detail then
      for k,v in table.sortedhash(characters) do
        if v.ligatures then
          table.print(v,k)
        end
      end
    end
    resources.private=private
  end
end
local function preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local resources=tfmdata.resources
  local changed=tfmdata.changed
  local unicodes=resources.unicodes
  local lookuphash=resources.lookuphash
  local lookuptypes=resources.lookuptypes
  local ligatures={}
  local alternate=tonumber(value)
  local defaultalt=otf.defaultbasealternate
  local trace_singles=trace_baseinit and trace_singles
  local trace_alternatives=trace_baseinit and trace_alternatives
  local trace_ligatures=trace_baseinit and trace_ligatures
  local actions={
    substitution=function(lookupdata,lookupname,description,unicode)
      if trace_singles then
        report_substitution(feature,lookupname,descriptions,unicode,lookupdata)
      end
      changed[unicode]=lookupdata
    end,
    alternate=function(lookupdata,lookupname,description,unicode)
      local replacement=lookupdata[alternate]
      if replacement then
        changed[unicode]=replacement
        if trace_alternatives then
          report_alternate(feature,lookupname,descriptions,unicode,replacement,value,"normal")
        end
      elseif defaultalt=="first" then
        replacement=lookupdata[1]
        changed[unicode]=replacement
        if trace_alternatives then
          report_alternate(feature,lookupname,descriptions,unicode,replacement,value,defaultalt)
        end
      elseif defaultalt=="last" then
        replacement=lookupdata[#data]
        if trace_alternatives then
          report_alternate(feature,lookupname,descriptions,unicode,replacement,value,defaultalt)
        end
      else
        if trace_alternatives then
          report_alternate(feature,lookupname,descriptions,unicode,replacement,value,"unknown")
        end
      end
    end,
    ligature=function(lookupdata,lookupname,description,unicode)
      if trace_ligatures then
        report_ligature(feature,lookupname,descriptions,unicode,lookupdata)
      end
      ligatures[#ligatures+1]={ unicode,lookupdata }
    end,
  }
  for unicode,character in next,characters do
    local description=descriptions[unicode]
    local lookups=description.slookups
    if lookups then
      for l=1,#lookuplist do
        local lookupname=lookuplist[l]
        local lookupdata=lookups[lookupname]
        if lookupdata then
          local lookuptype=lookuptypes[lookupname]
          local action=actions[lookuptype]
          if action then
            action(lookupdata,lookupname,description,unicode)
          end
        end
      end
    end
    local lookups=description.mlookups
    if lookups then
      for l=1,#lookuplist do
        local lookupname=lookuplist[l]
        local lookuplist=lookups[lookupname]
        if lookuplist then
          local lookuptype=lookuptypes[lookupname]
          local action=actions[lookuptype]
          if action then
            for i=1,#lookuplist do
              action(lookuplist[i],lookupname,description,unicode)
            end
          end
        end
      end
    end
  end
  finalize_ligatures(tfmdata,ligatures)
end
local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist) 
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local resources=tfmdata.resources
  local unicodes=resources.unicodes
  local sharedkerns={}
  local traceindeed=trace_baseinit and trace_kerns
  for unicode,character in next,characters do
    local description=descriptions[unicode]
    local rawkerns=description.kerns 
    if rawkerns then
      local s=sharedkerns[rawkerns]
      if s==false then
      elseif s then
        character.kerns=s
      else
        local newkerns=character.kerns
        local done=false
        for l=1,#lookuplist do
          local lookup=lookuplist[l]
          local kerns=rawkerns[lookup]
          if kerns then
            for otherunicode,value in next,kerns do
              if value==0 then
              elseif not newkerns then
                newkerns={ [otherunicode]=value }
                done=true
                if traceindeed then
                  report_kern(feature,lookup,descriptions,unicode,otherunicode,value)
                end
              elseif not newkerns[otherunicode] then 
                newkerns[otherunicode]=value
                done=true
                if traceindeed then
                  report_kern(feature,lookup,descriptions,unicode,otherunicode,value)
                end
              end
            end
          end
        end
        if done then
          sharedkerns[rawkerns]=newkerns
          character.kerns=newkerns 
        else
          sharedkerns[rawkerns]=false
        end
      end
    end
  end
end
basemethods.independent={
  preparesubstitutions=preparesubstitutions,
  preparepositionings=preparepositionings,
}
local function makefake(tfmdata,name,present)
  local resources=tfmdata.resources
  local private=resources.private
  local character={ intermediate=true,ligatures={} }
  resources.unicodes[name]=private
  tfmdata.characters[private]=character
  tfmdata.descriptions[private]={ name=name }
  resources.private=private+1
  present[name]=private
  return character
end
local function make_1(present,tree,name)
  for k,v in next,tree do
    if k=="ligature" then
      present[name]=v
    else
      make_1(present,v,name.."_"..k)
    end
  end
end
local function make_2(present,tfmdata,characters,tree,name,preceding,unicode,done,lookupname)
  for k,v in next,tree do
    if k=="ligature" then
      local character=characters[preceding]
      if not character then
        if trace_baseinit then
          report_prepare("weird ligature in lookup %a, current %C, preceding %C",lookupname,v,preceding)
        end
        character=makefake(tfmdata,name,present)
      end
      local ligatures=character.ligatures
      if ligatures then
        ligatures[unicode]={ char=v }
      else
        character.ligatures={ [unicode]={ char=v } }
      end
      if done then
        local d=done[lookupname]
        if not d then
          done[lookupname]={ "dummy",v }
        else
          d[#d+1]=v
        end
      end
    else
      local code=present[name] or unicode
      local name=name.."_"..k
      make_2(present,tfmdata,characters,v,name,code,k,done,lookupname)
    end
  end
end
local function preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local resources=tfmdata.resources
  local changed=tfmdata.changed
  local lookuphash=resources.lookuphash
  local lookuptypes=resources.lookuptypes
  local ligatures={}
  local alternate=tonumber(value)
  local defaultalt=otf.defaultbasealternate
  local trace_singles=trace_baseinit and trace_singles
  local trace_alternatives=trace_baseinit and trace_alternatives
  local trace_ligatures=trace_baseinit and trace_ligatures
  for l=1,#lookuplist do
    local lookupname=lookuplist[l]
    local lookupdata=lookuphash[lookupname]
    local lookuptype=lookuptypes[lookupname]
    for unicode,data in next,lookupdata do
      if lookuptype=="substitution" then
        if trace_singles then
          report_substitution(feature,lookupname,descriptions,unicode,data)
        end
        changed[unicode]=data
      elseif lookuptype=="alternate" then
         local replacement=data[alternate]
        if replacement then
          changed[unicode]=replacement
          if trace_alternatives then
            report_alternate(feature,lookupname,descriptions,unicode,replacement,value,"normal")
          end
        elseif defaultalt=="first" then
          replacement=data[1]
          changed[unicode]=replacement
          if trace_alternatives then
            report_alternate(feature,lookupname,descriptions,unicode,replacement,value,defaultalt)
          end
        elseif defaultalt=="last" then
          replacement=data[#data]
          if trace_alternatives then
            report_alternate(feature,lookupname,descriptions,unicode,replacement,value,defaultalt)
          end
        else
          if trace_alternatives then
            report_alternate(feature,lookupname,descriptions,unicode,replacement,value,"unknown")
          end
        end
      elseif lookuptype=="ligature" then
        ligatures[#ligatures+1]={ unicode,data,lookupname }
        if trace_ligatures then
          report_ligature(feature,lookupname,descriptions,unicode,data)
        end
      end
    end
  end
  local nofligatures=#ligatures
  if nofligatures>0 then
    local characters=tfmdata.characters
    local present={}
    local done=trace_baseinit and trace_ligatures and {}
    for i=1,nofligatures do
      local ligature=ligatures[i]
      local unicode,tree=ligature[1],ligature[2]
      make_1(present,tree,"ctx_"..unicode)
    end
    for i=1,nofligatures do
      local ligature=ligatures[i]
      local unicode,tree,lookupname=ligature[1],ligature[2],ligature[3]
      make_2(present,tfmdata,characters,tree,"ctx_"..unicode,unicode,unicode,done,lookupname)
    end
  end
end
local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist)
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local resources=tfmdata.resources
  local lookuphash=resources.lookuphash
  local traceindeed=trace_baseinit and trace_kerns
  for l=1,#lookuplist do
    local lookupname=lookuplist[l]
    local lookupdata=lookuphash[lookupname]
    for unicode,data in next,lookupdata do
      local character=characters[unicode]
      local kerns=character.kerns
      if not kerns then
        kerns={}
        character.kerns=kerns
      end
      if traceindeed then
        for otherunicode,kern in next,data do
          if not kerns[otherunicode] and kern~=0 then
            kerns[otherunicode]=kern
            report_kern(feature,lookup,descriptions,unicode,otherunicode,kern)
          end
        end
      else
        for otherunicode,kern in next,data do
          if not kerns[otherunicode] and kern~=0 then
            kerns[otherunicode]=kern
          end
        end
      end
    end
  end
end
local function initializehashes(tfmdata)
  nodeinitializers.features(tfmdata)
end
basemethods.shared={
  initializehashes=initializehashes,
  preparesubstitutions=preparesubstitutions,
  preparepositionings=preparepositionings,
}
basemethod="independent"
local function featuresinitializer(tfmdata,value)
  if true then 
    local starttime=trace_preparing and os.clock()
    local features=tfmdata.shared.features
    local fullname=trace_preparing and tfmdata.properties.fullname
    if features then
      applybasemethod("initializehashes",tfmdata)
      local collectlookups=otf.collectlookups
      local rawdata=tfmdata.shared.rawdata
      local properties=tfmdata.properties
      local script=properties.script
      local language=properties.language
      local basesubstitutions=rawdata.resources.features.gsub
      local basepositionings=rawdata.resources.features.gpos
      if basesubstitutions or basepositionings then
        local sequences=tfmdata.resources.sequences
        for s=1,#sequences do
          local sequence=sequences[s]
          local sfeatures=sequence.features
          if sfeatures then
            local order=sequence.order
            if order then
              for i=1,#order do 
                local feature=order[i]
                if features[feature] then
                  local validlookups,lookuplist=collectlookups(rawdata,feature,script,language)
                  if not validlookups then
                  elseif basesubstitutions and basesubstitutions[feature] then
                    if trace_preparing then
                      report_prepare("filtering base feature %a for %a",feature,fullname)
                    end
                    applybasemethod("preparesubstitutions",tfmdata,feature,value,validlookups,lookuplist)
                    registerbasefeature(feature,value)
                  elseif basepositionings and basepositionings[feature] then
                    if trace_preparing then
                      report_prepare("filtering base feature %a for %a",feature,fullname)
                    end
                    applybasemethod("preparepositionings",tfmdata,feature,features[feature],validlookups,lookuplist)
                    registerbasefeature(feature,value)
                  end
                end
              end
            end
          end
        end
      end
      registerbasehash(tfmdata)
    end
    if trace_preparing then
      report_prepare("preparation time is %0.3f seconds for %a",os.clock()-starttime,fullname)
    end
  end
end
registerotffeature {
  name="features",
  description="features",
  default=true,
  initializers={
    base=featuresinitializer,
  }
}
directives.register("fonts.otf.loader.basemethod",function(v)
  if basemethods[v] then
    basemethod=v
  end
end)

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['node-inj']={
  version=1.001,
  comment="companion to node-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files",
}
local next=next
local utfchar=utf.char
local trace_injections=false trackers.register("nodes.injections",function(v) trace_injections=v end)
local report_injections=logs.reporter("nodes","injections")
local attributes,nodes,node=attributes,nodes,node
fonts=fonts
local fontdata=fonts.hashes.identifiers
nodes.injections=nodes.injections or {}
local injections=nodes.injections
local nodecodes=nodes.nodecodes
local glyph_code=nodecodes.glyph
local kern_code=nodecodes.kern
local nodepool=nodes.pool
local newkern=nodepool.kern
local traverse_id=node.traverse_id
local insert_node_before=node.insert_before
local insert_node_after=node.insert_after
local a_kernpair=attributes.private('kernpair')
local a_ligacomp=attributes.private('ligacomp')
local a_markbase=attributes.private('markbase')
local a_markmark=attributes.private('markmark')
local a_markdone=attributes.private('markdone')
local a_cursbase=attributes.private('cursbase')
local a_curscurs=attributes.private('curscurs')
local a_cursdone=attributes.private('cursdone')
function injections.installnewkern(nk)
  newkern=nk or newkern
end
local cursives={}
local marks={}
local kerns={}
function injections.setcursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext)
  local dx,dy=factor*(exit[1]-entry[1]),factor*(exit[2]-entry[2])
  local ws,wn=tfmstart.width,tfmnext.width
  local bound=#cursives+1
  start[a_cursbase]=bound
  nxt[a_curscurs]=bound
  cursives[bound]={ rlmode,dx,dy,ws,wn }
  return dx,dy,bound
end
function injections.setpair(current,factor,rlmode,r2lflag,spec,tfmchr)
  local x,y,w,h=factor*spec[1],factor*spec[2],factor*spec[3],factor*spec[4]
  if x~=0 or w~=0 or y~=0 or h~=0 then
    local bound=current[a_kernpair]
    if bound then
      local kb=kerns[bound]
      kb[2],kb[3],kb[4],kb[5]=(kb[2] or 0)+x,(kb[3] or 0)+y,(kb[4] or 0)+w,(kb[5] or 0)+h
    else
      bound=#kerns+1
      current[a_kernpair]=bound
      kerns[bound]={ rlmode,x,y,w,h,r2lflag,tfmchr.width }
    end
    return x,y,w,h,bound
  end
  return x,y,w,h 
end
function injections.setkern(current,factor,rlmode,x,tfmchr)
  local dx=factor*x
  if dx~=0 then
    local bound=#kerns+1
    current[a_kernpair]=bound
    kerns[bound]={ rlmode,dx }
    return dx,bound
  else
    return 0,0
  end
end
function injections.setmark(start,base,factor,rlmode,ba,ma) 
  local dx,dy=factor*(ba[1]-ma[1]),factor*(ba[2]-ma[2])
  local bound=base[a_markbase]
  local index=1
  if bound then
    local mb=marks[bound]
    if mb then
      index=#mb+1
      mb[index]={ dx,dy,rlmode }
      start[a_markmark]=bound
      start[a_markdone]=index
      return dx,dy,bound
    else
      report_injections("possible problem, %U is base mark without data (id %a)",base.char,bound)
    end
  end
  index=index or 1
  bound=#marks+1
  base[a_markbase]=bound
  start[a_markmark]=bound
  start[a_markdone]=index
  marks[bound]={ [index]={ dx,dy,rlmode } }
  return dx,dy,bound
end
local function dir(n)
  return (n and n<0 and "r-to-l") or (n and n>0 and "l-to-r") or "unset"
end
local function trace(head)
  report_injections("begin run")
  for n in traverse_id(glyph_code,head) do
    if n.subtype<256 then
      local kp=n[a_kernpair]
      local mb=n[a_markbase]
      local mm=n[a_markmark]
      local md=n[a_markdone]
      local cb=n[a_cursbase]
      local cc=n[a_curscurs]
      local char=n.char
      report_injections("font %s, char %U, glyph %c",n.font,char,char)
      if kp then
        local k=kerns[kp]
        if k[3] then
          report_injections("  pairkern: dir %a, x %p, y %p, w %p, h %p",dir(k[1]),k[2],k[3],k[4],k[5])
        else
          report_injections("  kern: dir %a, dx %p",dir(k[1]),k[2])
        end
      end
      if mb then
        report_injections("  markbase: bound %a",mb)
      end
      if mm then
        local m=marks[mm]
        if mb then
          local m=m[mb]
          if m then
            report_injections("  markmark: bound %a, index %a, dx %p, dy %p",mm,md,m[1],m[2])
          else
            report_injections("  markmark: bound %a, missing index",mm)
          end
        else
          m=m[1]
          report_injections("  markmark: bound %a, dx %p, dy %p",mm,m and m[1],m and m[2])
        end
      end
      if cb then
        report_injections("  cursbase: bound %a",cb)
      end
      if cc then
        local c=cursives[cc]
        report_injections("  curscurs: bound %a, dir %a, dx %p, dy %p",cc,dir(c[1]),c[2],c[3])
      end
    end
  end
  report_injections("end run")
end
local function show_result(head)
  local current=head
  local skipping=false
  while current do
    local id=current.id
    if id==glyph_code then
      report_injections("char: %C, width %p, xoffset %p, yoffset %p",current.char,current.width,current.xoffset,current.yoffset)
      skipping=false
    elseif id==kern_code then
      report_injections("kern: %p",current.kern)
      skipping=false
    elseif not skipping then
      report_injections()
      skipping=true
    end
    current=current.next
  end
end
function injections.handler(head,where,keep)
  local has_marks,has_cursives,has_kerns=next(marks),next(cursives),next(kerns)
  if has_marks or has_cursives then
    if trace_injections then
      trace(head)
    end
    local done,ky,rl,valid,cx,wx,mk,nofvalid=false,{},{},{},{},{},{},0
    if has_kerns then 
      local nf,tm=nil,nil
      for n in traverse_id(glyph_code,head) do 
        if n.subtype<256 then
          nofvalid=nofvalid+1
          valid[nofvalid]=n
          if n.font~=nf then
            nf=n.font
            tm=fontdata[nf].resources.marks
          end
          if tm then
            mk[n]=tm[n.char]
          end
          local k=n[a_kernpair]
          if k then
            local kk=kerns[k]
            if kk then
              local x,y,w,h=kk[2] or 0,kk[3] or 0,kk[4] or 0,kk[5] or 0
              local dy=y-h
              if dy~=0 then
                ky[n]=dy
              end
              if w~=0 or x~=0 then
                wx[n]=kk
              end
              rl[n]=kk[1] 
            end
          end
        end
      end
    else
      local nf,tm=nil,nil
      for n in traverse_id(glyph_code,head) do
        if n.subtype<256 then
          nofvalid=nofvalid+1
          valid[nofvalid]=n
          if n.font~=nf then
            nf=n.font
            tm=fontdata[nf].resources.marks
          end
          if tm then
            mk[n]=tm[n.char]
          end
        end
      end
    end
    if nofvalid>0 then
      local cx={}
      if has_kerns and next(ky) then
        for n,k in next,ky do
          n.yoffset=k
        end
      end
      if has_cursives then
        local p_cursbase,p=nil,nil
        local t,d,maxt={},{},0
        for i=1,nofvalid do 
          local n=valid[i]
          if not mk[n] then
            local n_cursbase=n[a_cursbase]
            if p_cursbase then
              local n_curscurs=n[a_curscurs]
              if p_cursbase==n_curscurs then
                local c=cursives[n_curscurs]
                if c then
                  local rlmode,dx,dy,ws,wn=c[1],c[2],c[3],c[4],c[5]
                  if rlmode>=0 then
                    dx=dx-ws
                  else
                    dx=dx+wn
                  end
                  if dx~=0 then
                    cx[n]=dx
                    rl[n]=rlmode
                  end
                    dy=-dy
                  maxt=maxt+1
                  t[maxt]=p
                  d[maxt]=dy
                else
                  maxt=0
                end
              end
            elseif maxt>0 then
              local ny=n.yoffset
              for i=maxt,1,-1 do
                ny=ny+d[i]
                local ti=t[i]
                ti.yoffset=ti.yoffset+ny
              end
              maxt=0
            end
            if not n_cursbase and maxt>0 then
              local ny=n.yoffset
              for i=maxt,1,-1 do
                ny=ny+d[i]
                local ti=t[i]
                ti.yoffset=ny
              end
              maxt=0
            end
            p_cursbase,p=n_cursbase,n
          end
        end
        if maxt>0 then
          local ny=n.yoffset
          for i=maxt,1,-1 do
            ny=ny+d[i]
            local ti=t[i]
            ti.yoffset=ny
          end
          maxt=0
        end
        if not keep then
          cursives={}
        end
      end
      if has_marks then
        for i=1,nofvalid do
          local p=valid[i]
          local p_markbase=p[a_markbase]
          if p_markbase then
            local mrks=marks[p_markbase]
            local nofmarks=#mrks
            for n in traverse_id(glyph_code,p.next) do
              local n_markmark=n[a_markmark]
              if p_markbase==n_markmark then
                local index=n[a_markdone] or 1
                local d=mrks[index]
                if d then
                  local rlmode=d[3]
                  local k=wx[p]
                  if k then
                    local x=k[2]
                    local w=k[4]
                    if w then
                      if rlmode and rlmode>=0 then
                        n.xoffset=p.xoffset-p.width+d[1]-(w-x)
                      else
                        n.xoffset=p.xoffset-d[1]-x
                      end
                    else
                      if rlmode and rlmode>=0 then
                        n.xoffset=p.xoffset-p.width+d[1]
                      else
                        n.xoffset=p.xoffset-d[1]-x
                      end
                    end
                  else
                    if rlmode and rlmode>=0 then
                      n.xoffset=p.xoffset-p.width+d[1]
                    else
                      n.xoffset=p.xoffset-d[1]
                    end
                    local w=n.width
                    if w~=0 then
                      insert_node_before(head,n,newkern(-w/2))
                      insert_node_after(head,n,newkern(-w/2))
                    end
                  end
                  if mk[p] then
                    n.yoffset=p.yoffset+d[2]
                  else
                    n.yoffset=n.yoffset+p.yoffset+d[2]
                  end
                  if nofmarks==1 then
                    break
                  else
                    nofmarks=nofmarks-1
                  end
                end
              else
              end
            end
          end
        end
        if not keep then
          marks={}
        end
      end
      if next(wx) then
        for n,k in next,wx do
          local x=k[2]
          local w=k[4]
          if w then
            local rl=k[1] 
            local wx=w-x
            if rl<0 then	
              if wx~=0 then
                insert_node_before(head,n,newkern(wx)) 
              end
              if x~=0 then
                insert_node_after (head,n,newkern(x)) 
              end
            else
              if x~=0 then
                insert_node_before(head,n,newkern(x)) 
              end
              if wx~=0 then
                insert_node_after (head,n,newkern(wx)) 
              end
            end
          elseif x~=0 then
            insert_node_before(head,n,newkern(x)) 
          end
        end
      end
      if next(cx) then
        for n,k in next,cx do
          if k~=0 then
            local rln=rl[n]
            if rln and rln<0 then
              insert_node_before(head,n,newkern(-k)) 
            else
              insert_node_before(head,n,newkern(k)) 
            end
          end
        end
      end
      if not keep then
        kerns={}
      end
      return head,true
    elseif not keep then
      kerns,cursives,marks={},{},{}
    end
  elseif has_kerns then
    if trace_injections then
      trace(head)
    end
    for n in traverse_id(glyph_code,head) do
      if n.subtype<256 then
        local k=n[a_kernpair]
        if k then
          local kk=kerns[k]
          if kk then
            local rl,x,y,w=kk[1],kk[2] or 0,kk[3],kk[4]
            if y and y~=0 then
              n.yoffset=y 
            end
            if w then
              local wx=w-x
              if rl<0 then 
                if wx~=0 then
                  insert_node_before(head,n,newkern(wx))
                end
                if x~=0 then
                  insert_node_after (head,n,newkern(x))
                end
              else
                if x~=0 then
                  insert_node_before(head,n,newkern(x))
                end
                if wx~=0 then
                  insert_node_after(head,n,newkern(wx))
                end
              end
            else
              if x~=0 then
                insert_node_before(head,n,newkern(x))
              end
            end
          end
        end
      end
    end
    if not keep then
      kerns={}
    end
    return head,true
  else
  end
  return head,false
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-ota']={
  version=1.001,
  comment="companion to font-otf.lua (analysing)",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local type=type
if not trackers then trackers={ register=function() end } end
local fonts,nodes,node=fonts,nodes,node
local allocate=utilities.storage.allocate
local otf=fonts.handlers.otf
local analyzers=fonts.analyzers
local initializers=allocate()
local methods=allocate()
analyzers.initializers=initializers
analyzers.methods=methods
analyzers.useunicodemarks=false
local a_state=attributes.private('state')
local nodecodes=nodes.nodecodes
local glyph_code=nodecodes.glyph
local disc_code=nodecodes.disc
local math_code=nodecodes.math
local traverse_id=node.traverse_id
local traverse_node_list=node.traverse
local end_of_math=node.end_of_math
local fontdata=fonts.hashes.identifiers
local categories=characters and characters.categories or {} 
local otffeatures=fonts.constructors.newfeatures("otf")
local registerotffeature=otffeatures.register
local s_init=1  local s_rphf=7
local s_medi=2  local s_half=8
local s_fina=3  local s_pref=9
local s_isol=4  local s_blwf=10
local s_mark=5  local s_pstf=11
local s_rest=6
local states={
  init=s_init,
  medi=s_medi,
  fina=s_fina,
  isol=s_isol,
  mark=s_mark,
  rest=s_rest,
  rphf=s_rphf,
  half=s_half,
  pref=s_pref,
  blwf=s_blwf,
  pstf=s_pstf,
}
local features={
  init=s_init,
  medi=s_medi,
  fina=s_fina,
  isol=s_isol,
  rphf=s_rphf,
  half=s_half,
  pref=s_pref,
  blwf=s_blwf,
  pstf=s_pstf,
}
analyzers.states=states
analyzers.features=features
function analyzers.setstate(head,font)
  local useunicodemarks=analyzers.useunicodemarks
  local tfmdata=fontdata[font]
  local descriptions=tfmdata.descriptions
  local first,last,current,n,done=nil,nil,head,0,false 
  while current do
    local id=current.id
    if id==glyph_code and current.font==font then
      done=true
      local char=current.char
      local d=descriptions[char]
      if d then
        if d.class=="mark" or (useunicodemarks and categories[char]=="mn") then
          done=true
          current[a_state]=s_mark
        elseif n==0 then
          first,last,n=current,current,1
          current[a_state]=s_init
        else
          last,n=current,n+1
          current[a_state]=s_medi
        end
      else 
        if first and first==last then
          last[a_state]=s_isol
        elseif last then
          last[a_state]=s_fina
        end
        first,last,n=nil,nil,0
      end
    elseif id==disc_code then
      current[a_state]=s_medi
      last=current
    else 
      if first and first==last then
        last[a_state]=s_isol
      elseif last then
        last[a_state]=s_fina
      end
      first,last,n=nil,nil,0
      if id==math_code then
        current=end_of_math(current)
      end
    end
    current=current.next
  end
  if first and first==last then
    last[a_state]=s_isol
  elseif last then
    last[a_state]=s_fina
  end
  return head,done
end
local function analyzeinitializer(tfmdata,value) 
  local script,language=otf.scriptandlanguage(tfmdata) 
  local action=initializers[script]
  if not action then
  elseif type(action)=="function" then
    return action(tfmdata,value)
  else
    local action=action[language]
    if action then
      return action(tfmdata,value)
    end
  end
end
local function analyzeprocessor(head,font,attr)
  local tfmdata=fontdata[font]
  local script,language=otf.scriptandlanguage(tfmdata,attr)
  local action=methods[script]
  if not action then
  elseif type(action)=="function" then
    return action(head,font,attr)
  else
    action=action[language]
    if action then
      return action(head,font,attr)
    end
  end
  return head,false
end
registerotffeature {
  name="analyze",
  description="analysis of character classes",
  default=true,
  initializers={
    node=analyzeinitializer,
  },
  processors={
    position=1,
    node=analyzeprocessor,
  }
}
methods.latn=analyzers.setstate
local tatweel=0x0640
local zwnj=0x200C
local zwj=0x200D
local isolated={ 
  [0x0600]=true,[0x0601]=true,[0x0602]=true,[0x0603]=true,
  [0x0604]=true,
  [0x0608]=true,[0x060B]=true,[0x0621]=true,[0x0674]=true,
  [0x06DD]=true,
  [0x0856]=true,[0x0858]=true,[0x0857]=true,
  [0x07FA]=true,
  [zwnj]=true,
}
local final={ 
  [0x0622]=true,[0x0623]=true,[0x0624]=true,[0x0625]=true,
  [0x0627]=true,[0x0629]=true,[0x062F]=true,[0x0630]=true,
  [0x0631]=true,[0x0632]=true,[0x0648]=true,[0x0671]=true,
  [0x0672]=true,[0x0673]=true,[0x0675]=true,[0x0676]=true,
  [0x0677]=true,[0x0688]=true,[0x0689]=true,[0x068A]=true,
  [0x068B]=true,[0x068C]=true,[0x068D]=true,[0x068E]=true,
  [0x068F]=true,[0x0690]=true,[0x0691]=true,[0x0692]=true,
  [0x0693]=true,[0x0694]=true,[0x0695]=true,[0x0696]=true,
  [0x0697]=true,[0x0698]=true,[0x0699]=true,[0x06C0]=true,
  [0x06C3]=true,[0x06C4]=true,[0x06C5]=true,[0x06C6]=true,
  [0x06C7]=true,[0x06C8]=true,[0x06C9]=true,[0x06CA]=true,
  [0x06CB]=true,[0x06CD]=true,[0x06CF]=true,[0x06D2]=true,
  [0x06D3]=true,[0x06D5]=true,[0x06EE]=true,[0x06EF]=true,
  [0x0759]=true,[0x075A]=true,[0x075B]=true,[0x076B]=true,
  [0x076C]=true,[0x0771]=true,[0x0773]=true,[0x0774]=true,
	[0x0778]=true,[0x0779]=true,
  [0x08AA]=true,[0x08AB]=true,[0x08AC]=true,
  [0xFEF5]=true,[0xFEF7]=true,[0xFEF9]=true,[0xFEFB]=true,
	[0x0710]=true,[0x0715]=true,[0x0716]=true,[0x0717]=true,
	[0x0718]=true,[0x0719]=true,[0x0728]=true,[0x072A]=true,
	[0x072C]=true,[0x071E]=true,
  [0x072F]=true,[0x074D]=true,
  [0x0840]=true,[0x0849]=true,[0x0854]=true,[0x0846]=true,
  [0x084F]=true
}
local medial={ 
  [0x0626]=true,[0x0628]=true,[0x062A]=true,[0x062B]=true,
  [0x062C]=true,[0x062D]=true,[0x062E]=true,[0x0633]=true,
  [0x0634]=true,[0x0635]=true,[0x0636]=true,[0x0637]=true,
  [0x0638]=true,[0x0639]=true,[0x063A]=true,[0x063B]=true,
  [0x063C]=true,[0x063D]=true,[0x063E]=true,[0x063F]=true,
  [0x0641]=true,[0x0642]=true,[0x0643]=true,
  [0x0644]=true,[0x0645]=true,[0x0646]=true,[0x0647]=true,
  [0x0649]=true,[0x064A]=true,[0x066E]=true,[0x066F]=true,
  [0x0678]=true,[0x0679]=true,[0x067A]=true,[0x067B]=true,
  [0x067C]=true,[0x067D]=true,[0x067E]=true,[0x067F]=true,
  [0x0680]=true,[0x0681]=true,[0x0682]=true,[0x0683]=true,
  [0x0684]=true,[0x0685]=true,[0x0686]=true,[0x0687]=true,
  [0x069A]=true,[0x069B]=true,[0x069C]=true,[0x069D]=true,
  [0x069E]=true,[0x069F]=true,[0x06A0]=true,[0x06A1]=true,
  [0x06A2]=true,[0x06A3]=true,[0x06A4]=true,[0x06A5]=true,
  [0x06A6]=true,[0x06A7]=true,[0x06A8]=true,[0x06A9]=true,
  [0x06AA]=true,[0x06AB]=true,[0x06AC]=true,[0x06AD]=true,
  [0x06AE]=true,[0x06AF]=true,[0x06B0]=true,[0x06B1]=true,
  [0x06B2]=true,[0x06B3]=true,[0x06B4]=true,[0x06B5]=true,
  [0x06B6]=true,[0x06B7]=true,[0x06B8]=true,[0x06B9]=true,
  [0x06BA]=true,[0x06BB]=true,[0x06BC]=true,[0x06BD]=true,
  [0x06BE]=true,[0x06BF]=true,[0x06C1]=true,[0x06C2]=true,
  [0x06CC]=true,[0x06CE]=true,[0x06D0]=true,[0x06D1]=true,
  [0x06FA]=true,[0x06FB]=true,[0x06FC]=true,[0x06FF]=true,
  [0x0750]=true,[0x0751]=true,[0x0752]=true,[0x0753]=true,
  [0x0754]=true,[0x0755]=true,[0x0756]=true,[0x0757]=true,
  [0x0758]=true,[0x075C]=true,[0x075D]=true,[0x075E]=true,
  [0x075F]=true,[0x0760]=true,[0x0761]=true,[0x0762]=true,
  [0x0763]=true,[0x0764]=true,[0x0765]=true,[0x0766]=true,
  [0x0767]=true,[0x0768]=true,[0x0769]=true,[0x076A]=true,
  [0x076D]=true,[0x076E]=true,[0x076F]=true,[0x0770]=true,
  [0x0772]=true,[0x0775]=true,[0x0776]=true,[0x0777]=true,
  [0x077A]=true,[0x077B]=true,[0x077C]=true,[0x077D]=true,
  [0x077E]=true,[0x077F]=true,
  [0x08A0]=true,[0x08A2]=true,[0x08A4]=true,[0x08A5]=true,
  [0x08A6]=true,[0x0620]=true,[0x08A8]=true,[0x08A9]=true,
  [0x08A7]=true,[0x08A3]=true,
  [0x0712]=true,[0x0713]=true,[0x0714]=true,[0x071A]=true,
  [0x071B]=true,[0x071C]=true,[0x071D]=true,[0x071F]=true,
  [0x0720]=true,[0x0721]=true,[0x0722]=true,[0x0723]=true,
  [0x0724]=true,[0x0725]=true,[0x0726]=true,[0x0727]=true,
  [0x0729]=true,[0x072B]=true,[0x072D]=true,[0x072E]=true,
  [0x074E]=true,[0x074F]=true,
  [0x0841]=true,[0x0842]=true,[0x0843]=true,[0x0844]=true,
  [0x0845]=true,[0x0847]=true,[0x0848]=true,[0x0855]=true,
  [0x0851]=true,[0x084E]=true,[0x084D]=true,[0x084A]=true,
  [0x084B]=true,[0x084C]=true,[0x0850]=true,[0x0852]=true,
  [0x0853]=true,
  [0x07D7]=true,[0x07E8]=true,[0x07D9]=true,[0x07EA]=true,
  [0x07CA]=true,[0x07DB]=true,[0x07CC]=true,[0x07DD]=true,
  [0x07CE]=true,[0x07DF]=true,[0x07D4]=true,[0x07E5]=true,
  [0x07E9]=true,[0x07E7]=true,[0x07E3]=true,[0x07E2]=true,
  [0x07E0]=true,[0x07E1]=true,[0x07DE]=true,[0x07DC]=true,
  [0x07D1]=true,[0x07DA]=true,[0x07D8]=true,[0x07D6]=true,
  [0x07D2]=true,[0x07D0]=true,[0x07CF]=true,[0x07CD]=true,
  [0x07CB]=true,[0x07D3]=true,[0x07E4]=true,[0x07D5]=true,
  [0x07E6]=true,
  [tatweel]=true,
  [zwj]=true,
}
local arab_warned={}
local function warning(current,what)
  local char=current.char
  if not arab_warned[char] then
    log.report("analyze","arab: character %C has no %a class",char,what)
    arab_warned[char]=true
  end
end
local function finish(first,last)
  if last then
    if first==last then
      local fc=first.char
      if medial[fc] or final[fc] then
        first[a_state]=s_isol
      else
        warning(first,"isol")
        first[a_state]=s_error
      end
    else
      local lc=last.char
      if medial[lc] or final[lc] then
        last[a_state]=s_fina
      else
        warning(last,"fina")
        last[a_state]=s_error
      end
    end
    first,last=nil,nil
  elseif first then
    local fc=first.char
    if medial[fc] or final[fc] then
      first[a_state]=s_isol
    else
      warning(first,"isol")
      first[a_state]=s_error
    end
    first=nil
  end
  return first,last
end
function methods.arab(head,font,attr)
  local useunicodemarks=analyzers.useunicodemarks
  local tfmdata=fontdata[font]
  local marks=tfmdata.resources.marks
  local first,last,current,done=nil,nil,head,false
  while current do
    local id=current.id
    if id==glyph_code and current.font==font and current.subtype<256 and not current[a_state] then
      done=true
      local char=current.char
      if marks[char] or (useunicodemarks and categories[char]=="mn") then
        current[a_state]=s_mark
      elseif isolated[char] then 
        first,last=finish(first,last)
        current[a_state]=s_isol
        first,last=nil,nil
      elseif not first then
        if medial[char] then
          current[a_state]=s_init
          first,last=first or current,current
        elseif final[char] then
          current[a_state]=s_isol
          first,last=nil,nil
        else 
          first,last=finish(first,last)
        end
      elseif medial[char] then
        first,last=first or current,current
        current[a_state]=s_medi
      elseif final[char] then
        if not last[a_state]==s_init then
          last[a_state]=s_medi
        end
        current[a_state]=s_fina
        first,last=nil,nil
      elseif char>=0x0600 and char<=0x06FF then 
        current[a_state]=s_rest
        first,last=finish(first,last)
      else 
        first,last=finish(first,last)
      end
    else
      if first or last then
        first,last=finish(first,last)
      end
      if id==math_code then
        current=end_of_math(current)
      end
    end
    current=current.next
  end
  if first or last then
    finish(first,last)
  end
  return head,done
end
methods.syrc=methods.arab
methods.mand=methods.arab
methods.nko=methods.arab
directives.register("otf.analyze.useunicodemarks",function(v)
  analyzers.useunicodemarks=v
end)

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otn']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files",
}
local concat,insert,remove=table.concat,table.insert,table.remove
local gmatch,gsub,find,match,lower,strip=string.gmatch,string.gsub,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring=type,next,tonumber,tostring
local lpegmatch=lpeg.match
local random=math.random
local formatters=string.formatters
local logs,trackers,nodes,attributes=logs,trackers,nodes,attributes
local registertracker=trackers.register
local fonts=fonts
local otf=fonts.handlers.otf
local trace_lookups=false registertracker("otf.lookups",function(v) trace_lookups=v end)
local trace_singles=false registertracker("otf.singles",function(v) trace_singles=v end)
local trace_multiples=false registertracker("otf.multiples",function(v) trace_multiples=v end)
local trace_alternatives=false registertracker("otf.alternatives",function(v) trace_alternatives=v end)
local trace_ligatures=false registertracker("otf.ligatures",function(v) trace_ligatures=v end)
local trace_contexts=false registertracker("otf.contexts",function(v) trace_contexts=v end)
local trace_marks=false registertracker("otf.marks",function(v) trace_marks=v end)
local trace_kerns=false registertracker("otf.kerns",function(v) trace_kerns=v end)
local trace_cursive=false registertracker("otf.cursive",function(v) trace_cursive=v end)
local trace_preparing=false registertracker("otf.preparing",function(v) trace_preparing=v end)
local trace_bugs=false registertracker("otf.bugs",function(v) trace_bugs=v end)
local trace_details=false registertracker("otf.details",function(v) trace_details=v end)
local trace_applied=false registertracker("otf.applied",function(v) trace_applied=v end)
local trace_steps=false registertracker("otf.steps",function(v) trace_steps=v end)
local trace_skips=false registertracker("otf.skips",function(v) trace_skips=v end)
local trace_directions=false registertracker("otf.directions",function(v) trace_directions=v end)
local report_direct=logs.reporter("fonts","otf direct")
local report_subchain=logs.reporter("fonts","otf subchain")
local report_chain=logs.reporter("fonts","otf chain")
local report_process=logs.reporter("fonts","otf process")
local report_prepare=logs.reporter("fonts","otf prepare")
local report_warning=logs.reporter("fonts","otf warning")
registertracker("otf.verbose_chain",function(v) otf.setcontextchain(v and "verbose") end)
registertracker("otf.normal_chain",function(v) otf.setcontextchain(v and "normal") end)
registertracker("otf.replacements","otf.singles,otf.multiples,otf.alternatives,otf.ligatures")
registertracker("otf.positions","otf.marks,otf.kerns,otf.cursive")
registertracker("otf.actions","otf.replacements,otf.positions")
registertracker("otf.injections","nodes.injections")
registertracker("*otf.sample","otf.steps,otf.actions,otf.analyzing")
local insert_node_after=node.insert_after
local delete_node=nodes.delete
local copy_node=node.copy
local find_node_tail=node.tail or node.slide
local flush_node_list=node.flush_list
local end_of_math=node.end_of_math
local setmetatableindex=table.setmetatableindex
local zwnj=0x200C
local zwj=0x200D
local wildcard="*"
local default="dflt"
local nodecodes=nodes.nodecodes
local whatcodes=nodes.whatcodes
local glyphcodes=nodes.glyphcodes
local disccodes=nodes.disccodes
local glyph_code=nodecodes.glyph
local glue_code=nodecodes.glue
local disc_code=nodecodes.disc
local whatsit_code=nodecodes.whatsit
local math_code=nodecodes.math
local dir_code=whatcodes.dir
local localpar_code=whatcodes.localpar
local discretionary_code=disccodes.discretionary
local ligature_code=glyphcodes.ligature
local privateattribute=attributes.private
local a_state=privateattribute('state')
local a_markbase=privateattribute('markbase')
local a_markmark=privateattribute('markmark')
local a_markdone=privateattribute('markdone') 
local a_cursbase=privateattribute('cursbase')
local a_curscurs=privateattribute('curscurs')
local a_cursdone=privateattribute('cursdone')
local a_kernpair=privateattribute('kernpair')
local a_ligacomp=privateattribute('ligacomp') 
local injections=nodes.injections
local setmark=injections.setmark
local setcursive=injections.setcursive
local setkern=injections.setkern
local setpair=injections.setpair
local markonce=true
local cursonce=true
local kernonce=true
local fonthashes=fonts.hashes
local fontdata=fonthashes.identifiers
local otffeatures=fonts.constructors.newfeatures("otf")
local registerotffeature=otffeatures.register
local onetimemessage=fonts.loggers.onetimemessage or function() end
otf.defaultnodealternate="none"
local tfmdata=false
local characters=false
local descriptions=false
local resources=false
local marks=false
local currentfont=false
local lookuptable=false
local anchorlookups=false
local lookuptypes=false
local handlers={}
local rlmode=0
local featurevalue=false
local checkstep=(nodes and nodes.tracers and nodes.tracers.steppers.check)  or function() end
local registerstep=(nodes and nodes.tracers and nodes.tracers.steppers.register) or function() end
local registermessage=(nodes and nodes.tracers and nodes.tracers.steppers.message) or function() end
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  report_direct(...)
end
local function logwarning(...)
  report_direct(...)
end
local f_unicode=formatters["%U"]
local f_uniname=formatters["%U (%s)"]
local f_unilist=formatters["% t (% t)"]
local function gref(n) 
  if type(n)=="number" then
    local description=descriptions[n]
    local name=description and description.name
    if name then
      return f_uniname(n,name)
    else
      return f_unicode(n)
    end
  elseif n then
    local num,nam={},{}
    for i=1,#n do
      local ni=n[i]
      if tonumber(ni) then 
        local di=descriptions[ni]
        num[i]=f_unicode(ni)
        nam[i]=di and di.name or "-"
      end
    end
    return f_unilist(num,nam)
  else
    return "<error in node mode tracing>"
  end
end
local function cref(kind,chainname,chainlookupname,lookupname,index) 
  if index then
    return formatters["feature %a, chain %a, sub %a, lookup %a, index %a"](kind,chainname,chainlookupname,lookupname,index)
  elseif lookupname then
    return formatters["feature %a, chain %a, sub %a, lookup %a"](kind,chainname,chainlookupname,lookupname)
  elseif chainlookupname then
    return formatters["feature %a, chain %a, sub %a"](kind,chainname,chainlookupname)
  elseif chainname then
    return formatters["feature %a, chain %a"](kind,chainname)
  else
    return formatters["feature %a"](kind)
  end
end
local function pref(kind,lookupname)
  return formatters["feature %a, lookup %a"](kind,lookupname)
end
local function copy_glyph(g) 
  local components=g.components
  if components then
    g.components=nil
    local n=copy_node(g)
    g.components=components
    return n
  else
    return copy_node(g)
  end
end
local function markstoligature(kind,lookupname,head,start,stop,char)
  if start==stop and start.char==char then
    return head,start
  else
    local prev=start.prev
    local next=stop.next
    start.prev=nil
    stop.next=nil
    local base=copy_glyph(start)
    if head==start then
      head=base
    end
    base.char=char
    base.subtype=ligature_code
    base.components=start
    if prev then
      prev.next=base
    end
    if next then
      next.prev=base
    end
    base.next=next
    base.prev=prev
    return head,base
  end
end
local function getcomponentindex(start)
  if start.id~=glyph_code then
    return 0
  elseif start.subtype==ligature_code then
    local i=0
    local components=start.components
    while components do
      i=i+getcomponentindex(components)
      components=components.next
    end
    return i
  elseif not marks[start.char] then
    return 1
  else
    return 0
  end
end
local function toligature(kind,lookupname,head,start,stop,char,markflag,discfound) 
  if start==stop and start.char==char then
    start.char=char
    return head,start
  end
  local prev=start.prev
  local next=stop.next
  start.prev=nil
  stop.next=nil
  local base=copy_glyph(start)
  if start==head then
    head=base
  end
  base.char=char
  base.subtype=ligature_code
  base.components=start 
  if prev then
    prev.next=base
  end
  if next then
    next.prev=base
  end
  base.next=next
  base.prev=prev
  if not discfound then
    local deletemarks=markflag~="mark"
    local components=start
    local baseindex=0
    local componentindex=0
    local head=base
    local current=base
    while start do
      local char=start.char
      if not marks[char] then
        baseindex=baseindex+componentindex
        componentindex=getcomponentindex(start)
      elseif not deletemarks then 
        start[a_ligacomp]=baseindex+(start[a_ligacomp] or componentindex)
        if trace_marks then
          logwarning("%s: keep mark %s, gets index %s",pref(kind,lookupname),gref(char),start[a_ligacomp])
        end
        head,current=insert_node_after(head,current,copy_node(start)) 
      elseif trace_marks then
        logwarning("%s: delete mark %s",pref(kind,lookupname),gref(char))
      end
      start=start.next
    end
    local start=current.next
    while start and start.id==glyph_code do
      local char=start.char
      if marks[char] then
        start[a_ligacomp]=baseindex+(start[a_ligacomp] or componentindex)
        if trace_marks then
          logwarning("%s: set mark %s, gets index %s",pref(kind,lookupname),gref(char),start[a_ligacomp])
        end
      else
        break
      end
      start=start.next
    end
  end
  return head,base
end
function handlers.gsub_single(head,start,kind,lookupname,replacement)
  if trace_singles then
    logprocess("%s: replacing %s by single %s",pref(kind,lookupname),gref(start.char),gref(replacement))
  end
  start.char=replacement
  return head,start,true
end
local function get_alternative_glyph(start,alternatives,value,trace_alternatives)
  local n=#alternatives
  if value=="random" then
    local r=random(1,n)
    return alternatives[r],trace_alternatives and formatters["value %a, taking %a"](value,r)
  elseif value=="first" then
    return alternatives[1],trace_alternatives and formatters["value %a, taking %a"](value,1)
  elseif value=="last" then
    return alternatives[n],trace_alternatives and formatters["value %a, taking %a"](value,n)
  else
    value=tonumber(value)
    if type(value)~="number" then
      return alternatives[1],trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
    elseif value>n then
      local defaultalt=otf.defaultnodealternate
      if defaultalt=="first" then
        return alternatives[n],trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
      elseif defaultalt=="last" then
        return alternatives[1],trace_alternatives and formatters["invalid value %s, taking %a"](value,n)
      else
        return false,trace_alternatives and formatters["invalid value %a, %s"](value,"out of range")
      end
    elseif value==0 then
      return start.char,trace_alternatives and formatters["invalid value %a, %s"](value,"no change")
    elseif value<1 then
      return alternatives[1],trace_alternatives and formatters["invalid value %a, taking %a"](value,1)
    else
      return alternatives[value],trace_alternatives and formatters["value %a, taking %a"](value,value)
    end
  end
end
local function multiple_glyphs(head,start,multiple,ignoremarks)
  local nofmultiples=#multiple
  if nofmultiples>0 then
    start.char=multiple[1]
    if nofmultiples>1 then
      local sn=start.next
      for k=2,nofmultiples do
        local n=copy_node(start) 
        n.char=multiple[k]
        n.next=sn
        n.prev=start
        if sn then
          sn.prev=n
        end
        start.next=n
        start=n
      end
    end
    return head,start,true
  else
    if trace_multiples then
      logprocess("no multiple for %s",gref(start.char))
    end
    return head,start,false
  end
end
function handlers.gsub_alternate(head,start,kind,lookupname,alternative,sequence)
  local value=featurevalue==true and tfmdata.shared.features[kind] or featurevalue
  local choice,comment=get_alternative_glyph(start,alternative,value,trace_alternatives)
  if choice then
    if trace_alternatives then
      logprocess("%s: replacing %s by alternative %a to %s, %s",pref(kind,lookupname),gref(start.char),choice,gref(choice),comment)
    end
    start.char=choice
  else
    if trace_alternatives then
      logwarning("%s: no variant %a for %s, %s",pref(kind,lookupname),value,gref(start.char),comment)
    end
  end
  return head,start,true
end
function handlers.gsub_multiple(head,start,kind,lookupname,multiple,sequence)
  if trace_multiples then
    logprocess("%s: replacing %s by multiple %s",pref(kind,lookupname),gref(start.char),gref(multiple))
  end
  return multiple_glyphs(head,start,multiple,sequence.flags[1])
end
function handlers.gsub_ligature(head,start,kind,lookupname,ligature,sequence)
  local s,stop,discfound=start.next,nil,false
  local startchar=start.char
  if marks[startchar] then
    while s do
      local id=s.id
      if id==glyph_code and s.font==currentfont and s.subtype<256 then
        local lg=ligature[s.char]
        if lg then
          stop=s
          ligature=lg
          s=s.next
        else
          break
        end
      else
        break
      end
    end
    if stop then
      local lig=ligature.ligature
      if lig then
        if trace_ligatures then
          local stopchar=stop.char
          head,start=markstoligature(kind,lookupname,head,start,stop,lig)
          logprocess("%s: replacing %s upto %s by ligature %s case 1",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(start.char))
        else
          head,start=markstoligature(kind,lookupname,head,start,stop,lig)
        end
        return head,start,true
      else
      end
    end
  else
    local skipmark=sequence.flags[1]
    while s do
      local id=s.id
      if id==glyph_code and s.subtype<256 then
        if s.font==currentfont then
          local char=s.char
          if skipmark and marks[char] then
            s=s.next
          else
            local lg=ligature[char]
            if lg then
              stop=s
              ligature=lg
              s=s.next
            else
              break
            end
          end
        else
          break
        end
      elseif id==disc_code then
        discfound=true
        s=s.next
      else
        break
      end
    end
    local lig=ligature.ligature
    if lig then
      if stop then
        if trace_ligatures then
          local stopchar=stop.char
          head,start=toligature(kind,lookupname,head,start,stop,lig,skipmark,discfound)
          logprocess("%s: replacing %s upto %s by ligature %s case 2",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(start.char))
        else
          head,start=toligature(kind,lookupname,head,start,stop,lig,skipmark,discfound)
        end
        return head,start,true
      else
        start.char=lig
        if trace_ligatures then
          logprocess("%s: replacing %s by (no real) ligature %s case 3",pref(kind,lookupname),gref(startchar),gref(lig))
        end
        return head,start,true
      end
    else
    end
  end
  return head,start,false
end
function handlers.gpos_mark2base(head,start,kind,lookupname,markanchors,sequence)
  local markchar=start.char
  if marks[markchar] then
    local base=start.prev 
    if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
      local basechar=base.char
      if marks[basechar] then
        while true do
          base=base.prev
          if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
            basechar=base.char
            if not marks[basechar] then
              break
            end
          else
            if trace_bugs then
              logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
            end
            return head,start,false
          end
        end
      end
      local baseanchors=descriptions[basechar]
      if baseanchors then
        baseanchors=baseanchors.anchors
      end
      if baseanchors then
        local baseanchors=baseanchors['basechar']
        if baseanchors then
          local al=anchorlookups[lookupname]
          for anchor,ba in next,baseanchors do
            if al[anchor] then
              local ma=markanchors[anchor]
              if ma then
                local dx,dy,bound=setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma)
                if trace_marks then
                  logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                    pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                end
                return head,start,true
              end
            end
          end
          if trace_bugs then
            logwarning("%s, no matching anchors for mark %s and base %s",pref(kind,lookupname),gref(markchar),gref(basechar))
          end
        end
      elseif trace_bugs then
        onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
      end
    elseif trace_bugs then
      logwarning("%s: prev node is no char",pref(kind,lookupname))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
  end
  return head,start,false
end
function handlers.gpos_mark2ligature(head,start,kind,lookupname,markanchors,sequence)
  local markchar=start.char
  if marks[markchar] then
    local base=start.prev 
    if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
      local basechar=base.char
      if marks[basechar] then
        while true do
          base=base.prev
          if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
            basechar=base.char
            if not marks[basechar] then
              break
            end
          else
            if trace_bugs then
              logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
            end
            return head,start,false
          end
        end
      end
      local index=start[a_ligacomp]
      local baseanchors=descriptions[basechar]
      if baseanchors then
        baseanchors=baseanchors.anchors
        if baseanchors then
          local baseanchors=baseanchors['baselig']
          if baseanchors then
            local al=anchorlookups[lookupname]
            for anchor,ba in next,baseanchors do
              if al[anchor] then
                local ma=markanchors[anchor]
                if ma then
                  ba=ba[index]
                  if ba then
                    local dx,dy,bound=setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma) 
                    if trace_marks then
                      logprocess("%s, anchor %s, index %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                        pref(kind,lookupname),anchor,index,bound,gref(markchar),gref(basechar),index,dx,dy)
                    end
                    return head,start,true
                  else
                    if trace_bugs then
                      logwarning("%s: no matching anchors for mark %s and baselig %s with index %a",pref(kind,lookupname),gref(markchar),gref(basechar),index)
                    end
                  end
                end
              end
            end
            if trace_bugs then
              logwarning("%s: no matching anchors for mark %s and baselig %s",pref(kind,lookupname),gref(markchar),gref(basechar))
            end
          end
        end
      elseif trace_bugs then
        onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
      end
    elseif trace_bugs then
      logwarning("%s: prev node is no char",pref(kind,lookupname))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
  end
  return head,start,false
end
function handlers.gpos_mark2mark(head,start,kind,lookupname,markanchors,sequence)
  local markchar=start.char
  if marks[markchar] then
    local base=start.prev 
    local slc=start[a_ligacomp]
    if slc then 
      while base do
        local blc=base[a_ligacomp]
        if blc and blc~=slc then
          base=base.prev
        else
          break
        end
      end
    end
    if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then 
      local basechar=base.char
      local baseanchors=descriptions[basechar]
      if baseanchors then
        baseanchors=baseanchors.anchors
        if baseanchors then
          baseanchors=baseanchors['basemark']
          if baseanchors then
            local al=anchorlookups[lookupname]
            for anchor,ba in next,baseanchors do
              if al[anchor] then
                local ma=markanchors[anchor]
                if ma then
                  local dx,dy,bound=setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,true)
                  if trace_marks then
                    logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                      pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                  end
                  return head,start,true
                end
              end
            end
            if trace_bugs then
              logwarning("%s: no matching anchors for mark %s and basemark %s",pref(kind,lookupname),gref(markchar),gref(basechar))
            end
          end
        end
      elseif trace_bugs then
        onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
      end
    elseif trace_bugs then
      logwarning("%s: prev node is no mark",pref(kind,lookupname))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
  end
  return head,start,false
end
function handlers.gpos_cursive(head,start,kind,lookupname,exitanchors,sequence) 
  local alreadydone=cursonce and start[a_cursbase]
  if not alreadydone then
    local done=false
    local startchar=start.char
    if marks[startchar] then
      if trace_cursive then
        logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
      end
    else
      local nxt=start.next
      while not done and nxt and nxt.id==glyph_code and nxt.font==currentfont and nxt.subtype<256 do
        local nextchar=nxt.char
        if marks[nextchar] then
          nxt=nxt.next
        else
          local entryanchors=descriptions[nextchar]
          if entryanchors then
            entryanchors=entryanchors.anchors
            if entryanchors then
              entryanchors=entryanchors['centry']
              if entryanchors then
                local al=anchorlookups[lookupname]
                for anchor,entry in next,entryanchors do
                  if al[anchor] then
                    local exit=exitanchors[anchor]
                    if exit then
                      local dx,dy,bound=setcursive(start,nxt,tfmdata.parameters.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                      if trace_cursive then
                        logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                      end
                      done=true
                      break
                    end
                  end
                end
              end
            end
          elseif trace_bugs then
            onetimemessage(currentfont,startchar,"no entry anchors",report_fonts)
          end
          break
        end
      end
    end
    return head,start,done
  else
    if trace_cursive and trace_details then
      logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(start.char),alreadydone)
    end
    return head,start,false
  end
end
function handlers.gpos_single(head,start,kind,lookupname,kerns,sequence)
  local startchar=start.char
  local dx,dy,w,h=setpair(start,tfmdata.parameters.factor,rlmode,sequence.flags[4],kerns,characters[startchar])
  if trace_kerns then
    logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",pref(kind,lookupname),gref(startchar),dx,dy,w,h)
  end
  return head,start,false
end
function handlers.gpos_pair(head,start,kind,lookupname,kerns,sequence)
  local snext=start.next
  if not snext then
    return head,start,false
  else
    local prev,done=start,false
    local factor=tfmdata.parameters.factor
    local lookuptype=lookuptypes[lookupname]
    while snext and snext.id==glyph_code and snext.font==currentfont and snext.subtype<256 do
      local nextchar=snext.char
      local krn=kerns[nextchar]
      if not krn and marks[nextchar] then
        prev=snext
        snext=snext.next
      else
        if not krn then
        elseif type(krn)=="table" then
          if lookuptype=="pair" then 
            local a,b=krn[2],krn[3]
            if a and #a>0 then
              local startchar=start.char
              local x,y,w,h=setpair(start,factor,rlmode,sequence.flags[4],a,characters[startchar])
              if trace_kerns then
                logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
              end
            end
            if b and #b>0 then
              local startchar=start.char
              local x,y,w,h=setpair(snext,factor,rlmode,sequence.flags[4],b,characters[nextchar])
              if trace_kerns then
                logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
              end
            end
          else 
            report_process("%s: check this out (old kern stuff)",pref(kind,lookupname))
          end
          done=true
        elseif krn~=0 then
          local k=setkern(snext,factor,rlmode,krn)
          if trace_kerns then
            logprocess("%s: inserting kern %s between %s and %s",pref(kind,lookupname),k,gref(prev.char),gref(nextchar))
          end
          done=true
        end
        break
      end
    end
    return head,start,done
  end
end
local chainmores={}
local chainprocs={}
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  report_subchain(...)
end
local logwarning=report_subchain
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  report_chain(...)
end
local logwarning=report_chain
function chainprocs.chainsub(head,start,stop,kind,chainname,currentcontext,lookuphash,lookuplist,chainlookupname)
  logwarning("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
  return head,start,false
end
function chainmores.chainsub(head,start,stop,kind,chainname,currentcontext,lookuphash,lookuplist,chainlookupname,n)
  logprocess("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
  return head,start,false
end
function chainprocs.reversesub(head,start,stop,kind,chainname,currentcontext,lookuphash,replacements)
  local char=start.char
  local replacement=replacements[char]
  if replacement then
    if trace_singles then
      logprocess("%s: single reverse replacement of %s by %s",cref(kind,chainname),gref(char),gref(replacement))
    end
    start.char=replacement
    return head,start,true
  else
    return head,start,false
  end
end
function chainprocs.gsub_single(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex)
  local current=start
  local subtables=currentlookup.subtables
  if #subtables>1 then
    logwarning("todo: check if we need to loop over the replacements: %s",concat(subtables," "))
  end
  while current do
    if current.id==glyph_code then
      local currentchar=current.char
      local lookupname=subtables[1] 
      local replacement=lookuphash[lookupname]
      if not replacement then
        if trace_bugs then
          logwarning("%s: no single hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
        end
      else
        replacement=replacement[currentchar]
        if not replacement or replacement=="" then
          if trace_bugs then
            logwarning("%s: no single for %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(currentchar))
          end
        else
          if trace_singles then
            logprocess("%s: replacing single %s by %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(currentchar),gref(replacement))
          end
          current.char=replacement
        end
      end
      return head,start,true
    elseif current==stop then
      break
    else
      current=current.next
    end
  end
  return head,start,false
end
chainmores.gsub_single=chainprocs.gsub_single
function chainprocs.gsub_multiple(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
  local startchar=start.char
  local subtables=currentlookup.subtables
  local lookupname=subtables[1]
  local replacements=lookuphash[lookupname]
  if not replacements then
    if trace_bugs then
      logwarning("%s: no multiple hits",cref(kind,chainname,chainlookupname,lookupname))
    end
  else
    replacements=replacements[startchar]
    if not replacements or replacement=="" then
      if trace_bugs then
        logwarning("%s: no multiple for %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar))
      end
    else
      if trace_multiples then
        logprocess("%s: replacing %s by multiple characters %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar),gref(replacements))
      end
      return multiple_glyphs(head,start,replacements,currentlookup.flags[1])
    end
  end
  return head,start,false
end
chainmores.gsub_multiple=chainprocs.gsub_multiple
function chainprocs.gsub_alternate(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
  local current=start
  local subtables=currentlookup.subtables
  local value=featurevalue==true and tfmdata.shared.features[kind] or featurevalue
  while current do
    if current.id==glyph_code then 
      local currentchar=current.char
      local lookupname=subtables[1]
      local alternatives=lookuphash[lookupname]
      if not alternatives then
        if trace_bugs then
          logwarning("%s: no alternative hit",cref(kind,chainname,chainlookupname,lookupname))
        end
      else
        alternatives=alternatives[currentchar]
        if alternatives then
          local choice,comment=get_alternative_glyph(current,alternatives,value,trace_alternatives)
          if choice then
            if trace_alternatives then
              logprocess("%s: replacing %s by alternative %a to %s, %s",cref(kind,chainname,chainlookupname,lookupname),gref(char),choice,gref(choice),comment)
            end
            start.char=choice
          else
            if trace_alternatives then
              logwarning("%s: no variant %a for %s, %s",cref(kind,chainname,chainlookupname,lookupname),value,gref(char),comment)
            end
          end
        elseif trace_bugs then
          logwarning("%s: no alternative for %s, %s",cref(kind,chainname,chainlookupname,lookupname),gref(currentchar),comment)
        end
      end
      return head,start,true
    elseif current==stop then
      break
    else
      current=current.next
    end
  end
  return head,start,false
end
chainmores.gsub_alternate=chainprocs.gsub_alternate
function chainprocs.gsub_ligature(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex)
  local startchar=start.char
  local subtables=currentlookup.subtables
  local lookupname=subtables[1]
  local ligatures=lookuphash[lookupname]
  if not ligatures then
    if trace_bugs then
      logwarning("%s: no ligature hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
    end
  else
    ligatures=ligatures[startchar]
    if not ligatures then
      if trace_bugs then
        logwarning("%s: no ligatures starting with %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
      end
    else
      local s=start.next
      local discfound=false
      local last=stop
      local nofreplacements=0
      local skipmark=currentlookup.flags[1]
      while s do
        local id=s.id
        if id==disc_code then
          s=s.next
          discfound=true
        else
          local schar=s.char
          if skipmark and marks[schar] then 
            s=s.next
          else
            local lg=ligatures[schar]
            if lg then
              ligatures,last,nofreplacements=lg,s,nofreplacements+1
              if s==stop then
                break
              else
                s=s.next
              end
            else
              break
            end
          end
        end
      end
      local l2=ligatures.ligature
      if l2 then
        if chainindex then
          stop=last
        end
        if trace_ligatures then
          if start==stop then
            logprocess("%s: replacing character %s by ligature %s case 3",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(l2))
          else
            logprocess("%s: replacing character %s upto %s by ligature %s case 4",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(stop.char),gref(l2))
          end
        end
        head,start=toligature(kind,lookupname,head,start,stop,l2,currentlookup.flags[1],discfound)
        return head,start,true,nofreplacements
      elseif trace_bugs then
        if start==stop then
          logwarning("%s: replacing character %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
        else
          logwarning("%s: replacing character %s upto %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(stop.char))
        end
      end
    end
  end
  return head,start,false,0
end
chainmores.gsub_ligature=chainprocs.gsub_ligature
function chainprocs.gpos_mark2base(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
  local markchar=start.char
  if marks[markchar] then
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local markanchors=lookuphash[lookupname]
    if markanchors then
      markanchors=markanchors[markchar]
    end
    if markanchors then
      local base=start.prev 
      if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
        local basechar=base.char
        if marks[basechar] then
          while true do
            base=base.prev
            if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
              basechar=base.char
              if not marks[basechar] then
                break
              end
            else
              if trace_bugs then
                logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
              end
              return head,start,false
            end
          end
        end
        local baseanchors=descriptions[basechar].anchors
        if baseanchors then
          local baseanchors=baseanchors['basechar']
          if baseanchors then
            local al=anchorlookups[lookupname]
            for anchor,ba in next,baseanchors do
              if al[anchor] then
                local ma=markanchors[anchor]
                if ma then
                  local dx,dy,bound=setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma)
                  if trace_marks then
                    logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                      cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                  end
                  return head,start,true
                end
              end
            end
            if trace_bugs then
              logwarning("%s, no matching anchors for mark %s and base %s",cref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
            end
          end
        end
      elseif trace_bugs then
        logwarning("%s: prev node is no char",cref(kind,chainname,chainlookupname,lookupname))
      end
    elseif trace_bugs then
      logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
  end
  return head,start,false
end
function chainprocs.gpos_mark2ligature(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
  local markchar=start.char
  if marks[markchar] then
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local markanchors=lookuphash[lookupname]
    if markanchors then
      markanchors=markanchors[markchar]
    end
    if markanchors then
      local base=start.prev 
      if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
        local basechar=base.char
        if marks[basechar] then
          while true do
            base=base.prev
            if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then
              basechar=base.char
              if not marks[basechar] then
                break
              end
            else
              if trace_bugs then
                logwarning("%s: no base for mark %s",cref(kind,chainname,chainlookupname,lookupname),markchar)
              end
              return head,start,false
            end
          end
        end
        local index=start[a_ligacomp]
        local baseanchors=descriptions[basechar].anchors
        if baseanchors then
          local baseanchors=baseanchors['baselig']
          if baseanchors then
            local al=anchorlookups[lookupname]
            for anchor,ba in next,baseanchors do
              if al[anchor] then
                local ma=markanchors[anchor]
                if ma then
                  ba=ba[index]
                  if ba then
                    local dx,dy,bound=setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma) 
                    if trace_marks then
                      logprocess("%s, anchor %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                        cref(kind,chainname,chainlookupname,lookupname),anchor,a or bound,gref(markchar),gref(basechar),index,dx,dy)
                    end
                    return head,start,true
                  end
                end
              end
            end
            if trace_bugs then
              logwarning("%s: no matching anchors for mark %s and baselig %s",cref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
            end
          end
        end
      elseif trace_bugs then
        logwarning("feature %s, lookup %s: prev node is no char",kind,lookupname)
      end
    elseif trace_bugs then
      logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
  end
  return head,start,false
end
function chainprocs.gpos_mark2mark(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
  local markchar=start.char
  if marks[markchar] then
      local subtables=currentlookup.subtables
      local lookupname=subtables[1]
      local markanchors=lookuphash[lookupname]
      if markanchors then
        markanchors=markanchors[markchar]
      end
      if markanchors then
        local base=start.prev 
        local slc=start[a_ligacomp]
        if slc then 
          while base do
            local blc=base[a_ligacomp]
            if blc and blc~=slc then
              base=base.prev
            else
              break
            end
          end
        end
        if base and base.id==glyph_code and base.font==currentfont and base.subtype<256 then 
          local basechar=base.char
          local baseanchors=descriptions[basechar].anchors
          if baseanchors then
            baseanchors=baseanchors['basemark']
            if baseanchors then
              local al=anchorlookups[lookupname]
              for anchor,ba in next,baseanchors do
                if al[anchor] then
                  local ma=markanchors[anchor]
                  if ma then
                    local dx,dy,bound=setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,true)
                    if trace_marks then
                      logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                        cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                    end
                    return head,start,true
                  end
                end
              end
              if trace_bugs then
                logwarning("%s: no matching anchors for mark %s and basemark %s",gref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
              end
            end
          end
        elseif trace_bugs then
          logwarning("%s: prev node is no mark",cref(kind,chainname,chainlookupname,lookupname))
        end
      elseif trace_bugs then
        logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
      end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
  end
  return head,start,false
end
function chainprocs.gpos_cursive(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
  local alreadydone=cursonce and start[a_cursbase]
  if not alreadydone then
    local startchar=start.char
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local exitanchors=lookuphash[lookupname]
    if exitanchors then
      exitanchors=exitanchors[startchar]
    end
    if exitanchors then
      local done=false
      if marks[startchar] then
        if trace_cursive then
          logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
        end
      else
        local nxt=start.next
        while not done and nxt and nxt.id==glyph_code and nxt.font==currentfont and nxt.subtype<256 do
          local nextchar=nxt.char
          if marks[nextchar] then
            nxt=nxt.next
          else
            local entryanchors=descriptions[nextchar]
            if entryanchors then
              entryanchors=entryanchors.anchors
              if entryanchors then
                entryanchors=entryanchors['centry']
                if entryanchors then
                  local al=anchorlookups[lookupname]
                  for anchor,entry in next,entryanchors do
                    if al[anchor] then
                      local exit=exitanchors[anchor]
                      if exit then
                        local dx,dy,bound=setcursive(start,nxt,tfmdata.parameters.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                        if trace_cursive then
                          logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                        end
                        done=true
                        break
                      end
                    end
                  end
                end
              end
            elseif trace_bugs then
              onetimemessage(currentfont,startchar,"no entry anchors",report_fonts)
            end
            break
          end
        end
      end
      return head,start,done
    else
      if trace_cursive and trace_details then
        logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(start.char),alreadydone)
      end
      return head,start,false
    end
  end
  return head,start,false
end
function chainprocs.gpos_single(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex,sequence)
  local startchar=start.char
  local subtables=currentlookup.subtables
  local lookupname=subtables[1]
  local kerns=lookuphash[lookupname]
  if kerns then
    kerns=kerns[startchar] 
    if kerns then
      local dx,dy,w,h=setpair(start,tfmdata.parameters.factor,rlmode,sequence.flags[4],kerns,characters[startchar])
      if trace_kerns then
        logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",cref(kind,chainname,chainlookupname),gref(startchar),dx,dy,w,h)
      end
    end
  end
  return head,start,false
end
chainmores.gpos_single=chainprocs.gpos_single
function chainprocs.gpos_pair(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex,sequence)
  local snext=start.next
  if snext then
    local startchar=start.char
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local kerns=lookuphash[lookupname]
    if kerns then
      kerns=kerns[startchar]
      if kerns then
        local lookuptype=lookuptypes[lookupname]
        local prev,done=start,false
        local factor=tfmdata.parameters.factor
        while snext and snext.id==glyph_code and snext.font==currentfont and snext.subtype<256 do
          local nextchar=snext.char
          local krn=kerns[nextchar]
          if not krn and marks[nextchar] then
            prev=snext
            snext=snext.next
          else
            if not krn then
            elseif type(krn)=="table" then
              if lookuptype=="pair" then
                local a,b=krn[2],krn[3]
                if a and #a>0 then
                  local startchar=start.char
                  local x,y,w,h=setpair(start,factor,rlmode,sequence.flags[4],a,characters[startchar])
                  if trace_kerns then
                    logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                  end
                end
                if b and #b>0 then
                  local startchar=start.char
                  local x,y,w,h=setpair(snext,factor,rlmode,sequence.flags[4],b,characters[nextchar])
                  if trace_kerns then
                    logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                  end
                end
              else
                report_process("%s: check this out (old kern stuff)",cref(kind,chainname,chainlookupname))
                local a,b=krn[2],krn[6]
                if a and a~=0 then
                  local k=setkern(snext,factor,rlmode,a)
                  if trace_kerns then
                    logprocess("%s: inserting first kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(prev.char),gref(nextchar))
                  end
                end
                if b and b~=0 then
                  logwarning("%s: ignoring second kern xoff %s",cref(kind,chainname,chainlookupname),b*factor)
                end
              end
              done=true
            elseif krn~=0 then
              local k=setkern(snext,factor,rlmode,krn)
              if trace_kerns then
                logprocess("%s: inserting kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(prev.char),gref(nextchar))
              end
              done=true
            end
            break
          end
        end
        return head,start,done
      end
    end
  end
  return head,start,false
end
chainmores.gpos_pair=chainprocs.gpos_pair
local function show_skip(kind,chainname,char,ck,class)
  if ck[9] then
    logwarning("%s: skipping char %s, class %a, rule %a, lookuptype %a, %a => %a",cref(kind,chainname),gref(char),class,ck[1],ck[2],ck[9],ck[10])
  else
    logwarning("%s: skipping char %s, class %a, rule %a, lookuptype %a",cref(kind,chainname),gref(char),class,ck[1],ck[2])
  end
end
local function normal_handle_contextchain(head,start,kind,chainname,contexts,sequence,lookuphash)
  local flags=sequence.flags
  local done=false
  local skipmark=flags[1]
  local skipligature=flags[2]
  local skipbase=flags[3]
  local someskip=skipmark or skipligature or skipbase 
  local markclass=sequence.markclass          
  local skipped=false
  for k=1,#contexts do
    local match=true
    local current=start
    local last=start
    local ck=contexts[k]
    local seq=ck[3]
    local s=#seq
    if s==1 then
      match=current.id==glyph_code and current.font==currentfont and current.subtype<256 and seq[1][current.char]
    else
      local f,l=ck[4],ck[5]
      if f==1 and f==l then
      else
        if f==l then
        else
          local n=f+1
          last=last.next
          while n<=l do
            if last then
              local id=last.id
              if id==glyph_code then
                if last.font==currentfont and last.subtype<256 then
                  local char=last.char
                  local ccd=descriptions[char]
                  if ccd then
                    local class=ccd.class
                    if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                      skipped=true
                      if trace_skips then
                        show_skip(kind,chainname,char,ck,class)
                      end
                      last=last.next
                    elseif seq[n][char] then
                      if n<l then
                        last=last.next
                      end
                      n=n+1
                    else
                      match=false
                      break
                    end
                  else
                    match=false
                    break
                  end
                else
                  match=false
                  break
                end
              elseif id==disc_code then
                last=last.next
              else
                match=false
                break
              end
            else
              match=false
              break
            end
          end
        end
      end
      if match and f>1 then
        local prev=start.prev
        if prev then
          local n=f-1
          while n>=1 do
            if prev then
              local id=prev.id
              if id==glyph_code then
                if prev.font==currentfont and prev.subtype<256 then 
                  local char=prev.char
                  local ccd=descriptions[char]
                  if ccd then
                    local class=ccd.class
                    if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                      skipped=true
                      if trace_skips then
                        show_skip(kind,chainname,char,ck,class)
                      end
                    elseif seq[n][char] then
                      n=n -1
                    else
                      match=false
                      break
                    end
                  else
                    match=false
                    break
                  end
                else
                  match=false
                  break
                end
              elseif id==disc_code then
              elseif seq[n][32] then
                n=n -1
              else
                match=false
                break
              end
              prev=prev.prev
            elseif seq[n][32] then 
              n=n -1
            else
              match=false
              break
            end
          end
        elseif f==2 then
          match=seq[1][32]
        else
          for n=f-1,1 do
            if not seq[n][32] then
              match=false
              break
            end
          end
        end
      end
      if match and s>l then
        local current=last and last.next
        if current then
          local n=l+1
          while n<=s do
            if current then
              local id=current.id
              if id==glyph_code then
                if current.font==currentfont and current.subtype<256 then 
                  local char=current.char
                  local ccd=descriptions[char]
                  if ccd then
                    local class=ccd.class
                    if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                      skipped=true
                      if trace_skips then
                        show_skip(kind,chainname,char,ck,class)
                      end
                    elseif seq[n][char] then
                      n=n+1
                    else
                      match=false
                      break
                    end
                  else
                    match=false
                    break
                  end
                else
                  match=false
                  break
                end
              elseif id==disc_code then
              elseif seq[n][32] then 
                n=n+1
              else
                match=false
                break
              end
              current=current.next
            elseif seq[n][32] then
              n=n+1
            else
              match=false
              break
            end
          end
        elseif s-l==1 then
          match=seq[s][32]
        else
          for n=l+1,s do
            if not seq[n][32] then
              match=false
              break
            end
          end
        end
      end
    end
    if match then
      if trace_contexts then
        local rule,lookuptype,f,l=ck[1],ck[2],ck[4],ck[5]
        local char=start.char
        if ck[9] then
          logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %a, %a => %a",
            cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype,ck[9],ck[10])
        else
          logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %a",
            cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype)
        end
      end
      local chainlookups=ck[6]
      if chainlookups then
        local nofchainlookups=#chainlookups
        if nofchainlookups==1 then
          local chainlookupname=chainlookups[1]
          local chainlookup=lookuptable[chainlookupname]
          if chainlookup then
            local cp=chainprocs[chainlookup.type]
            if cp then
              local ok
              head,start,ok=cp(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)
              if ok then
                done=true
              end
            else
              logprocess("%s: %s is not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
            end
          else 
            logprocess("%s is not yet supported",cref(kind,chainname,chainlookupname))
          end
         else
          local i=1
          repeat
            if skipped then
              while true do
                local char=start.char
                local ccd=descriptions[char]
                if ccd then
                  local class=ccd.class
                  if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                    start=start.next
                  else
                    break
                  end
                else
                  break
                end
              end
            end
            local chainlookupname=chainlookups[i]
            local chainlookup=lookuptable[chainlookupname]
            if not chainlookup then
              i=i+1
            else
              local cp=chainmores[chainlookup.type]
              if not cp then
                logprocess("%s: %s is not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
                i=i+1
              else
                local ok,n
                head,start,ok,n=cp(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,i,sequence)
                if ok then
                  done=true
                  i=i+(n or 1)
                else
                  i=i+1
                end
              end
            end
            if start then
              start=start.next
            else
            end
          until i>nofchainlookups
        end
      else
        local replacements=ck[7]
        if replacements then
          head,start,done=chainprocs.reversesub(head,start,last,kind,chainname,ck,lookuphash,replacements) 
        else
          done=true 
          if trace_contexts then
            logprocess("%s: skipping match",cref(kind,chainname))
          end
        end
      end
    end
  end
  return head,start,done
end
local verbose_handle_contextchain=function(font,...)
  logwarning("no verbose handler installed, reverting to 'normal'")
  otf.setcontextchain()
  return normal_handle_contextchain(...)
end
otf.chainhandlers={
  normal=normal_handle_contextchain,
  verbose=verbose_handle_contextchain,
}
function otf.setcontextchain(method)
  if not method or method=="normal" or not otf.chainhandlers[method] then
    if handlers.contextchain then 
      logwarning("installing normal contextchain handler")
    end
    handlers.contextchain=normal_handle_contextchain
  else
    logwarning("installing contextchain handler %a",method)
    local handler=otf.chainhandlers[method]
    handlers.contextchain=function(...)
      return handler(currentfont,...) 
    end
  end
  handlers.gsub_context=handlers.contextchain
  handlers.gsub_contextchain=handlers.contextchain
  handlers.gsub_reversecontextchain=handlers.contextchain
  handlers.gpos_contextchain=handlers.contextchain
  handlers.gpos_context=handlers.contextchain
end
otf.setcontextchain()
local missing={} 
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  report_process(...)
end
local logwarning=report_process
local function report_missing_cache(typ,lookup)
  local f=missing[currentfont] if not f then f={} missing[currentfont]=f end
  local t=f[typ]        if not t then t={} f[typ]=t end
  if not t[lookup] then
    t[lookup]=true
    logwarning("missing cache for lookup %a, type %a, font %a, name %a",lookup,typ,currentfont,tfmdata.properties.fullname)
  end
end
local resolved={}
local lookuphashes={}
setmetatableindex(lookuphashes,function(t,font)
  local lookuphash=fontdata[font].resources.lookuphash
  if not lookuphash or not next(lookuphash) then
    lookuphash=false
  end
  t[font]=lookuphash
  return lookuphash
end)
local autofeatures=fonts.analyzers.features 
local function initialize(sequence,script,language,enabled)
  local features=sequence.features
  if features then
    local order=sequence.order
    if order then
      for i=1,#order do
        local kind=order[i] 
        local valid=enabled[kind]
        if valid then
          local scripts=features[kind] 
          local languages=scripts[script] or scripts[wildcard]
          if languages and (languages[language] or languages[wildcard]) then
            return { valid,autofeatures[kind] or false,sequence.chain or 0,kind,sequence }
          end
        end
      end
    else
    end
  end
  return false
end
function otf.dataset(tfmdata,font) 
  local shared=tfmdata.shared
  local properties=tfmdata.properties
  local language=properties.language or "dflt"
  local script=properties.script  or "dflt"
  local enabled=shared.features
  local res=resolved[font]
  if not res then
    res={}
    resolved[font]=res
  end
  local rs=res[script]
  if not rs then
    rs={}
    res[script]=rs
  end
  local rl=rs[language]
  if not rl then
    rl={
    }
    rs[language]=rl
    local sequences=tfmdata.resources.sequences
    for s=1,#sequences do
      local v=enabled and initialize(sequences[s],script,language,enabled)
      if v then
        rl[#rl+1]=v
      end
    end
  end
  return rl
end
local function featuresprocessor(head,font,attr)
  local lookuphash=lookuphashes[font] 
  if not lookuphash then
    return head,false
  end
  if trace_steps then
    checkstep(head)
  end
  tfmdata=fontdata[font]
  descriptions=tfmdata.descriptions
  characters=tfmdata.characters
  resources=tfmdata.resources
  marks=resources.marks
  anchorlookups=resources.lookup_to_anchor
  lookuptable=resources.lookups
  lookuptypes=resources.lookuptypes
  currentfont=font
  rlmode=0
  local sequences=resources.sequences
  local done=false
  local datasets=otf.dataset(tfmdata,font,attr)
  local dirstack={}
  for s=1,#datasets do
    local dataset=datasets[s]
    featurevalue=dataset[1] 
    local sequence=dataset[5] 
    local rlparmode=0
    local topstack=0
    local success=false
    local attribute=dataset[2]
    local chain=dataset[3] 
    local typ=sequence.type
    local subtables=sequence.subtables
    if chain<0 then
      local handler=handlers[typ]
      local start=find_node_tail(head) 
      while start do
        local id=start.id
        if id==glyph_code then
          if start.font==font and start.subtype<256 then
            local a=start[0]
            if a then
              a=a==attr
            else
              a=true
            end
            if a then
              for i=1,#subtables do
                local lookupname=subtables[i]
                local lookupcache=lookuphash[lookupname]
                if lookupcache then
                  local lookupmatch=lookupcache[start.char]
                  if lookupmatch then
                    head,start,success=handler(head,start,dataset[4],lookupname,lookupmatch,sequence,lookuphash,i)
                    if success then
                      break
                    end
                  end
                else
                  report_missing_cache(typ,lookupname)
                end
              end
              if start then start=start.prev end
            else
              start=start.prev
            end
          else
            start=start.prev
          end
        else
          start=start.prev
        end
      end
    else
      local handler=handlers[typ]
      local ns=#subtables
      local start=head 
      rlmode=0 
      if ns==1 then 
        local lookupname=subtables[1]
        local lookupcache=lookuphash[lookupname]
        if not lookupcache then 
          report_missing_cache(typ,lookupname)
        else
          local function subrun(start)
            local head=start
            local done=false
            while start do
              local id=start.id
              if id==glyph_code and start.font==font and start.subtype<256 then
                local a=start[0]
                if a then
                  a=(a==attr) and (not attribute or start[a_state]==attribute)
                else
                  a=not attribute or start[a_state]==attribute
                end
                if a then
                  local lookupmatch=lookupcache[start.char]
                  if lookupmatch then
                    local ok
                    head,start,ok=handler(head,start,dataset[4],lookupname,lookupmatch,sequence,lookuphash,1)
                    if ok then
                      done=true
                    end
                  end
                  if start then start=start.next end
                else
                  start=start.next
                end
              else
                start=start.next
              end
            end
            if done then
              success=true
              return head
            end
          end
          local function kerndisc(disc) 
            local prev=disc.prev
            local next=disc.next
            if prev and next then
              prev.next=next
              local a=prev[0]
              if a then
                a=(a==attr) and (not attribute or prev[a_state]==attribute)
              else
                a=not attribute or prev[a_state]==attribute
              end
              if a then
                local lookupmatch=lookupcache[prev.char]
                if lookupmatch then
                  local h,d,ok=handler(head,prev,dataset[4],lookupname,lookupmatch,sequence,lookuphash,1)
                  if ok then
                    done=true
                    success=true
                  end
                end
              end
              prev.next=disc
            end
            return next
          end
          while start do
            local id=start.id
            if id==glyph_code then
              if start.font==font and start.subtype<256 then
                local a=start[0]
                if a then
                  a=(a==attr) and (not attribute or start[a_state]==attribute)
                else
                  a=not attribute or start[a_state]==attribute
                end
                if a then
                  local lookupmatch=lookupcache[start.char]
                  if lookupmatch then
                    local ok
                    head,start,ok=handler(head,start,dataset[4],lookupname,lookupmatch,sequence,lookuphash,1)
                    if ok then
                      success=true
                    end
                  end
                  if start then start=start.next end
                else
                  start=start.next
                end
              else
                start=start.next
              end
            elseif id==disc_code then
              if start.subtype==discretionary_code then
                local pre=start.pre
                if pre then
                  local new=subrun(pre)
                  if new then start.pre=new end
                end
                local post=start.post
                if post then
                  local new=subrun(post)
                  if new then start.post=new end
                end
                local replace=start.replace
                if replace then
                  local new=subrun(replace)
                  if new then start.replace=new end
                end
elseif typ=="gpos_single" or typ=="gpos_pair" then
  kerndisc(start)
              end
              start=start.next
            elseif id==whatsit_code then 
              local subtype=start.subtype
              if subtype==dir_code then
                local dir=start.dir
                if   dir=="+TRT" or dir=="+TLT" then
                  topstack=topstack+1
                  dirstack[topstack]=dir
                elseif dir=="-TRT" or dir=="-TLT" then
                  topstack=topstack-1
                end
                local newdir=dirstack[topstack]
                if newdir=="+TRT" then
                  rlmode=-1
                elseif newdir=="+TLT" then
                  rlmode=1
                else
                  rlmode=rlparmode
                end
                if trace_directions then
                  report_process("directions after txtdir %a: parmode %a, txtmode %a, # stack %a, new dir %a",dir,rlparmode,rlmode,topstack,newdir)
                end
              elseif subtype==localpar_code then
                local dir=start.dir
                if dir=="TRT" then
                  rlparmode=-1
                elseif dir=="TLT" then
                  rlparmode=1
                else
                  rlparmode=0
                end
                rlmode=rlparmode
                if trace_directions then
                  report_process("directions after pardir %a: parmode %a, txtmode %a",dir,rlparmode,rlmode)
                end
              end
              start=start.next
            elseif id==math_code then
              start=end_of_math(start).next
            else
              start=start.next
            end
          end
        end
      else
        local function subrun(start)
          local head=start
          local done=false
          while start do
            local id=start.id
            if id==glyph_code and start.id==font and start.subtype<256 then
              local a=start[0]
              if a then
                a=(a==attr) and (not attribute or start[a_state]==attribute)
              else
                a=not attribute or start[a_state]==attribute
              end
              if a then
                for i=1,ns do
                  local lookupname=subtables[i]
                  local lookupcache=lookuphash[lookupname]
                  if lookupcache then
                    local lookupmatch=lookupcache[start.char]
                    if lookupmatch then
                      local ok
                      head,start,ok=handler(head,start,dataset[4],lookupname,lookupmatch,sequence,lookuphash,i)
                      if ok then
                        done=true
                        break
                      elseif not start then
                        break
                      end
                    end
                  else
                    report_missing_cache(typ,lookupname)
                  end
                end
                if start then start=start.next end
              else
                start=start.next
              end
            else
              start=start.next
            end
          end
          if done then
            success=true
            return head
          end
        end
        local function kerndisc(disc) 
          local prev=disc.prev
          local next=disc.next
          if prev and next then
            prev.next=next
            local a=prev[0]
            if a then
              a=(a==attr) and (not attribute or prev[a_state]==attribute)
            else
              a=not attribute or prev[a_state]==attribute
            end
            if a then
              for i=1,ns do
                local lookupname=subtables[i]
                local lookupcache=lookuphash[lookupname]
                if lookupcache then
                  local lookupmatch=lookupcache[prev.char]
                  if lookupmatch then
                    local h,d,ok=handler(head,prev,dataset[4],lookupname,lookupmatch,sequence,lookuphash,i)
                    if ok then
                      done=true
                      break
                    end
                  end
                else
                  report_missing_cache(typ,lookupname)
                end
              end
            end
            prev.next=disc
          end
          return next
        end
        while start do
          local id=start.id
          if id==glyph_code then
            if start.font==font and start.subtype<256 then
              local a=start[0]
              if a then
                a=(a==attr) and (not attribute or start[a_state]==attribute)
              else
                a=not attribute or start[a_state]==attribute
              end
              if a then
                for i=1,ns do
                  local lookupname=subtables[i]
                  local lookupcache=lookuphash[lookupname]
                  if lookupcache then
                    local lookupmatch=lookupcache[start.char]
                    if lookupmatch then
                      local ok
                      head,start,ok=handler(head,start,dataset[4],lookupname,lookupmatch,sequence,lookuphash,i)
                      if ok then
                        success=true
                        break
                      elseif not start then
                        break
                      end
                    end
                  else
                    report_missing_cache(typ,lookupname)
                  end
                end
                if start then start=start.next end
              else
                start=start.next
              end
            else
              start=start.next
            end
          elseif id==disc_code then
            if start.subtype==discretionary_code then
              local pre=start.pre
              if pre then
                local new=subrun(pre)
                if new then start.pre=new end
              end
              local post=start.post
              if post then
                local new=subrun(post)
                if new then start.post=new end
              end
              local replace=start.replace
              if replace then
                local new=subrun(replace)
                if new then start.replace=new end
              end
elseif typ=="gpos_single" or typ=="gpos_pair" then
  kerndisc(start)
            end
            start=start.next
          elseif id==whatsit_code then
            local subtype=start.subtype
            if subtype==dir_code then
              local dir=start.dir
              if   dir=="+TRT" or dir=="+TLT" then
                topstack=topstack+1
                dirstack[topstack]=dir
              elseif dir=="-TRT" or dir=="-TLT" then
                topstack=topstack-1
              end
              local newdir=dirstack[topstack]
              if newdir=="+TRT" then
                rlmode=-1
              elseif newdir=="+TLT" then
                rlmode=1
              else
                rlmode=rlparmode
              end
              if trace_directions then
                report_process("directions after txtdir %a: parmode %a, txtmode %a, # stack %a, new dir %a",dir,rlparmode,rlmode,topstack,newdir)
              end
            elseif subtype==localpar_code then
              local dir=start.dir
              if dir=="TRT" then
                rlparmode=-1
              elseif dir=="TLT" then
                rlparmode=1
              else
                rlparmode=0
              end
              rlmode=rlparmode
              if trace_directions then
                report_process("directions after pardir %a: parmode %a, txtmode %a",dir,rlparmode,rlmode)
              end
            end
            start=start.next
          elseif id==math_code then
            start=end_of_math(start).next
          else
            start=start.next
          end
        end
      end
    end
    if success then
      done=true
    end
    if trace_steps then 
      registerstep(head)
    end
  end
  return head,done
end
local function generic(lookupdata,lookupname,unicode,lookuphash)
  local target=lookuphash[lookupname]
  if target then
    target[unicode]=lookupdata
  else
    lookuphash[lookupname]={ [unicode]=lookupdata }
  end
end
local action={
  substitution=generic,
  multiple=generic,
  alternate=generic,
  position=generic,
  ligature=function(lookupdata,lookupname,unicode,lookuphash)
    local target=lookuphash[lookupname]
    if not target then
      target={}
      lookuphash[lookupname]=target
    end
    for i=1,#lookupdata do
      local li=lookupdata[i]
      local tu=target[li]
      if not tu then
        tu={}
        target[li]=tu
      end
      target=tu
    end
    target.ligature=unicode
  end,
  pair=function(lookupdata,lookupname,unicode,lookuphash)
    local target=lookuphash[lookupname]
    if not target then
      target={}
      lookuphash[lookupname]=target
    end
    local others=target[unicode]
    local paired=lookupdata[1]
    if others then
      others[paired]=lookupdata
    else
      others={ [paired]=lookupdata }
      target[unicode]=others
    end
  end,
}
local function prepare_lookups(tfmdata)
  local rawdata=tfmdata.shared.rawdata
  local resources=rawdata.resources
  local lookuphash=resources.lookuphash
  local anchor_to_lookup=resources.anchor_to_lookup
  local lookup_to_anchor=resources.lookup_to_anchor
  local lookuptypes=resources.lookuptypes
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  for unicode,character in next,characters do 
    local description=descriptions[unicode]
    if description then
      local lookups=description.slookups
      if lookups then
        for lookupname,lookupdata in next,lookups do
          action[lookuptypes[lookupname]](lookupdata,lookupname,unicode,lookuphash)
        end
      end
      local lookups=description.mlookups
      if lookups then
        for lookupname,lookuplist in next,lookups do
          local lookuptype=lookuptypes[lookupname]
          for l=1,#lookuplist do
            local lookupdata=lookuplist[l]
            action[lookuptype](lookupdata,lookupname,unicode,lookuphash)
          end
        end
      end
      local list=description.kerns
      if list then
        for lookup,krn in next,list do 
          local target=lookuphash[lookup]
          if target then
            target[unicode]=krn
          else
            lookuphash[lookup]={ [unicode]=krn }
          end
        end
      end
      local list=description.anchors
      if list then
        for typ,anchors in next,list do 
          if typ=="mark" or typ=="cexit" then 
            for name,anchor in next,anchors do
              local lookups=anchor_to_lookup[name]
              if lookups then
                for lookup,_ in next,lookups do
                  local target=lookuphash[lookup]
                  if target then
                    target[unicode]=anchors
                  else
                    lookuphash[lookup]={ [unicode]=anchors }
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
local function split(replacement,original)
  local result={}
  for i=1,#replacement do
    result[original[i]]=replacement[i]
  end
  return result
end
local valid={
  coverage={ chainsub=true,chainpos=true,contextsub=true },
  reversecoverage={ reversesub=true },
  glyphs={ chainsub=true,chainpos=true },
}
local function prepare_contextchains(tfmdata)
  local rawdata=tfmdata.shared.rawdata
  local resources=rawdata.resources
  local lookuphash=resources.lookuphash
  local lookups=rawdata.lookups
  if lookups then
    for lookupname,lookupdata in next,rawdata.lookups do
      local lookuptype=lookupdata.type
      if lookuptype then
        local rules=lookupdata.rules
        if rules then
          local format=lookupdata.format
          local validformat=valid[format]
          if not validformat then
            report_prepare("unsupported format %a",format)
          elseif not validformat[lookuptype] then
            report_prepare("unsupported format %a, lookuptype %a, lookupname %a",format,lookuptype,lookupname)
          else
            local contexts=lookuphash[lookupname]
            if not contexts then
              contexts={}
              lookuphash[lookupname]=contexts
            end
            local t,nt={},0
            for nofrules=1,#rules do
              local rule=rules[nofrules]
              local current=rule.current
              local before=rule.before
              local after=rule.after
              local replacements=rule.replacements
              local sequence={}
              local nofsequences=0
              if before then
                for n=1,#before do
                  nofsequences=nofsequences+1
                  sequence[nofsequences]=before[n]
                end
              end
              local start=nofsequences+1
              for n=1,#current do
                nofsequences=nofsequences+1
                sequence[nofsequences]=current[n]
              end
              local stop=nofsequences
              if after then
                for n=1,#after do
                  nofsequences=nofsequences+1
                  sequence[nofsequences]=after[n]
                end
              end
              if sequence[1] then
                nt=nt+1
                t[nt]={ nofrules,lookuptype,sequence,start,stop,rule.lookups,replacements }
                for unic,_ in next,sequence[start] do
                  local cu=contexts[unic]
                  if not cu then
                    contexts[unic]=t
                  end
                end
              end
            end
          end
        else
        end
      else
        report_prepare("missing lookuptype for lookupname %a",lookupname)
      end
    end
  end
end
local function featuresinitializer(tfmdata,value)
  if true then
    local rawdata=tfmdata.shared.rawdata
    local properties=rawdata.properties
    if not properties.initialized then
      local starttime=trace_preparing and os.clock()
      local resources=rawdata.resources
      resources.lookuphash=resources.lookuphash or {}
      prepare_contextchains(tfmdata)
      prepare_lookups(tfmdata)
      properties.initialized=true
      if trace_preparing then
        report_prepare("preparation time is %0.3f seconds for %a",os.clock()-starttime,tfmdata.properties.fullname)
      end
    end
  end
end
registerotffeature {
  name="features",
  description="features",
  default=true,
  initializers={
    position=1,
    node=featuresinitializer,
  },
  processors={
    node=featuresprocessor,
  }
}
otf.handlers=handlers

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otp']={
  version=1.001,
  comment="companion to font-otf.lua (packing)",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type=next,type
local sort,concat=table.sort,table.concat
local sortedhash=table.sortedhash
local trace_packing=false trackers.register("otf.packing",function(v) trace_packing=v end)
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
local report_otf=logs.reporter("fonts","otf loading")
fonts=fonts or {}
local handlers=fonts.handlers or {}
fonts.handlers=handlers
local otf=handlers.otf or {}
handlers.otf=otf
local enhancers=otf.enhancers or {}
otf.enhancers=enhancers
local glists=otf.glists or { "gsub","gpos" }
otf.glists=glists
local criterium=1
local threshold=0
local function tabstr_normal(t)
  local s={}
  local n=0
  for k,v in next,t do
    n=n+1
    if type(v)=="table" then
      s[n]=k..">"..tabstr_normal(v)
    elseif v==true then
      s[n]=k.."+" 
    elseif v then
      s[n]=k.."="..v
    else
      s[n]=k.."-" 
    end
  end
  if n==0 then
    return ""
  elseif n==1 then
    return s[1]
  else
    sort(s) 
    return concat(s,",")
  end
end
local function tabstr_flat(t)
  local s={}
  local n=0
  for k,v in next,t do
    n=n+1
    s[n]=k.."="..v
  end
  if n==0 then
    return ""
  elseif n==1 then
    return s[1]
  else
    sort(s) 
    return concat(s,",")
  end
end
local function tabstr_mixed(t) 
  local s={}
  local n=#t
  if n==0 then
    return ""
  elseif n==1 then
    local k=t[1]
    if k==true then
      return "++" 
    elseif k==false then
      return "--" 
    else
      return tostring(k) 
    end
  else
    for i=1,n do
      local k=t[i]
      if k==true then
        s[i]="++" 
      elseif k==false then
        s[i]="--" 
      else
        s[i]=k 
      end
    end
    return concat(s,",")
  end
end
local function tabstr_boolean(t)
  local s={}
  local n=0
  for k,v in next,t do
    n=n+1
    if v then
      s[n]=k.."+"
    else
      s[n]=k.."-"
    end
  end
  if n==0 then
    return ""
  elseif n==1 then
    return s[1]
  else
    sort(s) 
    return concat(s,",")
  end
end
local function packdata(data)
  if data then
    local h,t,c={},{},{}
    local hh,tt,cc={},{},{}
    local nt,ntt=0,0
    local function pack_normal(v)
      local tag=tabstr_normal(v)
      local ht=h[tag]
      if ht then
        c[ht]=c[ht]+1
        return ht
      else
        nt=nt+1
        t[nt]=v
        h[tag]=nt
        c[nt]=1
        return nt
      end
    end
    local function pack_flat(v)
      local tag=tabstr_flat(v)
      local ht=h[tag]
      if ht then
        c[ht]=c[ht]+1
        return ht
      else
        nt=nt+1
        t[nt]=v
        h[tag]=nt
        c[nt]=1
        return nt
      end
    end
    local function pack_boolean(v)
      local tag=tabstr_boolean(v)
      local ht=h[tag]
      if ht then
        c[ht]=c[ht]+1
        return ht
      else
        nt=nt+1
        t[nt]=v
        h[tag]=nt
        c[nt]=1
        return nt
      end
    end
    local function pack_indexed(v)
      local tag=concat(v," ")
      local ht=h[tag]
      if ht then
        c[ht]=c[ht]+1
        return ht
      else
        nt=nt+1
        t[nt]=v
        h[tag]=nt
        c[nt]=1
        return nt
      end
    end
    local function pack_mixed(v)
      local tag=tabstr_mixed(v)
      local ht=h[tag]
      if ht then
        c[ht]=c[ht]+1
        return ht
      else
        nt=nt+1
        t[nt]=v
        h[tag]=nt
        c[nt]=1
        return nt
      end
    end
    local function pack_final(v)
      if c[v]<=criterium then
        return t[v]
      else
        local hv=hh[v]
        if hv then
          return hv
        else
          ntt=ntt+1
          tt[ntt]=t[v]
          hh[v]=ntt
          cc[ntt]=c[v]
          return ntt
        end
      end
    end
    local function success(stage,pass)
      if nt==0 then
        if trace_loading or trace_packing then
          report_otf("pack quality: nothing to pack")
        end
        return false
      elseif nt>=threshold then
        local one,two,rest=0,0,0
        if pass==1 then
          for k,v in next,c do
            if v==1 then
              one=one+1
            elseif v==2 then
              two=two+1
            else
              rest=rest+1
            end
          end
        else
          for k,v in next,cc do
            if v>20 then
              rest=rest+1
            elseif v>10 then
              two=two+1
            else
              one=one+1
            end
          end
          data.tables=tt
        end
        if trace_loading or trace_packing then
          report_otf("pack quality: stage %s, pass %s, %s packed, 1-10:%s, 11-20:%s, rest:%s (criterium: %s)",stage,pass,one+two+rest,one,two,rest,criterium)
        end
        return true
      else
        if trace_loading or trace_packing then
          report_otf("pack quality: stage %s, pass %s, %s packed, aborting pack (threshold: %s)",stage,pass,nt,threshold)
        end
        return false
      end
    end
    local function packers(pass)
      if pass==1 then
        return pack_normal,pack_indexed,pack_flat,pack_boolean,pack_mixed
      else
        return pack_final,pack_final,pack_final,pack_final,pack_final
      end
    end
    local resources=data.resources
    local lookuptypes=resources.lookuptypes
    for pass=1,2 do
      if trace_packing then
        report_otf("start packing: stage 1, pass %s",pass)
      end
      local pack_normal,pack_indexed,pack_flat,pack_boolean,pack_mixed=packers(pass)
      for unicode,description in next,data.descriptions do
        local boundingbox=description.boundingbox
        if boundingbox then
          description.boundingbox=pack_indexed(boundingbox)
        end
        local slookups=description.slookups
        if slookups then
          for tag,slookup in next,slookups do
            local what=lookuptypes[tag]
            if what=="pair" then
              local t=slookup[2] if t then slookup[2]=pack_indexed(t) end
              local t=slookup[3] if t then slookup[3]=pack_indexed(t) end
            elseif what~="substitution" then
              slookups[tag]=pack_indexed(slookup) 
            end
          end
        end
        local mlookups=description.mlookups
        if mlookups then
          for tag,mlookup in next,mlookups do
            local what=lookuptypes[tag]
            if what=="pair" then
              for i=1,#mlookup do
                local lookup=mlookup[i]
                local t=lookup[2] if t then lookup[2]=pack_indexed(t) end
                local t=lookup[3] if t then lookup[3]=pack_indexed(t) end
              end
            elseif what~="substitution" then
              for i=1,#mlookup do
                mlookup[i]=pack_indexed(mlookup[i]) 
              end
            end
          end
        end
        local kerns=description.kerns
        if kerns then
          for tag,kern in next,kerns do
            kerns[tag]=pack_flat(kern)
          end
        end
        local math=description.math
        if math then
          local kerns=math.kerns
          if kerns then
            for tag,kern in next,kerns do
              kerns[tag]=pack_normal(kern)
            end
          end
        end
        local anchors=description.anchors
        if anchors then
          for what,anchor in next,anchors do
            if what=="baselig" then
              for _,a in next,anchor do
                for k=1,#a do
                  a[k]=pack_indexed(a[k])
                end
              end
            else
              for k,v in next,anchor do
                anchor[k]=pack_indexed(v)
              end
            end
          end
        end
        local altuni=description.altuni
        if altuni then
          for i=1,#altuni do
            altuni[i]=pack_flat(altuni[i])
          end
        end
      end
      local lookups=data.lookups
      if lookups then
        for _,lookup in next,lookups do
          local rules=lookup.rules
          if rules then
            for i=1,#rules do
              local rule=rules[i]
              local r=rule.before    if r then for i=1,#r do r[i]=pack_boolean(r[i]) end end
              local r=rule.after    if r then for i=1,#r do r[i]=pack_boolean(r[i]) end end
              local r=rule.current   if r then for i=1,#r do r[i]=pack_boolean(r[i]) end end
              local r=rule.replacements if r then rule.replacements=pack_flat  (r)  end 
              local r=rule.lookups   if r then rule.lookups=pack_indexed(r)  end
            end
          end
        end
      end
      local anchor_to_lookup=resources.anchor_to_lookup
      if anchor_to_lookup then
        for anchor,lookup in next,anchor_to_lookup do
          anchor_to_lookup[anchor]=pack_normal(lookup)
        end
      end
      local lookup_to_anchor=resources.lookup_to_anchor
      if lookup_to_anchor then
        for lookup,anchor in next,lookup_to_anchor do
          lookup_to_anchor[lookup]=pack_normal(anchor)
        end
      end
      local sequences=resources.sequences
      if sequences then
        for feature,sequence in next,sequences do
          local flags=sequence.flags
          if flags then
            sequence.flags=pack_normal(flags)
          end
          local subtables=sequence.subtables
          if subtables then
            sequence.subtables=pack_normal(subtables)
          end
          local features=sequence.features
          if features then
            for script,feature in next,features do
              features[script]=pack_normal(feature)
            end
          end
          local order=sequence.order
          if order then
            sequence.order=pack_indexed(order)
          end
          local markclass=sequence.markclass
          if markclass then
            sequence.markclass=pack_boolean(markclass)
          end
        end
      end
      local lookups=resources.lookups
      if lookups then
        for name,lookup in next,lookups do
          local flags=lookup.flags
          if flags then
            lookup.flags=pack_normal(flags)
          end
          local subtables=lookup.subtables
          if subtables then
            lookup.subtables=pack_normal(subtables)
          end
        end
      end
      local features=resources.features
      if features then
        for _,what in next,glists do
          local list=features[what]
          if list then
            for feature,spec in next,list do
              list[feature]=pack_normal(spec)
            end
          end
        end
      end
      if not success(1,pass) then
        return
      end
    end
    if nt>0 then
      for pass=1,2 do
        if trace_packing then
          report_otf("start packing: stage 2, pass %s",pass)
        end
        local pack_normal,pack_indexed,pack_flat,pack_boolean,pack_mixed=packers(pass)
        for unicode,description in next,data.descriptions do
          local kerns=description.kerns
          if kerns then
            description.kerns=pack_normal(kerns)
          end
          local math=description.math
          if math then
            local kerns=math.kerns
            if kerns then
              math.kerns=pack_normal(kerns)
            end
          end
          local anchors=description.anchors
          if anchors then
            description.anchors=pack_normal(anchors)
          end
          local mlookups=description.mlookups
          if mlookups then
            for tag,mlookup in next,mlookups do
              mlookups[tag]=pack_normal(mlookup)
            end
          end
          local altuni=description.altuni
          if altuni then
            description.altuni=pack_normal(altuni)
          end
        end
        local lookups=data.lookups
        if lookups then
          for _,lookup in next,lookups do
            local rules=lookup.rules
            if rules then
              for i=1,#rules do 
                local rule=rules[i]
                local r=rule.before if r then rule.before=pack_normal(r) end
                local r=rule.after  if r then rule.after=pack_normal(r) end
                local r=rule.current if r then rule.current=pack_normal(r) end
              end
            end
          end
        end
        local sequences=resources.sequences
        if sequences then
          for feature,sequence in next,sequences do
            sequence.features=pack_normal(sequence.features)
          end
        end
        if not success(2,pass) then
        end
      end
      for pass=1,2 do
        local pack_normal,pack_indexed,pack_flat,pack_boolean,pack_mixed=packers(pass)
        for unicode,description in next,data.descriptions do
          local slookups=description.slookups
          if slookups then
            description.slookups=pack_normal(slookups)
          end
          local mlookups=description.mlookups
          if mlookups then
            description.mlookups=pack_normal(mlookups)
          end
        end
      end
    end
  end
end
local unpacked_mt={
  __index=function(t,k)
      t[k]=false
      return k 
    end
}
local function unpackdata(data)
  if data then
    local tables=data.tables
    if tables then
      local resources=data.resources
      local lookuptypes=resources.lookuptypes
      local unpacked={}
      setmetatable(unpacked,unpacked_mt)
      for unicode,description in next,data.descriptions do
        local tv=tables[description.boundingbox]
        if tv then
          description.boundingbox=tv
        end
        local slookups=description.slookups
        if slookups then
          local tv=tables[slookups]
          if tv then
            description.slookups=tv
            slookups=unpacked[tv]
          end
          if slookups then
            for tag,lookup in next,slookups do
              local what=lookuptypes[tag]
              if what=="pair" then
                local tv=tables[lookup[2]]
                if tv then
                  lookup[2]=tv
                end
                local tv=tables[lookup[3]]
                if tv then
                  lookup[3]=tv
                end
              elseif what~="substitution" then
                local tv=tables[lookup]
                if tv then
                  slookups[tag]=tv
                end
              end
            end
          end
        end
        local mlookups=description.mlookups
        if mlookups then
          local tv=tables[mlookups]
          if tv then
            description.mlookups=tv
            mlookups=unpacked[tv]
          end
          if mlookups then
            for tag,list in next,mlookups do
              local tv=tables[list]
              if tv then
                mlookups[tag]=tv
                list=unpacked[tv]
              end
              if list then
                local what=lookuptypes[tag]
                if what=="pair" then
                  for i=1,#list do
                    local lookup=list[i]
                    local tv=tables[lookup[2]]
                    if tv then
                      lookup[2]=tv
                    end
                    local tv=tables[lookup[3]]
                    if tv then
                      lookup[3]=tv
                    end
                  end
                elseif what~="substitution" then
                  for i=1,#list do
                    local tv=tables[list[i]]
                    if tv then
                      list[i]=tv
                    end
                  end
                end
              end
            end
          end
        end
        local kerns=description.kerns
        if kerns then
          local tm=tables[kerns]
          if tm then
            description.kerns=tm
            kerns=unpacked[tm]
          end
          if kerns then
            for k,kern in next,kerns do
              local tv=tables[kern]
              if tv then
                kerns[k]=tv
              end
            end
          end
        end
        local math=description.math
        if math then
          local kerns=math.kerns
          if kerns then
            local tm=tables[kerns]
            if tm then
              math.kerns=tm
              kerns=unpacked[tm]
            end
            if kerns then
              for k,kern in next,kerns do
                local tv=tables[kern]
                if tv then
                  kerns[k]=tv
                end
              end
            end
          end
        end
        local anchors=description.anchors
        if anchors then
          local ta=tables[anchors]
          if ta then
            description.anchors=ta
            anchors=unpacked[ta]
          end
          if anchors then
            for tag,anchor in next,anchors do
              if tag=="baselig" then
                for _,list in next,anchor do
                  for i=1,#list do
                    local tv=tables[list[i]]
                    if tv then
                      list[i]=tv
                    end
                  end
                end
              else
                for a,data in next,anchor do
                  local tv=tables[data]
                  if tv then
                    anchor[a]=tv
                  end
                end
              end
            end
          end
        end
        local altuni=description.altuni
        if altuni then
          local altuni=tables[altuni]
          if altuni then
            description.altuni=altuni
            for i=1,#altuni do
              local tv=tables[altuni[i]]
              if tv then
                altuni[i]=tv
              end
            end
          end
        end
      end
      local lookups=data.lookups
      if lookups then
        for _,lookup in next,lookups do
          local rules=lookup.rules
          if rules then
            for i=1,#rules do 
              local rule=rules[i]
              local before=rule.before
              if before then
                local tv=tables[before]
                if tv then
                  rule.before=tv
                  before=unpacked[tv]
                end
                if before then
                  for i=1,#before do
                    local tv=tables[before[i]]
                    if tv then
                      before[i]=tv
                    end
                  end
                end
              end
              local after=rule.after
              if after then
                local tv=tables[after]
                if tv then
                  rule.after=tv
                  after=unpacked[tv]
                end
                if after then
                  for i=1,#after do
                    local tv=tables[after[i]]
                    if tv then
                      after[i]=tv
                    end
                  end
                end
              end
              local current=rule.current
              if current then
                local tv=tables[current]
                if tv then
                  rule.current=tv
                  current=unpacked[tv]
                end
                if current then
                  for i=1,#current do
                    local tv=tables[current[i]]
                    if tv then
                      current[i]=tv
                    end
                  end
                end
              end
              local replacements=rule.replacements
              if replacements then
                local tv=tables[replacements]
                if tv then
                  rule.replacements=tv
                end
              end
              local fore=rule.fore
              if fore then
                local tv=tables[fore]
                if tv then
                  rule.fore=tv
                end
              end
              local back=rule.back
              if back then
                local tv=tables[back]
                if tv then
                  rule.back=tv
                end
              end
              local names=rule.names
              if names then
                local tv=tables[names]
                if tv then
                  rule.names=tv
                end
              end
              local lookups=rule.lookups
              if lookups then
                local tv=tables[lookups]
                if tv then
                  rule.lookups=tv
                end
              end
            end
          end
        end
      end
      local anchor_to_lookup=resources.anchor_to_lookup
      if anchor_to_lookup then
        for anchor,lookup in next,anchor_to_lookup do
          local tv=tables[lookup]
          if tv then
            anchor_to_lookup[anchor]=tv
          end
        end
      end
      local lookup_to_anchor=resources.lookup_to_anchor
      if lookup_to_anchor then
        for lookup,anchor in next,lookup_to_anchor do
          local tv=tables[anchor]
          if tv then
            lookup_to_anchor[lookup]=tv
          end
        end
      end
      local ls=resources.sequences
      if ls then
        for _,feature in next,ls do
          local flags=feature.flags
          if flags then
            local tv=tables[flags]
            if tv then
              feature.flags=tv
            end
          end
          local subtables=feature.subtables
          if subtables then
            local tv=tables[subtables]
            if tv then
              feature.subtables=tv
            end
          end
          local features=feature.features
          if features then
            local tv=tables[features]
            if tv then
              feature.features=tv
              features=unpacked[tv]
            end
            if features then
              for script,data in next,features do
                local tv=tables[data]
                if tv then
                  features[script]=tv
                end
              end
            end
          end
          local order=feature.order
          if order then
            local tv=tables[order]
            if tv then
              feature.order=tv
            end
          end
          local markclass=feature.markclass
          if markclass then
            local tv=tables[markclass]
            if tv then
              feature.markclass=tv
            end
          end
        end
      end
      local lookups=resources.lookups
      if lookups then
        for _,lookup in next,lookups do
          local flags=lookup.flags
          if flags then
            local tv=tables[flags]
            if tv then
              lookup.flags=tv
            end
          end
          local subtables=lookup.subtables
          if subtables then
            local tv=tables[subtables]
            if tv then
              lookup.subtables=tv
            end
          end
        end
      end
      local features=resources.features
      if features then
        for _,what in next,glists do
          local feature=features[what]
          if feature then
            for tag,spec in next,feature do
              local tv=tables[spec]
              if tv then
                feature[tag]=tv
              end
            end
          end
        end
      end
      data.tables=nil
    end
  end
end
if otf.enhancers.register then
  otf.enhancers.register("pack",packdata)
  otf.enhancers.register("unpack",unpackdata)
end
otf.enhancers.unpack=unpackdata 

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-fonts-lua']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
fonts.formats.lua="lua"
function fonts.readers.lua(specification)
  local fullname=specification.filename or ""
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      fullname=specification.name.."."..forced
    else
      fullname=specification.name
    end
  end
  local fullname=resolvers.findfile(fullname) or ""
  if fullname~="" then
    local loader=loadfile(fullname)
    loader=loader and loader()
    return loader and loader(specification)
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-def']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local format,gmatch,match,find,lower,gsub=string.format,string.gmatch,string.match,string.find,string.lower,string.gsub
local tostring,next=tostring,next
local lpegmatch=lpeg.match
local suffixonly,removesuffix=file.suffix,file.removesuffix
local allocate=utilities.storage.allocate
local trace_defining=false trackers .register("fonts.defining",function(v) trace_defining=v end)
local directive_embedall=false directives.register("fonts.embedall",function(v) directive_embedall=v end)
trackers.register("fonts.loading","fonts.defining","otf.loading","afm.loading","tfm.loading")
trackers.register("fonts.all","fonts.*","otf.*","afm.*","tfm.*")
local report_defining=logs.reporter("fonts","defining")
local fonts=fonts
local fontdata=fonts.hashes.identifiers
local readers=fonts.readers
local definers=fonts.definers
local specifiers=fonts.specifiers
local constructors=fonts.constructors
local fontgoodies=fonts.goodies
readers.sequence=allocate { 'otf','ttf','afm','tfm','lua' } 
local variants=allocate()
specifiers.variants=variants
definers.methods=definers.methods or {}
local internalized=allocate() 
local lastdefined=nil 
local loadedfonts=constructors.loadedfonts
local designsizes=constructors.designsizes
local resolvefile=fontgoodies and fontgoodies.filenames and fontgoodies.filenames.resolve or function(s) return s end
local splitter,splitspecifiers=nil,"" 
local P,C,S,Cc=lpeg.P,lpeg.C,lpeg.S,lpeg.Cc
local left=P("(")
local right=P(")")
local colon=P(":")
local space=P(" ")
definers.defaultlookup="file"
local prefixpattern=P(false)
local function addspecifier(symbol)
  splitspecifiers=splitspecifiers..symbol
  local method=S(splitspecifiers)
  local lookup=C(prefixpattern)*colon
  local sub=left*C(P(1-left-right-method)^1)*right
  local specification=C(method)*C(P(1)^1)
  local name=C((1-sub-specification)^1)
  splitter=P((lookup+Cc(""))*name*(sub+Cc(""))*(specification+Cc("")))
end
local function addlookup(str,default)
  prefixpattern=prefixpattern+P(str)
end
definers.addlookup=addlookup
addlookup("file")
addlookup("name")
addlookup("spec")
local function getspecification(str)
  return lpegmatch(splitter,str or "") 
end
definers.getspecification=getspecification
function definers.registersplit(symbol,action,verbosename)
  addspecifier(symbol)
  variants[symbol]=action
  if verbosename then
    variants[verbosename]=action
  end
end
local function makespecification(specification,lookup,name,sub,method,detail,size)
  size=size or 655360
  if not lookup or lookup=="" then
    lookup=definers.defaultlookup
  end
  if trace_defining then
    report_defining("specification %a, lookup %a, name %a, sub %a, method %a, detail %a",
      specification,lookup,name,sub,method,detail)
  end
  local t={
    lookup=lookup,
    specification=specification,
    size=size,
    name=name,
    sub=sub,
    method=method,
    detail=detail,
    resolved="",
    forced="",
    features={},
  }
  return t
end
definers.makespecification=makespecification
function definers.analyze(specification,size)
  local lookup,name,sub,method,detail=getspecification(specification or "")
  return makespecification(specification,lookup,name,sub,method,detail,size)
end
definers.resolvers=definers.resolvers or {}
local resolvers=definers.resolvers
function resolvers.file(specification)
  local name=resolvefile(specification.name) 
  local suffix=lower(suffixonly(name))
  if fonts.formats[suffix] then
    specification.forced=suffix
    specification.forcedname=name
    specification.name=removesuffix(name)
  else
    specification.name=name 
  end
end
function resolvers.name(specification)
  local resolve=fonts.names.resolve
  if resolve then
    local resolved,sub=resolve(specification.name,specification.sub,specification) 
    if resolved then
      specification.resolved=resolved
      specification.sub=sub
      local suffix=lower(suffixonly(resolved))
      if fonts.formats[suffix] then
        specification.forced=suffix
        specification.forcedname=resolved
        specification.name=removesuffix(resolved)
      else
        specification.name=resolved
      end
    end
  else
    resolvers.file(specification)
  end
end
function resolvers.spec(specification)
  local resolvespec=fonts.names.resolvespec
  if resolvespec then
    local resolved,sub=resolvespec(specification.name,specification.sub,specification) 
    if resolved then
      specification.resolved=resolved
      specification.sub=sub
      specification.forced=lower(suffixonly(resolved))
      specification.forcedname=resolved
      specification.name=removesuffix(resolved)
    end
  else
    resolvers.name(specification)
  end
end
function definers.resolve(specification)
  if not specification.resolved or specification.resolved=="" then 
    local r=resolvers[specification.lookup]
    if r then
      r(specification)
    end
  end
  if specification.forced=="" then
    specification.forced=nil
    specification.forcedname=nil
  end
  specification.hash=lower(specification.name..' @ '..constructors.hashfeatures(specification))
  if specification.sub and specification.sub~="" then
    specification.hash=specification.sub..' @ '..specification.hash
  end
  return specification
end
function definers.applypostprocessors(tfmdata)
  local postprocessors=tfmdata.postprocessors
  if postprocessors then
    local properties=tfmdata.properties
    for i=1,#postprocessors do
      local extrahash=postprocessors[i](tfmdata) 
      if type(extrahash)=="string" and extrahash~="" then
        extrahash=gsub(lower(extrahash),"[^a-z]","-")
        properties.fullname=format("%s-%s",properties.fullname,extrahash)
      end
    end
  end
  return tfmdata
end
local function checkembedding(tfmdata)
  local properties=tfmdata.properties
  local embedding
  if directive_embedall then
    embedding="full"
  elseif properties and properties.filename and constructors.dontembed[properties.filename] then
    embedding="no"
  else
    embedding="subset"
  end
  if properties then
    properties.embedding=embedding
  else
    tfmdata.properties={ embedding=embedding }
  end
  tfmdata.embedding=embedding
end
function definers.loadfont(specification)
  local hash=constructors.hashinstance(specification)
  local tfmdata=loadedfonts[hash] 
  if not tfmdata then
    local forced=specification.forced or ""
    if forced~="" then
      local reader=readers[lower(forced)] 
      tfmdata=reader and reader(specification)
      if not tfmdata then
        report_defining("forced type %a of %a not found",forced,specification.name)
      end
    else
      local sequence=readers.sequence 
      for s=1,#sequence do
        local reader=sequence[s]
        if readers[reader] then 
          if trace_defining then
            report_defining("trying (reader sequence driven) type %a for %a with file %a",reader,specification.name,specification.filename)
          end
          tfmdata=readers[reader](specification)
          if tfmdata then
            break
          else
            specification.filename=nil
          end
        end
      end
    end
    if tfmdata then
      tfmdata=definers.applypostprocessors(tfmdata)
      checkembedding(tfmdata) 
      loadedfonts[hash]=tfmdata
      designsizes[specification.hash]=tfmdata.parameters.designsize
    end
  end
  if not tfmdata then
    report_defining("font with asked name %a is not found using lookup %a",specification.name,specification.lookup)
  end
  return tfmdata
end
function constructors.checkvirtualids()
end
function constructors.readanddefine(name,size) 
  local specification=definers.analyze(name,size)
  local method=specification.method
  if method and variants[method] then
    specification=variants[method](specification)
  end
  specification=definers.resolve(specification)
  local hash=constructors.hashinstance(specification)
  local id=definers.registered(hash)
  if not id then
    local tfmdata=definers.loadfont(specification)
    if tfmdata then
      tfmdata.properties.hash=hash
      constructors.checkvirtualids(tfmdata) 
      id=font.define(tfmdata)
      definers.register(tfmdata,id)
    else
      id=0 
    end
  end
  return fontdata[id],id
end
function definers.current() 
  return lastdefined
end
function definers.registered(hash)
  local id=internalized[hash]
  return id,id and fontdata[id]
end
function definers.register(tfmdata,id)
  if tfmdata and id then
    local hash=tfmdata.properties.hash
    if not hash then
      report_defining("registering font, id %a, name %a, invalid hash",id,tfmdata.properties.filename or "?")
    elseif not internalized[hash] then
      internalized[hash]=id
      if trace_defining then
        report_defining("registering font, id %s, hash %a",id,hash)
      end
      fontdata[id]=tfmdata
    end
  end
end
function definers.read(specification,size,id) 
  statistics.starttiming(fonts)
  if type(specification)=="string" then
    specification=definers.analyze(specification,size)
  end
  local method=specification.method
  if method and variants[method] then
    specification=variants[method](specification)
  end
  specification=definers.resolve(specification)
  local hash=constructors.hashinstance(specification)
  local tfmdata=definers.registered(hash) 
  if tfmdata then
    if trace_defining then
      report_defining("already hashed: %s",hash)
    end
  else
    tfmdata=definers.loadfont(specification) 
    if tfmdata then
      if trace_defining then
        report_defining("loaded and hashed: %s",hash)
      end
      tfmdata.properties.hash=hash
      if id then
        definers.register(tfmdata,id)
      end
    else
      if trace_defining then
        report_defining("not loaded and hashed: %s",hash)
      end
    end
  end
  lastdefined=tfmdata or id 
  if not tfmdata then 
    report_defining("unknown font %a, loading aborted",specification.name)
  elseif trace_defining and type(tfmdata)=="table" then
    local properties=tfmdata.properties or {}
    local parameters=tfmdata.parameters or {}
    report_defining("using %s font with id %a, name %a, size %a, bytes %a, encoding %a, fullname %a, filename %a",
      properties.format,id,properties.name,parameters.size,properties.encodingbytes,
      properties.encodingname,properties.fullname,file.basename(properties.filename))
  end
  statistics.stoptiming(fonts)
  return tfmdata
end
function font.getfont(id)
  return fontdata[id] 
end
callbacks.register('define_font',definers.read,"definition of fonts (tfmdata preparation)")

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-font-def']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
fonts.constructors.namemode="specification"
function fonts.definers.getspecification(str)
  return "",str,"",":",str
end
local list={}
local function issome ()  list.lookup='name'     end 
local function isfile ()  list.lookup='file'     end
local function isname ()  list.lookup='name'     end
local function thename(s)  list.name=s        end
local function issub (v)  list.sub=v        end
local function iscrap (s)  list.crap=string.lower(s) end
local function iskey (k,v) list[k]=v        end
local function istrue (s)  list[s]=true      end
local function isfalse(s)  list[s]=false      end
local P,S,R,C=lpeg.P,lpeg.S,lpeg.R,lpeg.C
local spaces=P(" ")^0
local namespec=(1-S("/:("))^0 
local crapspec=spaces*P("/")*(((1-P(":"))^0)/iscrap)*spaces
local filename_1=P("file:")/isfile*(namespec/thename)
local filename_2=P("[")*P(true)/isname*(((1-P("]"))^0)/thename)*P("]")
local fontname_1=P("name:")/isname*(namespec/thename)
local fontname_2=P(true)/issome*(namespec/thename)
local sometext=(R("az","AZ","09")+S("+-."))^1
local truevalue=P("+")*spaces*(sometext/istrue)
local falsevalue=P("-")*spaces*(sometext/isfalse)
local keyvalue=(C(sometext)*spaces*P("=")*spaces*C(sometext))/iskey
local somevalue=sometext/istrue
local subvalue=P("(")*(C(P(1-S("()"))^1)/issub)*P(")") 
local option=spaces*(keyvalue+falsevalue+truevalue+somevalue)*spaces
local options=P(":")*spaces*(P(";")^0*option)^0
local pattern=(filename_1+filename_2+fontname_1+fontname_2)*subvalue^0*crapspec^0*options^0
local function colonized(specification) 
  list={}
  lpeg.match(pattern,specification.specification)
  list.crap=nil 
  if list.name then
    specification.name=list.name
    list.name=nil
  end
  if list.lookup then
    specification.lookup=list.lookup
    list.lookup=nil
  end
  if list.sub then
    specification.sub=list.sub
    list.sub=nil
  end
  specification.features.normal=fonts.handlers.otf.features.normalize(list)
  return specification
end
fonts.definers.registersplit(":",colonized,"cryptic")
fonts.definers.registersplit("",colonized,"more cryptic") 
function fonts.definers.applypostprocessors(tfmdata)
  local postprocessors=tfmdata.postprocessors
  if postprocessors then
    for i=1,#postprocessors do
      local extrahash=postprocessors[i](tfmdata) 
      if type(extrahash)=="string" and extrahash~="" then
        extrahash=string.gsub(lower(extrahash),"[^a-z]","-")
        tfmdata.properties.fullname=format("%s-%s",tfmdata.properties.fullname,extrahash)
      end
    end
  end
  return tfmdata
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-fonts-ext']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
local otffeatures=fonts.constructors.newfeatures("otf")
local function initializeitlc(tfmdata,value)
  if value then
    local parameters=tfmdata.parameters
    local italicangle=parameters.italicangle
    if italicangle and italicangle~=0 then
      local properties=tfmdata.properties
      local factor=tonumber(value) or 1
      properties.hasitalics=true
      properties.autoitalicamount=factor*(parameters.uwidth or 40)/2
    end
  end
end
otffeatures.register {
  name="itlc",
  description="italic correction",
  initializers={
    base=initializeitlc,
    node=initializeitlc,
  }
}
local function initializeslant(tfmdata,value)
  value=tonumber(value)
  if not value then
    value=0
  elseif value>1 then
    value=1
  elseif value<-1 then
    value=-1
  end
  tfmdata.parameters.slantfactor=value
end
otffeatures.register {
  name="slant",
  description="slant glyphs",
  initializers={
    base=initializeslant,
    node=initializeslant,
  }
}
local function initializeextend(tfmdata,value)
  value=tonumber(value)
  if not value then
    value=0
  elseif value>10 then
    value=10
  elseif value<-10 then
    value=-10
  end
  tfmdata.parameters.extendfactor=value
end
otffeatures.register {
  name="extend",
  description="scale glyphs horizontally",
  initializers={
    base=initializeextend,
    node=initializeextend,
  }
}
fonts.protrusions=fonts.protrusions    or {}
fonts.protrusions.setups=fonts.protrusions.setups or {}
local setups=fonts.protrusions.setups
local function initializeprotrusion(tfmdata,value)
  if value then
    local setup=setups[value]
    if setup then
      local factor,left,right=setup.factor or 1,setup.left or 1,setup.right or 1
      local emwidth=tfmdata.parameters.quad
      tfmdata.parameters.protrusion={
        auto=true,
      }
      for i,chr in next,tfmdata.characters do
        local v,pl,pr=setup[i],nil,nil
        if v then
          pl,pr=v[1],v[2]
        end
        if pl and pl~=0 then chr.left_protruding=left*pl*factor end
        if pr and pr~=0 then chr.right_protruding=right*pr*factor end
      end
    end
  end
end
otffeatures.register {
  name="protrusion",
  description="shift characters into the left and or right margin",
  initializers={
    base=initializeprotrusion,
    node=initializeprotrusion,
  }
}
fonts.expansions=fonts.expansions    or {}
fonts.expansions.setups=fonts.expansions.setups or {}
local setups=fonts.expansions.setups
local function initializeexpansion(tfmdata,value)
  if value then
    local setup=setups[value]
    if setup then
      local factor=setup.factor or 1
      tfmdata.parameters.expansion={
        stretch=10*(setup.stretch or 0),
        shrink=10*(setup.shrink or 0),
        step=10*(setup.step  or 0),
        auto=true,
      }
      for i,chr in next,tfmdata.characters do
        local v=setup[i]
        if v and v~=0 then
          chr.expansion_factor=v*factor
        else 
          chr.expansion_factor=factor
        end
      end
    end
  end
end
otffeatures.register {
  name="expansion",
  description="apply hz optimization",
  initializers={
    base=initializeexpansion,
    node=initializeexpansion,
  }
}
function fonts.loggers.onetimemessage() end
local byte=string.byte
fonts.expansions.setups['default']={
  stretch=2,shrink=2,step=.5,factor=1,
  [byte('A')]=0.5,[byte('B')]=0.7,[byte('C')]=0.7,[byte('D')]=0.5,[byte('E')]=0.7,
  [byte('F')]=0.7,[byte('G')]=0.5,[byte('H')]=0.7,[byte('K')]=0.7,[byte('M')]=0.7,
  [byte('N')]=0.7,[byte('O')]=0.5,[byte('P')]=0.7,[byte('Q')]=0.5,[byte('R')]=0.7,
  [byte('S')]=0.7,[byte('U')]=0.7,[byte('W')]=0.7,[byte('Z')]=0.7,
  [byte('a')]=0.7,[byte('b')]=0.7,[byte('c')]=0.7,[byte('d')]=0.7,[byte('e')]=0.7,
  [byte('g')]=0.7,[byte('h')]=0.7,[byte('k')]=0.7,[byte('m')]=0.7,[byte('n')]=0.7,
  [byte('o')]=0.7,[byte('p')]=0.7,[byte('q')]=0.7,[byte('s')]=0.7,[byte('u')]=0.7,
  [byte('w')]=0.7,[byte('z')]=0.7,
  [byte('2')]=0.7,[byte('3')]=0.7,[byte('6')]=0.7,[byte('8')]=0.7,[byte('9')]=0.7,
}
fonts.protrusions.setups['default']={
  factor=1,left=1,right=1,
  [0x002C]={ 0,1  },
  [0x002E]={ 0,1  },
  [0x003A]={ 0,1  },
  [0x003B]={ 0,1  },
  [0x002D]={ 0,1  },
  [0x2013]={ 0,0.50 },
  [0x2014]={ 0,0.33 },
  [0x3001]={ 0,1  },
  [0x3002]={ 0,1  },
  [0x060C]={ 0,1  },
  [0x061B]={ 0,1  },
  [0x06D4]={ 0,1  },
}
fonts.handlers.otf.features.normalize=function(t)
  if t.rand then
    t.rand="random"
  end
  return t
end
function fonts.helpers.nametoslot(name)
  local t=type(name)
  if t=="string" then
    local tfmdata=fonts.hashes.identifiers[currentfont()]
    local shared=tfmdata and tfmdata.shared
    local fntdata=shared and shared.rawdata
    return fntdata and fntdata.resources.unicodes[name]
  elseif t=="number" then
    return n
  end
end
fonts.encodings=fonts.encodings or {}
local reencodings={}
fonts.encodings.reencodings=reencodings
local function specialreencode(tfmdata,value)
  local encoding=value and reencodings[value]
  if encoding then
    local temp={}
    local char=tfmdata.characters
    for k,v in next,encoding do
      temp[k]=char[v]
    end
    for k,v in next,temp do
      char[k]=temp[k]
    end
    return string.format("reencoded:%s",value)
  end
end
local function reencode(tfmdata,value)
  tfmdata.postprocessors=tfmdata.postprocessors or {}
  table.insert(tfmdata.postprocessors,
    function(tfmdata)
      return specialreencode(tfmdata,value)
    end
  )
end
otffeatures.register {
  name="reencode",
  description="reencode characters",
  manipulators={
    base=reencode,
    node=reencode,
  }
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luatex-fonts-cbk']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
if context then
  texio.write_nl("fatal error: this module is not for context")
  os.exit()
end
local fonts=fonts
local nodes=nodes
local traverse_id=node.traverse_id
local glyph_code=nodes.nodecodes.glyph
function nodes.handlers.characters(head)
  local fontdata=fonts.hashes.identifiers
  if fontdata then
    local usedfonts,done,prevfont={},false,nil
    for n in traverse_id(glyph_code,head) do
      local font=n.font
      if font~=prevfont then
        prevfont=font
        local used=usedfonts[font]
        if not used then
          local tfmdata=fontdata[font] 
          if tfmdata then
            local shared=tfmdata.shared 
            if shared then
              local processors=shared.processes
              if processors and #processors>0 then
                usedfonts[font]=processors
                done=true
              end
            end
          end
        end
      end
    end
    if done then
      for font,processors in next,usedfonts do
        for i=1,#processors do
          local h,d=processors[i](head,font,0)
          head,done=h or head,done or d
        end
      end
    end
    return head,true
  else
    return head,false
  end
end
function nodes.simple_font_handler(head)
  head=nodes.handlers.characters(head)
  nodes.injections.handler(head)
  nodes.handlers.protectglyphs(head)
  head=node.ligaturing(head)
  head=node.kerning(head)
  return head
end

end -- closure
