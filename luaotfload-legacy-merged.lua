-- merged file : luaotfload-legacy-merged.lua
-- parent file : luaotfload-legacy.lua
-- merge date  : Fri May 10 20:57:35 2013

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luat-dum']={
  version=1.100,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local dummyfunction=function() end
statistics={
  register=dummyfunction,
  starttiming=dummyfunction,
  stoptiming=dummyfunction,
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
  report=dummyfunction,
  simple=dummyfunction,
}
tasks={
  new=dummyfunction,
  actions=dummyfunction,
  appendaction=dummyfunction,
  prependaction=dummyfunction,
}
callbacks={
  register=function(n,f) return callback.register(n,f) end,
}
texconfig.kpse_init=true
resolvers=resolvers or {} 
local remapper={
  otf="opentype fonts",
  ttf="truetype fonts",
  ttc="truetype fonts",
  dfont="truetype fonts",
  cid="cid maps",
  fea="font feature files",
}
function resolvers.find_file(name,kind)
  name=string.gsub(name,"\\","/")
  kind=string.lower(kind)
  return kpse.find_file(name,(kind and kind~="" and (remapper[kind] or kind)) or file.extname(name,"tex"))
end
function resolvers.findbinfile(name,kind)
  if not kind or kind=="" then
    kind=file.extname(name) 
  end
  return resolvers.find_file(name,(kind and remapper[kind]) or kind)
end
caches={}
local writable,readables=nil,{}
if not caches.namespace or caches.namespace=="" or caches.namespace=="context" then
  caches.namespace='generic'
end
do
  local cachepaths
  if kpse.expand_var('$TEXMFCACHE')~='$TEXMFCACHE' then
    cachepaths=kpse.expand_var('$TEXMFCACHE')
  elseif kpse.expand_var('$TEXMFVAR')~='$TEXMFVAR' then
    cachepaths=kpse.expand_var('$TEXMFVAR')
  end
  if not cachepaths then
    cachepaths="."
  end
  cachepaths=string.split(cachepaths,os.type=="windows" and ";" or ":")
  for i=1,#cachepaths do
    local done
    writable=file.join(cachepaths[i],"luatex-cache")
    writable=file.join(writable,caches.namespace)
    writable,done=dir.mkdirs(writable)
    if done then
      break
    end
  end
  for i=1,#cachepaths do
    if file.isreadable(cachepaths[i]) then
      readables[#readables+1]=file.join(cachepaths[i],"luatex-cache",caches.namespace)
    end
  end
  if not writable then
    texio.write_nl("quiting: fix your writable cache path\n")
    os.exit()
  elseif #readables==0 then
    texio.write_nl("quiting: fix your readable cache path\n")
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
    name="temp-"..name 
    return file.addsuffix(file.join(path,name),"lua")
  end
end
function caches.iswritable(path,name)
  local fullname=makefullname(path,name)
  return fullname and file.iswritable(fullname)
end
function caches.loaddata(paths,name)
  for i=1,#paths do
    local fullname=makefullname(paths[i],name)
    if fullname then
      texio.write(string.format("(load: %s)",fullname))
      local data=loadfile(fullname)
      return data and data()
    end
  end
end
function caches.savedata(path,name,data)
  local fullname=makefullname(path,name)
  if fullname then
    texio.write(string.format("(save: %s)",fullname))
    table.tofile(fullname,data,'return',false,true,false)
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['luat-ovr']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Khaled Hosny and Elie Roux",
  copyright="Luaotfload Development Team",
  license="GNU GPL v2"
}
local write_nl,format,name=texio.write_nl,string.format,"luaotfload"
local dummyfunction=function() end
callbacks={
  register=dummyfunction,
}
function logs.report(category,fmt,...)
  if fmt then
    write_nl('log',format("%s | %s: %s",name,category,format(fmt,...)))
  elseif category then
    write_nl('log',format("%s | %s",name,category))
  else
    write_nl('log',format("%s |",name))
  end
end
function logs.info(category,fmt,...)
  if fmt then
    write_nl(format("%s | %s: %s",name,category,format(fmt,...)))
  elseif category then
    write_nl(format("%s | %s",name,category))
  else
    write_nl(format("%s |",name))
  end
  io.flush()
end
function logs.simple(fmt,...)
  if fmt then
    write_nl('log',format("%s | %s",name,format(fmt,...)))
  else
    write_nl('log',format("%s |",name))
  end
end
tex.attribute[0]=0
tex.ctxcatcodes=luatexbase.catcodetables.latex

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
containers.usecache=true
local function report(container,tag,name)
  if trace_cache or trace_containers then
    logs.report(format("%s cache",container.subcategory),"%s: %s",tag,name or 'invalid')
  end
end
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
  end
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
  return container.enabled and caches and caches.iswritable(container.writable,name)
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
      report(container,"loaded",name)
    else
      stored=nil
    end
    storage[name]=stored
  elseif stored then
    report(container,"reusing",name)
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
      report(container,"saved",name)
      data.unique,data.shared=unique,shared
    end
    report(container,"stored",name)
    container.storage[name]=data
  end
  return data
end
function containers.content(container,name)
  return container.storage[name]
end
function containers.cleanname(name)
  return (gsub(lower(name),"[^%w%d]+","-"))
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-ini']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local utf=unicode.utf8
local format,serialize=string.format,table.serialize
local write_nl=texio.write_nl
local lower=string.lower
if not fontloader then fontloader=fontforge end
fontloader.totable=fontloader.to_table
fonts=fonts   or {}
fonts.ids=fonts.ids or {} fonts.identifiers=fonts.ids 
fonts.chr=fonts.chr or {} fonts.characters=fonts.chr 
fonts.qua=fonts.qua or {} fonts.quads=fonts.qua 
fonts.tfm=fonts.tfm or {}
fonts.mode='base'
fonts.private=0xF0000 
fonts.verbose=false 
fonts.ids[0]={ 
  characters={},
  descriptions={},
  name="nullfont",
}
fonts.chr[0]={}
fonts.methods=fonts.methods or {
  base={ tfm={},afm={},otf={},vtf={},fix={} },
  node={ tfm={},afm={},otf={},vtf={},fix={} },
}
fonts.initializers=fonts.initializers or {
  base={ tfm={},afm={},otf={},vtf={},fix={} },
  node={ tfm={},afm={},otf={},vtf={},fix={} }
}
fonts.triggers=fonts.triggers or {
  'mode',
  'language',
  'script',
  'strategy',
}
fonts.processors=fonts.processors or {}
fonts.manipulators=fonts.manipulators or {}
fonts.define=fonts.define         or {}
fonts.define.specify=fonts.define.specify     or {}
fonts.define.specify.synonyms=fonts.define.specify.synonyms or {}
if not fonts.color then
  fonts.color={
    set=function() end,
    reset=function() end,
  }
end
fonts.formats={}
function fonts.fontformat(filename,default)
  local extname=lower(file.extname(filename))
  local format=fonts.formats[extname]
  if format then
    return format
  else
    logs.report("fonts define","unable to determine font format for '%s'",filename)
    return default
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['node-dum']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
nodes=nodes   or {}
fonts=fonts   or {}
attributes=attributes or {}
local traverse_id=node.traverse_id
local free_node=node.free
local remove_node=node.remove
local new_node=node.new
local glyph=node.id('glyph')
local fontdata=fonts.ids or {}
function nodes.simple_font_handler(head)
  head=nodes.process_characters(head)
  nodes.inject_kerns(head)
  nodes.protect_glyphs(head)
  head=node.ligaturing(head)
  head=node.kerning(head)
  return head
end
if tex.attribute[0]~=0 then
  texio.write_nl("log","!")
  texio.write_nl("log","! Attribute 0 is reserved for ConTeXt's font feature management and has to be")
  texio.write_nl("log","! set to zero. Also, some attributes in the range 1-255 are used for special")
  texio.write_nl("log","! purposed so setting them at the TeX end might break the font handler.")
  texio.write_nl("log","!")
  tex.attribute[0]=0 
end
nodes.protect_glyphs=node.protect_glyphs
nodes.unprotect_glyphs=node.unprotect_glyphs
function nodes.process_characters(head)
  local usedfonts,done,prevfont={},false,nil
  for n in traverse_id(glyph,head) do
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
end
function nodes.kern(k)
  local n=new_node("kern",1)
  n.kern=k
  return n
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
nodes.before=node.insert_before
nodes.after=node.insert_after
attributes.unsetvalue=-0x7FFFFFFF
local numbers,last={},127
function attributes.private(name)
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

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['node-inj']={
  version=1.001,
  comment="companion to node-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local next=next
local trace_injections=false trackers.register("nodes.injections",function(v) trace_injections=v end)
fonts=fonts   or {}
fonts.tfm=fonts.tfm or {}
fonts.ids=fonts.ids or {}
local fontdata=fonts.ids
local glyph=node.id('glyph')
local kern=node.id('kern')
local traverse_id=node.traverse_id
local unset_attribute=node.unset_attribute
local has_attribute=node.has_attribute
local set_attribute=node.set_attribute
local insert_node_before=node.insert_before
local insert_node_after=node.insert_after
local newkern=nodes.kern
local markbase=attributes.private('markbase')
local markmark=attributes.private('markmark')
local markdone=attributes.private('markdone')
local cursbase=attributes.private('cursbase')
local curscurs=attributes.private('curscurs')
local cursdone=attributes.private('cursdone')
local kernpair=attributes.private('kernpair')
local cursives={}
local marks={}
local kerns={}
function nodes.set_cursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext)
  local dx,dy=factor*(exit[1]-entry[1]),factor*(exit[2]-entry[2])
  local ws,wn=tfmstart.width,tfmnext.width
  local bound=#cursives+1
  set_attribute(start,cursbase,bound)
  set_attribute(nxt,curscurs,bound)
  cursives[bound]={ rlmode,dx,dy,ws,wn }
  return dx,dy,bound
end
function nodes.set_pair(current,factor,rlmode,r2lflag,spec,tfmchr)
  local x,y,w,h=factor*spec[1],factor*spec[2],factor*spec[3],factor*spec[4]
  if x~=0 or w~=0 or y~=0 or h~=0 then
    local bound=has_attribute(current,kernpair)
    if bound then
      local kb=kerns[bound]
      kb[2],kb[3],kb[4],kb[5]=(kb[2] or 0)+x,(kb[3] or 0)+y,(kb[4] or 0)+w,(kb[5] or 0)+h
    else
      bound=#kerns+1
      set_attribute(current,kernpair,bound)
      kerns[bound]={ rlmode,x,y,w,h,r2lflag,tfmchr.width }
    end
    return x,y,w,h,bound
  end
  return x,y,w,h 
end
function nodes.set_kern(current,factor,rlmode,x,tfmchr)
  local dx=factor*x
  if dx~=0 then
    local bound=#kerns+1
    set_attribute(current,kernpair,bound)
    kerns[bound]={ rlmode,dx }
    return dx,bound
  else
    return 0,0
  end
end
function nodes.set_mark(start,base,factor,rlmode,ba,ma,index) 
  local dx,dy=factor*(ba[1]-ma[1]),factor*(ba[2]-ma[2])
  local bound=has_attribute(base,markbase)
  if bound then
    local mb=marks[bound]
    if mb then
      if not index then index=#mb+1 end
      mb[index]={ dx,dy }
      set_attribute(start,markmark,bound)
      set_attribute(start,markdone,index)
      return dx,dy,bound
    else
      logs.report("nodes mark","possible problem, U+%04X is base without data (id: %s)",base.char,bound)
    end
  end
  index=index or 1
  bound=#marks+1
  set_attribute(base,markbase,bound)
  set_attribute(start,markmark,bound)
  set_attribute(start,markdone,index)
  marks[bound]={ [index]={ dx,dy,rlmode } }
  return dx,dy,bound
end
function nodes.trace_injection(head)
  local function dir(n)
    return (n and n<0 and "r-to-l") or (n and n>0 and "l-to-r") or ("unset")
  end
  local function report(...)
    logs.report("nodes finisher",...)
  end
  report("begin run")
  for n in traverse_id(glyph,head) do
    if n.subtype<256 then
      local kp=has_attribute(n,kernpair)
      local mb=has_attribute(n,markbase)
      local mm=has_attribute(n,markmark)
      local md=has_attribute(n,markdone)
      local cb=has_attribute(n,cursbase)
      local cc=has_attribute(n,curscurs)
      report("char U+%05X, font=%s",n.char,n.font)
      if kp then
        local k=kerns[kp]
        if k[3] then
          report("  pairkern: dir=%s, x=%s, y=%s, w=%s, h=%s",dir(k[1]),k[2] or "?",k[3] or "?",k[4] or "?",k[5] or "?")
        else
          report("  kern: dir=%s, dx=%s",dir(k[1]),k[2] or "?")
        end
      end
      if mb then
        report("  markbase: bound=%s",mb)
      end
      if mm then
        local m=marks[mm]
        if mb then
          local m=m[mb]
          if m then
            report("  markmark: bound=%s, index=%s, dx=%s, dy=%s",mm,md or "?",m[1] or "?",m[2] or "?")
          else
            report("  markmark: bound=%s, missing index",mm)
          end
        else
          m=m[1]
          report("  markmark: bound=%s, dx=%s, dy=%s",mm,m[1] or "?",m[2] or "?")
        end
      end
      if cb then
        report("  cursbase: bound=%s",cb)
      end
      if cc then
        local c=cursives[cc]
        report("  curscurs: bound=%s, dir=%s, dx=%s, dy=%s",cc,dir(c[1]),c[2] or "?",c[3] or "?")
      end
    end
  end
  report("end run")
end
function nodes.inject_kerns(head,where,keep)
  local has_marks,has_cursives,has_kerns=next(marks),next(cursives),next(kerns)
  if has_marks or has_cursives then
    if trace_injections then
      nodes.trace_injection(head)
    end
    local done,ky,rl,valid,cx,wx,mk=false,{},{},{},{},{},{}
    if has_kerns then 
      local nf,tm=nil,nil
      for n in traverse_id(glyph,head) do
        if n.subtype<256 then
          valid[#valid+1]=n
          if n.font~=nf then
            nf=n.font
            tm=fontdata[nf].marks
          end
          mk[n]=tm[n.char]
          local k=has_attribute(n,kernpair)
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
      for n in traverse_id(glyph,head) do
        if n.subtype<256 then
          valid[#valid+1]=n
          if n.font~=nf then
            nf=n.font
            tm=fontdata[nf].marks
          end
          mk[n]=tm[n.char]
        end
      end
    end
    if #valid>0 then
      local cx={}
      if has_kerns and next(ky) then
        for n,k in next,ky do
          n.yoffset=k
        end
      end
      if has_cursives then
        local p_cursbase,p=nil,nil
        local t,d,maxt={},{},0
        for i=1,#valid do 
          local n=valid[i]
          if not mk[n] then
            local n_cursbase=has_attribute(n,cursbase)
            if p_cursbase then
              local n_curscurs=has_attribute(n,curscurs)
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
        for i=1,#valid do
          local p=valid[i]
          local p_markbase=has_attribute(p,markbase)
          if p_markbase then
            local mrks=marks[p_markbase]
            for n in traverse_id(glyph,p.next) do
              local n_markmark=has_attribute(n,markmark)
              if p_markbase==n_markmark then
                local index=has_attribute(n,markdone) or 1
                local d=mrks[index]
                if d then
                  local rlmode=d[3]
                  if rlmode and rlmode>0 then
                    local k=wx[p]
                    if k then 
                      n.xoffset=p.xoffset-(p.width-d[1])-k[2]
                    else
                      n.xoffset=p.xoffset-(p.width-d[1])
                    end
                  else
                    local k=wx[p]
                    if k then
                      n.xoffset=p.xoffset-d[1]-k[2]
                    else
                      n.xoffset=p.xoffset-d[1]
                    end
                  end
                  if mk[p] then
                    n.yoffset=p.yoffset+d[2]
                  else
                    n.yoffset=n.yoffset+p.yoffset+d[2]
                  end
                end
              else
                break
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
          local rl,x,w,r2l=k[1],k[2] or 0,k[4] or 0,k[6]
          local wx=w-x
          if r2l then
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
      nodes.trace_injection(head)
    end
    for n in traverse_id(glyph,head) do
      if n.subtype<256 then
        local k=has_attribute(n,kernpair)
        if k then
          local kk=kerns[k]
          if kk then
            local rl,x,y,w=kk[1],kk[2] or 0,kk[3],kk[4]
            if y and y~=0 then
              n.yoffset=y 
            end
            if w then
              local r2l=kk[6]
              local wx=w-x
              if r2l then
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


if not modules then modules={} end modules ['otfl-luat-att']={
  version=math.pi/42,
  comment="companion to luaotfload.lua",
  author="Philipp Gesang",
  copyright="Luaotfload Development Team",
  license="GNU GPL v2"
}
function attributes.private(name)
  local attr="otfl@"..name
  local number=luatexbase.attributes[attr]
  if not number then
    number=luatexbase.new_attribute(attr)
  end
  return number
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
local utf=unicode.utf8
local next,format,match,lower,gsub=next,string.format,string.match,string.lower,string.gsub
local concat,sortedkeys,utfbyte,serialize=table.concat,table.sortedkeys,utf.byte,table.serialize
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local trace_scaling=false trackers.register("fonts.scaling",function(v) trace_scaling=v end)
fonts=fonts   or {}
fonts.tfm=fonts.tfm or {}
fonts.ids=fonts.ids or {}
local tfm=fonts.tfm
fonts.loaded=fonts.loaded  or {}
fonts.dontembed=fonts.dontembed or {}
fonts.triggers=fonts.triggers or {} 
fonts.initializers=fonts.initializers    or {}
fonts.initializers.common=fonts.initializers.common or {}
local fontdata=fonts.ids
local disc=node.id('disc')
local glyph=node.id('glyph')
local set_attribute=node.set_attribute
tfm.resolve_vf=true 
tfm.share_base_kerns=false 
tfm.mathactions={}
tfm.fontname_mode="fullpath"
tfm.enhance=tfm.enhance or function() end
fonts.formats.tfm="type1" 
function tfm.read_from_tfm(specification)
  local fname,tfmdata=specification.filename or "",nil
  if fname~="" then
    if trace_defining then
      logs.report("define font","loading tfm file %s at size %s",fname,specification.size)
    end
    tfmdata=font.read_tfm(fname,specification.size) 
    if tfmdata then
      tfmdata.descriptions=tfmdata.descriptions or {}
      if tfm.resolve_vf then
        fonts.logger.save(tfmdata,file.extname(fname),specification) 
        fname=resolvers.findbinfile(specification.name,'ovf')
        if fname and fname~="" then
          local vfdata=font.read_vf(fname,specification.size) 
          if vfdata then
            local chars=tfmdata.characters
            for k,v in next,vfdata.characters do
              chars[k].commands=v.commands
            end
            tfmdata.type='virtual'
            tfmdata.fonts=vfdata.fonts
          end
        end
      end
      tfm.enhance(tfmdata,specification)
    end
  elseif trace_defining then
    logs.report("define font","loading tfm with name %s fails",specification.name)
  end
  return tfmdata
end
local factors={
  pt=65536.0,
  bp=65781.8,
}
function tfm.setfactor(f)
  tfm.factor=factors[f or 'pt'] or factors.pt
end
tfm.setfactor()
function tfm.scaled(scaledpoints,designsize) 
  if scaledpoints<0 then
    if designsize then
      if designsize>tfm.factor then 
        return (- scaledpoints/1000)*designsize 
      else
        return (- scaledpoints/1000)*designsize*tfm.factor
      end
    else
      return (- scaledpoints/1000)*10*tfm.factor
    end
  else
    return scaledpoints
  end
end
function tfm.get_virtual_id(tfmdata)
  if not tfmdata.fonts then
    tfmdata.type="virtual"
    tfmdata.fonts={ { id=0 } }
    return 1
  else
    tfmdata.fonts[#tfmdata.fonts+1]={ id=0 }
    return #tfmdata.fonts
  end
end
function tfm.check_virtual_id(tfmdata,id)
  if tfmdata and tfmdata.type=="virtual" then
    if not tfmdata.fonts or #tfmdata.fonts==0 then
      tfmdata.type,tfmdata.fonts="real",nil
    else
      local vfonts=tfmdata.fonts
      for f=1,#vfonts do
        local fnt=vfonts[f]
        if fnt.id and fnt.id==0 then
          fnt.id=id
        end
      end
    end
  end
end
fonts.trace_scaling=false
local charactercache={}
function tfm.calculate_scale(tfmtable,scaledpoints,relativeid)
  if scaledpoints<0 then
    scaledpoints=(- scaledpoints/1000)*tfmtable.designsize 
  end
  local units=tfmtable.units or 1000
  local delta=scaledpoints/units 
  return scaledpoints,delta,units
end
function tfm.do_scale(tfmtable,scaledpoints,relativeid)
  local t={} 
  local scaledpoints,delta,units=tfm.calculate_scale(tfmtable,scaledpoints,relativeid)
  t.units_per_em=units or 1000
  local hdelta,vdelta=delta,delta
  for k,v in next,tfmtable do
    if type(v)=="table" then
    else
      t[k]=v
    end
  end
  local extend_factor=tfmtable.extend_factor or 0
  if extend_factor~=0 and extend_factor~=1 then
    hdelta=hdelta*extend_factor
    t.extend=extend_factor*1000
  else
    t.extend=1000
  end
  local slant_factor=tfmtable.slant_factor or 0
  if slant_factor~=0 then
    t.slant=slant_factor*1000
  else
    t.slant=0
  end
  local isvirtual=tfmtable.type=="virtual" or tfmtable.virtualized
  local hasmath=(tfmtable.math_parameters~=nil and next(tfmtable.math_parameters)~=nil) or (tfmtable.MathConstants~=nil and next(tfmtable.MathConstants)~=nil)
  local nodemode=tfmtable.mode=="node"
  local hasquality=tfmtable.auto_expand or tfmtable.auto_protrude
  local hasitalic=tfmtable.has_italic
  t.parameters={}
  t.characters={}
  t.MathConstants={}
  local descriptions=tfmtable.descriptions or {}
  t.unicodes=tfmtable.unicodes
  t.indices=tfmtable.indices
  t.marks=tfmtable.marks
t.goodies=tfmtable.goodies
t.colorscheme=tfmtable.colorscheme
  t.descriptions=descriptions
  if tfmtable.fonts then
    t.fonts=table.fastcopy(tfmtable.fonts) 
  end
  local tp=t.parameters
  local mp=t.math_parameters
  local tfmp=tfmtable.parameters
  tp.slant=(tfmp.slant     or tfmp[1] or 0)
  tp.space=(tfmp.space     or tfmp[2] or 0)*hdelta
  tp.space_stretch=(tfmp.space_stretch or tfmp[3] or 0)*hdelta
  tp.space_shrink=(tfmp.space_shrink or tfmp[4] or 0)*hdelta
  tp.x_height=(tfmp.x_height   or tfmp[5] or 0)*vdelta
  tp.quad=(tfmp.quad     or tfmp[6] or 0)*hdelta
  tp.extra_space=(tfmp.extra_space  or tfmp[7] or 0)*hdelta
  local protrusionfactor=(tp.quad~=0 and 1000/tp.quad) or 0
  local tc=t.characters
  local characters=tfmtable.characters
  local nameneeded=not tfmtable.shared.otfdata 
  local changed=tfmtable.changed or {} 
  local ischanged=changed and next(changed)
  local indices=tfmtable.indices
  local luatex=tfmtable.luatex
  local tounicode=luatex and luatex.tounicode
  local defaultwidth=luatex and luatex.defaultwidth or 0
  local defaultheight=luatex and luatex.defaultheight or 0
  local defaultdepth=luatex and luatex.defaultdepth or 0
  local scaledwidth=defaultwidth*hdelta
  local scaledheight=defaultheight*vdelta
  local scaleddepth=defaultdepth*vdelta
  local stackmath=tfmtable.ignore_stack_math~=true
  local private=fonts.private
  local sharedkerns={}
  for k,v in next,characters do
    local chr,description,index
    if ischanged then
      local c=changed[k]
      if c then
        description=descriptions[c] or v
        v=characters[c] or v
        index=(indices and indices[c]) or c
      else
        description=descriptions[k] or v
        index=(indices and indices[k]) or k
      end
    else
      description=descriptions[k] or v
      index=(indices and indices[k]) or k
    end
    local width=description.width
    local height=description.height
    local depth=description.depth
    if width then width=hdelta*width else width=scaledwidth end
    if height then height=vdelta*height else height=scaledheight end
    if depth and depth~=0 then
      depth=delta*depth
      if nameneeded then
        chr={
          name=description.name,
          index=index,
          height=height,
          depth=depth,
          width=width,
        }
      else
        chr={
          index=index,
          height=height,
          depth=depth,
          width=width,
        }
      end
    else
      if nameneeded then
        chr={
          name=description.name,
          index=index,
          height=height,
          width=width,
        }
      else
        chr={
          index=index,
          height=height,
          width=width,
        }
      end
    end
    if tounicode then
      local tu=tounicode[index] 
      if tu then
        chr.tounicode=tu
      end
    end
    if hasquality then
      local ve=v.expansion_factor
      if ve then
        chr.expansion_factor=ve*1000 
      end
      local vl=v.left_protruding
      if vl then
        chr.left_protruding=protrusionfactor*width*vl
      end
      local vr=v.right_protruding
      if vr then
        chr.right_protruding=protrusionfactor*width*vr
      end
    end
    if hasitalic then
      local vi=description.italic or v.italic
      if vi and vi~=0 then
        chr.italic=vi*hdelta
      end
    end
    if hasmath then
      local vn=v.next
      if vn then
        chr.next=vn
      else
        local vv=v.vert_variants
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
          local hv=v.horiz_variants
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
      local vt=description.top_accent
      if vt then
        chr.top_accent=vdelta*vt
      end
      if stackmath then
        local mk=v.mathkerns
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
      local vk=v.kerns
      if vk then
        local s=sharedkerns[vk]
        if not s then
          s={}
          for k,v in next,vk do s[k]=v*hdelta end
          sharedkerns[vk]=s
        end
        chr.kerns=s
      end
      local vl=v.ligatures
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
      local vc=v.commands
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
              tt[#tt+1]={ key,ivc[2]*hdelta }
            elseif key=="down" then
              tt[#tt+1]={ key,ivc[2]*vdelta }
            elseif key=="rule" then
              tt[#tt+1]={ key,ivc[2]*vdelta,ivc[3]*hdelta }
            else 
              tt[#tt+1]=ivc 
            end
          end
          chr.commands=tt
        else
          chr.commands=vc
        end
      end
    end
    tc[k]=chr
  end
  t.size=scaledpoints
  t.factor=delta
  t.hfactor=hdelta
  t.vfactor=vdelta
  if t.fonts then
    t.fonts=table.fastcopy(t.fonts) 
  end
  if hasmath then
    local ma=tfm.mathactions
    for i=1,#ma do
      ma[i](t,tfmtable,delta,hdelta,vdelta) 
    end
  end
  local tpx=tp.x_height
  if hasmath then
    if not tp[13] then tp[13]=.86*tpx end 
    if not tp[14] then tp[14]=.86*tpx end 
    if not tp[15] then tp[15]=.86*tpx end 
    if not tp[16] then tp[16]=.48*tpx end 
    if not tp[17] then tp[17]=.48*tpx end 
    if not tp[22] then tp[22]=0   end 
    if t.MathConstants then t.MathConstants.AccentBaseHeight=nil end 
  end
  t.tounicode=1
  t.cidinfo=tfmtable.cidinfo
  if hasmath then
    if trace_defining then
      logs.report("define font","math enabled for: name '%s', fullname: '%s', filename: '%s'",t.name or "noname",t.fullname or "nofullname",t.filename or "nofilename")
    end
  else
    if trace_defining then
      logs.report("define font","math disabled for: name '%s', fullname: '%s', filename: '%s'",t.name or "noname",t.fullname or "nofullname",t.filename or "nofilename")
    end
    t.nomath,t.MathConstants=true,nil
  end
  if not t.psname then
    t.psname=t.fontname or (t.fullname and fonts.names.cleanname(t.fullname))
  end
  if trace_defining then
    logs.report("define font","used for accesing subfont: '%s'",t.psname or "nopsname")
    logs.report("define font","used for subsetting: '%s'",t.fontname or "nofontname")
  end
  return t,delta
end
tfm.auto_cleanup=true
local lastfont=nil
function tfm.cleanup_table(tfmdata) 
  if tfm.auto_cleanup then 
    if tfmdata.type=='virtual' or tfmdata.virtualized then
      for k,v in next,tfmdata.characters do
        if v.commands then v.commands=nil end
      end
    else
    end
  end
end
function tfm.cleanup(tfmdata) 
end
function tfm.scale(tfmtable,scaledpoints,relativeid)
  local t,factor=tfm.do_scale(tfmtable,scaledpoints,relativeid)
  t.factor=factor
  t.ascender=factor*(tfmtable.ascender or 0)
  t.descender=factor*(tfmtable.descender or 0)
  t.shared=tfmtable.shared or {}
  t.unique=table.fastcopy(tfmtable.unique or {})
  tfm.cleanup(t)
  return t
end
fonts.analyzers=fonts.analyzers       or {}
fonts.analyzers.aux=fonts.analyzers.aux     or {}
fonts.analyzers.methods=fonts.analyzers.methods   or {}
fonts.analyzers.initializers=fonts.analyzers.initializers or {}
local state=attributes.private('state')
function fonts.analyzers.aux.setstate(head,font)
  local tfmdata=fontdata[font]
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local first,last,current,n,done=nil,nil,head,0,false 
  while current do
    local id=current.id
    if id==glyph and current.font==font then
      local d=descriptions[current.char]
      if d then
        if d.class=="mark" then
          done=true
          set_attribute(current,state,5) 
        elseif n==0 then
          first,last,n=current,current,1
          set_attribute(current,state,1) 
        else
          last,n=current,n+1
          set_attribute(current,state,2) 
        end
      else 
        if first and first==last then
          set_attribute(last,state,4) 
        elseif last then
          set_attribute(last,state,3) 
        end
        first,last,n=nil,nil,0
      end
    elseif id==disc then
      set_attribute(current,state,2) 
      last=current
    else 
      if first and first==last then
        set_attribute(last,state,4) 
      elseif last then
        set_attribute(last,state,3) 
      end
      first,last,n=nil,nil,0
    end
    current=current.next
  end
  if first and first==last then
    set_attribute(last,state,4) 
  elseif last then
    set_attribute(last,state,3) 
  end
  return head,done
end
function tfm.replacements(tfm,value)
  tfm.characters[0x0027]=tfm.characters[0x2019]
end
function tfm.checked_filename(metadata,whatever)
  local foundfilename=metadata.foundfilename
  if not foundfilename then
    local askedfilename=metadata.filename or ""
    if askedfilename~="" then
      foundfilename=resolvers.findbinfile(askedfilename,"") or ""
      if foundfilename=="" then
        logs.report("fonts","source file '%s' is not found",askedfilename)
        foundfilename=resolvers.findbinfile(file.basename(askedfilename),"") or ""
        if foundfilename~="" then
          logs.report("fonts","using source file '%s' (cache mismatch)",foundfilename)
        end
      end
    elseif whatever then
      logs.report("fonts","no source file for '%s'",whatever)
      foundfilename=""
    end
    metadata.foundfilename=foundfilename
  end
  return foundfilename
end
statistics.register("fonts load time",function()
  return statistics.elapsedseconds(fonts)
end)

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
local lpegmatch=lpeg.match
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
fonts=fonts     or {}
fonts.cid=fonts.cid   or {}
fonts.cid.map=fonts.cid.map or {}
fonts.cid.max=fonts.cid.max or 10
local number=lpeg.C(lpeg.R("09","af","AF")^1)
local space=lpeg.S(" \n\r\t")
local spaces=space^0
local period=lpeg.P(".")
local periods=period*period
local name=lpeg.P("/")*lpeg.C((1-space)^1)
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
local grammar=lpeg.P { "start",
  start=number*spaces*number*lpeg.V("series"),
  series=(spaces*(lpeg.V("one")+lpeg.V("range")+lpeg.V("named")) )^1,
  one=(number*spaces*number)/do_one,
  range=(number*periods*number*spaces*number)/do_range,
  named=(number*spaces*name)/do_name
}
function fonts.cid.load(filename)
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
  else
    return nil
  end
end
local template="%s-%s-%s.cidmap"
local function locate(registry,ordering,supplement)
  local filename=format(template,registry,ordering,supplement)
  local hashname=lower(filename)
  local cidmap=fonts.cid.map[hashname]
  if not cidmap then
    if trace_loading then
      logs.report("load otf","checking cidmap, registry: %s, ordering: %s, supplement: %s, filename: %s",registry,ordering,supplement,filename)
    end
    local fullname=resolvers.find_file(filename,'cid') or ""
    if fullname~="" then
      cidmap=fonts.cid.load(fullname)
      if cidmap then
        if trace_loading then
          logs.report("load otf","using cidmap file %s",filename)
        end
        fonts.cid.map[hashname]=cidmap
        cidmap.usedname=file.basename(filename)
        return cidmap
      end
    end
  end
  return cidmap
end
function fonts.cid.getmap(registry,ordering,supplement)
  local supplement=tonumber(supplement)
  if trace_loading then
    logs.report("load otf","needed cidmap, registry: %s, ordering: %s, supplement: %s",registry,ordering,supplement)
  end
  local cidmap=locate(registry,ordering,supplement)
  if not cidmap then
    local cidnum=nil
    if supplement<fonts.cid.max then
      for supplement=supplement+1,fonts.cid.max do
        local c=locate(registry,ordering,supplement)
        if c then
          cidmap,cidnum=c,supplement
          break
        end
      end
    end
    if not cidmap and supplement>0 then
      for supplement=supplement-1,0,-1 do
        local c=locate(registry,ordering,supplement)
        if c then
          cidmap,cidnum=c,supplement
          break
        end
      end
    end
    if cidmap and cidnum>0 then
      for s=0,cidnum-1 do
        filename=format(template,registry,ordering,s)
        if not fonts.cid.map[filename] then
          fonts.cid.map[filename]=cidmap 
        end
      end
    end
  end
  return cidmap
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otf']={
  version=1.001,
  comment="companion to font-otf.lua (tables)",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local type,next,tonumber,tostring=type,next,tonumber,tostring
local gsub,lower=string.gsub,string.lower
fonts=fonts   or {}
fonts.otf=fonts.otf or {}
local otf=fonts.otf
otf.tables=otf.tables  or {}
otf.meanings=otf.meanings or {}
otf.tables.scripts={
  ['dflt']='Default',
  ['arab']='Arabic',
  ['armn']='Armenian',
  ['bali']='Balinese',
  ['beng']='Bengali',
  ['bopo']='Bopomofo',
  ['brai']='Braille',
  ['bugi']='Buginese',
  ['buhd']='Buhid',
  ['byzm']='Byzantine Music',
  ['cans']='Canadian Syllabics',
  ['cher']='Cherokee',
  ['copt']='Coptic',
  ['cprt']='Cypriot Syllabary',
  ['cyrl']='Cyrillic',
  ['deva']='Devanagari',
  ['dsrt']='Deseret',
  ['ethi']='Ethiopic',
  ['geor']='Georgian',
  ['glag']='Glagolitic',
  ['goth']='Gothic',
  ['grek']='Greek',
  ['gujr']='Gujarati',
  ['guru']='Gurmukhi',
  ['hang']='Hangul',
  ['hani']='CJK Ideographic',
  ['hano']='Hanunoo',
  ['hebr']='Hebrew',
  ['ital']='Old Italic',
  ['jamo']='Hangul Jamo',
  ['java']='Javanese',
  ['kana']='Hiragana and Katakana',
  ['khar']='Kharosthi',
  ['khmr']='Khmer',
  ['knda']='Kannada',
  ['lao' ]='Lao',
  ['latn']='Latin',
  ['limb']='Limbu',
  ['linb']='Linear B',
  ['math']='Mathematical Alphanumeric Symbols',
  ['mlym']='Malayalam',
  ['mong']='Mongolian',
  ['musc']='Musical Symbols',
  ['mymr']='Myanmar',
  ['nko' ]="N'ko",
  ['ogam']='Ogham',
  ['orya']='Oriya',
  ['osma']='Osmanya',
  ['phag']='Phags-pa',
  ['phnx']='Phoenician',
  ['runr']='Runic',
  ['shaw']='Shavian',
  ['sinh']='Sinhala',
  ['sylo']='Syloti Nagri',
  ['syrc']='Syriac',
  ['tagb']='Tagbanwa',
  ['tale']='Tai Le',
  ['talu']='Tai Lu',
  ['taml']='Tamil',
  ['telu']='Telugu',
  ['tfng']='Tifinagh',
  ['tglg']='Tagalog',
  ['thaa']='Thaana',
  ['thai']='Thai',
  ['tibt']='Tibetan',
  ['ugar']='Ugaritic Cuneiform',
  ['xpeo']='Old Persian Cuneiform',
  ['xsux']='Sumero-Akkadian Cuneiform',
  ['yi' ]='Yi',
}
otf.tables.languages={
  ['dflt']='Default',
  ['aba']='Abaza',
  ['abk']='Abkhazian',
  ['ady']='Adyghe',
  ['afk']='Afrikaans',
  ['afr']='Afar',
  ['agw']='Agaw',
  ['als']='Alsatian',
  ['alt']='Altai',
  ['amh']='Amharic',
  ['ara']='Arabic',
  ['ari']='Aari',
  ['ark']='Arakanese',
  ['asm']='Assamese',
  ['ath']='Athapaskan',
  ['avr']='Avar',
  ['awa']='Awadhi',
  ['aym']='Aymara',
  ['aze']='Azeri',
  ['bad']='Badaga',
  ['bag']='Baghelkhandi',
  ['bal']='Balkar',
  ['bau']='Baule',
  ['bbr']='Berber',
  ['bch']='Bench',
  ['bcr']='Bible Cree',
  ['bel']='Belarussian',
  ['bem']='Bemba',
  ['ben']='Bengali',
  ['bgr']='Bulgarian',
  ['bhi']='Bhili',
  ['bho']='Bhojpuri',
  ['bik']='Bikol',
  ['bil']='Bilen',
  ['bkf']='Blackfoot',
  ['bli']='Balochi',
  ['bln']='Balante',
  ['blt']='Balti',
  ['bmb']='Bambara',
  ['bml']='Bamileke',
  ['bos']='Bosnian',
  ['bre']='Breton',
  ['brh']='Brahui',
  ['bri']='Braj Bhasha',
  ['brm']='Burmese',
  ['bsh']='Bashkir',
  ['bti']='Beti',
  ['cat']='Catalan',
  ['ceb']='Cebuano',
  ['che']='Chechen',
  ['chg']='Chaha Gurage',
  ['chh']='Chattisgarhi',
  ['chi']='Chichewa',
  ['chk']='Chukchi',
  ['chp']='Chipewyan',
  ['chr']='Cherokee',
  ['chu']='Chuvash',
  ['cmr']='Comorian',
  ['cop']='Coptic',
  ['cos']='Corsican',
  ['cre']='Cree',
  ['crr']='Carrier',
  ['crt']='Crimean Tatar',
  ['csl']='Church Slavonic',
  ['csy']='Czech',
  ['dan']='Danish',
  ['dar']='Dargwa',
  ['dcr']='Woods Cree',
  ['deu']='German',
  ['dgr']='Dogri',
  ['div']='Divehi',
  ['djr']='Djerma',
  ['dng']='Dangme',
  ['dnk']='Dinka',
  ['dri']='Dari',
  ['dun']='Dungan',
  ['dzn']='Dzongkha',
  ['ebi']='Ebira',
  ['ecr']='Eastern Cree',
  ['edo']='Edo',
  ['efi']='Efik',
  ['ell']='Greek',
  ['eng']='English',
  ['erz']='Erzya',
  ['esp']='Spanish',
  ['eti']='Estonian',
  ['euq']='Basque',
  ['evk']='Evenki',
  ['evn']='Even',
  ['ewe']='Ewe',
  ['fan']='French Antillean',
  ['far']='Farsi',
  ['fin']='Finnish',
  ['fji']='Fijian',
  ['fle']='Flemish',
  ['fne']='Forest Nenets',
  ['fon']='Fon',
  ['fos']='Faroese',
  ['fra']='French',
  ['fri']='Frisian',
  ['frl']='Friulian',
  ['fta']='Futa',
  ['ful']='Fulani',
  ['gad']='Ga',
  ['gae']='Gaelic',
  ['gag']='Gagauz',
  ['gal']='Galician',
  ['gar']='Garshuni',
  ['gaw']='Garhwali',
  ['gez']="Ge'ez",
  ['gil']='Gilyak',
  ['gmz']='Gumuz',
  ['gon']='Gondi',
  ['grn']='Greenlandic',
  ['gro']='Garo',
  ['gua']='Guarani',
  ['guj']='Gujarati',
  ['hai']='Haitian',
  ['hal']='Halam',
  ['har']='Harauti',
  ['hau']='Hausa',
  ['haw']='Hawaiin',
  ['hbn']='Hammer-Banna',
  ['hil']='Hiligaynon',
  ['hin']='Hindi',
  ['hma']='High Mari',
  ['hnd']='Hindko',
  ['ho']='Ho',
  ['hri']='Harari',
  ['hrv']='Croatian',
  ['hun']='Hungarian',
  ['hye']='Armenian',
  ['ibo']='Igbo',
  ['ijo']='Ijo',
  ['ilo']='Ilokano',
  ['ind']='Indonesian',
  ['ing']='Ingush',
  ['inu']='Inuktitut',
  ['iri']='Irish',
  ['irt']='Irish Traditional',
  ['isl']='Icelandic',
  ['ism']='Inari Sami',
  ['ita']='Italian',
  ['iwr']='Hebrew',
  ['jan']='Japanese',
  ['jav']='Javanese',
  ['jii']='Yiddish',
  ['jud']='Judezmo',
  ['jul']='Jula',
  ['kab']='Kabardian',
  ['kac']='Kachchi',
  ['kal']='Kalenjin',
  ['kan']='Kannada',
  ['kar']='Karachay',
  ['kat']='Georgian',
  ['kaz']='Kazakh',
  ['keb']='Kebena',
  ['kge']='Khutsuri Georgian',
  ['kha']='Khakass',
  ['khk']='Khanty-Kazim',
  ['khm']='Khmer',
  ['khs']='Khanty-Shurishkar',
  ['khv']='Khanty-Vakhi',
  ['khw']='Khowar',
  ['kik']='Kikuyu',
  ['kir']='Kirghiz',
  ['kis']='Kisii',
  ['kkn']='Kokni',
  ['klm']='Kalmyk',
  ['kmb']='Kamba',
  ['kmn']='Kumaoni',
  ['kmo']='Komo',
  ['kms']='Komso',
  ['knr']='Kanuri',
  ['kod']='Kodagu',
  ['koh']='Korean Old Hangul',
  ['kok']='Konkani',
  ['kon']='Kikongo',
  ['kop']='Komi-Permyak',
  ['kor']='Korean',
  ['koz']='Komi-Zyrian',
  ['kpl']='Kpelle',
  ['kri']='Krio',
  ['krk']='Karakalpak',
  ['krl']='Karelian',
  ['krm']='Karaim',
  ['krn']='Karen',
  ['krt']='Koorete',
  ['ksh']='Kashmiri',
  ['ksi']='Khasi',
  ['ksm']='Kildin Sami',
  ['kui']='Kui',
  ['kul']='Kulvi',
  ['kum']='Kumyk',
  ['kur']='Kurdish',
  ['kuu']='Kurukh',
  ['kuy']='Kuy',
  ['kyk']='Koryak',
  ['lad']='Ladin',
  ['lah']='Lahuli',
  ['lak']='Lak',
  ['lam']='Lambani',
  ['lao']='Lao',
  ['lat']='Latin',
  ['laz']='Laz',
  ['lcr']='L-Cree',
  ['ldk']='Ladakhi',
  ['lez']='Lezgi',
  ['lin']='Lingala',
  ['lma']='Low Mari',
  ['lmb']='Limbu',
  ['lmw']='Lomwe',
  ['lsb']='Lower Sorbian',
  ['lsm']='Lule Sami',
  ['lth']='Lithuanian',
  ['ltz']='Luxembourgish',
  ['lub']='Luba',
  ['lug']='Luganda',
  ['luh']='Luhya',
  ['luo']='Luo',
  ['lvi']='Latvian',
  ['maj']='Majang',
  ['mak']='Makua',
  ['mal']='Malayalam Traditional',
  ['man']='Mansi',
  ['map']='Mapudungun',
  ['mar']='Marathi',
  ['maw']='Marwari',
  ['mbn']='Mbundu',
  ['mch']='Manchu',
  ['mcr']='Moose Cree',
  ['mde']='Mende',
  ['men']="Me'en",
  ['miz']='Mizo',
  ['mkd']='Macedonian',
  ['mle']='Male',
  ['mlg']='Malagasy',
  ['mln']='Malinke',
  ['mlr']='Malayalam Reformed',
  ['mly']='Malay',
  ['mnd']='Mandinka',
  ['mng']='Mongolian',
  ['mni']='Manipuri',
  ['mnk']='Maninka',
  ['mnx']='Manx Gaelic',
  ['moh']='Mohawk',
  ['mok']='Moksha',
  ['mol']='Moldavian',
  ['mon']='Mon',
  ['mor']='Moroccan',
  ['mri']='Maori',
  ['mth']='Maithili',
  ['mts']='Maltese',
  ['mun']='Mundari',
  ['nag']='Naga-Assamese',
  ['nan']='Nanai',
  ['nas']='Naskapi',
  ['ncr']='N-Cree',
  ['ndb']='Ndebele',
  ['ndg']='Ndonga',
  ['nep']='Nepali',
  ['new']='Newari',
  ['ngr']='Nagari',
  ['nhc']='Norway House Cree',
  ['nis']='Nisi',
  ['niu']='Niuean',
  ['nkl']='Nkole',
  ['nko']="N'ko",
  ['nld']='Dutch',
  ['nog']='Nogai',
  ['nor']='Norwegian',
  ['nsm']='Northern Sami',
  ['nta']='Northern Tai',
  ['nto']='Esperanto',
  ['nyn']='Nynorsk',
  ['oci']='Occitan',
  ['ocr']='Oji-Cree',
  ['ojb']='Ojibway',
  ['ori']='Oriya',
  ['oro']='Oromo',
  ['oss']='Ossetian',
  ['paa']='Palestinian Aramaic',
  ['pal']='Pali',
  ['pan']='Punjabi',
  ['pap']='Palpa',
  ['pas']='Pashto',
  ['pgr']='Polytonic Greek',
  ['pil']='Pilipino',
  ['plg']='Palaung',
  ['plk']='Polish',
  ['pro']='Provencal',
  ['ptg']='Portuguese',
  ['qin']='Chin',
  ['raj']='Rajasthani',
  ['rbu']='Russian Buriat',
  ['rcr']='R-Cree',
  ['ria']='Riang',
  ['rms']='Rhaeto-Romanic',
  ['rom']='Romanian',
  ['roy']='Romany',
  ['rsy']='Rusyn',
  ['rua']='Ruanda',
  ['rus']='Russian',
  ['sad']='Sadri',
  ['san']='Sanskrit',
  ['sat']='Santali',
  ['say']='Sayisi',
  ['sek']='Sekota',
  ['sel']='Selkup',
  ['sgo']='Sango',
  ['shn']='Shan',
  ['sib']='Sibe',
  ['sid']='Sidamo',
  ['sig']='Silte Gurage',
  ['sks']='Skolt Sami',
  ['sky']='Slovak',
  ['sla']='Slavey',
  ['slv']='Slovenian',
  ['sml']='Somali',
  ['smo']='Samoan',
  ['sna']='Sena',
  ['snd']='Sindhi',
  ['snh']='Sinhalese',
  ['snk']='Soninke',
  ['sog']='Sodo Gurage',
  ['sot']='Sotho',
  ['sqi']='Albanian',
  ['srb']='Serbian',
  ['srk']='Saraiki',
  ['srr']='Serer',
  ['ssl']='South Slavey',
  ['ssm']='Southern Sami',
  ['sur']='Suri',
  ['sva']='Svan',
  ['sve']='Swedish',
  ['swa']='Swadaya Aramaic',
  ['swk']='Swahili',
  ['swz']='Swazi',
  ['sxt']='Sutu',
  ['syr']='Syriac',
  ['tab']='Tabasaran',
  ['taj']='Tajiki',
  ['tam']='Tamil',
  ['tat']='Tatar',
  ['tcr']='TH-Cree',
  ['tel']='Telugu',
  ['tgn']='Tongan',
  ['tgr']='Tigre',
  ['tgy']='Tigrinya',
  ['tha']='Thai',
  ['tht']='Tahitian',
  ['tib']='Tibetan',
  ['tkm']='Turkmen',
  ['tmn']='Temne',
  ['tna']='Tswana',
  ['tne']='Tundra Nenets',
  ['tng']='Tonga',
  ['tod']='Todo',
  ['trk']='Turkish',
  ['tsg']='Tsonga',
  ['tua']='Turoyo Aramaic',
  ['tul']='Tulu',
  ['tuv']='Tuvin',
  ['twi']='Twi',
  ['udm']='Udmurt',
  ['ukr']='Ukrainian',
  ['urd']='Urdu',
  ['usb']='Upper Sorbian',
  ['uyg']='Uyghur',
  ['uzb']='Uzbek',
  ['ven']='Venda',
  ['vit']='Vietnamese',
  ['wa' ]='Wa',
  ['wag']='Wagdi',
  ['wcr']='West-Cree',
  ['wel']='Welsh',
  ['wlf']='Wolof',
  ['xbd']='Tai Lue',
  ['xhs']='Xhosa',
  ['yak']='Yakut',
  ['yba']='Yoruba',
  ['ycr']='Y-Cree',
  ['yic']='Yi Classic',
  ['yim']='Yi Modern',
  ['zhh']='Chinese Hong Kong',
  ['zhp']='Chinese Phonetic',
  ['zhs']='Chinese Simplified',
  ['zht']='Chinese Traditional',
  ['znd']='Zande',
  ['zul']='Zulu'
}
otf.tables.features={
  ['aalt']='Access All Alternates',
  ['abvf']='Above-Base Forms',
  ['abvm']='Above-Base Mark Positioning',
  ['abvs']='Above-Base Substitutions',
  ['afrc']='Alternative Fractions',
  ['akhn']='Akhands',
  ['blwf']='Below-Base Forms',
  ['blwm']='Below-Base Mark Positioning',
  ['blws']='Below-Base Substitutions',
  ['c2pc']='Petite Capitals From Capitals',
  ['c2sc']='Small Capitals From Capitals',
  ['calt']='Contextual Alternates',
  ['case']='Case-Sensitive Forms',
  ['ccmp']='Glyph Composition/Decomposition',
  ['cjct']='Conjunct Forms',
  ['clig']='Contextual Ligatures',
  ['cpsp']='Capital Spacing',
  ['cswh']='Contextual Swash',
  ['curs']='Cursive Positioning',
  ['dflt']='Default Processing',
  ['dist']='Distances',
  ['dlig']='Discretionary Ligatures',
  ['dnom']='Denominators',
  ['dtls']='Dotless Forms',
  ['expt']='Expert Forms',
  ['falt']='Final glyph Alternates',
  ['fin2']='Terminal Forms #2',
  ['fin3']='Terminal Forms #3',
  ['fina']='Terminal Forms',
  ['flac']='Flattened Accents Over Capitals',
  ['frac']='Fractions',
  ['fwid']='Full Width',
  ['half']='Half Forms',
  ['haln']='Halant Forms',
  ['halt']='Alternate Half Width',
  ['hist']='Historical Forms',
  ['hkna']='Horizontal Kana Alternates',
  ['hlig']='Historical Ligatures',
  ['hngl']='Hangul',
  ['hojo']='Hojo Kanji Forms',
  ['hwid']='Half Width',
  ['init']='Initial Forms',
  ['isol']='Isolated Forms',
  ['ital']='Italics',
  ['jalt']='Justification Alternatives',
  ['jp04']='JIS2004 Forms',
  ['jp78']='JIS78 Forms',
  ['jp83']='JIS83 Forms',
  ['jp90']='JIS90 Forms',
  ['kern']='Kerning',
  ['lfbd']='Left Bounds',
  ['liga']='Standard Ligatures',
  ['ljmo']='Leading Jamo Forms',
  ['lnum']='Lining Figures',
  ['locl']='Localized Forms',
  ['mark']='Mark Positioning',
  ['med2']='Medial Forms #2',
  ['medi']='Medial Forms',
  ['mgrk']='Mathematical Greek',
  ['mkmk']='Mark to Mark Positioning',
  ['mset']='Mark Positioning via Substitution',
  ['nalt']='Alternate Annotation Forms',
  ['nlck']='NLC Kanji Forms',
  ['nukt']='Nukta Forms',
  ['numr']='Numerators',
  ['onum']='Old Style Figures',
  ['opbd']='Optical Bounds',
  ['ordn']='Ordinals',
  ['ornm']='Ornaments',
  ['palt']='Proportional Alternate Width',
  ['pcap']='Petite Capitals',
  ['pnum']='Proportional Figures',
  ['pref']='Pre-base Forms',
  ['pres']='Pre-base Substitutions',
  ['pstf']='Post-base Forms',
  ['psts']='Post-base Substitutions',
  ['pwid']='Proportional Widths',
  ['qwid']='Quarter Widths',
  ['rand']='Randomize',
  ['rkrf']='Rakar Forms',
  ['rlig']='Required Ligatures',
  ['rphf']='Reph Form',
  ['rtbd']='Right Bounds',
  ['rtla']='Right-To-Left Alternates',
  ['rtlm']='Right To Left Math',
  ['ruby']='Ruby Notation Forms',
  ['salt']='Stylistic Alternates',
  ['sinf']='Scientific Inferiors',
  ['size']='Optical Size',
  ['smcp']='Small Capitals',
  ['smpl']='Simplified Forms',
  ['ss01']='Stylistic Set 1',
  ['ss02']='Stylistic Set 2',
  ['ss03']='Stylistic Set 3',
  ['ss04']='Stylistic Set 4',
  ['ss05']='Stylistic Set 5',
  ['ss06']='Stylistic Set 6',
  ['ss07']='Stylistic Set 7',
  ['ss08']='Stylistic Set 8',
  ['ss09']='Stylistic Set 9',
  ['ss10']='Stylistic Set 10',
  ['ss11']='Stylistic Set 11',
  ['ss12']='Stylistic Set 12',
  ['ss13']='Stylistic Set 13',
  ['ss14']='Stylistic Set 14',
  ['ss15']='Stylistic Set 15',
  ['ss16']='Stylistic Set 16',
  ['ss17']='Stylistic Set 17',
  ['ss18']='Stylistic Set 18',
  ['ss19']='Stylistic Set 19',
  ['ss20']='Stylistic Set 20',
  ['ssty']='Script Style',
  ['subs']='Subscript',
  ['sups']='Superscript',
  ['swsh']='Swash',
  ['titl']='Titling',
  ['tjmo']='Trailing Jamo Forms',
  ['tnam']='Traditional Name Forms',
  ['tnum']='Tabular Figures',
  ['trad']='Traditional Forms',
  ['twid']='Third Widths',
  ['unic']='Unicase',
  ['valt']='Alternate Vertical Metrics',
  ['vatu']='Vattu Variants',
  ['vert']='Vertical Writing',
  ['vhal']='Alternate Vertical Half Metrics',
  ['vjmo']='Vowel Jamo Forms',
  ['vkna']='Vertical Kana Alternates',
  ['vkrn']='Vertical Kerning',
  ['vpal']='Proportional Alternate Vertical Metrics',
  ['vrt2']='Vertical Rotation',
  ['zero']='Slashed Zero',
  ['trep']='Traditional TeX Replacements',
  ['tlig']='Traditional TeX Ligatures',
}
otf.tables.baselines={
  ['hang']='Hanging baseline',
  ['icfb']='Ideographic character face bottom edge baseline',
  ['icft']='Ideographic character face tope edige baseline',
  ['ideo']='Ideographic em-box bottom edge baseline',
  ['idtp']='Ideographic em-box top edge baseline',
  ['math']='Mathmatical centered baseline',
  ['romn']='Roman baseline'
}
function otf.tables.to_tag(id)
  return stringformat("%4s",lower(id))
end
local function resolve(tab,id)
  if tab and id then
    id=lower(id)
    return tab[id] or tab[gsub(id," ","")] or tab['dflt'] or ''
  else
    return "unknown"
  end
end
function otf.meanings.script(id)
  return resolve(otf.tables.scripts,id)
end
function otf.meanings.language(id)
  return resolve(otf.tables.languages,id)
end
function otf.meanings.feature(id)
  return resolve(otf.tables.features,id)
end
function otf.meanings.baseline(id)
  return resolve(otf.tables.baselines,id)
end
otf.tables.to_scripts=table.reverse_hash(otf.tables.scripts )
otf.tables.to_languages=table.reverse_hash(otf.tables.languages)
otf.tables.to_features=table.reverse_hash(otf.tables.features )
local scripts=otf.tables.scripts
local languages=otf.tables.languages
local features=otf.tables.features
local to_scripts=otf.tables.to_scripts
local to_languages=otf.tables.to_languages
local to_features=otf.tables.to_features
for k,v in next,to_features do
  local stripped=gsub(k,"%-"," ")
  to_features[stripped]=v
  local stripped=gsub(k,"[^a-zA-Z0-9]","")
  to_features[stripped]=v
end
for k,v in next,to_features do
  to_features[lower(k)]=v
end
otf.meanings.checkers={
  rand=function(v)
    return v and "random"
  end
}
local checkers=otf.meanings.checkers
function otf.meanings.normalize(features)
  local h={}
  for k,v in next,features do
    k=lower(k)
    if k=="language" or k=="lang" then
      v=gsub(lower(v),"[^a-z0-9%-]","")
      if not languages[v] then
        h.language=to_languages[v] or "dflt"
      else
        h.language=v
      end
    elseif k=="script" then
      v=gsub(lower(v),"[^a-z0-9%-]","")
      if not scripts[v] then
        h.script=to_scripts[v] or "dflt"
      else
        h.script=v
      end
    else
      if type(v)=="string" then
        local b=v:is_boolean()
        if type(b)=="nil" then
          v=tonumber(v) or lower(v)
        else
          v=b
        end
      end
      k=to_features[k] or k
      local c=checkers[k]
      h[k]=c and c(v) or v
    end
  end
  return h
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
local utf=unicode.utf8
local match,format,find,concat,gsub,lower=string.match,string.format,string.find,table.concat,string.gsub,string.lower
local lpegmatch=lpeg.match
local utfbyte=utf.byte
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
local trace_unimapping=false trackers.register("otf.unimapping",function(v) trace_unimapping=v end)
local ctxcatcodes=tex and tex.ctxcatcodes
fonts=fonts   or {}
fonts.map=fonts.map or {}
local function load_lum_table(filename) 
  local lumname=file.replacesuffix(file.basename(filename),"lum")
  local lumfile=resolvers.find_file(lumname,"map") or ""
  if lumfile~="" and lfs.isfile(lumfile) then
    if trace_loading or trace_unimapping then
      logs.report("load otf","enhance: loading %s ",lumfile)
    end
    lumunic=dofile(lumfile)
    return lumunic,lumfile
  end
end
local hex=lpeg.R("AF","09")
local hexfour=(hex*hex*hex*hex)/function(s) return tonumber(s,16) end
local hexsix=(hex^1)/function(s) return tonumber(s,16) end
local dec=(lpeg.R("09")^1)/tonumber
local period=lpeg.P(".")
local unicode=lpeg.P("uni")*(hexfour*(period+lpeg.P(-1))*lpeg.Cc(false)+lpeg.Ct(hexfour^1)*lpeg.Cc(true))
local ucode=lpeg.P("u")*(hexsix*(period+lpeg.P(-1))*lpeg.Cc(false)+lpeg.Ct(hexsix^1)*lpeg.Cc(true))
local index=lpeg.P("index")*dec*lpeg.Cc(false)
local parser=unicode+ucode+index
local parsers={}
local function make_name_parser(str)
  if not str or str=="" then
    return parser
  else
    local p=parsers[str]
    if not p then
      p=lpeg.P(str)*period*dec*lpeg.Cc(false)
      parsers[str]=p
    end
    return p
  end
end
local function tounicode16(unicode)
  if unicode<0x10000 then
    return format("%04X",unicode)
  else
    return format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
  end
end
local function tounicode16sequence(unicodes)
  local t={}
  for l=1,#unicodes do
    local unicode=unicodes[l]
    if unicode<0x10000 then
      t[l]=format("%04X",unicode)
    else
      t[l]=format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
    end
  end
  return concat(t)
end
fonts.map.load_lum_table=load_lum_table
fonts.map.make_name_parser=make_name_parser
fonts.map.tounicode16=tounicode16
fonts.map.tounicode16sequence=tounicode16sequence
local separator=lpeg.S("_.")
local other=lpeg.C((1-separator)^1)
local ligsplitter=lpeg.Ct(other*(separator*other)^0)
fonts.map.add_to_unicode=function(data,filename)
  local unicodes=data.luatex and data.luatex.unicodes
  if not unicodes then
    return
  end
  unicodes['space']=unicodes['space'] or 32
  unicodes['hyphen']=unicodes['hyphen'] or 45
  unicodes['zwj']=unicodes['zwj']  or 0x200D
  unicodes['zwnj']=unicodes['zwnj']  or 0x200C
  local tounicode,originals,ns,nl,private,unknown={},{},0,0,fonts.private,format("%04X",utfbyte("?"))
  data.luatex.tounicode,data.luatex.originals=tounicode,originals
  local lumunic,uparser,oparser
  if false then 
    lumunic=load_lum_table(filename)
    lumunic=lumunic and lumunic.tounicode
  end
  local cidinfo,cidnames,cidcodes=data.cidinfo
  local usedmap=cidinfo and cidinfo.usedname
  usedmap=usedmap and lower(usedmap)
  usedmap=usedmap and fonts.cid.map[usedmap]
  if usedmap then
    oparser=usedmap and make_name_parser(cidinfo.ordering)
    cidnames=usedmap.names
    cidcodes=usedmap.unicodes
  end
  uparser=make_name_parser()
  local aglmap=fonts.map and fonts.map.agl_to_unicode
  for index,glyph in next,data.glyphs do
    local name,unic=glyph.name,glyph.unicode or -1 
    if unic==-1 or unic>=private or (unic>=0xE000 and unic<=0xF8FF) or unic==0xFFFE or unic==0xFFFF then
      local unicode=(lumunic and lumunic[name]) or (aglmap and aglmap[name])
      if unicode then
        originals[index],tounicode[index],ns=unicode,tounicode16(unicode),ns+1
      end
      if (not unicode) and usedmap then
        local foundindex=lpegmatch(oparser,name)
        if foundindex then
          unicode=cidcodes[foundindex] 
          if unicode then
            originals[index],tounicode[index],ns=unicode,tounicode16(unicode),ns+1
          else
            local reference=cidnames[foundindex] 
            if reference then
              local foundindex=lpegmatch(oparser,reference)
              if foundindex then
                unicode=cidcodes[foundindex]
                if unicode then
                  originals[index],tounicode[index],ns=unicode,tounicode16(unicode),ns+1
                end
              end
              if not unicode then
                local foundcodes,multiple=lpegmatch(uparser,reference)
                if foundcodes then
                  if multiple then
                    originals[index],tounicode[index],nl,unicode=foundcodes,tounicode16sequence(foundcodes),nl+1,true
                  else
                    originals[index],tounicode[index],ns,unicode=foundcodes,tounicode16(foundcodes),ns+1,foundcodes
                  end
                end
              end
            end
          end
        end
      end
      if not unicode then
        local split=lpegmatch(ligsplitter,name)
        local nplit=(split and #split) or 0
        if nplit==0 then
        elseif nplit==1 then
          local base=split[1]
          unicode=unicodes[base] or (aglmap and aglmap[base])
          if unicode then
            if type(unicode)=="table" then
              unicode=unicode[1]
            end
            originals[index],tounicode[index],ns=unicode,tounicode16(unicode),ns+1
          end
        else
          local t={}
          for l=1,nplit do
            local base=split[l]
            local u=unicodes[base] or (aglmap and aglmap[base])
            if not u then
              break
            elseif type(u)=="table" then
              t[#t+1]=u[1]
            else
              t[#t+1]=u
            end
          end
          if #t>0 then 
            originals[index],tounicode[index],nl,unicode=t,tounicode16sequence(t),nl+1,true
          end
        end
      end
      if not unicode then
        local foundcodes,multiple=lpegmatch(uparser,name)
        if foundcodes then
          if multiple then
            originals[index],tounicode[index],nl,unicode=foundcodes,tounicode16sequence(foundcodes),nl+1,true
          else
            originals[index],tounicode[index],ns,unicode=foundcodes,tounicode16(foundcodes),ns+1,foundcodes
          end
        end
      end
      if not unicode then
        originals[index],tounicode[index]=0xFFFD,"FFFD"
      end
    end
  end
  if trace_unimapping then
    for index,glyph in table.sortedhash(data.glyphs) do
      local toun,name,unic=tounicode[index],glyph.name,glyph.unicode or -1 
      if toun then
        logs.report("load otf","internal: 0x%05X, name: %s, unicode: 0x%05X, tounicode: %s",index,name,unic,toun)
      else
        logs.report("load otf","internal: 0x%05X, name: %s, unicode: 0x%05X",index,name,unic)
      end
    end
  end
  if trace_loading and (ns>0 or nl>0) then
    logs.report("load otf","enhance: %s tounicode entries added (%s ligatures)",nl+ns,ns)
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otf']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local utf=unicode.utf8
local concat,utfbyte=table.concat,utf.byte
local format,gmatch,gsub,find,match,lower,strip=string.format,string.gmatch,string.gsub,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring=type,next,tonumber,tostring
local abs=math.abs
local getn=table.getn
local lpegmatch=lpeg.match
local trace_private=false trackers.register("otf.private",function(v) trace_private=v end)
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
local trace_features=false trackers.register("otf.features",function(v) trace_features=v end)
local trace_dynamics=false trackers.register("otf.dynamics",function(v) trace_dynamics=v end)
local trace_sequences=false trackers.register("otf.sequences",function(v) trace_sequences=v end)
local trace_math=false trackers.register("otf.math",function(v) trace_math=v end)
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
fonts=fonts   or {}
fonts.otf=fonts.otf or {}
fonts.tfm=fonts.tfm or {}
local otf=fonts.otf
local tfm=fonts.tfm
local fontdata=fonts.ids
otf.tables=otf.tables      or {} 
otf.meanings=otf.meanings     or {} 
otf.tables.features=otf.tables.features or {} 
otf.tables.languages=otf.tables.languages or {} 
otf.tables.scripts=otf.tables.scripts  or {} 
otf.features=otf.features     or {}
otf.features.list=otf.features.list  or {}
otf.features.default=otf.features.default or {}
otf.enhancers=otf.enhancers    or {}
otf.glists={ "gsub","gpos" }
otf.version=2.653 
otf.pack=true 
otf.syncspace=true
otf.notdef=false
otf.cache=containers.define("fonts","otf",otf.version,true)
otf.cleanup_aat=false 
local wildcard="*"
local default="dflt"
otf.tables.global_fields=table.tohash {
  "lookups",
  "glyphs",
  "subfonts",
  "luatex",
  "pfminfo",
  "cidinfo",
  "tables",
  "names",
  "unicodes",
  "names",
  "anchor_classes",
  "kern_classes",
  "gpos",
  "gsub"
}
otf.tables.valid_fields={
  "anchor_classes",
  "ascent",
  "cache_version",
  "cidinfo",
  "copyright",
  "creationtime",
  "descent",
  "design_range_bottom",
  "design_range_top",
  "design_size",
  "encodingchanged",
  "extrema_bound",
  "familyname",
  "fontname",
  "fontstyle_id",
  "fontstyle_name",
  "fullname",
  "glyphs",
  "hasvmetrics",
  "head_optimized_for_cleartype",
  "horiz_base",
  "issans",
  "isserif",
  "italicangle",
  "kerns",
  "lookups",
  "macstyle",
  "modificationtime",
  "onlybitmaps",
  "origname",
  "os2_version",
  "pfminfo",
  "private",
  "serifcheck",
  "sfd_version",
  "strokedfont",
  "strokewidth",
  "subfonts",
  "table_version",
  "ttf_tables",
  "uni_interp",
  "uniqueid",
  "units_per_em",
  "upos",
  "use_typo_metrics",
  "uwidth",
  "validation_state",
  "verbose",
  "version",
  "vert_base",
  "weight",
  "weight_width_slope_only",
  "xuid",
}
local function load_featurefile(ff,featurefile)
  if featurefile then
    featurefile=resolvers.find_file(file.addsuffix(featurefile,'fea'),'fea')
    if featurefile and featurefile~="" then
      if trace_loading then
        logs.report("load otf","featurefile: %s",featurefile)
      end
      fontloader.apply_featurefile(ff,featurefile)
    end
  end
end
function otf.enhance(name,data,filename,verbose)
  local enhancer=otf.enhancers[name]
  if enhancer then
    if (verbose~=nil and verbose) or trace_loading then
      logs.report("load otf","enhance: %s (%s)",name,filename)
    end
    enhancer(data,filename)
  end
end
local enhancers={
  "patch bugs",
  "merge cid fonts","prepare unicode","cleanup ttf tables","compact glyphs","reverse coverage",
  "cleanup aat","enrich with features","add some missing characters",
  "reorganize mark classes",
  "reorganize kerns",
  "flatten glyph lookups","flatten anchor tables","flatten feature tables",
  "simplify glyph lookups",
  "prepare luatex tables",
  "analyse features","rehash features",
  "analyse anchors","analyse marks","analyse unicodes","analyse subtables",
  "check italic correction","check math",
  "share widths",
  "strip not needed data",
  "migrate metadata",
  "check math parameters",
}
function otf.load(filename,format,sub,featurefile)
  local name=file.basename(file.removesuffix(filename))
  local attr=lfs.attributes(filename)
  local size,time=attr.size or 0,attr.modification or 0
  if featurefile then
    local fattr=lfs.attributes(featurefile)
    local fsize,ftime=fattr and fattr.size or 0,fattr and fattr.modification or 0
    name=name.."@"..file.removesuffix(file.basename(featurefile))..ftime..fsize
  end
  if sub=="" then sub=false end
  local hash=name
  if sub then
    hash=hash.."-"..sub
  end
  hash=containers.cleanname(hash)
  local data=containers.read(otf.cache,hash)
  if not data or data.verbose~=fonts.verbose or data.size~=size or data.time~=time then
    logs.report("load otf","loading: %s (hash: %s)",filename,hash)
    local ff,messages
    if sub then
      ff,messages=fontloader.open(filename,sub)
    else
      ff,messages=fontloader.open(filename)
    end
    if trace_loading and messages and #messages>0 then
      if type(messages)=="string" then
        logs.report("load otf","warning: %s",messages)
      else
        for m=1,#messages do
          logs.report("load otf","warning: %s",tostring(messages[m]))
        end
      end
    else
      logs.report("load otf","font loaded okay")
    end
    if ff then
      load_featurefile(ff,featurefile)
      data=fontloader.to_table(ff)
      fontloader.close(ff)
      if data then
        logs.report("load otf","file size: %s",size)
        logs.report("load otf","enhancing ...")
        for e=1,#enhancers do
          otf.enhance(enhancers[e],data,filename)
          io.flush() 
        end
        if otf.pack and not fonts.verbose then
          otf.enhance("pack",data,filename)
        end
        data.size=size
        data.time=time
        data.verbose=fonts.verbose
        logs.report("load otf","saving in cache: %s",filename)
        data=containers.write(otf.cache,hash,data)
        collectgarbage("collect")
        data=containers.read(otf.cache,hash) 
        collectgarbage("collect")
      else
        logs.report("load otf","loading failed (table conversion error)")
      end
    else
      logs.report("load otf","loading failed (file read error)")
    end
  end
  if data then
    if trace_defining then
      logs.report("define font","loading from cache: %s",hash)
    end
    otf.enhance("unpack",data,filename,false) 
    otf.add_dimensions(data)
    if trace_sequences then
      otf.show_feature_order(data,filename)
    end
  end
  return data
end
function otf.add_dimensions(data)
  if data then
    local force=otf.notdef
    local luatex=data.luatex
    local defaultwidth=luatex.defaultwidth or 0
    local defaultheight=luatex.defaultheight or 0
    local defaultdepth=luatex.defaultdepth or 0
    for _,d in next,data.glyphs do
      local bb,wd=d.boundingbox,d.width
      if not wd then
        d.width=defaultwidth
      elseif wd~=0 and d.class=="mark" then
        d.width=-wd
      end
      if force and not d.name then
        d.name=".notdef"
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
function otf.show_feature_order(otfdata,filename)
  local sequences=otfdata.luatex.sequences
  if sequences and #sequences>0 then
    if trace_loading then
      logs.report("otf check","font %s has %s sequences",filename,#sequences)
      logs.report("otf check"," ")
    end
    for nos=1,#sequences do
      local sequence=sequences[nos]
      local typ=sequence.type or "no-type"
      local name=sequence.name or "no-name"
      local subtables=sequence.subtables or { "no-subtables" }
      local features=sequence.features
      if trace_loading then
        logs.report("otf check","%3i  %-15s  %-20s  [%s]",nos,name,typ,concat(subtables,","))
      end
      if features then
        for feature,scripts in next,features do
          local tt={}
          for script,languages in next,scripts do
            local ttt={}
            for language,_ in next,languages do
              ttt[#ttt+1]=language
            end
            tt[#tt+1]=format("[%s: %s]",script,concat(ttt," "))
          end
          if trace_loading then
            logs.report("otf check","       %s: %s",feature,concat(tt," "))
          end
        end
      end
    end
    if trace_loading then
      logs.report("otf check","\n")
    end
  elseif trace_loading then
    logs.report("otf check","font %s has no sequences",filename)
  end
end
otf.enhancers["reorganize mark classes"]=function(data,filename)
  if data.mark_classes then
    local unicodes=data.luatex.unicodes
    local reverse={}
    for name,class in next,data.mark_classes do
      local t={}
      for s in gmatch(class,"[^ ]+") do
        local us=unicodes[s]
        if type(us)=="table" then
          for u=1,#us do
            t[us[u]]=true
          end
        else
          t[us]=true
        end
      end
      reverse[name]=t
    end
    data.luatex.markclasses=reverse
    data.mark_classes=nil
  end
end
otf.enhancers["prepare luatex tables"]=function(data,filename)
  data.luatex=data.luatex or {}
  local luatex=data.luatex
  luatex.filename=filename
  luatex.version=otf.version
  luatex.creator="context mkiv"
end
otf.enhancers["cleanup aat"]=function(data,filename)
  if otf.cleanup_aat then
  end
end
local function analyze_features(g,features)
  if g then
    local t,done={},{}
    for k=1,#g do
      local f=features or g[k].features
      if f then
        for k=1,#f do
          local tag=f[k].tag
          if not done[tag] then
            t[#t+1]=tag
            done[tag]=true
          end
        end
      end
    end
    if #t>0 then
      return t
    end
  end
  return nil
end
otf.enhancers["analyse features"]=function(data,filename)
end
otf.enhancers["rehash features"]=function(data,filename)
  local features={}
  data.luatex.features=features
  for k,what in next,otf.glists do
    local dw=data[what]
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
            local ft=f[tag] if not ft then ft={} f[tag]=ft end
            local dscripts=df.scripts
            for script,languages in next,dscripts do
              script=strip(lower(script))
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
otf.enhancers["analyse anchors"]=function(data,filename)
  local classes=data.anchor_classes
  local luatex=data.luatex
  local anchor_to_lookup,lookup_to_anchor={},{}
  luatex.anchor_to_lookup,luatex.lookup_to_anchor=anchor_to_lookup,lookup_to_anchor
  if classes then
    for c=1,#classes do
      local class=classes[c]
      local anchor=class.name
      local lookups=class.lookup
      if type(lookups)~="table" then
        lookups={ lookups }
      end
      local a=anchor_to_lookup[anchor]
      if not a then a={} anchor_to_lookup[anchor]=a end
      for l=1,#lookups do
        local lookup=lookups[l]
        local l=lookup_to_anchor[lookup]
        if not l then l={} lookup_to_anchor[lookup]=l end
        l[anchor]=true
        a[lookup]=true
      end
    end
  end
end
otf.enhancers["analyse marks"]=function(data,filename)
  local glyphs=data.glyphs
  local marks={}
  data.luatex.marks=marks
  for unicode,index in next,data.luatex.indices do
    local glyph=glyphs[index]
    if glyph.class=="mark" then
      marks[unicode]=true
    end
  end
end
otf.enhancers["analyse unicodes"]=fonts.map.add_to_unicode
otf.enhancers["analyse subtables"]=function(data,filename)
  data.luatex=data.luatex or {}
  local luatex=data.luatex
  local sequences={}
  local lookups={}
  luatex.sequences=sequences
  luatex.lookups=lookups
  for _,g in next,{ data.gsub,data.gpos } do
    for k=1,#g do
      local gk=g[k]
      local typ=gk.type
      if typ=="gsub_contextchain" or typ=="gpos_contextchain" then
        gk.chain=1
      elseif typ=="gsub_reversecontextchain" or typ=="gpos_reversecontextchain" then
        gk.chain=-1
      else
        gk.chain=0
      end
      local features=gk.features
      if features then
        sequences[#sequences+1]=gk
        local t={}
        for f=1,#features do
          local feature=features[f]
          local hash={}
          for s,languages in next,feature.scripts do
            s=lower(s)
            local h=hash[s]
            if not h then h={} hash[s]=h end
            for l=1,#languages do
              h[strip(lower(languages[l]))]=true
            end
          end
          t[feature.tag]=hash
        end
        gk.features=t
      else
        lookups[gk.name]=gk
        gk.name=nil
      end
      local subtables=gk.subtables
      if subtables then
        local t={}
        for s=1,#subtables do
          local subtable=subtables[s]
          local name=subtable.name
          t[#t+1]=name
        end
        gk.subtables=t
      end
      local flags=gk.flags
      if flags then
        gk.flags={ 
          (flags.ignorecombiningmarks and "mark")   or false,
          (flags.ignoreligatures   and "ligature") or false,
          (flags.ignorebaseglyphs   and "base")   or false,
           flags.r2l                 or false,
        }
        if flags.mark_class then
          gk.markclass=luatex.markclasses[flags.mark_class]
        end
      end
    end
  end
end
otf.enhancers["merge cid fonts"]=function(data,filename)
  if data.subfonts then
    if data.glyphs and next(data.glyphs) then
      logs.report("load otf","replacing existing glyph table due to subfonts")
    end
    local cidinfo=data.cidinfo
    local verbose=fonts.verbose
    if cidinfo.registry then
      local cidmap,cidname=fonts.cid.getmap(cidinfo.registry,cidinfo.ordering,cidinfo.supplement)
      if cidmap then
        cidinfo.usedname=cidmap.usedname
        local glyphs,uni_to_int,int_to_uni,nofnames,nofunicodes={},{},{},0,0
        local unicodes,names=cidmap.unicodes,cidmap.names
        for n,subfont in next,data.subfonts do
          for index,g in next,subfont.glyphs do
            if not next(g) then
            else
              local unicode,name=unicodes[index],names[index]
              g.cidindex=n
              g.boundingbox=g.boundingbox 
              g.name=g.name or name or "unknown"
              if unicode then
                uni_to_int[unicode]=index
                int_to_uni[index]=unicode
                nofunicodes=nofunicodes+1
                g.unicode=unicode
              elseif name then
                nofnames=nofnames+1
                g.unicode=-1
              end
              glyphs[index]=g
            end
          end
          subfont.glyphs=nil
        end
        if trace_loading then
          logs.report("load otf","cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes,nofnames,nofunicodes+nofnames)
        end
        data.glyphs=glyphs
        data.map=data.map or {}
        data.map.map=uni_to_int
        data.map.backmap=int_to_uni
      elseif trace_loading then
        logs.report("load otf","unable to remap cid font, missing cid file for %s",filename)
      end
    elseif trace_loading then
      logs.report("load otf","font %s has no glyphs",filename)
    end
  end
end
otf.enhancers["prepare unicode"]=function(data,filename)
  local luatex=data.luatex
  if not luatex then luatex={} data.luatex=luatex end
  local indices,unicodes,multiples,internals={},{},{},{}
  local glyphs=data.glyphs
  local mapmap=data.map
  if not mapmap then
    logs.report("load otf","no map in %s",filename)
    mapmap={}
    data.map={ map=mapmap }
  elseif not mapmap.map then
    logs.report("load otf","no unicode map in %s",filename)
    mapmap={}
    data.map.map=mapmap
  else
    mapmap=mapmap.map
  end
  local criterium=fonts.private
  local private=fonts.private
  for index,glyph in next,glyphs do
    if index>0 then
      local name=glyph.name
      if name then
        local unicode=glyph.unicode
        if unicode==-1 or unicode>=criterium then
          glyph.unicode=private
          indices[private]=index
          unicodes[name]=private
          internals[index]=true
          if trace_private then
            logs.report("load otf","enhance: glyph %s at index U+%04X is moved to private unicode slot U+%04X",name,index,private)
          end
          private=private+1
        else
          indices[unicode]=index
          unicodes[name]=unicode
        end
      end
    end
  end
  for unicode,index in next,mapmap do
    if not internals[index] then
      local name=glyphs[index].name
      if name then
        local un=unicodes[name]
        if not un then
          unicodes[name]=unicode 
        elseif type(un)=="number" then
          if un~=unicode then
            multiples[#multiples+1]=name
            unicodes[name]={ un,unicode }
            indices[unicode]=index
          end
        else
          local ok=false
          for u=1,#un do
            if un[u]==unicode then
              ok=true
              break
            end
          end
          if not ok then
            multiples[#multiples+1]=name
            un[#un+1]=unicode
            indices[unicode]=index
          end
        end
      end
    end
  end
  if trace_loading then
    if #multiples>0 then
      logs.report("load otf","%s glyph are reused: %s",#multiples,concat(multiples," "))
    else
      logs.report("load otf","no glyph are reused")
    end
  end
  luatex.indices=indices
  luatex.unicodes=unicodes
  luatex.private=private
end
otf.enhancers["cleanup ttf tables"]=function(data,filename)
  local ttf_tables=data.ttf_tables
  if ttf_tables then
    for k=1,#ttf_tables do
      if ttf_tables[k].data then ttf_tables[k].data="deleted" end
    end
  end
  data.ttf_tab_saved=nil
end
otf.enhancers["compact glyphs"]=function(data,filename)
  table.compact(data.glyphs) 
  if data.subfonts then
    for _,subfont in next,data.subfonts do
      table.compact(subfont.glyphs) 
    end
  end
end
otf.enhancers["reverse coverage"]=function(data,filename)
  if data.lookups then
    for _,v in next,data.lookups do
      if v.rules then
        for _,vv in next,v.rules do
          local c=vv.coverage
          if c and c.before then
            c.before=table.reverse(c.before)
          end
        end
      end
    end
  end
end
otf.enhancers["check italic correction"]=function(data,filename)
  local glyphs=data.glyphs
  local ok=false
  for index,glyph in next,glyphs do
    local ic=glyph.italic_correction
    if ic then
      if ic~=0 then
        glyph.italic=ic
      end
      glyph.italic_correction=nil
      ok=true
    end
  end
  otf.tables.valid_fields[#otf.tables.valid_fields+1]="has_italic"
  data.has_italic=true
end
otf.enhancers["check math"]=function(data,filename)
  if data.math then
    local glyphs=data.glyphs
    local unicodes=data.luatex.unicodes
    for index,glyph in next,glyphs do
      local mk=glyph.mathkern
      local hv=glyph.horiz_variants
      local vv=glyph.vert_variants
      if mk or hv or vv then
        local math={}
        glyph.math=math
        if mk then
          for k,v in next,mk do
            if not next(v) then
              mk[k]=nil
            end
          end
          math.kerns=mk
          glyph.mathkern=nil
        end
        if hv then
          math.horiz_variants=hv.variants
          local p=hv.parts
          if p and #p>0 then
            for i=1,#p do
              local pi=p[i]
              pi.glyph=unicodes[pi.component] or 0
            end
            math.horiz_parts=p
          end
          local ic=hv.italic_correction
          if ic and ic~=0 then
            math.horiz_italic_correction=ic
          end
          glyph.horiz_variants=nil
        end
        if vv then
          local uc=unicodes[index]
          math.vert_variants=vv.variants
          local p=vv.parts
          if p and #p>0 then
            for i=1,#p do
              local pi=p[i]
              pi.glyph=unicodes[pi.component] or 0
            end
            math.vert_parts=p
          end
          local ic=vv.italic_correction
          if ic and ic~=0 then
            math.vert_italic_correction=ic
          end
          glyph.vert_variants=nil
        end
        local ic=glyph.italic_correction
        if ic then
          if ic~=0 then
            math.italic_correction=ic
          end
          glyph.italic_correction=nil
        end
      end
    end
  end
end
otf.enhancers["share widths"]=function(data,filename)
  local glyphs=data.glyphs
  local widths={}
  for index,glyph in next,glyphs do
    local width=glyph.width
    widths[width]=(widths[width] or 0)+1
  end
  local wd,most=0,1
  for k,v in next,widths do
    if v>most then
      wd,most=k,v
    end
  end
  if most>1000 then
    if trace_loading then
      logs.report("load otf","most common width: %s (%s times), sharing (cjk font)",wd,most)
    end
    for k,v in next,glyphs do
      if v.width==wd then
        v.width=nil
      end
    end
    data.luatex.defaultwidth=wd
  end
end
otf.enhancers["reorganize kerns"]=function(data,filename)
  local glyphs,mapmap,unicodes=data.glyphs,data.luatex.indices,data.luatex.unicodes
  local mkdone=false
  local function do_it(lookup,first_unicode,kerns)
    local glyph=glyphs[mapmap[first_unicode]]
    if glyph then
      local mykerns=glyph.mykerns
      if not mykerns then
        mykerns={} 
        glyph.mykerns=mykerns
      end
      local lookupkerns=mykerns[lookup]
      if not lookupkerns then
        lookupkerns={}
        mykerns[lookup]=lookupkerns
      end
      for second_unicode,kern in next,kerns do
        lookupkerns[second_unicode]=kern
      end
    elseif trace_loading then
      logs.report("load otf","no glyph data for U+%04X",first_unicode)
    end
  end
  for index,glyph in next,glyphs do
    if glyph.kerns then
      local mykerns={}
      for k,v in next,glyph.kerns do
        local vc,vo,vl=v.char,v.off,v.lookup
        if vc and vo and vl then 
          local uvc=unicodes[vc]
          if not uvc then
            if trace_loading then
              logs.report("load otf","problems with unicode %s of kern %s at glyph %s",vc,k,index)
            end
          else
            if type(vl)~="table" then
              vl={ vl }
            end
            for l=1,#vl do
              local vll=vl[l]
              local mkl=mykerns[vll]
              if not mkl then
                mkl={}
                mykerns[vll]=mkl
              end
              if type(uvc)=="table" then
                for u=1,#uvc do
                  mkl[uvc[u]]=vo
                end
              else
                mkl[uvc]=vo
              end
            end
          end
        end
      end
      glyph.mykerns=mykerns
      glyph.kerns=nil 
      mkdone=true
    end
  end
  if trace_loading and mkdone then
    logs.report("load otf","replacing 'kerns' tables by 'mykerns' tables")
  end
  if data.kerns then
    if trace_loading then
      logs.report("load otf","removing global 'kern' table")
    end
    data.kerns=nil
  end
  local dgpos=data.gpos
  if dgpos then
    local separator=lpeg.P(" ")
    local other=((1-separator)^0)/unicodes
    local splitter=lpeg.Ct(other*(separator*other)^0)
    for gp=1,#dgpos do
      local gpos=dgpos[gp]
      local subtables=gpos.subtables
      if subtables then
        for s=1,#subtables do
          local subtable=subtables[s]
          local kernclass=subtable.kernclass 
          if kernclass then 
            local split={} 
            for k=1,#kernclass do
              local kcl=kernclass[k]
              local firsts,seconds,offsets,lookups=kcl.firsts,kcl.seconds,kcl.offsets,kcl.lookup 
              if type(lookups)~="table" then
                lookups={ lookups }
              end
              local maxfirsts,maxseconds=#firsts,#seconds
              for _,s in next,firsts do
                split[s]=split[s] or lpegmatch(splitter,s)
              end
              for _,s in next,seconds do
                split[s]=split[s] or lpegmatch(splitter,s)
              end
              for l=1,#lookups do
                local lookup=lookups[l]
                for fk=1,#firsts do
                  local fv=firsts[fk]
                  local splt=split[fv]
                  if splt then
                    local kerns,baseoffset={},(fk-1)*maxseconds
                    for sk=2,maxseconds do
                      local sv=seconds[sk]
                      local splt=split[sv]
                      if splt then
                        local offset=offsets[baseoffset+sk]
                        if offset then
                          for i=1,#splt do
                            local second_unicode=splt[i]
                            if tonumber(second_unicode) then
                              kerns[second_unicode]=offset
                            else for s=1,#second_unicode do
                              kerns[second_unicode[s]]=offset
                            end end
                          end
                        end
                      end
                    end
                    for i=1,#splt do
                      local first_unicode=splt[i]
                      if tonumber(first_unicode) then
                        do_it(lookup,first_unicode,kerns)
                      else for f=1,#first_unicode do
                        do_it(lookup,first_unicode[f],kerns)
                      end end
                    end
                  end
                end
              end
            end
            subtable.comment="The kernclass table is merged into mykerns in the indexed glyph tables."
            subtable.kernclass={}
          end
        end
      end
    end
  end
end
otf.enhancers["strip not needed data"]=function(data,filename)
  local verbose=fonts.verbose
  local int_to_uni=data.luatex.unicodes
  for k,v in next,data.glyphs do
    local d=v.dependents
    if d then v.dependents=nil end
    local a=v.altuni
    if a then v.altuni=nil end
    if verbose then
      local code=int_to_uni[k]
      if code then
        local vu=v.unicode
        if not vu then
          v.unicode=code
        elseif type(vu)=="table" then
          if vu[#vu]==code then
          else
            vu[#vu+1]=code
          end
        elseif vu~=code then
          v.unicode={ vu,code }
        end
      end
    else
      v.unicode=nil
      v.index=nil
    end
  end
  data.luatex.comment="Glyph tables have their original index. When present, mykern tables are indexed by unicode."
  data.map=nil
  data.names=nil 
  data.glyphcnt=nil
  data.glyphmax=nil
  if true then
    data.gpos=nil
    data.gsub=nil
    data.anchor_classes=nil
  end
end
otf.enhancers["migrate metadata"]=function(data,filename)
  local global_fields=otf.tables.global_fields
  local metadata={}
  for k,v in next,data do
    if not global_fields[k] then
      metadata[k]=v
      data[k]=nil
    end
  end
  data.metadata=metadata
  local pfminfo=data.pfminfo
  metadata.isfixedpitch=metadata.isfixedpitch or (pfminfo.panose and pfminfo.panose["proportion"]=="Monospaced")
  metadata.charwidth=pfminfo and pfminfo.avgwidth
end
local private_math_parameters={
  "FractionDelimiterSize",
  "FractionDelimiterDisplayStyleSize",
}
otf.enhancers["check math parameters"]=function(data,filename)
  local mathdata=data.metadata.math
  if mathdata then
    for m=1,#private_math_parameters do
      local pmp=private_math_parameters[m]
      if not mathdata[pmp] then
        if trace_loading then
          logs.report("load otf","setting math parameter '%s' to 0",pmp)
        end
        mathdata[pmp]=0
      end
    end
  end
end
otf.enhancers["flatten glyph lookups"]=function(data,filename)
  for k,v in next,data.glyphs do
    local lookups=v.lookups
    if lookups then
      for kk,vv in next,lookups do
        for kkk=1,#vv do
          local vvv=vv[kkk]
          local s=vvv.specification
          if s then
            local t=vvv.type
            if t=="ligature" then
              vv[kkk]={ "ligature",s.components,s.char }
            elseif t=="alternate" then
              vv[kkk]={ "alternate",s.components }
            elseif t=="substitution" then
              vv[kkk]={ "substitution",s.variant }
            elseif t=="multiple" then
              vv[kkk]={ "multiple",s.components }
            elseif t=="position" then
              vv[kkk]={ "position",{ s.x or 0,s.y or 0,s.h or 0,s.v or 0 } }
            elseif t=="pair" then
              local one,two,paired=s.offsets[1],s.offsets[2],s.paired or ""
              if one then
                if two then
                  vv[kkk]={ "pair",paired,{ one.x or 0,one.y or 0,one.h or 0,one.v or 0 },{ two.x or 0,two.y or 0,two.h or 0,two.v or 0 } }
                else
                  vv[kkk]={ "pair",paired,{ one.x or 0,one.y or 0,one.h or 0,one.v or 0 } }
                end
              else
                if two then
                  vv[kkk]={ "pair",paired,{},{ two.x or 0,two.y or 0,two.h or 0,two.v or 0} } 
                else
                  vv[kkk]={ "pair",paired }
                end
              end
            else
              if trace_loading then
                logs.report("load otf","flattening needed, report to context list")
              end
              for a,b in next,s do
                if trace_loading and vvv[a] then
                  logs.report("load otf","flattening conflict, report to context list")
                end
                vvv[a]=b
              end
              vvv.specification=nil
            end
          end
        end
      end
    end
  end
end
otf.enhancers["simplify glyph lookups"]=function(data,filename)
  for k,v in next,data.glyphs do
    local lookups=v.lookups
    if lookups then
      local slookups,mlookups
      for kk,vv in next,lookups do
        if #vv==1 then
          if not slookups then
            slookups={}
            v.slookups=slookups
          end
          slookups[kk]=vv[1]
        else
          if not mlookups then
            mlookups={}
            v.mlookups=mlookups
          end
          mlookups[kk]=vv
        end
      end
      v.lookups=nil
    end
  end
end
otf.enhancers["flatten anchor tables"]=function(data,filename)
  for k,v in next,data.glyphs do
    if v.anchors then
      for kk,vv in next,v.anchors do
        for kkk,vvv in next,vv do
          if vvv.x or vvv.y then
            vv[kkk]={ vvv.x or 0,vvv.y or 0 }
          else
            for kkkk=1,#vvv do
              local vvvv=vvv[kkkk]
              vvv[kkkk]={ vvvv.x or 0,vvvv.y or 0 }
            end
          end
        end
      end
    end
  end
end
otf.enhancers["flatten feature tables"]=function(data,filename)
  for _,tag in next,otf.glists do
    if data[tag] then
      if trace_loading then
        logs.report("load otf","flattening %s table",tag)
      end
      for k,v in next,data[tag] do
        local features=v.features
        if features then
          for kk=1,#features do
            local vv=features[kk]
            local t={}
            local scripts=vv.scripts
            for kkk=1,#scripts do
              local vvv=scripts[kkk]
              t[vvv.script]=vvv.langs
            end
            vv.scripts=t
          end
        end
      end
    end
  end
end
otf.enhancers.patches=otf.enhancers.patches or {}
otf.enhancers["patch bugs"]=function(data,filename)
  local basename=file.basename(lower(filename))
  for pattern,action in next,otf.enhancers.patches do
    if find(basename,pattern) then
      action(data,filename)
    end
  end
end
fonts.otf.enhancers["enrich with features"]=function(data,filename)
end
function otf.features.register(name,default)
  otf.features.list[#otf.features.list+1]=name
  otf.features.default[name]=default
end
function otf.set_features(tfmdata,features)
  local processes={}
  if features and next(features) then
    local lists={ 
      fonts.triggers,
      fonts.processors,
      fonts.manipulators,
    }
    local mode=tfmdata.mode or fonts.mode 
    local initializers=fonts.initializers
    local fi=initializers[mode]
    if fi then
      local fiotf=fi.otf
      if fiotf then
        local done={}
        for l=1,4 do
          local list=lists[l]
          if list then
            for i=1,#list do
              local f=list[i]
              local value=features[f]
              if value and fiotf[f] then 
                if not done[f] then 
                  if trace_features then
                    logs.report("define otf","initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown',tfmdata.fullname or 'unknown')
                  end
                  fiotf[f](tfmdata,value) 
                  mode=tfmdata.mode or fonts.mode 
                  local im=initializers[mode]
                  if im then
                    fiotf=initializers[mode].otf
                  end
                  done[f]=true
                end
              end
            end
          end
        end
      end
    end
    local fm=fonts.methods[mode] 
    if fm then
      local fmotf=fm.otf
      if fmotf then
        for l=1,4 do
          local list=lists[l]
          if list then
            for i=1,#list do
              local f=list[i]
              if fmotf[f] then 
                if trace_features then
                  logs.report("define otf","installing feature handler %s for mode %s for font %s",f,mode or 'unknown',tfmdata.fullname or 'unknown')
                end
                processes[#processes+1]=fmotf[f]
              end
            end
          end
        end
      end
    else
    end
  end
  return processes,features
end
function otf.otf_to_tfm(specification)
  local name=specification.name
  local sub=specification.sub
  local filename=specification.filename
  local format=specification.format
  local features=specification.features.normal
  local cache_id=specification.hash
  local tfmdata=containers.read(tfm.cache,cache_id)
  if not tfmdata then
    local otfdata=otf.load(filename,format,sub,features and features.featurefile)
    if otfdata and next(otfdata) then
      otfdata.shared=otfdata.shared or {
        featuredata={},
        anchorhash={},
        initialized=false,
      }
      tfmdata=otf.copy_to_tfm(otfdata,cache_id)
      if tfmdata and next(tfmdata) then
        tfmdata.unique=tfmdata.unique or {}
        tfmdata.shared=tfmdata.shared or {} 
        local shared=tfmdata.shared
        shared.otfdata=otfdata
        shared.features=features 
        shared.dynamics={}
        shared.processes={}
        shared.set_dynamics=otf.set_dynamics
        tfmdata.luatex=otfdata.luatex
        tfmdata.indices=otfdata.luatex.indices
        tfmdata.unicodes=otfdata.luatex.unicodes
        tfmdata.marks=otfdata.luatex.marks
        tfmdata.originals=otfdata.luatex.originals
        tfmdata.changed={}
        tfmdata.has_italic=otfdata.metadata.has_italic
        if not tfmdata.language then tfmdata.language='dflt' end
        if not tfmdata.script  then tfmdata.script='dflt' end
        shared.processes,shared.features=otf.set_features(tfmdata,fonts.define.check(features,otf.features.default))
      end
    end
    containers.write(tfm.cache,cache_id,tfmdata)
  end
  return tfmdata
end
fonts.formats.dfont="truetype"
fonts.formats.ttc="truetype"
fonts.formats.ttf="truetype"
fonts.formats.otf="opentype"
function otf.copy_to_tfm(data,cache_id) 
  if data then
    local glyphs,pfminfo,metadata=data.glyphs or {},data.pfminfo or {},data.metadata or {}
    local luatex=data.luatex
    local unicodes=luatex.unicodes 
    local indices=luatex.indices
    local characters,parameters,math_parameters,descriptions={},{},{},{}
    local designsize=metadata.designsize or metadata.design_size or 100
    if designsize==0 then
      designsize=100
    end
    local spaceunits,spacer=500,"space"
    for u,i in next,indices do
      characters[u]={} 
      descriptions[u]=glyphs[i]
    end
    if metadata.math then
      for name,value in next,metadata.math do
        math_parameters[name]=value
      end
      for u,char in next,characters do
        local d=descriptions[u]
        local m=d.math
        if m then
          local variants,parts,c,uc=m.horiz_variants,m.horiz_parts,char,u
          if variants then
            for n in gmatch(variants,"[^ ]+") do
              local un=unicodes[n]
              if un and uc~=un then
                c.next=un
                c=characters[un]
				uc=un
              end
            end
            c.horiz_variants=parts
          elseif parts then
            c.horiz_variants=parts
          end
          local variants,parts,c,uc=m.vert_variants,m.vert_parts,char,u
          if variants then
            for n in gmatch(variants,"[^ ]+") do
              local un=unicodes[n]
              if un and uc~=un then
                c.next=un
                c=characters[un]
				uc=un
              end
            end 
            c.vert_variants=parts
          elseif parts then
            c.vert_variants=parts
          end
          local italic_correction=m.vert_italic_correction
          if italic_correction then
            c.vert_italic_correction=italic_correction
          end
          local kerns=m.kerns
          if kerns then
            char.mathkerns=kerns
          end
        end
      end
    end
    local endash,emdash,space=0x20,0x2014,"space" 
    if metadata.isfixedpitch then
      if descriptions[endash] then
        spaceunits,spacer=descriptions[endash].width,"space"
      end
      if not spaceunits and descriptions[emdash] then
        spaceunits,spacer=descriptions[emdash].width,"emdash"
      end
      if not spaceunits and metadata.charwidth then
        spaceunits,spacer=metadata.charwidth,"charwidth"
      end
    else
      if descriptions[endash] then
        spaceunits,spacer=descriptions[endash].width,"space"
      end
      if not spaceunits and descriptions[emdash] then
        spaceunits,spacer=descriptions[emdash].width/2,"emdash/2"
      end
      if not spaceunits and metadata.charwidth then
        spaceunits,spacer=metadata.charwidth,"charwidth"
      end
    end
    spaceunits=tonumber(spaceunits) or tfm.units/2
    local filename=fonts.tfm.checked_filename(luatex)
    local fontname=metadata.fontname
    local fullname=metadata.fullname or fontname
    local cidinfo=data.cidinfo
    local units=metadata.units_per_em or 1000
    cidinfo.registry=cidinfo and cidinfo.registry or ""
    parameters.slant=0
    parameters.space=spaceunits     
    parameters.space_stretch=units/2  
    parameters.space_shrink=1*units/3 
    parameters.x_height=2*units/5 
    parameters.quad=units   
    if spaceunits<2*units/5 then
    end
    local italicangle=metadata.italicangle
    if italicangle then 
      parameters.slant=parameters.slant-math.round(math.tan(italicangle*math.pi/180))
    end
    if metadata.isfixedpitch then
      parameters.space_stretch=0
      parameters.space_shrink=0
    elseif otf.syncspace then 
      parameters.space_stretch=spaceunits/2
      parameters.space_shrink=spaceunits/3
    end
    parameters.extra_space=parameters.space_shrink 
    if pfminfo.os2_xheight and pfminfo.os2_xheight>0 then
      parameters.x_height=pfminfo.os2_xheight
    else
      local x=0x78 
      if x then
        local x=descriptions[x]
        if x then
          parameters.x_height=x.height
        end
      end
    end
    return {
      characters=characters,
      parameters=parameters,
      math_parameters=math_parameters,
      descriptions=descriptions,
      indices=indices,
      unicodes=unicodes,
      type="real",
      direction=0,
      boundarychar_label=0,
      boundarychar=65536,
      designsize=(designsize/10)*65536,
      spacer="500 units",
      encodingbytes=2,
      filename=filename,
      fontname=fontname,
      fullname=fullname,
      psname=fontname or fullname,
      name=filename or fullname,
      units=units,
      format=fonts.fontformat(filename,"opentype"),
      cidinfo=cidinfo,
      ascender=abs(metadata.ascent or 0),
      descender=abs(metadata.descent or 0),
      spacer=spacer,
      italicangle=italicangle,
    }
  else
    return nil
  end
end
otf.features.register('mathsize')
function tfm.read_from_open_type(specification)
  local tfmtable=otf.otf_to_tfm(specification)
  if tfmtable then
    local otfdata=tfmtable.shared.otfdata
    tfmtable.name=specification.name
    tfmtable.sub=specification.sub
    local s=specification.size
    local m=otfdata.metadata.math
    if m then
      local f=specification.features
      if f then
        local f=f.normal
        if f and f.mathsize then
          local mathsize=specification.mathsize or 0
          if mathsize==2 then
            local p=m.ScriptPercentScaleDown
            if p then
              local ps=p*specification.textsize/100
              if trace_math then
                logs.report("define font","asked script size: %s, used: %s (%2.2f %%)",s,ps,(ps/s)*100)
              end
              s=ps
            end
          elseif mathsize==3 then
            local p=m.ScriptScriptPercentScaleDown
            if p then
              local ps=p*specification.textsize/100
              if trace_math then
                logs.report("define font","asked scriptscript size: %s, used: %s (%2.2f %%)",s,ps,(ps/s)*100)
              end
              s=ps
            end
          end
        end
      end
    end
    tfmtable=tfm.scale(tfmtable,s,specification.relativeid)
    if tfm.fontname_mode=="specification" then
      local specname=specification.specification
      if specname then
        tfmtable.name=specname
        if trace_defining then
          logs.report("define font","overloaded fontname: '%s'",specname)
        end
      end
    end
    fonts.logger.save(tfmtable,file.extname(specification.filename),specification)
  end
  return tfmtable
end
function otf.collect_lookups(otfdata,kind,script,language)
  local sequences=otfdata.luatex.sequences
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

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otd']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local trace_dynamics=false trackers.register("otf.dynamics",function(v) trace_dynamics=v end)
fonts=fonts   or {}
fonts.otf=fonts.otf or {}
local otf=fonts.otf
local fontdata=fonts.ids
otf.features=otf.features     or {}
otf.features.default=otf.features.default or {}
local context_setups=fonts.define.specify.context_setups
local context_numbers=fonts.define.specify.context_numbers
local a_to_script={} otf.a_to_script=a_to_script
local a_to_language={} otf.a_to_language=a_to_language
function otf.set_dynamics(font,dynamics,attribute)
  local features=context_setups[context_numbers[attribute]] 
  if features then
    local script=features.script  or 'dflt'
    local language=features.language or 'dflt'
    local ds=dynamics[script]
    if not ds then
      ds={}
      dynamics[script]=ds
    end
    local dsl=ds[language]
    if not dsl then
      dsl={}
      ds[language]=dsl
    end
    local dsla=dsl[attribute]
    if dsla then
      return dsla
    else
      local tfmdata=fontdata[font]
      a_to_script [attribute]=script
      a_to_language[attribute]=language
      local saved={
        script=tfmdata.script,
        language=tfmdata.language,
        mode=tfmdata.mode,
        features=tfmdata.shared.features
      }
      tfmdata.mode="node"
      tfmdata.language=language
      tfmdata.script=script
      tfmdata.shared.features={}
      local set=fonts.define.check(features,otf.features.default)
      dsla=otf.set_features(tfmdata,set)
      if trace_dynamics then
        logs.report("otf define","setting dynamics %s: attribute %s, script %s, language %s, set: %s",context_numbers[attribute],attribute,script,language,table.sequenced(set))
      end
      tfmdata.script=saved.script
      tfmdata.language=saved.language
      tfmdata.mode=saved.mode
      tfmdata.shared.features=saved.features
      dynamics[script][language][attribute]=dsla 
      return dsla
    end
  end
  return nil 
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
local otf=fonts.otf
otf.default_language='latn'
otf.default_script='dflt'
local languages=otf.tables.languages
local scripts=otf.tables.scripts
function otf.features.language(tfmdata,value)
  if value then
    value=lower(value)
    if languages[value] then
      tfmdata.language=value
    end
  end
end
function otf.features.script(tfmdata,value)
  if value then
    value=lower(value)
    if scripts[value] then
      tfmdata.script=value
    end
  end
end
function otf.features.mode(tfmdata,value)
  if value then
    tfmdata.mode=lower(value)
  end
end
fonts.initializers.base.otf.language=otf.features.language
fonts.initializers.base.otf.script=otf.features.script
fonts.initializers.base.otf.mode=otf.features.mode
fonts.initializers.base.otf.method=otf.features.mode
fonts.initializers.node.otf.language=otf.features.language
fonts.initializers.node.otf.script=otf.features.script
fonts.initializers.node.otf.mode=otf.features.mode
fonts.initializers.node.otf.method=otf.features.mode
otf.features.register("features",true)   
table.insert(fonts.processors,"features") 

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
local otf=fonts.otf
local tfm=fonts.tfm
local trace_baseinit=false trackers.register("otf.baseinit",function(v) trace_baseinit=v end)
local trace_singles=false trackers.register("otf.singles",function(v) trace_singles=v end)
local trace_multiples=false trackers.register("otf.multiples",function(v) trace_multiples=v end)
local trace_alternatives=false trackers.register("otf.alternatives",function(v) trace_alternatives=v end)
local trace_ligatures=false trackers.register("otf.ligatures",function(v) trace_ligatures=v end)
local trace_kerns=false trackers.register("otf.kerns",function(v) trace_kerns=v end)
local trace_preparing=false trackers.register("otf.preparing",function(v) trace_preparing=v end)
local wildcard="*"
local default="dflt"
local split_at_space=lpeg.Ct(lpeg.splitat(" ")) 
local pcache,fcache={},{} 
local function gref(descriptions,n)
  if type(n)=="number" then
    local name=descriptions[n].name
    if name then
      return format("U+%04X (%s)",n,name)
    else
      return format("U+%04X")
    end
  elseif n then
    local num,nam={},{}
    for i=1,#n do
      local ni=n[i]
      num[i]=format("U+%04X",ni)
      nam[i]=descriptions[ni].name or "?"
    end
    return format("%s (%s)",concat(num," "),concat(nam," "))
  else
    return "?"
  end
end
local function cref(kind,lookupname)
  if lookupname then
    return format("feature %s, lookup %s",kind,lookupname)
  else
    return format("feature %s",kind)
  end
end
local function resolve_ligatures(tfmdata,ligatures,kind)
  kind=kind or "unknown"
  local unicodes=tfmdata.unicodes
  local characters=tfmdata.characters
  local descriptions=tfmdata.descriptions
  local changed=tfmdata.changed
  local done={}
  while true do
    local ok=false
    for k,v in next,ligatures do
      local lig=v[1]
      if not done[lig] then
        local ligs=lpegmatch(split_at_space,lig)
        if #ligs==2 then
          local uc=v[2]
          local c,f,s=characters[uc],ligs[1],ligs[2]
          local uft,ust=unicodes[f] or 0,unicodes[s] or 0
          if not uft or not ust then
            logs.report("define otf","%s: unicode problem with base ligature %s = %s + %s",cref(kind),gref(descriptions,uc),gref(descriptions,uft),gref(descriptions,ust))
          else
            if type(uft)=="number" then uft={ uft } end
            if type(ust)=="number" then ust={ ust } end
            for ufi=1,#uft do
              local uf=uft[ufi]
              for usi=1,#ust do
                local us=ust[usi]
                if changed[uf] or changed[us] then
                  if trace_baseinit and trace_ligatures then
                    logs.report("define otf","%s: base ligature %s + %s ignored",cref(kind),gref(descriptions,uf),gref(descriptions,us))
                  end
                else
                  local first,second=characters[uf],us
                  if first and second then
                    local t=first.ligatures
                    if not t then
                      t={}
                      first.ligatures=t
                    end
                    if type(uc)=="number" then
                      t[second]={ type=0,char=uc }
                    else
                      t[second]={ type=0,char=uc[1] } 
                    end
                    if trace_baseinit and trace_ligatures then
                      logs.report("define otf","%s: base ligature %s + %s => %s",cref(kind),gref(descriptions,uf),gref(descriptions,us),gref(descriptions,uc))
                    end
                  end
                end
              end
            end
          end
          ok,done[lig]=true,descriptions[uc].name
        end
      end
    end
    if ok then
      for d,n in next,done do
        local pattern=pcache[d] if not pattern then pattern="^("..d..") "       pcache[d]=pattern end
        local fnc=fcache[n] if not fnc   then fnc=function() return n.." " end fcache[n]=fnc   end
        for k,v in next,ligatures do
          v[1]=gsub(v[1],pattern,fnc)
        end
      end
    else
      break
    end
  end
end
local splitter=lpeg.splitat(" ")
local function prepare_base_substitutions(tfmdata,kind,value) 
  if value then
    local otfdata=tfmdata.shared.otfdata
    local validlookups,lookuplist=otf.collect_lookups(otfdata,kind,tfmdata.script,tfmdata.language)
    if validlookups then
      local ligatures={}
      local unicodes=tfmdata.unicodes 
      local indices=tfmdata.indices
      local characters=tfmdata.characters
      local descriptions=tfmdata.descriptions
      local changed=tfmdata.changed
      local actions={
        substitution=function(p,lookup,k,glyph,unicode)
          local pv=p[2] 
          if pv then
            local upv=unicodes[pv]
            if upv then
              if type(upv)=="table" then
                upv=upv[1]
              end
              if characters[upv] then
                if trace_baseinit and trace_singles then
                  logs.report("define otf","%s: base substitution %s => %s",cref(kind,lookup),gref(descriptions,k),gref(descriptions,upv))
                end
                changed[k]=upv
              end
            end
          end
        end,
        alternate=function(p,lookup,k,glyph,unicode)
          local pc=p[2] 
          if pc then
            if value==1 then
              pc=lpegmatch(splitter,pc)
            elseif value==2 then
              local a,b=lpegmatch(splitter,pc)
              pc=b or a
            else
              pc={ lpegmatch(splitter,pc) }
              pc=pc[value] or pc[#pc]
            end
            if pc then
              local upc=unicodes[pc]
              if upc then
                if type(upc)=="table" then
                  upc=upc[1]
                end
                if characters[upc] then
                  if trace_baseinit and trace_alternatives then
                    logs.report("define otf","%s: base alternate %s %s => %s",cref(kind,lookup),tostring(value),gref(descriptions,k),gref(descriptions,upc))
                  end
                  changed[k]=upc
                end
              end
            end
          end
        end,
        ligature=function(p,lookup,k,glyph,unicode)
          local pc=p[2]
          if pc then
            if trace_baseinit and trace_ligatures then
              local upc={ lpegmatch(splitter,pc) }
              for i=1,#upc do upc[i]=unicodes[upc[i]] end
              logs.report("define otf","%s: base ligature %s => %s",cref(kind,lookup),gref(descriptions,upc),gref(descriptions,k))
            end
            ligatures[#ligatures+1]={ pc,k }
          end
        end,
      }
      for k,c in next,characters do
        local glyph=descriptions[k]
        local lookups=glyph.slookups
        if lookups then
          for l=1,#lookuplist do
            local lookup=lookuplist[l]
            local p=lookups[lookup]
            if p then
              local a=actions[p[1]]
              if a then
                a(p,lookup,k,glyph,unicode)
              end
            end
          end
        end
        local lookups=glyph.mlookups
        if lookups then
          for l=1,#lookuplist do
            local lookup=lookuplist[l]
            local ps=lookups[lookup]
            if ps then
              for i=1,#ps do
                local p=ps[i]
                local a=actions[p[1]]
                if a then
                  a(p,lookup,k,glyph,unicode)
                end
              end
            end
          end
        end
      end
      resolve_ligatures(tfmdata,ligatures,kind)
    end
  else
    tfmdata.ligatures=tfmdata.ligatures or {} 
  end
end
local function prepare_base_kerns(tfmdata,kind,value) 
  if value then
    local otfdata=tfmdata.shared.otfdata
    local validlookups,lookuplist=otf.collect_lookups(otfdata,kind,tfmdata.script,tfmdata.language)
    if validlookups then
      local unicodes=tfmdata.unicodes 
      local indices=tfmdata.indices
      local characters=tfmdata.characters
      local descriptions=tfmdata.descriptions
      local sharedkerns={}
      for u,chr in next,characters do
        local d=descriptions[u]
        if d then
          local dk=d.mykerns 
          if dk then
            local s=sharedkerns[dk]
            if s==false then
            elseif s then
              chr.kerns=s
            else
              local t,done=chr.kerns or {},false
              for l=1,#lookuplist do
                local lookup=lookuplist[l]
                local kerns=dk[lookup]
                if kerns then
                  for k,v in next,kerns do
                    if v~=0 and not t[k] then 
                      t[k],done=v,true
                      if trace_baseinit and trace_kerns then
                        logs.report("define otf","%s: base kern %s + %s => %s",cref(kind,lookup),gref(descriptions,u),gref(descriptions,k),v)
                      end
                    end
                  end
                end
              end
              if done then
                sharedkerns[dk]=t
                chr.kerns=t 
              else
                sharedkerns[dk]=false
              end
            end
          end
        end
      end
    end
  end
end
local supported_gsub={
  'liga','dlig','rlig','hlig',
  'pnum','onum','tnum','lnum',
  'zero',
  'smcp','cpsp','c2sc','ornm','aalt',
  'hwid','fwid',
  'ssty','rtlm',
}
local supported_gpos={
  'kern'
}
function otf.features.register_base_substitution(tag)
  supported_gsub[#supported_gsub+1]=tag
end
function otf.features.register_base_kern(tag)
  supported_gsub[#supported_gpos+1]=tag
end
local basehash,basehashes={},1
function fonts.initializers.base.otf.features(tfmdata,value)
  if true then
    local t=trace_preparing and os.clock()
    local features=tfmdata.shared.features
    if features then
      local h={}
      for f=1,#supported_gsub do
        local feature=supported_gsub[f]
        local value=features[feature]
        prepare_base_substitutions(tfmdata,feature,value)
        if value then
          h[#h+1]=feature.."="..tostring(value)
        end
      end
      for f=1,#supported_gpos do
        local feature=supported_gpos[f]
        local value=features[feature]
        prepare_base_kerns(tfmdata,feature,features[feature])
        if value then
          h[#h+1]=feature.."="..tostring(value)
        end
      end
      local hash=concat(h," ")
      local base=basehash[hash]
      if not base then
        basehashes=basehashes+1
        base=basehashes
        basehash[hash]=base
      end
      tfmdata.fullname=tfmdata.fullname.."-"..base
    end
    if trace_preparing then
      logs.report("otf define","preparation time is %0.3f seconds for %s",os.clock()-t,tfmdata.fullname or "?")
    end
  end
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otn']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local concat,insert,remove=table.concat,table.insert,table.remove
local format,gmatch,gsub,find,match,lower,strip=string.format,string.gmatch,string.gsub,string.find,string.match,string.lower,string.strip
local type,next,tonumber,tostring=type,next,tonumber,tostring
local lpegmatch=lpeg.match
local otf=fonts.otf
local tfm=fonts.tfm
local trace_lookups=false trackers.register("otf.lookups",function(v) trace_lookups=v end)
local trace_singles=false trackers.register("otf.singles",function(v) trace_singles=v end)
local trace_multiples=false trackers.register("otf.multiples",function(v) trace_multiples=v end)
local trace_alternatives=false trackers.register("otf.alternatives",function(v) trace_alternatives=v end)
local trace_ligatures=false trackers.register("otf.ligatures",function(v) trace_ligatures=v end)
local trace_contexts=false trackers.register("otf.contexts",function(v) trace_contexts=v end)
local trace_marks=false trackers.register("otf.marks",function(v) trace_marks=v end)
local trace_kerns=false trackers.register("otf.kerns",function(v) trace_kerns=v end)
local trace_cursive=false trackers.register("otf.cursive",function(v) trace_cursive=v end)
local trace_preparing=false trackers.register("otf.preparing",function(v) trace_preparing=v end)
local trace_bugs=false trackers.register("otf.bugs",function(v) trace_bugs=v end)
local trace_details=false trackers.register("otf.details",function(v) trace_details=v end)
local trace_applied=false trackers.register("otf.applied",function(v) trace_applied=v end)
local trace_steps=false trackers.register("otf.steps",function(v) trace_steps=v end)
local trace_skips=false trackers.register("otf.skips",function(v) trace_skips=v end)
local trace_directions=false trackers.register("otf.directions",function(v) trace_directions=v end)
trackers.register("otf.verbose_chain",function(v) otf.setcontextchain(v and "verbose") end)
trackers.register("otf.normal_chain",function(v) otf.setcontextchain(v and "normal") end)
trackers.register("otf.replacements","otf.singles,otf.multiples,otf.alternatives,otf.ligatures")
trackers.register("otf.positions","otf.marks,otf.kerns,otf.cursive")
trackers.register("otf.actions","otf.replacements,otf.positions")
trackers.register("otf.injections","nodes.injections")
trackers.register("*otf.sample","otf.steps,otf.actions,otf.analyzing")
local insert_node_after=node.insert_after
local delete_node=nodes.delete
local copy_node=node.copy
local find_node_tail=node.tail or node.slide
local set_attribute=node.set_attribute
local has_attribute=node.has_attribute
local zwnj=0x200C
local zwj=0x200D
local wildcard="*"
local default="dflt"
local split_at_space=lpeg.splitters[" "] or lpeg.Ct(lpeg.splitat(" ")) 
local glyph=node.id('glyph')
local glue=node.id('glue')
local kern=node.id('kern')
local disc=node.id('disc')
local whatsit=node.id('whatsit')
local state=attributes.private('state')
local markbase=attributes.private('markbase')
local markmark=attributes.private('markmark')
local markdone=attributes.private('markdone')
local cursbase=attributes.private('cursbase')
local curscurs=attributes.private('curscurs')
local cursdone=attributes.private('cursdone')
local kernpair=attributes.private('kernpair')
local set_mark=nodes.set_mark
local set_cursive=nodes.set_cursive
local set_kern=nodes.set_kern
local set_pair=nodes.set_pair
local markonce=true
local cursonce=true
local kernonce=true
local fontdata=fonts.ids
otf.features.process={}
local tfmdata=false
local otfdata=false
local characters=false
local descriptions=false
local marks=false
local indices=false
local unicodes=false
local currentfont=false
local lookuptable=false
local anchorlookups=false
local handlers={}
local rlmode=0
local featurevalue=false
local context_setups=fonts.define.specify.context_setups
local context_numbers=fonts.define.specify.context_numbers
local context_merged=fonts.define.specify.context_merged
local special_attributes={
  init=1,
  medi=2,
  fina=3,
  isol=4
}
local checkstep=(nodes and nodes.tracers and nodes.tracers.steppers.check)  or function() end
local registerstep=(nodes and nodes.tracers and nodes.tracers.steppers.register) or function() end
local registermessage=(nodes and nodes.tracers and nodes.tracers.steppers.message) or function() end
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  logs.report("otf direct",...)
end
local function logwarning(...)
  logs.report("otf direct",...)
end
local function gref(n)
  if type(n)=="number" then
    local description=descriptions[n]
    local name=description and description.name
    if name then
      return format("U+%04X (%s)",n,name)
    else
      return format("U+%04X",n)
    end
  elseif not n then
    return "<error in tracing>"
  else
    local num,nam={},{}
    for i=1,#n do
      local ni=n[i]
      num[#num+1]=format("U+%04X",ni)
      local dni=descriptions[ni]
      nam[#num]=(dni and dni.name) or "?"
    end
    return format("%s (%s)",concat(num," "),concat(nam," "))
  end
end
local function cref(kind,chainname,chainlookupname,lookupname,index)
  if index then
    return format("feature %s, chain %s, sub %s, lookup %s, index %s",kind,chainname,chainlookupname,lookupname,index)
  elseif lookupname then
    return format("feature %s, chain %s, sub %s, lookup %s",kind,chainname or "?",chainlookupname or "?",lookupname)
  elseif chainlookupname then
    return format("feature %s, chain %s, sub %s",kind,chainname or "?",chainlookupname)
  elseif chainname then
    return format("feature %s, chain %s",kind,chainname)
  else
    return format("feature %s",kind)
  end
end
local function pref(kind,lookupname)
  return format("feature %s, lookup %s",kind,lookupname)
end
local function markstoligature(kind,lookupname,start,stop,char)
  local n=copy_node(start)
  local keep=start
  local current
  current,start=insert_node_after(start,start,n)
  local snext=stop.next
  current.next=snext
  if snext then
    snext.prev=current
  end
  start.prev,stop.next=nil,nil
  current.char,current.subtype,current.components=char,2,start
  return keep
end
local function toligature(kind,lookupname,start,stop,char,markflag,discfound) 
  if start~=stop then
    if discfound then
      local lignode=copy_node(start)
      lignode.font,lignode.char,lignode.subtype=start.font,char,2
      local next,prev=stop.next,start.prev
      stop.next=nil
      lignode=node.do_ligature_n(start,stop,lignode)
      prev.next=lignode
      if next then
        next.prev=lignode
      end
      lignode.next,lignode.prev=next,prev
      start=lignode
    else 
      local deletemarks=markflag~="mark"
      local n=copy_node(start)
      local current
      current,start=insert_node_after(start,start,n)
      local snext=stop.next
      current.next=snext
      if snext then
        snext.prev=current
      end
      start.prev,stop.next=nil,nil
      current.char,current.subtype,current.components=char,2,start
      local head=current
      if deletemarks then
        if trace_marks then
          while start do
            if marks[start.char] then
              logwarning("%s: remove mark %s",pref(kind,lookupname),gref(start.char))
            end
            start=start.next
          end
        end
      else
        local i=0
        while start do
          if marks[start.char] then
            set_attribute(start,markdone,i)
            if trace_marks then
              logwarning("%s: keep mark %s, gets index %s",pref(kind,lookupname),gref(start.char),i)
            end
            head,current=insert_node_after(head,current,copy_node(start))
          else
            i=i+1
          end
          start=start.next
        end
        start=current.next
        while start and start.id==glyph do
          if marks[start.char] then
            set_attribute(start,markdone,i)
            if trace_marks then
              logwarning("%s: keep mark %s, gets index %s",pref(kind,lookupname),gref(start.char),i)
            end
          else
            break
          end
          start=start.next
        end
      end
      return head
    end
  else
    start.char=char
  end
  return start
end
function handlers.gsub_single(start,kind,lookupname,replacement)
  if trace_singles then
    logprocess("%s: replacing %s by single %s",pref(kind,lookupname),gref(start.char),gref(replacement))
  end
  start.char=replacement
  return start,true
end
local function alternative_glyph(start,alternatives,kind,chainname,chainlookupname,lookupname) 
  local value,choice,n=featurevalue or tfmdata.shared.features[kind],nil,#alternatives 
  if value=="random" then
    local r=math.random(1,n)
    value,choice=format("random, choice %s",r),alternatives[r]
  elseif value=="first" then
    value,choice=format("first, choice %s",1),alternatives[1]
  elseif value=="last" then
    value,choice=format("last, choice %s",n),alternatives[n]
  else
    value=tonumber(value)
    if type(value)~="number" then
      value,choice="default, choice 1",alternatives[1]
    elseif value>n then
      value,choice=format("no %s variants, taking %s",value,n),alternatives[n]
    elseif value==0 then
      value,choice=format("choice %s (no change)",value),start.char
    elseif value<1 then
      value,choice=format("no %s variants, taking %s",value,1),alternatives[1]
    else
      value,choice=format("choice %s",value),alternatives[value]
    end
  end
  if not choice then
    logwarning("%s: no variant %s for %s",cref(kind,chainname,chainlookupname,lookupname),value,gref(start.char))
    choice,value=start.char,format("no replacement instead of %s",value)
  end
  return choice,value
end
function handlers.gsub_alternate(start,kind,lookupname,alternative,sequence)
  local choice,index=alternative_glyph(start,alternative,kind,lookupname)
  if trace_alternatives then
    logprocess("%s: replacing %s by alternative %s (%s)",pref(kind,lookupname),gref(start.char),gref(choice),index)
  end
  start.char=choice
  return start,true
end
function handlers.gsub_multiple(start,kind,lookupname,multiple)
  if trace_multiples then
    logprocess("%s: replacing %s by multiple %s",pref(kind,lookupname),gref(start.char),gref(multiple))
  end
  start.char=multiple[1]
  if #multiple>1 then
    for k=2,#multiple do
      local n=copy_node(start)
      n.char=multiple[k]
      local sn=start.next
      n.next=sn
      n.prev=start
      if sn then
        sn.prev=n
      end
      start.next=n
      start=n
    end
  end
  return start,true
end
function handlers.gsub_ligature(start,kind,lookupname,ligature,sequence) 
  local s,stop,discfound=start.next,nil,false
  local startchar=start.char
  if marks[startchar] then
    while s do
      local id=s.id
      if id==glyph and s.subtype<256 then
        if s.font==currentfont then
          local char=s.char
          local lg=ligature[1][char]
          if not lg then
            break
          else
            stop=s
            ligature=lg
            s=s.next
          end
        else
          break
        end
      else
        break
      end
    end
    if stop and ligature[2] then
      if trace_ligatures then
        local stopchar=stop.char
        start=markstoligature(kind,lookupname,start,stop,ligature[2])
        logprocess("%s: replacing %s upto %s by ligature %s",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(start.char))
      else
        start=markstoligature(kind,lookupname,start,stop,ligature[2])
      end
      return start,true
    end
  else
    local skipmark=sequence.flags[1]
    while s do
      local id=s.id
      if id==glyph and s.subtype<256 then
        if s.font==currentfont then
          local char=s.char
          if skipmark and marks[char] then
            s=s.next
          else
            local lg=ligature[1][char]
            if not lg then
              break
            else
              stop=s
              ligature=lg
              s=s.next
            end
          end
        else
          break
        end
      elseif id==disc then
        discfound=true
        s=s.next
      else
        break
      end
    end
    if stop and ligature[2] then
      if trace_ligatures then
        local stopchar=stop.char
        start=toligature(kind,lookupname,start,stop,ligature[2],skipmark,discfound)
        logprocess("%s: replacing %s upto %s by ligature %s",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(start.char))
      else
        start=toligature(kind,lookupname,start,stop,ligature[2],skipmark,discfound)
      end
      return start,true
    end
  end
  return start,false
end
function handlers.gpos_mark2base(start,kind,lookupname,markanchors,sequence)
  local markchar=start.char
  if marks[markchar] then
    local base=start.prev 
    if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
      local basechar=base.char
      if marks[basechar] then
        while true do
          base=base.prev
          if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
            basechar=base.char
            if not marks[basechar] then
              break
            end
          else
            if trace_bugs then
              logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
            end
            return start,false
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
                local dx,dy,bound=set_mark(start,base,tfmdata.factor,rlmode,ba,ma)
                if trace_marks then
                  logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%s,%s)",
                    pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                end
                return start,true
              end
            end
          end
          if trace_bugs then
            logwarning("%s, no matching anchors for mark %s and base %s",pref(kind,lookupname),gref(markchar),gref(basechar))
          end
        end
      else
        fonts.register_message(currentfont,basechar,"no base anchors")
      end
    elseif trace_bugs then
      logwarning("%s: prev node is no char",pref(kind,lookupname))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
  end
  return start,false
end
function handlers.gpos_mark2ligature(start,kind,lookupname,markanchors,sequence)
  local markchar=start.char
  if marks[markchar] then
    local base=start.prev 
    local index=1
    if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
      local basechar=base.char
      if marks[basechar] then
        index=index+1
        while true do
          base=base.prev
          if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
            basechar=base.char
            if marks[basechar] then
              index=index+1
            else
              break
            end
          else
            if trace_bugs then
              logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
            end
            return start,false
          end
        end
      end
      local i=has_attribute(start,markdone)
      if i then index=i end
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
                    local dx,dy,bound=set_mark(start,base,tfmdata.factor,rlmode,ba,ma,index)
                    if trace_marks then
                      logprocess("%s, anchor %s, index %s, bound %s: anchoring mark %s to baselig %s at index %s => (%s,%s)",
                        pref(kind,lookupname),anchor,index,bound,gref(markchar),gref(basechar),index,dx,dy)
                    end
                    return start,true
                  end
                end
              end
            end
            if trace_bugs then
              logwarning("%s: no matching anchors for mark %s and baselig %s",pref(kind,lookupname),gref(markchar),gref(basechar))
            end
          end
        end
      else
        fonts.register_message(currentfont,basechar,"no base anchors")
      end
    elseif trace_bugs then
      logwarning("%s: prev node is no char",pref(kind,lookupname))
    end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
  end
  return start,false
end
function handlers.gpos_mark2mark(start,kind,lookupname,markanchors,sequence)
  local markchar=start.char
  if marks[markchar] then
      local base=start.prev 
      if base and base.id==glyph and base.subtype<256 and base.font==currentfont then 
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
                    local dx,dy,bound=set_mark(start,base,tfmdata.factor,rlmode,ba,ma)
                    if trace_marks then
                      logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%s,%s)",
                        pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                    end
                    return start,true
                  end
                end
              end
              if trace_bugs then
                logwarning("%s: no matching anchors for mark %s and basemark %s",pref(kind,lookupname),gref(markchar),gref(basechar))
              end
            end
          end
        else
          fonts.register_message(currentfont,basechar,"no base anchors")
        end
      elseif trace_bugs then
        logwarning("%s: prev node is no mark",pref(kind,lookupname))
      end
  elseif trace_bugs then
    logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
  end
  return start,false
end
function handlers.gpos_cursive(start,kind,lookupname,exitanchors,sequence) 
  local alreadydone=cursonce and has_attribute(start,cursbase)
  if not alreadydone then
    local done=false
    local startchar=start.char
    if marks[startchar] then
      if trace_cursive then
        logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
      end
    else
      local nxt=start.next
      while not done and nxt and nxt.id==glyph and nxt.subtype<256 and nxt.font==currentfont do
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
                      local dx,dy,bound=set_cursive(start,nxt,tfmdata.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                      if trace_cursive then
                        logprocess("%s: moving %s to %s cursive (%s,%s) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                      end
                      done=true
                      break
                    end
                  end
                end
              end
            end
          else
            fonts.register_message(currentfont,startchar,"no entry anchors")
          end
          break
        end
      end
    end
    return start,done
  else
    if trace_cursive and trace_details then
      logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(start.char),alreadydone)
    end
    return start,false
  end
end
function handlers.gpos_single(start,kind,lookupname,kerns,sequence)
  local startchar=start.char
  local dx,dy,w,h=set_pair(start,tfmdata.factor,rlmode,sequence.flags[4],kerns,characters[startchar])
  if trace_kerns then
    logprocess("%s: shifting single %s by (%s,%s) and correction (%s,%s)",pref(kind,lookupname),gref(startchar),dx,dy,w,h)
  end
  return start,false
end
function handlers.gpos_pair(start,kind,lookupname,kerns,sequence)
  local snext=start.next
  if not snext then
    return start,false
  else
    local prev,done=start,false
    local factor=tfmdata.factor
    while snext and snext.id==glyph and snext.subtype<256 and snext.font==currentfont do
      local nextchar=snext.char
local krn=kerns[nextchar]
      if not krn and marks[nextchar] then
        prev=snext
        snext=snext.next
      else
        local krn=kerns[nextchar]
        if not krn then
        elseif type(krn)=="table" then
          if krn[1]=="pair" then
            local a,b=krn[3],krn[4]
            if a and #a>0 then
              local startchar=start.char
              local x,y,w,h=set_pair(start,factor,rlmode,sequence.flags[4],a,characters[startchar])
              if trace_kerns then
                logprocess("%s: shifting first of pair %s and %s by (%s,%s) and correction (%s,%s)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
              end
            end
            if b and #b>0 then
              local startchar=start.char
              local x,y,w,h=set_pair(snext,factor,rlmode,sequence.flags[4],b,characters[nextchar])
              if trace_kerns then
                logprocess("%s: shifting second of pair %s and %s by (%s,%s) and correction (%s,%s)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
              end
            end
          else
            logs.report("%s: check this out (old kern stuff)",pref(kind,lookupname))
            local a,b=krn[3],krn[7]
            if a and a~=0 then
              local k=set_kern(snext,factor,rlmode,a)
              if trace_kerns then
                logprocess("%s: inserting first kern %s between %s and %s",pref(kind,lookupname),k,gref(prev.char),gref(nextchar))
              end
            end
            if b and b~=0 then
              logwarning("%s: ignoring second kern xoff %s",pref(kind,lookupname),b*factor)
            end
          end
          done=true
        elseif krn~=0 then
          local k=set_kern(snext,factor,rlmode,krn)
          if trace_kerns then
            logprocess("%s: inserting kern %s between %s and %s",pref(kind,lookupname),k,gref(prev.char),gref(nextchar))
          end
          done=true
        end
        break
      end
    end
    return start,done
  end
end
local chainmores={}
local chainprocs={}
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  logs.report("otf subchain",...)
end
local function logwarning(...)
  logs.report("otf subchain",...)
end
function chainmores.chainsub(start,stop,kind,chainname,currentcontext,cache,lookuplist,chainlookupname,n)
  logprocess("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
  return start,false
end
function chainmores.gsub_multiple(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
  logprocess("%s: gsub_multiple not yet supported",cref(kind,chainname,chainlookupname))
  return start,false
end
function chainmores.gsub_alternate(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,n)
  logprocess("%s: gsub_alternate not yet supported",cref(kind,chainname,chainlookupname))
  return start,false
end
local function logprocess(...)
  if trace_steps then
    registermessage(...)
  end
  logs.report("otf chain",...)
end
local function logwarning(...)
  logs.report("otf chain",...)
end
function chainprocs.chainsub(start,stop,kind,chainname,currentcontext,cache,lookuplist,chainlookupname)
  logwarning("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
  return start,false
end
function chainprocs.reversesub(start,stop,kind,chainname,currentcontext,cache,replacements)
  local char=start.char
  local replacement=replacements[char]
  if replacement then
    if trace_singles then
      logprocess("%s: single reverse replacement of %s by %s",cref(kind,chainname),gref(char),gref(replacement))
    end
    start.char=replacement
    return start,true
  else
    return start,false
  end
end
local function delete_till_stop(start,stop,ignoremarks)
  if start~=stop then
    local done=false
    while not done do
      done=start==stop
      delete_node(start,start.next)
    end
  end
end
function chainprocs.gsub_single(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex)
  if not chainindex then
    delete_till_stop(start,stop) 
  end
  local current=start
  local subtables=currentlookup.subtables
  while current do
    if current.id==glyph then
      local currentchar=current.char
      local lookupname=subtables[1]
      local replacement=cache.gsub_single[lookupname]
      if not replacement then
        if trace_bugs then
          logwarning("%s: no single hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
        end
      else
        replacement=replacement[currentchar]
        if not replacement then
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
      return start,true
    elseif current==stop then
      break
    else
      current=current.next
    end
  end
  return start,false
end
chainmores.gsub_single=chainprocs.gsub_single
function chainprocs.gsub_multiple(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
  delete_till_stop(start,stop)
  local startchar=start.char
  local subtables=currentlookup.subtables
  local lookupname=subtables[1]
  local replacements=cache.gsub_multiple[lookupname]
  if not replacements then
    if trace_bugs then
      logwarning("%s: no multiple hits",cref(kind,chainname,chainlookupname,lookupname))
    end
  else
    replacements=replacements[startchar]
    if not replacements then
      if trace_bugs then
        logwarning("%s: no multiple for %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar))
      end
    else
      if trace_multiples then
        logprocess("%s: replacing %s by multiple characters %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar),gref(replacements))
      end
      local sn=start.next
      for k=1,#replacements do
        if k==1 then
          start.char=replacements[k]
        else
          local n=copy_node(start) 
          n.char=replacements[k]
          n.next,n.prev=sn,start
          if sn then
            sn.prev=n
          end
          start.next,start=n,n
        end
      end
      return start,true
    end
  end
  return start,false
end
function chainprocs.gsub_alternate(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
  delete_till_stop(start,stop)
  local current=start
  local subtables=currentlookup.subtables
  while current do
    if current.id==glyph then
      local currentchar=current.char
      local lookupname=subtables[1]
      local alternatives=cache.gsub_alternate[lookupname]
      if not alternatives then
        if trace_bugs then
          logwarning("%s: no alternative hits",cref(kind,chainname,chainlookupname,lookupname))
        end
      else
        alternatives=alternatives[currentchar]
        if not alternatives then
          if trace_bugs then
            logwarning("%s: no alternative for %s",cref(kind,chainname,chainlookupname,lookupname),gref(currentchar))
          end
        else
          local choice,index=alternative_glyph(current,alternatives,kind,chainname,chainlookupname,lookupname)
          current.char=choice
          if trace_alternatives then
            logprocess("%s: replacing single %s by alternative %s (%s)",cref(kind,chainname,chainlookupname,lookupname),index,gref(currentchar),gref(choice),index)
          end
        end
      end
      return start,true
    elseif current==stop then
      break
    else
      current=current.next
    end
  end
  return start,false
end
function chainprocs.gsub_ligature(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex)
  local startchar=start.char
  local subtables=currentlookup.subtables
  local lookupname=subtables[1]
  local ligatures=cache.gsub_ligature[lookupname]
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
      local s,discfound,last,nofreplacements=start.next,false,stop,0
      while s do
        local id=s.id
        if id==disc then
          s=s.next
          discfound=true
        else
          local schar=s.char
          if marks[schar] then 
            s=s.next
          else
            local lg=ligatures[1][schar]
            if not lg then
              break
            else
              ligatures,last,nofreplacements=lg,s,nofreplacements+1
              if s==stop then
                break
              else
                s=s.next
              end
            end
          end
        end
      end
      local l2=ligatures[2]
      if l2 then
        if chainindex then
          stop=last
        end
        if trace_ligatures then
          if start==stop then
            logprocess("%s: replacing character %s by ligature %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(l2))
          else
            logprocess("%s: replacing character %s upto %s by ligature %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(stop.char),gref(l2))
          end
        end
        start=toligature(kind,lookupname,start,stop,l2,currentlookup.flags[1],discfound)
        return start,true,nofreplacements
      elseif trace_bugs then
        if start==stop then
          logwarning("%s: replacing character %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
        else
          logwarning("%s: replacing character %s upto %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(stop.char))
        end
      end
    end
  end
  return start,false,0
end
chainmores.gsub_ligature=chainprocs.gsub_ligature
function chainprocs.gpos_mark2base(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
  local markchar=start.char
  if marks[markchar] then
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local markanchors=cache.gpos_mark2base[lookupname]
    if markanchors then
      markanchors=markanchors[markchar]
    end
    if markanchors then
      local base=start.prev 
      if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
        local basechar=base.char
        if marks[basechar] then
          while true do
            base=base.prev
            if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
              basechar=base.char
              if not marks[basechar] then
                break
              end
            else
              if trace_bugs then
                logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
              end
              return start,false
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
                  local dx,dy,bound=set_mark(start,base,tfmdata.factor,rlmode,ba,ma)
                  if trace_marks then
                    logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%s,%s)",
                      cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                  end
                  return start,true
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
  return start,false
end
function chainprocs.gpos_mark2ligature(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
  local markchar=start.char
  if marks[markchar] then
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local markanchors=cache.gpos_mark2ligature[lookupname]
    if markanchors then
      markanchors=markanchors[markchar]
    end
    if markanchors then
      local base=start.prev 
      local index=1
      if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
        local basechar=base.char
        if marks[basechar] then
          index=index+1
          while true do
            base=base.prev
            if base and base.id==glyph and base.subtype<256 and base.font==currentfont then
              basechar=base.char
              if marks[basechar] then
                index=index+1
              else
                break
              end
            else
              if trace_bugs then
                logwarning("%s: no base for mark %s",cref(kind,chainname,chainlookupname,lookupname),markchar)
              end
              return start,false
            end
          end
        end
        local i=has_attribute(start,markdone)
        if i then index=i end
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
                    local dx,dy,bound=set_mark(start,base,tfmdata.factor,rlmode,ba,ma,index)
                    if trace_marks then
                      logprocess("%s, anchor %s, bound %s: anchoring mark %s to baselig %s at index %s => (%s,%s)",
                        cref(kind,chainname,chainlookupname,lookupname),anchor,a or bound,gref(markchar),gref(basechar),index,dx,dy)
                    end
                    return start,true
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
  return start,false
end
function chainprocs.gpos_mark2mark(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
  local markchar=start.char
  if marks[markchar] then
      local subtables=currentlookup.subtables
      local lookupname=subtables[1]
      local markanchors=cache.gpos_mark2mark[lookupname]
      if markanchors then
        markanchors=markanchors[markchar]
      end
      if markanchors then
        local base=start.prev 
        if base and base.id==glyph and base.subtype<256 and base.font==currentfont then 
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
                    local dx,dy,bound=set_mark(start,base,tfmdata.factor,rlmode,ba,ma)
                    if trace_marks then
                      logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%s,%s)",
                        cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                    end
                    return start,true
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
  return start,false
end
function chainprocs.gpos_cursive(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname)
  local alreadydone=cursonce and has_attribute(start,cursbase)
  if not alreadydone then
    local startchar=start.char
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local exitanchors=cache.gpos_cursive[lookupname]
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
        while not done and nxt and nxt.id==glyph and nxt.subtype<256 and nxt.font==currentfont do
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
                        local dx,dy,bound=set_cursive(start,nxt,tfmdata.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                        if trace_cursive then
                          logprocess("%s: moving %s to %s cursive (%s,%s) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                        end
                        done=true
                        break
                      end
                    end
                  end
                end
              end
            else
              fonts.register_message(currentfont,startchar,"no entry anchors")
            end
            break
          end
        end
      end
      return start,done
    else
      if trace_cursive and trace_details then
        logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(start.char),alreadydone)
      end
      return start,false
    end
  end
  return start,false
end
function chainprocs.gpos_single(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex,sequence)
  local startchar=start.char
  local subtables=currentlookup.subtables
  local lookupname=subtables[1]
  local kerns=cache.gpos_single[lookupname]
  if kerns then
    kerns=kerns[startchar]
    if kerns then
      local dx,dy,w,h=set_pair(start,tfmdata.factor,rlmode,sequence.flags[4],kerns,characters[startchar])
      if trace_kerns then
        logprocess("%s: shifting single %s by (%s,%s) and correction (%s,%s)",cref(kind,chainname,chainlookupname),gref(startchar),dx,dy,w,h)
      end
    end
  end
  return start,false
end
function chainprocs.gpos_pair(start,stop,kind,chainname,currentcontext,cache,currentlookup,chainlookupname,chainindex,sequence)
  local snext=start.next
  if snext then
    local startchar=start.char
    local subtables=currentlookup.subtables
    local lookupname=subtables[1]
    local kerns=cache.gpos_pair[lookupname]
    if kerns then
      kerns=kerns[startchar]
      if kerns then
        local prev,done=start,false
        local factor=tfmdata.factor
        while snext and snext.id==glyph and snext.subtype<256 and snext.font==currentfont do
          local nextchar=snext.char
          local krn=kerns[nextchar]
          if not krn and marks[nextchar] then
            prev=snext
            snext=snext.next
          else
            if not krn then
            elseif type(krn)=="table" then
              if krn[1]=="pair" then
                local a,b=krn[3],krn[4]
                if a and #a>0 then
                  local startchar=start.char
                  local x,y,w,h=set_pair(start,factor,rlmode,sequence.flags[4],a,characters[startchar])
                  if trace_kerns then
                    logprocess("%s: shifting first of pair %s and %s by (%s,%s) and correction (%s,%s)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                  end
                end
                if b and #b>0 then
                  local startchar=start.char
                  local x,y,w,h=set_pair(snext,factor,rlmode,sequence.flags[4],b,characters[nextchar])
                  if trace_kerns then
                    logprocess("%s: shifting second of pair %s and %s by (%s,%s) and correction (%s,%s)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                  end
                end
              else
                logs.report("%s: check this out (old kern stuff)",cref(kind,chainname,chainlookupname))
                local a,b=krn[3],krn[7]
                if a and a~=0 then
                  local k=set_kern(snext,factor,rlmode,a)
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
              local k=set_kern(snext,factor,rlmode,krn)
              if trace_kerns then
                logprocess("%s: inserting kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(prev.char),gref(nextchar))
              end
              done=true
            end
            break
          end
        end
        return start,done
      end
    end
  end
  return start,false
end
local function show_skip(kind,chainname,char,ck,class)
  if ck[9] then
    logwarning("%s: skipping char %s (%s) in rule %s, lookuptype %s (%s=>%s)",cref(kind,chainname),gref(char),class,ck[1],ck[2],ck[9],ck[10])
  else
    logwarning("%s: skipping char %s (%s) in rule %s, lookuptype %s",cref(kind,chainname),gref(char),class,ck[1],ck[2])
  end
end
local function normal_handle_contextchain(start,kind,chainname,contexts,sequence,cache)
  local flags,done=sequence.flags,false
  local skipmark,skipligature,skipbase=flags[1],flags[2],flags[3]
  local someskip=skipmark or skipligature or skipbase 
  local markclass=sequence.markclass 
  local skipped=false
  for k=1,#contexts do
    local match,current,last=true,start,start
    local ck=contexts[k]
    local seq=ck[3]
    local s=#seq
    if s==1 then
      match=current.id==glyph and current.subtype<256 and current.font==currentfont and seq[1][current.char]
    else
      local f,l=ck[4],ck[5]
      if f==l then
        match=true
      else
        local n=f+1
        last=last.next
          while n<=l do
            if last then
              local id=last.id
              if id==glyph then
                if last.subtype<256 and last.font==currentfont then
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
                      match=false break
                    end
                  else
                    match=false break
                  end
                else
                  match=false break
                end
              elseif id==disc then 
                last=last.next
              else
                match=false break
              end
            else
              match=false break
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
              if id==glyph then
                if prev.subtype<256 and prev.font==currentfont then 
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
                      match=false break
                    end
                  else
                    match=false break
                  end
                else
                  match=false break
                end
              elseif id==disc then
              elseif seq[n][32] then
                n=n -1
              else
                match=false break
              end
              prev=prev.prev
            elseif seq[n][32] then
              n=n -1
            else
              match=false break
            end
          end
        elseif f==2 then
          match=seq[1][32]
        else
          for n=f-1,1 do
            if not seq[n][32] then
              match=false break
            end
          end
        end
      end
      if match and s>l then
        local current=last.next
        if current then
          local n=l+1
          while n<=s do
            if current then
              local id=current.id
              if id==glyph then
                if current.subtype<256 and current.font==currentfont then 
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
                      match=false break
                    end
                  else
                    match=false break
                  end
                else
                  match=false break
                end
              elseif id==disc then
              elseif seq[n][32] then 
                n=n+1
              else
                match=false break
              end
              current=current.next
            elseif seq[n][32] then
              n=n+1
            else
              match=false break
            end
          end
        elseif s-l==1 then
          match=seq[s][32]
        else
          for n=l+1,s do
            if not seq[n][32] then
              match=false break
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
          logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %s (%s=>%s)",cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype,ck[9],ck[10])
        else
          logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %s",cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype)
        end
      end
      local chainlookups=ck[6]
      if chainlookups then
        local nofchainlookups=#chainlookups
        if nofchainlookups==1 then
          local chainlookupname=chainlookups[1]
          local chainlookup=lookuptable[chainlookupname]
          local cp=chainprocs[chainlookup.type]
          if cp then
            start,done=cp(start,last,kind,chainname,ck,cache,chainlookup,chainlookupname,nil,sequence)
          else
            logprocess("%s: %s is not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
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
            local cp=chainmores[chainlookup.type]
            if cp then
              local ok,n
              start,ok,n=cp(start,last,kind,chainname,ck,cache,chainlookup,chainlookupname,i,sequence)
              if ok then
                done=true
                i=i+(n or 1)
              else
                i=i+1
              end
            else
              logprocess("%s: multiple subchains for %s are not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
              i=i+1
            end
            start=start.next
          until i>nofchainlookups
        end
      else
        local replacements=ck[7]
        if replacements then
          start,done=chainprocs.reversesub(start,last,kind,chainname,ck,cache,replacements) 
        else
          done=true 
          if trace_contexts then
            logprocess("%s: skipping match",cref(kind,chainname))
          end
        end
      end
    end
  end
  return start,done
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
    logwarning("installing contextchain handler '%s'",method)
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
  logs.report("otf process",...)
end
local function logwarning(...)
  logs.report("otf process",...)
end
local function report_missing_cache(typ,lookup)
  local f=missing[currentfont] if not f then f={} missing[currentfont]=f end
  local t=f[typ]        if not t then t={} f[typ]=t end
  if not t[lookup] then
    t[lookup]=true
    logwarning("missing cache for lookup %s of type %s in font %s (%s)",lookup,typ,currentfont,tfmdata.fullname)
  end
end
local resolved={}
function fonts.methods.node.otf.features(head,font,attr)
  if trace_steps then
    checkstep(head)
  end
  tfmdata=fontdata[font]
  local shared=tfmdata.shared
  otfdata=shared.otfdata
  local luatex=otfdata.luatex
  descriptions=tfmdata.descriptions
  characters=tfmdata.characters
  indices=tfmdata.indices
  unicodes=tfmdata.unicodes
  marks=tfmdata.marks
  anchorlookups=luatex.lookup_to_anchor
  currentfont=font
  rlmode=0
  local featuredata=otfdata.shared.featuredata 
  local sequences=luatex.sequences
  lookuptable=luatex.lookups
  local done=false
  local script,language,s_enabled,a_enabled,dyn
  local attribute_driven=attr and attr~=0
  if attribute_driven then
    local features=context_setups[context_numbers[attr]] 
    dyn=context_merged[attr] or 0
    language,script=features.language or "dflt",features.script or "dflt"
    a_enabled=features 
    if dyn==2 or dyn==-2 then
      s_enabled=shared.features
    end
  else
    language,script=tfmdata.language or "dflt",tfmdata.script or "dflt"
    s_enabled=shared.features 
    dyn=0
  end
  local res=resolved[font]   if not res  then res={} resolved[font]=res end
  local rs=res   [script]  if not rs  then rs={} res   [script]=rs end
  local rl=rs   [language] if not rl  then rl={} rs   [language]=rl end
  local ra=rl   [attr]   if ra==nil then ra={} rl   [attr]=ra end
  for s=1,#sequences do
    local pardir,txtdir,success=0,{},false
    local sequence=sequences[s]
    local r=ra[s] 
    if r==nil then
      local chain=sequence.chain or 0
      local features=sequence.features
      if not features then
        r=false 
      else
        local valid,attribute,kind,what=false,false
        for k,v in next,features do
          local s_e=s_enabled and s_enabled[k]
          local a_e=a_enabled and a_enabled[k]
          if s_e or a_e then
            local l=v[script] or v[wildcard]
            if l then
              if l[language] then
                valid,what=s_e or a_e,language
              elseif l[wildcard] then
                valid,what=s_e or a_e,wildcard
              end
              if valid then
                kind,attribute=k,special_attributes[k] or false
                if a_e and dyn<0 then
                  valid=false
                end
                if trace_applied then
                  local typ,action=match(sequence.type,"(.*)_(.*)")
                  logs.report("otf node mode",
                    "%s font: %03i, dynamic: %03i, kind: %s, lookup: %3i, script: %-4s, language: %-4s (%-4s), type: %s, action: %s, name: %s",
                    (valid and "+") or "-",font,attr or 0,kind,s,script,language,what,typ,action,sequence.name)
                end
                break
              end
            end
          end
        end
        if valid then
          r={ valid,attribute,chain,kind }
        else
          r=false 
        end
      end
      ra[s]=r
    end
    featurevalue=r and r[1] 
    if featurevalue then
      local attribute,chain,typ,subtables=r[2],r[3],sequence.type,sequence.subtables
      if chain<0 then
        local handler=handlers[typ]
        local thecache=featuredata[typ] or {}
        local start=find_node_tail(head) 
        while start do
          local id=start.id
          if id==glyph then
            if start.subtype<256 and start.font==font then
              local a=has_attribute(start,0)
              if a then
                a=a==attr
              else
                a=true
              end
              if a then
                for i=1,#subtables do
                  local lookupname=subtables[i]
                  local lookupcache=thecache[lookupname]
                  if lookupcache then
                    local lookupmatch=lookupcache[start.char]
                    if lookupmatch then
                      start,success=handler(start,r[4],lookupname,lookupmatch,sequence,featuredata,i)
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
        local thecache=featuredata[typ] or {}
        local start=head 
        rlmode=0 
        if ns==1 then
          local lookupname=subtables[1]
          local lookupcache=thecache[lookupname]
          if not lookupcache then
            report_missing_cache(typ,lookupname)
          else
            while start do
              local id=start.id
              if id==glyph then
                if start.subtype<256 and start.font==font then
                  local a=has_attribute(start,0)
                  if a then
                    a=(a==attr) and (not attribute or has_attribute(start,state,attribute))
                  else
                    a=not attribute or has_attribute(start,state,attribute)
                  end
                  if a then
                    local lookupmatch=lookupcache[start.char]
                    if lookupmatch then
                      local ok
                      start,ok=handler(start,r[4],lookupname,lookupmatch,sequence,featuredata,1)
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
              elseif id==whatsit then
                local subtype=start.subtype
                if subtype==7 then
                  local dir=start.dir
                  if   dir=="+TRT" or dir=="+TLT" then
                    insert(txtdir,dir)
                  elseif dir=="-TRT" or dir=="-TLT" then
                    remove(txtdir)
                  end
                  local d=txtdir[#txtdir]
                  if d=="+TRT" then
                    rlmode=-1
                  elseif d=="+TLT" then
                    rlmode=1
                  else
                    rlmode=pardir
                  end
                  if trace_directions then
                    logs.report("fonts","directions after textdir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                  end
                elseif subtype==6 then
                  local dir=start.dir
                  if dir=="TRT" then
                    pardir=-1
                  elseif dir=="TLT" then
                    pardir=1
                  else
                    pardir=0
                  end
                  rlmode=pardir
                  if trace_directions then
                    logs.report("fonts","directions after pardir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                  end
                end
                start=start.next
              else
                start=start.next
              end
            end
          end
        else
          while start do
            local id=start.id
            if id==glyph then
              if start.subtype<256 and start.font==font then
                local a=has_attribute(start,0)
                if a then
                  a=(a==attr) and (not attribute or has_attribute(start,state,attribute))
                else
                  a=not attribute or has_attribute(start,state,attribute)
                end
                if a then
                  for i=1,ns do
                    local lookupname=subtables[i]
                    local lookupcache=thecache[lookupname]
                    if lookupcache then
                      local lookupmatch=lookupcache[start.char]
                      if lookupmatch then
                        local ok
                        start,ok=handler(start,r[4],lookupname,lookupmatch,sequence,featuredata,i)
                        if ok then
                          success=true
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
            elseif id==whatsit then
              local subtype=start.subtype
              if subtype==7 then
                local dir=start.dir
                if   dir=="+TRT" or dir=="+TLT" then
                  insert(txtdir,dir)
                elseif dir=="-TRT" or dir=="-TLT" then
                  remove(txtdir)
                end
                local d=txtdir[#txtdir]
                if d=="+TRT" then
                  rlmode=-1
                elseif d=="+TLT" then
                  rlmode=1
                else
                  rlmode=pardir
                end
                if trace_directions then
                  logs.report("fonts","directions after textdir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                end
              elseif subtype==6 then
                local dir=start.dir
                if dir=="TRT" then
                  pardir=-1
                elseif dir=="TLT" then
                  pardir=1
                else
                  pardir=0
                end
                rlmode=pardir
                if trace_directions then
                  logs.report("fonts","directions after pardir %s: pardir=%s, txtdir=%s:%s, rlmode=%s",dir,pardir,#txtdir,txtdir[#txtdir] or "unset",rlmode)
                end
              end
              start=start.next
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
  end
  return head,done
end
otf.features.prepare={}
local function split(replacement,original,cache,unicodes)
  local o,t,n={},{},0
  for s in gmatch(original,"[^ ]+") do
    local us=unicodes[s]
    if type(us)=="number" then 
      o[#o+1]=us
    else
      o[#o+1]=us[1]
    end
  end
  for s in gmatch(replacement,"[^ ]+") do
    n=n+1
    local us=unicodes[s]
    if type(us)=="number" then 
      t[o[n]]=us
    else
      t[o[n]]=us[1]
    end
  end
  return t
end
local function uncover(covers,result,cache,unicodes)
  for n=1,#covers do
    local c=covers[n]
    local cc=cache[c]
    if not cc then
      local t={}
      for s in gmatch(c,"[^ ]+") do
        local us=unicodes[s]
        if type(us)=="number" then
          t[us]=true
        else
          for i=1,#us do
            t[us[i]]=true
          end
        end
      end
      cache[c]=t
      result[#result+1]=t
    else
      result[#result+1]=cc
    end
  end
end
local function prepare_lookups(tfmdata)
  local otfdata=tfmdata.shared.otfdata
  local featuredata=otfdata.shared.featuredata
  local anchor_to_lookup=otfdata.luatex.anchor_to_lookup
  local lookup_to_anchor=otfdata.luatex.lookup_to_anchor
  local multiple=featuredata.gsub_multiple
  local alternate=featuredata.gsub_alternate
  local single=featuredata.gsub_single
  local ligature=featuredata.gsub_ligature
  local pair=featuredata.gpos_pair
  local position=featuredata.gpos_single
  local kerns=featuredata.gpos_pair
  local mark=featuredata.gpos_mark2mark
  local cursive=featuredata.gpos_cursive
  local unicodes=tfmdata.unicodes 
  local indices=tfmdata.indices
  local descriptions=tfmdata.descriptions
  local action={
    substitution=function(p,lookup,glyph,unicode)
      local old,new=unicode,unicodes[p[2]]
      if type(new)=="table" then
        new=new[1]
      end
      local s=single[lookup]
      if not s then s={} single[lookup]=s end
      s[old]=new
    end,
    multiple=function (p,lookup,glyph,unicode)
      local old,new=unicode,{}
      local m=multiple[lookup]
      if not m then m={} multiple[lookup]=m end
      m[old]=new
      for pc in gmatch(p[2],"[^ ]+") do
        local upc=unicodes[pc]
        if type(upc)=="number" then
          new[#new+1]=upc
        else
          new[#new+1]=upc[1]
        end
      end
    end,
    alternate=function(p,lookup,glyph,unicode)
      local old,new=unicode,{}
      local a=alternate[lookup]
      if not a then a={} alternate[lookup]=a end
      a[old]=new
      for pc in gmatch(p[2],"[^ ]+") do
        local upc=unicodes[pc]
        if type(upc)=="number" then
          new[#new+1]=upc
        else
          new[#new+1]=upc[1]
        end
      end
    end,
    ligature=function (p,lookup,glyph,unicode)
      local first=true
      local t=ligature[lookup]
      if not t then t={} ligature[lookup]=t end
      for s in gmatch(p[2],"[^ ]+") do
        if first then
          local u=unicodes[s]
          if not u then
            logs.report("define otf","lookup %s: ligature %s => %s ignored due to invalid unicode",lookup,p[2],glyph.name)
            break
          elseif type(u)=="number" then
            if not t[u] then
              t[u]={ {} }
            end
            t=t[u]
          else
            local tt=t
            local tu
            for i=1,#u do
              local u=u[i]
              if i==1 then
                if not t[u] then
                  t[u]={ {} }
                end
                tu=t[u]
                t=tu
              else
                if not t[u] then
                  tt[u]=tu
                end
              end
            end
          end
          first=false
        else
          s=unicodes[s]
          local t1=t[1]
          if not t1[s] then
            t1[s]={ {} }
          end
          t=t1[s]
        end
      end
      t[2]=unicode
    end,
    position=function(p,lookup,glyph,unicode)
      local s=position[lookup]
      if not s then s={} position[lookup]=s end
      s[unicode]=p[2] 
    end,
    pair=function(p,lookup,glyph,unicode)
      local s=pair[lookup]
      if not s then s={} pair[lookup]=s end
      local others=s[unicode]
      if not others then others={} s[unicode]=others end
      local two=p[2]
      local upc=unicodes[two]
      if not upc then
        for pc in gmatch(two,"[^ ]+") do
          local upc=unicodes[pc]
          if type(upc)=="number" then
            others[upc]=p 
          else
            for i=1,#upc do
              others[upc[i]]=p 
            end
          end
        end
      elseif type(upc)=="number" then
        others[upc]=p 
      else
        for i=1,#upc do
          others[upc[i]]=p 
        end
      end
    end,
  }
  for unicode,glyph in next,descriptions do
    local lookups=glyph.slookups
    if lookups then
      for lookup,p in next,lookups do
        action[p[1]](p,lookup,glyph,unicode)
      end
    end
    local lookups=glyph.mlookups
    if lookups then
      for lookup,whatever in next,lookups do
        for i=1,#whatever do 
          local p=whatever[i]
          action[p[1]](p,lookup,glyph,unicode)
        end
      end
    end
    local list=glyph.mykerns
    if list then
      for lookup,krn in next,list do
        local k=kerns[lookup]
        if not k then k={} kerns[lookup]=k end
        k[unicode]=krn
      end
    end
    local oanchor=glyph.anchors
    if oanchor then
      for typ,anchors in next,oanchor do 
        if typ=="mark" then
          for name,anchor in next,anchors do
            local lookups=anchor_to_lookup[name]
            if lookups then
              for lookup,_ in next,lookups do
                local f=mark[lookup]
                if not f then f={} mark[lookup]=f end
                f[unicode]=anchors
              end
            end
          end
        elseif typ=="cexit" then 
          for name,anchor in next,anchors do
            local lookups=anchor_to_lookup[name]
            if lookups then
              for lookup,_ in next,lookups do
                local f=cursive[lookup]
                if not f then f={} cursive[lookup]=f end
                f[unicode]=anchors
              end
            end
          end
        end
      end
    end
  end
end
luatex=luatex or {} 
local function prepare_contextchains(tfmdata)
  local otfdata=tfmdata.shared.otfdata
  local lookups=otfdata.lookups
  if lookups then
    local featuredata=otfdata.shared.featuredata
    local contextchain=featuredata.gsub_contextchain 
    local reversecontextchain=featuredata.gsub_reversecontextchain 
    local characters=tfmdata.characters
    local unicodes=tfmdata.unicodes
    local indices=tfmdata.indices
    local cache=luatex.covers
    if not cache then
      cache={}
      luatex.covers=cache
    end
    for lookupname,lookupdata in next,otfdata.lookups do
      local lookuptype=lookupdata.type
      if not lookuptype then
        logs.report("otf process","missing lookuptype for %s",lookupname)
      else
        local rules=lookupdata.rules
        if rules then
          local fmt=lookupdata.format
          if fmt=="coverage" then
            if lookuptype~="chainsub" and lookuptype~="chainpos" then
              logs.report("otf process","unsupported coverage %s for %s",lookuptype,lookupname)
            else
              local contexts=contextchain[lookupname]
              if not contexts then
                contexts={}
                contextchain[lookupname]=contexts
              end
              local t={}
              for nofrules=1,#rules do 
                local rule=rules[nofrules]
                local coverage=rule.coverage
                if coverage and coverage.current then
                  local current,before,after,sequence=coverage.current,coverage.before,coverage.after,{}
                  if before then
                    uncover(before,sequence,cache,unicodes)
                  end
                  local start=#sequence+1
                  uncover(current,sequence,cache,unicodes)
                  local stop=#sequence
                  if after then
                    uncover(after,sequence,cache,unicodes)
                  end
                  if sequence[1] then
                    t[#t+1]={ nofrules,lookuptype,sequence,start,stop,rule.lookups }
                    for unic,_ in next,sequence[start] do
                      local cu=contexts[unic]
                      if not cu then
                        contexts[unic]=t
                      end
                    end
                  end
                end
              end
            end
          elseif fmt=="reversecoverage" then
            if lookuptype~="reversesub" then
              logs.report("otf process","unsupported reverse coverage %s for %s",lookuptype,lookupname)
            else
              local contexts=reversecontextchain[lookupname]
              if not contexts then
                contexts={}
                reversecontextchain[lookupname]=contexts
              end
              local t={}
              for nofrules=1,#rules do
                local rule=rules[nofrules]
                local reversecoverage=rule.reversecoverage
                if reversecoverage and reversecoverage.current then
                  local current,before,after,replacements,sequence=reversecoverage.current,reversecoverage.before,reversecoverage.after,reversecoverage.replacements,{}
                  if before then
                    uncover(before,sequence,cache,unicodes)
                  end
                  local start=#sequence+1
                  uncover(current,sequence,cache,unicodes)
                  local stop=#sequence
                  if after then
                    uncover(after,sequence,cache,unicodes)
                  end
                  if replacements then
                    replacements=split(replacements,current[1],cache,unicodes)
                  end
                  if sequence[1] then
                    t[#t+1]={ nofrules,lookuptype,sequence,start,stop,rule.lookups,replacements }
                    for unic,_ in next,sequence[start] do
                      local cu=contexts[unic]
                      if not cu then
                        contexts[unic]=t
                      end
                    end
                  end
                end
              end
            end
          elseif fmt=="glyphs" then
            if lookuptype~="chainsub" and lookuptype~="chainpos" then
              logs.report("otf process","unsupported coverage %s for %s",lookuptype,lookupname)
            else
              local contexts=contextchain[lookupname]
              if not contexts then
                contexts={}
                contextchain[lookupname]=contexts
              end
              local t={}
              for nofrules=1,#rules do
                local rule=rules[nofrules]
                local glyphs=rule.glyphs
                if glyphs and glyphs.names then
                  local fore,back,names,sequence=glyphs.fore,glyphs.back,glyphs.names,{}
                  if fore and fore~="" then
                    fore=lpegmatch(split_at_space,fore)
                    uncover(fore,sequence,cache,unicodes)
                  end
                  local start=#sequence+1
                  names=lpegmatch(split_at_space,names)
                  uncover(names,sequence,cache,unicodes)
                  local stop=#sequence
                  if back and back~="" then
                    back=lpegmatch(split_at_space,back)
                    uncover(back,sequence,cache,unicodes)
                  end
                  if sequence[1] then
                    t[#t+1]={ nofrules,lookuptype,sequence,start,stop,rule.lookups }
                    for unic,_ in next,sequence[start] do
                      local cu=contexts[unic]
                      if not cu then
                        contexts[unic]=t
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
end
function fonts.initializers.node.otf.features(tfmdata,value)
  if true then 
    if not tfmdata.shared.otfdata.shared.initialized then
      local t=trace_preparing and os.clock()
      local otfdata=tfmdata.shared.otfdata
      local featuredata=otfdata.shared.featuredata
      featuredata.gsub_multiple={}
      featuredata.gsub_alternate={}
      featuredata.gsub_single={}
      featuredata.gsub_ligature={}
      featuredata.gsub_contextchain={}
      featuredata.gsub_reversecontextchain={}
      featuredata.gpos_pair={}
      featuredata.gpos_single={}
      featuredata.gpos_mark2base={}
      featuredata.gpos_mark2ligature=featuredata.gpos_mark2base
      featuredata.gpos_mark2mark=featuredata.gpos_mark2base
      featuredata.gpos_cursive={}
      featuredata.gpos_contextchain=featuredata.gsub_contextchain
      featuredata.gpos_reversecontextchain=featuredata.gsub_reversecontextchain
      prepare_contextchains(tfmdata)
      prepare_lookups(tfmdata)
      otfdata.shared.initialized=true
      if trace_preparing then
        logs.report("otf process","preparation time is %0.3f seconds for %s",os.clock()-t,tfmdata.fullname or "?")
      end
    end
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
local type,tostring,match,format,concat=type,tostring,string.match,string.format,table.concat
if not trackers then trackers={ register=function() end } end
local trace_analyzing=false trackers.register("otf.analyzing",function(v) trace_analyzing=v end)
local trace_cjk=false trackers.register("cjk.injections",function(v) trace_cjk=v end)
trackers.register("cjk.analyzing","otf.analyzing")
fonts=fonts            or {}
fonts.analyzers=fonts.analyzers       or {}
fonts.analyzers.initializers=fonts.analyzers.initializers or { node={ otf={} } }
fonts.analyzers.methods=fonts.analyzers.methods   or { node={ otf={} } }
local otf=fonts.otf
local tfm=fonts.tfm
local initializers=fonts.analyzers.initializers
local methods=fonts.analyzers.methods
local glyph=node.id('glyph')
local glue=node.id('glue')
local penalty=node.id('penalty')
local set_attribute=node.set_attribute
local has_attribute=node.has_attribute
local traverse_id=node.traverse_id
local traverse_node_list=node.traverse
local fontdata=fonts.ids
local state=attributes.private('state')
local fcs=(fonts.color and fonts.color.set)  or function() end
local fcr=(fonts.color and fonts.color.reset) or function() end
local a_to_script=otf.a_to_script
local a_to_language=otf.a_to_language
function fonts.initializers.node.otf.analyze(tfmdata,value,attr)
  local script,language
  if attr and attr>0 then
    script,language=a_to_script[attr],a_to_language[attr]
  else
    script,language=tfmdata.script,tfmdata.language
  end
  local action=initializers[script]
  if action then
    if type(action)=="function" then
      return action(tfmdata,value)
    else
      local action=action[language]
      if action then
        return action(tfmdata,value)
      end
    end
  end
  return nil
end
function fonts.methods.node.otf.analyze(head,font,attr)
  local tfmdata=fontdata[font]
  local script,language
  if attr and attr>0 then
    script,language=a_to_script[attr],a_to_language[attr]
  else
    script,language=tfmdata.script,tfmdata.language
  end
  local action=methods[script]
  if action then
    if type(action)=="function" then
      return action(head,font,attr)
    else
      action=action[language]
      if action then
        return action(head,font,attr)
      end
    end
  end
  return head,false
end
otf.features.register("analyze",true)  
table.insert(fonts.triggers,"analyze")
fonts.analyzers.methods.latn=fonts.analyzers.aux.setstate
local zwnj=0x200C
local zwj=0x200D
local isol={
  [0x0600]=true,[0x0601]=true,[0x0602]=true,[0x0603]=true,
  [0x0608]=true,[0x060B]=true,[0x0621]=true,[0x0674]=true,
  [0x06DD]=true,[zwnj]=true,
}
local isol_fina={
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
	[0x0778]=true,[0x0779]=true,[0xFEF5]=true,[0xFEF7]=true,
	[0xFEF9]=true,[0xFEFB]=true,
}
local isol_fina_medi_init={
  [0x0626]=true,[0x0628]=true,[0x062A]=true,[0x062B]=true,
  [0x062C]=true,[0x062D]=true,[0x062E]=true,[0x0633]=true,
  [0x0634]=true,[0x0635]=true,[0x0636]=true,[0x0637]=true,
  [0x0638]=true,[0x0639]=true,[0x063A]=true,[0x063B]=true,
  [0x063C]=true,[0x063D]=true,[0x063E]=true,[0x063F]=true,
  [0x0640]=true,[0x0641]=true,[0x0642]=true,[0x0643]=true,
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
  [0x077E]=true,[0x077F]=true,[zwj]=true,
}
local arab_warned={}
local function warning(current,what)
  local char=current.char
  if not arab_warned[char] then
    log.report("analyze","arab: character %s (U+%04X) has no %s class",char,char,what)
    arab_warned[char]=true
  end
end
function fonts.analyzers.methods.nocolor(head,font,attr)
  for n in traverse_node_list(head,glyph) do
    if not font or n.font==font then
      fcr(n)
    end
  end
  return head,true
end
local function finish(first,last)
  if last then
    if first==last then
      local fc=first.char
      if isol_fina_medi_init[fc] or isol_fina[fc] then
        set_attribute(first,state,4) 
        if trace_analyzing then fcs(first,"font:isol") end
      else
        warning(first,"isol")
        set_attribute(first,state,0) 
        if trace_analyzing then fcr(first) end
      end
    else
      local lc=last.char
      if isol_fina_medi_init[lc] or isol_fina[lc] then
        set_attribute(last,state,3) 
        if trace_analyzing then fcs(last,"font:fina") end
      else
        warning(last,"fina")
        set_attribute(last,state,0) 
        if trace_analyzing then fcr(last) end
      end
    end
    first,last=nil,nil
  elseif first then
    local fc=first.char
    if isol_fina_medi_init[fc] or isol_fina[fc] then
      set_attribute(first,state,4) 
      if trace_analyzing then fcs(first,"font:isol") end
    else
      warning(first,"isol")
      set_attribute(first,state,0) 
      if trace_analyzing then fcr(first) end
    end
    first=nil
  end
  return first,last
end
function fonts.analyzers.methods.arab(head,font,attr) 
  local tfmdata=fontdata[font]
  local marks=tfmdata.marks
  local first,last,current,done=nil,nil,head,false
  while current do
    if current.id==glyph and current.subtype<256 and current.font==font and not has_attribute(current,state) then
      done=true
      local char=current.char
      if marks[char] then
        set_attribute(current,state,5) 
        if trace_analyzing then fcs(current,"font:mark") end
      elseif isol[char] then 
        first,last=finish(first,last)
        set_attribute(current,state,4) 
        if trace_analyzing then fcs(current,"font:isol") end
        first,last=nil,nil
      elseif not first then
        if isol_fina_medi_init[char] then
          set_attribute(current,state,1) 
          if trace_analyzing then fcs(current,"font:init") end
          first,last=first or current,current
        elseif isol_fina[char] then
          set_attribute(current,state,4) 
          if trace_analyzing then fcs(current,"font:isol") end
          first,last=nil,nil
        else 
          first,last=finish(first,last)
        end
      elseif isol_fina_medi_init[char] then
        first,last=first or current,current
        set_attribute(current,state,2) 
        if trace_analyzing then fcs(current,"font:medi") end
      elseif isol_fina[char] then
        if not has_attribute(last,state,1) then
          set_attribute(last,state,2) 
          if trace_analyzing then fcs(last,"font:medi") end
        end
        set_attribute(current,state,3) 
        if trace_analyzing then fcs(current,"font:fina") end
        first,last=nil,nil
      elseif char>=0x0600 and char<=0x06FF then
        if trace_analyzing then fcs(current,"font:rest") end
        first,last=finish(first,last)
      else 
        first,last=finish(first,last)
      end
    else
      first,last=finish(first,last)
    end
    current=current.next
  end
  first,last=finish(first,last)
  return head,done
end

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-otc']={
  version=1.001,
  comment="companion to font-otf.lua (context)",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local format,insert=string.format,table.insert
local type,next=type,next
local trace_loading=false trackers.register("otf.loading",function(v) trace_loading=v end)
local otf=fonts.otf
local tfm=fonts.tfm
local extra_lists={
  tlig={
    {
      endash="hyphen hyphen",
      emdash="hyphen hyphen hyphen",
      quotedblleft="quoteleft quoteleft",
      quotedblright="quoteright quoteright",
      quotedblleft="grave grave",
      quotedblright="quotesingle quotesingle",
      quotedblbase="comma comma",
      exclamdown="exclam grave",
      questiondown="question grave",
      guillemotleft="less less",
      guillemotright="greater greater",
    },
  },
  trep={
    {
      [0x0022]=0x201D,
      [0x0027]=0x2019,
      [0x0060]=0x2018,
    },
  },
  anum={
    { 
      [0x0030]=0x0660,
      [0x0031]=0x0661,
      [0x0032]=0x0662,
      [0x0033]=0x0663,
      [0x0034]=0x0664,
      [0x0035]=0x0665,
      [0x0036]=0x0666,
      [0x0037]=0x0667,
      [0x0038]=0x0668,
      [0x0039]=0x0669,
    },
    { 
      [0x0030]=0x06F0,
      [0x0031]=0x06F1,
      [0x0032]=0x06F2,
      [0x0033]=0x06F3,
      [0x0034]=0x06F4,
      [0x0035]=0x06F5,
      [0x0036]=0x06F6,
      [0x0037]=0x06F7,
      [0x0038]=0x06F8,
      [0x0039]=0x06F9,
    },
  },
}
local extra_features={ 
  tlig={
    {
      features={ { scripts={ { script="*",langs={ "*" },} },tag="tlig",comment="added bij mkiv" },},
      name="ctx_tlig_1",
      subtables={ { name="ctx_tlig_1_s" } },
      type="gsub_ligature",
      flags={},
    },
  },
  trep={
    {
      features={ { scripts={ { script="*",langs={ "*" },} },tag="trep",comment="added bij mkiv" },},
      name="ctx_trep_1",
      subtables={ { name="ctx_trep_1_s" } },
      type="gsub_single",
      flags={},
    },
  },
  anum={
    {
      features={ { scripts={ { script="arab",langs={ "dflt","ARA" },} },tag="anum",comment="added bij mkiv" },},
      name="ctx_anum_1",
      subtables={ { name="ctx_anum_1_s" } },
      type="gsub_single",
      flags={},
    },
    {
      features={ { scripts={ { script="arab",langs={ "FAR" },} },tag="anum",comment="added bij mkiv" },},
      name="ctx_anum_2",
      subtables={ { name="ctx_anum_2_s" } },
      type="gsub_single",
      flags={},
    },
  },
}
fonts.otf.enhancers["add some missing characters"]=function(data,filename)
end
fonts.otf.enhancers["enrich with features"]=function(data,filename)
  local used={}
  for i=1,#otf.glists do
    local g=data[otf.glists[i]]
    if g then
      for i=1,#g do
        local f=g[i].features
        if f then
          for i=1,#f do
            local t=f[i].tag
            if t then used[t]=true end
          end
        end
      end
    end
  end
  local glyphs=data.glyphs
  local indices=data.map.map
  data.gsub=data.gsub or {}
  for kind,specifications in next,extra_features do
    if not used[kind] then
      local done=0
      for s=1,#specifications do
        local added=false
        local specification=specifications[s]
        local list=extra_lists[kind][s]
        local name=specification.name.."_s"
        if specification.type=="gsub_ligature" then
          for unicode,index in next,indices do
            local glyph=glyphs[index]
            local ligature=list[glyph.name]
            if ligature then
              local o=glyph.lookups or {}
              o[name]={
                {
                  ["type"]="ligature",
                  ["specification"]={
                    char=glyph.name,
                    components=ligature,
                  }
                }
              }
              glyph.lookups,done,added=o,done+1,true
            end
          end
        elseif specification.type=="gsub_single" then
          for unicode,index in next,indices do
            local glyph=glyphs[index]
            local r=list[unicode]
            if r then
              local replacement=indices[r]
              if replacement and glyphs[replacement] then
                local o=glyph.lookups or {}
                o[name]={
                  {
                    ["type"]="substitution",
                    ["specification"]={
                      variant=glyphs[replacement].name,
                    }
                  }
                }
                glyph.lookups,done,added=o,done+1,true
              end
            end
          end
        end
        if added then
          insert(data.gsub,s,table.fastcopy(specification)) 
        end
      end
      if done>0 then
        if trace_loading then
          logs.report("load otf","enhance: registering %s feature (%s glyphs affected)",kind,done)
        end
      end
    end
  end
end
otf.tables.features['tlig']='TeX Ligatures'
otf.tables.features['trep']='TeX Replacements'
otf.tables.features['anum']='Arabic Digits'
otf.features.register_base_substitution('tlig')
otf.features.register_base_substitution('trep')
otf.features.register_base_substitution('anum')
fonts.initializers.base.otf.equaldigits=fonts.initializers.common.equaldigits
fonts.initializers.node.otf.equaldigits=fonts.initializers.common.equaldigits
fonts.initializers.base.otf.lineheight=fonts.initializers.common.lineheight
fonts.initializers.node.otf.lineheight=fonts.initializers.common.lineheight
fonts.initializers.base.otf.compose=fonts.initializers.common.compose
fonts.initializers.node.otf.compose=fonts.initializers.common.compose

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-def']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local format,concat,gmatch,match,find,lower=string.format,table.concat,string.gmatch,string.match,string.find,string.lower
local tostring,next=tostring,next
local lpegmatch=lpeg.match
local trace_defining=false trackers .register("fonts.defining",function(v) trace_defining=v end)
local directive_embedall=false directives.register("fonts.embedall",function(v) directive_embedall=v end)
trackers.register("fonts.loading","fonts.defining","otf.loading","afm.loading","tfm.loading")
trackers.register("fonts.all","fonts.*","otf.*","afm.*","tfm.*")
fonts=fonts    or {}
fonts.define=fonts.define or {}
fonts.tfm=fonts.tfm  or {}
fonts.ids=fonts.ids  or {}
fonts.vf=fonts.vf   or {}
fonts.used=fonts.used  or {}
local tfm=fonts.tfm
local vf=fonts.vf
local define=fonts.define
tfm.version=1.01
tfm.cache=containers.define("fonts","tfm",tfm.version,false) 
define.method="afm or tfm" 
define.specify=fonts.define.specify or {}
define.methods=fonts.define.methods or {}
tfm.fonts=tfm.fonts    or {}
tfm.readers=tfm.readers   or {}
tfm.internalized=tfm.internalized or {} 
tfm.readers.sequence={ 'otf','ttf','afm','tfm' }
tfm.auto_afm=true
local readers=tfm.readers
local sequence=readers.sequence
fonts.version=1.05
fonts.cache=containers.define("fonts","def",fonts.version,false)
local splitter,specifiers=nil,""
local P,C,S,Cc=lpeg.P,lpeg.C,lpeg.S,lpeg.Cc
local left=P("(")
local right=P(")")
local colon=P(":")
local space=P(" ")
define.defaultlookup="file"
local prefixpattern=P(false)
function define.add_specifier(symbol)
  specifiers=specifiers..symbol
  local method=S(specifiers)
  local lookup=C(prefixpattern)*colon
  local sub=left*C(P(1-left-right-method)^1)*right
  local specification=C(method)*C(P(1)^1)
  local name=C((1-sub-specification)^1)
  splitter=P((lookup+Cc(""))*name*(sub+Cc(""))*(specification+Cc("")))
end
function define.add_lookup(str,default)
  prefixpattern=prefixpattern+P(str)
end
define.add_lookup("file")
define.add_lookup("name")
define.add_lookup("spec")
function define.get_specification(str)
  return lpegmatch(splitter,str)
end
function define.register_split(symbol,action)
  define.add_specifier(symbol)
  define.specify[symbol]=action
end
function define.makespecification(specification,lookup,name,sub,method,detail,size)
  size=size or 655360
  if trace_defining then
    logs.report("define font","%s -> lookup: %s, name: %s, sub: %s, method: %s, detail: %s",
      specification,(lookup~="" and lookup) or "[file]",(name~="" and name) or "-",
      (sub~="" and sub) or "-",(method~="" and method) or "-",(detail~="" and detail) or "-")
  end
  if not lookup or lookup=="" then
    lookup=define.defaultlookup
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
function define.analyze(specification,size)
  local lookup,name,sub,method,detail=define.get_specification(specification or "")
  return define.makespecification(specification,lookup,name,sub,method,detail,size)
end
local sortedhashkeys=table.sortedhashkeys
function tfm.hash_features(specification)
  local features=specification.features
  if features then
    local t={}
    local normal=features.normal
    if normal and next(normal) then
      local f=sortedhashkeys(normal)
      for i=1,#f do
        local v=f[i]
        if v~="number" and v~="features" then 
          t[#t+1]=v..'='..tostring(normal[v])
        end
      end
    end
    local vtf=features.vtf
    if vtf and next(vtf) then
      local f=sortedhashkeys(vtf)
      for i=1,#f do
        local v=f[i]
        t[#t+1]=v..'='..tostring(vtf[v])
      end
    end
    if #t>0 then
      return concat(t,"+")
    end
  end
  return "unknown"
end
fonts.designsizes={}
function tfm.hash_instance(specification,force)
  local hash,size,fallbacks=specification.hash,specification.size,specification.fallbacks
  if force or not hash then
    hash=tfm.hash_features(specification)
    specification.hash=hash
  end
  if size<1000 and fonts.designsizes[hash] then
    size=math.round(tfm.scaled(size,fonts.designsizes[hash]))
    specification.size=size
  end
    if fallbacks then
      return hash..' @ '..tostring(size)..' @ '..fallbacks
    else
      return hash..' @ '..tostring(size)
    end
end
define.resolvers=resolvers
function define.resolvers.file(specification)
  local suffix=file.suffix(specification.name)
  if fonts.formats[suffix] then
    specification.forced=suffix
    specification.name=file.removesuffix(specification.name)
  end
end
function define.resolvers.name(specification)
  local resolve=fonts.names.resolve
  if resolve then
    local resolved,sub=fonts.names.resolve(specification)
    specification.resolved,specification.sub=resolved,sub
    if resolved then
      local suffix=file.suffix(resolved)
      if fonts.formats[suffix] then
        specification.forced=suffix
        specification.name=file.removesuffix(resolved)
      else
        specification.name=resolved
      end
    end
  else
    define.resolvers.file(specification)
  end
end
function define.resolvers.spec(specification)
  local resolvespec=fonts.names.resolvespec
  if resolvespec then
    specification.resolved,specification.sub=fonts.names.resolvespec(specification)
    if specification.resolved then
      specification.forced=file.extname(specification.resolved)
      specification.name=file.removesuffix(specification.resolved)
    end
  else
    define.resolvers.name(specification)
  end
end
function define.resolve(specification)
  if not specification.resolved or specification.resolved=="" then 
    local r=define.resolvers[specification.lookup]
    if r then
      r(specification)
    end
  end
  if specification.forced=="" then
    specification.forced=nil
  else
    specification.forced=specification.forced
  end
  specification.hash=lower(specification.name..' @ '..tfm.hash_features(specification))
  if specification.sub and specification.sub~="" then
    specification.hash=specification.sub..' @ '..specification.hash
  end
  return specification
end
function tfm.read(specification)
  local hash=tfm.hash_instance(specification)
  local tfmtable=tfm.fonts[hash] 
  if not tfmtable then
    local forced=specification.forced or ""
    if forced~="" then
      tfmtable=readers[lower(forced)](specification)
      if not tfmtable then
        logs.report("define font","forced type %s of %s not found",forced,specification.name)
      end
    else
      for s=1,#sequence do 
        local reader=sequence[s]
        if readers[reader] then 
          if trace_defining then
            logs.report("define font","trying (reader sequence driven) type %s for %s with file %s",reader,specification.name,specification.filename or "unknown")
          end
          tfmtable=readers[reader](specification)
          if tfmtable then
            break
          else
            specification.filename=nil
          end
        end
      end
    end
    if tfmtable then
      if directive_embedall then
        tfmtable.embedding="full"
      elseif tfmtable.filename and fonts.dontembed[tfmtable.filename] then
        tfmtable.embedding="no"
      else
        tfmtable.embedding="subset"
      end
      tfm.fonts[hash]=tfmtable
      fonts.designsizes[specification.hash]=tfmtable.designsize
    end
  end
  if not tfmtable then
    logs.report("define font","font with name %s is not found",specification.name)
  end
  return tfmtable
end
function tfm.read_and_define(name,size) 
  local specification=define.analyze(name,size)
  local method=specification.method
  if method and define.specify[method] then
    specification=define.specify[method](specification)
  end
  specification=define.resolve(specification)
  local hash=tfm.hash_instance(specification)
  local id=define.registered(hash)
  if not id then
    local fontdata=tfm.read(specification)
    if fontdata then
      fontdata.hash=hash
      id=font.define(fontdata)
      define.register(fontdata,id)
      tfm.cleanup_table(fontdata)
    else
      id=0 
    end
  end
  return fonts.ids[id],id
end
local function check_tfm(specification,fullname)
  local foundname=resolvers.findbinfile(fullname,'tfm') or "" 
  if foundname=="" then
    foundname=resolvers.findbinfile(fullname,'ofm') or "" 
  end
  if foundname~="" then
    specification.filename,specification.format=foundname,"ofm"
    return tfm.read_from_tfm(specification)
  end
end
local function check_afm(specification,fullname)
  local foundname=resolvers.findbinfile(fullname,'afm') or "" 
  if foundname=="" and tfm.auto_afm then
    local encoding,shortname=match(fullname,"^(.-)%-(.*)$") 
    if encoding and shortname and fonts.enc.known[encoding] then
      shortname=resolvers.findbinfile(shortname,'afm') or "" 
      if shortname~="" then
        foundname=shortname
        if trace_loading then
          logs.report("load afm","stripping encoding prefix from filename %s",afmname)
        end
      end
    end
  end
  if foundname~="" then
    specification.filename,specification.format=foundname,"afm"
    return tfm.read_from_afm(specification)
  end
end
function readers.tfm(specification)
  local fullname,tfmtable=specification.filename or "",nil
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      tfmtable=check_tfm(specification,specification.name.."."..forced)
    end
    if not tfmtable then
      tfmtable=check_tfm(specification,specification.name)
    end
  else
    tfmtable=check_tfm(specification,fullname)
  end
  return tfmtable
end
function readers.afm(specification,method)
  local fullname,tfmtable=specification.filename or "",nil
  if fullname=="" then
    local forced=specification.forced or ""
    if forced~="" then
      tfmtable=check_afm(specification,specification.name.."."..forced)
    end
    if not tfmtable then
      method=method or define.method or "afm or tfm"
      if method=="tfm" then
        tfmtable=check_tfm(specification,specification.name)
      elseif method=="afm" then
        tfmtable=check_afm(specification,specification.name)
      elseif method=="tfm or afm" then
        tfmtable=check_tfm(specification,specification.name) or check_afm(specification,specification.name)
      else 
        tfmtable=check_afm(specification,specification.name) or check_tfm(specification,specification.name)
      end
    end
  else
    tfmtable=check_afm(specification,fullname)
  end
  return tfmtable
end
local function check_otf(forced,specification,suffix,what)
  local name=specification.name
  if forced then
    name=file.addsuffix(name,suffix,true)
  end
  local fullname,tfmtable=resolvers.findbinfile(name,suffix) or "",nil 
  if fullname=="" then
    local fb=fonts.names.old_to_new[name]
    if fb then
      fullname=resolvers.findbinfile(fb,suffix) or ""
    end
  end
  if fullname=="" then
    local fb=fonts.names.new_to_old[name]
    if fb then
      fullname=resolvers.findbinfile(fb,suffix) or ""
    end
  end
  if fullname~="" then
    specification.filename,specification.format=fullname,what 
    tfmtable=tfm.read_from_open_type(specification)       
  end
  return tfmtable
end
function readers.opentype(specification,suffix,what)
  local forced=specification.forced or ""
  if forced=="otf" then
    return check_otf(true,specification,forced,"opentype")
  elseif forced=="ttf" or forced=="ttc" or forced=="dfont" then
    return check_otf(true,specification,forced,"truetype")
  else
    return check_otf(false,specification,suffix,what)
  end
end
function readers.otf (specification) return readers.opentype(specification,"otf","opentype") end
function readers.ttf (specification) return readers.opentype(specification,"ttf","truetype") end
function readers.ttc (specification) return readers.opentype(specification,"ttf","truetype") end 
function readers.dfont(specification) return readers.opentype(specification,"ttf","truetype") end
function define.check(features,defaults) 
  local done=false
  if features and next(features) then
    for k,v in next,defaults do
      if features[k]==nil then
        features[k],done=v,true
      end
    end
  else
    features,done=table.fastcopy(defaults),true
  end
  return features,done 
end
define.last=nil
function define.register(fontdata,id)
  if fontdata and id then
    local hash=fontdata.hash
    if not tfm.internalized[hash] then
      if trace_defining then
        logs.report("define font","loading at 2 id %s, hash: %s",id or "?",hash or "?")
      end
      fonts.identifiers[id]=fontdata
      fonts.characters [id]=fontdata.characters
      fonts.quads   [id]=fontdata.parameters.quad
      tfm.internalized[hash]=id
    end
  end
end
function define.registered(hash)
  local id=tfm.internalized[hash]
  return id,id and fonts.ids[id]
end
local cache_them=false
function tfm.make(specification)
  local fvm=define.methods[specification.features.vtf.preset]
  if fvm then
    return fvm(specification)
  else
    return nil
  end
end
function define.read(specification,size,id) 
  statistics.starttiming(fonts)
  if type(specification)=="string" then
    specification=define.analyze(specification,size)
  end
  local method=specification.method
  if method and define.specify[method] then
    specification=define.specify[method](specification)
  end
  specification=define.resolve(specification)
  local hash=tfm.hash_instance(specification)
  if cache_them then
    local fontdata=containers.read(fonts.cache,hash) 
  end
  local fontdata=define.registered(hash) 
  if not fontdata then
    if specification.features.vtf and specification.features.vtf.preset then
      fontdata=tfm.make(specification)
    else
      fontdata=tfm.read(specification)
      if fontdata then
        tfm.check_virtual_id(fontdata)
      end
    end
    if cache_them then
      fontdata=containers.write(fonts.cache,hash,fontdata) 
    end
    if fontdata then
      fontdata.hash=hash
      fontdata.cache="no"
      if id then
        define.register(fontdata,id)
      end
    end
  end
  define.last=fontdata or id 
  if not fontdata then
    logs.report("define font","unknown font %s, loading aborted",specification.name)
  elseif trace_defining and type(fontdata)=="table" then
    logs.report("define font","using %s font with id %s, name:%s size:%s bytes:%s encoding:%s fullname:%s filename:%s",
      fontdata.type     or "unknown",
      id           or "?",
      fontdata.name     or "?",
      fontdata.size     or "default",
      fontdata.encodingbytes or "?",
      fontdata.encodingname or "unicode",
      fontdata.fullname   or "?",
      file.basename(fontdata.filename or "?"))
  end
  statistics.stoptiming(fonts)
  return fontdata
end
function vf.find(name)
  name=file.removesuffix(file.basename(name))
  if tfm.resolve_vf then
    local format=fonts.logger.format(name)
    if format=='tfm' or format=='ofm' then
      if trace_defining then
        logs.report("define font","locating vf for %s",name)
      end
      return resolvers.findbinfile(name,"ovf")
    else
      if trace_defining then
        logs.report("define font","vf for %s is already taken care of",name)
      end
      return nil 
    end
  else
    if trace_defining then
      logs.report("define font","locating vf for %s",name)
    end
    return resolvers.findbinfile(name,"ovf")
  end
end
callbacks.register('define_font',define.read,"definition of fonts (tfmtable preparation)")
callbacks.register('find_vf_file',vf.find,"locating virtual fonts, insofar needed") 

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-xtx']={
  version=1.001,
  comment="companion to font-ini.mkiv",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
local texsprint,count=tex.sprint,tex.count
local format,concat,gmatch,match,find,lower=string.format,table.concat,string.gmatch,string.match,string.find,string.lower
local tostring,next=tostring,next
local lpegmatch=lpeg.match
local trace_defining=false trackers.register("fonts.defining",function(v) trace_defining=v end)
local list={}
fonts.define.specify.colonized_default_lookup="file"
local function isstyle(s)
  local style=string.lower(s):split("/")
  for _,v in ipairs(style) do
    if v=="b" then
      list.style="bold"
    elseif v=="i" then
      list.style="italic"
    elseif v=="bi" or v=="ib" then
      list.style="bolditalic"
    elseif v:find("^s=") then
      list.optsize=v:split("=")[2]
    elseif v=="aat" or v=="icu" or v=="gr" then
      logs.report("load font","unsupported font option: %s",v)
    elseif not v:is_empty() then
      list.style=v:gsub("[^%a%d]","")
    end
  end
end
fonts=fonts   or {}
fonts.otf=fonts.otf or {}
local otf=fonts.otf
otf.tables=otf.tables or {}
otf.tables.defaults={
  dflt={
    "ccmp","locl","rlig","liga","clig",
    "kern","mark","mkmk","itlc",
  },
  arab={
    "ccmp","locl","isol","fina","fin2",
    "fin3","medi","med2","init","rlig",
    "calt","liga","cswh","mset","curs",
    "kern","mark","mkmk",
  },
  deva={
    "ccmp","locl","init","nukt","akhn",
    "rphf","blwf","half","pstf","vatu",
    "pres","blws","abvs","psts","haln",
    "calt","blwm","abvm","dist","kern",
    "mark","mkmk",
  },
  khmr={
    "ccmp","locl","pref","blwf","abvf",
    "pstf","pres","blws","abvs","psts",
    "clig","calt","blwm","abvm","dist",
    "kern","mark","mkmk",
  },
  thai={
    "ccmp","locl","liga","kern","mark",
    "mkmk",
  },
  hang={
    "ccmp","ljmo","vjmo","tjmo",
  },
}
otf.tables.defaults.beng=otf.tables.defaults.deva
otf.tables.defaults.guru=otf.tables.defaults.deva
otf.tables.defaults.gujr=otf.tables.defaults.deva
otf.tables.defaults.orya=otf.tables.defaults.deva
otf.tables.defaults.taml=otf.tables.defaults.deva
otf.tables.defaults.telu=otf.tables.defaults.deva
otf.tables.defaults.knda=otf.tables.defaults.deva
otf.tables.defaults.mlym=otf.tables.defaults.deva
otf.tables.defaults.sinh=otf.tables.defaults.deva
otf.tables.defaults.syrc=otf.tables.defaults.arab
otf.tables.defaults.mong=otf.tables.defaults.arab
otf.tables.defaults.nko=otf.tables.defaults.arab
otf.tables.defaults.tibt=otf.tables.defaults.khmr
otf.tables.defaults.lao=otf.tables.defaults.thai
local function parse_script(script)
  if otf.tables.scripts[script] then
    local dflt
    if otf.tables.defaults[script] then
      logs.report("load font","auto-selecting default features for script: %s",script)
      dflt=otf.tables.defaults[script]
    else
      logs.report("load font","auto-selecting default features for script: dflt (was %s)",script)
      dflt=otf.tables.defaults["dflt"]
    end
    for _,v in next,dflt do
      list[v]="yes"
    end
  else
    logs.report("load font","unknown script: %s",script)
  end
end
local function issome ()  list.lookup=fonts.define.specify.colonized_default_lookup end
local function isfile ()  list.lookup='file' end
local function isname ()  list.lookup='name' end
local function thename(s)  list.name=s end
local function issub (v)  list.sub=v end
local function iskey (k,v)
  if k=="script" then
    parse_script(v)
  end
  list[k]=v
end
local function istrue (s)  list[s]=true end
local function isfalse(s)  list[s]=false end
local spaces=lpeg.P(" ")^0
local namespec=(1-lpeg.S("/:("))^0 
local filespec=(lpeg.R("az","AZ")*lpeg.P(":"))^-1*(1-lpeg.S(":("))^1
local crapspec=spaces*lpeg.P("/")*(((1-lpeg.P(":"))^0)/isstyle)*spaces
local filename=(lpeg.P("file:")/isfile*(filespec/thename))+(lpeg.P("[")*lpeg.P(true)/isfile*(((1-lpeg.P("]"))^0)/thename)*lpeg.P("]"))
local fontname=(lpeg.P("name:")/isname*(namespec/thename))+lpeg.P(true)/issome*(namespec/thename)
local sometext=(lpeg.R("az","AZ","09")+lpeg.S("+-."))^1
local truevalue=lpeg.P("+")*spaces*(sometext/istrue)
local falsevalue=lpeg.P("-")*spaces*(sometext/isfalse)
local keyvalue=lpeg.P("+")+(lpeg.C(sometext)*spaces*lpeg.P("=")*spaces*lpeg.C(sometext))/iskey
local somevalue=sometext/istrue
local subvalue=lpeg.P("(")*(lpeg.C(lpeg.P(1-lpeg.S("()"))^1)/issub)*lpeg.P(")") 
local option=spaces*(keyvalue+falsevalue+truevalue+somevalue)*spaces
local options=lpeg.P(":")*spaces*(lpeg.P(";")^0*option)^0
local pattern=(filename+fontname)*subvalue^0*crapspec^0*options^0
local normalize_meanings=fonts.otf.meanings.normalize
function fonts.define.specify.colonized(specification) 
  list={}
  lpegmatch(pattern,specification.specification)
  if list.style then
    specification.style=list.style
    list.style=nil
  end
  if list.optsize then
    specification.optsize=list.optsize
    list.optsize=nil
  end
  if list.name then
    if resolvers.find_file(list.name,"tfm") then
      list.lookup="file"
      list.name=file.addsuffix(list.name,"tfm")
    elseif resolvers.find_file(list.name,"ofm") then
      list.lookup="file"
      list.name=file.addsuffix(list.name,"ofm")
    end
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
  specification.features.normal=normalize_meanings(list)
  return specification
end
fonts.define.register_split(":",fonts.define.specify.colonized)

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-dum']={
  version=1.001,
  comment="companion to luatex-*.tex",
  author="Hans Hagen, PRAGMA-ADE, Hasselt NL",
  copyright="PRAGMA ADE / ConTeXt Development Team",
  license="see context related readme files"
}
fonts=fonts or {}
fonts.otf.pack=false
fonts.tfm.resolve_vf=false 
fonts.tfm.fontname_mode="specification"
fonts.tfm.readers=fonts.tfm.readers or {}
fonts.tfm.readers.sequence={ 'otf','ttf','tfm' }
fonts.tfm.readers.afm=nil
fonts.define=fonts.define or {}
fonts.define.specify.colonized_default_lookup="name"
function fonts.define.get_specification(str)
  return "",str,"",":",str
end
fonts.logger=fonts.logger or {}
function fonts.logger.save()
end
fonts.names=fonts.names or {}
fonts.names.version=1.001 
fonts.names.basename="luatex-fonts-names.lua"
fonts.names.new_to_old={}
fonts.names.old_to_new={}
local data,loaded=nil,false
local fileformats={ "lua","tex","other text files" }
function fonts.names.resolve(name,sub)
  if not loaded then
    local basename=fonts.names.basename
    if basename and basename~="" then
      for i=1,#fileformats do
        local format=fileformats[i]
        local foundname=resolvers.find_file(basename,format) or ""
        if foundname~="" then
          data=dofile(foundname)
          break
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
    else
      return name,false 
    end
  end
end
fonts.names.resolvespec=fonts.names.resolve
table.insert(fonts.triggers,"itlc")
local function itlc(tfmdata,value)
  if value then
    local metadata=tfmdata.shared.otfdata.metadata
    if metadata then
      local italicangle=metadata.italicangle
      if italicangle and italicangle~=0 then
        local uwidth=(metadata.uwidth or 40)/2
        for unicode,d in next,tfmdata.descriptions do
          local it=d.boundingbox[3]-d.width+uwidth
          if it~=0 then
            d.italic=it
          end
        end
        tfmdata.has_italic=true
      end
    end
  end
end
fonts.initializers.base.otf.itlc=itlc
fonts.initializers.node.otf.itlc=itlc
function fonts.initializers.common.slant(tfmdata,value)
  value=tonumber(value)
  if not value then
    value=0
  elseif value>1 then
    value=1
  elseif value<-1 then
    value=-1
  end
  tfmdata.slant_factor=value
end
function fonts.initializers.common.extend(tfmdata,value)
  value=tonumber(value)
  if not value then
    value=0
  elseif value>10 then
    value=10
  elseif value<-10 then
    value=-10
  end
  tfmdata.extend_factor=value
end
table.insert(fonts.triggers,"slant")
table.insert(fonts.triggers,"extend")
fonts.initializers.base.otf.slant=fonts.initializers.common.slant
fonts.initializers.node.otf.slant=fonts.initializers.common.slant
fonts.initializers.base.otf.extend=fonts.initializers.common.extend
fonts.initializers.node.otf.extend=fonts.initializers.common.extend
fonts.protrusions=fonts.protrusions    or {}
fonts.protrusions.setups=fonts.protrusions.setups or {}
local setups=fonts.protrusions.setups
local function map_opbd_onto_protrusion(tfmdata,value,opbd)
  local characters,descriptions=tfmdata.characters,tfmdata.descriptions
  local otfdata=tfmdata.shared.otfdata
  local singles=otfdata.shared.featuredata.gpos_single
  local script,language=tfmdata.script,tfmdata.language
  local done,factor,left,right=false,1,1,1
  local setup=setups[value]
  if setup then
    factor=setup.factor or 1
    left=setup.left  or 1
    right=setup.right or 1
  else
    factor=tonumber(value) or 1
  end
  if opbd~="right" then
    local validlookups,lookuplist=fonts.otf.collect_lookups(otfdata,"lfbd",script,language)
    if validlookups then
      for i=1,#lookuplist do
        local lookup=lookuplist[i]
        local data=singles[lookup]
        if data then
          if trace_protrusion then
            logs.report("fonts","set left protrusion using lfbd lookup '%s'",lookup)
          end
          for k,v in next,data do
            local p=- (v[1]/1000)*factor*left
            characters[k].left_protruding=p
            if trace_protrusion then
              logs.report("opbd","lfbd -> %s -> 0x%05X (%s) -> %0.03f (%s)",lookup,k,utfchar(k),p,concat(v," "))
            end
          end
          done=true
        end
      end
    end
  end
  if opbd~="left" then
    local validlookups,lookuplist=fonts.otf.collect_lookups(otfdata,"rtbd",script,language)
    if validlookups then
      for i=1,#lookuplist do
        local lookup=lookuplist[i]
        local data=singles[lookup]
        if data then
          if trace_protrusion then
            logs.report("fonts","set right protrusion using rtbd lookup '%s'",lookup)
          end
          for k,v in next,data do
            local p=(v[1]/1000)*factor*right
            characters[k].right_protruding=p
            if trace_protrusion then
              logs.report("opbd","rtbd -> %s -> 0x%05X (%s) -> %0.03f (%s)",lookup,k,utfchar(k),p,concat(v," "))
            end
          end
        end
        done=true
      end
    end
  end
  tfmdata.auto_protrude=done
end
function fonts.initializers.common.protrusion(tfmdata,value)
  if value then
    local opbd=tfmdata.shared.features.opbd
    if opbd then
      map_opbd_onto_protrusion(tfmdata,value,opbd)
    elseif value then
      local setup=setups[value]
      if setup then
        local factor,left,right=setup.factor or 1,setup.left or 1,setup.right or 1
        local emwidth=tfmdata.parameters.quad
        tfmdata.auto_protrude=true
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
end
fonts.expansions=fonts.expansions    or {}
fonts.expansions.setups=fonts.expansions.setups or {}
local setups=fonts.expansions.setups
function fonts.initializers.common.expansion(tfmdata,value)
  if value then
    local setup=setups[value]
    if setup then
      local stretch,shrink,step,factor=setup.stretch or 0,setup.shrink or 0,setup.step or 0,setup.factor or 1
      tfmdata.stretch,tfmdata.shrink,tfmdata.step,tfmdata.auto_expand=stretch*10,shrink*10,step*10,true
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
table.insert(fonts.manipulators,"protrusion")
table.insert(fonts.manipulators,"expansion")
fonts.initializers.base.otf.protrusion=fonts.initializers.common.protrusion
fonts.initializers.node.otf.protrusion=fonts.initializers.common.protrusion
fonts.initializers.base.otf.expansion=fonts.initializers.common.expansion
fonts.initializers.node.otf.expansion=fonts.initializers.common.expansion
function fonts.register_message()
end
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
fonts.otf.meanings=fonts.otf.meanings or {}
fonts.otf.meanings.normalize=fonts.otf.meanings.normalize or function(t)
  if t.rand then
    t.rand="random"
  end
end
function fonts.otf.name_to_slot(name)
  local tfmdata=fonts.ids[font.current()]
  if tfmdata and tfmdata.shared then
    local otfdata=tfmdata.shared.otfdata
    local unicode=otfdata.luatex.unicodes[name]
    return unicode and (type(unicode)=="number" and unicode or unicode[1])
  end
end
function fonts.otf.char(n)
  if type(n)=="string" then
    n=fonts.otf.name_to_slot(n)
  end
  if type(n)=="number" then
    tex.sprint("\\char"..n)
  end
end
fonts.strippables=table.tohash {
  0x000AD,0x017B4,0x017B5,0x0200B,0x0200C,0x0200D,0x0200E,0x0200F,0x0202A,0x0202B,
  0x0202C,0x0202D,0x0202E,0x02060,0x02061,0x02062,0x02063,0x0206A,0x0206B,0x0206C,
  0x0206D,0x0206E,0x0206F,0x0FEFF,0x1D173,0x1D174,0x1D175,0x1D176,0x1D177,0x1D178,
  0x1D179,0x1D17A,0xE0001,0xE0020,0xE0021,0xE0022,0xE0023,0xE0024,0xE0025,0xE0026,
  0xE0027,0xE0028,0xE0029,0xE002A,0xE002B,0xE002C,0xE002D,0xE002E,0xE002F,0xE0030,
  0xE0031,0xE0032,0xE0033,0xE0034,0xE0035,0xE0036,0xE0037,0xE0038,0xE0039,0xE003A,
  0xE003B,0xE003C,0xE003D,0xE003E,0xE003F,0xE0040,0xE0041,0xE0042,0xE0043,0xE0044,
  0xE0045,0xE0046,0xE0047,0xE0048,0xE0049,0xE004A,0xE004B,0xE004C,0xE004D,0xE004E,
  0xE004F,0xE0050,0xE0051,0xE0052,0xE0053,0xE0054,0xE0055,0xE0056,0xE0057,0xE0058,
  0xE0059,0xE005A,0xE005B,0xE005C,0xE005D,0xE005E,0xE005F,0xE0060,0xE0061,0xE0062,
  0xE0063,0xE0064,0xE0065,0xE0066,0xE0067,0xE0068,0xE0069,0xE006A,0xE006B,0xE006C,
  0xE006D,0xE006E,0xE006F,0xE0070,0xE0071,0xE0072,0xE0073,0xE0074,0xE0075,0xE0076,
  0xE0077,0xE0078,0xE0079,0xE007A,0xE007B,0xE007C,0xE007D,0xE007E,0xE007F,
}

end -- closure

do -- begin closure to overcome local limits and interference

if not modules then modules={} end modules ['font-clr']={
  version=1.001,
  comment="companion to font-otf.lua (font color)",
  author="Khaled Hosny and Elie Roux",
  copyright="Luaotfload Development Team",
  license="GPL"
}
fonts.triggers=fonts.triggers      or {}
fonts.initializers=fonts.initializers    or {}
fonts.initializers.common=fonts.initializers.common or {}
local initializers,format=fonts.initializers,string.format
table.insert(fonts.triggers,"color")
function initializers.common.color(tfmdata,value)
  local sanitized
  if value then
    value=tostring(value)
    if #value==6 or #value==8 then
      sanitized=value
    elseif #value==7 then
      _,_,sanitized=value:find("(......)")
    elseif #value>8 then
      _,_,sanitized=value:find("(........)")
    else
    end
  end
  if sanitized then
    tfmdata.color=sanitized
    add_color_callback()
  end
end
initializers.base.otf.color=initializers.common.color
initializers.node.otf.color=initializers.common.color
local function hex2dec(hex,one)
  if one then
    return format("%.1g",tonumber(hex,16)/255)
  else
    return format("%.3g",tonumber(hex,16)/255)
  end
end
local res
local function pageresources(a)
  local res2
  if not res then
    res="/TransGs1<</ca 1/CA 1>>"
  end
  res2=format("/TransGs%s<</ca %s/CA %s>>",a,a,a)
  res=format("%s%s",res,res:find(res2) and "" or res2)
end
local function hex_to_rgba(hex)
  local r,g,b,a,push,pop,res3
  if hex then
    if #hex==6 then
      _,_,r,g,b=hex:find('(..)(..)(..)')
    elseif #hex==8 then
      _,_,r,g,b,a=hex:find('(..)(..)(..)(..)')
      a=hex2dec(a,true)
      pageresources(a)
    end
  else
    return nil
  end
  r=hex2dec(r)
  g=hex2dec(g)
  b=hex2dec(b)
  if a then
    push=format('/TransGs%g gs %s %s %s rg',a,r,g,b)
    pop='0 g /TransGs1 gs'
  else
    push=format('%s %s %s rg',r,g,b)
    pop='0 g'
  end
  return push,pop
end
local glyph=node.id('glyph')
local hlist=node.id('hlist')
local vlist=node.id('vlist')
local whatsit=node.id('whatsit')
local pgi=node.id('page_insert')
local sbox=node.id('sub_box')
local function lookup_next_color(head)
  for n in node.traverse(head) do
    if n.id==glyph then
      if fonts.ids[n.font] and fonts.ids[n.font].color then
        return fonts.ids[n.font].color
      else
        return -1
      end
    elseif n.id==vlist or n.id==hlist or n.id==sbox then
      local r=lookup_next_color(n.list)
      if r==-1 then
        return -1
      elseif r then
        return r
      end
    elseif n.id==whatsit or n.id==pgi then
      return -1
    end
  end
  return nil
end
local function node_colorize(head,current_color,next_color)
  for n in node.traverse(head) do
    if n.id==hlist or n.id==vlist or n.id==sbox then
      local next_color_in=lookup_next_color(n.next) or next_color
      n.list,current_color=node_colorize(n.list,current_color,next_color_in)
    elseif n.id==glyph then
      local tfmdata=fonts.ids[n.font]
      if tfmdata and tfmdata.color then
        if tfmdata.color~=current_color then
          local pushcolor=hex_to_rgba(tfmdata.color)
          local push=node.new(whatsit,8)
          push.mode=1
          push.data=pushcolor
          head=node.insert_before(head,n,push)
          current_color=tfmdata.color
        end
        local next_color_in=lookup_next_color (n.next) or next_color
        if next_color_in~=tfmdata.color then
          local _,popcolor=hex_to_rgba(tfmdata.color)
          local pop=node.new(whatsit,8)
          pop.mode=1
          pop.data=popcolor
          head=node.insert_after(head,n,pop)
          current_color=nil
        end
      end
    end
  end
  return head,current_color
end
local function font_colorize(head)
  if res then
   local r="/ExtGState<<"..res..">>"
   tex.pdfpageresources=tex.pdfpageresources:gsub(r,"")
  end
  local h=node_colorize(head,nil,nil)
  if res and res:find("%S") then 
   local r="/ExtGState<<"..res..">>"
   tex.pdfpageresources=tex.pdfpageresources..r
  end
  return h
end
local color_callback_activated=0
function add_color_callback()
  if color_callback_activated==0 then
    luatexbase.add_to_callback("pre_output_filter",font_colorize,"loaotfload.colorize")
    color_callback_activated=1
  end
end

end -- closure
