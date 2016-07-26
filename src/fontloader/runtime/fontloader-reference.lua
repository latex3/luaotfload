-- merged file : c:/data/develop/context/sources/luatex-fonts-merged.lua
-- parent file : c:/data/develop/context/sources/luatex-fonts.lua
-- merge date  : 07/25/16 21:49:08

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['l-lua']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
_MAJORVERSION,_MINORVERSION=string.match(_VERSION,"^[^%d]+(%d+)%.(%d+).*$")
_MAJORVERSION=tonumber(_MAJORVERSION) or 5
_MINORVERSION=tonumber(_MINORVERSION) or 1
_LUAVERSION=_MAJORVERSION+_MINORVERSION/10
if _LUAVERSION<5.2 and jit then
  _MINORVERSION=2
  _LUAVERSION=5.2
end
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
function setinspector(kind,inspector) 
  inspectors[kind]=inspector
end
function inspect(...) 
  for s=1,select("#",...) do
    local value=select(s,...)
    if value==nil then
      print("nil")
    else
      local done=false
      local kind=type(value)
      local inspector=inspectors[kind]
      if inspector then
        done=inspector(value)
        if done then
          break
        end
      end
      for kind,inspector in next,inspectors do
        done=inspector(value)
        if done then
          break
        end
      end
      if not done then
        print(tostring(value))
      end
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
local flush=io.flush
if flush then
  local execute=os.execute if execute then function os.execute(...) flush() return execute(...) end end
  local exec=os.exec  if exec  then function os.exec  (...) flush() return exec  (...) end end
  local spawn=os.spawn  if spawn  then function os.spawn (...) flush() return spawn (...) end end
  local popen=io.popen  if popen  then function io.popen (...) flush() return popen (...) end end
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
  setinspector("lpeg",function(v) if lpegtype(v) then lpegprint(v) return true end end)
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
patterns.utf_32_be_nl=P("\000\000\000\r\000\000\000\n")+P("\000\000\000\r")+P("\000\000\000\n")
patterns.utf_32_le_nl=P("\r\000\000\000\n\000\000\000")+P("\r\000\000\000")+P("\n\000\000\000")
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
local b_collapser=Cs(whitespace^0/""*(nonwhitespace^1+whitespace^1/" ")^0)
local e_collapser=Cs((whitespace^1*P(-1)/""+nonwhitespace^1+whitespace^1/" ")^0)
local m_collapser=Cs((nonwhitespace^1+whitespace^1/" ")^0)
local b_stripper=Cs(spacer^0/""*(nonspacer^1+spacer^1/" ")^0)
local e_stripper=Cs((spacer^1*P(-1)/""+nonspacer^1+spacer^1/" ")^0)
local m_stripper=Cs((nonspacer^1+spacer^1/" ")^0)
patterns.stripper=stripper
patterns.fullstripper=fullstripper
patterns.collapser=collapser
patterns.b_collapser=b_collapser
patterns.m_collapser=m_collapser
patterns.e_collapser=e_collapser
patterns.b_stripper=b_stripper
patterns.m_stripper=m_stripper
patterns.e_stripper=e_stripper
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
patterns.cpunsigned=digit^0*(period+comma)*digit^1
patterns.cfloat=sign^-1*patterns.cunsigned
patterns.cpfloat=sign^-1*patterns.cpunsigned
patterns.number=patterns.float+patterns.integer
patterns.cnumber=patterns.cfloat+patterns.integer
patterns.cpnumber=patterns.cpfloat+patterns.integer
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
local p_false=P(false)
local p_true=P(true)
local function make(t)
  local function making(t)
    local p=p_false
    local keys=sortedkeys(t)
    for i=1,#keys do
      local k=keys[i]
      if k~="" then
        local v=t[k]
        if v==true then
          p=p+P(k)*p_true
        elseif v==false then
        else
          p=p+P(k)*making(v)
        end
      end
    end
    if t[""] then
      p=p+p_true
    end
    return p
  end
  local p=p_false
  local keys=sortedkeys(t)
  for i=1,#keys do
    local k=keys[i]
    if k~="" then
      local v=t[k]
      if v==true then
        p=p+P(k)*p_true
      elseif v==false then
      else
        p=p+P(k)*making(v)
      end
    end
  end
  return p
end
local function collapse(t,x)
  if type(t)~="table" then
    return t,x
  else
    local n=next(t)
    if n==nil then
      return t,x
    elseif next(t,n)==nil then
      local k=n
      local v=t[k]
      if type(v)=="table" then
        return collapse(v,x..k)
      else
        return v,x..k
      end
    else
      local tt={}
      for k,v in next,t do
        local vv,kk=collapse(v,k)
        tt[kk]=vv
      end
      return tt,x
    end
  end
end
function lpeg.utfchartabletopattern(list) 
  local tree={}
  local n=#list
  if n==0 then
    for s in next,list do
      local t=tree
      local p,pk
      for c in gmatch(s,".") do
        if t==true then
          t={ [c]=true,[""]=true }
          p[pk]=t
          p=t
          t=false
        elseif t==false then
          t={ [c]=false }
          p[pk]=t
          p=t
          t=false
        else
          local tc=t[c]
          if not tc then
            tc=false
            t[c]=false
          end
          p=t
          t=tc
        end
        pk=c
      end
      if t==false then
        p[pk]=true
      elseif t==true then
      else
        t[""]=true
      end
    end
  else
    for i=1,n do
      local s=list[i]
      local t=tree
      local p,pk
      for c in gmatch(s,".") do
        if t==true then
          t={ [c]=true,[""]=true }
          p[pk]=t
          p=t
          t=false
        elseif t==false then
          t={ [c]=false }
          p[pk]=t
          p=t
          t=false
        else
          local tc=t[c]
          if not tc then
            tc=false
            t[c]=false
          end
          p=t
          t=tc
        end
        pk=c
      end
      if t==false then
        p[pk]=true
      elseif t==true then
      else
        t[""]=true
      end
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
local byte_to_HEX={}
local byte_to_hex={}
local byte_to_dec={} 
local hex_to_byte={}
for i=0,255 do
  local H=format("%02X",i)
  local h=format("%02x",i)
  local d=format("%03i",i)
  local c=char(i)
  byte_to_HEX[c]=H
  byte_to_hex[c]=h
  byte_to_dec[c]=d
  hex_to_byte[h]=c
  hex_to_byte[H]=c
end
local hextobyte=P(2)/hex_to_byte
local bytetoHEX=P(1)/byte_to_HEX
local bytetohex=P(1)/byte_to_hex
local bytetodec=P(1)/byte_to_dec
local hextobytes=Cs(hextobyte^0)
local bytestoHEX=Cs(bytetoHEX^0)
local bytestohex=Cs(bytetohex^0)
local bytestodec=Cs(bytetodec^0)
patterns.hextobyte=hextobyte
patterns.bytetoHEX=bytetoHEX
patterns.bytetohex=bytetohex
patterns.bytetodec=bytetodec
patterns.hextobytes=hextobytes
patterns.bytestoHEX=bytestoHEX
patterns.bytestohex=bytestohex
patterns.bytestodec=bytestodec
function string.toHEX(s)
  if not s or s=="" then
    return s
  else
    return lpegmatch(bytestoHEX,s)
  end
end
function string.tohex(s)
  if not s or s=="" then
    return s
  else
    return lpegmatch(bytestohex,s)
  end
end
function string.todec(s)
  if not s or s=="" then
    return s
  else
    return lpegmatch(bytestodec,s)
  end
end
function string.tobytes(s)
  if not s or s=="" then
    return s
  else
    return lpegmatch(hextobytes,s)
  end
end

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
local pattern_c=Ct(C(1)^0) 
local pattern_b=Ct((C(1)/byte)^0)
function string.totable(str,bytes)
  return lpegmatch(bytes and pattern_b or pattern_c,str)
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
    for key in next,t do
      k=k+1
      keys[k]=key
    end
    return keys
  else
    return {}
  end
end
local function compare(a,b)
  local ta=type(a) 
  if ta=="number" then
    local tb=type(b) 
    if ta==tb then
      return a<b
    elseif tb=="string" then
      return tostring(a)<b
    end
  elseif ta=="string" then
    local tb=type(b) 
    if ta==tb then
      return a<b
    else
      return a<tostring(b)
    end
  end
  return tostring(a)<tostring(b) 
end
local function sortedkeys(tab)
  if tab then
    local srt,category,s={},0,0 
    for key in next,tab do
      s=s+1
      srt[s]=key
      if category==3 then
      elseif category==1 then
        if type(key)~="string" then
          category=3
        end
      elseif category==2 then
        if type(key)~="number" then
          category=3
        end
      else
        local tkey=type(key)
        if tkey=="string" then
          category=1
        elseif tkey=="number" then
          category=2
        else
          category=3
        end
      end
    end
    if s<2 then
    elseif category==3 then
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
    for key in next,tab do
      if type(key)=="string" then
        s=s+1
        srt[s]=key
      end
    end
    if s>1 then
      sort(srt)
    end
    return srt
  else
    return {}
  end
end
local function sortedindexonly(tab)
  if tab then
    local srt,s={},0
    for key in next,tab do
      if type(key)=="number" then
        s=s+1
        srt[s]=key
      end
    end
    if s>1 then
      sort(srt)
    end
    return srt
  else
    return {}
  end
end
local function sortedhashkeys(tab,cmp) 
  if tab then
    local srt,s={},0
    for key in next,tab do
      if key then
        s=s+1
        srt[s]=key
      end
    end
    if s>1 then
      sort(srt,cmp)
    end
    return srt
  else
    return {}
  end
end
function table.allkeys(t)
  local keys={}
  for k,v in next,t do
    for k in next,v do
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
    local m=#s
    if m==1 then
      return next,t
    elseif m>0 then
      local n=0
      return function()
        if n<m then
          n=n+1
          local k=s[n]
          return k,t[k]
        end
      end
    end
  end
  return nothing
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
local noquotes,hexify,handle,compact,inline,functions
local reserved=table.tohash { 
  'and','break','do','else','elseif','end','false','for','function','if',
  'in','local','nil','not','or','repeat','return','then','true','until','while',
  'NaN','goto',
}
local function simple_table(t)
  local nt=#t
  if nt>0 then
    local n=0
    for _,v in next,t do
      n=n+1
    end
    if n==nt then
      local tt={}
      for i=1,nt do
        local v=t[i]
        local tv=type(v)
        if tv=="number" then
          if hexify then
            tt[i]=format("0x%X",v)
          else
            tt[i]=tostring(v) 
          end
        elseif tv=="string" then
          tt[i]=format("%q",v)
        elseif tv=="boolean" then
          tt[i]=v and "true" or "false"
        else
          return nil
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
          handle(format("%s[0x%X]={",depth,name))
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
  if root and next(root)~=nil then
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
      local tv=type(v)
      local tk=type(k)
      if compact and first and tk=="number" and k>=first and k<=last then
        if tv=="number" then
          if hexify then
            handle(format("%s 0x%X,",depth,v))
          else
            handle(format("%s %s,",depth,v)) 
          end
        elseif tv=="string" then
          handle(format("%s %q,",depth,v))
        elseif tv=="table" then
          if next(v)==nil then
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
            handle(format("%s [0x%X]=0x%X,",depth,k,v))
          else
            handle(format("%s [%s]=%s,",depth,k,v)) 
          end
        elseif tk=="boolean" then
          if hexify then
            handle(format("%s [%s]=0x%X,",depth,k and "true" or "false",v))
          else
            handle(format("%s [%s]=%s,",depth,k and "true" or "false",v)) 
          end
        elseif tk~="string" then
        elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
          if hexify then
            handle(format("%s %s=0x%X,",depth,k,v))
          else
            handle(format("%s %s=%s,",depth,k,v)) 
          end
        else
          if hexify then
            handle(format("%s [%q]=0x%X,",depth,k,v))
          else
            handle(format("%s [%q]=%s,",depth,k,v)) 
          end
        end
      elseif tv=="string" then
        if tk=="number" then
          if hexify then
            handle(format("%s [0x%X]=%q,",depth,k,v))
          else
            handle(format("%s [%s]=%q,",depth,k,v))
          end
        elseif tk=="boolean" then
          handle(format("%s [%s]=%q,",depth,k and "true" or "false",v))
        elseif tk~="string" then
        elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
          handle(format("%s %s=%q,",depth,k,v))
        else
          handle(format("%s [%q]=%q,",depth,k,v))
        end
      elseif tv=="table" then
        if next(v)==nil then
          if tk=="number" then
            if hexify then
              handle(format("%s [0x%X]={},",depth,k))
            else
              handle(format("%s [%s]={},",depth,k))
            end
          elseif tk=="boolean" then
            handle(format("%s [%s]={},",depth,k and "true" or "false"))
          elseif tk~="string" then
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
                handle(format("%s [0x%X]={ %s },",depth,k,concat(st,", ")))
              else
                handle(format("%s [%s]={ %s },",depth,k,concat(st,", ")))
              end
            elseif tk=="boolean" then
              handle(format("%s [%s]={ %s },",depth,k and "true" or "false",concat(st,", ")))
            elseif tk~="string" then
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
            handle(format("%s [0x%X]=%s,",depth,k,v and "true" or "false"))
          else
            handle(format("%s [%s]=%s,",depth,k,v and "true" or "false"))
          end
        elseif tk=="boolean" then
          handle(format("%s [%s]=%s,",depth,tostring(k),v and "true" or "false"))
        elseif tk~="string" then
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
              handle(format("%s [0x%X]=load(%q),",depth,k,f))
            else
              handle(format("%s [%s]=load(%q),",depth,k,f))
            end
          elseif tk=="boolean" then
            handle(format("%s [%s]=load(%q),",depth,k and "true" or "false",f))
          elseif tk~="string" then
          elseif noquotes and not reserved[k] and lpegmatch(propername,k) then
            handle(format("%s %s=load(%q),",depth,k,f))
          else
            handle(format("%s [%q]=load(%q),",depth,k,f))
          end
        end
      else
        if tk=="number" then
          if hexify then
            handle(format("%s [0x%X]=%q,",depth,k,tostring(v)))
          else
            handle(format("%s [%s]=%q,",depth,k,tostring(v)))
          end
        elseif tk=="boolean" then
          handle(format("%s [%s]=%q,",depth,k and "true" or "false",tostring(v)))
        elseif tk~="string" then
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
      handle(format("[0x%X]={",name))
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
    if next(root)~=nil then
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
local function sparse(old,nest,keeptables)
  local new={}
  for k,v in next,old do
    if not (v=="" or v==false) then
      if nest and type(v)=="table" then
        v=sparse(v,nest)
        if keeptables or next(v)~=nil then
          new[k]=v
        end
      else
        new[k]=v
      end
    end
  end
  return new
end
table.sparse=sparse
function table.compact(t)
  return sparse(t,true,true)
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
  setinspector("table",function(v) if type(v)=="table" then serialize(print,v,"table") return true end end)
end
function table.sub(t,i,j)
  return { unpack(t,i,j) }
end
function table.is_empty(t)
  return not t or next(t)==nil
end
function table.has_one_entry(t)
  return t and next(t,next(t))==nil
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
function table.filtered(t,pattern,sort,cmp)
  if t and type(pattern)=="string" then
    if sort then
      local s
      if cmp then
        s=sortedhashkeys(t,function(a,b) return cmp(t,a,b) end)
      else
        s=sortedkeys(t) 
      end
      local n=0
      local m=#s
      local function kv(s)
        while n<m do
          n=n+1
          local k=s[n]
          if find(k,pattern) then
            return k,t[k]
          end
        end
      end
      return kv,s
    else
      local n=next(t)
      local function iterator()
        while n~=nil do
          local k=n
          n=next(t,k)
          if find(k,pattern) then
            return k,t[k]
          end
        end
      end
      return iterator,t
    end
  else
    return nothing
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
local insert,concat=table.insert,table.concat
local match,find,gmatch=string.match,string.find,string.gmatch
local lpegmatch=lpeg.match
local getcurrentdir,attributes=lfs.currentdir,lfs.attributes
local checkedsplit=string.checkedsplit
local P,R,S,C,Cs,Cp,Cc,Ct=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Cs,lpeg.Cp,lpeg.Cc,lpeg.Ct
local tricky=S("/\\")*P(-1)
local attributes=lfs.attributes
if sandbox then
  sandbox.redefine(lfs.isfile,"lfs.isfile")
  sandbox.redefine(lfs.isdir,"lfs.isdir")
end
function lfs.isdir(name)
  if lpegmatch(tricky,name) then
    return attributes(name,"mode")=="directory"
  else
    return attributes(name.."/.","mode")=="directory"
  end
end
function lfs.isfile(name)
  return attributes(name,"mode")=="file"
end
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
function file.join(one,two,three,...)
  if not two then
    return one=="" and one or lpegmatch(reslasher,one)
  end
  if one=="" then
    return lpegmatch(stripper,three and concat({ two,three,... },"/") or two)
  end
  if lpegmatch(isnetwork,one) then
    local one=lpegmatch(reslasher,one)
    local two=lpegmatch(deslasher,three and concat({ two,three,... },"/") or two)
    if lpegmatch(hasroot,two) then
      return one..two
    else
      return one.."/"..two
    end
  elseif lpegmatch(isroot,one) then
    local two=lpegmatch(deslasher,three and concat({ two,three,... },"/") or two)
    if lpegmatch(hasroot,two) then
      return two
    else
      return "/"..two
    end
  else
    return lpegmatch(deslasher,concat({ one,two,three,... },"/"))
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
function string.is_boolean(str,default,strict)
  if type(str)=="string" then
    if str=="true" or str=="yes" or str=="on" or str=="t" or (not strict and str=="1") then
      return true
    elseif str=="false" or str=="no" or str=="off" or str=="f" or (not strict and str=="0") then
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
if not math.ceiling then
  math.ceiling=math.ceil
end
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

if not modules then modules={} end modules ['l-unicode']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
utf=utf or (unicode and unicode.utf8) or {}
utf.characters=utf.characters or string.utfcharacters
utf.values=utf.values   or string.utfvalues
local type=type
local char,byte,format,sub,gmatch=string.char,string.byte,string.format,string.sub,string.gmatch
local concat=table.concat
local P,C,R,Cs,Ct,Cmt,Cc,Carg,Cp=lpeg.P,lpeg.C,lpeg.R,lpeg.Cs,lpeg.Ct,lpeg.Cmt,lpeg.Cc,lpeg.Carg,lpeg.Cp
local lpegmatch=lpeg.match
local patterns=lpeg.patterns
local tabletopattern=lpeg.utfchartabletopattern
local bytepairs=string.bytepairs
local finder=lpeg.finder
local replacer=lpeg.replacer
local utfvalues=utf.values
local utfgmatch=utf.gmatch 
local p_utftype=patterns.utftype
local p_utfstricttype=patterns.utfstricttype
local p_utfoffset=patterns.utfoffset
local p_utf8char=patterns.utf8character
local p_utf8byte=patterns.utf8byte
local p_utfbom=patterns.utfbom
local p_newline=patterns.newline
local p_whitespace=patterns.whitespace
if not unicode then
  unicode={ utf=utf } 
end
if not utf.char then
  local floor,char=math.floor,string.char
  function utf.char(n)
    if n<0x80 then
      return char(n)
    elseif n<0x800 then
      return char(
        0xC0+floor(n/0x40),
        0x80+(n%0x40)
      )
    elseif n<0x10000 then
      return char(
        0xE0+floor(n/0x1000),
        0x80+(floor(n/0x40)%0x40),
        0x80+(n%0x40)
      )
    elseif n<0x200000 then
      return char(
        0xF0+floor(n/0x40000),
        0x80+(floor(n/0x1000)%0x40),
        0x80+(floor(n/0x40)%0x40),
        0x80+(n%0x40)
      )
    else
      return ""
    end
  end
end
if not utf.byte then
  local utf8byte=patterns.utf8byte
  function utf.byte(c)
    return lpegmatch(utf8byte,c)
  end
end
local utfchar,utfbyte=utf.char,utf.byte
function utf.filetype(data)
  return data and lpegmatch(p_utftype,data) or "unknown"
end
local toentities=Cs (
  (
    patterns.utf8one+(
        patterns.utf8two+patterns.utf8three+patterns.utf8four
      )/function(s) local b=utfbyte(s) if b<127 then return s else return format("&#%X;",b) end end
  )^0
)
patterns.toentities=toentities
function utf.toentities(str)
  return lpegmatch(toentities,str)
end
local one=P(1)
local two=C(1)*C(1)
local four=C(R(utfchar(0xD8),utfchar(0xFF)))*C(1)*C(1)*C(1)
local pattern=P("\254\255")*Cs((
          four/function(a,b,c,d)
                local ab=0xFF*byte(a)+byte(b)
                local cd=0xFF*byte(c)+byte(d)
                return utfchar((ab-0xD800)*0x400+(cd-0xDC00)+0x10000)
              end+two/function(a,b)
                return utfchar(byte(a)*256+byte(b))
              end+one
        )^1 )+P("\255\254")*Cs((
          four/function(b,a,d,c)
                local ab=0xFF*byte(a)+byte(b)
                local cd=0xFF*byte(c)+byte(d)
                return utfchar((ab-0xD800)*0x400+(cd-0xDC00)+0x10000)
              end+two/function(b,a)
                return utfchar(byte(a)*256+byte(b))
              end+one
        )^1 )
function string.toutf(s) 
  return lpegmatch(pattern,s) or s 
end
local validatedutf=Cs (
  (
    patterns.utf8one+patterns.utf8two+patterns.utf8three+patterns.utf8four+P(1)/"�"
  )^0
)
patterns.validatedutf=validatedutf
function utf.is_valid(str)
  return type(str)=="string" and lpegmatch(validatedutf,str) or false
end
if not utf.len then
  local n,f=0,1
  local utfcharcounter=patterns.utfbom^-1*Cmt (
    Cc(1)*patterns.utf8one^1+Cc(2)*patterns.utf8two^1+Cc(3)*patterns.utf8three^1+Cc(4)*patterns.utf8four^1,
    function(_,t,d) 
      n=n+(t-f)/d
      f=t
      return true
    end
  )^0
  function utf.len(str)
    n,f=0,1
    lpegmatch(utfcharcounter,str or "")
    return n
  end
end
utf.length=utf.len
if not utf.sub then
  local utflength=utf.length
  local b,e,n,first,last=0,0,0,0,0
  local function slide_zero(s,p)
    n=n+1
    if n>=last then
      e=p-1
    else
      return p
    end
  end
  local function slide_one(s,p)
    n=n+1
    if n==first then
      b=p
    end
    if n>=last then
      e=p-1
    else
      return p
    end
  end
  local function slide_two(s,p)
    n=n+1
    if n==first then
      b=p
    else
      return true
    end
  end
  local pattern_zero=Cmt(p_utf8char,slide_zero)^0
  local pattern_one=Cmt(p_utf8char,slide_one )^0
  local pattern_two=Cmt(p_utf8char,slide_two )^0
  local pattern_first=C(patterns.utf8character)
  function utf.sub(str,start,stop)
    if not start then
      return str
    end
    if start==0 then
      start=1
    end
    if not stop then
      if start<0 then
        local l=utflength(str) 
        start=l+start
      else
        start=start-1
      end
      b,n,first=0,0,start
      lpegmatch(pattern_two,str)
      if n>=first then
        return sub(str,b)
      else
        return ""
      end
    end
    if start<0 or stop<0 then
      local l=utf.length(str)
      if start<0 then
        start=l+start
        if start<=0 then
          start=1
        else
          start=start+1
        end
      end
      if stop<0 then
        stop=l+stop
        if stop==0 then
          stop=1
        else
          stop=stop+1
        end
      end
    end
    if start==1 and stop==1 then
      return lpegmatch(pattern_first,str) or ""
    elseif start>stop then
      return ""
    elseif start>1 then
      b,e,n,first,last=0,0,0,start-1,stop
      lpegmatch(pattern_one,str)
      if n>=first and e==0 then
        e=#str
      end
      return sub(str,b,e)
    else
      b,e,n,last=1,0,0,stop
      lpegmatch(pattern_zero,str)
      if e==0 then
        e=#str
      end
      return sub(str,b,e)
    end
  end
end
function utf.remapper(mapping,option,action) 
  local variant=type(mapping)
  if variant=="table" then
    action=action or mapping
    if option=="dynamic" then
      local pattern=false
      table.setmetatablenewindex(mapping,function(t,k,v) rawset(t,k,v) pattern=false end)
      return function(str)
        if not str or str=="" then
          return ""
        else
          if not pattern then
            pattern=Cs((tabletopattern(mapping)/action+p_utf8char)^0)
          end
          return lpegmatch(pattern,str)
        end
      end
    elseif option=="pattern" then
      return Cs((tabletopattern(mapping)/action+p_utf8char)^0)
    else
      local pattern=Cs((tabletopattern(mapping)/action+p_utf8char)^0)
      return function(str)
        if not str or str=="" then
          return ""
        else
          return lpegmatch(pattern,str)
        end
      end,pattern
    end
  elseif variant=="function" then
    if option=="pattern" then
      return Cs((p_utf8char/mapping+p_utf8char)^0)
    else
      local pattern=Cs((p_utf8char/mapping+p_utf8char)^0)
      return function(str)
        if not str or str=="" then
          return ""
        else
          return lpegmatch(pattern,str)
        end
      end,pattern
    end
  else
    return function(str)
      return str or ""
    end
  end
end
function utf.replacer(t) 
  local r=replacer(t,false,false,true)
  return function(str)
    return lpegmatch(r,str)
  end
end
function utf.subtituter(t) 
  local f=finder (t)
  local r=replacer(t,false,false,true)
  return function(str)
    local i=lpegmatch(f,str)
    if not i then
      return str
    elseif i>#str then
      return str
    else
      return lpegmatch(r,str)
    end
  end
end
local utflinesplitter=p_utfbom^-1*lpeg.tsplitat(p_newline)
local utfcharsplitter_ows=p_utfbom^-1*Ct(C(p_utf8char)^0)
local utfcharsplitter_iws=p_utfbom^-1*Ct((p_whitespace^1+C(p_utf8char))^0)
local utfcharsplitter_raw=Ct(C(p_utf8char)^0)
patterns.utflinesplitter=utflinesplitter
function utf.splitlines(str)
  return lpegmatch(utflinesplitter,str or "")
end
function utf.split(str,ignorewhitespace) 
  if ignorewhitespace then
    return lpegmatch(utfcharsplitter_iws,str or "")
  else
    return lpegmatch(utfcharsplitter_ows,str or "")
  end
end
function utf.totable(str) 
  return lpegmatch(utfcharsplitter_raw,str)
end
function utf.magic(f) 
  local str=f:read(4) or ""
  local off=lpegmatch(p_utfoffset,str)
  if off<4 then
    f:seek('set',off)
  end
  return lpegmatch(p_utftype,str)
end
local utf16_to_utf8_be,utf16_to_utf8_le
local utf32_to_utf8_be,utf32_to_utf8_le
local utf_16_be_getbom=patterns.utfbom_16_be^-1
local utf_16_le_getbom=patterns.utfbom_16_le^-1
local utf_32_be_getbom=patterns.utfbom_32_be^-1
local utf_32_le_getbom=patterns.utfbom_32_le^-1
local utf_16_be_linesplitter=utf_16_be_getbom*lpeg.tsplitat(patterns.utf_16_be_nl)
local utf_16_le_linesplitter=utf_16_le_getbom*lpeg.tsplitat(patterns.utf_16_le_nl)
local utf_32_be_linesplitter=utf_32_be_getbom*lpeg.tsplitat(patterns.utf_32_be_nl)
local utf_32_le_linesplitter=utf_32_le_getbom*lpeg.tsplitat(patterns.utf_32_le_nl)
local more=0
local p_utf16_to_utf8_be=C(1)*C(1)/function(left,right)
  local now=256*byte(left)+byte(right)
  if more>0 then
    now=(more-0xD800)*0x400+(now-0xDC00)+0x10000 
    more=0
    return utfchar(now)
  elseif now>=0xD800 and now<=0xDBFF then
    more=now
    return "" 
  else
    return utfchar(now)
  end
end
local p_utf16_to_utf8_le=C(1)*C(1)/function(right,left)
  local now=256*byte(left)+byte(right)
  if more>0 then
    now=(more-0xD800)*0x400+(now-0xDC00)+0x10000 
    more=0
    return utfchar(now)
  elseif now>=0xD800 and now<=0xDBFF then
    more=now
    return "" 
  else
    return utfchar(now)
  end
end
local p_utf32_to_utf8_be=C(1)*C(1)*C(1)*C(1)/function(a,b,c,d)
  return utfchar(256*256*256*byte(a)+256*256*byte(b)+256*byte(c)+byte(d))
end
local p_utf32_to_utf8_le=C(1)*C(1)*C(1)*C(1)/function(a,b,c,d)
  return utfchar(256*256*256*byte(d)+256*256*byte(c)+256*byte(b)+byte(a))
end
p_utf16_to_utf8_be=P(true)/function() more=0 end*utf_16_be_getbom*Cs(p_utf16_to_utf8_be^0)
p_utf16_to_utf8_le=P(true)/function() more=0 end*utf_16_le_getbom*Cs(p_utf16_to_utf8_le^0)
p_utf32_to_utf8_be=P(true)/function() more=0 end*utf_32_be_getbom*Cs(p_utf32_to_utf8_be^0)
p_utf32_to_utf8_le=P(true)/function() more=0 end*utf_32_le_getbom*Cs(p_utf32_to_utf8_le^0)
patterns.utf16_to_utf8_be=p_utf16_to_utf8_be
patterns.utf16_to_utf8_le=p_utf16_to_utf8_le
patterns.utf32_to_utf8_be=p_utf32_to_utf8_be
patterns.utf32_to_utf8_le=p_utf32_to_utf8_le
utf16_to_utf8_be=function(s)
  if s and s~="" then
    return lpegmatch(p_utf16_to_utf8_be,s)
  else
    return s
  end
end
local utf16_to_utf8_be_t=function(t)
  if not t then
    return nil
  elseif type(t)=="string" then
    t=lpegmatch(utf_16_be_linesplitter,t)
  end
  for i=1,#t do
    local s=t[i]
    if s~="" then
      t[i]=lpegmatch(p_utf16_to_utf8_be,s)
    end
  end
  return t
end
utf16_to_utf8_le=function(s)
  if s and s~="" then
    return lpegmatch(p_utf16_to_utf8_le,s)
  else
    return s
  end
end
local utf16_to_utf8_le_t=function(t)
  if not t then
    return nil
  elseif type(t)=="string" then
    t=lpegmatch(utf_16_le_linesplitter,t)
  end
  for i=1,#t do
    local s=t[i]
    if s~="" then
      t[i]=lpegmatch(p_utf16_to_utf8_le,s)
    end
  end
  return t
end
utf32_to_utf8_be=function(s)
  if s and s~="" then
    return lpegmatch(p_utf32_to_utf8_be,s)
  else
    return s
  end
end
local utf32_to_utf8_be_t=function(t)
  if not t then
    return nil
  elseif type(t)=="string" then
    t=lpegmatch(utf_32_be_linesplitter,t)
  end
  for i=1,#t do
    local s=t[i]
    if s~="" then
      t[i]=lpegmatch(p_utf32_to_utf8_be,s)
    end
  end
  return t
end
utf32_to_utf8_le=function(s)
  if s and s~="" then
    return lpegmatch(p_utf32_to_utf8_le,s)
  else
    return s
  end
end
local utf32_to_utf8_le_t=function(t)
  if not t then
    return nil
  elseif type(t)=="string" then
    t=lpegmatch(utf_32_le_linesplitter,t)
  end
  for i=1,#t do
    local s=t[i]
    if s~="" then
      t[i]=lpegmatch(p_utf32_to_utf8_le,s)
    end
  end
  return t
end
utf.utf16_to_utf8_le_t=utf16_to_utf8_le_t
utf.utf16_to_utf8_be_t=utf16_to_utf8_be_t
utf.utf32_to_utf8_le_t=utf32_to_utf8_le_t
utf.utf32_to_utf8_be_t=utf32_to_utf8_be_t
utf.utf16_to_utf8_le=utf16_to_utf8_le
utf.utf16_to_utf8_be=utf16_to_utf8_be
utf.utf32_to_utf8_le=utf32_to_utf8_le
utf.utf32_to_utf8_be=utf32_to_utf8_be
function utf.utf8_to_utf8_t(t)
  return type(t)=="string" and lpegmatch(utflinesplitter,t) or t
end
function utf.utf16_to_utf8_t(t,endian)
  return endian and utf16_to_utf8_be_t(t) or utf16_to_utf8_le_t(t) or t
end
function utf.utf32_to_utf8_t(t,endian)
  return endian and utf32_to_utf8_be_t(t) or utf32_to_utf8_le_t(t) or t
end
local function little(b)
  if b<0x10000 then
    return char(b%256,b/256)
  else
    b=b-0x10000
    local b1,b2=b/1024+0xD800,b%1024+0xDC00
    return char(b1%256,b1/256,b2%256,b2/256)
  end
end
local function big(b)
  if b<0x10000 then
    return char(b/256,b%256)
  else
    b=b-0x10000
    local b1,b2=b/1024+0xD800,b%1024+0xDC00
    return char(b1/256,b1%256,b2/256,b2%256)
  end
end
local l_remap=Cs((p_utf8byte/little+P(1)/"")^0)
local b_remap=Cs((p_utf8byte/big+P(1)/"")^0)
local function utf8_to_utf16_be(str,nobom)
  if nobom then
    return lpegmatch(b_remap,str)
  else
    return char(254,255)..lpegmatch(b_remap,str)
  end
end
local function utf8_to_utf16_le(str,nobom)
  if nobom then
    return lpegmatch(l_remap,str)
  else
    return char(255,254)..lpegmatch(l_remap,str)
  end
end
utf.utf8_to_utf16_be=utf8_to_utf16_be
utf.utf8_to_utf16_le=utf8_to_utf16_le
function utf.utf8_to_utf16(str,littleendian,nobom)
  if littleendian then
    return utf8_to_utf16_le(str,nobom)
  else
    return utf8_to_utf16_be(str,nobom)
  end
end
local pattern=Cs (
  (p_utf8byte/function(unicode     ) return format("0x%04X",unicode) end)*(p_utf8byte*Carg(1)/function(unicode,separator) return format("%s0x%04X",separator,unicode) end)^0
)
function utf.tocodes(str,separator)
  return lpegmatch(pattern,str,1,separator or " ")
end
function utf.ustring(s)
  return format("U+%05X",type(s)=="number" and s or utfbyte(s))
end
function utf.xstring(s)
  return format("0x%05X",type(s)=="number" and s or utfbyte(s))
end
function utf.toeight(str)
  if not str or str=="" then
    return nil
  end
  local utftype=lpegmatch(p_utfstricttype,str)
  if utftype=="utf-8" then
    return sub(str,4)        
  elseif utftype=="utf-16-be" then
    return utf16_to_utf8_be(str)  
  elseif utftype=="utf-16-le" then
    return utf16_to_utf8_le(str)  
  else
    return str
  end
end
local p_nany=p_utf8char/""
if utfgmatch then
  function utf.count(str,what)
    if type(what)=="string" then
      local n=0
      for _ in utfgmatch(str,what) do
        n=n+1
      end
      return n
    else 
      return #lpegmatch(Cs((P(what)/" "+p_nany)^0),str)
    end
  end
else
  local cache={}
  function utf.count(str,what)
    if type(what)=="string" then
      local p=cache[what]
      if not p then
        p=Cs((P(what)/" "+p_nany)^0)
        cache[p]=p
      end
      return #lpegmatch(p,str)
    else 
      return #lpegmatch(Cs((P(what)/" "+p_nany)^0),str)
    end
  end
end
if not utf.characters then
  function utf.characters(str)
    return gmatch(str,".[\128-\191]*")
  end
  string.utfcharacters=utf.characters
end
if not utf.values then
  local find=string.find
  local dummy=function()
  end
  function utf.values(str)
    local n=#str
    if n==0 then
      return dummy
    elseif n==1 then
      return function() return utfbyte(str) end
    else
      local p=1
      return function()
          local b,e=find(str,".[\128-\191]*",p)
          if b then
            p=e+1
            return utfbyte(sub(str,b,e))
          end
      end
    end
  end
  string.utfvalues=utf.values
end
function utf.chrlen(u) 
  return
    (u<0x80 and 1) or
    (u<0xE0 and 2) or
    (u<0xF0 and 3) or
    (u<0xF8 and 4) or
    (u<0xFC and 5) or
    (u<0xFE and 6) or 0
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
local newline=patterns.newline
local endofstring=patterns.endofstring
local whitespace=patterns.whitespace
local spacer=patterns.spacer
local spaceortab=patterns.spaceortab
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
local rubish=spaceortab^0*newline
local anyrubish=spaceortab+newline
local anything=patterns.anything
local stripped=(spaceortab^1/"")*newline
local leading=rubish^0/""
local trailing=(anyrubish^1*endofstring)/""
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
   end+newline*Cp()/function(position)
     extra,start=0,position
   end+patterns.anything
 )^1)
function strings.tabtospace(str,tab)
  return lpegmatch(pattern,str,1,tab or 7)
end
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
  ["collapse"]=patterns.collapser,
}
setmetatable(striplinepatterns,{ __index=function(t,k) return p_prune_collapse end })
strings.striplinepatterns=striplinepatterns
function strings.striplines(str,how)
  return str and lpegmatch(striplinepatterns[how],str) or str
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
local tracedchars={ [0]=
  "[null]","[soh]","[stx]","[etx]","[eot]","[enq]","[ack]","[bel]",
  "[bs]","[ht]","[lf]","[vt]","[ff]","[cr]","[so]","[si]",
  "[dle]","[dc1]","[dc2]","[dc3]","[dc4]","[nak]","[syn]","[etb]",
  "[can]","[em]","[sub]","[esc]","[fs]","[gs]","[rs]","[us]",
  "[space]",
}
string.tracedchars=tracedchars
strings.tracers=tracedchars
function string.tracedchar(b)
  if type(b)=="number" then
    return tracedchars[b] or (utfchar(b).." (U+"..format("%05X",b)..")")
  else
    local c=utfbyte(b)
    return tracedchars[c] or (b.." (U+"..(c and format("%05X",c) or "?????")..")")
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
local format_F=function(f) 
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
  ["?"]=Cs(((1-P("%"))^1        )^1)/format_rest,
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
local dquote=patterns.dquote 
local equote=patterns.escaped+dquote/'\\"'+1
local space=patterns.space
local cquote=Cc('"')
local pattern=Cs(dquote*(equote-P(-2))^0*dquote)          
+Cs(cquote*(equote-space)^0*space*equote^0*cquote) 
function string.optionalquoted(str)
  return lpegmatch(pattern,str) or str
end
local pattern=Cs((newline/(os.newline or "\r")+1)^0)
function string.replacenewlines(str)
  return lpegmatch(pattern,str)
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['util-fil']={
  version=1.001,
  comment="companion to luat-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local byte=string.byte
local char=string.char
local extract=bit32.extract
local floor=math.floor
utilities=utilities or {}
local files={}
utilities.files=files
local zerobased={}
function files.open(filename,zb)
  local f=io.open(filename,"rb")
  if f then
    zerobased[f]=zb or false
  end
  return f
end
function files.close(f)
  zerobased[f]=nil
  f:close()
end
function files.size(f)
  return f:seek("end")
end
files.getsize=files.size
function files.setposition(f,n)
  if zerobased[f] then
    f:seek("set",n)
  else
    f:seek("set",n-1)
  end
end
function files.getposition(f)
  if zerobased[f] then
    return f:seek()
  else
    return f:seek()+1
  end
end
function files.look(f,n,chars)
  local p=f:seek()
  local s=f:read(n)
  f:seek("set",p)
  if chars then
    return s
  else
    return byte(s,1,#s)
  end
end
function files.skip(f,n)
  if n==1 then
    f:read(n)
  else
    f:seek("set",f:seek()+n)
  end
end
function files.readbyte(f)
  return byte(f:read(1))
end
function files.readbytes(f,n)
  return byte(f:read(n),1,n)
end
function files.readchar(f)
  return f:read(1)
end
function files.readstring(f,n)
  return f:read(n or 1)
end
function files.readinteger1(f) 
  local n=byte(f:read(1))
  if n>=0x80 then
    return n-0x100
  else
    return n
  end
end
files.readcardinal1=files.readbyte 
files.readcardinal=files.readcardinal1
files.readinteger=files.readinteger1
function files.readcardinal2(f)
  local a,b=byte(f:read(2),1,2)
  return 0x100*a+b
end
function files.readinteger2(f)
  local a,b=byte(f:read(2),1,2)
  local n=0x100*a+b
  if n>=0x8000 then
    return n-0x10000
  else
    return n
  end
end
function files.readcardinal3(f)
  local a,b,c=byte(f:read(3),1,3)
  return 0x10000*a+0x100*b+c
end
function files.readinteger3(f)
  local a,b,c=byte(f:read(3),1,3)
  local n=0x10000*a+0x100*b+c
  if n>=0x80000 then
    return n-0x1000000
  else
    return n
  end
end
function files.readcardinal4(f)
  local a,b,c,d=byte(f:read(4),1,4)
  return 0x1000000*a+0x10000*b+0x100*c+d
end
function files.readinteger4(f)
  local a,b,c,d=byte(f:read(4),1,4)
  local n=0x1000000*a+0x10000*b+0x100*c+d
  if n>=0x8000000 then
    return n-0x100000000
  else
    return n
  end
end
function files.readfixed4(f)
  local a,b,c,d=byte(f:read(4),1,4)
  local n=0x100*a+b
  if n>=0x8000 then
    return n-0x10000+(0x100*c+d)/0xFFFF
  else
    return n+(0x100*c+d)/0xFFFF
  end
end
function files.read2dot14(f)
  local a,b=byte(f:read(2),1,2)
  local n=0x100*a+b
  local m=extract(n,0,30)
  if n>0x7FFF then
    n=extract(n,30,2)
    return m/0x4000-4
  else
    n=extract(n,30,2)
    return n+m/0x4000
  end
end
function files.skipshort(f,n)
  f:read(2*(n or 1))
end
function files.skiplong(f,n)
  f:read(4*(n or 1))
end
function files.writecardinal2(f,n)
  local a=char(n%256)
  n=floor(n/256)
  local b=char(n%256)
  f:write(b,a)
end
function files.writecardinal4(f,n)
  local a=char(n%256)
  n=floor(n/256)
  local b=char(n%256)
  n=floor(n/256)
  local c=char(n%256)
  n=floor(n/256)
  local d=char(n%256)
  f:write(d,c,b,a)
end
function files.writestring(f,s)
  f:write(char(byte(s,1,#s)))
end
function files.writebyte(f,b)
  f:write(char(b))
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
  return function(f,...)
    local r=texio.reporter or texio.write_nl
    if f then
      r(c.." : "..string.formatters(f,...))
    else
      r("")
    end
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
  register=function(n,f)
    return callback.register(n,f)
  end,
}
utilities=utilities or {} utilities.storage={
  allocate=function(t)
    return t or {}
  end,
  mark=function(t)
    return t or {}
  end,
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
  cid="cid maps",
  cidmap="cid maps",
  pfb="type1 fonts",
  afm="afm",
  enc="enc files",
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
  if type(t)~="table" then
    f,t=t,{}
  end
  local m=getmetatable(t)
  if f=="table" then
    f=function(t,k) local v={} t[k]=v return v end
  end
  if m then
    m.__index=f
  else
    setmetatable(t,{ __index=f })
  end
  return t
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
local nodecodes={}
local glyphcodes=node.subtypes("glyph")
local disccodes=node.subtypes("disc")
for k,v in next,node.types() do
  v=string.gsub(v,"_","")
  nodecodes[k]=v
  nodecodes[v]=k
end
for i=0,#glyphcodes do
  glyphcodes[glyphcodes[i]]=i
end
for i=0,#disccodes do
  disccodes[disccodes[i]]=i
end
nodes.nodecodes=nodecodes
nodes.glyphcodes=glyphcodes
nodes.disccodes=disccodes
local flush_node=node.flush_node
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
      flush_node(t)
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
local getfield=node.getfield
local setfield=node.setfield
nodes.getfield=getfield
nodes.setfield=setfield
nodes.getattr=getfield
nodes.setattr=setfield
nodes.tostring=node.tostring or tostring
nodes.copy=node.copy
nodes.copy_node=node.copy
nodes.copy_list=node.copy_list
nodes.delete=node.delete
nodes.dimensions=node.dimensions
nodes.end_of_math=node.end_of_math
nodes.flush_list=node.flush_list
nodes.flush_node=node.flush_node
nodes.flush=node.flush_node
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
nodes.has_glyph=node.has_glyph or node.first_glyph
nodes.current_attr=node.current_attr
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
nodes.mlist_to_hlist=node.mlist_to_hlist
local direct=node.direct
local nuts={}
nodes.nuts=nuts
local tonode=direct.tonode
local tonut=direct.todirect
nodes.tonode=tonode
nodes.tonut=tonut
nuts.tonode=tonode
nuts.tonut=tonut
local getfield=direct.getfield
local setfield=direct.setfield
nuts.getfield=getfield
nuts.setfield=setfield
nuts.getnext=direct.getnext
nuts.setnext=direct.setnext
nuts.getprev=direct.getprev
nuts.setprev=direct.setprev
nuts.getboth=direct.getboth
nuts.setboth=direct.setboth
nuts.getid=direct.getid
nuts.getattr=direct.get_attribute or direct.has_attribute or getfield
nuts.setattr=setfield
nuts.getfont=direct.getfont
nuts.setfont=direct.setfont
nuts.getsubtype=direct.getsubtype
nuts.setsubtype=direct.setsubtype or function(n,s) setfield(n,"subtype",s) end
nuts.getchar=direct.getchar
nuts.setchar=direct.setchar
nuts.getdisc=direct.getdisc
nuts.setdisc=direct.setdisc
nuts.setlink=direct.setlink
nuts.getlist=direct.getlist
nuts.setlist=direct.setlist  or function(n,l) setfield(n,"list",l) end
nuts.getleader=direct.getleader
nuts.setleader=direct.setleader or function(n,l) setfield(n,"leader",l) end
if not direct.is_glyph then
  local getchar=direct.getchar
  local getid=direct.getid
  local getfont=direct.getfont
  local glyph_code=nodes.nodecodes.glyph
  function direct.is_glyph(n,f)
    local id=getid(n)
    if id==glyph_code then
      if f and getfont(n)==f then
        return getchar(n)
      else
        return false
      end
    else
      return nil,id
    end
  end
  function direct.is_char(n,f)
    local id=getid(n)
    if id==glyph_code then
      if getsubtype(n)>=256 then
        return false
      elseif f and getfont(n)==f then
        return getchar(n)
      else
        return false
      end
    else
      return nil,id
    end
  end
end
nuts.ischar=direct.is_char
nuts.is_char=direct.is_char
nuts.isglyph=direct.is_glyph
nuts.is_glyph=direct.is_glyph
nuts.insert_before=direct.insert_before
nuts.insert_after=direct.insert_after
nuts.delete=direct.delete
nuts.copy=direct.copy
nuts.copy_node=direct.copy
nuts.copy_list=direct.copy_list
nuts.tail=direct.tail
nuts.flush_list=direct.flush_list
nuts.flush_node=direct.flush_node
nuts.flush=direct.flush
nuts.free=direct.free
nuts.remove=direct.remove
nuts.is_node=direct.is_node
nuts.end_of_math=direct.end_of_math
nuts.traverse=direct.traverse
nuts.traverse_id=direct.traverse_id
nuts.traverse_char=direct.traverse_char
nuts.ligaturing=direct.ligaturing
nuts.kerning=direct.kerning
nuts.getprop=nuts.getattr
nuts.setprop=nuts.setattr
local new_nut=direct.new
nuts.new=new_nut
nuts.pool={}
function nuts.pool.kern(k)
  local n=new_nut("kern",1)
  setfield(n,"kern",k)
  return n
end
local propertydata=direct.get_properties_table()
nodes.properties={ data=propertydata }
direct.set_properties_mode(true,true)   
function direct.set_properties_mode() end 
nuts.getprop=function(n,k)
  local p=propertydata[n]
  if p then
    return p[k]
  end
end
nuts.setprop=function(n,k,v)
  if v then
    local p=propertydata[n]
    if p then
      p[k]=v
    else
      propertydata[n]={ [k]=v }
    end
  end
end
nodes.setprop=nodes.setproperty
nodes.getprop=nodes.getproperty

end -- closure

do -- begin closure to overcome local limits and interference


characters=characters or {}
characters.blockrange={}
characters.classifiers={
 [1536]=4,
 [1537]=4,
 [1538]=4,
 [1539]=4,
 [1540]=4,
 [1541]=4,
 [1542]=6,
 [1543]=6,
 [1544]=4,
 [1545]=6,
 [1546]=6,
 [1547]=4,
 [1548]=6,
 [1549]=6,
 [1550]=6,
 [1551]=6,
 [1552]=5,
 [1553]=5,
 [1554]=5,
 [1555]=5,
 [1556]=5,
 [1557]=5,
 [1558]=5,
 [1559]=5,
 [1560]=5,
 [1561]=5,
 [1562]=5,
 [1563]=6,
 [1564]=6,
 [1566]=6,
 [1567]=6,
 [1568]=2,
 [1569]=4,
 [1570]=3,
 [1571]=3,
 [1572]=3,
 [1573]=3,
 [1574]=2,
 [1575]=3,
 [1576]=2,
 [1577]=3,
 [1578]=2,
 [1579]=2,
 [1580]=2,
 [1581]=2,
 [1582]=2,
 [1583]=3,
 [1584]=3,
 [1585]=3,
 [1586]=3,
 [1587]=2,
 [1588]=2,
 [1589]=2,
 [1590]=2,
 [1591]=2,
 [1592]=2,
 [1593]=2,
 [1594]=2,
 [1595]=2,
 [1596]=2,
 [1597]=2,
 [1598]=2,
 [1599]=2,
 [1600]=2,
 [1601]=2,
 [1602]=2,
 [1603]=2,
 [1604]=2,
 [1605]=2,
 [1606]=2,
 [1607]=2,
 [1608]=3,
 [1609]=2,
 [1610]=2,
 [1611]=5,
 [1612]=5,
 [1613]=5,
 [1614]=5,
 [1615]=5,
 [1616]=5,
 [1617]=5,
 [1618]=5,
 [1619]=5,
 [1620]=5,
 [1621]=5,
 [1622]=5,
 [1623]=5,
 [1624]=5,
 [1625]=5,
 [1626]=5,
 [1627]=5,
 [1628]=5,
 [1629]=5,
 [1630]=5,
 [1631]=5,
 [1632]=6,
 [1633]=6,
 [1634]=6,
 [1635]=6,
 [1636]=6,
 [1637]=6,
 [1638]=6,
 [1639]=6,
 [1640]=6,
 [1641]=6,
 [1642]=6,
 [1643]=6,
 [1644]=6,
 [1645]=6,
 [1646]=2,
 [1647]=2,
 [1648]=5,
 [1649]=3,
 [1650]=3,
 [1651]=3,
 [1652]=4,
 [1653]=3,
 [1654]=3,
 [1655]=3,
 [1656]=2,
 [1657]=2,
 [1658]=2,
 [1659]=2,
 [1660]=2,
 [1661]=2,
 [1662]=2,
 [1663]=2,
 [1664]=2,
 [1665]=2,
 [1666]=2,
 [1667]=2,
 [1668]=2,
 [1669]=2,
 [1670]=2,
 [1671]=2,
 [1672]=3,
 [1673]=3,
 [1674]=3,
 [1675]=3,
 [1676]=3,
 [1677]=3,
 [1678]=3,
 [1679]=3,
 [1680]=3,
 [1681]=3,
 [1682]=3,
 [1683]=3,
 [1684]=3,
 [1685]=3,
 [1686]=3,
 [1687]=3,
 [1688]=3,
 [1689]=3,
 [1690]=2,
 [1691]=2,
 [1692]=2,
 [1693]=2,
 [1694]=2,
 [1695]=2,
 [1696]=2,
 [1697]=2,
 [1698]=2,
 [1699]=2,
 [1700]=2,
 [1701]=2,
 [1702]=2,
 [1703]=2,
 [1704]=2,
 [1705]=2,
 [1706]=2,
 [1707]=2,
 [1708]=2,
 [1709]=2,
 [1710]=2,
 [1711]=2,
 [1712]=2,
 [1713]=2,
 [1714]=2,
 [1715]=2,
 [1716]=2,
 [1717]=2,
 [1718]=2,
 [1719]=2,
 [1720]=2,
 [1721]=2,
 [1722]=2,
 [1723]=2,
 [1724]=2,
 [1725]=2,
 [1726]=2,
 [1727]=2,
 [1728]=3,
 [1729]=2,
 [1730]=2,
 [1731]=3,
 [1732]=3,
 [1733]=3,
 [1734]=3,
 [1735]=3,
 [1736]=3,
 [1737]=3,
 [1738]=3,
 [1739]=3,
 [1740]=2,
 [1741]=3,
 [1742]=2,
 [1743]=3,
 [1744]=2,
 [1745]=2,
 [1746]=3,
 [1747]=3,
 [1748]=6,
 [1749]=3,
 [1750]=5,
 [1751]=5,
 [1752]=5,
 [1753]=5,
 [1754]=5,
 [1755]=5,
 [1756]=5,
 [1757]=4,
 [1758]=6,
 [1759]=5,
 [1760]=5,
 [1761]=5,
 [1762]=5,
 [1763]=5,
 [1764]=5,
 [1765]=6,
 [1766]=6,
 [1767]=5,
 [1768]=5,
 [1769]=6,
 [1770]=5,
 [1771]=5,
 [1772]=5,
 [1773]=5,
 [1774]=3,
 [1775]=3,
 [1776]=6,
 [1777]=6,
 [1778]=6,
 [1779]=6,
 [1780]=6,
 [1781]=6,
 [1782]=6,
 [1783]=6,
 [1784]=6,
 [1785]=6,
 [1786]=2,
 [1787]=2,
 [1788]=2,
 [1789]=6,
 [1790]=6,
 [1791]=2,
 [1792]=6,
 [1793]=6,
 [1794]=6,
 [1795]=6,
 [1796]=6,
 [1797]=6,
 [1798]=6,
 [1799]=6,
 [1800]=6,
 [1801]=6,
 [1802]=6,
 [1803]=6,
 [1804]=6,
 [1805]=6,
 [1807]=6,
 [1808]=3,
 [1809]=5,
 [1810]=2,
 [1811]=2,
 [1812]=2,
 [1813]=3,
 [1814]=3,
 [1815]=3,
 [1816]=3,
 [1817]=3,
 [1818]=2,
 [1819]=2,
 [1820]=2,
 [1821]=2,
 [1822]=3,
 [1823]=2,
 [1824]=2,
 [1825]=2,
 [1826]=2,
 [1827]=2,
 [1828]=2,
 [1829]=2,
 [1830]=2,
 [1831]=2,
 [1832]=3,
 [1833]=2,
 [1834]=3,
 [1835]=2,
 [1836]=3,
 [1837]=2,
 [1838]=2,
 [1839]=3,
 [1840]=5,
 [1841]=5,
 [1842]=5,
 [1843]=5,
 [1844]=5,
 [1845]=5,
 [1846]=5,
 [1847]=5,
 [1848]=5,
 [1849]=5,
 [1850]=5,
 [1851]=5,
 [1852]=5,
 [1853]=5,
 [1854]=5,
 [1855]=5,
 [1856]=5,
 [1857]=5,
 [1858]=5,
 [1859]=5,
 [1860]=5,
 [1861]=5,
 [1862]=5,
 [1863]=5,
 [1864]=5,
 [1865]=5,
 [1866]=5,
 [1869]=3,
 [1870]=2,
 [1871]=2,
 [1872]=2,
 [1873]=2,
 [1874]=2,
 [1875]=2,
 [1876]=2,
 [1877]=2,
 [1878]=2,
 [1879]=2,
 [1880]=2,
 [1881]=3,
 [1882]=3,
 [1883]=3,
 [1884]=2,
 [1885]=2,
 [1886]=2,
 [1887]=2,
 [1888]=2,
 [1889]=2,
 [1890]=2,
 [1891]=2,
 [1892]=2,
 [1893]=2,
 [1894]=2,
 [1895]=2,
 [1896]=2,
 [1897]=2,
 [1898]=2,
 [1899]=3,
 [1900]=3,
 [1901]=2,
 [1902]=2,
 [1903]=2,
 [1904]=2,
 [1905]=3,
 [1906]=2,
 [1907]=3,
 [1908]=3,
 [1909]=2,
 [1910]=2,
 [1911]=2,
 [1912]=3,
 [1913]=3,
 [1914]=2,
 [1915]=2,
 [1916]=2,
 [1917]=2,
 [1918]=2,
 [1919]=2,
 [1984]=6,
 [1985]=6,
 [1986]=6,
 [1987]=6,
 [1988]=6,
 [1989]=6,
 [1990]=6,
 [1991]=6,
 [1992]=6,
 [1993]=6,
 [1994]=2,
 [1995]=2,
 [1996]=2,
 [1997]=2,
 [1998]=2,
 [1999]=2,
 [2000]=2,
 [2001]=2,
 [2002]=2,
 [2003]=2,
 [2004]=2,
 [2005]=2,
 [2006]=2,
 [2007]=2,
 [2008]=2,
 [2009]=2,
 [2010]=2,
 [2011]=2,
 [2012]=2,
 [2013]=2,
 [2014]=2,
 [2015]=2,
 [2016]=2,
 [2017]=2,
 [2018]=2,
 [2019]=2,
 [2020]=2,
 [2021]=2,
 [2022]=2,
 [2023]=2,
 [2024]=2,
 [2025]=2,
 [2026]=2,
 [2027]=5,
 [2028]=5,
 [2029]=5,
 [2030]=5,
 [2031]=5,
 [2032]=5,
 [2033]=5,
 [2034]=5,
 [2035]=5,
 [2036]=6,
 [2037]=6,
 [2038]=6,
 [2039]=6,
 [2040]=6,
 [2041]=6,
 [2042]=2,
 [2112]=3,
 [2113]=2,
 [2114]=2,
 [2115]=2,
 [2116]=2,
 [2117]=2,
 [2118]=3,
 [2119]=3,
 [2120]=2,
 [2121]=3,
 [2122]=2,
 [2123]=2,
 [2124]=2,
 [2125]=2,
 [2126]=2,
 [2127]=2,
 [2128]=2,
 [2129]=2,
 [2130]=2,
 [2131]=2,
 [2132]=3,
 [2133]=2,
 [2134]=4,
 [2135]=4,
 [2136]=4,
 [2208]=2,
 [2209]=2,
 [2210]=2,
 [2211]=2,
 [2212]=2,
 [2213]=2,
 [2214]=2,
 [2215]=2,
 [2216]=2,
 [2217]=2,
 [2218]=3,
 [2219]=3,
 [2220]=3,
 [2221]=4,
 [2222]=3,
 [2223]=2,
 [2224]=2,
 [2225]=3,
 [2226]=3,
 [2227]=2,
 [2228]=2,
 [6150]=4,
 [6151]=2,
 [6154]=2,
 [6158]=4,
 [6176]=2,
 [6177]=2,
 [6178]=2,
 [6179]=2,
 [6180]=2,
 [6181]=2,
 [6182]=2,
 [6183]=2,
 [6184]=2,
 [6185]=2,
 [6186]=2,
 [6187]=2,
 [6188]=2,
 [6189]=2,
 [6190]=2,
 [6191]=2,
 [6192]=2,
 [6193]=2,
 [6194]=2,
 [6195]=2,
 [6196]=2,
 [6197]=2,
 [6198]=2,
 [6199]=2,
 [6200]=2,
 [6201]=2,
 [6202]=2,
 [6203]=2,
 [6204]=2,
 [6205]=2,
 [6206]=2,
 [6207]=2,
 [6208]=2,
 [6209]=2,
 [6210]=2,
 [6211]=2,
 [6212]=2,
 [6213]=2,
 [6214]=2,
 [6215]=2,
 [6216]=2,
 [6217]=2,
 [6218]=2,
 [6219]=2,
 [6220]=2,
 [6221]=2,
 [6222]=2,
 [6223]=2,
 [6224]=2,
 [6225]=2,
 [6226]=2,
 [6227]=2,
 [6228]=2,
 [6229]=2,
 [6230]=2,
 [6231]=2,
 [6232]=2,
 [6233]=2,
 [6234]=2,
 [6235]=2,
 [6236]=2,
 [6237]=2,
 [6238]=2,
 [6239]=2,
 [6240]=2,
 [6241]=2,
 [6242]=2,
 [6243]=2,
 [6244]=2,
 [6245]=2,
 [6246]=2,
 [6247]=2,
 [6248]=2,
 [6249]=2,
 [6250]=2,
 [6251]=2,
 [6252]=2,
 [6253]=2,
 [6254]=2,
 [6255]=2,
 [6256]=2,
 [6257]=2,
 [6258]=2,
 [6259]=2,
 [6260]=2,
 [6261]=2,
 [6262]=2,
 [6263]=2,
 [6272]=4,
 [6273]=4,
 [6274]=4,
 [6275]=4,
 [6276]=4,
 [6277]=4,
 [6278]=4,
 [6279]=2,
 [6280]=2,
 [6281]=2,
 [6282]=2,
 [6283]=2,
 [6284]=2,
 [6285]=2,
 [6286]=2,
 [6287]=2,
 [6288]=2,
 [6289]=2,
 [6290]=2,
 [6291]=2,
 [6292]=2,
 [6293]=2,
 [6294]=2,
 [6295]=2,
 [6296]=2,
 [6297]=2,
 [6298]=2,
 [6299]=2,
 [6300]=2,
 [6301]=2,
 [6302]=2,
 [6303]=2,
 [6304]=2,
 [6305]=2,
 [6306]=2,
 [6307]=2,
 [6308]=2,
 [6309]=2,
 [6310]=2,
 [6311]=2,
 [6312]=2,
 [6314]=2,
 [8204]=4,
 [8205]=2,
 [8294]=4,
 [8295]=4,
 [8296]=4,
 [8297]=4,
 [43072]=2,
 [43073]=2,
 [43074]=2,
 [43075]=2,
 [43076]=2,
 [43077]=2,
 [43078]=2,
 [43079]=2,
 [43080]=2,
 [43081]=2,
 [43082]=2,
 [43083]=2,
 [43084]=2,
 [43085]=2,
 [43086]=2,
 [43087]=2,
 [43088]=2,
 [43089]=2,
 [43090]=2,
 [43091]=2,
 [43092]=2,
 [43093]=2,
 [43094]=2,
 [43095]=2,
 [43096]=2,
 [43097]=2,
 [43098]=2,
 [43099]=2,
 [43100]=2,
 [43101]=2,
 [43102]=2,
 [43103]=2,
 [43104]=2,
 [43105]=2,
 [43106]=2,
 [43107]=2,
 [43108]=2,
 [43109]=2,
 [43110]=2,
 [43111]=2,
 [43112]=2,
 [43113]=2,
 [43114]=2,
 [43115]=2,
 [43116]=2,
 [43117]=2,
 [43118]=2,
 [43119]=2,
 [43120]=2,
 [43121]=2,
 [43122]=1,
 [43123]=4,
 [68288]=2,
 [68289]=2,
 [68290]=2,
 [68291]=2,
 [68292]=2,
 [68293]=3,
 [68294]=4,
 [68295]=3,
 [68296]=4,
 [68297]=3,
 [68298]=3,
 [68299]=4,
 [68300]=4,
 [68301]=1,
 [68302]=3,
 [68303]=3,
 [68304]=3,
 [68305]=3,
 [68306]=3,
 [68307]=2,
 [68308]=2,
 [68309]=2,
 [68310]=2,
 [68311]=1,
 [68312]=2,
 [68313]=2,
 [68314]=2,
 [68315]=2,
 [68316]=2,
 [68317]=3,
 [68318]=2,
 [68319]=2,
 [68320]=2,
 [68321]=3,
 [68322]=4,
 [68323]=4,
 [68324]=3,
 [68331]=2,
 [68332]=2,
 [68333]=2,
 [68334]=2,
 [68335]=3,
 [68480]=2,
 [68481]=3,
 [68482]=2,
 [68483]=3,
 [68484]=3,
 [68485]=3,
 [68486]=2,
 [68487]=2,
 [68488]=2,
 [68489]=3,
 [68490]=2,
 [68491]=2,
 [68492]=3,
 [68493]=2,
 [68494]=3,
 [68495]=3,
 [68496]=2,
 [68497]=3,
 [68521]=3,
 [68522]=3,
 [68523]=3,
 [68524]=3,
 [68525]=2,
 [68526]=2,
 [68527]=4,
}

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
local format,match,lower,gsub,find=string.format,string.match,string.lower,string.gsub,string.find
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
constructors.cacheintex=true
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
    local factor=constructors.factor
    if designsize then
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
local function mathkerns(v,vdelta)
  local k={}
  for i=1,#v do
    local entry=v[i]
    local height=entry.height
    local kern=entry.kern
    k[i]={
      height=height and vdelta*height or 0,
      kern=kern  and vdelta*kern  or 0,
    }
  end
  return k
end
local psfake=0
local function fixedpsname(psname,fallback)
  local usedname=psname
  if psname and psname~="" then
    if find(psname," ") then
      usedname=gsub(psname,"[%s]+","-")
    else
    end
  elseif not fallback or fallback=="" then
    psfake=psfake+1
    psname="fakename-"..psfake
  else
    psname=fallback
    usedname=gsub(psname,"[^a-zA-Z0-9]+","-")
  end
  return usedname,psname~=usedname
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
  local tounicode=fonts.mappings.tounicode
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
  target.units=units
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
  target.cache=constructors.cacheintex and "yes" or "renew"
  local fontname=properties.fontname or tfmdata.fontname
  local fullname=properties.fullname or tfmdata.fullname
  local filename=properties.filename or tfmdata.filename
  local psname=properties.psname  or tfmdata.psname
  local name=properties.name   or tfmdata.name
  local psname,psfixed=fixedpsname(psname,fontname or fullname or file.nameonly(filename))
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
  local haskerns=properties.haskerns   or properties.mode=="base" 
  local hasligatures=properties.hasligatures or properties.mode=="base" 
  local realdimensions=properties.realdimensions
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
  if hasmath then
    local mathitalics=properties.mathitalics
    if mathitalics==false then
      if trace_defining then
        report_defining("%s italics %s for font %a, fullname %a, filename %a","math",hasitalics and "ignored" or "disabled",name,fullname,filename)
      end
      hasitalics=false
      autoitalicamount=false
    end
  else
    local textitalics=properties.textitalics
    if textitalics==false then
      if trace_defining then
        report_defining("%s italics %s for font %a, fullname %a, filename %a","text",hasitalics and "ignored" or "disabled",name,fullname,filename)
      end
      hasitalics=false
      autoitalicamount=false
    end
  end
  if trace_defining then
    report_defining("defining tfm, name %a, fullname %a, filename %a, %spsname %a, hscale %a, vscale %a, math %a, italics %a",
      name,fullname,filename,psfixed and "(fixed) " or "",psname,hdelta,vdelta,
      hasmath and "enabled" or "disabled",hasitalics and "enabled" or "disabled")
  end
  constructors.beforecopyingcharacters(target,tfmdata)
  local sharedkerns={}
  for unicode,character in next,characters do
    local chr,description,index
    if changed then
      local c=changed[unicode]
      if c then
        description=descriptions[c] or descriptions[unicode] or character
        character=characters[c] or character
        index=description.index or c
      else
        description=descriptions[unicode] or character
        index=description.index or unicode
      end
    else
      description=descriptions[unicode] or character
      index=description.index or unicode
    end
    local width=description.width
    local height=description.height
    local depth=description.depth
    if realdimensions then
      if not height or height==0 then
        local bb=description.boundingbox
        local ht=bb[4]
        if ht~=0 then
          height=ht
        end
        if not depth or depth==0 then
          local dp=-bb[2]
          if dp~=0 then
            depth=dp
          end
        end
      elseif not depth or depth==0 then
        local dp=-description.boundingbox[2]
        if dp~=0 then
          depth=dp
        end
      end
    end
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
    local isunicode=description.unicode
    if isunicode then
      chr.unicode=isunicode
      chr.tounicode=tounicode(isunicode)
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
      local vi=character.vert_italic
      if vi and vi~=0 then
        chr.vert_italic=vi*hdelta
      end
      local va=character.accent
      if va then
        chr.top_accent=vdelta*va
      end
      if stackmath then
        local mk=character.mathkerns
        if mk then
          local tr,tl,br,bl=mk.topright,mk.topleft,mk.bottomright,mk.bottomleft
          chr.mathkern={ 
            top_right=tr and mathkerns(tr,vdelta) or nil,
            top_left=tl and mathkerns(tl,vdelta) or nil,
            bottom_right=br and mathkerns(br,vdelta) or nil,
            bottom_left=bl and mathkerns(bl,vdelta) or nil,
          }
        end
      end
      if hasitalics then
        local vi=character.italic
        if vi and vi~=0 then
          chr.italic=vi*hdelta
        end
      end
    elseif autoitalicamount then 
      local vi=description.italic
      if not vi then
        local bb=description.boundingbox
        if bb then
          local vi=bb[3]-description.width+autoitalicamount
          if vi>0 then 
            chr.italic=vi*hdelta
          end
        else
        end
      elseif vi~=0 then
        chr.italic=vi*hdelta
      end
    elseif hasitalics then 
      local vi=character.italic
      if vi and vi~=0 then
        chr.italic=vi*hdelta
      end
    end
    if haskerns then
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
    end
    if hasligatures then
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
  properties.setitalics=hasitalics
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
  local designsize=parameters.designsize
  if designsize then
    parameters.minsize=tfmdata.minsize or designsize
    parameters.maxsize=tfmdata.maxsize or designsize
  else
    designsize=factors.pt*10
    parameters.designsize=designsize
    parameters.minsize=designsize
    parameters.maxsize=designsize
  end
  parameters.minsize=tfmdata.minsize or parameters.designsize
  parameters.maxsize=tfmdata.maxsize or parameters.designsize
  if not parameters.units then
    parameters.units=tfmdata.units or tfmdata.units_per_em or 1000
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
  tfmdata.units=nil
  tfmdata.units_per_em=nil
  tfmdata.cache=nil
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
      s[n]=k..'='..tostring(v)
    end
  end
  if n>0 then
    sort(s)
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
local newhandler={}
constructors.handlers=newhandler 
constructors.newhandler=newhandler
local function setnewhandler(what) 
  local handler=handlers[what]
  if not handler then
    handler={}
    handlers[what]=handler
  end
  return handler
end
setmetatable(newhandler,{
  __call=function(t,k) local v=t[k] return v end,
  __index=function(t,k) local v=setnewhandler(k) t[k]=v return v end,
})
local newfeatures={}
constructors.newfeatures=newfeatures 
constructors.features=newfeatures
local function setnewfeatures(what)
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
setmetatable(newfeatures,{
  __call=function(t,k) local v=t[k] return v end,
  __index=function(t,k) local v=setnewfeatures(k) t[k]=v return v end,
})
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
function constructors.addcoreunicodes(unicodes) 
  if not unicodes then
    unicodes={}
  end
  unicodes.space=0x0020
  unicodes.hyphen=0x002D
  unicodes.zwj=0x200D
  unicodes.zwnj=0x200C
  return unicodes
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
local encodings={}
fonts.encodings=encodings
encodings.agl={}
encodings.known={}
setmetatable(encodings.agl,{ __index=function(t,k)
  if k=="unicodes" then
    texio.write(" <loading (extended) adobe glyph list>")
    local unicodes=dofile(resolvers.findfile("font-age.lua"))
    encodings.agl={ unicodes=unicodes }
    return unicodes
  else
    return nil
  end
end })
encodings.cache=containers.define("fonts","enc",encodings.version,true)
function encodings.load(filename)
  local name=file.removesuffix(filename)
  local data=containers.read(encodings.cache,name)
  if data then
    return data
  end
  local vector,tag,hash,unicodes={},"",{},{}
  local foundname=resolvers.findfile(filename,'enc')
  if foundname and foundname~="" then
    local ok,encoding,size=resolvers.loadbinfile(foundname)
    if ok and encoding then
      encoding=string.gsub(encoding,"%%(.-)\n","")
      local unicoding=encodings.agl.unicodes
      local tag,vec=string.match(encoding,"/(%w+)%s*%[(.*)%]%s*def")
      local i=0
      for ch in string.gmatch(vec,"/([%a%d%.]+)") do
        if ch~=".notdef" then
          vector[i]=ch
          if not hash[ch] then
            hash[ch]=i
          else
          end
          local u=unicoding[ch]
          if u then
            unicodes[u]=i
          end
        end
        i=i+1
      end
    end
  end
  local data={
    name=name,
    tag=tag,
    vector=vector,
    hash=hash,
    unicodes=unicodes
  }
  return containers.write(encodings.cache,name,data)
end

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
      names=names,
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
  local lowername=lower(filename)
  local found=cidmap[lowername]
  if found then
    return found
  end
  if ordering=="Identity" then
    local found={
      supplement=supplement,
      registry=registry,
      ordering=ordering,
      filename=filename,
      unicodes={},
      names={},
    }
    cidmap[lowername]=found
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
local tonumber,next,type=tonumber,next,type
local match,format,find,concat,gsub,lower=string.match,string.format,string.find,table.concat,string.gsub,string.lower
local P,R,S,C,Ct,Cc,lpegmatch=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Ct,lpeg.Cc,lpeg.match
local floor=math.floor
local formatters=string.formatters
local trace_loading=false trackers.register("fonts.loading",function(v) trace_loading=v end)
local trace_mapping=false trackers.register("fonts.mapping",function(v) trace_mapping=v end)
local report_fonts=logs.reporter("fonts","loading") 
local force_ligatures=false directives.register("fonts.mapping.forceligatures",function(v) force_ligatures=v end)
local fonts=fonts or {}
local mappings=fonts.mappings or {}
fonts.mappings=mappings
local allocate=utilities.storage.allocate
local hex=R("AF","af","09")
local hexfour=(hex*hex*hex^-2)/function(s) return tonumber(s,16) end
local hexsix=(hex*hex*hex^-4)/function(s) return tonumber(s,16) end
local dec=(R("09")^1)/tonumber
local period=P(".")
local unicode=(P("uni")+P("UNI"))*(hexfour*(period+P(-1))*Cc(false)+Ct(hexfour^1)*Cc(true)) 
local ucode=(P("u")+P("U") )*(hexsix*(period+P(-1))*Cc(false)+Ct(hexsix^1)*Cc(true)) 
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
local f_single=formatters["%04X"]
local f_double=formatters["%04X%04X"]
local function tounicode16(unicode)
  if unicode<0xD7FF or (unicode>0xDFFF and unicode<=0xFFFF) then
    return f_single(unicode)
  else
    unicode=unicode-0x10000
    return f_double(floor(unicode/1024)+0xD800,unicode%1024+0xDC00)
  end
end
local function tounicode16sequence(unicodes)
  local t={}
  for l=1,#unicodes do
    local u=unicodes[l]
    if u<0xD7FF or (u>0xDFFF and u<=0xFFFF) then
      t[l]=f_single(u)
    else
      u=u-0x10000
      t[l]=f_double(floor(u/1024)+0xD800,u%1024+0xDC00)
    end
  end
  return concat(t)
end
local function tounicode(unicode,name)
  if type(unicode)=="table" then
    local t={}
    for l=1,#unicode do
      local u=unicode[l]
      if u<0xD7FF or (u>0xDFFF and u<=0xFFFF) then
        t[l]=f_single(u)
      else
        u=u-0x10000
        t[l]=f_double(floor(u/1024)+0xD800,u%1024+0xDC00)
      end
    end
    return concat(t)
  else
    if unicode<0xD7FF or (unicode>0xDFFF and unicode<=0xFFFF) then
      return f_single(unicode)
    else
      unicode=unicode-0x10000
      return f_double(floor(unicode/1024)+0xD800,unicode%1024+0xDC00)
    end
  end
end
local function fromunicode16(str)
  if #str==4 then
    return tonumber(str,16)
  else
    local l,r=match(str,"(....)(....)")
    return 0x10000+(tonumber(l,16)-0xD800)*0x400+tonumber(r,16)-0xDC00
  end
end
mappings.makenameparser=makenameparser
mappings.tounicode=tounicode
mappings.tounicode16=tounicode16
mappings.tounicode16sequence=tounicode16sequence
mappings.fromunicode16=fromunicode16
local ligseparator=P("_")
local varseparator=P(".")
local namesplitter=Ct(C((1-ligseparator-varseparator)^1)*(ligseparator*C((1-ligseparator-varseparator)^1))^0)
local overloads=allocate {
  IJ={ name="I_J",unicode={ 0x49,0x4A },mess=0x0132 },
  ij={ name="i_j",unicode={ 0x69,0x6A },mess=0x0133 },
  ff={ name="f_f",unicode={ 0x66,0x66 },mess=0xFB00 },
  fi={ name="f_i",unicode={ 0x66,0x69 },mess=0xFB01 },
  fl={ name="f_l",unicode={ 0x66,0x6C },mess=0xFB02 },
  ffi={ name="f_f_i",unicode={ 0x66,0x66,0x69 },mess=0xFB03 },
  ffl={ name="f_f_l",unicode={ 0x66,0x66,0x6C },mess=0xFB04 },
  fj={ name="f_j",unicode={ 0x66,0x6A } },
  fk={ name="f_k",unicode={ 0x66,0x6B } },
}
for k,v in next,overloads do
  local name=v.name
  local mess=v.mess
  if name then
    overloads[name]=v
  end
  if mess then
    overloads[mess]=v
  end
end
mappings.overloads=overloads
function mappings.addtounicode(data,filename,checklookups)
  local resources=data.resources
  local unicodes=resources.unicodes
  if not unicodes then
    if trace_mapping then
      report_fonts("no unicode list, quitting tounicode for %a",filename)
    end
    return
  end
  local properties=data.properties
  local descriptions=data.descriptions
  unicodes['space']=unicodes['space'] or 32
  unicodes['hyphen']=unicodes['hyphen'] or 45
  unicodes['zwj']=unicodes['zwj']  or 0x200D
  unicodes['zwnj']=unicodes['zwnj']  or 0x200C
  local private=fonts.constructors and fonts.constructors.privateoffset or 0xF0000 
  local unicodevector=fonts.encodings.agl.unicodes or {} 
  local contextvector=fonts.encodings.agl.ctxcodes or {} 
  local missing={}
  local nofmissing=0
  local oparser=nil
  local cidnames=nil
  local cidcodes=nil
  local cidinfo=properties.cidinfo
  local usedmap=cidinfo and fonts.cid.getmap(cidinfo)
  local uparser=makenameparser() 
  if usedmap then
     oparser=usedmap and makenameparser(cidinfo.ordering)
     cidnames=usedmap.names
     cidcodes=usedmap.unicodes
  end
  local ns=0
  local nl=0
  for du,glyph in next,descriptions do
    local name=glyph.name
    if name then
      local overload=overloads[name]
      if overload then
        glyph.unicode=overload.unicode
      else
        local gu=glyph.unicode 
        if not gu or gu==-1 or du>=private or (du>=0xE000 and du<=0xF8FF) or du==0xFFFE or du==0xFFFF then
          local unicode=unicodevector[name] or contextvector[name]
          if unicode then
            glyph.unicode=unicode
            ns=ns+1
          end
          if (not unicode) and usedmap then
            local foundindex=lpegmatch(oparser,name)
            if foundindex then
              unicode=cidcodes[foundindex] 
              if unicode then
                glyph.unicode=unicode
                ns=ns+1
              else
                local reference=cidnames[foundindex] 
                if reference then
                  local foundindex=lpegmatch(oparser,reference)
                  if foundindex then
                    unicode=cidcodes[foundindex]
                    if unicode then
                      glyph.unicode=unicode
                      ns=ns+1
                    end
                  end
                  if not unicode or unicode=="" then
                    local foundcodes,multiple=lpegmatch(uparser,reference)
                    if foundcodes then
                      glyph.unicode=foundcodes
                      if multiple then
                        nl=nl+1
                        unicode=true
                      else
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
            if nsplit==0 then
            elseif nsplit==1 then
              local base=split[1]
              local u=unicodes[base] or unicodevector[base] or contextvector[name]
              if not u then
              elseif type(u)=="table" then
                if u[1]<private then
                  unicode=u
                  glyph.unicode=unicode
                end
              elseif u<private then
                unicode=u
                glyph.unicode=unicode
              end
            else
              local t,n={},0
              for l=1,nsplit do
                local base=split[l]
                local u=unicodes[base] or unicodevector[base] or contextvector[name]
                if not u then
                  break
                elseif type(u)=="table" then
                  if u[1]>=private then
                    break
                  end
                  n=n+1
                  t[n]=u[1]
                else
                  if u>=private then
                    break
                  end
                  n=n+1
                  t[n]=u
                end
              end
              if n>0 then
                if n==1 then
                  unicode=t[1]
                else
                  unicode=t
                end
                glyph.unicode=unicode
              end
            end
            nl=nl+1
          end
          if not unicode or unicode=="" then
            local foundcodes,multiple=lpegmatch(uparser,name)
            if foundcodes then
              glyph.unicode=foundcodes
              if multiple then
                nl=nl+1
                unicode=true
              else
                ns=ns+1
                unicode=foundcodes
              end
            end
          end
          local r=overloads[unicode]
          if r then
            unicode=r.unicode
            glyph.unicode=unicode
          end
          if not unicode then
            missing[du]=true
            nofmissing=nofmissing+1
          end
        end
      end
    end
  end
  if type(checklookups)=="function" then
    checklookups(data,missing,nofmissing)
  end
  local collected=false
  local unicoded=0
  for unicode,glyph in next,descriptions do
    if glyph.class=="ligature" and (force_ligatures or not glyph.unicode) then
      if not collected then
        collected=fonts.handlers.otf.readers.getcomponents(data)
        if not collected then
          break
        end
      end
      local u=collected[unicode] 
      if u then
        local n=#u
        for i=1,n do
          if u[i]>private then
            n=0
            break
          end
        end
        if n>0 then
          if n>1 then
            glyph.unicode=u
          else
            glyph.unicode=u[1]
          end
          unicoded=unicoded+1
        end
      end
    end
  end
  if trace_mapping and unicoded>0 then
    report_fonts("%n ligature tounicode mappings deduced from gsub ligature features",unicoded)
  end
  if trace_mapping then
    for unic,glyph in table.sortedhash(descriptions) do
      local name=glyph.name or "-"
      local index=glyph.index or 0
      local unicode=glyph.unicode
      if unicode then
        if type(unicode)=="table" then
          local unicodes={}
          for i=1,#unicode do
            unicodes[i]=formatters("%U",unicode[i])
          end
          report_fonts("internal slot %U, name %a, unicode %U, tounicode % t",index,name,unic,unicodes)
        else
          report_fonts("internal slot %U, name %a, unicode %U, tounicode %U",index,name,unic,unicode)
        end
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
fonts.names.cache=containers.define("fonts","data",fonts.names.version,true)
local data=nil
local loaded=false
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
local otf=constructors.handlers.otf
local otffeatures=constructors.features.otf
local registerotffeature=otffeatures.register
local otftables=otf.tables or {}
otf.tables=otftables
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
otf.modeinitializer=setmode
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
otftables.featuretypes=allocate {
  gpos_single="position",
  gpos_pair="position",
  gpos_cursive="position",
  gpos_mark2base="position",
  gpos_mark2ligature="position",
  gpos_mark2mark="position",
  gpos_context="position",
  gpos_contextchain="position",
  gsub_single="substitution",
  gsub_multiple="substitution",
  gsub_alternate="substitution",
  gsub_ligature="substitution",
  gsub_context="substitution",
  gsub_contextchain="substitution",
  gsub_reversecontextchain="substitution",
  gsub_reversesub="substitution",
}
function otffeatures.checkeddefaultscript(featuretype,autoscript,scripts)
  if featuretype=="position" then
    local default=scripts.dflt
    if default then
      if autoscript=="position" or autoscript==true then
        return default
      else
        report_otf("script feature %s not applied, enable default positioning")
      end
    else
    end
  elseif featuretype=="substitution" then
    local default=scripts.dflt
    if default then
      if autoscript=="substitution" or autoscript==true then
        return default
      end
    end
  end
end
function otffeatures.checkeddefaultlanguage(featuretype,autolanguage,languages)
  if featuretype=="position" then
    local default=languages.dflt
    if default then
      if autolanguage=="position" or autolanguage==true then
        return default
      else
        report_otf("language feature %s not applied, enable default positioning")
      end
    else
    end
  elseif featuretype=="substitution" then
    local default=languages.dflt
    if default then
      if autolanguage=="substitution" or autolanguage==true then
        return default
      end
    end
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otr']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type,unpack=next,type,unpack
local byte,lower,char,strip,gsub=string.byte,string.lower,string.char,string.strip,string.gsub
local bittest=bit32.btest
local concat,remove,unpack,fastcopy=table.concat,table.remov,table.unpack,table.fastcopy
local floor,abs,sqrt,round=math.floor,math.abs,math.sqrt,math.round
local P,R,S,C,Cs,Cc,Ct,Carg,Cmt=lpeg.P,lpeg.R,lpeg.S,lpeg.C,lpeg.Cs,lpeg.Cc,lpeg.Ct,lpeg.Carg,lpeg.Cmt
local lpegmatch=lpeg.match
local setmetatableindex=table.setmetatableindex
local formatters=string.formatters
local sortedkeys=table.sortedkeys
local sortedhash=table.sortedhash
local stripstring=string.strip
local utf16_to_utf8_be=utf.utf16_to_utf8_be
local report=logs.reporter("otf reader")
local trace_cmap=false 
fonts=fonts or {}
local handlers=fonts.handlers or {}
fonts.handlers=handlers
local otf=handlers.otf or {}
handlers.otf=otf
local readers=otf.readers or {}
otf.readers=readers
local streamreader=utilities.files  
local streamwriter=utilities.files
readers.streamreader=streamreader
readers.streamwriter=streamwriter
local openfile=streamreader.open
local closefile=streamreader.close
local setposition=streamreader.setposition
local skipshort=streamreader.skipshort
local readbytes=streamreader.readbytes
local readstring=streamreader.readstring
local readbyte=streamreader.readcardinal1 
local readushort=streamreader.readcardinal2 
local readuint=streamreader.readcardinal3 
local readulong=streamreader.readcardinal4
local readshort=streamreader.readinteger2  
local readlong=streamreader.readinteger4  
local readfixed=streamreader.readfixed4
local readfword=readshort          
local readufword=readushort         
local readoffset=readushort
local read2dot14=streamreader.read2dot14   
function streamreader.readtag(f)
  return lower(strip(readstring(f,4)))
end
local function readlongdatetime(f)
  local a,b,c,d,e,f,g,h=readbytes(f,8)
  return 0x100000000*d+0x1000000*e+0x10000*f+0x100*g+h
end
local tableversion=0.004
readers.tableversion=tableversion
local privateoffset=fonts.constructors and fonts.constructors.privateoffset or 0xF0000 
local reportedskipped={}
local function reportskippedtable(tag)
  if not reportedskipped[tag] then
    report("loading of table %a skipped (reported once only)",tag)
    reportedskipped[tag]=true
  end
end
local reservednames={ [0]="copyright",
  "family",
  "subfamily",
  "uniqueid",
  "fullname",
  "version",
  "postscriptname",
  "trademark",
  "manufacturer",
  "designer",
  "description",
  "vendorurl",
  "designerurl",
  "license",
  "licenseurl",
  "reserved",
  "typographicfamily",
  "typographicsubfamily",
  "compatiblefullname",
  "sampletext",
  "cidfindfontname",
  "wwsfamily",
  "wwssubfamily",
  "lightbackgroundpalette",
  "darkbackgroundpalette",
}
local platforms={ [0]="unicode",
  "macintosh",
  "iso",
  "windows",
  "custom",
}
local encodings={
  unicode={ [0]="unicode 1.0 semantics",
    "unicode 1.1 semantics",
    "iso/iec 10646",
    "unicode 2.0 bmp",
    "unicode 2.0 full",
    "unicode variation sequences",
    "unicode full repertoire",
  },
  macintosh={ [0]="roman","japanese","chinese (traditional)","korean","arabic","hebrew","greek","russian",
    "rsymbol","devanagari","gurmukhi","gujarati","oriya","bengali","tamil","telugu","kannada",
    "malayalam","sinhalese","burmese","khmer","thai","laotian","georgian","armenian",
    "chinese (simplified)","tibetan","mongolian","geez","slavic","vietnamese","sindhi",
    "uninterpreted",
  },
  iso={ [0]="7-bit ascii",
    "iso 10646",
    "iso 8859-1",
  },
  windows={ [0]="symbol",
    "unicode bmp",
    "shiftjis",
    "prc",
    "big5",
    "wansung",
    "johab",
    "reserved 7",
    "reserved 8",
    "reserved 9",
    "unicode ucs-4",
  },
  custom={
  }
}
local decoders={
  unicode={},
  macintosh={},
  iso={},
  windows={
    ["unicode semantics"]=utf16_to_utf8_be,
    ["unicode bmp"]=utf16_to_utf8_be,
    ["unicode full"]=utf16_to_utf8_be,
    ["unicode 1.0 semantics"]=utf16_to_utf8_be,
    ["unicode 1.1 semantics"]=utf16_to_utf8_be,
    ["unicode 2.0 bmp"]=utf16_to_utf8_be,
    ["unicode 2.0 full"]=utf16_to_utf8_be,
    ["unicode variation sequences"]=utf16_to_utf8_be,
    ["unicode full repertoire"]=utf16_to_utf8_be,
  },
  custom={},
}
local languages={
  unicode={
    [ 0]="english",
  },
  macintosh={
    [ 0]="english",
  },
  iso={},
  windows={
    [0x0409]="english - united states",
  },
  custom={},
}
local standardromanencoding={ [0]=
  "notdef",".null","nonmarkingreturn","space","exclam","quotedbl",
  "numbersign","dollar","percent","ampersand","quotesingle","parenleft",
  "parenright","asterisk","plus","comma","hyphen","period","slash",
  "zero","one","two","three","four","five","six","seven","eight",
  "nine","colon","semicolon","less","equal","greater","question","at",
  "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O",
  "P","Q","R","S","T","U","V","W","X","Y","Z","bracketleft",
  "backslash","bracketright","asciicircum","underscore","grave","a","b",
  "c","d","e","f","g","h","i","j","k","l","m","n","o","p","q",
  "r","s","t","u","v","w","x","y","z","braceleft","bar",
  "braceright","asciitilde","Adieresis","Aring","Ccedilla","Eacute",
  "Ntilde","Odieresis","Udieresis","aacute","agrave","acircumflex",
  "adieresis","atilde","aring","ccedilla","eacute","egrave",
  "ecircumflex","edieresis","iacute","igrave","icircumflex","idieresis",
  "ntilde","oacute","ograve","ocircumflex","odieresis","otilde","uacute",
  "ugrave","ucircumflex","udieresis","dagger","degree","cent","sterling",
  "section","bullet","paragraph","germandbls","registered","copyright",
  "trademark","acute","dieresis","notequal","AE","Oslash","infinity",
  "plusminus","lessequal","greaterequal","yen","mu","partialdiff",
  "summation","product","pi","integral","ordfeminine","ordmasculine",
  "Omega","ae","oslash","questiondown","exclamdown","logicalnot",
  "radical","florin","approxequal","Delta","guillemotleft",
  "guillemotright","ellipsis","nonbreakingspace","Agrave","Atilde",
  "Otilde","OE","oe","endash","emdash","quotedblleft","quotedblright",
  "quoteleft","quoteright","divide","lozenge","ydieresis","Ydieresis",
  "fraction","currency","guilsinglleft","guilsinglright","fi","fl",
  "daggerdbl","periodcentered","quotesinglbase","quotedblbase",
  "perthousand","Acircumflex","Ecircumflex","Aacute","Edieresis","Egrave",
  "Iacute","Icircumflex","Idieresis","Igrave","Oacute","Ocircumflex",
  "apple","Ograve","Uacute","Ucircumflex","Ugrave","dotlessi",
  "circumflex","tilde","macron","breve","dotaccent","ring","cedilla",
  "hungarumlaut","ogonek","caron","Lslash","lslash","Scaron","scaron",
  "Zcaron","zcaron","brokenbar","Eth","eth","Yacute","yacute","Thorn",
  "thorn","minus","multiply","onesuperior","twosuperior","threesuperior",
  "onehalf","onequarter","threequarters","franc","Gbreve","gbreve",
  "Idotaccent","Scedilla","scedilla","Cacute","cacute","Ccaron","ccaron",
  "dcroat",
}
local weights={
  [100]="thin",
  [200]="extralight",
  [300]="light",
  [400]="normal",
  [500]="medium",
  [600]="semibold",
  [700]="bold",
  [800]="extrabold",
  [900]="black",
}
local widths={
  [1]="ultracondensed",
  [2]="extracondensed",
  [3]="condensed",
  [4]="semicondensed",
  [5]="normal",
  [6]="semiexpanded",
  [7]="expanded",
  [8]="extraexpanded",
  [9]="ultraexpanded",
}
setmetatableindex(weights,function(t,k)
  local r=floor((k+50)/100)*100
  local v=(r>900 and "black") or rawget(t,r) or "normal"
  return v
end)
setmetatableindex(widths,function(t,k)
  return "normal"
end)
local panoseweights={
  [ 0]="normal",
  [ 1]="normal",
  [ 2]="verylight",
  [ 3]="light",
  [ 4]="thin",
  [ 5]="book",
  [ 6]="medium",
  [ 7]="demi",
  [ 8]="bold",
  [ 9]="heavy",
  [10]="black",
}
local panosewidths={
  [ 0]="normal",
  [ 1]="normal",
  [ 2]="normal",
  [ 3]="normal",
  [ 4]="normal",
  [ 5]="expanded",
  [ 6]="condensed",
  [ 7]="veryexpanded",
  [ 8]="verycondensed",
  [ 9]="monospaced",
}
local platformnames={
  postscriptname=true,
  fullname=true,
  family=true,
  subfamily=true,
  typographicfamily=true,
  typographicsubfamily=true,
  compatiblefullname=true,
}
function readers.name(f,fontdata,specification)
  local datatable=fontdata.tables.name
  if datatable then
    setposition(f,datatable.offset)
    local format=readushort(f)
    local nofnames=readushort(f)
    local offset=readushort(f)
    local start=datatable.offset+offset
    local namelists={
      unicode={},
      windows={},
      macintosh={},
    }
    for i=1,nofnames do
      local platform=platforms[readushort(f)]
      if platform then
        local namelist=namelists[platform]
        if namelist then
          local encoding=readushort(f)
          local language=readushort(f)
          local encodings=encodings[platform]
          local languages=languages[platform]
          if encodings and languages then
            local encoding=encodings[encoding]
            local language=languages[language]
            if encoding and language then
              local name=reservednames[readushort(f)]
              if name then
                namelist[#namelist+1]={
                  platform=platform,
                  encoding=encoding,
                  language=language,
                  name=name,
                  length=readushort(f),
                  offset=start+readushort(f),
                }
              else
                skipshort(f,2)
              end
            else
              skipshort(f,3)
            end
          else
            skipshort(f,3)
          end
        else
          skipshort(f,5)
        end
      else
        skipshort(f,5)
      end
    end
    local names={}
    local done={}
    local function filter(platform,e,l)
      local namelist=namelists[platform]
      for i=1,#namelist do
        local name=namelist[i]
        local nametag=name.name
        if not done[nametag] then
          local encoding=name.encoding
          local language=name.language
          if (not e or encoding==e) and (not l or language==l) then
            setposition(f,name.offset)
            local content=readstring(f,name.length)
            local decoder=decoders[platform]
            if decoder then
              decoder=decoder[encoding]
            end
            if decoder then
              content=decoder(content)
            end
            names[nametag]={
              content=content,
              platform=platform,
              encoding=encoding,
              language=language,
            }
            done[nametag]=true
          end
        end
      end
    end
    filter("windows","unicode bmp","english - united states")
    filter("macintosh","roman","english")
    filter("windows")
    filter("macintosh")
    filter("unicode")
    fontdata.names=names
    if specification.platformnames then
      local collected={}
      for platform,namelist in next,namelists do
        local filtered=false
        for i=1,#namelist do
          local entry=namelist[i]
          local name=entry.name
          if platformnames[name] then
            setposition(f,entry.offset)
            local content=readstring(f,entry.length)
            local encoding=entry.encoding
            local decoder=decoders[platform]
            if decoder then
              decoder=decoder[encoding]
            end
            if decoder then
              content=decoder(content)
            end
            if filtered then
              filtered[name]=content
            else
              filtered={ [name]=content }
            end
          end
        end
        if filtered then
          collected[platform]=filtered
        end
      end
      fontdata.platformnames=collected
    end
  else
    fontdata.names={}
  end
end
local validutf=lpeg.patterns.validutf8
local function getname(fontdata,key)
  local names=fontdata.names
  if names then
    local value=names[key]
    if value then
      local content=value.content
      return lpegmatch(validutf,content) and content or nil
    end
  end
end
readers["os/2"]=function(f,fontdata)
  local datatable=fontdata.tables["os/2"]
  if datatable then
    setposition(f,datatable.offset)
    local version=readushort(f)
    local windowsmetrics={
      version=version,
      averagewidth=readshort(f),
      weightclass=readushort(f),
      widthclass=readushort(f),
      fstype=readushort(f),
      subscriptxsize=readshort(f),
      subscriptysize=readshort(f),
      subscriptxoffset=readshort(f),
      subscriptyoffset=readshort(f),
      superscriptxsize=readshort(f),
      superscriptysize=readshort(f),
      superscriptxoffset=readshort(f),
      superscriptyoffset=readshort(f),
      strikeoutsize=readshort(f),
      strikeoutpos=readshort(f),
      familyclass=readshort(f),
      panose={ readbytes(f,10) },
      unicoderanges={ readulong(f),readulong(f),readulong(f),readulong(f) },
      vendor=readstring(f,4),
      fsselection=readushort(f),
      firstcharindex=readushort(f),
      lastcharindex=readushort(f),
      typoascender=readshort(f),
      typodescender=readshort(f),
      typolinegap=readshort(f),
      winascent=readushort(f),
      windescent=readushort(f),
    }
    if version>=1 then
      windowsmetrics.codepageranges={ readulong(f),readulong(f) }
    end
    if version>=3 then
      windowsmetrics.xheight=readshort(f)
      windowsmetrics.capheight=readshort(f)
      windowsmetrics.defaultchar=readushort(f)
      windowsmetrics.breakchar=readushort(f)
    end
    windowsmetrics.weight=windowsmetrics.weightclass and weights[windowsmetrics.weightclass]
    windowsmetrics.width=windowsmetrics.widthclass and widths [windowsmetrics.widthclass]
    windowsmetrics.panoseweight=panoseweights[windowsmetrics.panose[3]]
    windowsmetrics.panosewidth=panosewidths [windowsmetrics.panose[4]]
    fontdata.windowsmetrics=windowsmetrics
  else
    fontdata.windowsmetrics={}
  end
end
readers.head=function(f,fontdata)
  local datatable=fontdata.tables.head
  if datatable then
    setposition(f,datatable.offset)
    local fontheader={
      version=readfixed(f),
      revision=readfixed(f),
      checksum=readulong(f),
      magic=readulong(f),
      flags=readushort(f),
      units=readushort(f),
      created=readlongdatetime(f),
      modified=readlongdatetime(f),
      xmin=readshort(f),
      ymin=readshort(f),
      xmax=readshort(f),
      ymax=readshort(f),
      macstyle=readushort(f),
      smallpixels=readushort(f),
      directionhint=readshort(f),
      indextolocformat=readshort(f),
      glyphformat=readshort(f),
    }
    fontdata.fontheader=fontheader
  else
    fontdata.fontheader={}
  end
  fontdata.nofglyphs=0
end
readers.hhea=function(f,fontdata,specification)
  if specification.details then
    local datatable=fontdata.tables.hhea
    if datatable then
      setposition(f,datatable.offset)
      fontdata.horizontalheader={
        version=readfixed(f),
        ascender=readfword(f),
        descender=readfword(f),
        linegap=readfword(f),
        maxadvancewidth=readufword(f),
        minleftsidebearing=readfword(f),
        minrightsidebearing=readfword(f),
        maxextent=readfword(f),
        caretsloperise=readshort(f),
        caretsloperun=readshort(f),
        caretoffset=readshort(f),
        reserved_1=readshort(f),
        reserved_2=readshort(f),
        reserved_3=readshort(f),
        reserved_4=readshort(f),
        metricdataformat=readshort(f),
        nofhmetrics=readushort(f),
      }
    else
      fontdata.horizontalheader={
        nofhmetrics=0,
      }
    end
  end
end
readers.maxp=function(f,fontdata,specification)
  if specification.details then
    local datatable=fontdata.tables.maxp
    if datatable then
      setposition(f,datatable.offset)
      local version=readfixed(f)
      local nofglyphs=readushort(f)
      fontdata.nofglyphs=nofglyphs
      if version==0.5 then
        fontdata.maximumprofile={
          version=version,
          nofglyphs=nofglyphs,
        }
        return
      elseif version==1.0 then
        fontdata.maximumprofile={
          version=version,
          nofglyphs=nofglyphs,
          points=readushort(f),
          contours=readushort(f),
          compositepoints=readushort(f),
          compositecontours=readushort(f),
          zones=readushort(f),
          twilightpoints=readushort(f),
          storage=readushort(f),
          functiondefs=readushort(f),
          instructiondefs=readushort(f),
          stackelements=readushort(f),
          sizeofinstructions=readushort(f),
          componentelements=readushort(f),
          componentdepth=readushort(f),
        }
        return
      end
    end
    fontdata.maximumprofile={
      version=version,
      nofglyphs=0,
    }
  end
end
readers.hmtx=function(f,fontdata,specification)
  if specification.glyphs then
    local datatable=fontdata.tables.hmtx
    if datatable then
      setposition(f,datatable.offset)
      local nofmetrics=fontdata.horizontalheader.nofhmetrics
      local glyphs=fontdata.glyphs
      local nofglyphs=fontdata.nofglyphs
      local width=0 
      local leftsidebearing=0
      for i=0,nofmetrics-1 do
        local glyph=glyphs[i]
        width=readshort(f)
        leftsidebearing=readshort(f)
        if width~=0 then
          glyph.width=width
        end
      end
      for i=nofmetrics,nofglyphs-1 do
        local glyph=glyphs[i]
        if width~=0 then
          glyph.width=width
        end
      end
    end
  end
end
readers.post=function(f,fontdata,specification)
  local datatable=fontdata.tables.post
  if datatable then
    setposition(f,datatable.offset)
    local version=readfixed(f)
    fontdata.postscript={
      version=version,
      italicangle=round(1000*readfixed(f))/1000,
      underlineposition=readfword(f),
      underlinethickness=readfword(f),
      monospaced=readulong(f),
      minmemtype42=readulong(f),
      maxmemtype42=readulong(f),
      minmemtype1=readulong(f),
      maxmemtype1=readulong(f),
    }
    if not specification.glyphs then
    elseif version==1.0 then
      for index=0,#standardromanencoding do
        glyphs[index].name=standardromanencoding[index]
      end
    elseif version==2.0 then
      local glyphs=fontdata.glyphs
      local nofglyphs=readushort(f)
      local indices={}
      local names={}
      local maxnames=0
      for i=0,nofglyphs-1 do
        local nameindex=readushort(f)
        if nameindex>=258 then
          maxnames=maxnames+1
          nameindex=nameindex-257
          indices[nameindex]=i
        else
          glyphs[i].name=standardromanencoding[nameindex]
        end
      end
      for i=1,maxnames do
        local mapping=indices[i]
        if not mapping then
          report("quit post name fetching at %a of %a: %s",i,maxnames,"no index")
          break
        else
          local length=readbyte(f)
          if length>0 then
            glyphs[mapping].name=readstring(f,length)
          else
            report("quit post name fetching at %a of %a: %s",i,maxnames,"overflow")
            break
          end
        end
      end
    elseif version==2.5 then
    elseif version==3.0 then
    end
  else
    fontdata.postscript={}
  end
end
readers.cff=function(f,fontdata,specification)
  if specification.glyphs then
    reportskippedtable("cff")
  end
end
local formatreaders={}
local duplicatestoo=true
local sequence={
  { 3,1,4 },
  { 3,10,12 },
  { 0,3,4 },
  { 0,1,4 },
  { 0,0,6 },
  { 3,0,6 },
  { 0,5,14 },
  { 3,10,13 },
}
local supported={}
for i=1,#sequence do
  local sp,se,sf=unpack(sequence[i])
  local p=supported[sp]
  if not p then
    p={}
    supported[sp]=p
  end
  local e=p[se]
  if not e then
    e={}
    p[se]=e
  end
  e[sf]=true
end
formatreaders[4]=function(f,fontdata,offset)
  setposition(f,offset+2)
  local length=readushort(f) 
  local language=readushort(f)
  local nofsegments=readushort(f)/2
  skipshort(f,3)
  local endchars={}
  local startchars={}
  local deltas={}
  local offsets={}
  local indices={}
  local mapping=fontdata.mapping
  local glyphs=fontdata.glyphs
  local duplicates=fontdata.duplicates
  local nofdone=0
  for i=1,nofsegments do
    endchars[i]=readushort(f)
  end
  local reserved=readushort(f) 
  for i=1,nofsegments do
    startchars[i]=readushort(f)
  end
  for i=1,nofsegments do
    deltas[i]=readshort(f)
  end
  for i=1,nofsegments do
    offsets[i]=readushort(f)
  end
  local size=(length-2*2-5*2-4*nofsegments*2)/2
  for i=1,size-1 do
    indices[i]=readushort(f)
  end
  for segment=1,nofsegments do
    local startchar=startchars[segment]
    local endchar=endchars[segment]
    local offset=offsets[segment]
    local delta=deltas[segment]
    if startchar==0xFFFF and endchar==0xFFFF then
    elseif startchar==0xFFFF and offset==0 then
    elseif offset==0xFFFF then
    elseif offset==0 then
      if trace_cmap then
        report("format 4.%i segment %2i from %C upto %C at index %H",1,segment,startchar,endchar,(startchar+delta)%65536)
      end
      for unicode=startchar,endchar do
        local index=(unicode+delta)%65536
        if index and index>0 then
          local glyph=glyphs[index]
          if glyph then
            local gu=glyph.unicode
            if not gu then
              glyph.unicode=unicode
              nofdone=nofdone+1
            elseif gu~=unicode then
              if duplicatestoo then
                local d=duplicates[gu]
                if d then
                  d[unicode]=true
                else
                  duplicates[gu]={ [unicode]=true }
                end
              else
                report("duplicate case 1: %C %04i %s",unicode,index,glyphs[index].name)
              end
            end
            if not mapping[index] then
              mapping[index]=unicode
            end
          end
        end
      end
    else
      local shift=(segment-nofsegments+offset/2)-startchar
      if trace_cmap then
        report("format 4.%i segment %2i from %C upto %C at index %H",0,segment,startchar,endchar,(startchar+delta)%65536)
      end
      for unicode=startchar,endchar do
        local slot=shift+unicode
        local index=indices[slot]
        if index and index>0 then
          index=(index+delta)%65536
          local glyph=glyphs[index]
          if glyph then
            local gu=glyph.unicode
            if not gu then
              glyph.unicode=unicode
              nofdone=nofdone+1
            elseif gu~=unicode then
              if duplicatestoo then
                local d=duplicates[gu]
                if d then
                  d[unicode]=true
                else
                  duplicates[gu]={ [unicode]=true }
                end
              else
                report("duplicate case 2: %C %04i %s",unicode,index,glyphs[index].name)
              end
            end
            if not mapping[index] then
              mapping[index]=unicode
            end
          end
        end
      end
    end
  end
  return nofdone
end
formatreaders[6]=function(f,fontdata,offset)
  setposition(f,offset) 
  local format=readushort(f)
  local length=readushort(f)
  local language=readushort(f)
  local mapping=fontdata.mapping
  local glyphs=fontdata.glyphs
  local duplicates=fontdata.duplicates
  local start=readushort(f)
  local count=readushort(f)
  local stop=start+count-1
  local nofdone=0
  if trace_cmap then
    report("format 6 from %C to %C",2,start,stop)
  end
  for unicode=start,stop do
    local index=readushort(f)
    if index>0 then
      local glyph=glyphs[index]
      if glyph then
        local gu=glyph.unicode
        if not gu then
          glyph.unicode=unicode
          nofdone=nofdone+1
        elseif gu~=unicode then
        end
        if not mapping[index] then
          mapping[index]=unicode
        end
      end
    end
  end
  return nofdone
end
formatreaders[12]=function(f,fontdata,offset)
  setposition(f,offset+2+2+4+4) 
  local mapping=fontdata.mapping
  local glyphs=fontdata.glyphs
  local duplicates=fontdata.duplicates
  local nofgroups=readulong(f)
  local nofdone=0
  for i=1,nofgroups do
    local first=readulong(f)
    local last=readulong(f)
    local index=readulong(f)
    if trace_cmap then
      report("format 12 from %C to %C starts at index %i",first,last,index)
    end
    for unicode=first,last do
      local glyph=glyphs[index]
      if glyph then
        local gu=glyph.unicode
        if not gu then
          glyph.unicode=unicode
          nofdone=nofdone+1
        elseif gu~=unicode then
          local d=duplicates[gu]
          if d then
            d[unicode]=true
          else
            duplicates[gu]={ [unicode]=true }
          end
        end
        if not mapping[index] then
          mapping[index]=unicode
        end
      end
      index=index+1
    end
  end
  return nofdone
end
formatreaders[13]=function(f,fontdata,offset)
  setposition(f,offset+2+2+4+4) 
  local mapping=fontdata.mapping
  local glyphs=fontdata.glyphs
  local duplicates=fontdata.duplicates
  local nofgroups=readulong(f)
  local nofdone=0
  for i=1,nofgroups do
    local first=readulong(f)
    local last=readulong(f)
    local index=readulong(f)
    if first<privateoffset then
      if trace_cmap then
        report("format 13 from %C to %C get index %i",first,last,index)
      end
      local glyph=glyphs[index]
      local unicode=glyph.unicode
      if not unicode then
        unicode=first
        glyph.unicode=unicode
        first=first+1
      end
      local list=duplicates[unicode]
      mapping[index]=unicode
      if not list then
        list={}
        duplicates[unicode]=list
      end
      if last>=privateoffset then
        local limit=privateoffset-1
        report("format 13 from %C to %C pruned to %C",first,last,limit)
        last=limit
      end
      for unicode=first,last do
        list[unicode]=true
      end
      nofdone=nofdone+last-first+1
    else
      report("format 13 from %C to %C ignored",first,last)
    end
  end
  return nofdone
end
formatreaders[14]=function(f,fontdata,offset)
  if offset and offset~=0 then
    setposition(f,offset)
    local format=readushort(f)
    local length=readulong(f)
    local nofrecords=readulong(f)
    local records={}
    local variants={}
    local nofdone=0
    fontdata.variants=variants
    for i=1,nofrecords do
      records[i]={
        selector=readuint(f),
        default=readulong(f),
        other=readulong(f),
      }
    end
    for i=1,nofrecords do
      local record=records[i]
      local selector=record.selector
      local default=record.default
      local other=record.other
      local other=record.other
      if other~=0 then
        setposition(f,offset+other)
        local mapping={}
        local count=readulong(f)
        for i=1,count do
          mapping[readuint(f)]=readushort(f)
        end
        nofdone=nofdone+count
        variants[selector]=mapping
      end
    end
    return nofdone
  else
    return 0
  end
end
local function checkcmap(f,fontdata,records,platform,encoding,format)
  local data=records[platform]
  if not data then
    return 0
  end
  data=data[encoding]
  if not data then
    return 0
  end
  data=data[format]
  if not data then
    return 0
  end
  local reader=formatreaders[format]
  if not reader then
    return 0
  end
  local p=platforms[platform]
  local e=encodings[p]
  local n=reader(f,fontdata,data) or 0
  report("cmap checked: platform %i (%s), encoding %i (%s), format %i, new unicodes %i",platform,p,encoding,e and e[encoding] or "?",format,n)
  return n
end
function readers.cmap(f,fontdata,specification)
  if specification.glyphs then
    local datatable=fontdata.tables.cmap
    if datatable then
      local tableoffset=datatable.offset
      setposition(f,tableoffset)
      local version=readushort(f)
      local noftables=readushort(f)
      local records={}
      local unicodecid=false
      local variantcid=false
      local variants={}
      local duplicates=fontdata.duplicates or {}
      fontdata.duplicates=duplicates
      for i=1,noftables do
        local platform=readushort(f)
        local encoding=readushort(f)
        local offset=readulong(f)
        local record=records[platform]
        if not record then
          records[platform]={
            [encoding]={
              offsets={ offset },
              formats={},
            }
          }
        else
          local subtables=record[encoding]
          if not subtables then
            record[encoding]={
              offsets={ offset },
              formats={},
            }
          else
            local offsets=subtables.offsets
            offsets[#offsets+1]=offset
          end
        end
      end
      report("found cmaps:")
      for platform,record in sortedhash(records) do
        local p=platforms[platform]
        local e=encodings[p]
        local sp=supported[platform]
        local ps=p or "?"
        if sp then
          report("  platform %i: %s",platform,ps)
        else
          report("  platform %i: %s (unsupported)",platform,ps)
        end
        for encoding,subtables in sortedhash(record) do
          local se=sp and sp[encoding]
          local es=e and e[encoding] or "?"
          if se then
            report("    encoding %i: %s",encoding,es)
          else
            report("    encoding %i: %s (unsupported)",encoding,es)
          end
          local offsets=subtables.offsets
          local formats=subtables.formats
          for i=1,#offsets do
            local offset=tableoffset+offsets[i]
            setposition(f,offset)
            formats[readushort(f)]=offset
          end
          record[encoding]=formats
          local list=sortedkeys(formats)
          for i=1,#list do
            if not (se and se[list[i]]) then
              list[i]=list[i].." (unsupported)"
            end
          end
          report("      formats: % t",list)
        end
      end
      local ok=false
      for i=1,#sequence do
        local sp,se,sf=unpack(sequence[i])
        if checkcmap(f,fontdata,records,sp,se,sf)>0 then
          ok=true
        end
      end
      if not ok then
        report("no useable unicode cmap found")
      end
      fontdata.cidmaps={
        version=version,
        noftables=noftables,
        records=records,
      }
    else
      fontdata.cidmaps={}
    end
  end
end
function readers.loca(f,fontdata,specification)
  if specification.glyphs then
    reportskippedtable("loca")
  end
end
function readers.glyf(f,fontdata,specification) 
  if specification.glyphs then
    reportskippedtable("glyf")
  end
end
function readers.colr(f,fontdata,specification)
  if specification.glyphs then
    reportskippedtable("colr")
  end
end
function readers.cpal(f,fontdata,specification)
  if specification.glyphs then
    reportskippedtable("cpal")
  end
end
function readers.svg(f,fontdata,specification)
  if specification.glyphs then
    reportskippedtable("svg")
  end
end
function readers.kern(f,fontdata,specification)
  if specification.kerns then
    local datatable=fontdata.tables.kern
    if datatable then
      setposition(f,datatable.offset)
      local version=readushort(f)
      local noftables=readushort(f)
      for i=1,noftables do
        local version=readushort(f)
        local length=readushort(f)
        local coverage=readushort(f)
        local format=bit32.rshift(coverage,8) 
        if format==0 then
          local nofpairs=readushort(f)
          local searchrange=readushort(f)
          local entryselector=readushort(f)
          local rangeshift=readushort(f)
          local kerns={}
          local glyphs=fontdata.glyphs
          for i=1,nofpairs do
            local left=readushort(f)
            local right=readushort(f)
            local kern=readfword(f)
            local glyph=glyphs[left]
            local kerns=glyph.kerns
            if kerns then
              kerns[right]=kern
            else
              glyph.kerns={ [right]=kern }
            end
          end
        elseif format==2 then
          report("todo: kern classes")
        else
          report("todo: kerns")
        end
      end
    end
  end
end
function readers.gdef(f,fontdata,specification)
  if specification.details then
    reportskippedtable("gdef")
  end
end
function readers.gsub(f,fontdata,specification)
  if specification.details then
    reportskippedtable("gsub")
  end
end
function readers.gpos(f,fontdata,specification)
  if specification.details then
    reportskippedtable("gpos")
  end
end
function readers.math(f,fontdata,specification)
  if specification.glyphs then
    reportskippedtable("math")
  end
end
local function packoutlines(data,makesequence)
  local subfonts=data.subfonts
  if subfonts then
    for i=1,#subfonts do
      packoutlines(subfonts[i],makesequence)
    end
    return
  end
  local common=data.segments
  if common then
    return
  end
  local glyphs=data.glyphs
  if not glyphs then
    return
  end
  if makesequence then
    for index=1,#glyphs do
      local glyph=glyphs[index]
      local segments=glyph.segments
      if segments then
        local sequence={}
        local nofsequence=0
        for i=1,#segments do
          local segment=segments[i]
          local nofsegment=#segment
          nofsequence=nofsequence+1
          sequence[nofsequence]=segment[nofsegment]
          for i=1,nofsegment-1 do
            nofsequence=nofsequence+1
            sequence[nofsequence]=segment[i]
          end
        end
        glyph.sequence=sequence
        glyph.segments=nil
      end
    end
  else
    local hash={}
    local common={}
    local reverse={}
    local last=0
    for index=1,#glyphs do
      local segments=glyphs[index].segments
      if segments then
        for i=1,#segments do
          local h=concat(segments[i]," ")
          hash[h]=(hash[h] or 0)+1
        end
      end
    end
    for index=1,#glyphs do
      local segments=glyphs[index].segments
      if segments then
        for i=1,#segments do
          local segment=segments[i]
          local h=concat(segment," ")
          if hash[h]>1 then 
            local idx=reverse[h]
            if not idx then
              last=last+1
              reverse[h]=last
              common[last]=segment
              idx=last
            end
            segments[i]=idx
          end
        end
      end
    end
    if last>0 then
      data.segments=common
    end
  end
end
local function unpackoutlines(data)
  local subfonts=data.subfonts
  if subfonts then
    for i=1,#subfonts do
      unpackoutlines(subfonts[i])
    end
    return
  end
  local common=data.segments
  if not common then
    return
  end
  local glyphs=data.glyphs
  if not glyphs then
    return
  end
  for index=1,#glyphs do
    local segments=glyphs[index].segments
    if segments then
      for i=1,#segments do
        local c=common[segments[i]]
        if c then
          segments[i]=c
        end
      end
    end
  end
  data.segments=nil
end
otf.packoutlines=packoutlines
otf.unpackoutlines=unpackoutlines
local function getinfo(maindata,sub,platformnames,rawfamilynames)
  local fontdata=sub and maindata.subfonts and maindata.subfonts[sub] or maindata
  local names=fontdata.names
  local info=nil
  if names then
    local metrics=fontdata.windowsmetrics or {}
    local postscript=fontdata.postscript   or {}
    local fontheader=fontdata.fontheader   or {}
    local cffinfo=fontdata.cffinfo    or {}
    local filename=fontdata.filename
    local weight=getname(fontdata,"weight") or cffinfo.weight or metrics.weight
    local width=getname(fontdata,"width") or cffinfo.width or metrics.width
    local fontname=getname(fontdata,"postscriptname")
    local fullname=getname(fontdata,"fullname")
    local family=getname(fontdata,"family")
    local subfamily=getname(fontdata,"subfamily")
    local familyname=getname(fontdata,"typographicfamily")
    local subfamilyname=getname(fontdata,"typographicsubfamily")
    local compatiblename=getname(fontdata,"compatiblefullname") 
    if rawfamilynames then
    else
      if not  familyname then  familyname=family end
      if not subfamilyname then subfamilyname=subfamily end
    end
    info={ 
      subfontindex=fontdata.subfontindex or sub or 0,
      version=getname(fontdata,"version"),
      fontname=fontname,
      fullname=fullname,
      family=family,
      subfamily=subfamily,
      familyname=familyname,
      subfamilyname=subfamilyname,
      compatiblename=compatiblename,
      weight=weight and lower(weight),
      width=width and lower(width),
      pfmweight=metrics.weightclass or 400,
      pfmwidth=metrics.widthclass or 5,
      panosewidth=metrics.panosewidth,
      panoseweight=metrics.panoseweight,
      italicangle=postscript.italicangle or 0,
      units=fontheader.units or 0,
      designsize=fontdata.designsize,
      minsize=fontdata.minsize,
      maxsize=fontdata.maxsize,
      monospaced=(tonumber(postscript.monospaced or 0)>0) or metrics.panosewidth=="monospaced",
      averagewidth=metrics.averagewidth,
      xheight=metrics.xheight,
      capheight=metrics.capheight,
      ascender=metrics.typoascender,
      descender=metrics.typodescender,
      platformnames=platformnames and fontdata.platformnames or nil,
    }
  elseif n then
    info={
      filename=fontdata.filename,
      comment="there is no info for subfont "..n,
    }
  else
    info={
      filename=fontdata.filename,
      comment="there is no info",
    }
  end
  return info
end
local function loadtables(f,specification,offset)
  if offset then
    setposition(f,offset)
  end
  local tables={}
  local basename=file.basename(specification.filename)
  local filesize=specification.filesize
  local filetime=specification.filetime
  local fontdata={ 
    filename=basename,
    filesize=filesize,
    filetime=filetime,
    version=readstring(f,4),
    noftables=readushort(f),
    searchrange=readushort(f),
    entryselector=readushort(f),
    rangeshift=readushort(f),
    tables=tables,
  }
  for i=1,fontdata.noftables do
    local tag=lower(stripstring(readstring(f,4)))
    local checksum=readulong(f) 
    local offset=readulong(f)
    local length=readulong(f)
    if offset+length>filesize then
      report("bad %a table in file %a",tag,basename)
    end
    tables[tag]={
      checksum=checksum,
      offset=offset,
      length=length,
    }
  end
  if tables.cff then
    fontdata.format="opentype"
  else
    fontdata.format="truetype"
  end
  return fontdata
end
local function prepareglyps(fontdata)
  local glyphs=setmetatableindex(function(t,k)
    local v={
      index=k,
    }
    t[k]=v
    return v
  end)
  fontdata.glyphs=glyphs
  fontdata.mapping={}
end
local function readdata(f,offset,specification)
  local fontdata=loadtables(f,specification,offset)
  if specification.glyphs then
    prepareglyps(fontdata)
  end
  readers["name"](f,fontdata,specification)
  local askedname=specification.askedname
  if askedname then
    local fullname=getname(fontdata,"fullname") or ""
    local cleanname=gsub(askedname,"[^a-zA-Z0-9]","")
    local foundname=gsub(fullname,"[^a-zA-Z0-9]","")
    if lower(cleanname)~=lower(foundname) then
      return 
    end
  end
  readers["os/2"](f,fontdata,specification)
  readers["head"](f,fontdata,specification)
  readers["maxp"](f,fontdata,specification)
  readers["hhea"](f,fontdata,specification)
  readers["hmtx"](f,fontdata,specification)
  readers["post"](f,fontdata,specification)
  readers["cff" ](f,fontdata,specification)
  readers["cmap"](f,fontdata,specification)
  readers["loca"](f,fontdata,specification)
  readers["glyf"](f,fontdata,specification)
  readers["colr"](f,fontdata,specification)
  readers["cpal"](f,fontdata,specification)
  readers["svg" ](f,fontdata,specification)
  readers["kern"](f,fontdata,specification)
  readers["gdef"](f,fontdata,specification)
  readers["gsub"](f,fontdata,specification)
  readers["gpos"](f,fontdata,specification)
  readers["math"](f,fontdata,specification)
  fontdata.locations=nil
  fontdata.tables=nil
  fontdata.cidmaps=nil
  fontdata.dictionaries=nil
  return fontdata
end
local function loadfontdata(specification)
  local filename=specification.filename
  local fileattr=lfs.attributes(filename)
  local filesize=fileattr and fileattr.size or 0
  local filetime=fileattr and fileattr.modification or 0
  local f=openfile(filename,true) 
  if not f then
    report("unable to open %a",filename)
  elseif filesize==0 then
    report("empty file %a",filename)
    closefile(f)
  else
    specification.filesize=filesize
    specification.filetime=filetime
    local version=readstring(f,4)
    local fontdata=nil
    if version=="OTTO" or version=="true" or version=="\0\1\0\0" then
      fontdata=readdata(f,0,specification)
    elseif version=="ttcf" then
      local subfont=tonumber(specification.subfont)
      local offsets={}
      local ttcversion=readulong(f)
      local nofsubfonts=readulong(f)
      for i=1,nofsubfonts do
        offsets[i]=readulong(f)
      end
      if subfont then 
        if subfont>=1 and subfont<=nofsubfonts then
          fontdata=readdata(f,offsets[subfont],specification)
        else
          report("no subfont %a in file %a",subfont,filename)
        end
      else
        subfont=specification.subfont
        if type(subfont)=="string" and subfont~="" then
          specification.askedname=subfont
          for i=1,nofsubfonts do
            fontdata=readdata(f,offsets[i],specification)
            if fontdata then
              fontdata.subfontindex=i
              report("subfont named %a has index %a",subfont,i)
              break
            end
          end
          if not fontdata then
            report("no subfont named %a",subfont)
          end
        else
          local subfonts={}
          fontdata={
            filename=filename,
            filesize=filesize,
            filetime=filetime,
            version=version,
            subfonts=subfonts,
            ttcversion=ttcversion,
            nofsubfonts=nofsubfonts,
          }
          for i=1,nofsubfonts do
            subfonts[i]=readdata(f,offsets[i],specification)
          end
        end
      end
    else
      report("unknown version %a in file %a",version,filename)
    end
    closefile(f)
    return fontdata or {}
  end
end
local function loadfont(specification,n)
  if type(specification)=="string" then
    specification={
      filename=specification,
      info=true,
      details=true,
      glyphs=true,
      shapes=true,
      kerns=true,
      globalkerns=true,
      lookups=true,
      subfont=n or true,
      tounicode=false,
    }
  end
  if specification.shapes or specification.lookups or specification.kerns then
    specification.glyphs=true
  end
  if specification.glyphs then
    specification.details=true
  end
  if specification.details then
    specification.info=true 
  end
  if specification.platformnames then
    specification.platformnames=true 
  end
  local function message(str)
    report("fatal error in file %a: %s\n%s",specification.filename,str,debug.traceback())
  end
  local ok,result=xpcall(loadfontdata,message,specification)
  if ok then
    return result
  end
end
function readers.loadshapes(filename,n)
  local fontdata=loadfont {
    filename=filename,
    shapes=true,
    subfont=n,
  }
  return fontdata and {
    filename=filename,
    format=fontdata.format,
    glyphs=fontdata.glyphs,
    units=fontdata.fontheader.units,
  } or {
    filename=filename,
    format="unknown",
    glyphs={},
    units=0,
  }
end
function readers.loadfont(filename,n)
  local fontdata=loadfont {
    filename=filename,
    glyphs=true,
    shapes=false,
    lookups=true,
    subfont=n,
  }
  if fontdata then
    return {
      tableversion=tableversion,
      creator="context mkiv",
      size=fontdata.filesize,
      time=fontdata.filetime,
      glyphs=fontdata.glyphs,
      descriptions=fontdata.descriptions,
      format=fontdata.format,
      goodies={},
      metadata=getinfo(fontdata,n),
      properties={
        hasitalics=fontdata.hasitalics or false,
        maxcolorclass=fontdata.maxcolorclass,
        hascolor=fontdata.hascolor or false,
      },
      resources={
        filename=filename,
        private=privateoffset,
        duplicates=fontdata.duplicates or {},
        features=fontdata.features  or {},
        sublookups=fontdata.sublookups or {},
        marks=fontdata.marks    or {},
        markclasses=fontdata.markclasses or {},
        marksets=fontdata.marksets  or {},
        sequences=fontdata.sequences  or {},
        variants=fontdata.variants,
        version=getname(fontdata,"version"),
        cidinfo=fontdata.cidinfo,
        mathconstants=fontdata.mathconstants,
        colorpalettes=fontdata.colorpalettes,
        svgshapes=fontdata.svgshapes,
      },
    }
  end
end
function readers.getinfo(filename,specification)
  local subfont=nil
  local platformnames=false
  local rawfamilynames=false
  if type(specification)=="table" then
    subfont=tonumber(specification.subfont)
    platformnames=specification.platformnames
    rawfamilynames=specification.rawfamilynames
  else
    subfont=tonumber(specification)
  end
  local fontdata=loadfont {
    filename=filename,
    details=true,
    platformnames=platformnames,
  }
  if fontdata then
    local subfonts=fontdata.subfonts
    if not subfonts then
      return getinfo(fontdata,nil,platformnames,rawfamilynames)
    elseif not subfont then
      local info={}
      for i=1,#subfonts do
        info[i]=getinfo(fontdata,i,platformnames,rawfamilynames)
      end
      return info
    elseif subfont>=1 and subfont<=#subfonts then
      return getinfo(fontdata,subfont,platformnames,rawfamilynames)
    else
      return {
        filename=filename,
        comment="there is no subfont "..subfont.." in this file"
      }
    end
  else
    return {
      filename=filename,
      comment="the file cannot be opened for reading",
    }
  end
end
function readers.rehash(fontdata,hashmethod)
  report("the %a helper is not yet implemented","rehash")
end
function readers.checkhash(fontdata)
  report("the %a helper is not yet implemented","checkhash")
end
function readers.pack(fontdata,hashmethod)
  report("the %a helper is not yet implemented","pack")
end
function readers.unpack(fontdata)
  report("the %a helper is not yet implemented","unpack")
end
function readers.expand(fontdata)
  report("the %a helper is not yet implemented","unpack")
end
function readers.compact(fontdata)
  report("the %a helper is not yet implemented","compact")
end
local extenders={}
function readers.registerextender(extender)
  extenders[#extenders+1]=extender
end
function readers.extend(fontdata)
  for i=1,#extenders do
    local extender=extenders[i]
    local name=extender.name or "unknown"
    local action=extender.action
    if action then
      action(fontdata)
    end
  end
end
if fonts.hashes then
  local identifiers=fonts.hashes.identifiers
  local loadshapes=readers.loadshapes
  readers.version=0.006
  readers.cache=containers.define("fonts","shapes",readers.version,true)
  local function load(filename,sub)
    local base=file.basename(filename)
    local name=file.removesuffix(base)
    local kind=file.suffix(filename)
    local attr=lfs.attributes(filename)
    local size=attr and attr.size or 0
    local time=attr and attr.modification or 0
    local sub=tonumber(sub)
    if size>0 and (kind=="otf" or kind=="ttf" or kind=="tcc") then
      local hash=containers.cleanname(base) 
      if sub then
        hash=hash.."-"..sub
      end
      data=containers.read(readers.cache,hash)
      if not data or data.time~=time or data.size~=size then
        data=loadshapes(filename,sub)
        if data then
          data.size=size
          data.format=data.format or (kind=="otf" and "opentype") or "truetype"
          data.time=time
          packoutlines(data)
          containers.write(readers.cache,hash,data)
          data=containers.read(readers.cache,hash) 
        end
      end
      unpackoutlines(data)
    else
      data={
        filename=filename,
        size=0,
        time=time,
        format="unknown",
        units=1000,
        glyphs={}
      }
    end
    return data
  end
  fonts.hashes.shapes=table.setmetatableindex(function(t,k)
    local d=identifiers[k]
    local v=load(d.properties.filename,d.subindex)
    t[k]=v
    return v
  end)
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-cff']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type,tonumber=next,type,tonumber
local byte=string.byte
local concat,remove=table.concat,table.remove
local floor,abs,round,ceil=math.floor,math.abs,math.round,math.ceil
local P,C,R,S,C,Cs,Ct=lpeg.P,lpeg.C,lpeg.R,lpeg.S,lpeg.C,lpeg.Cs,lpeg.Ct
local lpegmatch=lpeg.match
local readers=fonts.handlers.otf.readers
local streamreader=readers.streamreader
local readbytes=streamreader.readbytes
local readstring=streamreader.readstring
local readbyte=streamreader.readcardinal1 
local readushort=streamreader.readcardinal2 
local readuint=streamreader.readcardinal3 
local readulong=streamreader.readcardinal4 
local setposition=streamreader.setposition
local getposition=streamreader.getposition
local setmetatableindex=table.setmetatableindex
local trace_charstrings=false trackers.register("fonts.cff.charstrings",function(v) trace_charstrings=v end)
local report=logs.reporter("otf reader","cff")
local parsedictionaries
local parsecharstring
local parsecharstrings
local resetcharstrings
local parseprivates
local defaultstrings={ [0]=
  ".notdef","space","exclam","quotedbl","numbersign","dollar","percent",
  "ampersand","quoteright","parenleft","parenright","asterisk","plus",
  "comma","hyphen","period","slash","zero","one","two","three","four",
  "five","six","seven","eight","nine","colon","semicolon","less",
  "equal","greater","question","at","A","B","C","D","E","F","G","H",
  "I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W",
  "X","Y","Z","bracketleft","backslash","bracketright","asciicircum",
  "underscore","quoteleft","a","b","c","d","e","f","g","h","i","j",
  "k","l","m","n","o","p","q","r","s","t","u","v","w","x","y",
  "z","braceleft","bar","braceright","asciitilde","exclamdown","cent",
  "sterling","fraction","yen","florin","section","currency",
  "quotesingle","quotedblleft","guillemotleft","guilsinglleft",
  "guilsinglright","fi","fl","endash","dagger","daggerdbl",
  "periodcentered","paragraph","bullet","quotesinglbase","quotedblbase",
  "quotedblright","guillemotright","ellipsis","perthousand","questiondown",
  "grave","acute","circumflex","tilde","macron","breve","dotaccent",
  "dieresis","ring","cedilla","hungarumlaut","ogonek","caron","emdash",
  "AE","ordfeminine","Lslash","Oslash","OE","ordmasculine","ae",
  "dotlessi","lslash","oslash","oe","germandbls","onesuperior",
  "logicalnot","mu","trademark","Eth","onehalf","plusminus","Thorn",
  "onequarter","divide","brokenbar","degree","thorn","threequarters",
  "twosuperior","registered","minus","eth","multiply","threesuperior",
  "copyright","Aacute","Acircumflex","Adieresis","Agrave","Aring",
  "Atilde","Ccedilla","Eacute","Ecircumflex","Edieresis","Egrave",
  "Iacute","Icircumflex","Idieresis","Igrave","Ntilde","Oacute",
  "Ocircumflex","Odieresis","Ograve","Otilde","Scaron","Uacute",
  "Ucircumflex","Udieresis","Ugrave","Yacute","Ydieresis","Zcaron",
  "aacute","acircumflex","adieresis","agrave","aring","atilde",
  "ccedilla","eacute","ecircumflex","edieresis","egrave","iacute",
  "icircumflex","idieresis","igrave","ntilde","oacute","ocircumflex",
  "odieresis","ograve","otilde","scaron","uacute","ucircumflex",
  "udieresis","ugrave","yacute","ydieresis","zcaron","exclamsmall",
  "Hungarumlautsmall","dollaroldstyle","dollarsuperior","ampersandsmall",
  "Acutesmall","parenleftsuperior","parenrightsuperior","twodotenleader",
  "onedotenleader","zerooldstyle","oneoldstyle","twooldstyle",
  "threeoldstyle","fouroldstyle","fiveoldstyle","sixoldstyle",
  "sevenoldstyle","eightoldstyle","nineoldstyle","commasuperior",
  "threequartersemdash","periodsuperior","questionsmall","asuperior",
  "bsuperior","centsuperior","dsuperior","esuperior","isuperior",
  "lsuperior","msuperior","nsuperior","osuperior","rsuperior","ssuperior",
  "tsuperior","ff","ffi","ffl","parenleftinferior","parenrightinferior",
  "Circumflexsmall","hyphensuperior","Gravesmall","Asmall","Bsmall",
  "Csmall","Dsmall","Esmall","Fsmall","Gsmall","Hsmall","Ismall",
  "Jsmall","Ksmall","Lsmall","Msmall","Nsmall","Osmall","Psmall",
  "Qsmall","Rsmall","Ssmall","Tsmall","Usmall","Vsmall","Wsmall",
  "Xsmall","Ysmall","Zsmall","colonmonetary","onefitted","rupiah",
  "Tildesmall","exclamdownsmall","centoldstyle","Lslashsmall",
  "Scaronsmall","Zcaronsmall","Dieresissmall","Brevesmall","Caronsmall",
  "Dotaccentsmall","Macronsmall","figuredash","hypheninferior",
  "Ogoneksmall","Ringsmall","Cedillasmall","questiondownsmall","oneeighth",
  "threeeighths","fiveeighths","seveneighths","onethird","twothirds",
  "zerosuperior","foursuperior","fivesuperior","sixsuperior",
  "sevensuperior","eightsuperior","ninesuperior","zeroinferior",
  "oneinferior","twoinferior","threeinferior","fourinferior",
  "fiveinferior","sixinferior","seveninferior","eightinferior",
  "nineinferior","centinferior","dollarinferior","periodinferior",
  "commainferior","Agravesmall","Aacutesmall","Acircumflexsmall",
  "Atildesmall","Adieresissmall","Aringsmall","AEsmall","Ccedillasmall",
  "Egravesmall","Eacutesmall","Ecircumflexsmall","Edieresissmall",
  "Igravesmall","Iacutesmall","Icircumflexsmall","Idieresissmall",
  "Ethsmall","Ntildesmall","Ogravesmall","Oacutesmall","Ocircumflexsmall",
  "Otildesmall","Odieresissmall","OEsmall","Oslashsmall","Ugravesmall",
  "Uacutesmall","Ucircumflexsmall","Udieresissmall","Yacutesmall",
  "Thornsmall","Ydieresissmall","001.000","001.001","001.002","001.003",
  "Black","Bold","Book","Light","Medium","Regular","Roman","Semibold",
}
local cffreaders={
  readbyte,
  readushort,
  readuint,
  readulong,
}
local function readheader(f)
  local offset=getposition(f)
  local header={
    offset=offset,
    major=readbyte(f),
    minor=readbyte(f),
    size=readbyte(f),
    osize=readbyte(f),
  }
  setposition(f,offset+header.size)
  return header
end
local function readlengths(f)
  local count=readushort(f)
  if count==0 then
    return {}
  end
  local osize=readbyte(f)
  local read=cffreaders[osize]
  if not read then
    report("bad offset size: %i",osize)
    return {}
  end
  local lengths={}
  local previous=read(f)
  for i=1,count do
    local offset=read(f)
    lengths[i]=offset-previous
    previous=offset
  end
  return lengths
end
local function readfontnames(f)
  local names=readlengths(f)
  for i=1,#names do
    names[i]=readstring(f,names[i])
  end
  return names
end
local function readtopdictionaries(f)
  local dictionaries=readlengths(f)
  for i=1,#dictionaries do
    dictionaries[i]=readstring(f,dictionaries[i])
  end
  return dictionaries
end
local function readstrings(f)
  local lengths=readlengths(f)
  local strings=setmetatableindex({},defaultstrings)
  local index=#defaultstrings
  for i=1,#lengths do
    index=index+1
    strings[index]=readstring(f,lengths[i])
  end
  return strings
end
do
  local stack={}
  local top=0
  local result={}
  local strings={}
  local p_single=P("\00")/function()
      result.version=strings[stack[top]] or "unset"
      top=0
    end+P("\01")/function()
      result.notice=strings[stack[top]] or "unset"
      top=0
    end+P("\02")/function()
      result.fullname=strings[stack[top]] or "unset"
      top=0
    end+P("\03")/function()
      result.familyname=strings[stack[top]] or "unset"
      top=0
    end+P("\04")/function()
      result.weight=strings[stack[top]] or "unset"
      top=0
    end+P("\05")/function()
      result.fontbbox={ unpack(stack,1,4) }
      top=0
    end
+P("\13")/function()
      result.uniqueid=stack[top]
      top=0
    end+P("\14")/function()
      result.xuid=concat(stack,"",1,top)
      top=0
    end+P("\15")/function()
      result.charset=stack[top]
      top=0
    end+P("\16")/function()
      result.encoding=stack[top]
      top=0
    end+P("\17")/function()
      result.charstrings=stack[top]
      top=0
    end+P("\18")/function()
      result.private={
        size=stack[top-1],
        offset=stack[top],
      }
      top=0
    end+P("\19")/function()
      result.subroutines=stack[top]
    end+P("\20")/function()
      result.defaultwidthx=stack[top]
    end+P("\21")/function()
      result.nominalwidthx=stack[top]
    end
  local p_double=P("\12")*(
    P("\00")/function()
      result.copyright=stack[top]
      top=0
    end+P("\01")/function()
      result.monospaced=stack[top]==1 and true or false 
      top=0
    end+P("\02")/function()
      result.italicangle=stack[top]
      top=0
    end+P("\03")/function()
      result.underlineposition=stack[top]
      top=0
    end+P("\04")/function()
      result.underlinethickness=stack[top]
      top=0
    end+P("\05")/function()
      result.painttype=stack[top]
      top=0
    end+P("\06")/function()
      result.charstringtype=stack[top]
      top=0
    end+P("\07")/function()
      result.fontmatrix={ unpack(stack,1,6) }
      top=0
    end+P("\08")/function()
      result.strokewidth=stack[top]
      top=0
    end+P("\20")/function()
      result.syntheticbase=stack[top]
      top=0
    end+P("\21")/function()
      result.postscript=strings[stack[top]] or "unset"
      top=0
    end+P("\22")/function()
      result.basefontname=strings[stack[top]] or "unset"
      top=0
    end+P("\21")/function()
      result.basefontblend=stack[top]
      top=0
    end+P("\30")/function()
      result.cid.registry=strings[stack[top-2]] or "unset"
      result.cid.ordering=strings[stack[top-1]] or "unset"
      result.cid.supplement=stack[top]
      top=0
    end+P("\31")/function()
      result.cid.fontversion=stack[top]
      top=0
    end+P("\32")/function()
      result.cid.fontrevision=stack[top]
      top=0
    end+P("\33")/function()
      result.cid.fonttype=stack[top]
      top=0
    end+P("\34")/function()
      result.cid.count=stack[top]
      top=0
    end+P("\35")/function()
      result.cid.uidbase=stack[top]
      top=0
    end+P("\36")/function()
      result.cid.fdarray=stack[top]
      top=0
    end+P("\37")/function()
      result.cid.fdselect=stack[top]
      top=0
    end+P("\38")/function()
      result.cid.fontname=strings[stack[top]] or "unset"
      top=0
    end
  )
  local p_last=P("\x0F")/"0"+P("\x1F")/"1"+P("\x2F")/"2"+P("\x3F")/"3"+P("\x4F")/"4"+P("\x5F")/"5"+P("\x6F")/"6"+P("\x7F")/"7"+P("\x8F")/"8"+P("\x9F")/"9"+P("\xAF")/""+P("\xBF")/""+P("\xCF")/""+P("\xDF")/""+P("\xEF")/""+R("\xF0\xFF")/""
  local remap={
    ["\x00"]="00",["\x01"]="01",["\x02"]="02",["\x03"]="03",["\x04"]="04",["\x05"]="05",["\x06"]="06",["\x07"]="07",["\x08"]="08",["\x09"]="09",["\x0A"]="0.",["\x0B"]="0E",["\x0C"]="0E-",["\x0D"]="0",["\x0E"]="0-",["\x0F"]="0",
    ["\x10"]="10",["\x11"]="11",["\x12"]="12",["\x13"]="13",["\x14"]="14",["\x15"]="15",["\x16"]="16",["\x17"]="17",["\x18"]="18",["\x19"]="19",["\x1A"]="0.",["\x1B"]="0E",["\x1C"]="0E-",["\x1D"]="0",["\x1E"]="0-",["\x1F"]="0",
    ["\x20"]="20",["\x21"]="21",["\x22"]="22",["\x23"]="23",["\x24"]="24",["\x25"]="25",["\x26"]="26",["\x27"]="27",["\x28"]="28",["\x29"]="29",["\x2A"]="0.",["\x2B"]="0E",["\x2C"]="0E-",["\x2D"]="0",["\x2E"]="0-",["\x2F"]="0",
    ["\x30"]="30",["\x31"]="31",["\x32"]="32",["\x33"]="33",["\x34"]="34",["\x35"]="35",["\x36"]="36",["\x37"]="37",["\x38"]="38",["\x39"]="39",["\x3A"]="0.",["\x3B"]="0E",["\x3C"]="0E-",["\x3D"]="0",["\x3E"]="0-",["\x3F"]="0",
    ["\x40"]="40",["\x41"]="41",["\x42"]="42",["\x43"]="43",["\x44"]="44",["\x45"]="45",["\x46"]="46",["\x47"]="47",["\x48"]="48",["\x49"]="49",["\x4A"]="0.",["\x4B"]="0E",["\x4C"]="0E-",["\x4D"]="0",["\x4E"]="0-",["\x4F"]="0",
    ["\x50"]="50",["\x51"]="51",["\x52"]="52",["\x53"]="53",["\x54"]="54",["\x55"]="55",["\x56"]="56",["\x57"]="57",["\x58"]="58",["\x59"]="59",["\x5A"]="0.",["\x5B"]="0E",["\x5C"]="0E-",["\x5D"]="0",["\x5E"]="0-",["\x5F"]="0",
    ["\x60"]="60",["\x61"]="61",["\x62"]="62",["\x63"]="63",["\x64"]="64",["\x65"]="65",["\x66"]="66",["\x67"]="67",["\x68"]="68",["\x69"]="69",["\x6A"]="0.",["\x6B"]="0E",["\x6C"]="0E-",["\x6D"]="0",["\x6E"]="0-",["\x6F"]="0",
    ["\x70"]="70",["\x71"]="71",["\x72"]="72",["\x73"]="73",["\x74"]="74",["\x75"]="75",["\x76"]="76",["\x77"]="77",["\x78"]="78",["\x79"]="79",["\x7A"]="0.",["\x7B"]="0E",["\x7C"]="0E-",["\x7D"]="0",["\x7E"]="0-",["\x7F"]="0",
    ["\x80"]="80",["\x81"]="81",["\x82"]="82",["\x83"]="83",["\x84"]="84",["\x85"]="85",["\x86"]="86",["\x87"]="87",["\x88"]="88",["\x89"]="89",["\x8A"]="0.",["\x8B"]="0E",["\x8C"]="0E-",["\x8D"]="0",["\x8E"]="0-",["\x8F"]="0",
    ["\x90"]="90",["\x91"]="91",["\x92"]="92",["\x93"]="93",["\x94"]="94",["\x95"]="95",["\x96"]="96",["\x97"]="97",["\x98"]="98",["\x99"]="99",["\x9A"]="0.",["\x9B"]="0E",["\x9C"]="0E-",["\x9D"]="0",["\x9E"]="0-",["\x9F"]="0",
    ["\xA0"]=".0",["\xA1"]=".1",["\xA2"]=".2",["\xA3"]=".3",["\xA4"]=".4",["\xA5"]=".5",["\xA6"]=".6",["\xA7"]=".7",["\xA8"]=".8",["\xA9"]=".9",["\xAA"]="..",["\xAB"]=".E",["\xAC"]=".E-",["\xAD"]=".",["\xAE"]=".-",["\xAF"]=".",
    ["\xB0"]="E0",["\xB1"]="E1",["\xB2"]="E2",["\xB3"]="E3",["\xB4"]="E4",["\xB5"]="E5",["\xB6"]="E6",["\xB7"]="E7",["\xB8"]="E8",["\xB9"]="E9",["\xBA"]="E.",["\xBB"]="EE",["\xBC"]="EE-",["\xBD"]="E",["\xBE"]="E-",["\xBF"]="E",
    ["\xC0"]="E-0",["\xC1"]="E-1",["\xC2"]="E-2",["\xC3"]="E-3",["\xC4"]="E-4",["\xC5"]="E-5",["\xC6"]="E-6",["\xC7"]="E-7",["\xC8"]="E-8",["\xC9"]="E-9",["\xCA"]="E-.",["\xCB"]="E-E",["\xCC"]="E-E-",["\xCD"]="E-",["\xCE"]="E--",["\xCF"]="E-",
    ["\xD0"]="-0",["\xD1"]="-1",["\xD2"]="-2",["\xD3"]="-3",["\xD4"]="-4",["\xD5"]="-5",["\xD6"]="-6",["\xD7"]="-7",["\xD8"]="-8",["\xD9"]="-9",["\xDA"]="-.",["\xDB"]="-E",["\xDC"]="-E-",["\xDD"]="-",["\xDE"]="--",["\xDF"]="-",
  }
  local p_nibbles=P("\30")*Cs(((1-p_last)/remap)^0+p_last)/function(n)
    top=top+1
    stack[top]=tonumber(n) or 0
  end
  local p_byte=C(R("\32\246"))/function(b0)
    top=top+1
    stack[top]=byte(b0)-139
  end
  local p_positive=C(R("\247\250"))*C(1)/function(b0,b1)
    top=top+1
    stack[top]=(byte(b0)-247)*256+byte(b1)+108
  end
  local p_negative=C(R("\251\254"))*C(1)/function(b0,b1)
    top=top+1
    stack[top]=-(byte(b0)-251)*256-byte(b1)-108
  end
  local p_short=P("\28")*C(1)*C(1)/function(b1,b2)
    top=top+1
    local n=0x100*byte(b1)+byte(b2)
    if n>=0x8000 then
      stack[top]=n-0xFFFF-1
    else
      stack[top]=n
    end
  end
  local p_long=P("\29")*C(1)*C(1)*C(1)*C(1)/function(b1,b2,b3,b4)
    top=top+1
    local n=0x1000000*byte(b1)+0x10000*byte(b2)+0x100*byte(b3)+byte(b4)
    if n>=0x8000000 then
      stack[top]=n-0xFFFFFFFF-1
    else
      stack[top]=n
    end
  end
  local p_unsupported=P(1)/function(detail)
    top=0
  end
  local p_dictionary=(
    p_byte+p_positive+p_negative+p_short+p_long+p_nibbles+p_single+p_double+p_unsupported
  )^1
  parsedictionaries=function(data,dictionaries)
    stack={}
    strings=data.strings
    for i=1,#dictionaries do
      top=0
      result={
        monospaced=false,
        italicangle=0,
        underlineposition=-100,
        underlinethickness=50,
        painttype=0,
        charstringtype=2,
        fontmatrix={ 0.001,0,0,0.001,0,0 },
        fontbbox={ 0,0,0,0 },
        strokewidth=0,
        charset=0,
        encoding=0,
        cid={
          fontversion=0,
          fontrevision=0,
          fonttype=0,
          count=8720,
        }
      }
      lpegmatch(p_dictionary,dictionaries[i])
      dictionaries[i]=result
    end
    result={}
    top=0
    stack={}
  end
  parseprivates=function(data,dictionaries)
    stack={}
    strings=data.strings
    for i=1,#dictionaries do
      local private=dictionaries[i].private
      if private and private.data then
        top=0
        result={
          forcebold=false,
          languagegroup=0,
          expansionfactor=0.06,
          initialrandomseed=0,
          subroutines=0,
          defaultwidthx=0,
          nominalwidthx=0,
          cid={
          },
        }
        lpegmatch(p_dictionary,private.data)
        private.data=result
      end
    end
    result={}
    top=0
    stack={}
  end
  local x=0
  local y=0
  local width=false
  local r=0
  local stems=0
  local globalbias=0
  local localbias=0
  local globals=false
  local locals=false
  local depth=1
  local xmin=0
  local xmax=0
  local ymin=0
  local ymax=0
  local checked=false
  local keepcurve=false
  local function showstate(where)
    report("%w%-10s : [%s] n=%i",depth*2,where,concat(stack," ",1,top),top)
  end
  local function showvalue(where,value,showstack)
    if showstack then
      report("%w%-10s : %s : [%s] n=%i",depth*2,where,tostring(value),concat(stack," ",1,top),top)
    else
      report("%w%-10s : %s",depth*2,where,tostring(value))
    end
  end
  local function moveto(x,y)
    if keepcurve then
      r=r+1
      result[r]={ x,y,"m" }
    end
    if checked then
      if x<xmin then xmin=x elseif x>xmax then xmax=x end
      if y<ymin then ymin=y elseif y>ymax then ymax=y end
    else
      xmin=x
      ymin=y
      xmax=x
      ymax=y
      checked=true
    end
  end
  local function lineto(x,y)
    if keepcurve then
      r=r+1
      result[r]={ x,y,"l" }
    end
    if checked then
      if x<xmin then xmin=x elseif x>xmax then xmax=x end
      if y<ymin then ymin=y elseif y>ymax then ymax=y end
    else
      xmin=x
      ymin=y
      xmax=x
      ymax=y
      checked=true
    end
  end
  local function curveto(x1,y1,x2,y2,x3,y3)
    if keepcurve then
      r=r+1
      result[r]={ x1,y1,x2,y2,x3,y3,"c" }
    end
    if checked then
      if x1<xmin then xmin=x1 elseif x1>xmax then xmax=x1 end
      if y1<ymin then ymin=y1 elseif y1>ymax then ymax=y1 end
    else
      xmin=x1
      ymin=y1
      xmax=x1
      ymax=y1
      checked=true
    end
    if x2<xmin then xmin=x2 elseif x2>xmax then xmax=x2 end
    if y2<ymin then ymin=y2 elseif y2>ymax then ymax=y2 end
    if x3<xmin then xmin=x3 elseif x3>xmax then xmax=x3 end
    if y3<ymin then ymin=y3 elseif y3>ymax then ymax=y3 end
  end
  local function rmoveto()
    if top>2 then
      if not width then
        width=stack[1]
        if trace_charstrings then
          showvalue("width",width)
        end
      end
    elseif not width then
      width=true
    end
    if trace_charstrings then
      showstate("rmoveto")
    end
    x=x+stack[top-1] 
    y=y+stack[top]  
    top=0
    moveto(x,y)
  end
  local function hmoveto()
    if top>1 then
      if not width then
        width=stack[1]
        if trace_charstrings then
          showvalue("width",width)
        end
      end
    elseif not width then
      width=true
    end
    if trace_charstrings then
      showstate("hmoveto")
    end
    x=x+stack[top] 
    top=0
    moveto(x,y)
  end
  local function vmoveto()
    if top>1 then
      if not width then
        width=stack[1]
        if trace_charstrings then
          showvalue("width",width)
        end
      end
    elseif not width then
      width=true
    end
    if trace_charstrings then
      showstate("vmoveto")
    end
    y=y+stack[top] 
    top=0
    moveto(x,y)
  end
  local function rlineto()
    if trace_charstrings then
      showstate("rlineto")
    end
    for i=1,top,2 do
      x=x+stack[i]  
      y=y+stack[i+1] 
      lineto(x,y)
    end
    top=0
  end
  local function xlineto(swap) 
    for i=1,top do
      if swap then
        x=x+stack[i]
        swap=false
      else
        y=y+stack[i]
        swap=true
      end
      lineto(x,y)
    end
    top=0
  end
  local function hlineto() 
    if trace_charstrings then
      showstate("hlineto")
    end
    xlineto(true)
  end
  local function vlineto() 
    if trace_charstrings then
      showstate("vlineto")
    end
    xlineto(false)
  end
  local function rrcurveto()
    if trace_charstrings then
      showstate("rrcurveto")
    end
    for i=1,top,6 do
      local ax=x+stack[i]  
      local ay=y+stack[i+1] 
      local bx=ax+stack[i+2] 
      local by=ay+stack[i+3] 
      x=bx+stack[i+4] 
      y=by+stack[i+5] 
      curveto(ax,ay,bx,by,x,y)
    end
    top=0
  end
  local function hhcurveto()
    if trace_charstrings then
      showstate("hhcurveto")
    end
    local s=1
    if top%2~=0 then
      y=y+stack[1] 
      s=2
    end
    for i=s,top,4 do
      local ax=x+stack[i] 
      local ay=y
      local bx=ax+stack[i+1] 
      local by=ay+stack[i+2] 
      x=bx+stack[i+3] 
      y=by
      curveto(ax,ay,bx,by,x,y)
    end
    top=0
  end
  local function vvcurveto()
    if trace_charstrings then
      showstate("vvcurveto")
    end
    local s=1
    local d=0
    if top%2~=0 then
      d=stack[1] 
      s=2
    end
    for i=s,top,4 do
      local ax=x+d
      local ay=y+stack[i] 
      local bx=ax+stack[i+1] 
      local by=ay+stack[i+2] 
      x=bx
      y=by+stack[i+3] 
      curveto(ax,ay,bx,by,x,y)
      d=0
    end
    top=0
  end
  local function xxcurveto(swap)
    local last=top%4~=0 and stack[top]
    if last then
      top=top-1
    end
    local sw=swap
    for i=1,top,4 do
      local ax,ay,bx,by
      if swap then
        ax=x+stack[i]
        ay=y
        bx=ax+stack[i+1]
        by=ay+stack[i+2]
        y=by+stack[i+3]
        if last and i+3==top then
          x=bx+last
        else
          x=bx
        end
        swap=false
      else
        ax=x
        ay=y+stack[i]
        bx=ax+stack[i+1]
        by=ay+stack[i+2]
        x=bx+stack[i+3]
        if last and i+3==top then
          y=by+last
        else
          y=by
        end
        swap=true
      end
      curveto(ax,ay,bx,by,x,y)
    end
    top=0
  end
  local function hvcurveto()
    if trace_charstrings then
      showstate("hvcurveto")
    end
    xxcurveto(true)
  end
  local function vhcurveto()
    if trace_charstrings then
      showstate("vhcurveto")
    end
    xxcurveto(false)
  end
  local function rcurveline()
    if trace_charstrings then
      showstate("rcurveline")
    end
    for i=1,top-2,6 do
      local ax=x+stack[i]  
      local ay=y+stack[i+1] 
      local bx=ax+stack[i+2] 
      local by=ay+stack[i+3] 
      x=bx+stack[i+4] 
      y=by+stack[i+5] 
      curveto(ax,ay,bx,by,x,y)
    end
    x=x+stack[top-1] 
    y=y+stack[top]  
    lineto(x,y)
    top=0
  end
  local function rlinecurve()
    if trace_charstrings then
      showstate("rlinecurve")
    end
    if top>6 then
      for i=1,top-6,2 do
        x=x+stack[i]
        y=y+stack[i+1]
        lineto(x,y)
      end
    end
    local ax=x+stack[top-5]
    local ay=y+stack[top-4]
    local bx=ax+stack[top-3]
    local by=ay+stack[top-2]
    x=bx+stack[top-1]
    y=by+stack[top]
    curveto(ax,ay,bx,by,x,y)
    top=0
  end
  local function flex() 
    if trace_charstrings then
      showstate("flex")
    end
    local ax=x+stack[1] 
    local ay=y+stack[2] 
    local bx=ax+stack[3] 
    local by=ay+stack[4] 
    local cx=bx+stack[5] 
    local cy=by+stack[6] 
    curveto(ax,ay,bx,by,cx,cy)
    local dx=cx+stack[7] 
    local dy=cy+stack[8] 
    local ex=dx+stack[9] 
    local ey=dy+stack[10] 
    x=ex+stack[11]    
    y=ey+stack[12]    
    curveto(dx,dy,ex,ey,x,y)
    top=0
  end
  local function hflex()
    if trace_charstrings then
      showstate("hflex")
    end
    local ax=x+stack[1]  
    local ay=y
    local bx=ax+stack[2] 
    local by=ay+stack[3] 
    local cx=bx+stack[4] 
    local cy=by
    curveto(ax,ay,bx,by,cx,cy)
    local dx=cx+stack[5] 
    local dy=by
    local ex=dx+stack[6] 
    local ey=y
    x=ex+stack[7]    
    curveto(dx,dy,ex,ey,x,y)
    top=0
  end
  local function hflex1()
    if trace_charstrings then
      showstate("hflex1")
    end
    local ax=x+stack[1] 
    local ay=y+stack[2] 
    local bx=ax+stack[3] 
    local by=ay+stack[4] 
    local cx=bx+stack[5] 
    local cy=by
    curveto(ax,ay,bx,by,cx,cy)
    local dx=cx+stack[6] 
    local dy=by
    local ex=dx+stack[7] 
    local ey=dy+stack[8] 
    x=ex+stack[9]    
    curveto(dx,dy,ex,ey,x,y)
    top=0
  end
  local function flex1()
    if trace_charstrings then
      showstate("flex1")
    end
    local ax=x+stack[1] 
    local ay=y+stack[2] 
    local bx=ax+stack[3] 
    local by=ay+stack[4] 
    local cx=bx+stack[5] 
    local cy=by+stack[6] 
    curveto(ax,ay,bx,by,cx,cy)
    local dx=cx+stack[7] 
    local dy=cy+stack[8] 
    local ex=dx+stack[9] 
    local ey=dy+stack[10] 
    if abs(ex-x)>abs(ey-y) then 
      x=ex+stack[11]
    else
      y=ey+stack[11]
    end
    curveto(dx,dy,ex,ey,x,y)
    top=0
  end
  local function getstem()
    if top==0 then
    elseif top%2~=0 then
      if width then
        remove(stack,1)
      else
        width=remove(stack,1)
        if trace_charstrings then
          showvalue("width",width)
        end
      end
      top=top-1
    end
    if trace_charstrings then
      showstate("stem")
    end
    stems=stems+top/2
    top=0
  end
  local function getmask()
    if top==0 then
    elseif top%2~=0 then
      if width then
        remove(stack,1)
      else
        width=remove(stack,1)
        if trace_charstrings then
          showvalue("width",width)
        end
      end
      top=top-1
    end
    if trace_charstrings then
      showstate(operator==19 and "hintmark" or "cntrmask")
    end
    stems=stems+top/2
    top=0
    if stems==0 then
    elseif stems<=8 then
      return 1
    else
      return floor((stems+7)/8)
    end
  end
  local function unsupported()
    if trace_charstrings then
      showstate("unsupported")
    end
    top=0
  end
  local actions={ [0]=unsupported,
    getstem,
    unsupported,
    getstem,
    vmoveto,
    rlineto,
    hlineto,
    vlineto,
    rrcurveto,
    unsupported,
    unsupported,
    unsupported,
    unsupported,
    unsupported,
    unsupported,
    unsupported,
    unsupported,
    unsupported,
    getstem,
    getmask,
    getmask,
    rmoveto,
    hmoveto,
    getstem,
    rcurveline,
    rlinecurve,
    vvcurveto,
    hhcurveto,
    unsupported,
    unsupported,
    vhcurveto,
    hvcurveto,
  }
  local subactions={
    [034]=hflex,
    [035]=flex,
    [036]=hflex1,
    [037]=flex1,
  }
  local p_bytes=Ct((P(1)/byte)^0)
  local function call(scope,list,bias,process)
    local index=stack[top]+bias
    top=top-1
    if trace_charstrings then
      showvalue(scope,index,true)
    end
    local str=list[index]
    if str then
      if type(str)=="string" then
        str=lpegmatch(p_bytes,str)
        list[index]=str
      end
      depth=depth+1
      process(str)
      depth=depth-1
    else
      report("unknown %s %i",scope,index)
    end
  end
  local function process(tab)
    local i=1
    local n=#tab
    while i<=n do
      local t=tab[i]
      if t>=32 and t<=246 then
        top=top+1
        stack[top]=t-139
        i=i+1
      elseif t>=247 and t<=250 then
        top=top+1
        stack[top]=(t-247)*256+tab[i+1]+108
        i=i+2
      elseif t>=251 and t<=254 then
        top=top+1
        stack[top]=-(t-251)*256-tab[i+1]-108
        i=i+2
      elseif t==28 then
        top=top+1
        local n=0x100*tab[i+1]+tab[i+2]
        if n>=0x8000 then
          stack[top]=n-0xFFFF-1
        else
          stack[top]=n
        end
        i=i+3
      elseif t==255 then
        local n=0x100*tab[i+1]+tab[i+2]
        top=top+1
        if n>=0x8000 then
          stack[top]=n-0xFFFF-1+(0x100*tab[i+3]+tab[i+4])/0xFFFF
        else
          stack[top]=n+(0x100*tab[i+3]+tab[i+4])/0xFFFF
        end
        i=i+5
      elseif t==11 then
        if trace_charstrings then
          showstate("return")
        end
        return
      elseif t==10 then
        call("local",locals,localbias,process)
        i=i+1
       elseif t==14 then 
        if width then
        elseif top>0 then
          width=stack[1]
          if trace_charstrings then
            showvalue("width",width)
          end
        else
          width=true
        end
        if trace_charstrings then
          showstate("endchar")
        end
        return
      elseif t==29 then
        call("global",globals,globalbias,process)
        i=i+1
      elseif t==12 then
        i=i+1
        local t=tab[i]
        local a=subactions[t]
        if a then
          a()
        else
          if trace_charstrings then
            showvalue("<subaction>",t)
          end
          top=0
        end
        i=i+1
      else
        local a=actions[t]
        if a then
          local s=a()
          if s then
            i=i+s
          end
        else
          if trace_charstrings then
            showvalue("<action>",t)
          end
          top=0
        end
        i=i+1
      end
    end
  end
  parsecharstrings=function(data,glyphs,doshapes)
    local dictionary=data.dictionaries[1]
    local charstrings=dictionary.charstrings
    local charset=dictionary.charset
    keepcurve=doshapes
    stack={}
    glyphs=glyphs or {}
    strings=data.strings
    locals=dictionary.subroutines
    globals=data.routines
    globalbias=#globals
    localbias=#locals
    globalbias=((globalbias<1240 and 107) or (globalbias<33900 and 1131) or 32768)+1
    localbias=((localbias<1240 and 107) or (localbias<33900 and 1131) or 32768)+1
    local nominalwidth=dictionary.private.data.nominalwidthx or 0
    local defaultwidth=dictionary.private.data.defaultwidthx or 0
    for i=1,#charstrings do
      local str=charstrings[i]
      local tab=lpegmatch(p_bytes,str)
      local index=i-1
      x=0
      y=0
      width=false
      r=0
      top=0
      stems=0
      result={}
      xmin=0
      xmax=0
      ymin=0
      ymax=0
      checked=false
      if trace_charstrings then
        report("glyph: %i",index)
        report("data: % t",tab)
      end
      process(tab)
      local boundingbox={ round(xmin),round(ymin),round(xmax),round(ymax) }
      if width==true or width==false then
        width=defaultwidth
      else
        width=nominalwidth+width
      end
      local glyph=glyphs[index] 
      if not glyph then
        glyphs[index]={
          segments=doshapes~=false and result or nil,
          boundingbox=boundingbox,
          width=width,
          name=charset[index],
        }
      else
        glyph.segments=doshapes~=false and result or nil
        glyph.boundingbox=boundingbox
        if not glyph.width then
          glyph.width=width
        end
        if charset and not glyph.name then
          glyph.name=charset[index]
        end
      end
      if trace_charstrings then
        report("width: %s",tostring(width))
        report("boundingbox: % t",boundingbox)
      end
      charstrings[i]=nil 
    end
    return glyphs
  end
  parsecharstring=function(data,dictionary,charstring,glyphs,index,doshapes)
    local private=dictionary.private
    keepcurve=doshapes
    strings=data.strings 
    locals=dictionary.subroutines or {}
    globals=data.routines or {}
    globalbias=#globals
    localbias=#locals
    globalbias=((globalbias<1240 and 107) or (globalbias<33900 and 1131) or 32768)+1
    localbias=((localbias<1240 and 107) or (localbias<33900 and 1131) or 32768)+1
    local nominalwidth=private and private.data.nominalwidthx or 0
    local defaultwidth=private and private.data.defaultwidthx or 0
    local tab=lpegmatch(p_bytes,charstring)
    x=0
    y=0
    width=false
    r=0
    top=0
    stems=0
    result={}
    xmin=0
    xmax=0
    ymin=0
    ymax=0
    checked=false
    if trace_charstrings then
      report("glyph: %i",index)
      report("data: % t",tab)
    end
    process(tab)
    local boundingbox={ xmin,ymin,xmax,ymax }
    if width==true or width==false then
      width=defaultwidth
    else
      width=nominalwidth+width
    end
index=index-1
    local glyph=glyphs[index] 
    if not glyph then
      glyphs[index]={
        segments=doshapes~=false and result or nil,
        boundingbox=boundingbox,
        width=width,
        name=charset[index],
      }
    else
      glyph.segments=doshapes~=false and result or nil
      glyph.boundingbox=boundingbox
      if not glyph.width then
        glyph.width=width
      end
      if charset and not glyph.name then
        glyph.name=charset[index]
      end
    end
    if trace_charstrings then
      report("width: %s",tostring(width))
      report("boundingbox: % t",boundingbox)
    end
    return charstring
  end
  resetcharstrings=function()
    result={}
    top=0
    stack={}
  end
end
local function readglobals(f,data)
  local routines=readlengths(f)
  for i=1,#routines do
    routines[i]=readstring(f,routines[i])
  end
  data.routines=routines
end
local function readencodings(f,data)
  data.encodings={}
end
local function readcharsets(f,data,dictionary)
  local header=data.header
  local strings=data.strings
  local nofglyphs=data.nofglyphs
  local charsetoffset=dictionary.charset
  if charsetoffset~=0 then
    setposition(f,header.offset+charsetoffset)
    local format=readbyte(f)
    local charset={ [0]=".notdef" }
    dictionary.charset=charset
    if format==0 then
      for i=1,nofglyphs do
        charset[i]=strings[readushort(f)]
      end
    elseif format==1 or format==2 then
      local readcount=format==1 and readbyte or readushort
      local i=1
      while i<=nofglyphs do
        local sid=readushort(f)
        local n=readcount(f)
        for s=sid,sid+n do
          charset[i]=strings[s]
          i=i+1
          if i>nofglyphs then
            break
          end
        end
      end
    else
      report("cff parser: unsupported charset format %a",format)
    end
  end
end
local function readprivates(f,data)
  local header=data.header
  local dictionaries=data.dictionaries
  local private=dictionaries[1].private
  if private then
    setposition(f,header.offset+private.offset)
    private.data=readstring(f,private.size)
  end
end
local function readlocals(f,data,dictionary)
  local header=data.header
  local private=dictionary.private
  if private then
    local subroutineoffset=private.data.subroutines
    if subroutineoffset~=0 then
      setposition(f,header.offset+private.offset+subroutineoffset)
      local subroutines=readlengths(f)
      for i=1,#subroutines do
        subroutines[i]=readstring(f,subroutines[i])
      end
      dictionary.subroutines=subroutines
      private.data.subroutines=nil
    else
      dictionary.subroutines={}
    end
  else
    dictionary.subroutines={}
  end
end
local function readcharstrings(f,data)
  local header=data.header
  local dictionaries=data.dictionaries
  local dictionary=dictionaries[1]
  local type=dictionary.charstringtype
  local offset=dictionary.charstrings
  if type==2 then
    setposition(f,header.offset+offset)
    local charstrings=readlengths(f)
    local nofglyphs=#charstrings
    for i=1,nofglyphs do
      charstrings[i]=readstring(f,charstrings[i])
    end
    data.nofglyphs=nofglyphs
    dictionary.charstrings=charstrings
  else
    report("unsupported charstr type %i",type)
    data.nofglyphs=0
    dictionary.charstrings={}
  end
end
local function readcidprivates(f,data)
  local header=data.header
  local dictionaries=data.dictionaries[1].cid.dictionaries
  for i=1,#dictionaries do
    local dictionary=dictionaries[i]
    local private=dictionary.private
    if private then
      setposition(f,header.offset+private.offset)
      private.data=readstring(f,private.size)
    end
  end
  parseprivates(data,dictionaries)
end
local function readnoselect(f,data,glyphs,doshapes)
  local dictionaries=data.dictionaries
  local dictionary=dictionaries[1]
  readglobals(f,data)
  readcharstrings(f,data)
  readencodings(f,data)
  readcharsets(f,data,dictionary)
  readprivates(f,data)
  parseprivates(data,data.dictionaries)
  readlocals(f,data,dictionary)
  parsecharstrings(data,glyphs,doshapes)
  resetcharstrings()
end
local function readfdselect(f,data,glyphs,doshapes)
  local header=data.header
  local dictionaries=data.dictionaries
  local dictionary=dictionaries[1]
  local cid=dictionary.cid
  local cidselect=cid and cid.fdselect
  readglobals(f,data)
  readcharstrings(f,data)
  readencodings(f,data)
  local charstrings=dictionary.charstrings
  local fdindex={}
  local nofglyphs=data.nofglyphs
  local maxindex=-1
  setposition(f,header.offset+cidselect)
  local format=readbyte(f)
  if format==1 then
    for i=0,nofglyphs do 
      local index=readbyte(i)
      fdindex[i]=index
      if index>maxindex then
        maxindex=index
      end
    end
  elseif format==3 then
    local nofranges=readushort(f)
    local first=readushort(f)
    local index=readbyte(f)
    while true do
      local last=readushort(f)
      if index>maxindex then
        maxindex=index
      end
      for i=first,last do
        fdindex[i]=index
      end
      if last>=nofglyphs then
        break
      else
        first=last+1
        index=readbyte(f)
      end
    end
  else
  end
  if maxindex>=0 then
    local cidarray=cid.fdarray
    setposition(f,header.offset+cidarray)
    local dictionaries=readlengths(f)
    for i=1,#dictionaries do
      dictionaries[i]=readstring(f,dictionaries[i])
    end
    parsedictionaries(data,dictionaries)
    cid.dictionaries=dictionaries
    readcidprivates(f,data)
    for i=1,#dictionaries do
      readlocals(f,data,dictionaries[i])
    end
    for i=1,#charstrings do
      parsecharstring(data,dictionaries[fdindex[i]+1],charstrings[i],glyphs,i,doshapes)
    end
    resetcharstrings()
  end
end
function readers.cff(f,fontdata,specification)
  if specification.details then
    local datatable=fontdata.tables.cff
    if datatable then
      local offset=datatable.offset
      local glyphs=fontdata.glyphs
      if not f then
        report("invalid filehandle")
        return
      end
      if offset then
        setposition(f,offset)
      end
      local header=readheader(f)
      if header.major>1 then
        report("version mismatch")
        return
      end
      local names=readfontnames(f)
      local dictionaries=readtopdictionaries(f)
      local strings=readstrings(f)
      local data={
        header=header,
        names=names,
        dictionaries=dictionaries,
        strings=strings,
        nofglyphs=fontdata.nofglyphs,
      }
      parsedictionaries(data,data.dictionaries)
      local d=dictionaries[1]
      local c=d.cid
      fontdata.cffinfo={
        familynamename=d.familyname,
        fullname=d.fullname,
        boundingbox=d.boundingbox,
        weight=d.weight,
        italicangle=d.italicangle,
        underlineposition=d.underlineposition,
        underlinethickness=d.underlinethickness,
        monospaced=d.monospaced,
      }
      fontdata.cidinfo=c and {
        registry=c.registry,
        ordering=c.ordering,
        supplement=c.supplement,
      }
      if not specification.glyphs then
      else
        local cid=d.cid
        if cid and cid.fdselect then
          readfdselect(f,data,glyphs,specification.shapes or false)
        else
          readnoselect(f,data,glyphs,specification.shapes or false)
        end
      end
    end
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-ttf']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type,unpack=next,type,unpack
local bittest=bit32.btest
local sqrt=math.sqrt
local report=logs.reporter("otf reader","ttf")
local readers=fonts.handlers.otf.readers
local streamreader=readers.streamreader
local setposition=streamreader.setposition
local getposition=streamreader.getposition
local skipbytes=streamreader.skip
local readbyte=streamreader.readcardinal1 
local readushort=streamreader.readcardinal2 
local readulong=streamreader.readcardinal4 
local readchar=streamreader.readinteger1  
local readshort=streamreader.readinteger2  
local read2dot14=streamreader.read2dot14   
local function mergecomposites(glyphs,shapes)
  local function merge(index,shape,components)
    local contours={}
    local nofcontours=0
    for i=1,#components do
      local component=components[i]
      local subindex=component.index
      local subshape=shapes[subindex]
      local subcontours=subshape.contours
      if not subcontours then
        local subcomponents=subshape.components
        if subcomponents then
          subcontours=merge(subindex,subshape,subcomponents)
        end
      end
      if subcontours then
        local matrix=component.matrix
        local xscale=matrix[1]
        local xrotate=matrix[2]
        local yrotate=matrix[3]
        local yscale=matrix[4]
        local xoffset=matrix[5]
        local yoffset=matrix[6]
        for i=1,#subcontours do
          local points=subcontours[i]
          local result={}
          for i=1,#points do
            local p=points[i]
            local x=p[1]
            local y=p[2]
            result[i]={
              xscale*x+xrotate*y+xoffset,
              yscale*y+yrotate*x+yoffset,
              p[3]
            }
          end
          nofcontours=nofcontours+1
          contours[nofcontours]=result
        end
      else
        report("missing contours composite %s, component %s of %s, glyph %s",index,i,#components,subindex)
      end
    end
    shape.contours=contours
    shape.components=nil
    return contours
  end
  for index=1,#glyphs do
    local shape=shapes[index]
    local components=shape.components
    if components then
      merge(index,shape,components)
    end
  end
end
local function readnothing(f,nofcontours)
  return {
    type="nothing",
  }
end
local function curveto(m_x,m_y,l_x,l_y,r_x,r_y) 
  return {
    l_x+2/3*(m_x-l_x),l_y+2/3*(m_y-l_y),
    r_x+2/3*(m_x-r_x),r_y+2/3*(m_y-r_y),
    r_x,r_y,"c" 
  }
end
local function contours2outlines(glyphs,shapes)
  local quadratic=true
  for index=1,#glyphs do
    local glyph=glyphs[index]
    local shape=shapes[index]
    local contours=shape.contours
    if contours then
      local nofcontours=#contours
      local segments={}
      local nofsegments=0
      glyph.segments=segments
      if nofcontours>0 then
        for i=1,nofcontours do
          local contour=contours[i]
          local nofcontour=#contour
          if nofcontour>0 then
            local first_pt=contour[1]
            local first_on=first_pt[3]
            if nofcontour==1 then
              first_pt[3]="m" 
              nofsegments=nofsegments+1
              segments[nofsegments]=first_pt
            else 
              local first_on=first_pt[3]
              local last_pt=contour[nofcontour]
              local last_on=last_pt[3]
              local start=1
              local control_pt=false
              if first_on then
                start=2
              else
                if last_on then
                  first_pt=last_pt
                else
                  first_pt={ (first_pt[1]+last_pt[1])/2,(first_pt[2]+last_pt[2])/2,false }
                end
                control_pt=first_pt
              end
              nofsegments=nofsegments+1
              segments[nofsegments]={ first_pt[1],first_pt[2],"m" } 
              local previous_pt=first_pt
              for i=start,nofcontour do
                local current_pt=contour[i]
                local current_on=current_pt[3]
                local previous_on=previous_pt[3]
                if previous_on then
                  if current_on then
                    nofsegments=nofsegments+1
                    segments[nofsegments]={ current_pt[1],current_pt[2],"l" } 
                  else
                    control_pt=current_pt
                  end
                elseif current_on then
                  local ps=segments[nofsegments]
                  nofsegments=nofsegments+1
                  if quadratic then
                    segments[nofsegments]={ control_pt[1],control_pt[2],current_pt[1],current_pt[2],"q" } 
                  else
                    local p=segments[nofsegments-1] local n=#p
                    segments[nofsegments]=curveto(control_pt[1],control_pt[2],p[n-2],p[n-1],current_pt[1],current_pt[2])
                  end
                  control_pt=false
                else
                  nofsegments=nofsegments+1
                  local halfway_x=(previous_pt[1]+current_pt[1])/2
                  local halfway_y=(previous_pt[2]+current_pt[2])/2
                  if quadratic then
                    segments[nofsegments]={ control_pt[1],control_pt[2],halfway_x,halfway_y,"q" } 
                  else
                    local p=segments[nofsegments-1] local n=#p
                    segments[nofsegments]=curveto(control_pt[1],control_pt[2],p[n-2],p[n-1],halfway_x,halfway_y)
                  end
                  control_pt=current_pt
                end
                previous_pt=current_pt
              end
              if first_pt==last_pt then
              else
                nofsegments=nofsegments+1
                if not control_pt then
                  segments[nofsegments]={ first_pt[1],first_pt[2],"l" } 
                elseif quadratic then
                  segments[nofsegments]={ control_pt[1],control_pt[2],first_pt[1],first_pt[2],"q" } 
                else
                  local p=last_pt local n=#p
                  segments[nofsegments]=curveto(control_pt[1],control_pt[2],p[n-2],p[n-1],first_pt[1],first_pt[2])
                end
              end
            end
          end
        end
      end
    end
  end
end
local function readglyph(f,nofcontours)
  local points={}
  local endpoints={}
  local instructions={}
  local flags={}
  for i=1,nofcontours do
    endpoints[i]=readshort(f)+1
  end
  local nofpoints=endpoints[nofcontours]
  local nofinstructions=readushort(f)
  skipbytes(f,nofinstructions)
  local i=1
  while i<=nofpoints do
    local flag=readbyte(f)
    flags[i]=flag
    if bittest(flag,0x0008) then
      for j=1,readbyte(f) do
        i=i+1
        flags[i]=flag
      end
    end
    i=i+1
  end
  local x=0
  for i=1,nofpoints do
    local flag=flags[i]
    local short=bittest(flag,0x0002)
    local same=bittest(flag,0x0010)
    if short then
      if same then
        x=x+readbyte(f)
      else
        x=x-readbyte(f)
      end
    elseif same then
    else
      x=x+readshort(f)
    end
    points[i]={ x,y,bittest(flag,0x0001) }
  end
  local y=0
  for i=1,nofpoints do
    local flag=flags[i]
    local short=bittest(flag,0x0004)
    local same=bittest(flag,0x0020)
    if short then
      if same then
        y=y+readbyte(f)
      else
        y=y-readbyte(f)
      end
    elseif same then
    else
      y=y+readshort(f)
    end
    points[i][2]=y
  end
  local first=1
  for i=1,#endpoints do
    local last=endpoints[i]
    endpoints[i]={ unpack(points,first,last) }
    first=last+1
  end
  return {
    type="glyph",
    contours=endpoints,
  }
end
local function readcomposite(f)
  local components={}
  local nofcomponents=0
  local instructions=false
  while true do
    local flags=readushort(f)
    local index=readushort(f)
    local f_xyarg=bittest(flags,0x0002)
    local f_offset=bittest(flags,0x0800)
    local xscale=1
    local xrotate=0
    local yrotate=0
    local yscale=1
    local xoffset=0
    local yoffset=0
    local base=false
    local reference=false
    if f_xyarg then
      if bittest(flags,0x0001) then 
        xoffset=readshort(f)
        yoffset=readshort(f)
      else
        xoffset=readchar(f) 
        yoffset=readchar(f) 
      end
    else
      if bittest(flags,0x0001) then 
        base=readshort(f)
        reference=readshort(f)
      else
        base=readchar(f) 
        reference=readchar(f) 
      end
    end
    if bittest(flags,0x0008) then 
      xscale=read2dot14(f)
      yscale=xscale
      if f_xyarg and f_offset then
        xoffset=xoffset*xscale
        yoffset=yoffset*yscale
      end
    elseif bittest(flags,0x0040) then 
      xscale=read2dot14(f)
      yscale=read2dot14(f)
      if f_xyarg and f_offset then
        xoffset=xoffset*xscale
        yoffset=yoffset*yscale
      end
    elseif bittest(flags,0x0080) then 
      xscale=read2dot14(f)
      xrotate=read2dot14(f)
      yrotate=read2dot14(f)
      yscale=read2dot14(f)
      if f_xyarg and f_offset then
        xoffset=xoffset*sqrt(xscale^2+xrotate^2)
        yoffset=yoffset*sqrt(yrotate^2+yscale^2)
      end
    end
    nofcomponents=nofcomponents+1
    components[nofcomponents]={
      index=index,
      usemine=bittest(flags,0x0200),
      round=bittest(flags,0x0006),
      base=base,
      reference=reference,
      matrix={ xscale,xrotate,yrotate,yscale,xoffset,yoffset },
    }
    if bittest(flags,0x0100) then
      instructions=true
    end
    if not bittest(flags,0x0020) then 
      break
    end
  end
  return {
    type="composite",
    components=components,
  }
end
function readers.loca(f,fontdata,specification)
  if specification.glyphs then
    local datatable=fontdata.tables.loca
    if datatable then
      local offset=fontdata.tables.glyf.offset
      local format=fontdata.fontheader.indextolocformat
      local locations={}
      setposition(f,datatable.offset)
      if format==1 then
        local nofglyphs=datatable.length/4-1
      -1
        for i=0,nofglyphs do
          locations[i]=offset+readulong(f)
        end
        fontdata.nofglyphs=nofglyphs
      else
        local nofglyphs=datatable.length/2-1
      -1
        for i=0,nofglyphs do
          locations[i]=offset+readushort(f)*2
        end
        fontdata.nofglyphs=nofglyphs
      end
      fontdata.locations=locations
    end
  end
end
function readers.glyf(f,fontdata,specification) 
  if specification.glyphs then
    local datatable=fontdata.tables.glyf
    if datatable then
      local locations=fontdata.locations
      if locations then
        local glyphs=fontdata.glyphs
        local nofglyphs=fontdata.nofglyphs
        local filesize=fontdata.filesize
        local nothing={ 0,0,0,0 }
        local shapes={}
        local loadshapes=specification.shapes
        for index=0,nofglyphs do
          local location=locations[index]
          if location>=filesize then
            report("discarding %s glyphs due to glyph location bug",nofglyphs-index+1)
            fontdata.nofglyphs=index-1
            fontdata.badfont=true
            break
          elseif location>0 then
            setposition(f,location)
            local nofcontours=readshort(f)
            glyphs[index].boundingbox={
              readshort(f),
              readshort(f),
              readshort(f),
              readshort(f),
            }
            if not loadshapes then
            elseif nofcontours==0 then
              shapes[index]=readnothing(f,nofcontours)
            elseif nofcontours>0 then
              shapes[index]=readglyph(f,nofcontours)
            else
              shapes[index]=readcomposite(f,nofcontours)
            end
          else
            if loadshapes then
              shapes[index]={}
            end
            glyphs[index].boundingbox=nothing
          end
        end
        if loadshapes then
          mergecomposites(glyphs,shapes)
          contours2outlines(glyphs,shapes)
        end
      end
    end
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-dsp']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type=next,type
local bittest=bit32.btest
local rshift=bit32.rshift
local concat=table.concat
local lower=string.lower
local sub=string.sub
local strip=string.strip
local tohash=table.tohash
local reversed=table.reversed
local setmetatableindex=table.setmetatableindex
local formatters=string.formatters
local sortedkeys=table.sortedkeys
local sortedhash=table.sortedhash
local report=logs.reporter("otf reader")
local readers=fonts.handlers.otf.readers
local streamreader=readers.streamreader
local setposition=streamreader.setposition
local skipshort=streamreader.skipshort
local readushort=streamreader.readcardinal2 
local readulong=streamreader.readcardinal4 
local readshort=streamreader.readinteger2  
local readfword=readshort
local readstring=streamreader.readstring
local readtag=streamreader.readtag
local readbytes=streamreader.readbytes
local gsubhandlers={}
local gposhandlers={}
local lookupidoffset=-1  
local classes={
  "base",
  "ligature",
  "mark",
  "component",
}
local gsubtypes={
  "single",
  "multiple",
  "alternate",
  "ligature",
  "context",
  "chainedcontext",
  "extension",
  "reversechainedcontextsingle",
}
local gpostypes={
  "single",
  "pair",
  "cursive",
  "marktobase",
  "marktoligature",
  "marktomark",
  "context",
  "chainedcontext",
  "extension",
}
local chaindirections={
  context=0,
  chainedcontext=1,
  reversechainedcontextsingle=-1,
}
local lookupnames={
  gsub={
    single="gsub_single",
    multiple="gsub_multiple",
    alternate="gsub_alternate",
    ligature="gsub_ligature",
    context="gsub_context",
    chainedcontext="gsub_contextchain",
    reversechainedcontextsingle="gsub_reversecontextchain",
  },
  gpos={
    single="gpos_single",
    pair="gpos_pair",
    cursive="gpos_cursive",
    marktobase="gpos_mark2base",
    marktoligature="gpos_mark2ligature",
    marktomark="gpos_mark2mark",
    context="gpos_context",
    chainedcontext="gpos_contextchain",
  }
}
local lookupflags=setmetatableindex(function(t,k)
  local v={
    bittest(k,0x0008) and true or false,
    bittest(k,0x0004) and true or false,
    bittest(k,0x0002) and true or false,
    bittest(k,0x0001) and true or false,
  }
  t[k]=v
  return v
end)
local function readcoverage(f,offset,simple)
  setposition(f,offset)
  local coverageformat=readushort(f)
  local coverage={}
  if coverageformat==1 then
    local nofcoverage=readushort(f)
    if simple then
      for i=1,nofcoverage do
        coverage[i]=readushort(f)
      end
    else
      for i=0,nofcoverage-1 do
        coverage[readushort(f)]=i 
      end
    end
  elseif coverageformat==2 then
    local nofranges=readushort(f)
    local n=simple and 1 or 0 
    for i=1,nofranges do
      local firstindex=readushort(f)
      local lastindex=readushort(f)
      local coverindex=readushort(f)
      if simple then
        for i=firstindex,lastindex do
          coverage[n]=i
          n=n+1
        end
      else
        for i=firstindex,lastindex do
          coverage[i]=n
          n=n+1
        end
      end
    end
  else
    report("unknown coverage format %a ",coverageformat)
  end
  return coverage
end
local function readclassdef(f,offset,preset)
  setposition(f,offset)
  local classdefformat=readushort(f)
  local classdef={}
  if type(preset)=="number" then
    for k=0,preset-1 do
      classdef[k]=1
    end
  end
  if classdefformat==1 then
    local index=readushort(f)
    local nofclassdef=readushort(f)
    for i=1,nofclassdef do
      classdef[index]=readushort(f)+1
      index=index+1
    end
  elseif classdefformat==2 then
    local nofranges=readushort(f)
    local n=0
    for i=1,nofranges do
      local firstindex=readushort(f)
      local lastindex=readushort(f)
      local class=readushort(f)+1
      for i=firstindex,lastindex do
        classdef[i]=class
      end
    end
  else
    report("unknown classdef format %a ",classdefformat)
  end
  if type(preset)=="table" then
    for k in next,preset do
      if not classdef[k] then
        classdef[k]=1
      end
    end
  end
  return classdef
end
local function classtocoverage(defs)
  if defs then
    local list={}
    for index,class in next,defs do
      local c=list[class]
      if c then
        c[#c+1]=index
      else
        list[class]={ index }
      end
    end
    return list
  end
end
local function readposition(f,format)
  if format==0 then
    return nil
  end
  local x=bittest(format,0x0001) and readshort(f) or 0 
  local y=bittest(format,0x0002) and readshort(f) or 0 
  local h=bittest(format,0x0004) and readshort(f) or 0 
  local v=bittest(format,0x0008) and readshort(f) or 0 
  if x==0 and y==0 and h==0 and v==0 then
    return nil
  else
    return { x,y,h,v }
  end
end
local function readanchor(f,offset)
  if not offset or offset==0 then
    return nil 
  end
  setposition(f,offset)
  local format=readshort(f)
  if format==0 then
    report("invalid anchor format %i @ position %i",format,offset)
    return false
  elseif format>3 then
    report("unsupported anchor format %i @ position %i",format,offset)
    return false
  end
  return { readshort(f),readshort(f) }
end
local function readfirst(f,offset)
  if offset then
    setposition(f,offset)
  end
  return { readushort(f) }
end
local function readarray(f,offset,first)
  if offset then
    setposition(f,offset)
  end
  local n=readushort(f)
  if first then
    local t={ first }
    for i=2,n do
      t[i]=readushort(f)
    end
    return t,n
  elseif n>0 then
    local t={}
    for i=1,n do
      t[i]=readushort(f)
    end
    return t,n
  end
end
local function readcoveragearray(f,offset,t,simple)
  if not t then
    return nil
  end
  local n=#t
  if n==0 then
    return nil
  end
  for i=1,n do
    t[i]=readcoverage(f,offset+t[i],simple)
  end
  return t
end
local function covered(subset,all)
  local used,u
  for i=1,#subset do
    local s=subset[i]
    if all[s] then
      if used then
        u=u+1
        used[u]=s
      else
        u=1
        used={ s }
      end
    end
  end
  return used
end
local function readlookuparray(f,noflookups,nofcurrent)
  local lookups={}
  if noflookups>0 then
    local length=0
    for i=1,noflookups do
      local index=readushort(f)+1
      if index>length then
        length=index
      end
      lookups[index]=readushort(f)+1
    end
    for index=1,length do
      if not lookups[index] then
        lookups[index]=false
      end
    end
  end
  return lookups
end
local function unchainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,what)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local subclasssets=readarray(f)
    local rules={}
    if subclasssets then
      coverage=readcoverage(f,tableoffset+coverage,true)
      for i=1,#subclasssets do
        local offset=subclasssets[i]
        if offset>0 then
          local firstcoverage=coverage[i]
          local rulesoffset=tableoffset+offset
          local subclassrules=readarray(f,rulesoffset)
          for rule=1,#subclassrules do
            setposition(f,rulesoffset+subclassrules[rule])
            local nofcurrent=readushort(f)
            local noflookups=readushort(f)
            local current={ { firstcoverage } }
            for i=2,nofcurrent do
              current[i]={ readushort(f) }
            end
            local lookups=readlookuparray(f,noflookups,nofcurrent)
            rules[#rules+1]={
              current=current,
              lookups=lookups
            }
          end
        end
      end
    else
      report("empty subclassset in %a subtype %i","unchainedcontext",subtype)
    end
    return {
      format="glyphs",
      rules=rules,
    }
  elseif subtype==2 then
    local coverage=readushort(f)
    local currentclassdef=readushort(f)
    local subclasssets=readarray(f)
    local rules={}
    if subclasssets then
      coverage=readcoverage(f,tableoffset+coverage)
      currentclassdef=readclassdef(f,tableoffset+currentclassdef,coverage)
      local currentclasses=classtocoverage(currentclassdef,fontdata.glyphs)
      for class=1,#subclasssets do
        local offset=subclasssets[class]
        if offset>0 then
          local firstcoverage=currentclasses[class]
          if firstcoverage then
            firstcoverage=covered(firstcoverage,coverage) 
            if firstcoverage then
              local rulesoffset=tableoffset+offset
              local subclassrules=readarray(f,rulesoffset)
              for rule=1,#subclassrules do
                setposition(f,rulesoffset+subclassrules[rule])
                local nofcurrent=readushort(f)
                local noflookups=readushort(f)
                local current={ firstcoverage }
                for i=2,nofcurrent do
                  current[i]=currentclasses[readushort(f)+1]
                end
                local lookups=readlookuparray(f,noflookups,nofcurrent)
                rules[#rules+1]={
                  current=current,
                  lookups=lookups
                }
              end
            else
              report("no coverage")
            end
          else
            report("no coverage class")
          end
        end
      end
    else
      report("empty subclassset in %a subtype %i","unchainedcontext",subtype)
    end
    return {
      format="class",
      rules=rules,
    }
  elseif subtype==3 then
    local current=readarray(f)
    local noflookups=readushort(f)
    local lookups=readlookuparray(f,noflookups,#current)
    current=readcoveragearray(f,tableoffset,current,true)
    return {
      format="coverage",
      rules={
        {
          current=current,
          lookups=lookups,
        }
      }
    }
  else
    report("unsupported subtype %a in %a %s",subtype,"unchainedcontext",what)
  end
end
local function chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,what)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local subclasssets=readarray(f)
    local rules={}
    if subclasssets then
      coverage=readcoverage(f,tableoffset+coverage,true)
      for i=1,#subclasssets do
        local offset=subclasssets[i]
        if offset>0 then
          local firstcoverage=coverage[i]
          local rulesoffset=tableoffset+offset
          local subclassrules=readarray(f,rulesoffset)
          for rule=1,#subclassrules do
            setposition(f,rulesoffset+subclassrules[rule])
            local nofbefore=readushort(f)
            local before
            if nofbefore>0 then
              before={}
              for i=1,nofbefore do
                before[i]={ readushort(f) }
              end
            end
            local nofcurrent=readushort(f)
            local current={ { firstcoverage } }
            for i=2,nofcurrent do
              current[i]={ readushort(f) }
            end
            local nofafter=readushort(f)
            local after
            if nofafter>0 then
              after={}
              for i=1,nofafter do
                after[i]={ readushort(f) }
              end
            end
            local noflookups=readushort(f)
            local lookups=readlookuparray(f,noflookups,nofcurrent)
            rules[#rules+1]={
              before=before,
              current=current,
              after=after,
              lookups=lookups,
            }
          end
        end
      end
    else
      report("empty subclassset in %a subtype %i","chainedcontext",subtype)
    end
    return {
      format="glyphs",
      rules=rules,
    }
  elseif subtype==2 then
    local coverage=readushort(f)
    local beforeclassdef=readushort(f)
    local currentclassdef=readushort(f)
    local afterclassdef=readushort(f)
    local subclasssets=readarray(f)
    local rules={}
    if subclasssets then
      local coverage=readcoverage(f,tableoffset+coverage)
      local beforeclassdef=readclassdef(f,tableoffset+beforeclassdef,nofglyphs)
      local currentclassdef=readclassdef(f,tableoffset+currentclassdef,coverage)
      local afterclassdef=readclassdef(f,tableoffset+afterclassdef,nofglyphs)
      local beforeclasses=classtocoverage(beforeclassdef,fontdata.glyphs)
      local currentclasses=classtocoverage(currentclassdef,fontdata.glyphs)
      local afterclasses=classtocoverage(afterclassdef,fontdata.glyphs)
      for class=1,#subclasssets do
        local offset=subclasssets[class]
        if offset>0 then
          local firstcoverage=currentclasses[class]
          if firstcoverage then
            firstcoverage=covered(firstcoverage,coverage) 
            if firstcoverage then
              local rulesoffset=tableoffset+offset
              local subclassrules=readarray(f,rulesoffset)
              for rule=1,#subclassrules do
                setposition(f,rulesoffset+subclassrules[rule])
                local nofbefore=readushort(f)
                local before
                if nofbefore>0 then
                  before={}
                  for i=1,nofbefore do
                    before[i]=beforeclasses[readushort(f)+1]
                  end
                end
                local nofcurrent=readushort(f)
                local current={ firstcoverage }
                for i=2,nofcurrent do
                  current[i]=currentclasses[readushort(f)+1]
                end
                local nofafter=readushort(f)
                local after
                if nofafter>0 then
                  after={}
                  for i=1,nofafter do
                    after[i]=afterclasses[readushort(f)+1]
                  end
                end
                local noflookups=readushort(f)
                local lookups=readlookuparray(f,noflookups,nofcurrent)
                rules[#rules+1]={
                  before=before,
                  current=current,
                  after=after,
                  lookups=lookups,
                }
              end
            else
              report("no coverage")
            end
          else
            report("class is not covered")
          end
        end
      end
    else
      report("empty subclassset in %a subtype %i","chainedcontext",subtype)
    end
    return {
      format="class",
      rules=rules,
    }
  elseif subtype==3 then
    local before=readarray(f)
    local current=readarray(f)
    local after=readarray(f)
    local noflookups=readushort(f)
    local lookups=readlookuparray(f,noflookups,#current)
    before=readcoveragearray(f,tableoffset,before,true)
    current=readcoveragearray(f,tableoffset,current,true)
    after=readcoveragearray(f,tableoffset,after,true)
    return {
      format="coverage",
      rules={
        {
          before=before,
          current=current,
          after=after,
          lookups=lookups,
        }
      }
    }
  else
    report("unsupported subtype %a in %a %s",subtype,"chainedcontext",what)
  end
end
local function extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,types,handlers,what)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local lookuptype=types[readushort(f)]
    local faroffset=readulong(f)
    local handler=handlers[lookuptype]
    if handler then
      return handler(f,fontdata,lookupid,tableoffset+faroffset,0,glyphs,nofglyphs),lookuptype
    else
      report("no handler for lookuptype %a subtype %a in %s %s",lookuptype,subtype,what,"extension")
    end
  else
    report("unsupported subtype %a in %s %s",subtype,what,"extension")
  end
end
function gsubhandlers.single(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local delta=readshort(f) 
    local coverage=readcoverage(f,tableoffset+coverage) 
    for index in next,coverage do
      local newindex=index+delta
      if index>nofglyphs or newindex>nofglyphs then
        report("invalid index in %s format %i: %i -> %i (max %i)","single",subtype,index,newindex,nofglyphs)
        coverage[index]=nil
      else
        coverage[index]=newindex
      end
    end
    return {
      coverage=coverage
    }
  elseif subtype==2 then 
    local coverage=readushort(f)
    local nofreplacements=readushort(f)
    local replacements={}
    for i=1,nofreplacements do
      replacements[i]=readushort(f)
    end
    local coverage=readcoverage(f,tableoffset+coverage) 
    for index,newindex in next,coverage do
      newindex=newindex+1
      if index>nofglyphs or newindex>nofglyphs then
        report("invalid index in %s format %i: %i -> %i (max %i)","single",subtype,index,newindex,nofglyphs)
        coverage[index]=nil
      else
        coverage[index]=replacements[newindex]
      end
    end
    return {
      coverage=coverage
    }
  else
    report("unsupported subtype %a in %a substitution",subtype,"single")
  end
end
local function sethandler(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,what)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local nofsequence=readushort(f)
    local sequences={}
    for i=1,nofsequence do
      sequences[i]=readushort(f)
    end
    for i=1,nofsequence do
      setposition(f,tableoffset+sequences[i])
      local n=readushort(f)
      local s={}
      for i=1,n do
        s[i]=readushort(f)
      end
      sequences[i]=s
    end
    local coverage=readcoverage(f,tableoffset+coverage)
    for index,newindex in next,coverage do
      newindex=newindex+1
      if index>nofglyphs or newindex>nofglyphs then
        report("invalid index in %s format %i: %i -> %i (max %i)",what,subtype,index,newindex,nofglyphs)
        coverage[index]=nil
      else
        coverage[index]=sequences[newindex]
      end
    end
    return {
      coverage=coverage
    }
  else
    report("unsupported subtype %a in %a substitution",subtype,what)
  end
end
function gsubhandlers.multiple(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return sethandler(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"multiple")
end
function gsubhandlers.alternate(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return sethandler(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"alternate")
end
function gsubhandlers.ligature(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local nofsets=readushort(f)
    local ligatures={}
    for i=1,nofsets do
      ligatures[i]=readushort(f)
    end
    for i=1,nofsets do
      local offset=lookupoffset+offset+ligatures[i]
      setposition(f,offset)
      local n=readushort(f)
      local l={}
      for i=1,n do
        l[i]=offset+readushort(f)
      end
      ligatures[i]=l
    end
    local coverage=readcoverage(f,tableoffset+coverage)
    for index,newindex in next,coverage do
      local hash={}
      local ligatures=ligatures[newindex+1]
      for i=1,#ligatures do
        local offset=ligatures[i]
        setposition(f,offset)
        local lig=readushort(f)
        local cnt=readushort(f)
        local hsh=hash
        for i=2,cnt do
          local c=readushort(f)
          local h=hsh[c]
          if not h then
            h={}
            hsh[c]=h
          end
          hsh=h
        end
        hsh.ligature=lig
      end
      coverage[index]=hash
    end
    return {
      coverage=coverage
    }
  else
    report("unsupported subtype %a in %a substitution",subtype,"ligature")
  end
end
function gsubhandlers.context(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return unchainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"substitution"),"context"
end
function gsubhandlers.chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"substitution"),"chainedcontext"
end
function gsubhandlers.extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,gsubtypes,gsubhandlers,"substitution")
end
function gsubhandlers.reversechainedcontextsingle(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then 
    local current=readfirst(f)
    local before=readarray(f)
    local after=readarray(f)
    local replacements=readarray(f)
    current=readcoveragearray(f,tableoffset,current,true)
    before=readcoveragearray(f,tableoffset,before,true)
    after=readcoveragearray(f,tableoffset,after,true)
    return {
      coverage={
        format="reversecoverage",
        before=before,
        current=current,
        after=after,
        replacements=replacements,
      }
    },"reversechainedcontextsingle"
  else
    report("unsupported subtype %a in %a substitution",subtype,"reversechainedcontextsingle")
  end
end
local function readpairsets(f,tableoffset,sets,format1,format2)
  local done={}
  for i=1,#sets do
    local offset=sets[i]
    local reused=done[offset]
    if not reused then
      setposition(f,tableoffset+offset)
      local n=readushort(f)
      reused={}
      for i=1,n do
        reused[i]={
          readushort(f),
          readposition(f,format1),
          readposition(f,format2)
        }
      end
      done[offset]=reused
    end
    sets[i]=reused
  end
  return sets
end
local function readpairclasssets(f,nofclasses1,nofclasses2,format1,format2)
  local classlist1={}
  for i=1,nofclasses1 do
    local classlist2={}
    classlist1[i]=classlist2
    for j=1,nofclasses2 do
      local one=readposition(f,format1)
      local two=readposition(f,format2)
      if one or two then
        classlist2[j]={ one,two }
      else
        classlist2[j]=false
      end
    end
  end
  return classlist1
end
function gposhandlers.single(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local format=readushort(f)
    local value=readposition(f,format)
    local coverage=readcoverage(f,tableoffset+coverage)
    for index,newindex in next,coverage do
      coverage[index]=value
    end
    return {
      format="pair",
      coverage=coverage
    }
  elseif subtype==2 then
    local coverage=readushort(f)
    local format=readushort(f)
    local values={}
    local nofvalues=readushort(f)
    for i=1,nofvalues do
      values[i]=readposition(f,format)
    end
    local coverage=readcoverage(f,tableoffset+coverage)
    for index,newindex in next,coverage do
      coverage[index]=values[newindex+1]
    end
    return {
      format="pair",
      coverage=coverage
    }
  else
    report("unsupported subtype %a in %a positioning",subtype,"single")
  end
end
function gposhandlers.pair(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=readushort(f)
    local format1=readushort(f)
    local format2=readushort(f)
    local sets=readarray(f)
       sets=readpairsets(f,tableoffset,sets,format1,format2)
       coverage=readcoverage(f,tableoffset+coverage)
    for index,newindex in next,coverage do
      local set=sets[newindex+1]
      local hash={}
      for i=1,#set do
        local value=set[i]
        if value then
          local other=value[1]
          local first=value[2]
          local second=value[3]
          if first or second then
            hash[other]={ first,second } 
          else
            hash[other]=nil
          end
        end
      end
      coverage[index]=hash
    end
    return {
      format="pair",
      coverage=coverage
    }
  elseif subtype==2 then
    local coverage=readushort(f)
    local format1=readushort(f)
    local format2=readushort(f)
    local classdef1=readushort(f)
    local classdef2=readushort(f)
    local nofclasses1=readushort(f) 
    local nofclasses2=readushort(f) 
    local classlist=readpairclasssets(f,nofclasses1,nofclasses2,format1,format2)
       coverage=readcoverage(f,tableoffset+coverage)
       classdef1=readclassdef(f,tableoffset+classdef1,coverage)
       classdef2=readclassdef(f,tableoffset+classdef2,nofglyphs)
    local usedcoverage={}
    for g1,c1 in next,classdef1 do
      if coverage[g1] then
        local l1=classlist[c1]
        if l1 then
          local hash={}
          for paired,class in next,classdef2 do
            local offsets=l1[class]
            if offsets then
              local first=offsets[1]
              local second=offsets[2]
              if first or second then
                hash[paired]={ first,second }
              else
              end
            end
          end
          usedcoverage[g1]=hash
        end
      end
    end
    return {
      format="pair",
      coverage=usedcoverage
    }
  elseif subtype==3 then
    report("yet unsupported subtype %a in %a positioning",subtype,"pair")
  else
    report("unsupported subtype %a in %a positioning",subtype,"pair")
  end
end
function gposhandlers.cursive(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local coverage=tableoffset+readushort(f)
    local nofrecords=readushort(f)
    local records={}
    for i=1,nofrecords do
      local entry=readushort(f)
      local exit=readushort(f)
      records[i]={
        entry=entry~=0 and (tableoffset+entry) or false,
        exit=exit~=0 and (tableoffset+exit ) or false,
      }
    end
    coverage=readcoverage(f,coverage)
    for i=1,nofrecords do
      local r=records[i]
      records[i]={
        1,
        readanchor(f,r.entry) or nil,
        readanchor(f,r.exit ) or nil,
      }
    end
    for index,newindex in next,coverage do
      coverage[index]=records[newindex+1]
    end
    return {
      coverage=coverage
    }
  else
    report("unsupported subtype %a in %a positioning",subtype,"cursive")
  end
end
local function handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,ligature)
  local tableoffset=lookupoffset+offset
  setposition(f,tableoffset)
  local subtype=readushort(f)
  if subtype==1 then
    local markcoverage=tableoffset+readushort(f)
    local basecoverage=tableoffset+readushort(f)
    local nofclasses=readushort(f)
    local markoffset=tableoffset+readushort(f)
    local baseoffset=tableoffset+readushort(f)
    local markcoverage=readcoverage(f,markcoverage)
    local basecoverage=readcoverage(f,basecoverage,true)
    setposition(f,markoffset)
    local markclasses={}
    local nofmarkclasses=readushort(f)
    local lastanchor=fontdata.lastanchor or 0
    local usedanchors={}
    for i=1,nofmarkclasses do
      local class=readushort(f)+1
      local offset=readushort(f)
      if offset==0 then
        markclasses[i]=false
      else
        markclasses[i]={ class,markoffset+offset }
      end
      usedanchors[class]=true
    end
    for i=1,nofmarkclasses do
      local mc=markclasses[i]
      if mc then
        mc[2]=readanchor(f,mc[2])
      end
    end
    setposition(f,baseoffset)
    local nofbaserecords=readushort(f)
    local baserecords={}
    if ligature then
      for i=1,nofbaserecords do 
        local offset=readushort(f)
        if offset==0 then
          baserecords[i]=false
        else
          baserecords[i]=baseoffset+offset
        end
      end
      for i=1,nofbaserecords do
        local recordoffset=baserecords[i]
        if recordoffset then
          setposition(f,recordoffset)
          local nofcomponents=readushort(f)
          local components={}
          for i=1,nofcomponents do
            local classes={}
            for i=1,nofclasses do
              local offset=readushort(f)
              if offset~=0 then
                classes[i]=recordoffset+offset
              else
                classes[i]=false
              end
            end
            components[i]=classes
          end
          baserecords[i]=components
        end
      end
      local baseclasses={} 
      for i=1,nofclasses do
        baseclasses[i]={}
      end
      for i=1,nofbaserecords do
        local components=baserecords[i]
        if components then
          local b=basecoverage[i]
          for c=1,#components do
            local classes=components[c]
            if classes then
              for i=1,nofclasses do
                local anchor=readanchor(f,classes[i])
                local bclass=baseclasses[i]
                local bentry=bclass[b]
                if bentry then
                  bentry[c]=anchor
                else
                  bclass[b]={ [c]=anchor }
                end
              end
            end
          end
        end
      end
      for index,newindex in next,markcoverage do
        markcoverage[index]=markclasses[newindex+1] or nil
      end
      return {
        format="ligature",
        baseclasses=baseclasses,
        coverage=markcoverage,
      }
    else
      for i=1,nofbaserecords do
        local r={}
        for j=1,nofclasses do
          local offset=readushort(f)
          if offset==0 then
            r[j]=false
          else
            r[j]=baseoffset+offset
          end
        end
        baserecords[i]=r
      end
      local baseclasses={} 
      for i=1,nofclasses do
        baseclasses[i]={}
      end
      for i=1,nofbaserecords do
        local r=baserecords[i]
        local b=basecoverage[i]
        for j=1,nofclasses do
          baseclasses[j][b]=readanchor(f,r[j])
        end
      end
      for index,newindex in next,markcoverage do
        markcoverage[index]=markclasses[newindex+1] or nil
      end
      return {
        format="base",
        baseclasses=baseclasses,
        coverage=markcoverage,
      }
    end
  else
    report("unsupported subtype %a in",subtype)
  end
end
function gposhandlers.marktobase(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
end
function gposhandlers.marktoligature(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,true)
end
function gposhandlers.marktomark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
end
function gposhandlers.context(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return unchainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"positioning"),"context"
end
function gposhandlers.chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"positioning"),"chainedcontext"
end
function gposhandlers.extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
  return extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,gpostypes,gposhandlers,"positioning")
end
do
  local plugins={}
  function plugins.size(f,fontdata,tableoffset,parameters)
    if not fontdata.designsize then
      setposition(f,tableoffset+parameters)
      local designsize=readushort(f)
      if designsize>0 then
        fontdata.designsize=designsize
        skipshort(f,2)
        fontdata.minsize=readushort(f)
        fontdata.maxsize=readushort(f)
      end
    end
  end
  local function reorderfeatures(fontdata,scripts,features)
    local scriptlangs={}
    local featurehash={}
    local featureorder={}
    for script,languages in next,scripts do
      for language,record in next,languages do
        local hash={}
        local list=record.featureindices
        for k=1,#list do
          local index=list[k]
          local feature=features[index]
          local lookups=feature.lookups
          local tag=feature.tag
          if tag then
            hash[tag]=true
          end
          if lookups then
            for i=1,#lookups do
              local lookup=lookups[i]
              local o=featureorder[lookup]
              if o then
                local okay=true
                for i=1,#o do
                  if o[i]==tag then
                    okay=false
                    break
                  end
                end
                if okay then
                  o[#o+1]=tag
                end
              else
                featureorder[lookup]={ tag }
              end
              local f=featurehash[lookup]
              if f then
                local h=f[tag]
                if h then
                  local s=h[script]
                  if s then
                    s[language]=true
                  else
                    h[script]={ [language]=true }
                  end
                else
                  f[tag]={ [script]={ [language]=true } }
                end
              else
                featurehash[lookup]={ [tag]={ [script]={ [language]=true } } }
              end
              local h=scriptlangs[tag]
              if h then
                local s=h[script]
                if s then
                  s[language]=true
                else
                  h[script]={ [language]=true }
                end
              else
                scriptlangs[tag]={ [script]={ [language]=true } }
              end
            end
          end
        end
      end
    end
    return scriptlangs,featurehash,featureorder
  end
  local function readscriplan(f,fontdata,scriptoffset)
    setposition(f,scriptoffset)
    local nofscripts=readushort(f)
    local scripts={}
    for i=1,nofscripts do
      scripts[readtag(f)]=scriptoffset+readushort(f)
    end
    local languagesystems=setmetatableindex("table")
    for script,offset in next,scripts do
      setposition(f,offset)
      local defaultoffset=readushort(f)
      local noflanguages=readushort(f)
      local languages={}
      if defaultoffset>0 then
        languages.dflt=languagesystems[offset+defaultoffset]
      end
      for i=1,noflanguages do
        local language=readtag(f)
        local offset=offset+readushort(f)
        languages[language]=languagesystems[offset]
      end
      scripts[script]=languages
    end
    for offset,usedfeatures in next,languagesystems do
      if offset>0 then
        setposition(f,offset)
        local featureindices={}
        usedfeatures.featureindices=featureindices
        usedfeatures.lookuporder=readushort(f) 
        usedfeatures.requiredindex=readushort(f) 
        local noffeatures=readushort(f)
        for i=1,noffeatures do
          featureindices[i]=readushort(f)+1
        end
      end
    end
    return scripts
  end
  local function readfeatures(f,fontdata,featureoffset)
    setposition(f,featureoffset)
    local features={}
    local noffeatures=readushort(f)
    for i=1,noffeatures do
      features[i]={
        tag=readtag(f),
        offset=readushort(f)
      }
    end
    for i=1,noffeatures do
      local feature=features[i]
      local offset=featureoffset+feature.offset
      setposition(f,offset)
      local parameters=readushort(f) 
      local noflookups=readushort(f)
      if noflookups>0 then
        local lookups={}
        feature.lookups=lookups
        for j=1,noflookups do
          lookups[j]=readushort(f)+1
        end
      end
      if parameters>0 then
        feature.parameters=parameters
        local plugin=plugins[feature.tag]
        if plugin then
          plugin(f,fontdata,offset,parameters)
        end
      end
    end
    return features
  end
  local function readlookups(f,lookupoffset,lookuptypes,featurehash,featureorder)
    setposition(f,lookupoffset)
    local lookups={}
    local noflookups=readushort(f)
    for i=1,noflookups do
      lookups[i]=readushort(f)
    end
    for lookupid=1,noflookups do
      local index=lookups[lookupid]
      setposition(f,lookupoffset+index)
      local subtables={}
      local typebits=readushort(f)
      local flagbits=readushort(f)
      local lookuptype=lookuptypes[typebits]
      local lookupflags=lookupflags[flagbits]
      local nofsubtables=readushort(f)
      for j=1,nofsubtables do
        local offset=readushort(f)
        subtables[j]=offset+index 
      end
      local markclass=bittest(flagbits,0x0010) 
      if markclass then
        markclass=readushort(f) 
      end
      local markset=rshift(flagbits,8)
      if markset>0 then
        markclass=markset 
      end
      lookups[lookupid]={
        type=lookuptype,
        flags=lookupflags,
        name=lookupid,
        subtables=subtables,
        markclass=markclass,
        features=featurehash[lookupid],
        order=featureorder[lookupid],
      }
    end
    return lookups
  end
  local function readscriptoffsets(f,fontdata,tableoffset)
    if not tableoffset then
      return
    end
    setposition(f,tableoffset)
    local version=readulong(f)
    if version~=0x00010000 then
      report("table version %a of %a is not supported (yet), maybe font %s is bad",version,what,fontdata.filename)
      return
    end
    return tableoffset+readushort(f),tableoffset+readushort(f),tableoffset+readushort(f)
  end
  local f_lookupname=formatters["%s_%s_%s"]
  local function resolvelookups(f,lookupoffset,fontdata,lookups,lookuptypes,lookuphandlers,what)
    local sequences=fontdata.sequences  or {}
    local sublookuplist=fontdata.sublookups or {}
    fontdata.sequences=sequences
    fontdata.sublookups=sublookuplist
    local nofsublookups=#sublookuplist
    local nofsequences=#sequences 
    local lastsublookup=nofsublookups
    local lastsequence=nofsequences
    local lookupnames=lookupnames[what]
    local sublookuphash={}
    local sublookupcheck={}
    local glyphs=fontdata.glyphs
    local nofglyphs=fontdata.nofglyphs or #glyphs
    local noflookups=#lookups
    local lookupprefix=sub(what,2,2)
    for lookupid=1,noflookups do
      local lookup=lookups[lookupid]
      local lookuptype=lookup.type
      local subtables=lookup.subtables
      local features=lookup.features
      local handler=lookuphandlers[lookuptype]
      if handler then
        local nofsubtables=#subtables
        local order=lookup.order
        local flags=lookup.flags
        if flags[1] then flags[1]="mark" end
        if flags[2] then flags[2]="ligature" end
        if flags[3] then flags[3]="base" end
        local markclass=lookup.markclass
        if nofsubtables>0 then
          local steps={}
          local nofsteps=0
          local oldtype=nil
          for s=1,nofsubtables do
            local step,lt=handler(f,fontdata,lookupid,lookupoffset,subtables[s],glyphs,nofglyphs)
            if lt then
              lookuptype=lt
              if oldtype and lt~=oldtype then
                report("messy %s lookup type %a and %a",what,lookuptype,oldtype)
              end
              oldtype=lookuptype
            end
            if not step then
              report("unsupported %s lookup type %a",what,lookuptype)
            else
              nofsteps=nofsteps+1
              steps[nofsteps]=step
              local rules=step.rules
              if rules then
                for i=1,#rules do
                  local rule=rules[i]
                  local before=rule.before
                  local current=rule.current
                  local after=rule.after
                  if before then
                    for i=1,#before do
                      before[i]=tohash(before[i])
                    end
                    rule.before=reversed(before)
                  end
                  if current then
                    for i=1,#current do
                      current[i]=tohash(current[i])
                    end
                  end
                  if after then
                    for i=1,#after do
                      after[i]=tohash(after[i])
                    end
                  end
                end
              end
            end
          end
          if nofsteps~=nofsubtables then
            report("bogus subtables removed in %s lookup type %a",what,lookuptype)
          end
          lookuptype=lookupnames[lookuptype] or lookuptype
          if features then
            nofsequences=nofsequences+1
            local l={
              index=nofsequences,
              name=f_lookupname(lookupprefix,"s",lookupid+lookupidoffset),
              steps=steps,
              nofsteps=nofsteps,
              type=lookuptype,
              markclass=markclass or nil,
              flags=flags,
              order=order,
              features=features,
            }
            sequences[nofsequences]=l
            lookup.done=l
          else
            nofsublookups=nofsublookups+1
            local l={
              index=nofsublookups,
              name=f_lookupname(lookupprefix,"l",lookupid+lookupidoffset),
              steps=steps,
              nofsteps=nofsteps,
              type=lookuptype,
              markclass=markclass or nil,
              flags=flags,
            }
            sublookuplist[nofsublookups]=l
            sublookuphash[lookupid]=nofsublookups
            sublookupcheck[lookupid]=0
            lookup.done=l
          end
        else
          report("no subtables for lookup %a",lookupid)
        end
      else
        report("no handler for lookup %a with type %a",lookupid,lookuptype)
      end
    end
    local reported={}
    local function report_issue(i,what,sequence,kind)
      local name=sequence.name
      if not reported[name] then
        report("rule %i in %s lookup %a has %s lookups",i,what,name,kind)
        reported[name]=true
      end
    end
    for i=lastsequence+1,nofsequences do
      local sequence=sequences[i]
      local steps=sequence.steps
      for i=1,#steps do
        local step=steps[i]
        local rules=step.rules
        if rules then
          for i=1,#rules do
            local rule=rules[i]
            local rlookups=rule.lookups
            if not rlookups then
              report_issue(i,what,sequence,"no")
            elseif not next(rlookups) then
              report_issue(i,what,sequence,"empty")
              rule.lookups=nil
            else
              local length=#rlookups
              for index=1,length do
                local lookupid=rlookups[index]
                if lookupid then
                  local h=sublookuphash[lookupid]
                  if not h then
                    local lookup=lookups[lookupid]
                    if lookup then
                      local d=lookup.done
                      if d then
                        nofsublookups=nofsublookups+1
                        h={
                          index=nofsublookups,
                          name=f_lookupname(lookupprefix,"d",lookupid+lookupidoffset),
                          derived=true,
                          steps=d.steps,
                          nofsteps=d.nofsteps,
                          type=d.lookuptype,
                          markclass=d.markclass or nil,
                          flags=d.flags,
                        }
                        sublookuplist[nofsublookups]=h
                        sublookuphash[lookupid]=nofsublookups
                        sublookupcheck[lookupid]=1
                      else
                        report_issue(i,what,sequence,"missing")
                        rule.lookups=nil
                        break
                      end
                    else
                      report_issue(i,what,sequence,"bad")
                      rule.lookups=nil
                      break
                    end
                  else
                    sublookupcheck[lookupid]=sublookupcheck[lookupid]+1
                  end
                  rlookups[index]=h or false
                else
                  rlookups[index]=false
                end
              end
            end
          end
        end
      end
    end
    for i,n in sortedhash(sublookupcheck) do
      local l=lookups[i]
      local t=l.type
      if n==0 and t~="extension" then
        local d=l.done
        report("%s lookup %s of type %a is not used",what,d and d.name or l.name,t)
      end
    end
  end
  local function readscripts(f,fontdata,what,lookuptypes,lookuphandlers,lookupstoo)
    local datatable=fontdata.tables[what]
    if not datatable then
      return
    end
    local tableoffset=datatable.offset
    if not tableoffset then
      return
    end
    local scriptoffset,featureoffset,lookupoffset=readscriptoffsets(f,fontdata,tableoffset)
    if not scriptoffset then
      return
    end
    local scripts=readscriplan(f,fontdata,scriptoffset)
    local features=readfeatures(f,fontdata,featureoffset)
    local scriptlangs,featurehash,featureorder=reorderfeatures(fontdata,scripts,features)
    if fontdata.features then
      fontdata.features[what]=scriptlangs
    else
      fontdata.features={ [what]=scriptlangs }
    end
    if not lookupstoo then
      return
    end
    local lookups=readlookups(f,lookupoffset,lookuptypes,featurehash,featureorder)
    if lookups then
      resolvelookups(f,lookupoffset,fontdata,lookups,lookuptypes,lookuphandlers,what)
    end
  end
  local function checkkerns(f,fontdata,specification)
    local datatable=fontdata.tables.kern
    if not datatable then
      return 
    end
    local features=fontdata.features
    local gposfeatures=features and features.gpos
    local name
    if not gposfeatures or not gposfeatures.kern then
      name="kern"
    elseif specification.globalkerns then
      name="globalkern"
    else
      report("ignoring global kern table using gpos kern feature")
      return
    end
    report("adding global kern table as gpos feature %a",name)
    setposition(f,datatable.offset)
    local version=readushort(f)
    local noftables=readushort(f)
    local kerns=setmetatableindex("table")
    for i=1,noftables do
      local version=readushort(f)
      local length=readushort(f)
      local coverage=readushort(f)
      local format=bit32.rshift(coverage,8) 
      if format==0 then
        local nofpairs=readushort(f)
        local searchrange=readushort(f)
        local entryselector=readushort(f)
        local rangeshift=readushort(f)
        for i=1,nofpairs do
          kerns[readushort(f)][readushort(f)]=readfword(f)
        end
      elseif format==2 then
      else
      end
    end
    local feature={ dflt={ dflt=true } }
    if not features then
      fontdata.features={ gpos={ [name]=feature } }
    elseif not gposfeatures then
      fontdata.features.gpos={ [name]=feature }
    else
      gposfeatures[name]=feature
    end
    local sequences=fontdata.sequences
    if not sequences then
      sequences={}
      fontdata.sequences=sequences
    end
    local nofsequences=#sequences+1
    sequences[nofsequences]={
      index=nofsequences,
      name=name,
      steps={
        {
          coverage=kerns,
          format="kern",
        },
      },
      nofsteps=1,
      type="gpos_pair",
      flags={ false,false,false,false },
      order={ name },
      features={ [name]=feature },
    }
  end
  function readers.gsub(f,fontdata,specification)
    if specification.details then
      readscripts(f,fontdata,"gsub",gsubtypes,gsubhandlers,specification.lookups)
    end
  end
  function readers.gpos(f,fontdata,specification)
    if specification.details then
      readscripts(f,fontdata,"gpos",gpostypes,gposhandlers,specification.lookups)
      if specification.lookups then
        checkkerns(f,fontdata,specification)
      end
    end
  end
end
function readers.gdef(f,fontdata,specification)
  if specification.glyphs then
    local datatable=fontdata.tables.gdef
    if datatable then
      local tableoffset=datatable.offset
      setposition(f,tableoffset)
      local version=readulong(f)
      local classoffset=tableoffset+readushort(f)
      local attachmentoffset=tableoffset+readushort(f) 
      local ligaturecarets=tableoffset+readushort(f) 
      local markclassoffset=tableoffset+readushort(f)
      local marksetsoffset=version==0x00010002 and (tableoffset+readushort(f))
      local glyphs=fontdata.glyphs
      local marks={}
      local markclasses=setmetatableindex("table")
      local marksets=setmetatableindex("table")
      fontdata.marks=marks
      fontdata.markclasses=markclasses
      fontdata.marksets=marksets
      setposition(f,classoffset)
      local classformat=readushort(f)
      if classformat==1 then
        local firstindex=readushort(f)
        local lastindex=firstindex+readushort(f)-1
        for index=firstindex,lastindex do
          local class=classes[readushort(f)]
          if class=="mark" then
            marks[index]=true
          end
          glyphs[index].class=class
        end
      elseif classformat==2 then
        local nofranges=readushort(f)
        for i=1,nofranges do
          local firstindex=readushort(f)
          local lastindex=readushort(f)
          local class=classes[readushort(f)]
          if class then
            for index=firstindex,lastindex do
              glyphs[index].class=class
              if class=="mark" then
                marks[index]=true
              end
            end
          end
        end
      end
      setposition(f,markclassoffset)
      local classformat=readushort(f)
      if classformat==1 then
        local firstindex=readushort(f)
        local lastindex=firstindex+readushort(f)-1
        for index=firstindex,lastindex do
          markclasses[readushort(f)][index]=true
        end
      elseif classformat==2 then
        local nofranges=readushort(f)
        for i=1,nofranges do
          local firstindex=readushort(f)
          local lastindex=readushort(f)
          local class=markclasses[readushort(f)]
          for index=firstindex,lastindex do
            class[index]=true
          end
        end
      end
      if marksetsoffset then
        setposition(f,marksetsoffset)
        local format=readushort(f)
        if format==1 then
          local nofsets=readushort(f)
          local sets={}
          for i=1,nofsets do
            sets[i]=readulong(f)
          end
          for i=1,nofsets do
            local offset=sets[i]
            if offset~=0 then
              marksets[i]=readcoverage(f,marksetsoffset+offset)
            end
          end
        end
      end
    end
  end
end
local function readmathvalue(f)
  local v=readshort(f)
  skipshort(f,1) 
  return v
end
local function readmathconstants(f,fontdata,offset)
  setposition(f,offset)
  fontdata.mathconstants={
    ScriptPercentScaleDown=readshort(f),
    ScriptScriptPercentScaleDown=readshort(f),
    DelimitedSubFormulaMinHeight=readushort(f),
    DisplayOperatorMinHeight=readushort(f),
    MathLeading=readmathvalue(f),
    AxisHeight=readmathvalue(f),
    AccentBaseHeight=readmathvalue(f),
    FlattenedAccentBaseHeight=readmathvalue(f),
    SubscriptShiftDown=readmathvalue(f),
    SubscriptTopMax=readmathvalue(f),
    SubscriptBaselineDropMin=readmathvalue(f),
    SuperscriptShiftUp=readmathvalue(f),
    SuperscriptShiftUpCramped=readmathvalue(f),
    SuperscriptBottomMin=readmathvalue(f),
    SuperscriptBaselineDropMax=readmathvalue(f),
    SubSuperscriptGapMin=readmathvalue(f),
    SuperscriptBottomMaxWithSubscript=readmathvalue(f),
    SpaceAfterScript=readmathvalue(f),
    UpperLimitGapMin=readmathvalue(f),
    UpperLimitBaselineRiseMin=readmathvalue(f),
    LowerLimitGapMin=readmathvalue(f),
    LowerLimitBaselineDropMin=readmathvalue(f),
    StackTopShiftUp=readmathvalue(f),
    StackTopDisplayStyleShiftUp=readmathvalue(f),
    StackBottomShiftDown=readmathvalue(f),
    StackBottomDisplayStyleShiftDown=readmathvalue(f),
    StackGapMin=readmathvalue(f),
    StackDisplayStyleGapMin=readmathvalue(f),
    StretchStackTopShiftUp=readmathvalue(f),
    StretchStackBottomShiftDown=readmathvalue(f),
    StretchStackGapAboveMin=readmathvalue(f),
    StretchStackGapBelowMin=readmathvalue(f),
    FractionNumeratorShiftUp=readmathvalue(f),
    FractionNumeratorDisplayStyleShiftUp=readmathvalue(f),
    FractionDenominatorShiftDown=readmathvalue(f),
    FractionDenominatorDisplayStyleShiftDown=readmathvalue(f),
    FractionNumeratorGapMin=readmathvalue(f),
    FractionNumeratorDisplayStyleGapMin=readmathvalue(f),
    FractionRuleThickness=readmathvalue(f),
    FractionDenominatorGapMin=readmathvalue(f),
    FractionDenominatorDisplayStyleGapMin=readmathvalue(f),
    SkewedFractionHorizontalGap=readmathvalue(f),
    SkewedFractionVerticalGap=readmathvalue(f),
    OverbarVerticalGap=readmathvalue(f),
    OverbarRuleThickness=readmathvalue(f),
    OverbarExtraAscender=readmathvalue(f),
    UnderbarVerticalGap=readmathvalue(f),
    UnderbarRuleThickness=readmathvalue(f),
    UnderbarExtraDescender=readmathvalue(f),
    RadicalVerticalGap=readmathvalue(f),
    RadicalDisplayStyleVerticalGap=readmathvalue(f),
    RadicalRuleThickness=readmathvalue(f),
    RadicalExtraAscender=readmathvalue(f),
    RadicalKernBeforeDegree=readmathvalue(f),
    RadicalKernAfterDegree=readmathvalue(f),
    RadicalDegreeBottomRaisePercent=readshort(f),
  }
end
local function readmathglyphinfo(f,fontdata,offset)
  setposition(f,offset)
  local italics=readushort(f)
  local accents=readushort(f)
  local extensions=readushort(f)
  local kerns=readushort(f)
  local glyphs=fontdata.glyphs
  if italics~=0 then
    setposition(f,offset+italics)
    local coverage=readushort(f)
    local nofglyphs=readushort(f)
    coverage=readcoverage(f,offset+italics+coverage,true)
    setposition(f,offset+italics+4)
    for i=1,nofglyphs do
      local italic=readmathvalue(f)
      if italic~=0 then
        local glyph=glyphs[coverage[i]]
        local math=glyph.math
        if not math then
          glyph.math={ italic=italic }
        else
          math.italic=italic
        end
      end
    end
    fontdata.hasitalics=true
  end
  if accents~=0 then
    setposition(f,offset+accents)
    local coverage=readushort(f)
    local nofglyphs=readushort(f)
    coverage=readcoverage(f,offset+accents+coverage,true)
    setposition(f,offset+accents+4)
    for i=1,nofglyphs do
      local accent=readmathvalue(f)
      if accent~=0 then
        local glyph=glyphs[coverage[i]]
        local math=glyph.math
        if not math then
          glyph.math={ accent=accent }
        else
          math.accent=accent
        end
      end
    end
  end
  if extensions~=0 then
    setposition(f,offset+extensions)
  end
  if kerns~=0 then
    local kernoffset=offset+kerns
    setposition(f,kernoffset)
    local coverage=readushort(f)
    local nofglyphs=readushort(f)
    if nofglyphs>0 then
      local function get(offset)
        setposition(f,kernoffset+offset)
        local n=readushort(f)
        if n==0 then
          local k=readmathvalue(f)
          if k==0 then
          else
            return { { kern=k } }
          end
        else
          local l={}
          for i=1,n do
            l[i]={ height=readmathvalue(f) }
          end
          for i=1,n do
            l[i].kern=readmathvalue(f)
          end
          l[n+1]={ kern=readmathvalue(f) }
          return l
        end
      end
      local kernsets={}
      for i=1,nofglyphs do
        local topright=readushort(f)
        local topleft=readushort(f)
        local bottomright=readushort(f)
        local bottomleft=readushort(f)
        kernsets[i]={
          topright=topright~=0 and topright  or nil,
          topleft=topleft~=0 and topleft   or nil,
          bottomright=bottomright~=0 and bottomright or nil,
          bottomleft=bottomleft~=0 and bottomleft or nil,
        }
      end
      coverage=readcoverage(f,kernoffset+coverage,true)
      for i=1,nofglyphs do
        local kernset=kernsets[i]
        if next(kernset) then
          local k=kernset.topright  if k then kernset.topright=get(k) end
          local k=kernset.topleft   if k then kernset.topleft=get(k) end
          local k=kernset.bottomright if k then kernset.bottomright=get(k) end
          local k=kernset.bottomleft if k then kernset.bottomleft=get(k) end
          if next(kernset) then
            local glyph=glyphs[coverage[i]]
            local math=glyph.math
            if math then
              math.kerns=kernset
            else
              glyph.math={ kerns=kernset }
            end
          end
        end
      end
    end
  end
end
local function readmathvariants(f,fontdata,offset)
  setposition(f,offset)
  local glyphs=fontdata.glyphs
  local minoverlap=readushort(f)
  local vcoverage=readushort(f)
  local hcoverage=readushort(f)
  local vnofglyphs=readushort(f)
  local hnofglyphs=readushort(f)
  local vconstruction={}
  local hconstruction={}
  for i=1,vnofglyphs do
    vconstruction[i]=readushort(f)
  end
  for i=1,hnofglyphs do
    hconstruction[i]=readushort(f)
  end
  fontdata.mathconstants.MinConnectorOverlap=minoverlap
  local function get(offset,coverage,nofglyphs,construction,kvariants,kparts,kitalic)
    if coverage~=0 and nofglyphs>0 then
      local coverage=readcoverage(f,offset+coverage,true)
      for i=1,nofglyphs do
        local c=construction[i]
        if c~=0 then
          local index=coverage[i]
          local glyph=glyphs[index]
          local math=glyph.math
          setposition(f,offset+c)
          local assembly=readushort(f)
          local nofvariants=readushort(f)
          if nofvariants>0 then
            local variants,v=nil,0
            for i=1,nofvariants do
              local variant=readushort(f)
              if variant==index then
              elseif variants then
                v=v+1
                variants[v]=variant
              else
                v=1
                variants={ variant }
              end
              skipshort(f)
            end
            if not variants then
            elseif not math then
              math={ [kvariants]=variants }
              glyph.math=math
            else
              math[kvariants]=variants
            end
          end
          if assembly~=0 then
            setposition(f,offset+c+assembly)
            local italic=readmathvalue(f)
            local nofparts=readushort(f)
            local parts={}
            for i=1,nofparts do
              local p={
                glyph=readushort(f),
                start=readushort(f),
                ["end"]=readushort(f),
                advance=readushort(f),
              }
              local flags=readushort(f)
              if bittest(flags,0x0001) then
                p.extender=1 
              end
              parts[i]=p
            end
            if not math then
              math={
                [kparts]=parts
              }
              glyph.math=math
            else
              math[kparts]=parts
            end
            if italic and italic~=0 then
              math[kitalic]=italic
            end
          end
        end
      end
    end
  end
  get(offset,vcoverage,vnofglyphs,vconstruction,"vvariants","vparts","vitalic")
  get(offset,hcoverage,hnofglyphs,hconstruction,"hvariants","hparts","hitalic")
end
function readers.math(f,fontdata,specification)
  if specification.glyphs then
    local datatable=fontdata.tables.math
    if datatable then
      local tableoffset=datatable.offset
      setposition(f,tableoffset)
      local version=readulong(f)
      if version~=0x00010000 then
        report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"math",fontdata.filename)
        return
      end
      local constants=readushort(f)
      local glyphinfo=readushort(f)
      local variants=readushort(f)
      if constants==0 then
        report("the math table of %a has no constants",fontdata.filename)
      else
        readmathconstants(f,fontdata,tableoffset+constants)
      end
      if glyphinfo~=0 then
        readmathglyphinfo(f,fontdata,tableoffset+glyphinfo)
      end
      if variants~=0 then
        readmathvariants(f,fontdata,tableoffset+variants)
      end
    end
  end
end
function readers.colr(f,fontdata,specification)
  local datatable=fontdata.tables.colr
  if datatable then
    if specification.glyphs then
      local tableoffset=datatable.offset
      setposition(f,tableoffset)
      local version=readushort(f)
      if version~=0 then
        report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"colr",fontdata.filename)
        return
      end
      if not fontdata.tables.cpal then
        report("color table %a in font %a has no mandate %a table","colr",fontdata.filename,"cpal")
        fontdata.colorpalettes={}
      end
      local glyphs=fontdata.glyphs
      local nofglyphs=readushort(f)
      local baseoffset=readulong(f)
      local layeroffset=readulong(f)
      local noflayers=readushort(f)
      local layerrecords={}
      local maxclass=0
      setposition(f,tableoffset+layeroffset)
      for i=1,noflayers do
        local slot=readushort(f)
        local class=readushort(f)
        if class<0xFFFF then
          class=class+1
          if class>maxclass then
            maxclass=class
          end
        end
        layerrecords[i]={
          slot=slot,
          class=class,
        }
      end
      fontdata.maxcolorclass=maxclass
      setposition(f,tableoffset+baseoffset)
      for i=0,nofglyphs-1 do
        local glyphindex=readushort(f)
        local firstlayer=readushort(f)
        local noflayers=readushort(f)
        local t={}
        for i=1,noflayers do
          t[i]=layerrecords[firstlayer+i]
        end
        glyphs[glyphindex].colors=t
      end
    end
    fontdata.hascolor=true
  end
end
function readers.cpal(f,fontdata,specification)
  if specification.glyphs then
    local datatable=fontdata.tables.cpal
    if datatable then
      local tableoffset=datatable.offset
      setposition(f,tableoffset)
      local version=readushort(f)
      if version>1 then
        report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"cpal",fontdata.filename)
        return
      end
      local nofpaletteentries=readushort(f)
      local nofpalettes=readushort(f)
      local nofcolorrecords=readushort(f)
      local firstcoloroffset=readulong(f)
      local colorrecords={}
      local palettes={}
      for i=1,nofpalettes do
        palettes[i]=readushort(f)
      end
      if version==1 then
        local palettettypesoffset=readulong(f)
        local palettelabelsoffset=readulong(f)
        local paletteentryoffset=readulong(f)
      end
      setposition(f,tableoffset+firstcoloroffset)
      for i=1,nofcolorrecords do
        local b,g,r,a=readbytes(f,4)
        colorrecords[i]={
          r,g,b,a~=255 and a or nil,
        }
      end
      for i=1,nofpalettes do
        local p={}
        local o=palettes[i]
        for j=1,nofpaletteentries do
          p[j]=colorrecords[o+j]
        end
        palettes[i]=p
      end
      fontdata.colorpalettes=palettes
    end
  end
end
function readers.svg(f,fontdata,specification)
  local datatable=fontdata.tables.svg
  if datatable then
    if specification.glyphs then
      local tableoffset=datatable.offset
      setposition(f,tableoffset)
      local version=readushort(f)
      if version~=0 then
        report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"svg",fontdata.filename)
        return
      end
      local glyphs=fontdata.glyphs
      local indexoffset=tableoffset+readulong(f)
      local reserved=readulong(f)
      setposition(f,indexoffset)
      local nofentries=readushort(f)
      local entries={}
      for i=1,nofentries do
        entries[i]={
          first=readushort(f),
          last=readushort(f),
          offset=indexoffset+readulong(f),
          length=readulong(f),
        }
      end
      for i=1,nofentries do
        local entry=entries[i]
        setposition(f,entry.offset)
        entries[i]={
          first=entry.first,
          last=entry.last,
          data=readstring(f,entry.length)
        }
      end
      fontdata.svgshapes=entries
    end
    fontdata.hascolor=true
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-oup']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type=next,type
local P,R,S=lpeg.P,lpeg.R,lpeg.S
local lpegmatch=lpeg.match
local insert,remove,copy,unpack=table.insert,table.remove,table.copy,table.unpack
local formatters=string.formatters
local sortedkeys=table.sortedkeys
local sortedhash=table.sortedhash
local tohash=table.tohash
local report=logs.reporter("otf reader")
local trace_markwidth=false trackers.register("otf.markwidth",function(v) trace_markwidth=v end)
local readers=fonts.handlers.otf.readers
local privateoffset=fonts.constructors and fonts.constructors.privateoffset or 0xF0000 
local f_private=formatters["P%05X"]
local f_unicode=formatters["U%05X"]
local f_index=formatters["I%05X"]
local f_character_y=formatters["%C"]
local f_character_n=formatters["[ %C ]"]
local doduplicates=true 
local function replaced(list,index,replacement)
  if type(list)=="number" then
    return replacement
  elseif type(replacement)=="table" then
    local t={}
    local n=index-1
    for i=1,n do
      t[i]=list[i]
    end
    for i=1,#replacement do
      n=n+1
      t[n]=replacement[i]
    end
    for i=index+1,#list do
      n=n+1
      t[n]=list[i]
    end
  else
    list[index]=replacement
    return list
  end
end
local function unifyresources(fontdata,indices)
  local descriptions=fontdata.descriptions
  local resources=fontdata.resources
  if not descriptions or not resources then
    return
  end
  local variants=fontdata.resources.variants
  if variants then
    for selector,unicodes in next,variants do
      for unicode,index in next,unicodes do
        unicodes[unicode]=indices[index]
      end
    end
  end
  local function remark(marks)
    if marks then
      local newmarks={}
      for k,v in next,marks do
        local u=indices[k]
        if u then
          newmarks[u]=v
        else
          report("discarding mark %i",k)
        end
      end
      return newmarks
    end
  end
  local marks=resources.marks
  if marks then
    resources.marks=remark(marks)
  end
  local markclasses=resources.markclasses
  if markclasses then
    for class,marks in next,markclasses do
      markclasses[class]=remark(marks)
    end
  end
  local marksets=resources.marksets
  if marksets then
    for class,marks in next,marksets do
      marksets[class]=remark(marks)
    end
  end
  local done={}
  local duplicates=doduplicates and resources.duplicates
  if duplicates and not next(duplicates) then
    duplicates=false
  end
  local function recover(cover) 
    for i=1,#cover do
      local c=cover[i]
      if not done[c] then
        local t={}
        for k,v in next,c do
          t[indices[k]]=v
        end
        cover[i]=t
        done[c]=d
      end
    end
  end
  local function recursed(c) 
    local t={}
    for g,d in next,c do
      if type(d)=="table" then
        t[indices[g]]=recursed(d)
      else
        t[g]=indices[d] 
      end
    end
    return t
  end
  local function unifythem(sequences)
    if not sequences then
      return
    end
    for i=1,#sequences do
      local sequence=sequences[i]
      local kind=sequence.type
      local steps=sequence.steps
      local features=sequence.features
      if steps then
        for i=1,#steps do
          local step=steps[i]
          if kind=="gsub_single" then
            local c=step.coverage
            if c then
              local t1=done[c]
              if not t1 then
                t1={}
                if duplicates then
                  for g1,d1 in next,c do
                    local ug1=indices[g1]
                    local ud1=indices[d1]
                    t1[ug1]=ud1
                    local dg1=duplicates[ug1]
                    if dg1 then
                      for u in next,dg1 do
                        t1[u]=ud1
                      end
                    end
                  end
                else
                  for g1,d1 in next,c do
                    t1[indices[g1]]=indices[d1]
                  end
                end
                done[c]=t1
              end
              step.coverage=t1
            end
          elseif kind=="gpos_pair" then
            local c=step.coverage
            if c then
              local t1=done[c]
              if not t1 then
                t1={}
                for g1,d1 in next,c do
                  local t2=done[d1]
                  if not t2 then
                    t2={}
                    for g2,d2 in next,d1 do
                      t2[indices[g2]]=d2
                    end
                    done[d1]=t2
                  end
                  t1[indices[g1]]=t2
                end
                done[c]=t1
              end
              step.coverage=t1
            end
          elseif kind=="gsub_ligature" then
            local c=step.coverage
            if c then
              step.coverage=recursed(c)
            end
          elseif kind=="gsub_alternate" or kind=="gsub_multiple" then
            local c=step.coverage
            if c then
              local t1=done[c]
              if not t1 then
                t1={}
                if duplicates then
                  for g1,d1 in next,c do
                    for i=1,#d1 do
                      d1[i]=indices[d1[i]]
                    end
                    local ug1=indices[g1]
                    t1[ug1]=d1
                    local dg1=duplicates[ug1]
                    if dg1 then
                      for u in next,dg1 do
                        t1[u]=copy(d1)
                      end
                    end
                  end
                else
                  for g1,d1 in next,c do
                    for i=1,#d1 do
                      d1[i]=indices[d1[i]]
                    end
                    t1[indices[g1]]=d1
                  end
                end
                done[c]=t1
              end
              step.coverage=t1
            end
          elseif kind=="gpos_mark2base" or kind=="gpos_mark2mark" or kind=="gpos_mark2ligature" then
            local c=step.coverage
            if c then
              local t1=done[c]
              if not t1 then
                t1={}
                for g1,d1 in next,c do
                  t1[indices[g1]]=d1
                end
                done[c]=t1
              end
              step.coverage=t1
            end
            local c=step.baseclasses
            if c then
              local t1=done[c]
              if not t1 then
                for g1,d1 in next,c do
                  local t2=done[d1]
                  if not t2 then
                    t2={}
                    for g2,d2 in next,d1 do
                      t2[indices[g2]]=d2
                    end
                    done[d1]=t2
                  end
                  c[g1]=t2
                end
                done[c]=c
              end
            end
          elseif kind=="gpos_single" then
            local c=step.coverage
            if c then
              local t1=done[c]
              if not t1 then
                t1={}
                if duplicates then
                  for g1,d1 in next,c do
                    local ug1=indices[g1]
                    t1[ug1]=d1
                    local dg1=duplicates[ug1]
                    if dg1 then
                      for u in next,dg1 do
                        t1[u]=d1
                      end
                    end
                  end
                else
                  for g1,d1 in next,c do
                    t1[indices[g1]]=d1
                  end
                end
                done[c]=t1
              end
              step.coverage=t1
            end
          elseif kind=="gpos_cursive" then
            local c=step.coverage
            if c then
              local t1=done[c]
              if not t1 then
                t1={}
                if duplicates then
                  for g1,d1 in next,c do
                    local ug1=indices[g1]
                    t1[ug1]=d1
                    local dg1=duplicates[ug1]
                    if dg1 then
                      for u in next,dg1 do
                        t1[u]=copy(d1)
                      end
                    end
                  end
                else
                  for g1,d1 in next,c do
                    t1[indices[g1]]=d1
                  end
                end
                done[c]=t1
              end
              step.coverage=t1
            end
          end
          local rules=step.rules
          if rules then
            for i=1,#rules do
              local rule=rules[i]
              local before=rule.before  if before then recover(before) end
              local after=rule.after  if after  then recover(after)  end
              local current=rule.current if current then recover(current) end
              local replacements=rule.replacements
              if replacements then
                if not done[replacements] then
                  local r={}
                  for k,v in next,replacements do
                    r[indices[k]]=indices[v]
                  end
                  rule.replacements=r
                  done[replacements]=r
                end
              end
            end
          end
        end
      end
    end
  end
  unifythem(resources.sequences)
  unifythem(resources.sublookups)
end
local function copyduplicates(fontdata)
  if doduplicates then
    local descriptions=fontdata.descriptions
    local resources=fontdata.resources
    local duplicates=resources.duplicates
    if duplicates then
      for u,d in next,duplicates do
        local du=descriptions[u]
        if du then
          local t={ f_character_y(u),"@",f_index(du.index),"->" }
          local n=0
          local m=25
          for u in next,d do
            if descriptions[u] then
              if n<m then
                t[n+4]=f_character_n(u)
              end
            else
              local c=copy(du)
              c.unicode=u 
              descriptions[u]=c
              if n<m then
                t[n+4]=f_character_y(u)
              end
            end
            n=n+1
          end
          if n<=m then
            report("duplicates: %i : % t",n,t)
          else
            report("duplicates: %i : % t ...",n,t)
          end
        else
        end
      end
    end
  end
end
local ignore={ 
  ["notdef"]=true,
  [".notdef"]=true,
  ["null"]=true,
  [".null"]=true,
  ["nonmarkingreturn"]=true,
}
local function checklookups(fontdata,missing,nofmissing)
  local descriptions=fontdata.descriptions
  local resources=fontdata.resources
  if missing and nofmissing and nofmissing<=0 then
    return
  end
  local singles={}
  local alternates={}
  local ligatures={}
  if not missing then
    missing={}
    nofmissing=0
    for u,d in next,descriptions do
      if not d.unicode then
        nofmissing=nofmissing+1
        missing[u]=true
      end
    end
  end
  local function collectthem(sequences)
    if not sequences then
      return
    end
    for i=1,#sequences do
      local sequence=sequences[i]
      local kind=sequence.type
      local steps=sequence.steps
      if steps then
        for i=1,#steps do
          local step=steps[i]
          if kind=="gsub_single" then
            local c=step.coverage
            if c then
              singles[#singles+1]=c
            end
          elseif kind=="gsub_alternate" then
            local c=step.coverage
            if c then
              alternates[#alternates+1]=c
            end
          elseif kind=="gsub_ligature" then
            local c=step.coverage
            if c then
              ligatures[#ligatures+1]=c
            end
          end
        end
      end
    end
  end
  collectthem(resources.sequences)
  collectthem(resources.sublookups)
  local loops=0
  while true do
    loops=loops+1
    local old=nofmissing
    for i=1,#singles do
      local c=singles[i]
      for g1,g2 in next,c do
        if missing[g1] then
          local u2=descriptions[g2].unicode
          if u2 then
            missing[g1]=false
            descriptions[g1].unicode=u2
            nofmissing=nofmissing-1
          end
        end
        if missing[g2] then
          local u1=descriptions[g1].unicode
          if u1 then
            missing[g2]=false
            descriptions[g2].unicode=u1
            nofmissing=nofmissing-1
          end
        end
      end
    end
    for i=1,#alternates do
      local c=alternates[i]
      for g1,d1 in next,c do
        if missing[g1] then
          for i=1,#d1 do
            local g2=d1[i]
            local u2=descriptions[g2].unicode
            if u2 then
              missing[g1]=false
              descriptions[g1].unicode=u2
              nofmissing=nofmissing-1
            end
          end
        end
        if not missing[g1] then
          for i=1,#d1 do
            local g2=d1[i]
            if missing[g2] then
              local u1=descriptions[g1].unicode
              if u1 then
                missing[g2]=false
                descriptions[g2].unicode=u1
                nofmissing=nofmissing-1
              end
            end
          end
        end
      end
    end
    if nofmissing<=0 then
      report("all done in %s loops",loops)
      return
    elseif old==nofmissing then
      break
    end
  end
  local t,n 
  local function recursed(c)
    for g,d in next,c do
      if g~="ligature" then
        local u=descriptions[g].unicode
        if u then
          n=n+1
          t[n]=u
          recursed(d)
          n=n-1
        end
      elseif missing[d] then
        local l={}
        local m=0
        for i=1,n do
          local u=t[i]
          if type(u)=="table" then
            for i=1,#u do
              m=m+1
              l[m]=u[i]
            end
          else
            m=m+1
            l[m]=u
          end
        end
        missing[d]=false
        descriptions[d].unicode=l
        nofmissing=nofmissing-1
      end
    end
  end
  if nofmissing>0 then
    t={}
    n=0
    local loops=0
    while true do
      loops=loops+1
      local old=nofmissing
      for i=1,#ligatures do
        recursed(ligatures[i])
      end
      if nofmissing<=0 then
        report("all done in %s loops",loops)
        return
      elseif old==nofmissing then
        break
      end
    end
    t=nil
    n=0
  end
  if nofmissing>0 then
    local done={}
    for i,r in next,missing do
      if r then
        local data=descriptions[i]
        local name=data and data.name or f_index(i)
        if not ignore[name] then
          done[name]=true
        end
      end
    end
    if next(done) then
      report("not unicoded: % t",table.sortedkeys(done))
    end
  end
end
local function unifymissing(fontdata)
  if not fonts.mappings then
    require("font-map")
    require("font-agl")
  end
  local unicodes={}
  local private=fontdata.private
  local resources=fontdata.resources
  resources.unicodes=unicodes
  for unicode,d in next,fontdata.descriptions do
    if unicode<privateoffset then
      local name=d.name
      if name then
        unicodes[name]=unicode
      end
    end
  end
  fonts.mappings.addtounicode(fontdata,fontdata.filename,checklookups)
  resources.unicodes=nil
end
local function unifyglyphs(fontdata,usenames)
  local private=fontdata.private or privateoffset
  local glyphs=fontdata.glyphs
  local indices={}
  local descriptions={}
  local names=usenames and {}
  local resources=fontdata.resources
  local zero=glyphs[0]
  local zerocode=zero.unicode
  if not zerocode then
    zerocode=private
    zero.unicode=zerocode
    private=private+1
  end
  descriptions[zerocode]=zero
  if names then
    local name=glyphs[0].name or f_private(zerocode)
    indices[0]=name
    names[name]=zerocode
  else
    indices[0]=zerocode
  end
  for index=1,#glyphs do
    local glyph=glyphs[index]
    local unicode=glyph.unicode 
    if not unicode then
      unicode=private
      if names then
        local name=glyph.name or f_private(unicode)
        indices[index]=name
        names[name]=unicode
      else
        indices[index]=unicode
      end
      private=private+1
    elseif descriptions[unicode] then
      report("assigning private unicode %U to glyph indexed %05X (%C)",private,index,unicode)
      unicode=private
      if names then
        local name=glyph.name or f_private(unicode)
        indices[index]=name
        names[name]=unicode
      else
        indices[index]=unicode
      end
      private=private+1
    else
      if names then
        local name=glyph.name or f_unicode(unicode)
        indices[index]=name
        names[name]=unicode
      else
        indices[index]=unicode
      end
    end
    descriptions[unicode]=glyph
  end
  for index=1,#glyphs do
    local math=glyphs[index].math
    if math then
      local list=math.vparts
      if list then
        for i=1,#list do local l=list[i] l.glyph=indices[l.glyph] end
      end
      local list=math.hparts
      if list then
        for i=1,#list do local l=list[i] l.glyph=indices[l.glyph] end
      end
      local list=math.vvariants
      if list then
        for i=1,#list do list[i]=indices[list[i]] end
      end
      local list=math.hvariants
      if list then
        for i=1,#list do list[i]=indices[list[i]] end
      end
    end
  end
  local colorpalettes=resources.colorpalettes
  if colorpalettes then
    for index=1,#glyphs do
      local colors=glyphs[index].colors
      if colors then
        for i=1,#colors do
          local c=colors[i]
          c.slot=indices[c.slot]
        end
      end
    end
  end
  fontdata.private=private
  fontdata.glyphs=nil
  fontdata.names=names
  fontdata.descriptions=descriptions
  fontdata.hashmethod=hashmethod
  return indices,names
end
local p_bogusname=(
  (P("uni")+P("UNI")+P("Uni")+P("U")+P("u"))*S("Xx")^0*R("09","AF")^1+(P("identity")+P("Identity")+P("IDENTITY"))*R("09","AF")^1+(P("index")+P("Index")+P("INDEX"))*R("09")^1
)*P(-1)
local function stripredundant(fontdata)
  local descriptions=fontdata.descriptions
  if descriptions then
    local n=0
    local c=0
    for unicode,d in next,descriptions do
      local name=d.name
      if name and lpegmatch(p_bogusname,name) then
        d.name=nil
        n=n+1
      end
      if d.class=="base" then
        d.class=nil
        c=c+1
      end
    end
    if n>0 then
      report("%s bogus names removed (verbose unicode)",n)
    end
    if c>0 then
      report("%s base class tags removed (default is base)",c)
    end
  end
end
function readers.getcomponents(fontdata) 
  local resources=fontdata.resources
  if resources then
    local sequences=resources.sequences
    if sequences then
      local collected={}
      for i=1,#sequences do
        local sequence=sequences[i]
        if sequence.type=="gsub_ligature" then
          local steps=sequence.steps
          if steps then
            local l={}
            local function traverse(p,k,v)
              if k=="ligature" then
                collected[v]={ unpack(l) }
              else
                insert(l,k)
                for k,vv in next,v do
                  traverse(p,k,vv)
                end
                remove(l)
              end
            end
            for i=1,#steps do
              local coverage=steps[i].coverage
              if coverage then
                for k,v in next,coverage do
                  traverse(k,k,v)
                end
              end
            end
          end
        end
      end
      if next(collected) then
        while true do
          local done=false
          for k,v in next,collected do
            for i=1,#v do
              local vi=v[i]
              if vi==k then
                collected[k]=nil
                break
              else
                local c=collected[vi]
                if c then
                  done=true
                  local t={}
                  local n=i-1
                  for j=1,n do
                    t[j]=v[j]
                  end
                  for j=1,#c do
                    n=n+1
                    t[n]=c[j]
                  end
                  for j=i+1,#v do
                    n=n+1
                    t[n]=v[j]
                  end
                  collected[k]=t
                  break
                end
              end
            end
          end
          if not done then
            break
          end
        end
        return collected
      end
    end
  end
end
readers.unifymissing=unifymissing
function readers.rehash(fontdata,hashmethod) 
  if not (fontdata and fontdata.glyphs) then
    return
  end
  if hashmethod=="indices" then
    fontdata.hashmethod="indices"
  elseif hashmethod=="names" then
    fontdata.hashmethod="names"
    local indices=unifyglyphs(fontdata,true)
    unifyresources(fontdata,indices)
    copyduplicates(fontdata)
    unifymissing(fontdata)
  else
    fontdata.hashmethod="unicode"
    local indices=unifyglyphs(fontdata)
    unifyresources(fontdata,indices)
    copyduplicates(fontdata)
    unifymissing(fontdata)
    stripredundant(fontdata)
  end
end
function readers.checkhash(fontdata)
  local hashmethod=fontdata.hashmethod
  if hashmethod=="unicodes" then
    fontdata.names=nil 
  elseif hashmethod=="names" and fontdata.names then
    unifyresources(fontdata,fontdata.names)
    copyduplicates(fontdata)
    fontdata.hashmethod="unicode"
    fontdata.names=nil 
  else
    readers.rehash(fontdata,"unicode")
  end
end
function readers.addunicodetable(fontdata)
  local resources=fontdata.resources
  local unicodes=resources.unicodes
  if not unicodes then
    local descriptions=fontdata.descriptions
    if descriptions then
      unicodes={}
      resources.unicodes=unicodes
      for u,d in next,descriptions do
        local n=d.name
        if n then
          unicodes[n]=u
        end
      end
    end
  end
end
local concat,sort=table.concat,table.sort
local next,type,tostring=next,type,tostring
local criterium=1
local threshold=0
local trace_packing=false trackers.register("otf.packing",function(v) trace_packing=v end)
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
local report_otf=logs.reporter("fonts","otf loading")
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
function readers.pack(data)
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
          report_otf("pack quality: stage %s, pass %s, %s packed, 1-10:%s, 11-20:%s, rest:%s (criterium: %s)",
            stage,pass,one+two+rest,one,two,rest,criterium)
        end
        return true
      else
        if trace_loading or trace_packing then
          report_otf("pack quality: stage %s, pass %s, %s packed, aborting pack (threshold: %s)",
            stage,pass,nt,threshold)
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
    local sequences=resources.sequences
    local sublookups=resources.sublookups
    local features=resources.features
    local palettes=resources.colorpalettes
    local chardata=characters and characters.data
    local descriptions=data.descriptions or data.glyphs
    if not descriptions then
      return
    end
    for pass=1,2 do
      if trace_packing then
        report_otf("start packing: stage 1, pass %s",pass)
      end
      local pack_normal,pack_indexed,pack_flat,pack_boolean,pack_mixed=packers(pass)
      for unicode,description in next,descriptions do
        local boundingbox=description.boundingbox
        if boundingbox then
          description.boundingbox=pack_indexed(boundingbox)
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
      end
      local function packthem(sequences)
        for i=1,#sequences do
          local sequence=sequences[i]
          local kind=sequence.type
          local steps=sequence.steps
          local order=sequence.order
          local features=sequence.features
          local flags=sequence.flags
          if steps then
            for i=1,#steps do
              local step=steps[i]
              if kind=="gpos_pair" then
                local c=step.coverage
                if c then
                  if step.format=="kern" then
                    for g1,d1 in next,c do
                      c[g1]=pack_normal(d1)
                    end
                  else
                    for g1,d1 in next,c do
                      for g2,d2 in next,d1 do
                        local f=d2[1] if f then d2[1]=pack_indexed(f) end
                        local s=d2[2] if s then d2[2]=pack_indexed(s) end
                      end
                    end
                  end
                end
              elseif kind=="gpos_single" then
                local c=step.coverage
                if c then
                  if step.format=="kern" then
                    step.coverage=pack_normal(c)
                  else
                    for g1,d1 in next,c do
                      c[g1]=pack_indexed(d1)
                    end
                  end
                end
              elseif kind=="gpos_cursive" then
                local c=step.coverage
                if c then
                  for g1,d1 in next,c do
                    local f=d1[2] if f then d1[2]=pack_indexed(f) end
                    local s=d1[3] if s then d1[3]=pack_indexed(s) end
                  end
                end
              elseif kind=="gpos_mark2base" or kind=="gpos_mark2mark" then
                local c=step.baseclasses
                if c then
                  for g1,d1 in next,c do
                    for g2,d2 in next,d1 do
                      d1[g2]=pack_indexed(d2)
                    end
                  end
                end
                local c=step.coverage
                if c then
                  for g1,d1 in next,c do
                    d1[2]=pack_indexed(d1[2])
                  end
                end
              elseif kind=="gpos_mark2ligature" then
                local c=step.baseclasses
                if c then
                  for g1,d1 in next,c do
                    for g2,d2 in next,d1 do
                      for g3,d3 in next,d2 do
                        d2[g3]=pack_indexed(d3)
                      end
                    end
                  end
                end
                local c=step.coverage
                if c then
                  for g1,d1 in next,c do
                    d1[2]=pack_indexed(d1[2])
                  end
                end
              end
              local rules=step.rules
              if rules then
                for i=1,#rules do
                  local rule=rules[i]
                  local r=rule.before    if r then for i=1,#r do r[i]=pack_boolean(r[i]) end end
                  local r=rule.after    if r then for i=1,#r do r[i]=pack_boolean(r[i]) end end
                  local r=rule.current   if r then for i=1,#r do r[i]=pack_boolean(r[i]) end end
                  local r=rule.lookups   if r then rule.lookups=pack_mixed (r)  end
                  local r=rule.replacements if r then rule.replacements=pack_flat  (r)  end
                end
              end
            end
          end
          if order then
            sequence.order=pack_indexed(order)
          end
          if features then
            for script,feature in next,features do
              features[script]=pack_normal(feature)
            end
          end
          if flags then
            sequence.flags=pack_normal(flags)
          end
        end
      end
      if sequences then
        packthem(sequences)
      end
      if sublookups then
        packthem(sublookups)
      end
      if features then
        for k,list in next,features do
          for feature,spec in next,list do
            list[feature]=pack_normal(spec)
          end
        end
      end
      if palettes then
        for i=1,#palettes do
          local p=palettes[i]
          for j=1,#p do
            p[j]=pack_indexed(p[j])
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
        for unicode,description in next,descriptions do
          local math=description.math
          if math then
            local kerns=math.kerns
            if kerns then
              math.kerns=pack_normal(kerns)
            end
          end
        end
        local function packthem(sequences)
          for i=1,#sequences do
            local sequence=sequences[i]
            local kind=sequence.type
            local steps=sequence.steps
            local features=sequence.features
            if steps then
              for i=1,#steps do
                local step=steps[i]
                if kind=="gpos_pair" then
                  local c=step.coverage
                  if c then
                    if step.format=="kern" then
                    else
                      for g1,d1 in next,c do
                        for g2,d2 in next,d1 do
                          d1[g2]=pack_normal(d2)
                        end
                      end
                    end
                  end
                end
                local rules=step.rules
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
            if features then
              sequence.features=pack_normal(features)
            end
          end
        end
        if sequences then
          packthem(sequences)
        end
        if sublookups then
          packthem(sublookups)
        end
        if not success(2,pass) then
        end
      end
      for pass=1,2 do
        if trace_packing then
          report_otf("start packing: stage 3, pass %s",pass)
        end
        local pack_normal,pack_indexed,pack_flat,pack_boolean,pack_mixed=packers(pass)
        local function packthem(sequences)
          for i=1,#sequences do
            local sequence=sequences[i]
            local kind=sequence.type
            local steps=sequence.steps
            local features=sequence.features
            if steps then
              for i=1,#steps do
                local step=steps[i]
                if kind=="gpos_pair" then
                  local c=step.coverage
                  if c then
                    if step.format=="kern" then
                    else
                      for g1,d1 in next,c do
                        c[g1]=pack_normal(d1)
                      end
                    end
                  end
                end
              end
            end
          end
        end
        if sequences then
          packthem(sequences)
        end
        if sublookups then
          packthem(sublookups)
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
function readers.unpack(data)
  if data then
    local tables=data.tables
    if tables then
      local resources=data.resources
      local descriptions=data.descriptions or data.glyphs
      local sequences=resources.sequences
      local sublookups=resources.sublookups
      local features=resources.features
      local palettes=resources.colorpalettes
      local unpacked={}
      setmetatable(unpacked,unpacked_mt)
      for unicode,description in next,descriptions do
        local tv=tables[description.boundingbox]
        if tv then
          description.boundingbox=tv
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
      end
      local function unpackthem(sequences)
        for i=1,#sequences do
          local sequence=sequences[i]
          local kind=sequence.type
          local steps=sequence.steps
          local order=sequence.order
          local features=sequence.features
          local flags=sequence.flags
          local markclass=sequence.markclass
          if steps then
            for i=1,#steps do
              local step=steps[i]
              if kind=="gpos_pair" then
                local c=step.coverage
                if c then
                  if step.format=="kern" then
                    for g1,d1 in next,c do
                      local tv=tables[d1]
                      if tv then
                        c[g1]=tv
                      end
                    end
                  else
                    for g1,d1 in next,c do
                      local tv=tables[d1]
                      if tv then
                        c[g1]=tv
                        d1=tv
                      end
                      for g2,d2 in next,d1 do
                        local tv=tables[d2]
                        if tv then
                          d1[g2]=tv
                          d2=tv
                        end
                        local f=tables[d2[1]] if f then d2[1]=f end
                        local s=tables[d2[2]] if s then d2[2]=s end
                      end
                    end
                  end
                end
              elseif kind=="gpos_single" then
                local c=step.coverage
                if c then
                  if step.format=="kern" then
                    local tv=tables[c]
                    if tv then
                      step.coverage=tv
                    end
                  else
                    for g1,d1 in next,c do
                      local tv=tables[d1]
                      if tv then
                        c[g1]=tv
                      end
                    end
                  end
                end
              elseif kind=="gpos_cursive" then
                local c=step.coverage
                if c then
                  for g1,d1 in next,c do
                    local f=tables[d1[2]] if f then d1[2]=f end
                    local s=tables[d1[3]] if s then d1[3]=s end
                  end
                end
              elseif kind=="gpos_mark2base" or kind=="gpos_mark2mark" then
                local c=step.baseclasses
                if c then
                  for g1,d1 in next,c do
                    for g2,d2 in next,d1 do
                      local tv=tables[d2]
                      if tv then
                        d1[g2]=tv
                      end
                    end
                  end
                end
                local c=step.coverage
                if c then
                  for g1,d1 in next,c do
                    local tv=tables[d1[2]]
                    if tv then
                      d1[2]=tv
                    end
                  end
                end
              elseif kind=="gpos_mark2ligature" then
                local c=step.baseclasses
                if c then
                  for g1,d1 in next,c do
                    for g2,d2 in next,d1 do
                      for g3,d3 in next,d2 do
                        local tv=tables[d2[g3]]
                        if tv then
                          d2[g3]=tv
                        end
                      end
                    end
                  end
                end
                local c=step.coverage
                if c then
                  for g1,d1 in next,c do
                    local tv=tables[d1[2]]
                    if tv then
                      d1[2]=tv
                    end
                  end
                end
              end
              local rules=step.rules
              if rules then
                for i=1,#rules do
                  local rule=rules[i]
                  local before=rule.before
                  if before then
                    local tv=tables[before]
                    if tv then
                      rule.before=tv
                      before=tv
                    end
                    for i=1,#before do
                      local tv=tables[before[i]]
                      if tv then
                        before[i]=tv
                      end
                    end
                  end
                  local after=rule.after
                  if after then
                    local tv=tables[after]
                    if tv then
                      rule.after=tv
                      after=tv
                    end
                    for i=1,#after do
                      local tv=tables[after[i]]
                      if tv then
                        after[i]=tv
                      end
                    end
                  end
                  local current=rule.current
                  if current then
                    local tv=tables[current]
                    if tv then
                      rule.current=tv
                      current=tv
                    end
                    for i=1,#current do
                      local tv=tables[current[i]]
                      if tv then
                        current[i]=tv
                      end
                    end
                  end
                  local lookups=rule.lookups
                  if lookups then
                    local tv=tables[lookups]
                    if tv then
                      rule.lookups=tv
                    end
                  end
                  local replacements=rule.replacements
                  if replacements then
                    local tv=tables[replacements]
                    if tv then
                      rule.replacements=tv
                    end
                  end
                end
              end
            end
          end
          if features then
            local tv=tables[features]
            if tv then
              sequence.features=tv
              features=tv
            end
            for script,feature in next,features do
              local tv=tables[feature]
              if tv then
                features[script]=tv
              end
            end
          end
          if order then
            local tv=tables[order]
            if tv then
              sequence.order=tv
            end
          end
          if flags then
            local tv=tables[flags]
            if tv then
              sequence.flags=tv
            end
          end
        end
      end
      if sequences then
        unpackthem(sequences)
      end
      if sublookups then
        unpackthem(sublookups)
      end
      if features then
        for k,list in next,features do
          for feature,spec in next,list do
            local tv=tables[spec]
            if tv then
              list[feature]=tv
            end
          end
        end
      end
      if palettes then
        for i=1,#palettes do
          local p=palettes[i]
          for j=1,#p do
            local tv=tables[p[j]]
            if tv then
              p[j]=tv
            end
          end
        end
      end
      data.tables=nil
    end
  end
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
local function sameformat(sequence,steps,first,nofsteps,kind)
  return true
end
local function mergesteps_1(lookup,strict)
  local steps=lookup.steps
  local nofsteps=lookup.nofsteps
  local first=steps[1]
  if strict then
    local f=first.format
    for i=2,nofsteps do
      if steps[i].format~=f then
        report("not merging %a steps of %a lookup %a, different formats",nofsteps,lookup.type,lookup.name)
        return 0
      end
    end
  end
  report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
  local target=first.coverage
  for i=2,nofsteps do
    for k,v in next,steps[i].coverage do
      if not target[k] then
        target[k]=v
      end
    end
  end
  lookup.nofsteps=1
  lookup.merged=true
  lookup.steps={ first }
  return nofsteps-1
end
local function mergesteps_2(lookup,strict) 
  local steps=lookup.steps
  local nofsteps=lookup.nofsteps
  local first=steps[1]
  if strict then
    local f=first.format
    for i=2,nofsteps do
      if steps[i].format~=f then
        report("not merging %a steps of %a lookup %a, different formats",nofsteps,lookup.type,lookup.name)
        return 0
      end
    end
  end
  report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
  local target=first.coverage
  for i=2,nofsteps do
    for k,v in next,steps[i].coverage do
      local tk=target[k]
      if tk then
        for k,v in next,v do
          if not tk[k] then
            tk[k]=v
          end
        end
      else
        target[k]=v
      end
    end
  end
  lookup.nofsteps=1
  lookup.steps={ first }
  return nofsteps-1
end
local function mergesteps_3(lookup,strict) 
  local steps=lookup.steps
  local nofsteps=lookup.nofsteps
  local first=steps[1]
  report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
  local baseclasses={}
  local coverage={}
  local used={}
  for i=1,nofsteps do
    local offset=i*10
    local step=steps[i]
    for k,v in sortedhash(step.baseclasses) do
      baseclasses[offset+k]=v
    end
    for k,v in next,step.coverage do
      local tk=coverage[k]
      if tk then
        for k,v in next,v do
          if not tk[k] then
            tk[k]=v
            local c=offset+v[1]
            v[1]=c
            if not used[c] then
              used[c]=true
            end
          end
        end
      else
        coverage[k]=v
        local c=offset+v[1]
        v[1]=c
        if not used[c] then
          used[c]=true
        end
      end
    end
  end
  for k,v in next,baseclasses do
    if not used[k] then
      baseclasses[k]=nil
      report("discarding not used baseclass %i",k)
    end
  end
  first.baseclasses=baseclasses
  first.coverage=coverage
  lookup.nofsteps=1
  lookup.steps={ first }
  return nofsteps-1
end
local function nested(old,new)
  for k,v in next,old do
    if k=="ligature" then
      if not new.ligature then
        new.ligature=v
      end
    else
      local n=new[k]
      if n then
        nested(v,n)
      else
        new[k]=v
      end
    end
  end
end
local function mergesteps_4(lookup) 
  local steps=lookup.steps
  local nofsteps=lookup.nofsteps
  local first=steps[1]
  report("merging %a steps of %a lookup %a",nofsteps,lookup.type,lookup.name)
  local target=first.coverage
  for i=2,nofsteps do
    for k,v in next,steps[i].coverage do
      local tk=target[k]
      if tk then
        nested(v,tk)
      else
        target[k]=v
      end
    end
  end
  lookup.nofsteps=1
  lookup.steps={ first }
  return nofsteps-1
end
local function checkkerns(lookup)
  local steps=lookup.steps
  local nofsteps=lookup.nofsteps
  for i=1,nofsteps do
    local step=steps[i]
    if step.format=="pair" then
      local coverage=step.coverage
      local kerns=true
      for g1,d1 in next,coverage do
        if d1[1]~=0 or d1[2]~=0 or d1[4]~=0 then
          kerns=false
          break
        end
      end
      if kerns then
        report("turning pairs of step %a of %a lookup %a into kerns",i,lookup.type,lookup.name)
        for g1,d1 in next,coverage do
          coverage[g1]=d1[3]
        end
        step.format="kern"
      end
    end
  end
end
local function checkpairs(lookup)
  local steps=lookup.steps
  local nofsteps=lookup.nofsteps
  local kerned=0
  for i=1,nofsteps do
    local step=steps[i]
    if step.format=="pair" then
      local coverage=step.coverage
      local kerns=true
      for g1,d1 in next,coverage do
        for g2,d2 in next,d1 do
          if d2[2] then
            kerns=false
            break
          else
            local v=d2[1]
            if v[1]~=0 or v[2]~=0 or v[4]~=0 then
              kerns=false
              break
            end
          end
        end
      end
      if kerns then
        report("turning pairs of step %a of %a lookup %a into kerns",i,lookup.type,lookup.name)
        for g1,d1 in next,coverage do
          for g2,d2 in next,d1 do
            d1[g2]=d2[1][3]
          end
        end
        step.format="kern"
        kerned=kerned+1
      end
    end
  end
  return kerned
end
function readers.compact(data)
  if not data or data.compacted then
    return
  else
    data.compacted=true
  end
  local resources=data.resources
  local merged=0
  local kerned=0
  local allsteps=0
  local function compact(what)
    local lookups=resources[what]
    if lookups then
      for i=1,#lookups do
        local lookup=lookups[i]
        local nofsteps=lookup.nofsteps
        allsteps=allsteps+nofsteps
        if nofsteps>1 then
          local kind=lookup.type
          if kind=="gsub_single" or kind=="gsub_alternate" or kind=="gsub_multiple" then
            merged=merged+mergesteps_1(lookup)
          elseif kind=="gsub_ligature" then
            merged=merged+mergesteps_4(lookup)
          elseif kind=="gpos_single" then
            merged=merged+mergesteps_1(lookup,true)
            checkkerns(lookup)
          elseif kind=="gpos_pair" then
            merged=merged+mergesteps_2(lookup,true)
            kerned=kerned+checkpairs(lookup)
          elseif kind=="gpos_cursive" then
            merged=merged+mergesteps_2(lookup)
          elseif kind=="gpos_mark2mark" or kind=="gpos_mark2base" or kind=="gpos_mark2ligature" then
            merged=merged+mergesteps_3(lookup)
          end
        end
      end
    else
      report("no lookups in %a",what)
    end
  end
  compact("sequences")
  compact("sublookups")
  if merged>0 then
    report("%i steps of %i removed due to merging",merged,allsteps)
  end
  if kerned>0 then
    report("%i steps of %i steps turned from pairs into kerns",kerned,allsteps)
  end
end
function readers.expand(data)
  if not data or data.expanded then
    return
  else
    data.expanded=true
  end
  local resources=data.resources
  local sublookups=resources.sublookups
  local sequences=resources.sequences 
  local markclasses=resources.markclasses
  local descriptions=data.descriptions
  if descriptions then
    local defaultwidth=resources.defaultwidth or 0
    local defaultheight=resources.defaultheight or 0
    local defaultdepth=resources.defaultdepth or 0
    local basename=trace_markwidth and file.basename(resources.filename)
    for u,d in next,descriptions do
      local bb=d.boundingbox
      local wd=d.width
      if not wd then
        d.width=defaultwidth
      elseif trace_markwidth and wd~=0 and d.class=="mark" then
        report("mark %a with width %b found in %a",d.name or "<noname>",wd,basename)
      end
      if bb then
        local ht=bb[4]
        local dp=-bb[2]
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
  local function expandlookups(sequences)
    if sequences then
      for i=1,#sequences do
        local sequence=sequences[i]
        local steps=sequence.steps
        if steps then
          local kind=sequence.type
          local markclass=sequence.markclass
          if markclass then
            if not markclasses then
              report_warning("missing markclasses")
              sequence.markclass=false
            else
              sequence.markclass=markclasses[markclass]
            end
          end
          for i=1,sequence.nofsteps do
            local step=steps[i]
            local baseclasses=step.baseclasses
            if baseclasses then
              local coverage=step.coverage
              for k,v in next,coverage do
                v[1]=baseclasses[v[1]] 
              end
            elseif kind=="gpos_cursive" then
              local coverage=step.coverage
              for k,v in next,coverage do
                v[1]=coverage 
              end
            end
            local rules=step.rules
            if rules then
              local rulehash={}
              local rulesize=0
              local coverage={}
              local lookuptype=sequence.type
              step.coverage=coverage 
              for nofrules=1,#rules do
                local rule=rules[nofrules]
                local current=rule.current
                local before=rule.before
                local after=rule.after
                local replacements=rule.replacements or false
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
                local lookups=rule.lookups or false
                local subtype=nil
                if lookups then
                  for k,v in next,lookups do
                    local lookup=sublookups[v]
                    if lookup then
                      lookups[k]=lookup
                      if not subtype then
                        subtype=lookup.type
                      end
                    else
                    end
                  end
                end
                if sequence[1] then 
                  rulesize=rulesize+1
                  rulehash[rulesize]={
                    nofrules,
                    lookuptype,
                    sequence,
                    start,
                    stop,
                    lookups,
                    replacements,
                    subtype,
                  }
                  for unic in next,sequence[start] do
                    local cu=coverage[unic]
                    if not cu then
                      coverage[unic]=rulehash 
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
  expandlookups(sequences)
  expandlookups(sublookups)
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otl']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files",
}
local gmatch,find,match,lower,strip=string.gmatch,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring,unpack=type,next,tonumber,tostring,unpack
local abs=math.abs
local ioflush=io.flush
local derivetable=table.derive
local formatters=string.formatters
local setmetatableindex=table.setmetatableindex
local allocate=utilities.storage.allocate
local registertracker=trackers.register
local registerdirective=directives.register
local starttiming=statistics.starttiming
local stoptiming=statistics.stoptiming
local elapsedtime=statistics.elapsedtime
local findbinfile=resolvers.findbinfile
local trace_loading=false registertracker("otf.loading",function(v) trace_loading=v end)
local trace_features=false registertracker("otf.features",function(v) trace_features=v end)
local trace_defining=false registertracker("fonts.defining",function(v) trace_defining=v end)
local report_otf=logs.reporter("fonts","otf loading")
local fonts=fonts
local otf=fonts.handlers.otf
otf.version=3.025 
otf.cache=containers.define("fonts","otl",otf.version,true)
otf.svgcache=containers.define("fonts","svg",otf.version,true)
otf.pdfcache=containers.define("fonts","pdf",otf.version,true)
otf.svgenabled=false
local otfreaders=otf.readers
local hashes=fonts.hashes
local definers=fonts.definers
local readers=fonts.readers
local constructors=fonts.constructors
local otffeatures=constructors.features.otf
local registerotffeature=otffeatures.register
local enhancers=allocate()
otf.enhancers=enhancers
local patches={}
enhancers.patches=patches
local forceload=false
local cleanup=0   
local syncspace=true
local forcenotdef=false
local applyruntimefixes=fonts.treatments and fonts.treatments.applyfixes
local wildcard="*"
local default="dflt"
local formats=fonts.formats
formats.otf="opentype"
formats.ttf="truetype"
formats.ttc="truetype"
registerdirective("fonts.otf.loader.cleanup",function(v) cleanup=tonumber(v) or (v and 1) or 0 end)
registerdirective("fonts.otf.loader.force",function(v) forceload=v end)
registerdirective("fonts.otf.loader.syncspace",function(v) syncspace=v end)
registerdirective("fonts.otf.loader.forcenotdef",function(v) forcenotdef=v end)
local ordered_enhancers={
  "check extra features",
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
  local featurefile=nil
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
  local reload=not data or data.size~=size or data.time~=time or data.tableversion~=otfreaders.tableversion
  if forceload then
    report_otf("forced reload of %a due to hard coded flag",filename)
    reload=true
  end
   if reload then
    report_otf("loading %a, hash %a",filename,hash)
    starttiming(otfreaders)
    data=otfreaders.loadfont(filename,sub or 1)
    if data then
      local resources=data.resources
      local svgshapes=resources.svgshapes
      if svgshapes then
        resources.svgshapes=nil
        if otf.svgenabled then
          local timestamp=os.date()
          containers.write(otf.svgcache,hash,{
            svgshapes=svgshapes,
            timestamp=timestamp,
          })
          data.properties.svg={
            hash=hash,
            timestamp=timestamp,
          }
        end
      end
      otfreaders.compact(data)
      otfreaders.rehash(data,"unicodes")
      otfreaders.addunicodetable(data)
      otfreaders.extend(data)
      otfreaders.pack(data)
      report_otf("loading done")
      report_otf("saving %a in cache",filename)
      data=containers.write(otf.cache,hash,data)
      if cleanup>1 then
        collectgarbage("collect")
      end
      stoptiming(otfreaders)
      if elapsedtime then
        report_otf("loading, optimizing, packing and caching time %s",elapsedtime(otfreaders))
      end
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
    otfreaders.unpack(data)
    otfreaders.expand(data) 
    otfreaders.addunicodetable(data)
    enhancers.apply(data,filename,data)
    if applyruntimefixes then
      applyruntimefixes(filename,data)
    end
    data.metadata.math=data.resources.mathconstants
  end
  return data
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
    local properties=derivetable(data.properties)
    local descriptions=derivetable(data.descriptions)
    local goodies=derivetable(data.goodies)
    local characters={}
    local parameters={}
    local mathparameters={}
    local resources=data.resources
    local unicodes=resources.unicodes
    local spaceunits=500
    local spacer="space"
    local designsize=metadata.designsize or 100
    local minsize=metadata.minsize or designsize
    local maxsize=metadata.maxsize or designsize
    local mathspecs=metadata.math
    if designsize==0 then
      designsize=100
      minsize=100
      maxsize=100
    end
    if mathspecs then
      for name,value in next,mathspecs do
        mathparameters[name]=value
      end
    end
    for unicode in next,data.descriptions do 
      characters[unicode]={}
    end
    if mathspecs then
      for unicode,character in next,characters do
        local d=descriptions[unicode]
        local m=d.math
        if m then
          local italic=m.italic
          local vitalic=m.vitalic
          local variants=m.hvariants
          local parts=m.hparts
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
            italic=m.hitalic
          end
          local variants=m.vvariants
          local parts=m.vparts
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
          if italic and italic~=0 then
            character.italic=italic
          end
          if vitalic and vitalic~=0 then
            character.vert_italic=vitalic
          end
          local accent=m.accent 
          if accent then
            character.accent=accent
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
    local psname=fontname or fullname
    local units=metadata.units or 1000
    if units==0 then 
      units=1000 
      metadata.units=1000
      report_otf("changing %a units to %a",0,units)
    end
    local monospaced=metadata.monospaced
    local charwidth=metadata.averagewidth 
    local charxheight=metadata.xheight 
    local italicangle=metadata.italicangle
    local hasitalics=metadata.hasitalics
    properties.monospaced=monospaced
    properties.hasitalics=hasitalics
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
    spaceunits=tonumber(spaceunits) or units/2
    parameters.slant=0
    parameters.space=spaceunits      
    parameters.space_stretch=1*units/2  
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
      local x=0x0078
      if x then
        local x=descriptions[x]
        if x then
          parameters.x_height=x.height
        end
      end
    end
    parameters.designsize=(designsize/10)*65536
    parameters.minsize=(minsize/10)*65536
    parameters.maxsize=(maxsize/10)*65536
    parameters.ascender=abs(metadata.ascender or 0)
    parameters.descender=abs(metadata.descender or 0)
    parameters.units=units
    properties.space=spacer
    properties.encodingbytes=2
    properties.format=data.format or formats.otf
    properties.noglyphnames=true
    properties.filename=filename
    properties.fontname=fontname
    properties.fullname=fullname
    properties.psname=psname
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
local converters={
  woff={
    cachename="webfonts",
    action=otf.readers.woff2otf,
  }
}
local function checkconversion(specification)
  local filename=specification.filename
  local converter=converters[lower(file.suffix(filename))]
  if converter then
    local base=file.basename(filename)
    local name=file.removesuffix(base)
    local attr=lfs.attributes(filename)
    local size=attr and attr.size or 0
    local time=attr and attr.modification or 0
    if size>0 then
      local cleanname=containers.cleanname(name)
      local cachename=caches.setfirstwritablefile(cleanname,converter.cachename)
      if not io.exists(cachename) or (time~=lfs.attributes(cachename).modification) then
        report_otf("caching font %a in %a",filename,cachename)
        converter.action(filename,cachename) 
        lfs.touch(cachename,time,time)
      end
      specification.filename=cachename
    end
  end
end
local function otftotfm(specification)
  local cache_id=specification.hash
  local tfmdata=containers.read(constructors.cache,cache_id)
  if not tfmdata then
    checkconversion(specification) 
    local name=specification.name
    local sub=specification.sub
    local subindex=specification.subindex
    local filename=specification.filename
    local features=specification.features.normal
    local rawdata=otf.load(filename,sub,features and features.featurefile)
    if rawdata and next(rawdata) then
      local descriptions=rawdata.descriptions
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
  if not kind then
    return
  end
  if not script then
    script=default
  end
  if not language then
    language=default
  end
  local lookupcache=rawdata.lookupcache
  if not lookupcache then
    lookupcache={}
    rawdata.lookupcache=lookupcache
  end
  local kindlookup=lookupcache[kind]
  if not kindlookup then
    kindlookup={}
    lookupcache[kind]=kindlookup
  end
  local scriptlookup=kindlookup[script]
  if not scriptlookup then
    scriptlookup={}
    kindlookup[script]=scriptlookup
  end
  local languagelookup=scriptlookup[language]
  if not languagelookup then
    local sequences=rawdata.resources.sequences
    local featuremap={}
    local featurelist={}
    if sequences then
      for s=1,#sequences do
        local sequence=sequences[s]
        local features=sequence.features
        if features then
          features=features[kind]
          if features then
            features=features[script] or features[wildcard]
            if features then
              features=features[language] or features[wildcard]
              if features then
                if not featuremap[sequence] then
                  featuremap[sequence]=true
                  featurelist[#featurelist+1]=sequence
                end
              end
            end
          end
        end
      end
      if #featurelist==0 then
        featuremap,featurelist=false,false
      end
    else
      featuremap,featurelist=false,false
    end
    languagelookup={ featuremap,featurelist }
    scriptlookup[language]=languagelookup
  end
  return unpack(languagelookup)
end
local function getgsub(tfmdata,k,kind,value)
  local shared=tfmdata.shared
  local rawdata=shared and shared.rawdata
  if rawdata then
    local sequences=rawdata.resources.sequences
    if sequences then
      local properties=tfmdata.properties
      local validlookups,lookuplist=otf.collectlookups(rawdata,kind,properties.script,properties.language)
      if validlookups then
        local choice=tonumber(value) or 1 
        for i=1,#lookuplist do
          local lookup=lookuplist[i]
          local steps=lookup.steps
          local nofsteps=lookup.nofsteps
          for i=1,nofsteps do
            local coverage=steps[i].coverage
            if coverage then
              local found=coverage[k]
              if found then
                return found,lookup.type
              end
            end
          end
        end
      end
    end
  end
end
otf.getgsub=getgsub 
function otf.getsubstitution(tfmdata,k,kind,value)
  local found,kind=getgsub(tfmdata,k,kind,value)
  if not found then
  elseif kind=="gsub_single" then
    return found
  elseif kind=="gsub_alternate" then
    local choice=tonumber(value) or 1 
    return found[choice] or found[1] or k
  end
  return k
end
otf.getalternate=otf.getsubstitution
function otf.getmultiple(tfmdata,k,kind)
  local found,kind=getgsub(tfmdata,k,kind)
  if found and kind=="gsub_multiple" then
    return found
  end
  return { k }
end
function otf.getkern(tfmdata,left,right,kind)
  local kerns=getgsub(tfmdata,left,kind or "kern",true) 
  if kerns then
    local found=kerns[right]
    local kind=type(found)
    if kind=="table" then
      found=found[1][3] 
    elseif kind~="number" then
      found=false
    end
    if found then
      return found*tfmdata.parameters.factor
    end
  end
  return 0
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
function readers.otf(specification) return opentypereader(specification,"otf") end
function readers.ttf(specification) return opentypereader(specification,"ttf") end
function readers.ttc(specification) return opentypereader(specification,"ttf") end
function readers.woff(specification)
  checkconversion(specification)
  opentypereader(specification,"")
end
function otf.scriptandlanguage(tfmdata,attr)
  local properties=tfmdata.properties
  return properties.script or "dflt",properties.language or "dflt"
end
local function justset(coverage,unicode,replacement)
  coverage[unicode]=replacement
end
otf.coverup={
  stepkey="steps",
  actions={
    chainsubstitution=justset,
    chainposition=justset,
    substitution=justset,
    alternate=justset,
    multiple=justset,
    kern=justset,
    pair=justset,
    ligature=function(coverage,unicode,ligature)
      local first=ligature[1]
      local tree=coverage[first]
      if not tree then
        tree={}
        coverage[first]=tree
      end
      for i=2,#ligature do
        local l=ligature[i]
        local t=tree[l]
        if not t then
          t={}
          tree[l]=t
        end
        tree=t
      end
      tree.ligature=unicode
    end,
  },
  register=function(coverage,featuretype,format)
    return {
      format=format,
      coverage=coverage,
    }
  end
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-oto']={ 
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local concat,unpack=table.concat,table.unpack
local insert,remove=table.insert,table.remove
local format,gmatch,gsub,find,match,lower,strip=string.format,string.gmatch,string.gsub,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring,rawget=type,next,tonumber,tostring,rawget
local trace_baseinit=false trackers.register("otf.baseinit",function(v) trace_baseinit=v end)
local trace_singles=false trackers.register("otf.singles",function(v) trace_singles=v end)
local trace_multiples=false trackers.register("otf.multiples",function(v) trace_multiples=v end)
local trace_alternatives=false trackers.register("otf.alternatives",function(v) trace_alternatives=v end)
local trace_ligatures=false trackers.register("otf.ligatures",function(v) trace_ligatures=v end)
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
local function cref(feature,sequence)
  return formatters["feature %a, type %a, chain lookup %a"](feature,sequence.type,sequence.name)
end
local function report_alternate(feature,sequence,descriptions,unicode,replacement,value,comment)
  report_prepare("%s: base alternate %s => %s (%S => %S)",
    cref(feature,sequence),
    gref(descriptions,unicode),
    replacement and gref(descriptions,replacement),
    value,
    comment)
end
local function report_substitution(feature,sequence,descriptions,unicode,substitution)
  report_prepare("%s: base substitution %s => %S",
    cref(feature,sequence),
    gref(descriptions,unicode),
    gref(descriptions,substitution))
end
local function report_ligature(feature,sequence,descriptions,unicode,ligature)
  report_prepare("%s: base ligature %s => %S",
    cref(feature,sequence),
    gref(descriptions,ligature),
    gref(descriptions,unicode))
end
local function report_kern(feature,sequence,descriptions,unicode,otherunicode,value)
  report_prepare("%s: base kern %s + %s => %S",
    cref(feature,sequence),
    gref(descriptions,unicode),
    gref(descriptions,otherunicode),
    value)
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
  properties.fullname=(properties.fullname or properties.name).."-"..base
  applied={}
end
local function registerbasefeature(feature,value)
  applied[#applied+1]=feature.."="..tostring(value)
end
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
local function make_2(present,tfmdata,characters,tree,name,preceding,unicode,done)
  for k,v in next,tree do
    if k=="ligature" then
      local character=characters[preceding]
      if not character then
        if trace_baseinit then
          report_prepare("weird ligature in lookup %a, current %C, preceding %C",sequence.name,v,preceding)
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
        local d=done[name]
        if not d then
          done[name]={ "dummy",v }
        else
          d[#d+1]=v
        end
      end
    else
      local code=present[name] or unicode
      local name=name.."_"..k
      make_2(present,tfmdata,characters,v,name,code,k,done)
    end
  end
end
local function preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local resources=tfmdata.resources
  local changed=tfmdata.changed
  local ligatures={}
  local alternate=tonumber(value) or true and 1
  local defaultalt=otf.defaultbasealternate
  local trace_singles=trace_baseinit and trace_singles
  local trace_alternatives=trace_baseinit and trace_alternatives
  local trace_ligatures=trace_baseinit and trace_ligatures
  if not changed then
    changed={}
    tfmdata.changed=changed
  end
  for i=1,#lookuplist do
    local sequence=lookuplist[i]
    local steps=sequence.steps
    local kind=sequence.type
    if kind=="gsub_single" then
      for i=1,#steps do
        for unicode,data in next,steps[i].coverage do
          if not changed[unicode] then
            if trace_singles then
              report_substitution(feature,sequence,descriptions,unicode,data)
            end
            changed[unicode]=data
          end
        end
      end
    elseif kind=="gsub_alternate" then
      for i=1,#steps do
        for unicode,data in next,steps[i].coverage do
          if not changed[unicode] then
            local replacement=data[alternate]
            if replacement then
              changed[unicode]=replacement
              if trace_alternatives then
                report_alternate(feature,sequence,descriptions,unicode,replacement,value,"normal")
              end
            elseif defaultalt=="first" then
              replacement=data[1]
              changed[unicode]=replacement
              if trace_alternatives then
                report_alternate(feature,sequence,descriptions,unicode,replacement,value,defaultalt)
              end
            elseif defaultalt=="last" then
              replacement=data[#data]
              if trace_alternatives then
                report_alternate(feature,sequence,descriptions,unicode,replacement,value,defaultalt)
              end
            else
              if trace_alternatives then
                report_alternate(feature,sequence,descriptions,unicode,replacement,value,"unknown")
              end
            end
          end
        end
      end
    elseif kind=="gsub_ligature" then
      for i=1,#steps do
        for unicode,data in next,steps[i].coverage do
          ligatures[#ligatures+1]={ unicode,data,"" } 
          if trace_ligatures then
            report_ligature(feature,sequence,descriptions,unicode,data)
          end
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
      make_2(present,tfmdata,characters,tree,"ctx_"..unicode,unicode,unicode,done,sequence)
    end
  end
end
local function preparepositionings(tfmdata,feature,value,validlookups,lookuplist)
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local resources=tfmdata.resources
  local properties=tfmdata.properties
  local traceindeed=trace_baseinit and trace_kerns
  for i=1,#lookuplist do
    local sequence=lookuplist[i]
    local steps=sequence.steps
    local kind=sequence.type
    local format=sequence.format
    if kind=="gpos_pair" then
      for i=1,#steps do
        local step=steps[i]
        if step.format=="kern" then
          for unicode,data in next,steps[i].coverage do
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
                  report_kern(feature,sequence,descriptions,unicode,otherunicode,kern)
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
        else
          for unicode,data in next,steps[i].coverage do
            local character=characters[unicode]
            local kerns=character.kerns
            for otherunicode,kern in next,data do
              if not kern[2] and not (kerns and kerns[otherunicode]) then
                local kern=kern[1]
                if kern[1]~=0 or kern[2]~=0 or kern[4]~=0 then
                else
                  kern=kern[3]
                  if kern~=0 then
                    if kerns then
                      kerns[otherunicode]=kern
                    else
                      kerns={ [otherunicode]=kern }
                      character.kerns=kerns
                    end
                    if traceindeed then
                      report_kern(feature,sequence,descriptions,unicode,otherunicode,kern)
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
end
local function initializehashes(tfmdata)
end
local function featuresinitializer(tfmdata,value)
  if true then 
    local starttime=trace_preparing and os.clock()
    local features=tfmdata.shared.features
    local fullname=tfmdata.properties.fullname or "?"
    if features then
      initializehashes(tfmdata)
      local collectlookups=otf.collectlookups
      local rawdata=tfmdata.shared.rawdata
      local properties=tfmdata.properties
      local script=properties.script
      local language=properties.language
      local rawresources=rawdata.resources
      local rawfeatures=rawresources and rawresources.features
      local basesubstitutions=rawfeatures and rawfeatures.gsub
      local basepositionings=rawfeatures and rawfeatures.gpos
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
                local value=features[feature]
                if value then
                  local validlookups,lookuplist=collectlookups(rawdata,feature,script,language)
                  if not validlookups then
                  elseif basesubstitutions and basesubstitutions[feature] then
                    if trace_preparing then
                      report_prepare("filtering base %s feature %a for %a with value %a","sub",feature,fullname,value)
                    end
                    preparesubstitutions(tfmdata,feature,value,validlookups,lookuplist)
                    registerbasefeature(feature,value)
                  elseif basepositionings and basepositionings[feature] then
                    if trace_preparing then
                      report_prepare("filtering base %a feature %a for %a with value %a","pos",feature,fullname,value)
                    end
                    preparepositionings(tfmdata,feature,value,validlookups,lookuplist)
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
otf.basemodeinitializer=featuresinitializer

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otj']={
  version=1.001,
  comment="companion to font-lib.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files",
}
if not nodes.properties then return end
local next,rawget=next,rawget
local fastcopy=table.fastcopy
local registertracker=trackers.register
local trace_injections=false registertracker("fonts.injections",function(v) trace_injections=v end)
local trace_marks=false registertracker("fonts.injections.marks",function(v) trace_marks=v end)
local trace_cursive=false registertracker("fonts.injections.cursive",function(v) trace_cursive=v end)
local trace_spaces=false registertracker("fonts.injections.spaces",function(v) trace_spaces=v end)
local use_advance=false directives.register("fonts.injections.advance",function(v) use_advance=v end)
local report_injections=logs.reporter("fonts","injections")
local report_spaces=logs.reporter("fonts","spaces")
local attributes,nodes,node=attributes,nodes,node
fonts=fonts
local hashes=fonts.hashes
local fontdata=hashes.identifiers
nodes.injections=nodes.injections or {}
local injections=nodes.injections
local tracers=nodes.tracers
local setcolor=tracers and tracers.colors.set
local resetcolor=tracers and tracers.colors.reset
local nodecodes=nodes.nodecodes
local glyph_code=nodecodes.glyph
local disc_code=nodecodes.disc
local kern_code=nodecodes.kern
local glue_code=nodecodes.glue
local nuts=nodes.nuts
local nodepool=nuts.pool
local newkern=nodepool.kern
local tonode=nuts.tonode
local tonut=nuts.tonut
local getfield=nuts.getfield
local setfield=nuts.setfield
local getnext=nuts.getnext
local getprev=nuts.getprev
local getid=nuts.getid
local getfont=nuts.getfont
local getsubtype=nuts.getsubtype
local getchar=nuts.getchar
local getboth=nuts.getboth
local ischar=nuts.is_char
local getdisc=nuts.getdisc
local setdisc=nuts.setdisc
local traverse_id=nuts.traverse_id
local traverse_char=nuts.traverse_char
local insert_node_before=nuts.insert_before
local insert_node_after=nuts.insert_after
local properties=nodes.properties.data
function injections.installnewkern(nk)
  newkern=nk or newkern
end
local nofregisteredkerns=0
local nofregisteredpairs=0
local nofregisteredmarks=0
local nofregisteredcursives=0
local keepregisteredcounts=false
function injections.keepcounts()
  keepregisteredcounts=true
end
function injections.resetcounts()
  nofregisteredkerns=0
  nofregisteredpairs=0
  nofregisteredmarks=0
  nofregisteredcursives=0
  keepregisteredcounts=false
end
function injections.reset(n)
  local p=rawget(properties,n)
  if p then
    p.injections=false 
  else
    properties[n]=false 
  end
end
function injections.copy(target,source)
  local sp=rawget(properties,source)
  if sp then
    local tp=rawget(properties,target)
    local si=sp.injections
    if si then
      si=fastcopy(si)
      if tp then
        tp.injections=si
      else
        propertydata[target]={
          injections=si,
        }
      end
    elseif tp then
      tp.injections=false 
    else
      properties[target]={ injections={} }
    end
  else
    local tp=rawget(properties,target)
    if tp then
      tp.injections=false 
    else
      properties[target]=false 
    end
  end
end
function injections.setligaindex(n,index)
  local p=rawget(properties,n)
  if p then
    local i=p.injections
    if i then
      i.ligaindex=index
    else
      p.injections={
        ligaindex=index
      }
    end
  else
    properties[n]={
      injections={
        ligaindex=index
      }
    }
  end
end
function injections.getligaindex(n,default)
  local p=rawget(properties,n)
  if p then
    local i=p.injections
    if i then
      return i.ligaindex or default
    end
  end
  return default
end
function injections.setcursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext) 
  local dx=factor*(exit[1]-entry[1])
  local dy=-factor*(exit[2]-entry[2])
  local ws=tfmstart.width
  local wn=tfmnext.width
  nofregisteredcursives=nofregisteredcursives+1
  if rlmode<0 then
    dx=-(dx+wn)
  else
    dx=dx-ws
  end
  if dx==0 then
    dx=0
  end
  local p=rawget(properties,start)
  if p then
    local i=p.injections
    if i then
      i.cursiveanchor=true
    else
      p.injections={
        cursiveanchor=true,
      }
    end
  else
    properties[start]={
      injections={
        cursiveanchor=true,
      },
    }
  end
  local p=rawget(properties,nxt)
  if p then
    local i=p.injections
    if i then
      i.cursivex=dx
      i.cursivey=dy
    else
      p.injections={
        cursivex=dx,
        cursivey=dy,
      }
    end
  else
    properties[nxt]={
      injections={
        cursivex=dx,
        cursivey=dy,
      },
    }
  end
  return dx,dy,nofregisteredcursives
end
function injections.setpair(current,factor,rlmode,r2lflag,spec,injection) 
  local x=factor*spec[1]
  local y=factor*spec[2]
  local w=factor*spec[3]
  local h=factor*spec[4]
  if x~=0 or w~=0 or y~=0 or h~=0 then 
    local yoffset=y-h
    local leftkern=x   
    local rightkern=w-x 
    if leftkern~=0 or rightkern~=0 or yoffset~=0 then
      nofregisteredpairs=nofregisteredpairs+1
      if rlmode and rlmode<0 then
        leftkern,rightkern=rightkern,leftkern
      end
      if not injection then
        injection="injections"
      end
      local p=rawget(properties,current)
      if p then
        local i=rawget(p,injection)
        if i then
          if leftkern~=0 then
            i.leftkern=(i.leftkern or 0)+leftkern
          end
          if rightkern~=0 then
            i.rightkern=(i.rightkern or 0)+rightkern
          end
          if yoffset~=0 then
            i.yoffset=(i.yoffset or 0)+yoffset
          end
        elseif leftkern~=0 or rightkern~=0 then
          p[injection]={
            leftkern=leftkern,
            rightkern=rightkern,
            yoffset=yoffset,
          }
        else
          p[injection]={
            yoffset=yoffset,
          }
        end
      elseif leftkern~=0 or rightkern~=0 then
        properties[current]={
          [injection]={
            leftkern=leftkern,
            rightkern=rightkern,
            yoffset=yoffset,
          },
        }
      else
        properties[current]={
          [injection]={
            yoffset=yoffset,
          },
        }
      end
      return x,y,w,h,nofregisteredpairs
     end
  end
  return x,y,w,h 
end
function injections.setkern(current,factor,rlmode,x,injection)
  local dx=factor*x
  if dx~=0 then
    nofregisteredkerns=nofregisteredkerns+1
    local p=rawget(properties,current)
    if not injection then
      injection="injections"
    end
    if p then
      local i=rawget(p,injection)
      if i then
        i.leftkern=dx+(i.leftkern or 0)
      else
        p[injection]={
          leftkern=dx,
        }
      end
    else
      properties[current]={
        [injection]={
          leftkern=dx,
        },
      }
    end
    return dx,nofregisteredkerns
  else
    return 0,0
  end
end
function injections.setmark(start,base,factor,rlmode,ba,ma,tfmbase,mkmk) 
  local dx,dy=factor*(ba[1]-ma[1]),factor*(ba[2]-ma[2])
  nofregisteredmarks=nofregisteredmarks+1
  if rlmode>=0 then
    dx=tfmbase.width-dx 
  end
  local p=rawget(properties,start)
  if p then
    local i=p.injections
    if i then
      if i.markmark then
      else
        i.markx=dx
        i.marky=dy
        i.markdir=rlmode or 0
        i.markbase=nofregisteredmarks
        i.markbasenode=base
        i.markmark=mkmk
      end
    else
      p.injections={
        markx=dx,
        marky=dy,
        markdir=rlmode or 0,
        markbase=nofregisteredmarks,
        markbasenode=base,
        markmark=mkmk,
      }
    end
  else
    properties[start]={
      injections={
        markx=dx,
        marky=dy,
        markdir=rlmode or 0,
        markbase=nofregisteredmarks,
        markbasenode=base,
        markmark=mkmk,
      },
    }
  end
  return dx,dy,nofregisteredmarks
end
local function dir(n)
  return (n and n<0 and "r-to-l") or (n and n>0 and "l-to-r") or "unset"
end
local function showchar(n,nested)
  local char=getchar(n)
  report_injections("%wfont %s, char %U, glyph %c",nested and 2 or 0,getfont(n),char,char)
end
local function show(n,what,nested,symbol)
  if n then
    local p=rawget(properties,n)
    if p then
      local i=rawget(p,what)
      if i then
        local leftkern=i.leftkern or 0
        local rightkern=i.rightkern or 0
        local yoffset=i.yoffset  or 0
        local markx=i.markx   or 0
        local marky=i.marky   or 0
        local markdir=i.markdir  or 0
        local markbase=i.markbase or 0
        local cursivex=i.cursivex or 0
        local cursivey=i.cursivey or 0
        local ligaindex=i.ligaindex or 0
        local cursbase=i.cursiveanchor
        local margin=nested and 4 or 2
        if rightkern~=0 or yoffset~=0 then
          report_injections("%w%s pair: lx %p, rx %p, dy %p",margin,symbol,leftkern,rightkern,yoffset)
        elseif leftkern~=0 then
          report_injections("%w%s kern: dx %p",margin,symbol,leftkern)
        end
        if markx~=0 or marky~=0 or markbase~=0 then
          report_injections("%w%s mark: dx %p, dy %p, dir %s, base %s",margin,symbol,markx,marky,markdir,markbase~=0 and "yes" or "no")
        end
        if cursivex~=0 or cursivey~=0 then
          if cursbase then
            report_injections("%w%s curs: base dx %p, dy %p",margin,symbol,cursivex,cursivey)
          else
            report_injections("%w%s curs: dx %p, dy %p",margin,symbol,cursivex,cursivey)
          end
        elseif cursbase then
          report_injections("%w%s curs: base",margin,symbol)
        end
        if ligaindex~=0 then
          report_injections("%w%s liga: index %i",margin,symbol,ligaindex)
        end
      end
    end
  end
end
local function showsub(n,what,where)
  report_injections("begin subrun: %s",where)
  for n in traverse_id(glyph_code,n) do
    showchar(n,where)
    show(n,what,where," ")
  end
  report_injections("end subrun")
end
local function trace(head,where)
  report_injections("begin run %s: %s kerns, %s pairs, %s marks and %s cursives registered",
    where or "",nofregisteredkerns,nofregisteredpairs,nofregisteredmarks,nofregisteredcursives)
  local n=head
  while n do
    local id=getid(n)
    if id==glyph_code then
      showchar(n)
      show(n,"injections",false," ")
      show(n,"preinjections",false,"<")
      show(n,"postinjections",false,">")
      show(n,"replaceinjections",false,"=")
      show(n,"emptyinjections",false,"*")
    elseif id==disc_code then
      local pre,post,replace=getdisc(n)
      if pre then
        showsub(pre,"preinjections","pre")
      end
      if post then
        showsub(post,"postinjections","post")
      end
      if replace then
        showsub(replace,"replaceinjections","replace")
      end
      show(n,"emptyinjections",false,"*")
    end
    n=getnext(n)
  end
  report_injections("end run")
end
local function show_result(head)
  local current=head
  local skipping=false
  while current do
    local id=getid(current)
    if id==glyph_code then
      report_injections("char: %C, width %p, xoffset %p, yoffset %p",
        getchar(current),getfield(current,"width"),getfield(current,"xoffset"),getfield(current,"yoffset"))
      skipping=false
    elseif id==kern_code then
      report_injections("kern: %p",getfield(current,"kern"))
      skipping=false
    elseif not skipping then
      report_injections()
      skipping=true
    end
    current=getnext(current)
  end
end
local function inject_kerns_only(head,where)
  head=tonut(head)
  if trace_injections then
    trace(head,"kerns")
  end
  local current=head
  local prev=nil
  local next=nil
  local prevdisc=nil
  local prevglyph=nil
  local pre=nil 
  local post=nil 
  local replace=nil 
  local pretail=nil 
  local posttail=nil 
  local replacetail=nil 
  while current do
    local id=getid(current)
    local next=getnext(current)
    if id==glyph_code then
      if getsubtype(current)<256 then
        local p=rawget(properties,current)
        if p then
          local i=p.injections
          if i then
            local leftkern=i.leftkern
            if leftkern and leftkern~=0 then
              if use_advance then
                setfield(current,"xoffset",leftkern)
                setfield(current,"xadvance",leftkern)
              else
                insert_node_before(head,current,newkern(leftkern))
              end
            end
          end
          if prevdisc then
            local done=false
            if post then
              local i=p.postinjections
              if i then
                local leftkern=i.leftkern
                if leftkern and leftkern~=0 then
                  if use_advance then
                    setfield(post,"xadvance",leftkern)
                  else
                    insert_node_after(post,posttail,newkern(leftkern))
                    done=true
                  end
                end
              end
            end
            if replace then
              local i=p.replaceinjections
              if i then
                local leftkern=i.leftkern
                if leftkern and leftkern~=0 then
                  if use_advance then
                    setfield(replace,"xadvance",leftkern)
                  else
                    insert_node_after(replace,replacetail,newkern(leftkern))
                    done=true
                  end
                end
              end
            else
              local i=p.emptyinjections
              if i then
                local leftkern=i.leftkern
                if leftkern and leftkern~=0 then
                  setfield(prev,"replace",newkern(leftkern)) 
                end
              end
            end
            if done then
              setdisc(prevdisc,pre,post,replace)
            end
          end
        end
      end
      prevdisc=nil
      prevglyph=current
    elseif id==disc_code then
      pre,post,replace,pretail,posttail,replacetail=getdisc(current,true)
      local done=false
      if pre then
        for n in traverse_char(pre) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.preinjections
            if i then
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                if use_advance then
                  setfield(pre,"xoffset",leftkern)
                  setfield(pre,"xadvance",leftkern)
                else
                  pre=insert_node_before(pre,n,newkern(leftkern))
                  done=true
                end
              end
            end
          end
        end
      end
      if post then
        for n in traverse_char(post) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.postinjections
            if i then
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                if use_advance then
                  setfield(post,"xoffset",leftkern)
                  setfield(post,"xadvance",leftkern)
                else
                  post=insert_node_before(post,n,newkern(leftkern))
                  done=true
                end
              end
            end
          end
        end
      end
      if replace then
        for n in traverse_char(replace) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.replaceinjections
            if i then
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                if use_advance then
                  setfield(replace,"xoffset",leftkern)
                  setfield(replace,"xadvance",leftkern)
                else
                  replace=insert_node_before(replace,n,newkern(leftkern))
                  done=true
                end
              end
            end
          end
        end
      end
      if done then
        setdisc(current,pre,post,replace)
      end
      prevglyph=nil
      prevdisc=current
    else
      prevglyph=nil
      prevdisc=nil
    end
    prev=current
    current=next
  end
  if keepregisteredcounts then
    keepregisteredcounts=false
  else
    nofregisteredkerns=0
  end
  return tonode(head),true
end
local function inject_pairs_only(head,where)
  head=tonut(head)
  if trace_injections then
    trace(head,"pairs")
  end
  local current=head
  local prev=nil
  local next=nil
  local prevdisc=nil
  local prevglyph=nil
  local pre=nil 
  local post=nil 
  local replace=nil 
  local pretail=nil 
  local posttail=nil 
  local replacetail=nil 
  while current do
    local id=getid(current)
    local next=getnext(current)
    if id==glyph_code then
      if getsubtype(current)<256 then
        local p=rawget(properties,current)
        if p then
          local i=p.injections
          if i then
            local yoffset=i.yoffset
            if yoffset and yoffset~=0 then
              setfield(current,"yoffset",yoffset)
            end
            local leftkern=i.leftkern
            if leftkern and leftkern~=0 then
              head=insert_node_before(head,current,newkern(leftkern))
            end
            local rightkern=i.rightkern
            if rightkern and rightkern~=0 then
              insert_node_after(head,current,newkern(rightkern))
            end
          else
            local i=p.emptyinjections
            if i then
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                if next and getid(next)==disc_code then
                  if replace then
                  else
                    setfield(next,"replace",newkern(rightkern)) 
                  end
                end
              end
            end
          end
          if prevdisc then
            local done=false
            if post then
              local i=p.postinjections
              if i then
                local leftkern=i.leftkern
                if leftkern and leftkern~=0 then
                  insert_node_after(post,posttail,newkern(leftkern))
                  done=true
                end
              end
            end
            if replace then
              local i=p.replaceinjections
              if i then
                local leftkern=i.leftkern
                if leftkern and leftkern~=0 then
                  insert_node_after(replace,replacetail,newkern(leftkern))
                  done=true
                end
              end
            else
              local i=p.emptyinjections
              if i then
                local leftkern=i.leftkern
                if leftkern and leftkern~=0 then
                  setfield(prev,"replace",newkern(leftkern)) 
                end
              end
            end
            if done then
              setdisc(prevdisc,pre,post,replace)
            end
          end
        end
      end
      prevdisc=nil
      prevglyph=current
    elseif id==disc_code then
      pre,post,replace,pretail,posttail,replacetail=getdisc(current,true)
      local done=false
      if pre then
        for n in traverse_char(pre) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.preinjections
            if i then
              local yoffset=i.yoffset
              if yoffset and yoffset~=0 then
                setfield(n,"yoffset",yoffset)
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                pre=insert_node_before(pre,n,newkern(leftkern))
                done=true
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(pre,n,newkern(rightkern))
                done=true
              end
            end
          end
        end
      end
      if post then
        for n in traverse_char(post) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.postinjections
            if i then
              local yoffset=i.yoffset
              if yoffset and yoffset~=0 then
                setfield(n,"yoffset",yoffset)
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                post=insert_node_before(post,n,newkern(leftkern))
                done=true
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(post,n,newkern(rightkern))
                done=true
              end
            end
          end
        end
      end
      if replace then
        for n in traverse_char(replace) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.replaceinjections
            if i then
              local yoffset=i.yoffset
              if yoffset and yoffset~=0 then
                setfield(n,"yoffset",yoffset)
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                replace=insert_node_before(replace,n,newkern(leftkern))
                done=true
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(replace,n,newkern(rightkern))
                done=true
              end
            end
          end
        end
      end
      if prevglyph then
        if pre then
          local p=rawget(properties,prevglyph)
          if p then
            local i=p.preinjections
            if i then
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                pre=insert_node_before(pre,pre,newkern(rightkern))
                done=true
              end
            end
          end
        end
        if replace then
          local p=rawget(properties,prevglyph)
          if p then
            local i=p.replaceinjections
            if i then
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                replace=insert_node_before(replace,replace,newkern(rightkern))
                done=true
              end
            end
          end
        end
      end
      if done then
        setdisc(current,pre,post,replace)
      end
      prevglyph=nil
      prevdisc=current
    else
      prevglyph=nil
      prevdisc=nil
    end
    prev=current
    current=next
  end
  if keepregisteredcounts then
    keepregisteredcounts=false
  else
    nofregisteredkerns=0
  end
  return tonode(head),true
end
local function showoffset(n,flag)
  local o=getfield(n,"xoffset")
  if o==0 then
    o=getfield(n,"yoffset")
  end
  if o~=0 then
    setcolor(n,flag and "darkred" or "darkgreen")
  else
    resetcolor(n)
  end
end
local function inject_everything(head,where)
  head=tonut(head)
  if trace_injections then
    trace(head,"everything")
  end
  local hascursives=nofregisteredcursives>0
  local hasmarks=nofregisteredmarks>0
  local current=head
  local last=nil
  local font=font
  local markdata=nil
  local prev=nil
  local next=nil
  local prevdisc=nil
  local prevglyph=nil
  local pre=nil 
  local post=nil 
  local replace=nil 
  local pretail=nil 
  local posttail=nil 
  local replacetail=nil
  local cursiveanchor=nil
  local minc=0
  local maxc=0
  local glyphs={}
  local marks={}
  local nofmarks=0
  local function processmark(p,n,pn) 
    local px=getfield(p,"xoffset")
    local ox=0
    local rightkern=nil
    local pp=rawget(properties,p)
    if pp then
      pp=pp.injections
      if pp then
        rightkern=pp.rightkern
      end
    end
    if rightkern then 
      if pn.markdir<0 then
        ox=px-pn.markx-rightkern
      else
        if false then
          local leftkern=pp.leftkern
          if leftkern then
            ox=px-pn.markx-leftkern
          else
            ox=px-pn.markx
          end
        else
          ox=px-pn.markx
        end
      end
    else
        ox=px-pn.markx
      local wn=getfield(n,"width") 
      if wn~=0 then
        pn.leftkern=-wn/2
        pn.rightkern=-wn/2
      end
    end
    local oy=getfield(n,"yoffset")+getfield(p,"yoffset")+pn.marky
    setfield(n,"xoffset",ox)
    setfield(n,"yoffset",oy)
    if trace_marks then
      showoffset(n,true)
    end
  end
  while current do
    local id=getid(current)
    local next=getnext(current)
    if id==glyph_code then
      if getsubtype(current)<256 then
        local p=rawget(properties,current)
        if p then
          local i=p.injections
          if i then
            local pm=i.markbasenode
            if pm then
              nofmarks=nofmarks+1
              marks[nofmarks]=current
            else
local yoffset=i.yoffset
if yoffset and yoffset~=0 then
  setfield(current,"yoffset",yoffset)
end
              if hascursives then
                local cursivex=i.cursivex
                if cursivex then
                  if cursiveanchor then
                    if cursivex~=0 then
                      i.leftkern=(i.leftkern or 0)+cursivex
                    end
                    if maxc==0 then
                      minc=1
                      maxc=1
                      glyphs[1]=cursiveanchor
                    else
                      maxc=maxc+1
                      glyphs[maxc]=cursiveanchor
                    end
                    properties[cursiveanchor].cursivedy=i.cursivey 
                    last=current
                  else
                    maxc=0
                  end
                elseif maxc>0 then
                  local ny=getfield(current,"yoffset")
                  for i=maxc,minc,-1 do
                    local ti=glyphs[i]
                    ny=ny+properties[ti].cursivedy
                    setfield(ti,"yoffset",ny) 
                    if trace_cursive then
                      showoffset(ti)
                    end
                  end
                  maxc=0
                  cursiveanchor=nil
                end
                if i.cursiveanchor then
                  cursiveanchor=current 
                else
                  if maxc>0 then
                    local ny=getfield(current,"yoffset")
                    for i=maxc,minc,-1 do
                      local ti=glyphs[i]
                      ny=ny+properties[ti].cursivedy
                      setfield(ti,"yoffset",ny) 
                      if trace_cursive then
                        showoffset(ti)
                      end
                    end
                    maxc=0
                  end
                  cursiveanchor=nil
                end
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                insert_node_before(head,current,newkern(leftkern))
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(head,current,newkern(rightkern))
              end
            end
          else
            local i=p.emptyinjections
            if i then
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                if next and getid(next)==disc_code then
                  if replace then
                  else
                    setfield(next,"replace",newkern(rightkern)) 
                  end
                end
              end
            end
          end
          if prevdisc then
            if p then
              local done=false
              if post then
                local i=p.postinjections
                if i then
                  local leftkern=i.leftkern
                  if leftkern and leftkern~=0 then
                    insert_node_after(post,posttail,newkern(leftkern))
                    done=true
                  end
                end
              end
              if replace then
                local i=p.replaceinjections
                if i then
                  local leftkern=i.leftkern
                  if leftkern and leftkern~=0 then
                    insert_node_after(replace,replacetail,newkern(leftkern))
                    done=true
                  end
                end
              else
                local i=p.emptyinjections
                if i then
                  local leftkern=i.leftkern
                  if leftkern and leftkern~=0 then
                    setfield(prev,"replace",newkern(leftkern)) 
                  end
                end
              end
              if done then
                setdisc(prevdisc,pre,post,replace)
              end
            end
          end
        else
          if hascursives and maxc>0 then
            local ny=getfield(current,"yoffset")
            for i=maxc,minc,-1 do
              local ti=glyphs[i]
              ny=ny+properties[ti].cursivedy
              setfield(ti,"yoffset",getfield(ti,"yoffset")+ny) 
            end
            maxc=0
            cursiveanchor=nil
          end
        end
      end
      prevdisc=nil
      prevglyph=current
    elseif id==disc_code then
      pre,post,replace,pretail,posttail,replacetail=getdisc(current,true)
      local done=false
      if pre then
        for n in traverse_char(pre) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.preinjections
            if i then
              local yoffset=i.yoffset
              if yoffset and yoffset~=0 then
                setfield(n,"yoffset",yoffset)
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                pre=insert_node_before(pre,n,newkern(leftkern))
                done=true
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(pre,n,newkern(rightkern))
                done=true
              end
              if hasmarks then
                local pm=i.markbasenode
                if pm then
                  processmark(pm,current,i)
                end
              end
            end
          end
        end
      end
      if post then
        for n in traverse_char(post) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.postinjections
            if i then
              local yoffset=i.yoffset
              if yoffset and yoffset~=0 then
                setfield(n,"yoffset",yoffset)
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                post=insert_node_before(post,n,newkern(leftkern))
                done=true
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(post,n,newkern(rightkern))
                done=true
              end
              if hasmarks then
                local pm=i.markbasenode
                if pm then
                  processmark(pm,current,i)
                end
              end
            end
          end
        end
      end
      if replace then
        for n in traverse_char(replace) do
          local p=rawget(properties,n)
          if p then
            local i=p.injections or p.replaceinjections
            if i then
              local yoffset=i.yoffset
              if yoffset and yoffset~=0 then
                setfield(n,"yoffset",yoffset)
              end
              local leftkern=i.leftkern
              if leftkern and leftkern~=0 then
                replace=insert_node_before(replace,n,newkern(leftkern))
                done=true
              end
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                insert_node_after(replace,n,newkern(rightkern))
                done=true
              end
              if hasmarks then
                local pm=i.markbasenode
                if pm then
                  processmark(pm,current,i)
                end
              end
            end
          end
        end
      end
      if prevglyph then
        if pre then
          local p=rawget(properties,prevglyph)
          if p then
            local i=p.preinjections
            if i then
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                pre=insert_node_before(pre,pre,newkern(rightkern))
                done=true
              end
            end
          end
        end
        if replace then
          local p=rawget(properties,prevglyph)
          if p then
            local i=p.replaceinjections
            if i then
              local rightkern=i.rightkern
              if rightkern and rightkern~=0 then
                replace=insert_node_before(replace,replace,newkern(rightkern))
                done=true
              end
            end
          end
        end
      end
      if done then
        setdisc(current,pre,post,replace)
      end
      prevglyph=nil
      prevdisc=current
    else
      prevglyph=nil
      prevdisc=nil
    end
    prev=current
    current=next
  end
  if hascursives and maxc>0 then
    local ny=getfield(last,"yoffset")
    for i=maxc,minc,-1 do
      local ti=glyphs[i]
      ny=ny+properties[ti].cursivedy
      setfield(ti,"yoffset",ny) 
      if trace_cursive then
        showoffset(ti)
      end
    end
  end
  if nofmarks>0 then
    for i=1,nofmarks do
      local m=marks[i]
      local p=rawget(properties,m)
      local i=p.injections
      local b=i.markbasenode
      processmark(b,m,i)
    end
  elseif hasmarks then
  end
  if keepregisteredcounts then
    keepregisteredcounts=false
  else
    nofregisteredkerns=0
    nofregisteredpairs=0
    nofregisteredmarks=0
    nofregisteredcursives=0
  end
  return tonode(head),true
end
local triggers=false
function nodes.injections.setspacekerns(font,sequence)
  if triggers then
    triggers[font]=sequence
  else
    triggers={ [font]=sequence }
  end
end
local getthreshold
if context then
  local threshold=1 
  local parameters=fonts.hashes.parameters
  directives.register("otf.threshold",function(v) threshold=tonumber(v) or 1 end)
  getthreshold=function(font)
    local p=parameters[font]
    local f=p.factor
    local s=p.spacing
    local t=threshold*(s and s.width or p.space or 0)-2
    return t>0 and t or 0,f
  end
else
  injections.threshold=0
  getthreshold=function(font)
    local p=fontdata[font].parameters
    local f=p.factor
    local s=p.spacing
    local t=injections.threshold*(s and s.width or p.space or 0)-2
    return t>0 and t or 0,f
  end
end
injections.getthreshold=getthreshold
function injections.isspace(n,threshold)
  if getid(n)==glue_code then
    local w=getfield(n,"width")
    if threshold and w>threshold then 
      return 32
    end
  end
end
local function injectspaces(head)
  if not triggers then
    return head,false
  end
  local lastfont=nil
  local spacekerns=nil
  local leftkerns=nil
  local rightkerns=nil
  local factor=0
  local threshold=0
  local leftkern=false
  local rightkern=false
  local function updatefont(font,trig)
    leftkerns=trig.left
    rightkerns=trig.right
    lastfont=font
    threshold,
    factor=getthreshold(font)
  end
  for n in traverse_id(glue_code,tonut(head)) do
    local prev,next=getboth(n)
    local prevchar=ischar(prev)
    local nextchar=ischar(next)
    if nextchar then
      local font=getfont(next)
      local trig=triggers[font]
      if trig then
        if lastfont~=font then
          updatefont(font,trig)
        end
        if rightkerns then
          rightkern=rightkerns[nextchar]
        end
      end
    end
    if prevchar then
      local font=getfont(prev)
      local trig=triggers[font]
      if trig then
        if lastfont~=font then
          updatefont(font,trig)
        end
        if leftkerns then
          leftkern=leftkerns[prevchar]
        end
      end
    end
    if leftkern then
      local old=getfield(n,"width")
      if old>threshold then
        if rightkern then
          local new=old+(leftkern+rightkern)*factor
          if trace_spaces then
            report_spaces("%C [%p -> %p] %C",prevchar,old,new,nextchar)
          end
          setfield(n,"width",new)
          leftkern=false
        else
          local new=old+leftkern*factor
          if trace_spaces then
            report_spaces("%C [%p -> %p]",prevchar,old,new)
          end
          setfield(n,"width",new)
        end
      end
      leftkern=false
    elseif rightkern then
      local old=getfield(n,"width")
      if old>threshold then
        local new=old+rightkern*factor
        if trace_spaces then
          report_spaces("[%p -> %p] %C",nextchar,old,new)
        end
        setfield(n,"width",new)
      end
      rightkern=false
    end
  end
  triggers=false
  return head,true
end
function injections.handler(head,where)
  if triggers then
    head=injectspaces(head)
  end
  if nofregisteredmarks>0 or nofregisteredcursives>0 then
    if trace_injections then
      report_injections("injection variant %a","everything")
    end
    return inject_everything(head,where)
  elseif nofregisteredpairs>0 then
    if trace_injections then
      report_injections("injection variant %a","pairs")
    end
    return inject_pairs_only(head,where)
  elseif nofregisteredkerns>0 then
    if trace_injections then
      report_injections("injection variant %a","kerns")
    end
    return inject_kerns_only(head,where)
  else
    return head,false
  end
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
local a_state=attributes.private('state')
local nuts=nodes.nuts
local tonut=nuts.tonut
local getfield=nuts.getfield
local getnext=nuts.getnext
local getprev=nuts.getprev
local getprev=nuts.getprev
local getprop=nuts.getprop
local setprop=nuts.setprop
local getfont=nuts.getfont
local getsubtype=nuts.getsubtype
local getchar=nuts.getchar
local ischar=nuts.is_char
local traverse_id=nuts.traverse_id
local end_of_math=nuts.end_of_math
local nodecodes=nodes.nodecodes
local disc_code=nodecodes.disc
local math_code=nodecodes.math
local fontdata=fonts.hashes.identifiers
local categories=characters and characters.categories or {} 
local chardata=characters and characters.data
local otffeatures=fonts.constructors.features.otf
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
  med2=s_medi,
  fina=s_fina,
  fin2=s_fina,
  fin3=s_fina,
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
  med2=s_medi,
  fina=s_fina,
  fin2=s_fina,
  fin3=s_fina,
  isol=s_isol,
  rphf=s_rphf,
  half=s_half,
  pref=s_pref,
  blwf=s_blwf,
  pstf=s_pstf,
}
analyzers.states=states
analyzers.features=features
analyzers.useunicodemarks=false
function analyzers.setstate(head,font)
  local useunicodemarks=analyzers.useunicodemarks
  local tfmdata=fontdata[font]
  local descriptions=tfmdata.descriptions
  local first,last,current,n,done=nil,nil,head,0,false 
  current=tonut(current)
  while current do
    local char,id=ischar(current,font)
    if char and not getprop(current,a_state) then
      done=true
      local d=descriptions[char]
      if d then
        if d.class=="mark" then
          done=true
          setprop(current,a_state,s_mark)
        elseif useunicodemarks and categories[char]=="mn" then
          done=true
          setprop(current,a_state,s_mark)
        elseif n==0 then
          first,last,n=current,current,1
          setprop(current,a_state,s_init)
        else
          last,n=current,n+1
          setprop(current,a_state,s_medi)
        end
      else 
        if first and first==last then
          setprop(last,a_state,s_isol)
        elseif last then
          setprop(last,a_state,s_fina)
        end
        first,last,n=nil,nil,0
      end
    elseif char==false then
      if first and first==last then
        setprop(last,a_state,s_isol)
      elseif last then
        setprop(last,a_state,s_fina)
      end
      first,last,n=nil,nil,0
      if id==math_code then
        current=end_of_math(current)
      end
    elseif id==disc_code then
      setprop(current,a_state,s_medi)
      last=current
    else 
      if first and first==last then
        setprop(last,a_state,s_isol)
      elseif last then
        setprop(last,a_state,s_fina)
      end
      first,last,n=nil,nil,0
      if id==math_code then
        current=end_of_math(current)
      end
    end
    current=getnext(current)
  end
  if first and first==last then
    setprop(last,a_state,s_isol)
  elseif last then
    setprop(last,a_state,s_fina)
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
local arab_warned={}
local function warning(current,what)
  local char=getchar(current)
  if not arab_warned[char] then
    log.report("analyze","arab: character %C has no %a class",char,what)
    arab_warned[char]=true
  end
end
local mappers={
  l=s_init,
  d=s_medi,
  c=s_medi,
  r=s_fina,
  u=s_isol,
}
local classifiers=characters.classifiers
if not classifiers then
  local first_arabic,last_arabic=characters.blockrange("arabic")
  local first_syriac,last_syriac=characters.blockrange("syriac")
  local first_mandiac,last_mandiac=characters.blockrange("mandiac")
  local first_nko,last_nko=characters.blockrange("nko")
  classifiers=table.setmetatableindex(function(t,k)
    local c=chardata[k]
    local v=false
    if c then
      local arabic=c.arabic
      if arabic then
        v=mappers[arabic]
        if not v then
          log.report("analyze","error in mapping arabic %C",k)
          v=false
        end
      elseif k>=first_arabic and k<=last_arabic or k>=first_syriac and k<=last_syriac or
          k>=first_mandiac and k<=last_mandiac or k>=first_nko   and k<=last_nko   then
        if categories[k]=="mn" then
          v=s_mark
        else
          v=s_rest
        end
      end
    end
    t[k]=v
    return v
  end)
end
function methods.arab(head,font,attr)
  local first,last=nil,nil
  local c_first,c_last=nil,nil
  local current,done=head,false
  current=tonut(current)
  while current do
    local char,id=ischar(current,font)
    if char and not getprop(current,a_state) then
      done=true
      local classifier=classifiers[char]
      if not classifier then
        if last then
          if c_last==s_medi or c_last==s_fina then
            setprop(last,a_state,s_fina)
          else
            warning(last,"fina")
            setprop(last,a_state,s_error)
          end
          first,last=nil,nil
        elseif first then
          if c_first==s_medi or c_first==s_fina then
            setprop(first,a_state,s_isol)
          else
            warning(first,"isol")
            setprop(first,a_state,s_error)
          end
          first=nil
        end
      elseif classifier==s_mark then
        setprop(current,a_state,s_mark)
      elseif classifier==s_isol then
        if last then
          if c_last==s_medi or c_last==s_fina then
            setprop(last,a_state,s_fina)
          else
            warning(last,"fina")
            setprop(last,a_state,s_error)
          end
          first,last=nil,nil
        elseif first then
          if c_first==s_medi or c_first==s_fina then
            setprop(first,a_state,s_isol)
          else
            warning(first,"isol")
            setprop(first,a_state,s_error)
          end
          first=nil
        end
        setprop(current,a_state,s_isol)
      elseif classifier==s_medi then
        if first then
          last=current
          c_last=classifier
          setprop(current,a_state,s_medi)
        else
          setprop(current,a_state,s_init)
          first=current
          c_first=classifier
        end
      elseif classifier==s_fina then
        if last then
          if getprop(last,a_state)~=s_init then
            setprop(last,a_state,s_medi)
          end
          setprop(current,a_state,s_fina)
          first,last=nil,nil
        elseif first then
          setprop(current,a_state,s_fina)
          first=nil
        else
          setprop(current,a_state,s_isol)
        end
      else 
        setprop(current,a_state,s_rest)
        if last then
          if c_last==s_medi or c_last==s_fina then
            setprop(last,a_state,s_fina)
          else
            warning(last,"fina")
            setprop(last,a_state,s_error)
          end
          first,last=nil,nil
        elseif first then
          if c_first==s_medi or c_first==s_fina then
            setprop(first,a_state,s_isol)
          else
            warning(first,"isol")
            setprop(first,a_state,s_error)
          end
          first=nil
        end
      end
    else
      if last then
        if c_last==s_medi or c_last==s_fina then
          setprop(last,a_state,s_fina)
        else
          warning(last,"fina")
          setprop(last,a_state,s_error)
        end
        first,last=nil,nil
      elseif first then
        if c_first==s_medi or c_first==s_fina then
          setprop(first,a_state,s_isol)
        else
          warning(first,"isol")
          setprop(first,a_state,s_error)
        end
        first=nil
      end
      if id==math_code then 
        current=end_of_math(current)
      end
    end
    current=getnext(current)
  end
  if last then
    if c_last==s_medi or c_last==s_fina then
      setprop(last,a_state,s_fina)
    else
      warning(last,"fina")
      setprop(last,a_state,s_error)
    end
  elseif first then
    if c_first==s_medi or c_first==s_fina then
      setprop(first,a_state,s_isol)
    else
      warning(first,"isol")
      setprop(first,a_state,s_error)
    end
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

if not modules then modules={} end modules ['font-ots']={ 
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files",
}
local type,next,tonumber=type,next,tonumber
local random=math.random
local formatters=string.formatters
local insert=table.insert
local logs,trackers,nodes,attributes=logs,trackers,nodes,attributes
local registertracker=trackers.register
local registerdirective=directives.register
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
local trace_steps=false registertracker("otf.steps",function(v) trace_steps=v end)
local trace_skips=false registertracker("otf.skips",function(v) trace_skips=v end)
local trace_directions=false registertracker("otf.directions",function(v) trace_directions=v end)
local trace_kernruns=false registertracker("otf.kernruns",function(v) trace_kernruns=v end)
local trace_discruns=false registertracker("otf.discruns",function(v) trace_discruns=v end)
local trace_compruns=false registertracker("otf.compruns",function(v) trace_compruns=v end)
local trace_testruns=false registertracker("otf.testruns",function(v) trace_testruns=v end)
local optimizekerns=true
local report_direct=logs.reporter("fonts","otf direct")
local report_subchain=logs.reporter("fonts","otf subchain")
local report_chain=logs.reporter("fonts","otf chain")
local report_process=logs.reporter("fonts","otf process")
local report_warning=logs.reporter("fonts","otf warning")
local report_run=logs.reporter("fonts","otf run")
registertracker("otf.replacements","otf.singles,otf.multiples,otf.alternatives,otf.ligatures")
registertracker("otf.positions","otf.marks,otf.kerns,otf.cursive")
registertracker("otf.actions","otf.replacements,otf.positions")
registertracker("otf.injections","nodes.injections")
registertracker("*otf.sample","otf.steps,otf.actions,otf.analyzing")
local nuts=nodes.nuts
local tonode=nuts.tonode
local tonut=nuts.tonut
local getfield=nuts.getfield
local setfield=nuts.setfield
local getnext=nuts.getnext
local setnext=nuts.setnext
local getprev=nuts.getprev
local setprev=nuts.setprev
local getboth=nuts.getboth
local setboth=nuts.setboth
local getid=nuts.getid
local getattr=nuts.getattr
local setattr=nuts.setattr
local getprop=nuts.getprop
local setprop=nuts.setprop
local getfont=nuts.getfont
local getsubtype=nuts.getsubtype
local setsubtype=nuts.setsubtype
local getchar=nuts.getchar
local setchar=nuts.setchar
local getdisc=nuts.getdisc
local setdisc=nuts.setdisc
local setlink=nuts.setlink
local ischar=nuts.is_char
local insert_node_after=nuts.insert_after
local copy_node=nuts.copy
local copy_node_list=nuts.copy_list
local find_node_tail=nuts.tail
local flush_node_list=nuts.flush_list
local flush_node=nuts.flush_node
local end_of_math=nuts.end_of_math
local traverse_nodes=nuts.traverse
local traverse_id=nuts.traverse_id
local remove_node=nuts.remove
local setmetatableindex=table.setmetatableindex
local zwnj=0x200C
local zwj=0x200D
local wildcard="*"
local default="dflt"
local nodecodes=nodes.nodecodes
local glyphcodes=nodes.glyphcodes
local disccodes=nodes.disccodes
local glyph_code=nodecodes.glyph
local glue_code=nodecodes.glue
local disc_code=nodecodes.disc
local math_code=nodecodes.math
local dir_code=nodecodes.dir
local localpar_code=nodecodes.localpar
local discretionary_code=disccodes.discretionary
local ligature_code=glyphcodes.ligature
local privateattribute=attributes.private
local a_state=privateattribute('state')
local injections=nodes.injections
local setmark=injections.setmark
local setcursive=injections.setcursive
local setkern=injections.setkern
local setpair=injections.setpair
local resetinjection=injections.reset
local copyinjection=injections.copy
local setligaindex=injections.setligaindex
local getligaindex=injections.getligaindex
local cursonce=true
local fonthashes=fonts.hashes
local fontdata=fonthashes.identifiers
local fontfeatures=fonthashes.features
local otffeatures=fonts.constructors.features.otf
local registerotffeature=otffeatures.register
local onetimemessage=fonts.loggers.onetimemessage or function() end
otf.defaultnodealternate="none"
local tfmdata=false
local characters=false
local descriptions=false
local marks=false
local currentfont=false
local factor=0
local threshold=0
local sweepnode=nil
local sweepprev=nil
local sweepnext=nil
local sweephead={}
local notmatchpre={}
local notmatchpost={}
local notmatchreplace={}
local handlers={}
local isspace=injections.isspace
local getthreshold=injections.getthreshold
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
local function cref(dataset,sequence,index)
  if not dataset then
    return "no valid dataset"
  elseif index then
    return formatters["feature %a, type %a, chain lookup %a, index %a"](dataset[4],sequence.type,sequence.name,index)
  else
    return formatters["feature %a, type %a, chain lookup %a"](dataset[4],sequence.type,sequence.name)
  end
end
local function pref(dataset,sequence)
  return formatters["feature %a, type %a, lookup %a"](dataset[4],sequence.type,sequence.name)
end
local function mref(rlmode)
  if not rlmode or rlmode==0 then
    return "---"
  elseif rlmode==-1 or rlmode=="+TRT" then
    return "r2l"
  else
    return "l2r"
  end
end
local function copy_glyph(g) 
  local components=getfield(g,"components")
  if components then
    setfield(g,"components",nil)
    local n=copy_node(g)
    copyinjection(n,g) 
    setfield(g,"components",components)
    return n
  else
    local n=copy_node(g)
    copyinjection(n,g) 
    return n
  end
end
local function flattendisk(head,disc)
  local _,_,replace,_,_,replacetail=getdisc(disc,true)
  setfield(disc,"replace",nil)
  flush_node(disc)
  if head==disc then
    local next=getnext(disc)
    if replace then
      if next then
        setlink(replacetail,next)
      end
      return replace,replace
    elseif next then
      return next,next
    else
      return 
    end
  else
    local prev,next=getboth(disc)
    if replace then
      if next then
        setlink(replacetail,next)
      end
      setlink(prev,replace)
      return head,replace
    else
      setlink(prev,next) 
      return head,next
    end
  end
end
local function appenddisc(disc,list)
  local pre,post,replace,pretail,posttail,replacetail=getdisc(disc,true)
  local posthead=list
  local replacehead=copy_node_list(list)
  if post then
    setlink(posttail,posthead)
  else
    post=phead
  end
  if replace then
    setlink(replacetail,replacehead)
  else
    replace=rhead
  end
  setdisc(disc,pre,post,replace)
end
local function markstoligature(head,start,stop,char)
  if start==stop and getchar(start)==char then
    return head,start
  else
    local prev=getprev(start)
    local next=getnext(stop)
    setprev(start,nil)
    setnext(stop,nil)
    local base=copy_glyph(start)
    if head==start then
      head=base
    end
    resetinjection(base)
    setchar(base,char)
    setsubtype(base,ligature_code)
    setfield(base,"components",start)
    setlink(prev,base)
    setlink(base,next)
    return head,base
  end
end
local function getcomponentindex(start) 
  if getid(start)~=glyph_code then 
    return 0
  elseif getsubtype(start)==ligature_code then
    local i=0
    local components=getfield(start,"components")
    while components do
      i=i+getcomponentindex(components)
      components=getnext(components)
    end
    return i
  elseif not marks[getchar(start)] then
    return 1
  else
    return 0
  end
end
local a_noligature=attributes.private("noligature")
local function toligature(head,start,stop,char,dataset,sequence,markflag,discfound) 
  if getattr(start,a_noligature)==1 then
    return head,start
  end
  if start==stop and getchar(start)==char then
    resetinjection(start)
    setchar(start,char)
    return head,start
  end
  local components=getfield(start,"components")
  if components then
  end
  local prev=getprev(start)
  local next=getnext(stop)
  local comp=start
  setprev(start,nil)
  setnext(stop,nil)
  local base=copy_glyph(start)
  if start==head then
    head=base
  end
  resetinjection(base)
  setchar(base,char)
  setsubtype(base,ligature_code)
  setfield(base,"components",comp) 
  if prev then
    setnext(prev,base)
  end
  if next then
    setprev(next,base)
  end
  setboth(base,prev,next)
  if not discfound then
    local deletemarks=markflag~="mark"
    local components=start
    local baseindex=0
    local componentindex=0
    local head=base
    local current=base
    while start do
      local char=getchar(start)
      if not marks[char] then
        baseindex=baseindex+componentindex
        componentindex=getcomponentindex(start)
      elseif not deletemarks then 
        setligaindex(start,baseindex+getligaindex(start,componentindex))
        if trace_marks then
          logwarning("%s: keep mark %s, gets index %s",pref(dataset,sequence),gref(char),getligaindex(start))
        end
        local n=copy_node(start)
        copyinjection(n,start)
        head,current=insert_node_after(head,current,n) 
      elseif trace_marks then
        logwarning("%s: delete mark %s",pref(dataset,sequence),gref(char))
      end
      start=getnext(start)
    end
    local start=getnext(current)
    while start do
      local char=ischar(start)
      if char then
        if marks[char] then
          setligaindex(start,baseindex+getligaindex(start,componentindex))
          if trace_marks then
            logwarning("%s: set mark %s, gets index %s",pref(dataset,sequence),gref(char),getligaindex(start))
          end
          start=getnext(start)
        else
          break
        end
      else
        break
      end
    end
  else
    local discprev,discnext=getboth(discfound)
    if discprev and discnext then
      local pre,post,replace,pretail,posttail,replacetail=getdisc(discfound,true)
      if not replace then 
        local prev=getprev(base)
local current=comp
local previous=nil
local copied=nil
while current do
  if getid(current)==glyph_code then
    local n=copy_node(current)
    if copied then
      setlink(previous,n)
    else
      copied=n
    end
    previous=n
  end
  current=getnext(current)
end
        setprev(discnext,nil) 
        setnext(discprev,nil) 
        if pre then
          setlink(discprev,pre)
        end
        pre=comp
        if post then
          setlink(posttail,discnext)
          setprev(post,nil)
        else
          post=discnext
        end
        setlink(prev,discfound)
        setlink(discfound,next)
        setboth(base,nil,nil)
        setfield(base,"components",copied)
        setdisc(discfound,pre,post,base,discretionary_code)
        base=prev 
      end
    end
  end
  return head,base
end
local function multiple_glyphs(head,start,multiple,ignoremarks,what)
  local nofmultiples=#multiple
  if nofmultiples>0 then
    resetinjection(start)
    setchar(start,multiple[1])
    if nofmultiples>1 then
      local sn=getnext(start)
      for k=2,nofmultiples do
        local n=copy_node(start) 
        resetinjection(n)
        setchar(n,multiple[k])
        insert_node_after(head,start,n)
        start=n
      end
      if what==true then
      elseif what>1 then
        local m=multiple[nofmultiples]
        for i=2,what do
          local n=copy_node(start) 
          resetinjection(n)
          setchar(n,m)
          insert_node_after(head,start,n)
          start=n
        end
      end
    end
    return head,start,true
  else
    if trace_multiples then
      logprocess("no multiple for %s",gref(getchar(start)))
    end
    return head,start,false
  end
end
local function get_alternative_glyph(start,alternatives,value)
  local n=#alternatives
  if value=="random" then
    local r=random(1,n)
    return alternatives[r],trace_alternatives and formatters["value %a, taking %a"](value,r)
  elseif value=="first" then
    return alternatives[1],trace_alternatives and formatters["value %a, taking %a"](value,1)
  elseif value=="last" then
    return alternatives[n],trace_alternatives and formatters["value %a, taking %a"](value,n)
  end
  value=value==true and 1 or tonumber(value)
  if type(value)~="number" then
    return alternatives[1],trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
  end
  if value>n then
    local defaultalt=otf.defaultnodealternate
    if defaultalt=="first" then
      return alternatives[n],trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
    elseif defaultalt=="last" then
      return alternatives[1],trace_alternatives and formatters["invalid value %s, taking %a"](value,n)
    else
      return false,trace_alternatives and formatters["invalid value %a, %s"](value,"out of range")
    end
  elseif value==0 then
    return getchar(start),trace_alternatives and formatters["invalid value %a, %s"](value,"no change")
  elseif value<1 then
    return alternatives[1],trace_alternatives and formatters["invalid value %a, taking %a"](value,1)
  else
    return alternatives[value],trace_alternatives and formatters["value %a, taking %a"](value,value)
  end
end
function handlers.gsub_single(head,start,dataset,sequence,replacement)
  if trace_singles then
    logprocess("%s: replacing %s by single %s",pref(dataset,sequence),gref(getchar(start)),gref(replacement))
  end
  resetinjection(start)
  setchar(start,replacement)
  return head,start,true
end
function handlers.gsub_alternate(head,start,dataset,sequence,alternative)
  local kind=dataset[4]
  local what=dataset[1]
  local value=what==true and tfmdata.shared.features[kind] or what
  local choice,comment=get_alternative_glyph(start,alternative,value)
  if choice then
    if trace_alternatives then
      logprocess("%s: replacing %s by alternative %a to %s, %s",pref(dataset,sequence),gref(getchar(start)),gref(choice),comment)
    end
    resetinjection(start)
    setchar(start,choice)
  else
    if trace_alternatives then
      logwarning("%s: no variant %a for %s, %s",pref(dataset,sequence),value,gref(getchar(start)),comment)
    end
  end
  return head,start,true
end
function handlers.gsub_multiple(head,start,dataset,sequence,multiple)
  if trace_multiples then
    logprocess("%s: replacing %s by multiple %s",pref(dataset,sequence),gref(getchar(start)),gref(multiple))
  end
  return multiple_glyphs(head,start,multiple,sequence.flags[1],dataset[1])
end
function handlers.gsub_ligature(head,start,dataset,sequence,ligature)
  local current=getnext(start)
  if not current then
    return head,start,false,nil
  end
  local stop=nil
  local startchar=getchar(start)
  if marks[startchar] then
    while current do
      local char=ischar(current,currentfont)
      if char then
        local lg=ligature[char]
        if lg then
          stop=current
          ligature=lg
          current=getnext(current)
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
          local stopchar=getchar(stop)
          head,start=markstoligature(head,start,stop,lig)
          logprocess("%s: replacing %s upto %s by ligature %s case 1",pref(dataset,sequence),gref(startchar),gref(stopchar),gref(getchar(start)))
        else
          head,start=markstoligature(head,start,stop,lig)
        end
        return head,start,true,false
      else
      end
    end
  else
    local skipmark=sequence.flags[1]
    local discfound=false
    local lastdisc=nil
    while current do
      local char,id=ischar(current,currentfont)
      if char then
        if skipmark and marks[char] then
          current=getnext(current)
        else 
          local lg=ligature[char] 
          if lg then
            if not discfound and lastdisc then
              discfound=lastdisc
              lastdisc=nil
            end
            stop=current 
            ligature=lg
            current=getnext(current)
          else
            break
          end
        end
      elseif char==false then
        break
      elseif id==disc_code then
        local replace=getfield(current,"replace")
        if replace then
          while replace do
            local char,id=ischar(replace,currentfont)
            if char then
              local lg=ligature[char] 
              if lg then
                ligature=lg
                replace=getnext(replace)
              else
                return head,start,false,false
              end
            else
              return head,start,false,false
            end
          end
          stop=current
        end
        lastdisc=current
        current=getnext(current)
      else
        break
      end
    end
    local lig=ligature.ligature
    if lig then
      if stop then
        if trace_ligatures then
          local stopchar=getchar(stop)
          head,start=toligature(head,start,stop,lig,dataset,sequence,skipmark,discfound)
          logprocess("%s: replacing %s upto %s by ligature %s case 2",pref(dataset,sequence),gref(startchar),gref(stopchar),gref(lig))
        else
          head,start=toligature(head,start,stop,lig,dataset,sequence,skipmark,discfound)
        end
      else
        resetinjection(start)
        setchar(start,lig)
        if trace_ligatures then
          logprocess("%s: replacing %s by (no real) ligature %s case 3",pref(dataset,sequence),gref(startchar),gref(lig))
        end
      end
      return head,start,true,discfound
    else
    end
  end
  return head,start,false,discfound
end
function handlers.gpos_single(head,start,dataset,sequence,kerns,rlmode,step,i,injection)
  local startchar=getchar(start)
  if step.format=="pair" then
    local dx,dy,w,h=setpair(start,factor,rlmode,sequence.flags[4],kerns,injection)
    if trace_kerns then
      logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",pref(dataset,sequence),gref(startchar),dx,dy,w,h)
    end
  else
    local k=setkern(start,factor,rlmode,kerns,injection)
    if trace_kerns then
      logprocess("%s: shifting single %s by %p",pref(dataset,sequence),gref(startchar),k)
    end
  end
  return head,start,false
end
function handlers.gpos_pair(head,start,dataset,sequence,kerns,rlmode,step,i,injection)
  local snext=getnext(start)
  if not snext then
    return head,start,false
  else
    local prev=start
    local done=false
    while snext do
      local nextchar=ischar(snext,currentfont)
      if nextchar then
        local krn=kerns[nextchar]
        if not krn and marks[nextchar] then
          prev=snext
          snext=getnext(snext)
        elseif not krn then
          break
        elseif step.format=="pair" then
          local a,b=krn[1],krn[2]
          if optimizekerns then
            if not b and a[1]==0 and a[2]==0 and a[4]==0 then
              local k=setkern(snext,factor,rlmode,a[3],injection)
              if trace_kerns then
                logprocess("%s: shifting single %s by %p",pref(dataset,sequence),gref(nextchar),k)
              end
              done=true
              break
            end
          end
          if a and #a>0 then
            local x,y,w,h=setpair(start,factor,rlmode,sequence.flags[4],a,injection)
            if trace_kerns then
              local startchar=getchar(start)
              logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p) as %s",pref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h,injection or "injections")
            end
          end
          if b and #b>0 then
            local x,y,w,h=setpair(snext,factor,rlmode,sequence.flags[4],b,injection)
            if trace_kerns then
              local startchar=getchar(snext)
              logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p) as %s",pref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h,injection or "injections")
            end
          end
          done=true
          break
        elseif krn~=0 then
          local k=setkern(snext,factor,rlmode,krn,injection)
          if trace_kerns then
            logprocess("%s: inserting kern %p between %s and %s as %s",pref(dataset,sequence),k,gref(getchar(prev)),gref(nextchar),injection or "injections")
          end
          done=true
          break
        else 
          break
        end
      else
        break
      end
    end
    return head,start,done
  end
end
function handlers.gpos_mark2base(head,start,dataset,sequence,markanchors,rlmode)
  local markchar=getchar(start)
  if marks[markchar] then
    local base=getprev(start) 
    if base then
      local basechar=ischar(base,currentfont)
      if basechar then
        if marks[basechar] then
          while base do
            base=getprev(base)
            if base then
              basechar=ischar(base,currentfont)
              if basechar then
                if not marks[basechar] then
                  break
                end
              else
                if trace_bugs then
                  logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),1)
                end
                return head,start,false
              end
            else
              if trace_bugs then
                logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),2)
              end
              return head,start,false
            end
          end
        end
        local ba=markanchors[1][basechar]
        if ba then
          local ma=markanchors[2]
          local dx,dy,bound=setmark(start,base,factor,rlmode,ba,ma,characters[basechar])
          if trace_marks then
            logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
              pref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
          end
          return head,start,true
        end
      elseif trace_bugs then
        logwarning("%s: nothing preceding, case %i",pref(dataset,sequence),1)
      end
    elseif trace_bugs then
      logwarning("%s: nothing preceding, case %i",pref(dataset,sequence),2)
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(dataset,sequence),gref(markchar))
  end
  return head,start,false
end
function handlers.gpos_mark2ligature(head,start,dataset,sequence,markanchors,rlmode)
  local markchar=getchar(start)
  if marks[markchar] then
    local base=getprev(start) 
    if base then
      local basechar=ischar(base,currentfont)
      if basechar then
        if marks[basechar] then
          while base do
            base=getprev(base)
            if base then
              basechar=ischar(base,currentfont)
              if basechar then
                if not marks[basechar] then
                  break
                end
              else
                if trace_bugs then
                  logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),1)
                end
                return head,start,false
              end
            else
              if trace_bugs then
                logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),2)
              end
              return head,start,false
            end
          end
        end
        local ba=markanchors[1][basechar]
        if ba then
          local ma=markanchors[2]
          if ma then
            local index=getligaindex(start)
            ba=ba[index]
            if ba then
              local dx,dy,bound=setmark(start,base,factor,rlmode,ba,ma,characters[basechar]) 
              if trace_marks then
                logprocess("%s, anchor %s, index %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                  pref(dataset,sequence),anchor,index,bound,gref(markchar),gref(basechar),index,dx,dy)
              end
              return head,start,true
            else
              if trace_bugs then
                logwarning("%s: no matching anchors for mark %s and baselig %s with index %a",pref(dataset,sequence),gref(markchar),gref(basechar),index)
              end
            end
          end
        elseif trace_bugs then
          onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
        end
      elseif trace_bugs then
        logwarning("%s: prev node is no char, case %i",pref(dataset,sequence),1)
      end
    elseif trace_bugs then
      logwarning("%s: prev node is no char, case %i",pref(dataset,sequence),2)
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(dataset,sequence),gref(markchar))
  end
  return head,start,false
end
function handlers.gpos_mark2mark(head,start,dataset,sequence,markanchors,rlmode)
  local markchar=getchar(start)
  if marks[markchar] then
    local base=getprev(start) 
    local slc=getligaindex(start)
    if slc then 
      while base do
        local blc=getligaindex(base)
        if blc and blc~=slc then
          base=getprev(base)
        else
          break
        end
      end
    end
    if base then
      local basechar=ischar(base,currentfont)
      if basechar then 
        local ba=markanchors[1][basechar] 
        if ba then
          local ma=markanchors[2]
          local dx,dy,bound=setmark(start,base,factor,rlmode,ba,ma,characters[basechar],true)
          if trace_marks then
            logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
              pref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
          end
          return head,start,true
        end
      end
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(dataset,sequence),gref(markchar))
  end
  return head,start,false
end
function handlers.gpos_cursive(head,start,dataset,sequence,exitanchors,rlmode,step,i) 
  local done=false
  local startchar=getchar(start)
  if marks[startchar] then
    if trace_cursive then
      logprocess("%s: ignoring cursive for mark %s",pref(dataset,sequence),gref(startchar))
    end
  else
    local nxt=getnext(start)
    while not done and nxt do
      local nextchar=ischar(nxt,currentfont)
      if not nextchar then
        break
      elseif marks[nextchar] then
        nxt=getnext(nxt)
      else
        local exit=exitanchors[3]
        if exit then
          local entry=exitanchors[1][nextchar]
          if entry then
            entry=entry[2]
            if entry then
              local dx,dy,bound=setcursive(start,nxt,factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
              if trace_cursive then
                logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in %s mode",pref(dataset,sequence),gref(startchar),gref(nextchar),dx,dy,anchor,bound,mref(rlmode))
              end
              done=true
            end
          end
        end
        break
      end
    end
  end
  return head,start,done
end
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
local function reversesub(head,start,stop,dataset,sequence,replacements,rlmode)
  local char=getchar(start)
  local replacement=replacements[char]
  if replacement then
    if trace_singles then
      logprocess("%s: single reverse replacement of %s by %s",cref(dataset,sequence),gref(char),gref(replacement))
    end
    resetinjection(start)
    setchar(start,replacement)
    return head,start,true
  else
    return head,start,false
  end
end
chainprocs.reversesub=reversesub
local function reportmoresteps(dataset,sequence)
  logwarning("%s: more than 1 step",cref(dataset,sequence))
end
function chainprocs.gsub_single(head,start,stop,dataset,sequence,currentlookup,chainindex)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local current=start
  while current do
    local currentchar=ischar(current)
    if currentchar then
      local replacement=steps[1].coverage[currentchar]
      if not replacement or replacement=="" then
        if trace_bugs then
          logwarning("%s: no single for %s",cref(dataset,sequence,chainindex),gref(currentchar))
        end
      else
        if trace_singles then
          logprocess("%s: replacing single %s by %s",cref(dataset,sequence,chainindex),gref(currentchar),gref(replacement))
        end
        resetinjection(current)
        setchar(current,replacement)
      end
      return head,start,true
    elseif currentchar==false then
      break
    elseif current==stop then
      break
    else
      current=getnext(current)
    end
  end
  return head,start,false
end
function chainprocs.gsub_multiple(head,start,stop,dataset,sequence,currentlookup)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local startchar=getchar(start)
  local replacement=steps[1].coverage[startchar]
  if not replacement or replacement=="" then
    if trace_bugs then
      logwarning("%s: no multiple for %s",cref(dataset,sequence),gref(startchar))
    end
  else
    if trace_multiples then
      logprocess("%s: replacing %s by multiple characters %s",cref(dataset,sequence),gref(startchar),gref(replacement))
    end
    return multiple_glyphs(head,start,replacement,sequence.flags[1],dataset[1])
  end
  return head,start,false
end
function chainprocs.gsub_alternate(head,start,stop,dataset,sequence,currentlookup)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local kind=dataset[4]
  local what=dataset[1]
  local value=what==true and tfmdata.shared.features[kind] or what 
  local current=start
  while current do
    local currentchar=ischar(current)
    if currentchar then
      local alternatives=steps[1].coverage[currentchar]
      if alternatives then
        local choice,comment=get_alternative_glyph(current,alternatives,value)
        if choice then
          if trace_alternatives then
            logprocess("%s: replacing %s by alternative %a to %s, %s",cref(dataset,sequence),gref(char),choice,gref(choice),comment)
          end
          resetinjection(start)
          setchar(start,choice)
        else
          if trace_alternatives then
            logwarning("%s: no variant %a for %s, %s",cref(dataset,sequence),value,gref(char),comment)
          end
        end
      end
      return head,start,true
    elseif currentchar==false then
      break
    elseif current==stop then
      break
    else
      current=getnext(current)
    end
  end
  return head,start,false
end
function chainprocs.gsub_ligature(head,start,stop,dataset,sequence,currentlookup,chainindex)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local startchar=getchar(start)
  local ligatures=steps[1].coverage[startchar]
  if not ligatures then
    if trace_bugs then
      logwarning("%s: no ligatures starting with %s",cref(dataset,sequence,chainindex),gref(startchar))
    end
  else
    local current=getnext(start)
    local discfound=false
    local last=stop
    local nofreplacements=1
    local skipmark=currentlookup.flags[1] 
    while current do
      local id=getid(current)
      if id==disc_code then
        if not discfound then
          discfound=current
        end
        if current==stop then
          break 
        else
          current=getnext(current)
        end
      else
        local schar=getchar(current)
        if skipmark and marks[schar] then
            current=getnext(current)
        else
          local lg=ligatures[schar]
          if lg then
            ligatures=lg
            last=current
            nofreplacements=nofreplacements+1
            if current==stop then
              break
            else
              current=getnext(current)
            end
          else
            break
          end
        end
      end
    end
    local ligature=ligatures.ligature
    if ligature then
      if chainindex then
        stop=last
      end
      if trace_ligatures then
        if start==stop then
          logprocess("%s: replacing character %s by ligature %s case 3",cref(dataset,sequence,chainindex),gref(startchar),gref(ligature))
        else
          logprocess("%s: replacing character %s upto %s by ligature %s case 4",cref(dataset,sequence,chainindex),gref(startchar),gref(getchar(stop)),gref(ligature))
        end
      end
      head,start=toligature(head,start,stop,ligature,dataset,sequence,skipmark,discfound)
      return head,start,true,nofreplacements,discfound
    elseif trace_bugs then
      if start==stop then
        logwarning("%s: replacing character %s by ligature fails",cref(dataset,sequence,chainindex),gref(startchar))
      else
        logwarning("%s: replacing character %s upto %s by ligature fails",cref(dataset,sequence,chainindex),gref(startchar),gref(getchar(stop)))
      end
    end
  end
  return head,start,false,0,false
end
function chainprocs.gpos_single(head,start,stop,dataset,sequence,currentlookup,rlmode,chainindex)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local startchar=getchar(start)
  local step=steps[1]
  local kerns=step.coverage[startchar]
  if not kerns then
  elseif step.format=="pair" then
    local dx,dy,w,h=setpair(start,factor,rlmode,sequence.flags[4],kerns) 
    if trace_kerns then
      logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",cref(dataset,sequence),gref(startchar),dx,dy,w,h)
    end
  else 
    local k=setkern(start,factor,rlmode,kerns,injection)
    if trace_kerns then
      logprocess("%s: shifting single %s by %p",cref(dataset,sequence),gref(startchar),k)
    end
  end
  return head,start,false
end
function chainprocs.gpos_pair(head,start,stop,dataset,sequence,currentlookup,rlmode,chainindex) 
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local snext=getnext(start)
  if snext then
    local startchar=getchar(start)
    local step=steps[1]
    local kerns=step.coverage[startchar] 
    if kerns then
      local prev=start
      local done=false
      while snext do
        local nextchar=ischar(snext,currentfont)
        if not nextchar then
          break
        end
        local krn=kerns[nextchar]
        if not krn and marks[nextchar] then
          prev=snext
          snext=getnext(snext)
        elseif not krn then
          break
        elseif step.format=="pair" then
          local a,b=krn[1],krn[2]
          if optimizekerns then
            if not b and a[1]==0 and a[2]==0 and a[4]==0 then
              local k=setkern(snext,factor,rlmode,a[3],"injections")
              if trace_kerns then
                logprocess("%s: shifting single %s by %p",cref(dataset,sequence),gref(startchar),k)
              end
              done=true
              break
            end
          end
          if a and #a>0 then
            local startchar=getchar(start)
            local x,y,w,h=setpair(start,factor,rlmode,sequence.flags[4],a,"injections") 
            if trace_kerns then
              logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h)
            end
          end
          if b and #b>0 then
            local startchar=getchar(start)
            local x,y,w,h=setpair(snext,factor,rlmode,sequence.flags[4],b,"injections")
            if trace_kerns then
              logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h)
            end
          end
          done=true
          break
        elseif krn~=0 then
          local k=setkern(snext,factor,rlmode,krn)
          if trace_kerns then
            logprocess("%s: inserting kern %s between %s and %s",cref(dataset,sequence),k,gref(getchar(prev)),gref(nextchar))
          end
          done=true
          break
        else
          break
        end
      end
      return head,start,done
    end
  end
  return head,start,false
end
function chainprocs.gpos_mark2base(head,start,stop,dataset,sequence,currentlookup,rlmode)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local markchar=getchar(start)
  if marks[markchar] then
    local markanchors=steps[1].coverage[markchar] 
    if markanchors then
      local base=getprev(start) 
      if base then
        local basechar=ischar(base,currentfont)
        if basechar then
          if marks[basechar] then
            while base do
              base=getprev(base)
              if base then
                local basechar=ischar(base,currentfont)
                if basechar then
                  if not marks[basechar] then
                    break
                  end
                else
                  if trace_bugs then
                    logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),1)
                  end
                  return head,start,false
                end
              else
                if trace_bugs then
                  logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),2)
                end
                return head,start,false
              end
            end
          end
          local ba=markanchors[1][basechar]
          if ba then
            local ma=markanchors[2]
            if ma then
              local dx,dy,bound=setmark(start,base,factor,rlmode,ba,ma,characters[basechar])
              if trace_marks then
                logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                  cref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
              end
              return head,start,true
            end
          end
        elseif trace_bugs then
          logwarning("%s: prev node is no char, case %i",cref(dataset,sequence),1)
        end
      elseif trace_bugs then
        logwarning("%s: prev node is no char, case %i",cref(dataset,sequence),2)
      end
    elseif trace_bugs then
      logwarning("%s: mark %s has no anchors",cref(dataset,sequence),gref(markchar))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",cref(dataset,sequence),gref(markchar))
  end
  return head,start,false
end
function chainprocs.gpos_mark2ligature(head,start,stop,dataset,sequence,currentlookup,rlmode)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local markchar=getchar(start)
  if marks[markchar] then
    local markanchors=steps[1].coverage[markchar] 
    if markanchors then
      local base=getprev(start) 
      if base then
        local basechar=ischar(base,currentfont)
        if basechar then
          if marks[basechar] then
            while base do
              base=getprev(base)
              if base then
                local basechar=ischar(base,currentfont)
                if basechar then
                  if not marks[basechar] then
                    break
                  end
                else
                  if trace_bugs then
                    logwarning("%s: no base for mark %s, case %i",cref(dataset,sequence),markchar,1)
                  end
                  return head,start,false
                end
              else
                if trace_bugs then
                  logwarning("%s: no base for mark %s, case %i",cref(dataset,sequence),markchar,2)
                end
                return head,start,false
              end
            end
          end
          local ba=markanchors[1][basechar]
          if ba then
            local ma=markanchors[2]
            if ma then
              local index=getligaindex(start)
              ba=ba[index]
              if ba then
                local dx,dy,bound=setmark(start,base,factor,rlmode,ba,ma,characters[basechar])
                if trace_marks then
                  logprocess("%s, anchor %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                    cref(dataset,sequence),anchor,a or bound,gref(markchar),gref(basechar),index,dx,dy)
                end
                return head,start,true
              end
            end
          end
        elseif trace_bugs then
          logwarning("%s, prev node is no char, case %i",cref(dataset,sequence),1)
        end
      elseif trace_bugs then
        logwarning("%s, prev node is no char, case %i",cref(dataset,sequence),2)
      end
    elseif trace_bugs then
      logwarning("%s, mark %s has no anchors",cref(dataset,sequence),gref(markchar))
    end
  elseif trace_bugs then
    logwarning("%s, mark %s is no mark",cref(dataset,sequence),gref(markchar))
  end
  return head,start,false
end
function chainprocs.gpos_mark2mark(head,start,stop,dataset,sequence,currentlookup,rlmode)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local markchar=getchar(start)
  if marks[markchar] then
    local markanchors=steps[1].coverage[markchar] 
    if markanchors then
      local base=getprev(start) 
      local slc=getligaindex(start)
      if slc then 
        while base do
          local blc=getligaindex(base)
          if blc and blc~=slc then
            base=getprev(base)
          else
            break
          end
        end
      end
      if base then 
        local basechar=ischar(base,currentfont)
        if basechar then
          local ba=markanchors[1][basechar]
          if ba then
            local ma=markanchors[2]
            if ma then
              local dx,dy,bound=setmark(start,base,factor,rlmode,ba,ma,characters[basechar],true)
              if trace_marks then
                logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                  cref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
              end
              return head,start,true
            end
          end
        elseif trace_bugs then
          logwarning("%s: prev node is no mark, case %i",cref(dataset,sequence),1)
        end
      elseif trace_bugs then
        logwarning("%s: prev node is no mark, case %i",cref(dataset,sequence),2)
      end
    elseif trace_bugs then
      logwarning("%s: mark %s has no anchors",cref(dataset,sequence),gref(markchar))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",cref(dataset,sequence),gref(markchar))
  end
  return head,start,false
end
function chainprocs.gpos_cursive(head,start,stop,dataset,sequence,currentlookup,rlmode)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  local startchar=getchar(start)
  local exitanchors=steps[1].coverage[startchar] 
  if exitanchors then
    local done=false
    if marks[startchar] then
      if trace_cursive then
        logprocess("%s: ignoring cursive for mark %s",pref(dataset,sequence),gref(startchar))
      end
    else
      local nxt=getnext(start)
      while not done and nxt do
        local nextchar=ischar(nxt,currentfont)
        if not nextchar then
          break
        elseif marks[nextchar] then
          nxt=getnext(nxt)
        else
          local exit=exitanchors[3]
          if exit then
            local entry=exitanchors[1][nextchar]
            if entry then
              entry=entry[2]
              if entry then
                local dx,dy,bound=setcursive(start,nxt,factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                if trace_cursive then
                  logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in %s mode",pref(dataset,sequence),gref(startchar),gref(nextchar),dx,dy,anchor,bound,mref(rlmode))
                end
                done=true
                break
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
      logprocess("%s, cursive %s is already done",pref(dataset,sequence),gref(getchar(start)),alreadydone)
    end
    return head,start,false
  end
end
local function show_skip(dataset,sequence,char,ck,class)
  logwarning("%s: skipping char %s, class %a, rule %a, lookuptype %a",cref(dataset,sequence),gref(char),class,ck[1],ck[8] or ck[2])
end
local function chaindisk(head,start,last,dataset,sequence,chainlookup,rlmode,k,ck,chainproc)
  if not start then
    return head,start,false
  end
  local startishead=start==head
  local seq=ck[3]
  local f=ck[4]
  local l=ck[5]
  local s=#seq
  local done=false
  local sweepnode=sweepnode
  local sweeptype=sweeptype
  local sweepoverflow=false
  local checkdisc=getprev(head) 
  local keepdisc=not sweepnode
  local lookaheaddisc=nil
  local backtrackdisc=nil
  local current=start
  local last=start
  local prev=getprev(start)
  local i=f
  while i<=l do
    local id=getid(current)
    if id==glyph_code then
      i=i+1
      last=current
      current=getnext(current)
    elseif id==disc_code then
      if keepdisc then
        keepdisc=false
        if notmatchpre[current]~=notmatchreplace[current] then
          lookaheaddisc=current
        end
        local replace=getfield(current,"replace")
        while replace and i<=l do
          if getid(replace)==glyph_code then
            i=i+1
          end
          replace=getnext(replace)
        end
        last=current
        current=getnext(c)
      else
        head,current=flattendisk(head,current)
      end
    else
      last=current
      current=getnext(current)
    end
    if current then
    elseif sweepoverflow then
      break
    elseif sweeptype=="post" or sweeptype=="replace" then
      current=getnext(sweepnode)
      if current then
        sweeptype=nil
        sweepoverflow=true
      else
        break
      end
    else
      break 
    end
  end
  if sweepoverflow then
    local prev=current and getprev(current)
    if not current or prev~=sweepnode then
      local head=getnext(sweepnode)
      local tail=nil
      if prev then
        tail=prev
        setprev(current,sweepnode)
      else
        tail=find_node_tail(head)
      end
      setnext(sweepnode,current)
      setprev(head,nil)
      setnext(tail,nil)
      appenddisc(sweepnode,head)
    end
  end
  if l<s then
    local i=l
    local t=sweeptype=="post" or sweeptype=="replace"
    while current and i<s do
      local id=getid(current)
      if id==glyph_code then
        i=i+1
        current=getnext(current)
      elseif id==disc_code then
        if keepdisc then
          keepdisc=false
          if notmatchpre[current]~=notmatchreplace[current] then
            lookaheaddisc=current
          end
          local replace=getfield(c,"replace")
          while replace and i<s do
            if getid(replace)==glyph_code then
              i=i+1
            end
            replace=getnext(replace)
          end
          current=getnext(current)
        elseif notmatchpre[current]~=notmatchreplace[current] then
          head,current=flattendisk(head,current)
        else
          current=getnext(current) 
        end
      else
        current=getnext(current)
      end
      if not current and t then
        current=getnext(sweepnode)
        if current then
          sweeptype=nil
        end
      end
    end
  end
  if f>1 then
    local current=prev
    local i=f
    local t=sweeptype=="pre" or sweeptype=="replace"
    if not current and t and current==checkdisk then
      current=getprev(sweepnode)
    end
    while current and i>1 do 
      local id=getid(current)
      if id==glyph_code then
        i=i-1
      elseif id==disc_code then
        if keepdisc then
          keepdisc=false
          if notmatchpost[current]~=notmatchreplace[current] then
            backtrackdisc=current
          end
          local replace=getfield(current,"replace")
          while replace and i>1 do
            if getid(replace)==glyph_code then
              i=i-1
            end
            replace=getnext(replace)
          end
        elseif notmatchpost[current]~=notmatchreplace[current] then
          head,current=flattendisk(head,current)
        end
      end
      current=getprev(current)
      if t and current==checkdisk then
        current=getprev(sweepnode)
      end
    end
  end
  local ok=false
  if lookaheaddisc then
    local cf=start
    local cl=getprev(lookaheaddisc)
    local cprev=getprev(start)
    local insertedmarks=0
    while cprev do
      local char=ischar(cf,currentfont)
      if char and marks[char] then
        insertedmarks=insertedmarks+1
        cf=cprev
        startishead=cf==head
        cprev=getprev(cprev)
      else
        break
      end
    end
    setprev(lookaheaddisc,cprev)
    if cprev then
      setnext(cprev,lookaheaddisc)
    end
    setprev(cf,nil)
    setnext(cl,nil)
    if startishead then
      head=lookaheaddisc
    end
    local pre,post,replace=getdisc(lookaheaddisc)
    local new=copy_node_list(cf)
    local cnew=new
    for i=1,insertedmarks do
      cnew=getnext(cnew)
    end
    local clast=cnew
    for i=f,l do
      clast=getnext(clast)
    end
    if not notmatchpre[lookaheaddisc] then
      cf,start,ok=chainproc(cf,start,last,dataset,sequence,chainlookup,rlmode,k)
    end
    if not notmatchreplace[lookaheaddisc] then
      new,cnew,ok=chainproc(new,cnew,clast,dataset,sequence,chainlookup,rlmode,k)
    end
    if pre then
      setlink(cl,pre)
    end
    if replace then
      local tail=find_node_tail(new)
      setlink(tail,replace)
    end
    setdisc(lookaheaddisc,cf,post,new)
    start=getprev(lookaheaddisc)
    sweephead[cf]=getnext(clast)
    sweephead[new]=getnext(last)
  elseif backtrackdisc then
    local cf=getnext(backtrackdisc)
    local cl=start
    local cnext=getnext(start)
    local insertedmarks=0
    while cnext do
      local char=ischar(cnext,currentfont)
      if char and marks[char] then
        insertedmarks=insertedmarks+1
        cl=cnext
        cnext=getnext(cnext)
      else
        break
      end
    end
    if cnext then
      setprev(cnext,backtrackdisc)
    end
    setnext(backtrackdisc,cnext)
    setprev(cf,nil)
    setnext(cl,nil)
    local pre,post,replace,pretail,posttail,replacetail=getdisc(backtrackdisc,true)
    local new=copy_node_list(cf)
    local cnew=find_node_tail(new)
    for i=1,insertedmarks do
      cnew=getprev(cnew)
    end
    local clast=cnew
    for i=f,l do
      clast=getnext(clast)
    end
    if not notmatchpost[backtrackdisc] then
      cf,start,ok=chainproc(cf,start,last,dataset,sequence,chainlookup,rlmode,k)
    end
    if not notmatchreplace[backtrackdisc] then
      new,cnew,ok=chainproc(new,cnew,clast,dataset,sequence,chainlookup,rlmode,k)
    end
    if post then
      setlink(posttail,cf)
    else
      post=cf
    end
    if replace then
      setlink(replacetail,new)
    else
      replace=new
    end
    setdisc(backtrackdisc,pre,post,replace)
    start=getprev(backtrackdisc)
    sweephead[post]=getnext(clast)
    sweephead[replace]=getnext(last)
  else
    head,start,ok=chainproc(head,start,last,dataset,sequence,chainlookup,rlmode,k)
  end
  return head,start,ok
end
local noflags={ false,false,false,false }
local function handle_contextchain(head,start,dataset,sequence,contexts,rlmode)
  local sweepnode=sweepnode
  local sweeptype=sweeptype
  local currentfont=currentfont
  local diskseen=false
  local checkdisc=getprev(head)
  local flags=sequence.flags or noflags
  local done=false
  local skipmark=flags[1]
  local skipligature=flags[2]
  local skipbase=flags[3]
  local markclass=sequence.markclass
  local skipped=false
  for k=1,#contexts do 
    local match=true
    local current=start
    local last=start
    local ck=contexts[k]
    local seq=ck[3]
    local s=#seq
    local size=1
    if s==1 then
      local char=ischar(current,currentfont)
      if char then
        match=seq[1][char]
      end
    else
      local f=ck[4]
      local l=ck[5]
      size=l-f+1
      if size>1 then
        local discfound=nil
        local n=f+1
        last=getnext(last) 
        while n<=l do
          if not last and (sweeptype=="post" or sweeptype=="replace") then
            last=getnext(sweepnode)
            sweeptype=nil
          end
          if last then
            local char,id=ischar(last,currentfont)
            if char then
              local ccd=descriptions[char]
              if ccd then
                local class=ccd.class or "base"
                if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                  skipped=true
                  if trace_skips then
                    show_skip(dataset,sequence,char,ck,class)
                  end
                  last=getnext(last)
                elseif seq[n][char] then
                  if n<l then
                    last=getnext(last)
                  end
                  n=n+1
                else
                  if discfound then
                    notmatchreplace[discfound]=true
                    match=not notmatchpre[discfound]
                  else
                    match=false
                  end
                  break
                end
              else
                if discfound then
                  notmatchreplace[discfound]=true
                  match=not notmatchpre[discfound]
                else
                  match=false
                end
                break
              end
            elseif char==false then
              if discfound then
                notmatchreplace[discfound]=true
                match=not notmatchpre[discfound]
              else
                match=false
              end
              break
            elseif id==disc_code then
              diskseen=true
              discfound=last
              notmatchpre[last]=nil
              notmatchpost[last]=true
              notmatchreplace[last]=nil
              local pre,post,replace=getdisc(last)
              if pre then
                local n=n
                while pre do
                  if seq[n][getchar(pre)] then
                    n=n+1
                    pre=getnext(pre)
                    if n>l then
                      break
                    end
                  else
                    notmatchpre[last]=true
                    break
                  end
                end
                if n<=l then
                  notmatchpre[last]=true
                end
              else
                notmatchpre[last]=true
              end
              if replace then
                while replace do
                  if seq[n][getchar(replace)] then
                    n=n+1
                    replace=getnext(replace)
                    if n>l then
                      break
                    end
                  else
                    notmatchreplace[last]=true
                    match=not notmatchpre[last]
                    break
                  end
                end
                match=not notmatchpre[last]
              end
              last=getnext(last)
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
      if match and f>1 then
        local prev=getprev(start)
        if prev then
          if prev==checkdisc and (sweeptype=="pre" or sweeptype=="replace") then
            prev=getprev(sweepnode)
          end
          if prev then
            local discfound=nil
            local n=f-1
            while n>=1 do
              if prev then
                local char,id=ischar(prev,currentfont)
                if char then
                  local ccd=descriptions[char]
                  if ccd then
                    local class=ccd.class
                    if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                      skipped=true
                      if trace_skips then
                        show_skip(dataset,sequence,char,ck,class)
                      end
                      prev=getprev(prev) 
                    elseif seq[n][char] then
                      if n>1 then 
                        prev=getprev(prev) 
                      end
                      n=n-1
                    else
                      if discfound then
                        notmatchreplace[discfound]=true
                        match=not notmatchpost[discfound]
                      else
                        match=false
                      end
                      break
                    end
                  else
                    if discfound then
                      notmatchreplace[discfound]=true
                      match=not notmatchpost[discfound]
                    else
                      match=false
                    end
                    break
                  end
                elseif char==false then
                  if discfound then
                    notmatchreplace[discfound]=true
                    match=not notmatchpost[discfound]
                  else
                    match=false
                  end
                  break
                elseif id==disc_code then
                  diskseen=true
                  discfound=prev
                  notmatchpre[prev]=true
                  notmatchpost[prev]=nil
                  notmatchreplace[prev]=nil
                  local pre,post,replace,pretail,posttail,replacetail=getdisc(prev,true)
                  if pre~=start and post~=start and replace~=start then
                    if post then
                      local n=n
                      while posttail do
                        if seq[n][getchar(posttail)] then
                          n=n-1
                          if posttail==post then
                            break
                          else
                            posttail=getprev(posttail)
                            if n<1 then
                              break
                            end
                          end
                        else
                          notmatchpost[prev]=true
                          break
                        end
                      end
                      if n>=1 then
                        notmatchpost[prev]=true
                      end
                    else
                      notmatchpost[prev]=true
                    end
                    if replace then
                      while replacetail do
                        if seq[n][getchar(replacetail)] then
                          n=n-1
                          if replacetail==replace then
                            break
                          else
                            replacetail=getprev(replacetail)
                            if n<1 then
                              break
                            end
                          end
                        else
                          notmatchreplace[prev]=true
                          match=not notmatchpost[prev]
                          break
                        end
                      end
                      if not match then
                        break
                      end
                    end
                  end
                  prev=getprev(prev)
                elseif seq[n][32] and isspace(prev,threshold) then
                  n=n-1
                  prev=getprev(prev)
                else
                  match=false
                  break
                end
              else
                match=false
                break
              end
            end
          else
            match=false
          end
        else
          match=false
        end
      end
      if match and s>l then
        local current=last and getnext(last)
        if not current then
          if sweeptype=="post" or sweeptype=="replace" then
            current=getnext(sweepnode)
          end
        end
        if current then
          local discfound=nil
          local n=l+1
          while n<=s do
            if current then
              local char,id=ischar(current,currentfont)
              if char then
                local ccd=descriptions[char]
                if ccd then
                  local class=ccd.class
                  if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                    skipped=true
                    if trace_skips then
                      show_skip(dataset,sequence,char,ck,class)
                    end
                    current=getnext(current) 
                  elseif seq[n][char] then
                    if n<s then 
                      current=getnext(current) 
                    end
                    n=n+1
                  else
                    if discfound then
                      notmatchreplace[discfound]=true
                      match=not notmatchpre[discfound]
                    else
                      match=false
                    end
                    break
                  end
                else
                  if discfound then
                    notmatchreplace[discfound]=true
                    match=not notmatchpre[discfound]
                  else
                    match=false
                  end
                  break
                end
              elseif char==false then
                if discfound then
                  notmatchreplace[discfound]=true
                  match=not notmatchpre[discfound]
                else
                  match=false
                end
                break
              elseif id==disc_code then
                diskseen=true
                discfound=current
                notmatchpre[current]=nil
                notmatchpost[current]=true
                notmatchreplace[current]=nil
                local pre,post,replace=getdisc(current)
                if pre then
                  local n=n
                  while pre do
                    if seq[n][getchar(pre)] then
                      n=n+1
                      pre=getnext(pre)
                      if n>s then
                        break
                      end
                    else
                      notmatchpre[current]=true
                      break
                    end
                  end
                  if n<=s then
                    notmatchpre[current]=true
                  end
                else
                  notmatchpre[current]=true
                end
                if replace then
                  while replace do
                    if seq[n][getchar(replace)] then
                      n=n+1
                      replace=getnext(replace)
                      if n>s then
                        break
                      end
                    else
                      notmatchreplace[current]=true
                      match=notmatchpre[current]
                      break
                    end
                  end
                  if not match then
                    break
                  end
                else
                end
                current=getnext(current)
              elseif seq[n][32] and isspace(current,threshold) then
                n=n+1
                current=getnext(current)
              else
                match=false
                break
              end
            else
              match=false
              break
            end
          end
        else
          match=false
        end
      end
    end
    if match then
      local diskchain=diskseen or sweepnode
      if trace_contexts then
        local rule=ck[1]
        local lookuptype=ck[8] or ck[2]
        local first=ck[4]
        local last=ck[5]
        local char=getchar(start)
        logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %a",
          cref(dataset,sequence),rule,gref(char),first-1,last-first+1,s-last,lookuptype)
      end
      local chainlookups=ck[6]
      if chainlookups then
        local nofchainlookups=#chainlookups
        if size==1 then
          local chainlookup=chainlookups[1]
          local chainkind=chainlookup.type
          local chainproc=chainprocs[chainkind]
          if chainproc then
            local ok
            if diskchain then
              head,start,ok=chaindisk(head,start,last,dataset,sequence,chainlookup,rlmode,1,ck,chainproc)
            else
              head,start,ok=chainproc(head,start,last,dataset,sequence,chainlookup,rlmode,1)
            end
            if ok then
              done=true
            end
          else
            logprocess("%s: %s is not yet supported (1)",cref(dataset,sequence),chainkind)
          end
         else
          local i=1
          while start do
            if skipped then
              while start do 
                local char=getchar(start)
                local ccd=descriptions[char]
                if ccd then
                  local class=ccd.class or "base"
                  if class==skipmark or class==skipligature or class==skipbase or (markclass and class=="mark" and not markclass[char]) then
                    start=getnext(start)
                  else
                    break
                  end
                else
                  break
                end
              end
            end
            local chainlookup=chainlookups[i]
            if chainlookup then
              local chainkind=chainlookup.type
              local chainproc=chainprocs[chainkind]
              if chainproc then
                local ok,n
                if diskchain then
                  head,start,ok=chaindisk(head,start,last,dataset,sequence,chainlookup,rlmode,i,ck,chainproc)
                else
                  head,start,ok,n=chainproc(head,start,last,dataset,sequence,chainlookup,rlmode,i)
                end
                if ok then
                  done=true
                  if n and n>1 and i+n>nofchainlookups then
                    break
                  end
                end
              else
                logprocess("%s: %s is not yet supported (2)",cref(dataset,sequence),chainkind)
              end
            end
            i=i+1
            if i>size or not start then
              break
            elseif start then
              start=getnext(start)
            end
          end
        end
      else
        local replacements=ck[7]
        if replacements then
          head,start,done=reversesub(head,start,last,dataset,sequence,replacements,rlmode)
        else
          done=true
          if trace_contexts then
            logprocess("%s: skipping match",cref(dataset,sequence))
          end
        end
      end
      if done then
        break 
      end
    end
  end
  if diskseen then
    notmatchpre={}
    notmatchpost={}
    notmatchreplace={}
  end
  return head,start,done
end
handlers.gsub_context=handle_contextchain
handlers.gsub_contextchain=handle_contextchain
handlers.gsub_reversecontextchain=handle_contextchain
handlers.gpos_contextchain=handle_contextchain
handlers.gpos_context=handle_contextchain
local function chained_contextchain(head,start,stop,dataset,sequence,currentlookup,rlmode)
  local steps=currentlookup.steps
  local nofsteps=currentlookup.nofsteps
  if nofsteps>1 then
    reportmoresteps(dataset,sequence)
  end
  return handle_contextchain(head,start,dataset,sequence,currentlookup,rlmode)
end
chainprocs.gsub_context=chained_contextchain
chainprocs.gsub_contextchain=chained_contextchain
chainprocs.gsub_reversecontextchain=chained_contextchain
chainprocs.gpos_contextchain=chained_contextchain
chainprocs.gpos_context=chained_contextchain
local missing=setmetatableindex("table")
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  report_process(...)
end
local logwarning=report_process
local function report_missing_coverage(dataset,sequence)
  local t=missing[currentfont]
  if not t[sequence] then
    t[sequence]=true
    logwarning("missing coverage for feature %a, lookup %a, type %a, font %a, name %a",
      dataset[4],sequence.name,sequence.type,currentfont,tfmdata.properties.fullname)
  end
end
local resolved={}
local sequencelists=setmetatableindex(function(t,font)
  local sequences=fontdata[font].resources.sequences
  if not sequences or not next(sequences) then
    sequences=false
  end
  t[font]=sequences
  return sequences
end)
local autofeatures=fonts.analyzers.features
local featuretypes=otf.tables.featuretypes
local defaultscript=otf.features.checkeddefaultscript
local defaultlanguage=otf.features.checkeddefaultlanguage
local function initialize(sequence,script,language,enabled,autoscript,autolanguage)
  local features=sequence.features
  if features then
    local order=sequence.order
    if order then
      local featuretype=featuretypes[sequence.type or "unknown"]
      for i=1,#order do
        local kind=order[i]
        local valid=enabled[kind]
        if valid then
          local scripts=features[kind]
          local languages=scripts and (
            scripts[script] or
            scripts[wildcard] or
            (autoscript and defaultscript(featuretype,autoscript,scripts))
          )
          local enabled=languages and (
            languages[language] or
            languages[wildcard] or
            (autolanguage and defaultlanguage(featuretype,autolanguage,languages))
          )
          if enabled then
            return { valid,autofeatures[kind] or false,sequence,kind }
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
  local autoscript=enabled and enabled.autoscript
  local autolanguage=enabled and enabled.autolanguage
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
      local v=enabled and initialize(sequences[s],script,language,enabled,autoscript,autolanguage)
      if v then
        rl[#rl+1]=v
      end
    end
  end
  return rl
end
local function report_disc(what,n)
  report_run("%s: %s > %s",what,n,languages.serializediscretionary(n))
end
local function kernrun(disc,k_run,font,attr,...)
  if trace_kernruns then
    report_disc("kern",disc)
  end
  local prev,next=getboth(disc)
  local nextstart=next
  local done=false
  local pre,post,replace,pretail,posttail,replacetail=getdisc(disc,true)
  local prevmarks=prev
  while prevmarks do
    local char=ischar(prevmarks,font)
    if char and marks[char] then
      prevmarks=getprev(prevmarks)
    else
      break
    end
  end
  if prev and not ischar(prev,font) then 
    prev=false
  end
  if next and not ischar(next,font) then 
    next=false
  end
  if pre then
    if k_run(pre,"injections",nil,font,attr,...) then
      done=true
    end
    if prev then
      local nest=getprev(pre)
      setlink(prev,pre)
      if k_run(prevmarks,"preinjections",pre,font,attr,...) then 
        done=true
      end
      setprev(pre,nest)
      setnext(prev,disc)
    end
  end
  if post then
    if k_run(post,"injections",nil,font,attr,...) then
      done=true
    end
    if next then
      setlink(posttail,next)
      if k_run(posttail,"postinjections",next,font,attr,...) then
        done=true
      end
      setnext(posttail,nil)
      setprev(next,disc)
    end
  end
  if replace then
    if k_run(replace,"injections",nil,font,attr,...) then
      done=true
    end
    if prev then
      local nest=getprev(replace)
      setlink(prev,replace)
      if k_run(prevmarks,"replaceinjections",replace,font,attr,...) then 
        done=true
      end
      setprev(replace,nest)
      setnext(prev,disc)
    end
    if next then
      setlink(replacetail,next)
      if k_run(replacetail,"replaceinjections",next,font,attr,...) then
        done=true
      end
      setnext(replacetail,nil)
      setprev(next,disc)
    end
  elseif prev and next then
    setlink(prev,next)
    if k_run(prevmarks,"emptyinjections",next,font,attr,...) then
      done=true
    end
    setlink(prev,disc)
    setlink(disc,next)
  end
  return nextstart,done
end
local function comprun(disc,c_run,...)
  if trace_compruns then
    report_disc("comp",disc)
  end
  local pre,post,replace=getdisc(disc)
  local renewed=false
  if pre then
    sweepnode=disc
    sweeptype="pre" 
    local new,done=c_run(pre,...)
    if done then
      pre=new
      renewed=true
    end
  end
  if post then
    sweepnode=disc
    sweeptype="post"
    local new,done=c_run(post,...)
    if done then
      post=new
      renewed=true
    end
  end
  if replace then
    sweepnode=disc
    sweeptype="replace"
    local new,done=c_run(replace,...)
    if done then
      replace=new
      renewed=true
    end
  end
  sweepnode=nil
  sweeptype=nil
  if renewed then
    setdisc(disc,pre,post,replace)
  end
  return getnext(disc),renewed
end
local function testrun(disc,t_run,c_run,...)
  if trace_testruns then
    report_disc("test",disc)
  end
  local prev,next=getboth(disc)
  if not next then
    return
  end
  local pre,post,replace,pretail,posttail,replacetail=getdisc(disc,true)
  local done=false
  if replace and prev then
    setlink(replacetail,next)
    local ok,overflow=t_run(replace,next,...)
    if ok and overflow then
      setfield(disc,"replace",nil)
      setlink(prev,replace)
      setboth(disc)
      flush_node_list(disc)
      return replace,true 
    else
      setnext(replacetail)
      setprev(next,disc)
    end
  end
  local renewed=false
  if pre then
    sweepnode=disc
    sweeptype="pre"
    local new,ok=c_run(pre,...)
    if ok then
      pre=new
      renewed=true
    end
  end
  if post then
    sweepnode=disc
    sweeptype="post"
    local new,ok=c_run(post,...)
    if ok then
      post=new
      renewed=true
    end
  end
  if replace then
    sweepnode=disc
    sweeptype="replace"
    local new,ok=c_run(replace,...)
    if ok then
      replace=new
      renewed=true
    end
  end
  sweepnode=nil
  sweeptype=nil
  if renewed then
    setdisc(disc,pre,post,replace)
    return next,true
  else
    return next,done
  end
end
local nesting=0
local function c_run_single(head,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
  local done=false
  local sweep=sweephead[head]
  if sweep then
    start=sweep
    sweephead[head]=nil
  else
    start=head
  end
  while start do
    local char=ischar(start,font)
    if char then
      local a=attr and getattr(start,0)
      if not a or (a==attr) then
        local lookupmatch=lookupcache[char]
        if lookupmatch then
          local ok
          head,start,ok=handler(head,start,dataset,sequence,lookupmatch,rlmode,step,1)
          if ok then
            done=true
          end
        end
        if start then
          start=getnext(start)
        end
      else
        start=getnext(start)
      end
    elseif char==false then
      return head,done
    elseif sweep then
      return head,done
    else
      start=getnext(start)
    end
  end
  return head,done
end
local function t_run_single(start,stop,font,attr,lookupcache)
  while start~=stop do
    local char=ischar(start,font)
    if char then
      local a=attr and getattr(start,0)
      if not a or (a==attr) then
        local lookupmatch=lookupcache[char]
        if lookupmatch then
          local s=getnext(start)
          local l=nil
          local d=0
          while s do
            if s==stop then
              d=1
            elseif d>0 then
              d=d+1
            end
            local lg=lookupmatch[getchar(s)]
            if lg then
              l=lg
              s=getnext(s)
            else
              break
            end
          end
          if l and l.ligature then
            return true,d>1
          end
        end
      end
      start=getnext(start)
    else
      break
    end
  end
end
local function k_run_single(sub,injection,last,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
  local a=attr and getattr(sub,0)
  if not a or (a==attr) then
    for n in traverse_nodes(sub) do 
      if n==last then
        break
      end
      local char=ischar(n)
      if char then
        local lookupmatch=lookupcache[char]
        if lookupmatch then
          local h,d,ok=handler(sub,n,dataset,sequence,lookupmatch,rlmode,step,1,injection)
          if ok then
            return true
          end
        end
      end
    end
  end
end
local function c_run_multiple(head,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
  local done=false
  local sweep=sweephead[head]
  if sweep then
    start=sweep
    sweephead[head]=nil
  else
    start=head
  end
  while start do
    local char=ischar(start,font)
    if char then
      local a=attr and getattr(start,0)
      if not a or (a==attr) then
        for i=1,nofsteps do
          local step=steps[i]
          local lookupcache=step.coverage
          if lookupcache then
            local lookupmatch=lookupcache[char]
            if lookupmatch then
              local ok
              head,start,ok=handler(head,start,dataset,sequence,lookupmatch,rlmode,step,i)
              if ok then
                done=true
                break
              elseif not start then
                break
              end
            end
          else
            report_missing_coverage(dataset,sequence)
          end
        end
        if start then
          start=getnext(start)
        end
      else
        start=getnext(start)
      end
    elseif char==false then
      return head,done
    elseif sweep then
      return head,done
    else
      start=getnext(start)
    end
  end
  return head,done
end
local function t_run_multiple(start,stop,font,attr,steps,nofsteps)
  while start~=stop do
    local char=ischar(start,font)
    if char then
      local a=attr and getattr(start,0)
      if not a or (a==attr) then
        for i=1,nofsteps do
          local step=steps[i]
          local lookupcache=step.coverage
          if lookupcache then
            local lookupmatch=lookupcache[char]
            if lookupmatch then
              local s=getnext(start)
              local l=nil
              local d=0
              while s do
                if s==stop then
                  d=1
                elseif d>0 then
                  d=d+1
                end
                local lg=lookupmatch[getchar(s)]
                if lg then
                  l=lg
                  s=getnext(s)
                else
                  break
                end
              end
              if l and l.ligature then
                return true,d>1
              end
            end
          else
            report_missing_coverage(dataset,sequence)
          end
        end
      end
      start=getnext(start)
    else
      break
    end
  end
end
local function k_run_multiple(sub,injection,last,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
  local a=attr and getattr(sub,0)
  if not a or (a==attr) then
    for n in traverse_nodes(sub) do 
      if n==last then
        break
      end
      local char=ischar(n)
      if char then
        for i=1,nofsteps do
          local step=steps[i]
          local lookupcache=step.coverage
          if lookupcache then
            local lookupmatch=lookupcache[char]
            if lookupmatch then
              local h,d,ok=handler(head,n,dataset,sequence,lookupmatch,step,rlmode,i,injection)
              if ok then
                return true
              end
            end
          else
            report_missing_coverage(dataset,sequence)
          end
        end
      end
    end
  end
end
local function txtdirstate(start,stack,top,rlparmode)
  local dir=getfield(start,"dir")
  local new=1
  if dir=="+TRT" then
    top=top+1
    stack[top]=dir
    new=-1
  elseif dir=="+TLT" then
    top=top+1
    stack[top]=dir
  elseif dir=="-TRT" or dir=="-TLT" then
    top=top-1
    if stack[top]=="+TRT" then
      new=-1
    end
  else
    new=rlparmode
  end
  if trace_directions then
    report_process("directions after txtdir %a: parmode %a, txtmode %a, level %a",dir,mref(rlparmode),mref(new),top)
  end
  return getnext(start),top,new
end
local function pardirstate(start)
  local dir=getfield(start,"dir")
  local new=0
  if dir=="TLT" then
    new=1
  elseif dir=="TRT" then
    new=-1
  end
  if trace_directions then
    report_process("directions after pardir %a: parmode %a",dir,mref(new))
  end
  return getnext(start),new,new
end
local function featuresprocessor(head,font,attr)
  local sequences=sequencelists[font] 
  if not sequencelists then
    return head,false
  end
  nesting=nesting+1
  if nesting==1 then
    currentfont=font
    tfmdata=fontdata[font]
    descriptions=tfmdata.descriptions
    characters=tfmdata.characters
    marks=tfmdata.resources.marks
    threshold,
    factor=getthreshold(font)
  elseif currentfont~=font then
    report_warning("nested call with a different font, level %s, quitting",nesting)
    nesting=nesting-1
    return head,false
  end
  head=tonut(head)
  if trace_steps then
    checkstep(head)
  end
  local rlmode=0
  local done=false
  local datasets=otf.dataset(tfmdata,font,attr)
  local dirstack={} 
  sweephead={}
  for s=1,#datasets do
    local dataset=datasets[s]
    local attribute=dataset[2]
    local sequence=dataset[3] 
    local rlparmode=0
    local topstack=0
    local success=false
    local typ=sequence.type
    local gpossing=typ=="gpos_single" or typ=="gpos_pair" 
    local handler=handlers[typ]
    local steps=sequence.steps
    local nofsteps=sequence.nofsteps
    if not steps then
      local h,d,ok=handler(head,head,dataset,sequence,nil,nil,nil,0,font,attr)
      if ok then
        success=true
        if h then
          head=h
        end
      end
    elseif typ=="gsub_reversecontextchain" then
      local start=find_node_tail(head)
      while start do
        local char=ischar(start,font)
        if char then
          local a=attr and getattr(start,0)
          if not a or (a==attr) then
            for i=1,nofsteps do
              local step=steps[i]
              local lookupcache=step.coverage
              if lookupcache then
                local lookupmatch=lookupcache[char]
                if lookupmatch then
                  local ok
                  head,start,ok=handler(head,start,dataset,sequence,lookupmatch,rlmode,step,i)
                  if ok then
                    success=true
                    break
                  end
                end
              else
                report_missing_coverage(dataset,sequence)
              end
            end
            if start then
              start=getprev(start)
            end
          else
            start=getprev(start)
          end
        else
          start=getprev(start)
        end
      end
    else
      local start=head 
      rlmode=0 
      if nofsteps==1 then 
        local step=steps[1]
        local lookupcache=step.coverage
        if not lookupcache then
          report_missing_coverage(dataset,sequence)
        else
          while start do
            local char,id=ischar(start,font)
            if char then
              local a=attr and getattr(start,0)
              if a then
                a=(a==attr) and (not attribute or getprop(start,a_state)==attribute)
              else
                a=not attribute or getprop(start,a_state)==attribute
              end
              if a then
                local lookupmatch=lookupcache[char]
                if lookupmatch then
                  local ok
                  head,start,ok=handler(head,start,dataset,sequence,lookupmatch,rlmode,step,1)
                  if ok then
                    success=true
                  end
                end
                if start then
                  start=getnext(start)
                end
              else
                start=getnext(start)
              end
            elseif char==false then
              start=getnext(start)
            elseif id==disc_code then
              local ok
              if gpossing then
                start,ok=kernrun(start,k_run_single,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
              elseif typ=="gsub_ligature" then
                start,ok=testrun(start,t_run_single,c_run_single,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
              else
                start,ok=comprun(start,c_run_single,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
              end
              if ok then
                success=true
              end
            elseif id==math_code then
              start=getnext(end_of_math(start))
            elseif id==dir_code then
              start,topstack,rlmode=txtdirstate(start,dirstack,topstack,rlparmode)
            elseif id==localpar_code then
              start,rlparmode,rlmode=pardirstate(start)
            else
              start=getnext(start)
            end
          end
        end
      else
        while start do
          local char,id=ischar(start,font)
          if char then
            local a=attr and getattr(start,0)
            if a then
              a=(a==attr) and (not attribute or getprop(start,a_state)==attribute)
            else
              a=not attribute or getprop(start,a_state)==attribute
            end
            if a then
              for i=1,nofsteps do
                local step=steps[i]
                local lookupcache=step.coverage
                if lookupcache then
                  local lookupmatch=lookupcache[char]
                  if lookupmatch then
                    local ok
                    head,start,ok=handler(head,start,dataset,sequence,lookupmatch,rlmode,step,i)
                    if ok then
                      success=true
                      break
                    elseif not start then
                      break
                    end
                  end
                else
                  report_missing_coverage(dataset,sequence)
                end
              end
              if start then
                start=getnext(start)
              end
            else
              start=getnext(start)
            end
          elseif char==false then
            start=getnext(start)
          elseif id==disc_code then
            local ok
            if gpossing then
              start,ok=kernrun(start,k_run_multiple,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
            elseif typ=="gsub_ligature" then
              start,ok=testrun(start,t_run_multiple,c_run_multiple,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
            else
              start,ok=comprun(start,c_run_multiple,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
            end
            if ok then
              success=true
            end
          elseif id==math_code then
            start=getnext(end_of_math(start))
          elseif id==dir_code then
            start,topstack,rlmode=txtdirstate(start,dirstack,topstack,rlparmode)
          elseif id==localpar_code then
            start,rlparmode,rlmode=pardirstate(start)
          else
            start=getnext(start)
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
  nesting=nesting-1
  head=tonode(head)
  return head,done
end
local function featuresinitializer(tfmdata,value)
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
otf.nodemodeinitializer=featuresinitializer
otf.featuresprocessor=featuresprocessor
otf.handlers=handlers
local setspacekerns=nodes.injections.setspacekerns if not setspacekerns then os.exit() end
if fontfeatures then
  function otf.handlers.trigger_space_kerns(head,start,dataset,sequence,_,_,_,_,font,attr)
    local features=fontfeatures[font]
    local enabled=features.spacekern==true and features.kern==true
    if enabled then
      setspacekerns(font,sequence)
    end
    return head,start,enabled
  end
else 
  function otf.handlers.trigger_space_kerns(head,start,dataset,sequence,_,_,_,_,font,attr)
    local shared=fontdata[font].shared
    local features=shared and shared.features
    local enabled=features and features.spacekern==true and features.kern==true
    if enabled then
      setspacekerns(font,sequence)
    end
    return head,start,enabled
  end
end
local function hasspacekerns(data)
  local sequences=data.resources.sequences
  for i=1,#sequences do
    local sequence=sequences[i]
    local steps=sequence.steps
    if steps and sequence.features.kern then
      for i=1,#steps do
        local coverage=steps[i].coverage
        if not coverage then
        elseif coverage[32] then
          return true
        else
          for k,v in next,coverage do
            if v[32] then
              return true
            end
          end
        end
      end
    end
  end
  return false
end
otf.readers.registerextender {
  name="spacekerns",
  action=function(data)
    data.properties.hasspacekerns=hasspacekerns(data)
  end
}
local function spaceinitializer(tfmdata,value) 
  local resources=tfmdata.resources
  local spacekerns=resources and resources.spacekerns
  local properties=tfmdata.properties
  if value and spacekerns==nil then
    if properties and properties.hasspacekerns then
      local sequences=resources.sequences
      local left={}
      local right={}
      local last=0
      local feat=nil
      for i=1,#sequences do
        local sequence=sequences[i]
        local steps=sequence.steps
        if steps then
          local kern=sequence.features.kern
          if kern then
            if feat then
              for script,languages in next,kern do
                local f=feat[k]
                if f then
                  for l in next,languages do
                    f[l]=true
                  end
                else
                  feat[script]=languages
                end
              end
            else
              feat=kern
            end
            for i=1,#steps do
              local step=steps[i]
              local coverage=step.coverage
              if coverage then
                local kerns=coverage[32]
                if kerns then
                  for k,v in next,kerns do
                    if type(v)=="table" then
                      right[k]=v[3] 
                    else
                      right[k]=v
                    end
                  end
                end
                for k,v in next,coverage do
                  local kern=v[32]
                  if kern then
                    if type(kern)=="table" then
                      left[k]=kern[3] 
                    else
                      left[k]=kern
                    end
                  end
                end
              end
            end
            last=i
          end
        else
        end
      end
      left=next(left) and left or false
      right=next(right) and right or false
      if left or right then
        spacekerns={
          left=left,
          right=right,
        }
        if last>0 then
          local triggersequence={
            features={ kern=feat or { dflt={ dflt=true,} } },
            flags=noflags,
            name="trigger_space_kerns",
            order={ "kern" },
            type="trigger_space_kerns",
            left=left,
            right=right,
          }
          insert(sequences,last,triggersequence)
        end
      else
        spacekerns=false
      end
    else
      spacekerns=false
    end
    resources.spacekerns=spacekerns
  end
  return spacekerns
end
registerotffeature {
  name="spacekern",
  description="space kern injection",
  default=true,
  initializers={
    node=spaceinitializer,
  },
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-osd']={ 
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Kai Eigner, TAT Zetwerk / Hans Hagen, PRAGMA ADE",
  copyright="TAT Zetwerk / PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local insert,imerge,copy=table.insert,table.imerge,table.copy
local next,type=next,type
local report_devanagari=logs.reporter("otf","devanagari")
fonts=fonts          or {}
fonts.analyzers=fonts.analyzers     or {}
fonts.analyzers.methods=fonts.analyzers.methods or { node={ otf={} } }
local otf=fonts.handlers.otf
local handlers=otf.handlers
local methods=fonts.analyzers.methods
local otffeatures=fonts.constructors.features.otf
local registerotffeature=otffeatures.register
local nuts=nodes.nuts
local tonode=nuts.tonode
local tonut=nuts.tonut
local getnext=nuts.getnext
local getprev=nuts.getprev
local getboth=nuts.getboth
local getid=nuts.getid
local getchar=nuts.getchar
local getfont=nuts.getfont
local getsubtype=nuts.getsubtype
local setlink=nuts.setlink
local setnext=nuts.setnext
local setprev=nuts.setprev
local setchar=nuts.setchar
local getprop=nuts.getprop
local setprop=nuts.setprop
local ischar=nuts.is_char
local insert_node_after=nuts.insert_after
local copy_node=nuts.copy
local remove_node=nuts.remove
local flush_list=nuts.flush_list
local flush_node=nuts.flush_node
local copyinjection=nodes.injections.copy 
local unsetvalue=attributes.unsetvalue
local fontdata=fonts.hashes.identifiers
local a_state=attributes.private('state')
local a_syllabe=attributes.private('syllabe')
local dotted_circle=0x25CC
local states=fonts.analyzers.states 
local s_rphf=states.rphf
local s_half=states.half
local s_pref=states.pref
local s_blwf=states.blwf
local s_pstf=states.pstf
local replace_all_nbsp=nil
replace_all_nbsp=function(head) 
  replace_all_nbsp=typesetters and typesetters.characters and typesetters.characters.replacenbspaces or function(head)
    return head
  end
  return replace_all_nbsp(head)
end
local xprocesscharacters=nil
if context then
  xprocesscharacters=function(head,font)
    xprocesscharacters=nodes.handlers.characters
    return xprocesscharacters(head,font)
  end
else
  xprocesscharacters=function(head,font)
    xprocesscharacters=nodes.handlers.nodepass 
    return xprocesscharacters(head,font)
  end
end
local function processcharacters(head,font)
  return tonut(xprocesscharacters(tonode(head))) 
end
local consonant={
  [0x0915]=true,[0x0916]=true,[0x0917]=true,[0x0918]=true,
  [0x0919]=true,[0x091A]=true,[0x091B]=true,[0x091C]=true,
  [0x091D]=true,[0x091E]=true,[0x091F]=true,[0x0920]=true,
  [0x0921]=true,[0x0922]=true,[0x0923]=true,[0x0924]=true,
  [0x0925]=true,[0x0926]=true,[0x0927]=true,[0x0928]=true,
  [0x0929]=true,[0x092A]=true,[0x092B]=true,[0x092C]=true,
  [0x092D]=true,[0x092E]=true,[0x092F]=true,[0x0930]=true,
  [0x0931]=true,[0x0932]=true,[0x0933]=true,[0x0934]=true,
  [0x0935]=true,[0x0936]=true,[0x0937]=true,[0x0938]=true,
  [0x0939]=true,[0x0958]=true,[0x0959]=true,[0x095A]=true,
  [0x095B]=true,[0x095C]=true,[0x095D]=true,[0x095E]=true,
  [0x095F]=true,[0x0979]=true,[0x097A]=true,
  [0x0C95]=true,[0x0C96]=true,[0x0C97]=true,[0x0C98]=true,
  [0x0C99]=true,[0x0C9A]=true,[0x0C9B]=true,[0x0C9C]=true,
  [0x0C9D]=true,[0x0C9E]=true,[0x0C9F]=true,[0x0CA0]=true,
  [0x0CA1]=true,[0x0CA2]=true,[0x0CA3]=true,[0x0CA4]=true,
  [0x0CA5]=true,[0x0CA6]=true,[0x0CA7]=true,[0x0CA8]=true,
  [0x0CA9]=true,[0x0CAA]=true,[0x0CAB]=true,[0x0CAC]=true,
  [0x0CAD]=true,[0x0CAE]=true,[0x0CAF]=true,[0x0CB0]=true,
  [0x0CB1]=true,[0x0CB2]=true,[0x0CB3]=true,[0x0CB4]=true,
  [0x0CB5]=true,[0x0CB6]=true,[0x0CB7]=true,[0x0CB8]=true,
  [0x0CB9]=true,
  [0x0CDE]=true,
  [0x0D15]=true,[0x0D16]=true,[0x0D17]=true,[0x0D18]=true,
  [0x0D19]=true,[0x0D1A]=true,[0x0D1B]=true,[0x0D1C]=true,
  [0x0D1D]=true,[0x0D1E]=true,[0x0D1F]=true,[0x0D20]=true,
  [0x0D21]=true,[0x0D22]=true,[0x0D23]=true,[0x0D24]=true,
  [0x0D25]=true,[0x0D26]=true,[0x0D27]=true,[0x0D28]=true,
  [0x0D29]=true,[0x0D2A]=true,[0x0D2B]=true,[0x0D2C]=true,
  [0x0D2D]=true,[0x0D2E]=true,[0x0D2F]=true,[0x0D30]=true,
  [0x0D31]=true,[0x0D32]=true,[0x0D33]=true,[0x0D34]=true,
  [0x0D35]=true,[0x0D36]=true,[0x0D37]=true,[0x0D38]=true,
  [0x0D39]=true,[0x0D3A]=true,
}
local independent_vowel={
  [0x0904]=true,[0x0905]=true,[0x0906]=true,[0x0907]=true,
  [0x0908]=true,[0x0909]=true,[0x090A]=true,[0x090B]=true,
  [0x090C]=true,[0x090D]=true,[0x090E]=true,[0x090F]=true,
  [0x0910]=true,[0x0911]=true,[0x0912]=true,[0x0913]=true,
  [0x0914]=true,[0x0960]=true,[0x0961]=true,[0x0972]=true,
  [0x0973]=true,[0x0974]=true,[0x0975]=true,[0x0976]=true,
  [0x0977]=true,
  [0x0C85]=true,[0x0C86]=true,[0x0C87]=true,[0x0C88]=true,
  [0x0C89]=true,[0x0C8A]=true,[0x0C8B]=true,[0x0C8C]=true,
  [0x0C8D]=true,[0x0C8E]=true,[0x0C8F]=true,[0x0C90]=true,
  [0x0C91]=true,[0x0C92]=true,[0x0C93]=true,[0x0C94]=true,
  [0x0D05]=true,[0x0D06]=true,[0x0D07]=true,[0x0D08]=true,
  [0x0D09]=true,[0x0D0A]=true,[0x0D0B]=true,[0x0D0C]=true,
  [0x0D0E]=true,[0x0D0F]=true,[0x0D10]=true,[0x0D12]=true,
  [0x0D13]=true,[0x0D14]=true,
}
local dependent_vowel={
  [0x093A]=true,[0x093B]=true,[0x093E]=true,[0x093F]=true,
  [0x0940]=true,[0x0941]=true,[0x0942]=true,[0x0943]=true,
  [0x0944]=true,[0x0945]=true,[0x0946]=true,[0x0947]=true,
  [0x0948]=true,[0x0949]=true,[0x094A]=true,[0x094B]=true,
  [0x094C]=true,[0x094E]=true,[0x094F]=true,[0x0955]=true,
  [0x0956]=true,[0x0957]=true,[0x0962]=true,[0x0963]=true,
  [0x0CBE]=true,[0x0CBF]=true,[0x0CC0]=true,[0x0CC1]=true,
  [0x0CC2]=true,[0x0CC3]=true,[0x0CC4]=true,[0x0CC5]=true,
  [0x0CC6]=true,[0x0CC7]=true,[0x0CC8]=true,[0x0CC9]=true,
  [0x0CCA]=true,[0x0CCB]=true,[0x0CCC]=true,
  [0x0D3E]=true,[0x0D3F]=true,[0x0D40]=true,[0x0D41]=true,
  [0x0D42]=true,[0x0D43]=true,[0x0D44]=true,[0x0D46]=true,
  [0x0D47]=true,[0x0D48]=true,[0x0D4A]=true,[0x0D4B]=true,
  [0x0D4C]=true,[0x0D57]=true,
}
local vowel_modifier={
  [0x0900]=true,[0x0901]=true,[0x0902]=true,[0x0903]=true,
  [0xA8E0]=true,[0xA8E1]=true,[0xA8E2]=true,[0xA8E3]=true,
  [0xA8E4]=true,[0xA8E5]=true,[0xA8E6]=true,[0xA8E7]=true,
  [0xA8E8]=true,[0xA8E9]=true,[0xA8EA]=true,[0xA8EB]=true,
  [0xA8EC]=true,[0xA8ED]=true,[0xA8EE]=true,[0xA8EF]=true,
  [0xA8F0]=true,[0xA8F1]=true,
  [0x0D02]=true,[0x0D03]=true,
}
local stress_tone_mark={
  [0x0951]=true,[0x0952]=true,[0x0953]=true,[0x0954]=true,
  [0x0CCD]=true,
  [0x0D4D]=true,
}
local nukta={
  [0x093C]=true,
  [0x0CBC]=true,
}
local halant={
  [0x094D]=true,
  [0x0CCD]=true,
  [0x0D4D]=true,
}
local ra={
  [0x0930]=true,
  [0x0CB0]=true,
  [0x0D30]=true,
}
local c_anudatta=0x0952 
local c_nbsp=0x00A0 
local c_zwnj=0x200C 
local c_zwj=0x200D 
local zw_char={ 
  [0x200C]=true,
  [0x200D]=true,
}
local pre_mark={
  [0x093F]=true,[0x094E]=true,
  [0x0D46]=true,[0x0D47]=true,[0x0D48]=true,
}
local above_mark={
  [0x0900]=true,[0x0901]=true,[0x0902]=true,[0x093A]=true,
  [0x0945]=true,[0x0946]=true,[0x0947]=true,[0x0948]=true,
  [0x0951]=true,[0x0953]=true,[0x0954]=true,[0x0955]=true,
  [0xA8E0]=true,[0xA8E1]=true,[0xA8E2]=true,[0xA8E3]=true,
  [0xA8E4]=true,[0xA8E5]=true,[0xA8E6]=true,[0xA8E7]=true,
  [0xA8E8]=true,[0xA8E9]=true,[0xA8EA]=true,[0xA8EB]=true,
  [0xA8EC]=true,[0xA8ED]=true,[0xA8EE]=true,[0xA8EF]=true,
  [0xA8F0]=true,[0xA8F1]=true,
  [0x0D4E]=true,
}
local below_mark={
  [0x093C]=true,[0x0941]=true,[0x0942]=true,[0x0943]=true,
  [0x0944]=true,[0x094D]=true,[0x0952]=true,[0x0956]=true,
  [0x0957]=true,[0x0962]=true,[0x0963]=true,
}
local post_mark={
  [0x0903]=true,[0x093B]=true,[0x093E]=true,[0x0940]=true,
  [0x0949]=true,[0x094A]=true,[0x094B]=true,[0x094C]=true,
  [0x094F]=true,
}
local twopart_mark={
  [0x0D4A]={ 0x0D46,0x0D3E,},	
  [0x0D4B]={ 0x0D47,0x0D3E,},	
  [0x0D4C]={ 0x0D46,0x0D57,},	
}
local mark_four={} 
for k,v in next,pre_mark  do mark_four[k]=pre_mark  end
for k,v in next,above_mark do mark_four[k]=above_mark end
for k,v in next,below_mark do mark_four[k]=below_mark end
for k,v in next,post_mark do mark_four[k]=post_mark end
local mark_above_below_post={}
for k,v in next,above_mark do mark_above_below_post[k]=above_mark end
for k,v in next,below_mark do mark_above_below_post[k]=below_mark end
for k,v in next,post_mark do mark_above_below_post[k]=post_mark end
local reorder_class={
  [0x0930]="before postscript",
  [0x093F]="before half",
  [0x0940]="after subscript",
  [0x0941]="after subscript",
  [0x0942]="after subscript",
  [0x0943]="after subscript",
  [0x0944]="after subscript",
  [0x0945]="after subscript",
  [0x0946]="after subscript",
  [0x0947]="after subscript",
  [0x0948]="after subscript",
  [0x0949]="after subscript",
  [0x094A]="after subscript",
  [0x094B]="after subscript",
  [0x094C]="after subscript",
  [0x0962]="after subscript",
  [0x0963]="after subscript",
  [0x093E]="after subscript",
  [0x0CB0]="after postscript",
  [0x0CBF]="before subscript",
  [0x0CC6]="before subscript",
  [0x0CCC]="before subscript",
  [0x0CBE]="before subscript",
  [0x0CE2]="before subscript",
  [0x0CE3]="before subscript",
  [0x0CC1]="before subscript",
  [0x0CC2]="before subscript",
  [0x0CC3]="after subscript",
  [0x0CC4]="after subscript",
  [0x0CD5]="after subscript",
  [0x0CD6]="after subscript",
}
local dflt_true={
  dflt=true
}
local dev2_defaults={
  dev2=dflt_true,
}
local deva_defaults={
  dev2=dflt_true,
  deva=dflt_true,
}
local false_flags={ false,false,false,false }
local both_joiners_true={
  [0x200C]=true,
  [0x200D]=true,
}
local sequence_reorder_matras={
  features={ dv01=dev2_defaults },
  flags=false_flags,
  name="dv01_reorder_matras",
  order={ "dv01" },
  type="devanagari_reorder_matras",
  nofsteps=1,
  steps={
    {
      osdstep=true,
      coverage=pre_mark,
    }
  }
}
local sequence_reorder_reph={
  features={ dv02=dev2_defaults },
  flags=false_flags,
  name="dv02_reorder_reph",
  order={ "dv02" },
  type="devanagari_reorder_reph",
  nofsteps=1,
  steps={
    {
      osdstep=true,
      coverage={},
    }
  }
}
local sequence_reorder_pre_base_reordering_consonants={
  features={ dv03=dev2_defaults },
  flags=false_flags,
  name="dv03_reorder_pre_base_reordering_consonants",
  order={ "dv03" },
  type="devanagari_reorder_pre_base_reordering_consonants",
  nofsteps=1,
  steps={
    {
      osdstep=true,
      coverage={},
    }
  }
}
local sequence_remove_joiners={
  features={ dv04=deva_defaults },
  flags=false_flags,
  name="dv04_remove_joiners",
  order={ "dv04" },
  type="devanagari_remove_joiners",
  nofsteps=1,
  steps={
    { osdstep=true,
      coverage=both_joiners_true,
    },
  }
}
local basic_shaping_forms={
  nukt=true,
  akhn=true,
  rphf=true,
  pref=true,
  rkrf=true,
  blwf=true,
  half=true,
  pstf=true,
  vatu=true,
  cjct=true,
}
local valid={
  akhn=true,
  rphf=true,
  pref=true,
  half=true,
  blwf=true,
  pstf=true,
  pres=true,
  blws=true,
  psts=true,
}
local function initializedevanagi(tfmdata)
  local script,language=otf.scriptandlanguage(tfmdata,attr) 
  if script=="deva" or script=="dev2" or script=="mlym" or script=="mlm2" then
    local resources=tfmdata.resources
    local devanagari=resources.devanagari
    if not devanagari then
      report_devanagari("adding devanagari features to font")
      local gsubfeatures=resources.features.gsub
      local sequences=resources.sequences
      local sharedfeatures=tfmdata.shared.features
      local lastmatch=0
      for s=1,#sequences do 
        local features=sequences[s].features
        if features then
          for k,v in next,features do
            if basic_shaping_forms[k] then
              lastmatch=s
            end
          end
        end
      end
      local insertindex=lastmatch+1
      gsubfeatures["dv01"]=dev2_defaults 
      gsubfeatures["dv02"]=dev2_defaults 
      gsubfeatures["dv03"]=dev2_defaults 
      gsubfeatures["dv04"]=deva_defaults
      local reorder_pre_base_reordering_consonants=copy(sequence_reorder_pre_base_reordering_consonants)
      local reorder_reph=copy(sequence_reorder_reph)
      local reorder_matras=copy(sequence_reorder_matras)
      local remove_joiners=copy(sequence_remove_joiners)
      insert(sequences,insertindex,reorder_pre_base_reordering_consonants)
      insert(sequences,insertindex,reorder_reph)
      insert(sequences,insertindex,reorder_matras)
      insert(sequences,insertindex,remove_joiners)
      local blwfcache={}
      local seqsubset={}
      local rephstep={
        coverage={} 
      }
      local devanagari={
        reph=false,
        vattu=false,
        blwfcache=blwfcache,
        seqsubset=seqsubset,
        reorderreph=rephstep,
      }
      reorder_reph.steps={ rephstep }
      local pre_base_reordering_consonants={}
      reorder_pre_base_reordering_consonants.steps[1].coverage=pre_base_reordering_consonants
      resources.devanagari=devanagari
      for s=1,#sequences do
        local sequence=sequences[s]
        local steps=sequence.steps
        local nofsteps=sequence.nofsteps
        local features=sequence.features
        if features["rphf"] then
          devanagari.reph=true
        elseif features["blwf"] then
          devanagari.vattu=true
          for i=1,nofsteps do
            local step=steps[i]
            local coverage=step.coverage
            if coverage then
              for k,v in next,coverage do
                if not blwfcache[k] then
                  blwfcache[k]=v
                end
              end
            end
          end
        end
        if valid[kind] then
          for i=1,nofsteps do
            local step=steps[i]
            local coverage=step.coverage
            if coverage then
              local reph=false
              if step.osdstep then
                for k,v in next,ra do
                  local r=coverage[k]
                  if r then
                    local h=false
                    for k,v in next,halant do
                      local h=r[k]
                      if h then
                        reph=h.ligature or false
                        break
                      end
                    end
                    if reph then
                      break
                    end
                  end
                end
              else
              end
              seqsubset[#seqsubset+1]={ kind,coverage,reph }
            end
          end
        end
        if kind=="pref" then
          local sequence=dataset[3] 
          local steps=sequence.steps
          local nofsteps=sequence.nofsteps
          for i=1,nofsteps do
            local step=steps[i]
            local coverage=step.coverage
            if coverage then
              for k,v in next,halant do
                local h=coverage[k]
                if h then
                  local found=false
                  for k,v in next,h do
                    found=v and v.ligature
                    if found then
                      pre_base_reordering_consonants[k]=found
                      break
                    end
                  end
                  if found then
                    break
                  end
                end
              end
            end
          end
        end
      end
      if script=="deva" then
        sharedfeatures["dv04"]=true 
      elseif script=="dev2" then
        sharedfeatures["dv01"]=true 
        sharedfeatures["dv02"]=true 
        sharedfeatures["dv03"]=true 
        sharedfeatures["dv04"]=true 
      elseif script=="mlym" then
        sharedfeatures["pstf"]=true
      elseif script=="mlm2" then
        sharedfeatures["pstf"]=true
        sharedfeatures["pref"]=true
        sharedfeatures["dv03"]=true 
        gsubfeatures ["dv03"]=dev2_defaults 
        insert(sequences,insertindex,sequence_reorder_pre_base_reordering_consonants)
      end
    end
  end
end
registerotffeature {
  name="devanagari",
  description="inject additional features",
  default=true,
  initializers={
    node=initializedevanagi,
  },
}
local function deva_initialize(font,attr) 
  local tfmdata=fontdata[font]
  local datasets=otf.dataset(tfmdata,font,attr) 
  local devanagaridata=datasets.devanagari
  if not devanagaridata then
    devanagaridata={
      reph=false,
      vattu=false,
      blwfcache={},
    }
    datasets.devanagari=devanagaridata
    local resources=tfmdata.resources
    local devanagari=resources.devanagari
    for s=1,#datasets do
      local dataset=datasets[s]
      if dataset and dataset[1] then 
        local kind=dataset[4]
        if kind=="rphf" then
          devanagaridata.reph=true
        elseif kind=="blwf" then
          devanagaridata.vattu=true
          devanagaridata.blwfcache=devanagari.blwfcache
        end
      end
    end
  end
  return devanagaridata.reph,devanagaridata.vattu,devanagaridata.blwfcache
end
local function deva_reorder(head,start,stop,font,attr,nbspaces)
  local reph,vattu,blwfcache=deva_initialize(font,attr) 
  local current=start
  local n=getnext(start)
  local base=nil
  local firstcons=nil
  local lastcons=nil
  local basefound=false
  if reph and ra[getchar(start)] and halant[getchar(n)] then
    if n==stop then
      return head,stop,nbspaces
    end
    if getchar(getnext(n))==c_zwj then
      current=start
    else
      current=getnext(n)
      setprop(start,a_state,s_rphf)
    end
  end
  if getchar(current)==c_nbsp then
    if current==stop then
      stop=getprev(stop)
      head=remove_node(head,current)
      flush_node(current)
      return head,stop,nbspaces
    else
      nbspaces=nbspaces+1
      base=current
      firstcons=current
      lastcons=current
      current=getnext(current)
      if current~=stop then
        if nukta[getchar(current)] then
          current=getnext(current)
        end
        if getchar(current)==c_zwj then
          if current~=stop then
            local next=getnext(current)
            if next~=stop and halant[getchar(next)] then
              current=next
              next=getnext(current)
              local tmp=next and getnext(next) or nil 
              local changestop=next==stop
              local tempcurrent=copy_node(next)
							copyinjection(tempcurrent,next)
              local nextcurrent=copy_node(current)
							copyinjection(nextcurrent,current) 
              setlink(tempcurrent,nextcurrent)
              setprop(tempcurrent,a_state,s_blwf)
              tempcurrent=processcharacters(tempcurrent,font)
              setprop(tempcurrent,a_state,unsetvalue)
              if getchar(next)==getchar(tempcurrent) then
                flush_list(tempcurrent)
                local n=copy_node(current)
								copyinjection(n,current) 
                setchar(current,dotted_circle)
                head=insert_node_after(head,current,n)
              else
                setchar(current,getchar(tempcurrent)) 
                local freenode=getnext(current)
                setlink(current,tmp)
                flush_node(freenode)
                flush_list(tempcurrent)
                if changestop then
                  stop=current
                end
              end
            end
          end
        end
      end
    end
  end
  while not basefound do
    local char=getchar(current)
    if consonant[char] then
      setprop(current,a_state,s_half)
      if not firstcons then
        firstcons=current
      end
      lastcons=current
      if not base then
        base=current
      elseif blwfcache[char] then
        setprop(current,a_state,s_blwf)
      else
        base=current
      end
    end
    basefound=current==stop
    current=getnext(current)
  end
  if base~=lastcons then
    local np=base
    local n=getnext(base)
    local ch=getchar(n)
    if nukta[ch] then
      np=n
      n=getnext(n)
      ch=getchar(n)
    end
    if halant[ch] then
      if lastcons~=stop then
        local ln=getnext(lastcons)
        if nukta[getchar(ln)] then
          lastcons=ln
        end
      end
      local nn=getnext(n)
      local ln=getnext(lastcons) 
      setlink(np,nn)
      setnext(lastcons,n)
      if ln then
        setprev(ln,n)
      end
      setnext(n,ln)
      setprev(n,lastcons)
      if lastcons==stop then
        stop=n
      end
    end
  end
  n=getnext(start)
  if n~=stop and ra[getchar(start)] and halant[getchar(n)] and not zw_char[getchar(getnext(n))] then
    local matra=base
    if base~=stop then
      local next=getnext(base)
      if dependent_vowel[getchar(next)] then
        matra=next
      end
    end
    local sp=getprev(start)
    local nn=getnext(n)
    local mn=getnext(matra)
    setlink(sp,nn)
    setlink(matra,start)
    setlink(n,mn)
    if head==start then
      head=nn
    end
    start=nn
    if matra==stop then
      stop=n
    end
  end
  local current=start
  while current~=stop do
    local next=getnext(current)
    if next~=stop and halant[getchar(next)] and getchar(getnext(next))==c_zwnj then
      setprop(current,a_state,unsetvalue)
    end
    current=next
  end
  if base~=stop and getprop(base,a_state) then
    local next=getnext(base)
    if halant[getchar(next)] and not (next~=stop and getchar(getnext(next))==c_zwj) then
      setprop(base,a_state,unsetvalue)
    end
  end
  local current,allreordered,moved=start,false,{ [base]=true }
  local a,b,p,bn=base,base,base,getnext(base)
  if base~=stop and nukta[getchar(bn)] then
    a,b,p=bn,bn,bn
  end
  while not allreordered do
    local c=current
    local n=getnext(current)
    local l=nil 
    if c~=stop then
      local ch=getchar(n)
      if nukta[ch] then
        c=n
        n=getnext(n)
        ch=getchar(n)
      end
      if c~=stop then
        if halant[ch] then
          c=n
          n=getnext(n)
          ch=getchar(n)
        end
        while c~=stop and dependent_vowel[ch] do
          c=n
          n=getnext(n)
          ch=getchar(n)
        end
        if c~=stop then
          if vowel_modifier[ch] then
            c=n
            n=getnext(n)
            ch=getchar(n)
          end
          if c~=stop and stress_tone_mark[ch] then
            c=n
            n=getnext(n)
          end
        end
      end
    end
    local bp=getprev(firstcons)
    local cn=getnext(current)
    local last=getnext(c)
    while cn~=last do
      if pre_mark[getchar(cn)] then
        if bp then
          setnext(bp,cn)
        end
        local prev,next=getboth(cn)
        if next then
          setprev(next,prev)
        end
        setnext(prev,next)
        if cn==stop then
          stop=prev
        end
        setprev(cn,bp)
        setlink(cn,firstcons)
        if firstcons==start then
          if head==start then
            head=cn
          end
          start=cn
        end
        break
      end
      cn=getnext(cn)
    end
    allreordered=c==stop
    current=getnext(c)
  end
  if reph or vattu then
    local current,cns=start,nil
    while current~=stop do
      local c=current
      local n=getnext(current)
      if ra[getchar(current)] and halant[getchar(n)] then
        c=n
        n=getnext(n)
        local b,bn=base,base
        while bn~=stop do
          local next=getnext(bn)
          if dependent_vowel[getchar(next)] then
            b=next
          end
          bn=next
        end
        if getprop(current,a_state)==s_rphf then
          if b~=current then
            if current==start then
              if head==start then
                head=n
              end
              start=n
            end
            if b==stop then
              stop=c
            end
            local prev=getprev(current)
            setlink(prev,n)
            local next=getnext(b)
            setlink(c,next)
            setlink(b,current)
          end
        elseif cns and getnext(cns)~=current then
          local cp=getprev(current)
          local cnsn=getnext(cns)
          setlink(cp,n)
          setlink(cns,current)
          setlink(c,cnsn)
          if c==stop then
            stop=cp
            break
          end
          current=getprev(n)
        end
      else
        local char=getchar(current)
        if consonant[char] then
          cns=current
          local next=getnext(cns)
          if halant[getchar(next)] then
            cns=next
          end
        elseif char==c_nbsp then
          nbspaces=nbspaces+1
          cns=current
          local next=getnext(cns)
          if halant[getchar(next)] then
            cns=next
          end
        end
      end
      current=getnext(current)
    end
  end
  if getchar(base)==c_nbsp then
    nbspaces=nbspaces-1
    head=remove_node(head,base)
    flush_node(base)
  end
  return head,stop,nbspaces
end
function handlers.devanagari_reorder_matras(head,start) 
  local current=start 
  local startfont=getfont(start)
  local startattr=getprop(start,a_syllabe)
  while current do
    local char=ischar(current,startfont)
    local next=getnext(current)
    if char and getprop(current,a_syllabe)==startattr then
      if halant[char] and not getprop(current,a_state) then
        if next then
          local char=ischar(next,startfont)
          if char and zw_char[char] and getprop(next,a_syllabe)==startattr then
            current=next
            next=getnext(current)
          end
        end
        local startnext=getnext(start)
        head=remove_node(head,start)
        setlink(start,next)
        setlink(current,start)
        start=startnext
        break
      end
    end
    current=next
  end
  return head,start,true
end
function handlers.devanagari_reorder_reph(head,start)
  local current=getnext(start)
  local startnext=nil
  local startprev=nil
  local startfont=getfont(start)
  local startattr=getprop(start,a_syllabe)
  while current do
    local char=ischar(current,font)
    if char and getprop(current,a_syllabe)==startattr then 
      if halant[char] and not getprop(current,a_state) then
        local next=getnext(current)
        if next then
          local nextchar=ischar(next,font)
          if nextchar and zw_char[nextchar] and getprop(next,a_syllabe)==startattr then
            current=next
            next=getnext(current)
          end
        end
        startnext=getnext(start)
        head=remove_node(head,start)
        setlink(start,next)
        setlink(current,start)
        start=startnext
        startattr=getprop(start,a_syllabe)
        break
      end
      current=getnext(current)
    else
      break
    end
  end
  if not startnext then
    current=getnext(start)
    while current do
      local char=ischar(current,font)
      if char and getprop(current,a_syllabe)==startattr then 
        if getprop(current,a_state)==s_pstf then 
          startnext=getnext(start)
          head=remove_node(head,start)
          local prev=getprev(current)
          setlink(prev,start)
          setlink(start,current)
          start=startnext
          startattr=getprop(start,a_syllabe)
          break
        end
        current=getnext(current)
      else
        break
      end
    end
  end
  if not startnext then
    current=getnext(start)
    local c=nil
    while current do
      local char=ischar(current,font)
      if char and getprop(current,a_syllabe)==startattr then 
        if not c and mark_above_below_post[char] and reorder_class[char]~="after subscript" then
          c=current
        end
        current=getnext(current)
      else
        break
      end
    end
    if c then
      startnext=getnext(start)
      head=remove_node(head,start)
      local prev=getprev(c)
      setlink(prev,start)
      setlink(start,c)
      start=startnext
      startattr=getprop(start,a_syllabe)
    end
  end
  if not startnext then
    current=start
    local next=getnext(current)
    while next do
      local nextchar=ischar(next,font)
      if nextchar and getprop(next,a_syllabe)==startattr then 
        current=next
        next=getnext(current)
      else
        break
      end
    end
    if start~=current then
      startnext=getnext(start)
      head=remove_node(head,start)
      local next=getnext(current)
      setlink(start,next)
      setlink(current,"next",start)
      start=startnext
    end
  end
  return head,start,true
end
function handlers.devanagari_reorder_pre_base_reordering_consonants(head,start)
  local current=start
  local startnext=nil
  local startprev=nil
  local startfont=getfont(start)
  local startattr=getprop(start,a_syllabe)
  while current do
    local char=ischar(current,font)
    if char and getprop(current,a_syllabe)==startattr then
      local next=getnext(current)
      if halant[char] and not getprop(current,a_state) then
        if next then
          local nextchar=ischar(next,font)
          if nextchar and getprop(next,a_syllabe)==startattr then
            if nextchar==c_zwnj or nextchar==c_zwj then
              current=next
              next=getnext(current)
            end
          end
        end
        startnext=getnext(start)
        removenode(start,start)
        setlink(start,next)
        setlink(current,start)
        start=startnext
        break
      end
      current=next
    else
      break
    end
  end
  if not startnext then
    current=getnext(start)
    startattr=getprop(start,a_syllabe)
    while current do
      local char=ischar(current,font)
      if char and getprop(current,a_syllabe)==startattr then
        if not consonant[char] and getprop(current,a_state) then 
          startnext=getnext(start)
          removenode(start,start)
          local prev=getprev(current)
          setlink(start,prev)
          setlink(start,current)
          start=startnext
          break
        end
        current=getnext(current)
      else
        break
      end
    end
  end
  return head,start,true
end
function handlers.devanagari_remove_joiners(head,start,kind,lookupname,replacement)
  local stop=getnext(start)
  local font=getfont(start)
  local last=start
  while stop do
    local char=ischar(stop,font)
    if char and (char==c_zwnj or char==c_zwj) then
      last=stop
      stop=getnext(stop)
    else
      break
    end
  end
  local prev=getprev(start)
  if stop then
    setnext(last)
    setlink(prev,stop)
  elseif prev then
    setnext(prev)
  end
  if head==start then
  	head=stop
  end
  flush_list(start)
  return head,stop,true
end
local function dev2_initialize(font,attr)
  local devanagari=fontdata[font].resources.devanagari
  if devanagari then
    return devanagari.seqsubset or {},devanagari.reorderreph or {}
  else
    return {},{}
  end
end
local function dev2_reorder(head,start,stop,font,attr,nbspaces) 
  local seqsubset,reorderreph=dev2_initialize(font,attr)
  local reph=false 
  local halfpos=nil
  local basepos=nil
  local subpos=nil
  local postpos=nil
  local locl={}
  for i=1,#seqsubset do
    local subset=seqsubset[i]
    local kind=subset[1]
    local lookupcache=subset[2]
    if kind=="rphf" then
      for k,v in next,ra do
        local r=lookupcache[k]
        if r then
          for k,v in next,halant do
            local h=r[k]
            if h then
              reph=h.ligature or false
              break
            end
          end
          if reph then
            break
          end
        end
      end
      local current=start
      local last=getnext(stop)
      while current~=last do
        if current~=stop then
          local c=locl[current] or getchar(current)
          local found=lookupcache[c]
          if found then
            local next=getnext(current)
            local n=locl[next] or getchar(next)
            if found[n] then  
              local afternext=next~=stop and getnext(next)
              if afternext and zw_char[getchar(afternext)] then 
                current=next
                current=getnext(current)
              elseif current==start then
                setprop(current,a_state,s_rphf)
                current=next
              else
                current=next
              end
            end
          end
        end
        current=getnext(current)
      end
    elseif kind=="pref" then
      local current=start
      local last=getnext(stop)
      while current~=last do
        if current~=stop then
          local c=locl[current] or getchar(current)
          local found=lookupcache[c]
          if found then
            local next=getnext(current)
            local n=locl[next] or getchar(next)
            if found[n] then
              setprop(current,a_state,s_pref)
              setprop(next,a_state,s_pref)
              current=next
            end
          end
        end
        current=getnext(current)
      end
    elseif kind=="half" then 
      local current=start
      local last=getnext(stop)
      while current~=last do
        if current~=stop then
          local c=locl[current] or getchar(current)
          local found=lookupcache[c]
          if found then
            local next=getnext(current)
            local n=locl[next] or getchar(next)
            if found[n] then
              if next~=stop and getchar(getnext(next))==c_zwnj then  
                current=next
              else
                setprop(current,a_state,s_half)
                if not halfpos then
                  halfpos=current
                end
              end
              current=getnext(current)
            end
          end
        end
        current=getnext(current)
      end
    elseif kind=="blwf" then 
      local current=start
      local last=getnext(stop)
      while current~=last do
        if current~=stop then
          local c=locl[current] or getchar(current)
          local found=lookupcache[c]
          if found then
            local next=getnext(current)
            local n=locl[next] or getchar(next)
            if found[n] then
              setprop(current,a_state,s_blwf)
              setprop(next,a_state,s_blwf)
              current=next
              subpos=current
            end
          end
        end
        current=getnext(current)
      end
    elseif kind=="pstf" then 
      local current=start
      local last=getnext(stop)
      while current~=last do
        if current~=stop then
          local c=locl[current] or getchar(current)
          local found=lookupcache[c]
          if found then
            local next=getnext(current)
            local n=locl[next] or getchar(next)
            if found[n] then
              setprop(current,a_state,s_pstf)
              setprop(next,a_state,s_pstf)
              current=next
              postpos=current
            end
          end
        end
        current=getnext(current)
      end
    end
  end
  reorderreph.coverage={ [reph]=true }
  local current,base,firstcons=start,nil,nil
  if getprop(start,a_state)==s_rphf then
    current=getnext(getnext(start))
  end
  if current~=getnext(stop) and getchar(current)==c_nbsp then
    if current==stop then
      stop=getprev(stop)
      head=remove_node(head,current)
      flush_node(current)
      return head,stop,nbspaces
    else
      nbspaces=nbspaces+1
      base=current
      current=getnext(current)
      if current~=stop then
        local char=getchar(current)
        if nukta[char] then
          current=getnext(current)
          char=getchar(current)
        end
        if char==c_zwj then
          local next=getnext(current)
          if current~=stop and next~=stop and halant[getchar(next)] then
            current=next
            next=getnext(current)
            local tmp=getnext(next)
            local changestop=next==stop
            setnext(next,nil)
            setprop(current,a_state,s_pref)
            current=processcharacters(current,font)
            setprop(current,a_state,s_blwf)
            current=processcharacters(current,font)
            setprop(current,a_state,s_pstf)
            current=processcharacters(current,font)
            setprop(current,a_state,unsetvalue)
            if halant[getchar(current)] then
              setnext(getnext(current),tmp)
              local nc=copy_node(current)
							copyinjection(nc,current)
              setchar(current,dotted_circle)
              head=insert_node_after(head,current,nc)
            else
              setnext(current,tmp) 
              if changestop then
                stop=current
              end
            end
          end
        end
      end
    end
  else 
    local last=getnext(stop)
    while current~=last do  
      local next=getnext(current)
      if consonant[getchar(current)] then
        if not (current~=stop and next~=stop and halant[getchar(next)] and getchar(getnext(next))==c_zwj) then
          if not firstcons then
            firstcons=current
          end
          local a=getprop(current,a_state)
          if not (a==s_pref or a==s_blwf or a==s_pstf) then
            base=current
          end
        end
      end
      current=next
    end
    if not base then
      base=firstcons
    end
  end
  if not base then
    if getprop(start,a_state)==s_rphf then
      setprop(start,a_state,unsetvalue)
    end
    return head,stop,nbspaces
  else
    if getprop(base,a_state) then
      setprop(base,a_state,unsetvalue)
    end
    basepos=base
  end
  if not halfpos then
    halfpos=base
  end
  if not subpos then
    subpos=base
  end
  if not postpos then
    postpos=subpos or base
  end
  local moved={}
  local current=start
  local last=getnext(stop)
  while current~=last do
    local char,target,cn=locl[current] or getchar(current),nil,getnext(current)
    local tpm=twopart_mark[char]
    if tpm then
      local extra=copy_node(current)
      copyinjection(extra,current)
      char=tpm[1]
      setchar(current,char)
      setchar(extra,tpm[2])
      head=insert_node_after(head,current,extra)
    end
    if not moved[current] and dependent_vowel[char] then
      if pre_mark[char] then      
        moved[current]=true
        local prev,next=getboth(current)
        setlink(prev,next)
        if current==stop then
          stop=getprev(current)
        end
        if halfpos==start then
          if head==start then
            head=current
          end
          start=current
        end
        local prev=getprev(halfpos)
        setlink(prev,current)
        setlink(current,halfpos)
        halfpos=current
      elseif above_mark[char] then  
        target=basepos
        if subpos==basepos then
          subpos=current
        end
        if postpos==basepos then
          postpos=current
        end
        basepos=current
      elseif below_mark[char] then  
        target=subpos
        if postpos==subpos then
          postpos=current
        end
        subpos=current
      elseif post_mark[char] then  
        target=postpos
        postpos=current
      end
      if mark_above_below_post[char] then
        local prev=getprev(current)
        if prev~=target then
          local next=getnext(current)
          setlink(next,prev)
          if current==stop then
            stop=prev
          end
          local next=getnext(target)
          setlink(current,next)
          setlink(target,current)
        end
      end
    end
    current=cn
  end
  local current,c=start,nil
  while current~=stop do
    local char=getchar(current)
    if halant[char] or stress_tone_mark[char] then
      if not c then
        c=current
      end
    else
      c=nil
    end
    local next=getnext(current)
    if c and nukta[getchar(next)] then
      if head==c then
        head=next
      end
      if stop==next then
        stop=current
      end
      local prev=getprev(c)
      setlink(next,prev)
      local nextnext=getnext(next)
      setnext(current,nextnext)
      local nextnextnext=getnext(nextnext)
      if nextnextnext then
        setprev(nextnextnext,current)
      end
      setlink(nextnext,c)
    end
    if stop==current then break end
    current=getnext(current)
  end
  if getchar(base)==c_nbsp then
    nbspaces=nbspaces-1
    head=remove_node(head,base)
    flush_node(base)
  end
  return head,stop,nbspaces
end
local separator={}
imerge(separator,consonant)
imerge(separator,independent_vowel)
imerge(separator,dependent_vowel)
imerge(separator,vowel_modifier)
imerge(separator,stress_tone_mark)
for k,v in next,nukta do separator[k]=true end
for k,v in next,halant do separator[k]=true end
local function analyze_next_chars_one(c,font,variant)
  local n=getnext(c)
  if not n then
    return c
  end
  if variant==1 then
    local v=ischar(n,font)
    if v and nukta[v] then
      n=getnext(n)
      if n then
        v=ischar(n,font)
      end
    end
    if n and v then
      local nn=getnext(n)
      if nn then
        local vv=ischar(nn,font)
        if vv then
          local nnn=getnext(nn)
          if nnn then
            local vvv=ischar(nnn,font)
            if vvv then
              if vv==c_zwj and consonant[vvv] then
                c=nnn
              elseif (vv==c_zwnj or vv==c_zwj) and halant[vvv] then
                local nnnn=getnext(nnn)
                if nnnn then
                  local vvvv=ischar(nnnn)
                  if vvvv and consonant[vvvv] then
                    c=nnnn
                  end
                end
              end
            end
          end
        end
      end
    end
  elseif variant==2 then
    local v=ischar(n,font)
    if v and nukta[v] then
      c=n
    end
    n=getnext(c)
    if n then
      v=ischar(n,font)
      if v then
        local nn=getnext(n)
        if nn then
          local vv=ischar(nn,font)
          if vv and zw_char[vv] then
            n=nn
            v=vv
            nn=getnext(nn)
            vv=nn and ischar(nn,font)
          end
          if vv and halant[v] and consonant[vv] then
            c=nn
          end
        end
      end
    end
  end
  local n=getnext(c)
  if not n then
    return c
  end
  local v=ischar(n,font)
  if not v then
    return c
  end
  if dependent_vowel[v] then
    c=getnext(c)
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if nukta[v] then
    c=getnext(c)
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if halant[v] then
    c=getnext(c)
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if vowel_modifier[v] then
    c=getnext(c)
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if stress_tone_mark[v] then
    c=getnext(c)
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if stress_tone_mark[v] then
    return n
  else
    return c
  end
end
local function analyze_next_chars_two(c,font)
  local n=getnext(c)
  if not n then
    return c
  end
  local v=ischar(n,font)
  if v and nukta[v] then
    c=n
  end
  n=c
  while true do
    local nn=getnext(n)
    if nn then
      local vv=ischar(nn,font)
      if vv then
        if halant[vv] then
          n=nn
          local nnn=getnext(nn)
          if nnn then
            local vvv=ischar(nnn,font)
            if vvv and zw_char[vvv] then
              n=nnn
            end
          end
        elseif vv==c_zwnj or vv==c_zwj then
          local nnn=getnext(nn)
          if nnn then
            local vvv=ischar(nnn,font)
            if vvv and halant[vvv] then
              n=nnn
            end
          end
        else
          break
        end
        local nn=getnext(n)
        if nn then
          local vv=ischar(nn,font)
          if vv and consonant[vv] then
            n=nn
            local nnn=getnext(nn)
            if nnn then
              local vvv=ischar(nnn,font)
              if vvv and nukta[vvv] then
                n=nnn
              end
            end
            c=n
          else
            break
          end
        else
          break
        end
      else
        break
      end
    else
      break
    end
  end
  if not c then
    return
  end
  local n=getnext(c)
  if not n then
    return c
  end
  local v=ischar(n,font)
  if not v then
    return c
  end
  if v==c_anudatta then
    c=n
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if halant[v] then
    c=n
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
    if v==c_zwnj or v==c_zwj then
      c=n
      n=getnext(c)
      if not n then
        return c
      end
      v=ischar(n,font)
      if not v then
        return c
      end
    end
  else
    if dependent_vowel[v] then
      c=n
      n=getnext(c)
      if not n then
        return c
      end
      v=ischar(n,font)
      if not v then
        return c
      end
    end
    if nukta[v] then
      c=n
      n=getnext(c)
      if not n then
        return c
      end
      v=ischar(n,font)
      if not v then
        return c
      end
    end
    if halant[v] then
      c=n
      n=getnext(c)
      if not n then
        return c
      end
      v=ischar(n,font)
      if not v then
        return c
      end
    end
  end
  if vowel_modifier[v] then
    c=n
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if stress_tone_mark[v] then
    c=n
    n=getnext(c)
    if not n then
      return c
    end
    v=ischar(n,font)
    if not v then
      return c
    end
  end
  if stress_tone_mark[v] then
    return n
  else
    return c
  end
end
local function inject_syntax_error(head,current,mark)
  local signal=copy_node(current)
	copyinjection(signal,current)
  if mark==pre_mark then 
    setchar(signal,dotted_circle)
  else
    setchar(current,dotted_circle)
  end
  return insert_node_after(head,current,signal)
end
function methods.deva(head,font,attr)
  head=tonut(head)
  local current=head
  local start=true
  local done=false
  local nbspaces=0
  while current do
		local char=ischar(current,font)
    if char then
      done=true
      local syllablestart=current
      local syllableend=nil
      local c=current
      local n=getnext(c)
	    local first=char
      if n and ra[first] then
        local second=ischar(n,font)
        if second and halant[second] then
          local n=getnext(n)
          if n then
            local third=ischar(n,font)
            if third then
              c=n
              first=third
            end
          end
        end
      end
      local standalone=first==c_nbsp
      if standalone then
        local prev=getprev(current)
        if prev then
          local prevchar=ischar(prev,font)
          if not prevchar then
          elseif not separator[prevchar] then
          else
            standalone=false
          end
        else
        end
      end
      if standalone then
				local syllableend=analyze_next_chars_one(c,font,2)
				current=getnext(syllableend)
        if syllablestart~=syllableend then
          head,current,nbspaces=deva_reorder(head,syllablestart,syllableend,font,attr,nbspaces)
          current=getnext(current)
        end
      else
        if consonant[char] then
          local prevc=true
          while prevc do
            prevc=false
            local n=getnext(current)
            if not n then
              break
            end
            local v=ischar(n,font)
            if not v then
              break
            end
            if nukta[v] then
              n=getnext(n)
              if not n then
                break
              end
              v=ischar(n,font)
              if not v then
                break
              end
            end
            if halant[v] then
              n=getnext(n)
              if not n then
                break
              end
              v=ischar(n,font)
              if not v then
                break
              end
              if v==c_zwnj or v==c_zwj then
                n=getnext(n)
                if not n then
                  break
                end
                v=ischar(n,font)
                if not v then
                  break
                end
              end
              if consonant[v] then
                prevc=true
                current=n
              end
            end
          end
          local n=getnext(current)
          if n then
            local v=ischar(n,font)
            if v and nukta[v] then
              current=n
              n=getnext(current)
            end
          end
          syllableend=current
          current=n
          if current then
            local v=ischar(current,font)
            if not v then
            elseif halant[v] then
              local n=getnext(current)
              if n then
                local v=ischar(n,font)
                if v and zw_char[v] then
                  syllableend=n
                  current=getnext(n)
                else
                  syllableend=current
                  current=n
                end
              else
                syllableend=current
                current=n
              end
            else
              if dependent_vowel[v] then
                syllableend=current
                current=getnext(current)
                v=ischar(current,font)
              end
              if v and vowel_modifier[v] then
                syllableend=current
                current=getnext(current)
                v=ischar(current,font)
              end
              if v and stress_tone_mark[v] then
                syllableend=current
                current=getnext(current)
              end
            end
          end
          if syllablestart~=syllableend then
            head,current,nbspaces=deva_reorder(head,syllablestart,syllableend,font,attr,nbspaces)
            current=getnext(current)
          end
        elseif independent_vowel[char] then
          syllableend=current
          current=getnext(current)
          if current then
            local v=ischar(current,font)
            if v then
              if vowel_modifier[v] then
                syllableend=current
                current=getnext(current)
                v=ischar(current,font)
              end
              if v and stress_tone_mark[v] then
                syllableend=current
                current=getnext(current)
              end
            end
          end
        else
          local mark=mark_four[char]
          if mark then
            head,current=inject_syntax_error(head,current,mark)
          end
          current=getnext(current)
        end
      end
    else
      current=getnext(current)
    end
    start=false
  end
  if nbspaces>0 then
    head=replace_all_nbsp(head)
  end
  head=tonode(head)
  return head,done
end
function methods.dev2(head,font,attr)
  head=tonut(head)
  local current=head
  local start=true
  local done=false
  local syllabe=0
  local nbspaces=0
  while current do
    local syllablestart=nil
    local syllableend=nil
    local char=ischar(current,font)
    if char then
      done=true
      syllablestart=current
      local c=current
      local n=getnext(current)
      if n and ra[char] then
        local nextchar=ischar(n,font)
        if nextchar and halant[nextchar] then
          local n=getnext(n)
          if n then
            local nextnextchar=ischar(n,font)
            if nextnextchar then
              c=n
							char=nextnextchar
            end
          end
        end
      end
      if independent_vowel[char] then
        current=analyze_next_chars_one(c,font,1)
        syllableend=current
      else
        local standalone=char==c_nbsp
        if standalone then
          nbspaces=nbspaces+1
          local p=getprev(current)
          if not p then
          elseif ischar(p,font) then
          elseif not separator[getchar(p)] then
          else
            standalone=false
          end
        end
        if standalone then
          current=analyze_next_chars_one(c,font,2)
          syllableend=current
        elseif consonant[getchar(current)] then
          current=analyze_next_chars_two(current,font) 
          syllableend=current
        end
      end
    end
    if syllableend then
      syllabe=syllabe+1
      local c=syllablestart
      local n=getnext(syllableend)
      while c~=n do
        setprop(c,a_syllabe,syllabe)
        c=getnext(c)
      end
    end
    if syllableend and syllablestart~=syllableend then
      head,current,nbspaces=dev2_reorder(head,syllablestart,syllableend,font,attr,nbspaces)
    end
    if not syllableend then
      local char=ischar(current,font)
      if char and not getprop(current,a_state) then
        local mark=mark_four[char]
        if mark then
          head,current=inject_syntax_error(head,current,mark)
        end
      end
    end
    start=false
    current=getnext(current)
  end
  if nbspaces>0 then
    head=replace_all_nbsp(head)
  end
  head=tonode(head)
  return head,done
end
methods.mlym=methods.deva
methods.mlm2=methods.dev2

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-ocl']={
  version=1.001,
  comment="companion to font-otf.lua (context)",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local tostring,next,format=tostring,next,string.format
local formatters=string.formatters
local otf=fonts.handlers.otf
local f_color_start=formatters["pdf:direct: %f %f %f rg"]
local s_color_stop="pdf:direct:"
if context then
  local startactualtext=nil
  local stopactualtext=nil
  function otf.getactualtext(n)
    if not startactualtext then
      startactualtext=backends.codeinjections.startunicodetoactualtext
      stopactualtext=backends.codeinjections.stopunicodetoactualtext
    end
    return startactualtext(n),stopactualtext()
  end
else
  local tounicode=fonts.mappings.tounicode16
  function otf.getactualtext(n)
    return "/Span << /ActualText <feff"..tounicode(n).."> >> BDC","EMC"
  end
end
local function initializecolr(tfmdata,kind,value) 
  if value then
    local palettes=tfmdata.resources.colorpalettes
    if palettes then
      local palette=palettes[tonumber(value) or 1] or palettes[1] or {}
      local classes=#palette
      if classes==0 then
        return
      end
      local characters=tfmdata.characters
      local descriptions=tfmdata.descriptions
      local properties=tfmdata.properties
      local colorvalues={}
      properties.virtualized=true
      tfmdata.fonts={
        { id=0 }
      }
      for i=1,classes do
        local p=palette[i]
        colorvalues[i]={ "special",f_color_start(p[1]/255,p[2]/255,p[3]/255) }
      end
      local getactualtext=otf.getactualtext
      for unicode,character in next,characters do
        local description=descriptions[unicode]
        if description then
          local colorlist=description.colors
          if colorlist then
            local b,e=getactualtext(unicode)
            local w=character.width or 0
            local s=#colorlist
            local n=1
            local t={
              { "special","pdf:direct: q "..b }
            }
            for i=1,s do
              local entry=colorlist[i]
              n=n+1 t[n]=colorvalues[entry.class]
              n=n+1 t[n]={ "char",entry.slot }
              if s>1 and i<s and w~=0 then
                n=n+1 t[n]={ "right",-w }
              end
            end
            n=n+1 t[n]={ "special","pdf:direct:"..e.." Q" }
            character.commands=t
          end
        end
      end
    end
  end
end
fonts.handlers.otf.features.register {
  name="colr",
  description="color glyphs",
  manipulators={
    base=initializecolr,
    node=initializecolr,
  }
}
local otfsvg=otf.svg or {}
otf.svg=otfsvg
otf.svgenabled=true
do
  local nofstreams=0
  local f_name=formatters[ [[svg-glyph-%05i]] ]
  local f_used=context and formatters[ [[original:///%s]] ] or formatters[ [[%s]] ]
  local cache={}
  function otfsvg.storepdfdata(pdf)
    nofstreams=nofstreams+1
    local o,n=epdf.openMemStream(pdf,#pdf,f_name(nofstreams))
    cache[n]=o 
    return nil,f_used(n),nil
  end
  if context then
    local storepdfdata=otfsvg.storepdfdata
    local initialized=false
    function otfsvg.storepdfdata(pdf)
      if not initialized then
        if resolvers.setmemstream then
          local f_setstream=formatters[ [[resolvers.setmemstream("svg-glyph-%05i",%q,true)]] ]
          local f_getstream=formatters[ [[memstream:///svg-glyph-%05i]] ]
          local f_nilstream=formatters[ [[resolvers.resetmemstream("svg-glyph-%05i",true)]] ]
          storepdfdata=function(pdf)
            nofstreams=nofstreams+1
            return
              f_setstream(nofstreams,pdf),
              f_getstream(nofstreams),
              f_nilstream(nofstreams)
          end
          otfsvg.storepdfdata=storepdfdata
        end
        initialized=true
      end
      return storepdfdata(pdf)
    end
  end
end
do
  local report_svg=logs.reporter("fonts","svg conversion")
  local loaddata=io.loaddata
  local savedata=io.savedata
  local remove=os.remove
  if context and xml.convert then
    local xmlconvert=xml.convert
    local xmlfirst=xml.first
    function otfsvg.filterglyph(entry,index)
      local svg=xmlconvert(entry.data)
      local root=svg and xmlfirst(svg,"/svg[@id='glyph"..index.."']")
      local data=root and tostring(root)
      return data
    end
  else
    function otfsvg.filterglyph(entry,index) 
      return entry.data
    end
  end
  function otfsvg.topdf(svgshapes)
    local inkscape=io.popen("inkscape --shell > temp-otf-svg-shape.log","w")
    local pdfshapes={}
    local nofshapes=#svgshapes
    local f_svgfile=formatters["temp-otf-svg-shape-%i.svg"]
    local f_pdffile=formatters["temp-otf-svg-shape-%i.pdf"]
    local f_convert=formatters["%s --export-pdf=%s\n"]
    local filterglyph=otfsvg.filterglyph
    report_svg("processing %i svg containers",nofshapes)
    statistics.starttiming()
    for i=1,nofshapes do
      local entry=svgshapes[i]
      for index=entry.first,entry.last do
        local data=filterglyph(entry,index)
        if data and data~="" then
          local svgfile=f_svgfile(index)
          local pdffile=f_pdffile(index)
          savedata(svgfile,data)
          inkscape:write(f_convert(svgfile,pdffile))
          pdfshapes[index]=true
        end
      end
    end
    inkscape:write("quit\n")
    inkscape:close()
    report_svg("processing %i pdf results",nofshapes)
    for index in next,pdfshapes do
      local svgfile=f_svgfile(index)
      local pdffile=f_pdffile(index)
      pdfshapes[index]=loaddata(pdffile)
      remove(svgfile)
      remove(pdffile)
    end
    statistics.stoptiming()
    if statistics.elapsedseconds then
      report_svg("svg conversion time %s",statistics.elapsedseconds())
    end
    return pdfshapes
  end
end
local function initializesvg(tfmdata,kind,value) 
  if value and otf.svgenabled then
    local characters=tfmdata.characters
    local descriptions=tfmdata.descriptions
    local properties=tfmdata.properties
    local svg=properties.svg
    local hash=svg and svg.hash
    local timestamp=svg and svg.timestamp
    if not hash then
      return
    end
    local pdffile=containers.read(otf.pdfcache,hash)
    local pdfshapes=pdffile and pdffile.pdfshapes
    if not pdfshapes or pdffile.timestamp~=timestamp then
      local svgfile=containers.read(otf.svgcache,hash)
      local svgshapes=svgfile and svgfile.svgshapes
      pdfshapes=svgshapes and otfsvg.topdf(svgshapes) or {}
      containers.write(otf.pdfcache,hash,{
        pdfshapes=pdfshapes,
        timestamp=timestamp,
      })
    end
    if not pdfshapes or not next(pdfshapes) then
      return
    end
    properties.virtualized=true
    tfmdata.fonts={
      { id=0 }
    }
    local getactualtext=otf.getactualtext
    local storepdfdata=otfsvg.storepdfdata
    local nop={ "nop" }
    for unicode,character in next,characters do
      local index=character.index
      if index then
        local pdf=pdfshapes[index]
        if pdf then
          local setcode,name,nilcode=storepdfdata(pdf)
          if name then
            local bt,et=getactualtext(unicode)
            local wd=character.width or 0
            local ht=character.height or 0
            local dp=character.depth or 0
            character.commands={
              { "special","pdf:direct:"..bt },
              { "down",dp },
              setcode and { "lua",setcode } or nop,
              { "image",{ filename=name,width=wd,height=ht,depth=dp } },
              nilcode and { "lua",nilcode } or nop,
              { "special","pdf:direct:"..et },
            }
            character.svg=true
          end
        end
      end
    end
  end
end
fonts.handlers.otf.features.register {
  name="svg",
  description="svg glyphs",
  manipulators={
    base=initializesvg,
    node=initializesvg,
  }
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-onr']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local fonts,logs,trackers,resolvers=fonts,logs,trackers,resolvers
local next,type,tonumber,rawget,rawset=next,type,tonumber,rawget,rawset
local match,lower,gsub,strip,find=string.match,string.lower,string.gsub,string.strip,string.find
local char,byte,sub=string.char,string.byte,string.sub
local abs=math.abs
local bxor,rshift=bit32.bxor,bit32.rshift
local P,S,R,Cmt,C,Ct,Cs,Carg,Cf,Cg=lpeg.P,lpeg.S,lpeg.R,lpeg.Cmt,lpeg.C,lpeg.Ct,lpeg.Cs,lpeg.Carg,lpeg.Cf,lpeg.Cg
local lpegmatch,patterns=lpeg.match,lpeg.patterns
local trace_indexing=false trackers.register("afm.indexing",function(v) trace_indexing=v end)
local trace_loading=false trackers.register("afm.loading",function(v) trace_loading=v end)
local report_afm=logs.reporter("fonts","afm loading")
local report_pfb=logs.reporter("fonts","pfb loading")
local handlers=fonts.handlers
local afm=handlers.afm or {}
handlers.afm=afm
local readers=afm.readers or {}
afm.readers=readers
afm.version=1.512
local get_indexes
do
  local n,m
  local progress=function(str,position,name,size)
    local forward=position+tonumber(size)+3+2
    n=n+1
    if n>=m then
      return #str,name
    elseif forward<#str then
      return forward,name
    else
      return #str,name
    end
  end
  local initialize=function(str,position,size)
    n=0
    m=size 
    return position+1
  end
  local charstrings=P("/CharStrings")
  local encoding=P("/Encoding")
  local dup=P("dup")
  local put=P("put")
  local array=P("array")
  local name=P("/")*C((R("az")+R("AZ")+R("09")+S("-_."))^1)
  local digits=R("09")^1
  local cardinal=digits/tonumber
  local spaces=P(" ")^1
  local spacing=patterns.whitespace^0
  local p_filternames=Ct (
    (1-charstrings)^0*charstrings*spaces*Cmt(cardinal,initialize)*(Cmt(name*spaces*cardinal,progress)+P(1))^1
  )
  local p_filterencoding=(1-encoding)^0*encoding*spaces*digits*spaces*array*(1-dup)^0*Cf(
      Ct("")*Cg(spacing*dup*spaces*cardinal*spaces*name*spaces*put)^1
,rawset)
  local decrypt
  do
    local r,c1,c2,n=0,0,0,0
    local function step(c)
      local cipher=byte(c)
      local plain=bxor(cipher,rshift(r,8))
      r=((cipher+r)*c1+c2)%65536
      return char(plain)
    end
    decrypt=function(binary)
      r,c1,c2,n=55665,52845,22719,4
      binary=gsub(binary,".",step)
      return sub(binary,n+1)
    end
  end
  local function loadpfbvector(filename)
    local data=io.loaddata(resolvers.findfile(filename))
    if not data then
      report_pfb("no data in %a",filename)
      return
    end
    if not (find(data,"!PS%-AdobeFont%-") or find(data,"%%!FontType1")) then
      report_pfb("no font in %a",filename)
      return
    end
    local ascii,binary=match(data,"(.*)eexec%s+......(.*)")
    if not binary then
      report_pfb("no binary data in %a",filename)
      return
    end
    binary=decrypt(binary,4)
    local vector=lpegmatch(p_filternames,binary)
    for i=1,#vector do
      vector[i-1]=vector[i]
    end
    vector[#vector]=nil
    if not vector then
      report_pfb("no vector in %a",filename)
      return
    end
    local encoding=lpegmatch(p_filterencoding,ascii)
    return vector,encoding
  end
  local pfb=handlers.pfb or {}
  handlers.pfb=pfb
  pfb.loadvector=loadpfbvector
  get_indexes=function(data,pfbname)
    local vector=loadpfbvector(pfbname)
    if vector then
      local characters=data.characters
      if trace_loading then
        report_afm("getting index data from %a",pfbname)
      end
      for index=1,#vector do
        local name=vector[index]
        local char=characters[name]
        if char then
          if trace_indexing then
            report_afm("glyph %a has index %a",name,index)
          end
          char.index=index
        end
      end
    end
  end
end
local spacer=patterns.spacer
local whitespace=patterns.whitespace
local lineend=patterns.newline
local spacing=spacer^0
local number=spacing*S("+-")^-1*(R("09")+S("."))^1/tonumber
local name=spacing*C((1-whitespace)^1)
local words=spacing*((1-lineend)^1/strip)
local rest=(1-lineend)^0
local fontdata=Carg(1)
local semicolon=spacing*P(";")
local plus=spacing*P("plus")*number
local minus=spacing*P("minus")*number
local function addkernpair(data,one,two,value)
  local chr=data.characters[one]
  if chr then
    local kerns=chr.kerns
    if kerns then
      kerns[two]=tonumber(value)
    else
      chr.kerns={ [two]=tonumber(value) }
    end
  end
end
local p_kernpair=(fontdata*P("KPX")*name*name*number)/addkernpair
local chr=false
local ind=0
local function start(data,version)
  data.metadata.afmversion=version
  ind=0
  chr={}
end
local function stop()
  ind=0
  chr=false
end
local function setindex(i)
  if i<0 then
    ind=ind+1 
  else
    ind=i
  end
  chr={
    index=ind
  }
end
local function setwidth(width)
  chr.width=width
end
local function setname(data,name)
  data.characters[name]=chr
end
local function setboundingbox(boundingbox)
  chr.boundingbox=boundingbox
end
local function setligature(plus,becomes)
  local ligatures=chr.ligatures
  if ligatures then
    ligatures[plus]=becomes
  else
    chr.ligatures={ [plus]=becomes }
  end
end
local p_charmetric=((
  P("C")*number/setindex+P("WX")*number/setwidth+P("N")*fontdata*name/setname+P("B")*Ct((number)^4)/setboundingbox+P("L")*(name)^2/setligature
 )*semicolon )^1
local p_charmetrics=P("StartCharMetrics")*number*(p_charmetric+(1-P("EndCharMetrics")))^0*P("EndCharMetrics")
local p_kernpairs=P("StartKernPairs")*number*(p_kernpair+(1-P("EndKernPairs" )))^0*P("EndKernPairs" )
local function set_1(data,key,a)   data.metadata[lower(key)]=a      end
local function set_2(data,key,a,b)  data.metadata[lower(key)]={ a,b }  end
local function set_3(data,key,a,b,c) data.metadata[lower(key)]={ a,b,c } end
local p_parameters=P(false)+fontdata*((P("FontName")+P("FullName")+P("FamilyName"))/lower)*words/function(data,key,value)
    data.metadata[key]=value
  end+fontdata*((P("Weight")+P("Version"))/lower)*name/function(data,key,value)
    data.metadata[key]=value
  end+fontdata*P("IsFixedPitch")*name/function(data,pitch)
    data.metadata.monospaced=toboolean(pitch,true)
  end+fontdata*P("FontBBox")*Ct(number^4)/function(data,boundingbox)
    data.metadata.boundingbox=boundingbox
 end+fontdata*((P("CharWidth")+P("CapHeight")+P("XHeight")+P("Descender")+P("Ascender")+P("ItalicAngle"))/lower)*number/function(data,key,value)
    data.metadata[key]=value
  end+P("Comment")*spacing*(P(false)+(fontdata*C("DESIGNSIZE")*number*rest)/set_1 
+(fontdata*C("TFM designsize")*number*rest)/set_1+(fontdata*C("DesignSize")*number*rest)/set_1+(fontdata*C("CODINGSCHEME")*words*rest)/set_1 
+(fontdata*C("CHECKSUM")*number*words*rest)/set_1 
+(fontdata*C("SPACE")*number*plus*minus*rest)/set_3 
+(fontdata*C("QUAD")*number*rest)/set_1 
+(fontdata*C("EXTRASPACE")*number*rest)/set_1 
+(fontdata*C("NUM")*number*number*number*rest)/set_3 
+(fontdata*C("DENOM")*number*number*rest)/set_2 
+(fontdata*C("SUP")*number*number*number*rest)/set_3 
+(fontdata*C("SUB")*number*number*rest)/set_2 
+(fontdata*C("SUPDROP")*number*rest)/set_1 
+(fontdata*C("SUBDROP")*number*rest)/set_1 
+(fontdata*C("DELIM")*number*number*rest)/set_2 
+(fontdata*C("AXISHEIGHT")*number*rest)/set_1 
  )
local fullparser=(P("StartFontMetrics")*fontdata*name/start )*(p_charmetrics+p_kernpairs+p_parameters+(1-P("EndFontMetrics")) )^0*(P("EndFontMetrics")/stop )
local fullparser=(P("StartFontMetrics")*fontdata*name/start )*(p_charmetrics+p_kernpairs+p_parameters+(1-P("EndFontMetrics")) )^0*(P("EndFontMetrics")/stop )
local infoparser=(P("StartFontMetrics")*fontdata*name/start )*(p_parameters+(1-P("EndFontMetrics")) )^0*(P("EndFontMetrics")/stop )
local function read(filename,parser)
  local afmblob=io.loaddata(filename)
  if afmblob then
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
    if trace_loading then
      report_afm("parsing afm file %a",filename)
    end
    lpegmatch(parser,afmblob,1,data)
    return data
  else
    if trace_loading then
      report_afm("no valid afm file %a",filename)
    end
    return nil
  end
end
function readers.loadfont(afmname,pfbname)
  local data=read(resolvers.findfile(afmname),fullparser)
  if data then
    if not pfbname or pfbname=="" then
      pfbname=file.replacesuffix(file.nameonly(afmname),"pfb")
      pfbname=resolvers.findfile(pfbname)
    end
    if pfbname and pfbname~="" then
      data.resources.filename=resolvers.unresolve(pfbname)
      get_indexes(data,pfbname)
    elseif trace_loading then
      report_afm("no pfb file for %a",afmname)
    end
    return data
  end
end
function readers.getinfo(filename)
  local data=read(resolvers.findfile(filename),infoparser)
  if data then
    return data.metadata
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-one']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local fonts,logs,trackers,containers,resolvers=fonts,logs,trackers,containers,resolvers
local next,type,tonumber,rawget=next,type,tonumber,rawget
local match,gmatch,lower,gsub,strip,find=string.match,string.gmatch,string.lower,string.gsub,string.strip,string.find
local char,byte,sub=string.char,string.byte,string.sub
local abs=math.abs
local bxor,rshift=bit32.bxor,bit32.rshift
local P,S,R,Cmt,C,Ct,Cs,Carg=lpeg.P,lpeg.S,lpeg.R,lpeg.Cmt,lpeg.C,lpeg.Ct,lpeg.Cs,lpeg.Carg
local lpegmatch,patterns=lpeg.match,lpeg.patterns
local trace_features=false trackers.register("afm.features",function(v) trace_features=v end)
local trace_indexing=false trackers.register("afm.indexing",function(v) trace_indexing=v end)
local trace_loading=false trackers.register("afm.loading",function(v) trace_loading=v end)
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local report_afm=logs.reporter("fonts","afm loading")
local setmetatableindex=table.setmetatableindex
local derivetable=table.derive
local findbinfile=resolvers.findbinfile
local definers=fonts.definers
local readers=fonts.readers
local constructors=fonts.constructors
local afm=constructors.handlers.afm
local pfb=constructors.handlers.pfb
local otf=fonts.handlers.otf
local otfreaders=otf.readers
local otfenhancers=otf.enhancers
local afmfeatures=constructors.features.afm
local registerafmfeature=afmfeatures.register
afm.version=1.512 
afm.cache=containers.define("fonts","afm",afm.version,true)
afm.autoprefixed=true 
afm.helpdata={} 
afm.syncspace=true 
local overloads=fonts.mappings.overloads
local applyruntimefixes=fonts.treatments and fonts.treatments.applyfixes
local enhancers={
}
local steps={
  "unify names",
  "add ligatures",
  "add extra kerns",
  "normalize features",
  "check extra features",
  "fix names",
}
local function applyenhancers(data,filename)
  for i=1,#steps do
    local step=steps[i]
    local enhancer=enhancers[step]
    if enhancer then
      if trace_loading then
        report_afm("applying enhancer %a",step)
      end
      enhancer(data,filename)
    else
      report_afm("invalid enhancer %a",step)
    end
  end
end
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
      data=afm.readers.loadfont(filename,pfbname)
      if data then
        applyenhancers(data,filename)
        fonts.mappings.addtounicode(data,filename)
        otfreaders.pack(data)
        data.size=size
        data.time=time
        data.pfbsize=pfbsize
        data.pfbtime=pfbtime
        report_afm("saving %a in cache",name)
        data=containers.write(afm.cache,name,data)
        data=containers.read(afm.cache,name)
      end
    end
    if data then
      otfreaders.unpack(data)
      otfreaders.expand(data) 
      otfreaders.addunicodetable(data) 
      otfenhancers.apply(data,filename,data)
      if applyruntimefixes then
        applyruntimefixes(filename,data)
      end
    end
    return data
  end
end
local uparser=fonts.mappings.makenameparser() 
enhancers["unify names"]=function(data,filename)
  local unicodevector=fonts.encodings.agl.unicodes 
  local unicodes={}
  local names={}
  local private=constructors.privateoffset
  local descriptions=data.descriptions
  for name,blob in next,data.characters do
    local code=unicodevector[name] 
    if not code then
      code=lpegmatch(uparser,name)
      if type(code)~="number" then
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
  resources.private=private
end
local everywhere={ ["*"]={ ["*"]=true } } 
local noflags={ false,false,false,false }
enhancers["normalize features"]=function(data)
  local ligatures=setmetatableindex("table")
  local kerns=setmetatableindex("table")
  local extrakerns=setmetatableindex("table")
  for u,c in next,data.descriptions do
    local l=c.ligatures
    local k=c.kerns
    local e=c.extrakerns
    if l then
      ligatures[u]=l
      for u,v in next,l do
        l[u]={ ligature=v }
      end
      c.ligatures=nil
    end
    if k then
      kerns[u]=k
      for u,v in next,k do
        k[u]=v 
      end
      c.kerns=nil
    end
    if e then
      extrakerns[u]=e
      for u,v in next,e do
        e[u]=v 
      end
      c.extrakerns=nil
    end
  end
  local features={
    gpos={},
    gsub={},
  }
  local sequences={
  }
  if next(ligatures) then
    features.gsub.liga=everywhere
    data.properties.hasligatures=true
    sequences[#sequences+1]={
      features={
        liga=everywhere,
      },
      flags=noflags,
      name="s_s_0",
      nofsteps=1,
      order={ "liga" },
      type="gsub_ligature",
      steps={
        {
          coverage=ligatures,
        },
      },
    }
  end
  if next(kerns) then
    features.gpos.kern=everywhere
    data.properties.haskerns=true
    sequences[#sequences+1]={
      features={
        kern=everywhere,
      },
      flags=noflags,
      name="p_s_0",
      nofsteps=1,
      order={ "kern" },
      type="gpos_pair",
      steps={
        {
          format="kern",
          coverage=kerns,
        },
      },
    }
  end
  if next(extrakerns) then
    features.gpos.extrakerns=everywhere
    data.properties.haskerns=true
    sequences[#sequences+1]={
      features={
        extrakerns=everywhere,
      },
      flags=noflags,
      name="p_s_1",
      nofsteps=1,
      order={ "extrakerns" },
      type="gpos_pair",
      steps={
        {
          format="kern",
          coverage=extrakerns,
        },
      },
    }
  end
  data.resources.features=features
  data.resources.sequences=sequences
end
enhancers["check extra features"]=otf.enhancers.enhance
enhancers["fix names"]=function(data)
  for k,v in next,data.descriptions do
    local n=v.name
    local r=overloads[n]
    if r then
      local name=r.name
      if trace_indexing then
        report_afm("renaming characters %a to %a",n,name)
      end
      v.name=name
      v.unicode=r.unicode
    end
  end
end
local addthem=function(rawdata,ligatures)
  if ligatures then
    local descriptions=rawdata.descriptions
    local resources=rawdata.resources
    local unicodes=resources.unicodes
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
enhancers["add ligatures"]=function(rawdata)
  addthem(rawdata,afm.helpdata.ligatures)
end
enhancers["add extra kerns"]=function(rawdata) 
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
    local endash=0x0020 
    local emdash=0x2014
    local spacer="space"
    local spaceunits=500
    local monospaced=metadata.monospaced
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
      local x=0x0078 
      if x then
        local x=descriptions[x]
        if x then
          parameters.x_height=x.height
        end
      end
    end
    if metadata.sup then
      local dummy={ 0,0,0 }
      parameters[ 1]=metadata.designsize    or 0
      parameters[ 2]=metadata.checksum     or 0
      parameters[ 3],
      parameters[ 4],
      parameters[ 5]=unpack(metadata.space   or dummy)
      parameters[ 6]=metadata.quad    or 0
      parameters[ 7]=metadata.extraspace or 0
      parameters[ 8],
      parameters[ 9],
      parameters[10]=unpack(metadata.num    or dummy)
      parameters[11],
      parameters[12]=unpack(metadata.denom   or dummy)
      parameters[13],
      parameters[14],
      parameters[15]=unpack(metadata.sup    or dummy)
      parameters[16],
      parameters[17]=unpack(metadata.sub    or dummy)
      parameters[18]=metadata.supdrop  or 0
      parameters[19]=metadata.subdrop  or 0
      parameters[20],
      parameters[21]=unpack(metadata.delim   or dummy)
      parameters[22]=metadata.axisheight or 0
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
local function addtables(data)
  local resources=data.resources
  local lookuptags=resources.lookuptags
  local unicodes=resources.unicodes
  if not lookuptags then
    lookuptags={}
    resources.lookuptags=lookuptags
  end
  setmetatableindex(lookuptags,function(t,k)
    local v=type(k)=="number" and ("lookup "..k) or k
    t[k]=v
    return v
  end)
  if not unicodes then
    unicodes={}
    resources.unicodes=unicodes
    setmetatableindex(unicodes,function(t,k)
      setmetatableindex(unicodes,nil)
      for u,d in next,data.descriptions do
        local n=d.name
        if n then
          t[n]=u
        end
      end
      return rawget(t,k)
    end)
  end
  constructors.addcoreunicodes(unicodes) 
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
        addtables(rawdata)
        adddimensions(rawdata)
        tfmdata=copytotfm(rawdata)
        if tfmdata and next(tfmdata) then
          local shared=tfmdata.shared
          if not shared then
            shared={}
            tfmdata.shared=shared
          end
          shared.rawdata=rawdata
          shared.dynamics={}
          tfmdata.changed={}
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
registerafmfeature {
  name="mode",
  description="mode",
  initializers={
    base=otf.modeinitializer,
    node=otf.modeinitializer,
  }
}
registerafmfeature {
  name="features",
  description="features",
  default=true,
  initializers={
    node=otf.nodemodeinitializer,
    base=otf.basemodeinitializer,
  },
  processors={
    node=otf.featuresprocessor,
  }
}
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
  local fullname=specification.filename or ""
  local tfmdata=nil
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      tfmdata=check_afm(specification,specification.name.."."..forced)
    end
    if not tfmdata then
      local check_tfm=readers.check_tfm
      method=(check_tfm and (method or definers.method or "afm or tfm")) or "afm"
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
  specification.forced="afm"
  local function swap(name)
    local value=specification[swap]
    if value then
      specification[swap]=gsub("%.pfb",".afm",1)
    end
  end
  swap("filename")
  swap("fullname")
  swap("forcedname")
  swap("specification")
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

if not modules then modules={} end modules ['font-tfm']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next,type=next,type
local match,format=string.match,string.format
local concat,sortedhash=table.concat,table.sortedhash
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local trace_features=false trackers.register("tfm.features",function(v) trace_features=v end)
local report_defining=logs.reporter("fonts","defining")
local report_tfm=logs.reporter("fonts","tfm loading")
local findbinfile=resolvers.findbinfile
local setmetatableindex=table.setmetatableindex
local fonts=fonts
local handlers=fonts.handlers
local readers=fonts.readers
local constructors=fonts.constructors
local encodings=fonts.encodings
local tfm=constructors.handlers.tfm
tfm.version=1.000
tfm.maxnestingdepth=5
tfm.maxnestingsize=65536*1024
local otf=fonts.handlers.otf
local tfmfeatures=constructors.features.tfm
local registertfmfeature=tfmfeatures.register
constructors.resolvevirtualtoo=false 
fonts.formats.tfm="type1" 
fonts.formats.ofm="type1"
function tfm.setfeatures(tfmdata,features)
  local okay=constructors.initializefeatures("tfm",tfmdata,features,trace_features,report_tfm)
  if okay then
    return constructors.collectprocessors("tfm",tfmdata,features,trace_features,report_tfm)
  else
    return {} 
  end
end
local depth={} 
local enhancers={}
local steps={
  "normalize features",
  "check extra features"
}
enhancers["check extra features"]=otf.enhancers.enhance
local function applyenhancers(data,filename)
  for i=1,#steps do
    local step=steps[i]
    local enhancer=enhancers[step]
    if enhancer then
      if trace_loading then
        report_tfm("applying enhancer %a",step)
      end
      enhancer(data,filename)
    else
      report_tfm("invalid enhancer %a",step)
    end
  end
end
local function read_from_tfm(specification)
  local filename=specification.filename
  local size=specification.size
  depth[filename]=(depth[filename] or 0)+1
  if trace_defining then
    report_defining("loading tfm file %a at size %s",filename,size)
  end
  local tfmdata=font.read_tfm(filename,size) 
  if tfmdata then
    local features=specification.features and specification.features.normal or {}
    local features=constructors.checkedfeatures("tfm",features)
    specification.features.normal=features
    local newtfmdata=(depth[filename]==1) and tfm.reencode(tfmdata,specification)
    if newtfmdata then
       tfmdata=newtfmdata
    end
    local resources=tfmdata.resources or {}
    local properties=tfmdata.properties or {}
    local parameters=tfmdata.parameters or {}
    local shared=tfmdata.shared   or {}
    shared.features=features
    shared.resources=resources
    properties.name=tfmdata.name      
    properties.fontname=tfmdata.fontname    
    properties.psname=tfmdata.psname     
    properties.fullname=tfmdata.fullname    
    properties.filename=specification.filename 
    properties.format=fonts.formats.tfm
    tfmdata.properties=properties
    tfmdata.resources=resources
    tfmdata.parameters=parameters
    tfmdata.shared=shared
    shared.rawdata={ resources=resources }
    shared.features=features
    if newtfmdata then
      if not resources.marks then
        resources.marks={}
      end
      if not resources.sequences then
        resources.sequences={}
      end
      if not resources.features then
        resources.features={
          gsub={},
          gpos={},
        }
      end
      if not tfmdata.changed then
        tfmdata.changed={}
      end
      if not tfmdata.descriptions then
        tfmdata.descriptions=tfmdata.characters
      end
      otf.readers.addunicodetable(tfmdata)
      applyenhancers(tfmdata,filename)
      constructors.applymanipulators("tfm",tfmdata,features,trace_features,report_tfm)
      otf.readers.unifymissing(tfmdata)
      fonts.mappings.addtounicode(tfmdata,filename)
      tfmdata.tounicode=1
      local tounicode=fonts.mappings.tounicode
      for unicode,v in next,tfmdata.characters do
        local u=v.unicode
        if u then
          v.tounicode=tounicode(u)
        end
      end
      if tfmdata.usedbitmap then
        tfm.addtounicode(tfmdata)
      end
    end
    shared.processes=next(features) and tfm.setfeatures(tfmdata,features) or nil
    parameters.factor=1 
    parameters.size=size
    parameters.slant=parameters.slant     or parameters[1] or 0
    parameters.space=parameters.space     or parameters[2] or 0
    parameters.space_stretch=parameters.space_stretch or parameters[3] or 0
    parameters.space_shrink=parameters.space_shrink  or parameters[4] or 0
    parameters.x_height=parameters.x_height    or parameters[5] or 0
    parameters.quad=parameters.quad      or parameters[6] or 0
    parameters.extra_space=parameters.extra_space  or parameters[7] or 0
    constructors.enhanceparameters(parameters)
    if newtfmdata then
    elseif constructors.resolvevirtualtoo then
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
          tfmdata.type="virtual" 
          local fontlist=vfdata.fonts
          local name=file.nameonly(filename)
          for i=1,#fontlist do
            local n=fontlist[i].name
            local s=fontlist[i].size
            local d=depth[filename]
            s=constructors.scaled(s,vfdata.designsize)
            if d>tfm.maxnestingdepth then
              report_defining("too deeply nested virtual font %a with size %a, max nesting depth %s",n,s,tfm.maxnestingdepth)
              fontlist[i]={ id=0 }
            elseif (d>1) and (s>tfm.maxnestingsize) then
              report_defining("virtual font %a exceeds size %s",n,s)
              fontlist[i]={ id=0 }
            else
              local t,id=fonts.constructors.readanddefine(n,s)
              fontlist[i]={ id=id }
            end
          end
        end
      end
    end
    properties.haskerns=true
    properties.hasligatures=true
    resources.unicodes={}
    resources.lookuptags={}
    depth[filename]=depth[filename]-1
    return tfmdata
  else
    depth[filename]=depth[filename]-1
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
readers.ofm=readers.tfm
do
  local outfiles={}
  local tfmcache=table.setmetatableindex(function(t,tfmdata)
    local id=font.define(tfmdata)
    t[tfmdata]=id
    return id
  end)
  local encdone=table.setmetatableindex("table")
  function tfm.reencode(tfmdata,specification)
    local features=specification.features
    if not features then
      return
    end
    local features=features.normal
    if not features then
      return
    end
    local tfmfile=file.basename(tfmdata.name)
    local encfile=features.reencode 
    local pfbfile=features.pfbfile 
    local bitmap=features.bitmap  
    if not encfile then
      return
    end
    local pfbfile=outfiles[tfmfile]
    if pfbfile==nil then
      if bitmap then
        pfbfile=false
      elseif type(pfbfile)~="string" then
        pfbfile=tfmfile
      end
      if type(pfbfile)=="string" then
        pfbfile=file.addsuffix(pfbfile,"pfb")
        report_tfm("using type1 shapes from %a for %a",pfbfile,tfmfile)
      else
        report_tfm("using bitmap shapes for %a",tfmfile)
        pfbfile=false 
      end
      outfiles[tfmfile]=pfbfile
    end
    local encoding=false
    local vector=false
    if type(pfbfile)=="string" then
      local pfb=fonts.constructors.handlers.pfb
      if pfb and pfb.loadvector then
        local v,e=pfb.loadvector(pfbfile)
        if v then
          vector=v
        end
        if e then
          encoding=e
        end
      end
    end
    if type(encfile)=="string" and encfile~="auto" then
      encoding=fonts.encodings.load(file.addsuffix(encfile,"enc"))
      if encoding then
        encoding=encoding.vector
      end
    end
    if not encoding then
      report_tfm("bad encoding for %a, quitting",tfmfile)
      return
    end
    local unicoding=fonts.encodings.agl and fonts.encodings.agl.unicodes
    local virtualid=tfmcache[tfmdata]
    local tfmdata=table.copy(tfmdata) 
    local characters={}
    local originals=tfmdata.characters
    local indices={}
    local parentfont={ "font",1 }
    local private=fonts.constructors.privateoffset
    local reported=encdone[tfmfile][encfile]
    local backmap=vector and table.swapped(vector)
    local done={} 
    for index,name in sortedhash(encoding) do 
      local unicode=unicoding[name]
      local original=originals[index]
      if original then
        if unicode then
          original.unicode=unicode
        else
          unicode=private
          private=private+1
          if not reported then
            report_tfm("glyph %a in font %a with encoding %a gets unicode %U",name,tfmfile,encfile,unicode)
          end
        end
        characters[unicode]=original
        indices[index]=unicode
        original.name=name 
        if backmap then
          original.index=backmap[name]
        else 
          original.commands={ parentfont,{ "char",index } }
          original.oindex=index
        end
        done[name]=true
      elseif not done[name] then
        report_tfm("bad index %a in font %a with name %a",index,tfmfile,name)
      end
    end
    encdone[tfmfile][encfile]=true
    for k,v in next,characters do
      local kerns=v.kerns
      if kerns then
        local t={}
        for k,v in next,kerns do
          local i=indices[k]
          if i then
            t[i]=v
          end
        end
        v.kerns=next(t) and t or nil
      end
      local ligatures=v.ligatures
      if ligatures then
        local t={}
        for k,v in next,ligatures do
          local i=indices[k]
          if i then
            t[i]=v
            v.char=indices[v.char]
          end
        end
        v.ligatures=next(t) and t or nil
      end
    end
    tfmdata.fonts={ { id=virtualid } }
    tfmdata.characters=characters
    tfmdata.fullname=tfmdata.fullname or tfmdata.name
    tfmdata.psname=file.nameonly(pfbfile or tfmdata.name)
    tfmdata.filename=pfbfile
    tfmdata.encodingbytes=2
    tfmdata.format="type1"
    tfmdata.tounicode=1
    tfmdata.embedding="subset"
    tfmdata.usedbitmap=bitmap and virtualid
    return tfmdata
  end
end
do
  local template=[[
/CIDInit /ProcSet findresource begin
  12 dict begin
  begincmap
    /CIDSystemInfo << /Registry (TeX) /Ordering (bitmap-%s) /Supplement 0 >> def
    /CMapName /TeX-bitmap-%s def
    /CMapType 2 def
    1 begincodespacerange
      <00> <FF>
    endcodespacerange
    %s beginbfchar
%s
    endbfchar
  endcmap
CMapName currentdict /CMap defineresource pop end
end
end
]]
  local flushstreamobject=lpdf and lpdf.flushstreamobject
  local setfontattributes=pdf.setfontattributes
  if not flushstreamobject then
    flushstreamobject=function(data)
      return pdf.obj {
        immediate=true,
        type="stream",
        string=data,
      }
    end
  end
  if not setfontattributes then
    setfontattributes=function(id,data)
      print(format("your luatex is too old so no tounicode bitmap font%i",id))
    end
  end
  function tfm.addtounicode(tfmdata)
    local id=tfmdata.usedbitmap
    local map={}
    local char={} 
    for k,v in next,tfmdata.characters do
      local index=v.oindex
      local tounicode=v.tounicode
      if index and tounicode then
        map[index]=tounicode
      end
    end
    for k,v in sortedhash(map) do
      char[#char+1]=format("<%02X> <%s>",k,v)
    end
    char=concat(char,"\n")
    local stream=format(template,id,id,#char,char)
    local reference=flushstreamobject(stream,nil,true)
    setfontattributes(id,format("/ToUnicode %i 0 R",reference))
  end
end
do
  local everywhere={ ["*"]={ ["*"]=true } } 
  local noflags={ false,false,false,false }
  enhancers["normalize features"]=function(data)
    local ligatures=setmetatableindex("table")
    local kerns=setmetatableindex("table")
    local characters=data.characters
    for u,c in next,characters do
      local l=c.ligatures
      local k=c.kerns
      if l then
        ligatures[u]=l
        for u,v in next,l do
          l[u]={ ligature=v.char }
        end
        c.ligatures=nil
      end
      if k then
        kerns[u]=k
        for u,v in next,k do
          k[u]=v 
        end
        c.kerns=nil
      end
    end
    for u,l in next,ligatures do
      for k,v in next,l do
        local vl=v.ligature
        local dl=ligatures[vl]
        if dl then
          for kk,vv in next,dl do
            v[kk]=vv 
          end
        end
      end
    end
    local features={
      gpos={},
      gsub={},
    }
    local sequences={
    }
    if next(ligatures) then
      features.gsub.liga=everywhere
      data.properties.hasligatures=true
      sequences[#sequences+1]={
        features={
          liga=everywhere,
        },
        flags=noflags,
        name="s_s_0",
        nofsteps=1,
        order={ "liga" },
        type="gsub_ligature",
        steps={
          {
            coverage=ligatures,
          },
        },
      }
    end
    if next(kerns) then
      features.gpos.kern=everywhere
      data.properties.haskerns=true
      sequences[#sequences+1]={
        features={
          kern=everywhere,
        },
        flags=noflags,
        name="p_s_0",
        nofsteps=1,
        order={ "kern" },
        type="gpos_pair",
        steps={
          {
            format="kern",
            coverage=kerns,
          },
        },
      }
    end
    data.resources.features=features
    data.resources.sequences=sequences
    data.shared.resources=data.shared.resources or resources
  end
end
registertfmfeature {
  name="mode",
  description="mode",
  initializers={
    base=otf.modeinitializer,
    node=otf.modeinitializer,
  }
}
registertfmfeature {
  name="features",
  description="features",
  default=true,
  initializers={
    base=otf.basemodeinitializer,
    node=otf.nodemodeinitializer,
  },
  processors={
    node=otf.featuresprocessor,
  }
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-lua']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local report_lua=logs.reporter("fonts","lua loading")
local fonts=fonts
local readers=fonts.readers
fonts.formats.lua="lua"
local function check_lua(specification,fullname)
  local fullname=resolvers.findfile(fullname) or ""
  if fullname~="" then
    local loader=loadfile(fullname)
    loader=loader and loader()
    return loader and loader(specification)
  end
end
readers.check_lua=check_lua
function readers.lua(specification)
  local original=specification.specification
  if trace_defining then
    report_lua("using lua reader for %a",original)
  end
  local fullname=specification.filename or ""
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      fullname=specification.name.."."..forced
    else
      fullname=specification.name
    end
  end
  return check_lua(specification,fullname)
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
local lower,gsub=string.lower,string.gsub
local tostring,next=tostring,next
local lpegmatch=lpeg.match
local suffixonly,removesuffix=file.suffix,file.removesuffix
local formatters=string.formatters
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
    local resolved,sub,subindex=resolve(specification.name,specification.sub,specification) 
    if resolved then
      specification.resolved=resolved
      specification.sub=sub
      specification.subindex=subindex
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
    local resolved,sub,subindex=resolvespec(specification.name,specification.sub,specification) 
    if resolved then
      specification.resolved=resolved
      specification.sub=sub
      specification.subindex=subindex
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
        properties.fullname=formatters["%s-%s"](properties.fullname,extrahash)
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
    report_defining("using %a font with id %a, name %a, size %a, bytes %a, encoding %a, fullname %a, filename %a",
      properties.format or "unknown",id,properties.name,parameters.size,properties.encodingbytes,
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

if not modules then modules={} end modules ['luatex-fonts-def']={
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
local sometext=(R("az","AZ","09")+S("+-.{}"))^1
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
local otffeatures=fonts.constructors.features.otf
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

if not modules then modules={} end modules ['font-gbn']={
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
local nuts=nodes.nuts 
local traverse_id=nuts.traverse_id
local flush_node=nuts.flush_node
local glyph_code=nodes.nodecodes.glyph
local disc_code=nodes.nodecodes.disc
local tonode=nuts.tonode
local tonut=nuts.tonut
local getfont=nuts.getfont
local getchar=nuts.getchar
local getid=nuts.getid
local getboth=nuts.getboth
local getprev=nuts.getprev
local getnext=nuts.getnext
local getdisc=nuts.getdisc
local setchar=nuts.setchar
local setlink=nuts.setlink
local setprev=nuts.setprev
local n_ligaturing=node.ligaturing
local n_kerning=node.kerning
local ligaturing=nuts.ligaturing
local kerning=nuts.kerning
local basemodepass=true
local function l_warning() texio.write_nl("warning: node.ligaturing called directly") l_warning=nil end
local function k_warning() texio.write_nl("warning: node.kerning called directly")  k_warning=nil end
function node.ligaturing(...)
  if basemodepass and l_warning then
    l_warning()
  end
  return n_ligaturing(...)
end
function node.kerning(...)
  if basemodepass and k_warning then
    k_warning()
  end
  return n_kerning(...)
end
function nodes.handlers.setbasemodepass(v)
  basemodepass=v
end
function nodes.handlers.nodepass(head)
  local fontdata=fonts.hashes.identifiers
  if fontdata then
    local nuthead=tonut(head)
    local usedfonts={}
    local basefonts={}
    local prevfont=nil
    local basefont=nil
    local variants=nil
    local redundant=nil
    for n in traverse_id(glyph_code,nuthead) do
      local font=getfont(n)
      if font~=prevfont then
        if basefont then
          basefont[2]=getprev(n)
        end
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
              elseif basemodepass then
                basefont={ n,nil }
                basefonts[#basefonts+1]=basefont
              end
            end
            local resources=tfmdata.resources
            variants=resources and resources.variants
            variants=variants and next(variants) and variants or false
          end
        else
          local tfmdata=fontdata[prevfont]
          if tfmdata then
            local resources=tfmdata.resources
            variants=resources and resources.variants
            variants=variants and next(variants) and variants or false
          end
        end
      end
      if variants then
        local char=getchar(n)
        if char>=0xFE00 and (char<=0xFE0F or (char>=0xE0100 and char<=0xE01EF)) then
          local hash=variants[char]
          if hash then
            local p=getprev(n)
            if p and getid(p)==glyph_code then
              local variant=hash[getchar(p)]
              if variant then
                setchar(p,variant)
              end
            end
          end
          if not redundant then
            redundant={ n }
          else
            redundant[#redundant+1]=n
          end
        end
      end
    end
    local nofbasefonts=#basefonts
    if redundant then
      for i=1,#redundant do
        local r=redundant[i]
        local p,n=getboth(r)
        if r==nuthead then
          nuthead=n
          setprev(n)
        else
          setlink(p,n)
        end
        if nofbasefonts>0 then
          for i=1,nofbasefonts do
            local bi=basefonts[i]
            if r==bi[1] then
              bi[1]=n
            end
            if r==bi[2] then
              bi[2]=n
            end
          end
        end
        flush_node(r)
      end
    end
    for d in traverse_id(disc_code,nuthead) do
      local _,_,r=getdisc(d)
      if r then
        for n in traverse_id(glyph_code,r) do
          local font=getfont(n)
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
                  end
                end
              end
            end
          end
        end
      end
    end
    if next(usedfonts) then
      for font,processors in next,usedfonts do
        for i=1,#processors do
          head=processors[i](head,font,0) or head
        end
      end
    end
    if basemodepass and nofbasefonts>0 then
      for i=1,nofbasefonts do
        local range=basefonts[i]
        local start=range[1]
        local stop=range[2]
        if start then
          local front=nuthead==start
          local prev,next
          if stop then
            next=getnext(stop)
            start,stop=ligaturing(start,stop)
            start,stop=kerning(start,stop)
          else
            prev=getprev(start)
            start=ligaturing(start)
            start=kerning(start)
          end
          if prev then
            setlink(prev,start)
          end
          if next then
            setlink(stop,next)
          end
          if front and nuthead~=start then
            head=tonode(start)
          end
        end
      end
    end
    return head,true
  else
    return head,false
  end
end
function nodes.handlers.basepass(head)
  if not basemodepass then
    head=n_ligaturing(head)
    head=n_kerning(head)
  end
  return head,true
end
local nodepass=nodes.handlers.nodepass
local basepass=nodes.handlers.basepass
local injectpass=nodes.injections.handler
local protectpass=nodes.handlers.protectglyphs
function nodes.simple_font_handler(head)
  if head then
    head=nodepass(head)
    head=injectpass(head)
    if not basemodepass then
      head=basepass(head)
    end
    protectpass(head)
    return head,true
  else
    return head,false
  end
end

end -- closure
