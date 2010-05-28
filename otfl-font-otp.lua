if not modules then modules = { } end modules ['font-otp'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (packing)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: pack math (but not that much to share)

local next, type, tostring = next, type, tostring
local sort, concat = table.sort, table.concat

local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

fonts               = fonts               or { }
fonts.otf           = fonts.otf           or { }
fonts.otf.enhancers = fonts.otf.enhancers or { }
fonts.otf.glists    = fonts.otf.glists    or { "gsub", "gpos" }

local criterium, threshold, tabstr = 1, 0, table.serialize

local function tabstr(t) -- hashed from core-uti / experiment
    local s = { }
    for k, v in next, t do
        if type(v) == "table" then
            s[#s+1] = k.."={"..tabstr(v).."}"
        else
            s[#s+1] = k.."="..tostring(v)
        end
    end
    sort(s)
    return concat(s,",")
end

function fonts.otf.enhancers.pack(data)
    if data then
        local h, t, c = { }, { }, { }
        local hh, tt, cc = { }, { }, { }
        local function pack_1(v)
            -- v == table
            local tag = tabstr(v)
            local ht = h[tag]
            if not ht then
                ht = #t+1
                t[ht] = v
                h[tag] = ht
                c[ht] = 1
            else
                c[ht] = c[ht] + 1
            end
            return ht
        end
        local function pack_2(v)
            -- v == number
            if c[v] <= criterium then
                return t[v]
            else
                -- compact hash
                local hv = hh[v]
                if not hv then
                    hv = #tt+1
                    tt[hv] = t[v]
                    hh[v] = hv
                    cc[hv] = c[v]
                end
                return hv
            end
        end
        local function success(stage,pass)
            if #t == 0 then
                if trace_loading then
                    logs.report("load otf","pack quality: nothing to pack")
                end
                return false
            elseif #t >= threshold then
                local one, two, rest = 0, 0, 0
                if pass == 1 then
                    for k,v in next, c do
                        if v == 1 then
                            one = one + 1
                        elseif v == 2 then
                            two = two + 1
                        else
                            rest = rest + 1
                        end
                    end
                else
                    for k,v in next, cc do
                        if v >20 then
                            rest = rest + 1
                        elseif v >10 then
                            two = two + 1
                        else
                            one = one + 1
                        end
                    end
                    data.tables = tt
                end
                if trace_loading then
                    logs.report("load otf","pack quality: stage %s, pass %s, %s packed, 1-10:%s, 11-20:%s, rest:%s (criterium: %s)", stage, pass, one+two+rest, one, two, rest, criterium)
                end
                return true
            else
                if trace_loading then
                    logs.report("load otf","pack quality: stage %s, pass %s, %s packed, aborting pack (threshold: %s)", stage, pass, #t, threshold)
                end
                return false
            end
        end
        for pass=1,2 do
            local pack = (pass == 1 and pack_1) or pack_2
            for k, v in next, data.glyphs do
                v.boundingbox = pack(v.boundingbox)
                local l = v.slookups
                if l then
                    for k,v in next, l do
                        l[k] = pack(v)
                    end
                end
                local l = v.mlookups
                if l then
                    for k,v in next, l do
                        for kk=1,#v do
                            local vkk = v[kk]
                            local what = vkk[1]
                            if what == "pair" then
                                local t = vkk[3] if t then vkk[3] = pack(t) end
                                local t = vkk[4] if t then vkk[4] = pack(t) end
                            elseif what == "position" then
                                local t = vkk[2] if t then vkk[2] = pack(t) end
                            end
                        --  v[kk] = pack(vkk)
                        end
                    end
                end
                local m = v.mykerns
                if m then
                    for k,v in next, m do
                        m[k] = pack(v)
                    end
                end
                local m = v.math
                if m then
                    local mk = m.kerns
                    if mk then
                        for k,v in next, mk do
                            mk[k] = pack(v)
                        end
                    end
                end
                local a = v.anchors
                if a then
                    for k,v in next, a do
                        if k == "baselig" then
                            for kk, vv in next, v do
                                for kkk=1,#vv do
                                    vv[kkk] = pack(vv[kkk])
                                end
                            end
                        else
                            for kk, vv in next, v do
                                v[kk] = pack(vv)
                            end
                        end
                    end
                end
            end
            if data.lookups then
                for k, v in next, data.lookups do
                    if v.rules then
                        for kk, vv in next, v.rules do
                            local l = vv.lookups
                            if l then
                                vv.lookups = pack(l)
                            end
                            local c = vv.coverage
                            if c then
                                local cc = c.before  if cc then c.before  = pack(cc) end
                                local cc = c.after   if cc then c.after   = pack(cc) end
                                local cc = c.current if cc then c.current = pack(cc) end
                            end
                            local c = vv.reversecoverage
                            if c then
                                local cc = c.before  if cc then c.before  = pack(cc) end
                                local cc = c.after   if cc then c.after   = pack(cc) end
                                local cc = c.current if cc then c.current = pack(cc) end
                            end
                            -- no need to pack vv.glyphs
                            local c = vv.glyphs
                            if c then
                                if c.fore == "" then c.fore = nil end
                                if c.back == "" then c.back = nil end
                            end
                        end
                    end
                end
            end
            if data.luatex then
                local la = data.luatex.anchor_to_lookup
                if la then
                    for lookup, ldata in next, la do
                        la[lookup] = pack(ldata)
                    end
                end
                local la = data.luatex.lookup_to_anchor
                if la then
                    for lookup, ldata in next, la do
                        la[lookup] = pack(ldata)
                    end
                end
                local ls = data.luatex.sequences
                if ls then
                    for feature, fdata in next, ls do
                        local flags = fdata.flags
                        if flags then
                            fdata.flags = pack(flags)
                        end
                        local subtables = fdata.subtables
                        if subtables then
                            fdata.subtables = pack(subtables)
                        end
                        local features = fdata.features
                        if features then
                            for script, sdata in next, features do
                                features[script] = pack(sdata)
                            end
                        end
                    end
                end
                local ls = data.luatex.lookups
                if ls then
                    for lookup, fdata in next, ls do
                        local flags = fdata.flags
                        if flags then
                            fdata.flags = pack(flags)
                        end
                        local subtables = fdata.subtables
                        if subtables then
                            fdata.subtables = pack(subtables)
                        end
                    end
                end
                local lf = data.luatex.features
                if lf then
                    for _, g in next, fonts.otf.glists do
                        local gl = lf[g]
                        if gl then
                            for feature, spec in next, gl do
                                gl[feature] = pack(spec)
                            end
                        end
                    end
                end
            end
            if not success(1,pass) then
                return
            end
        end
        if #t > 0 then
            for pass=1,2 do
                local pack = (pass == 1 and pack_1) or pack_2
                for k, v in next, data.glyphs do
                    local m = v.mykerns
                    if m then
                        v.mykerns = pack(m)
                    end
                    local m = v.math
                    if m then
                        local mk = m.kerns
                        if mk then
                            m.kerns = pack(mk)
                        end
                    end
                    local a = v.anchors
                    if a then
                        v.anchors = pack(a)
                    end
                    local l = v.mlookups
                    if l then
                        for k,v in next, l do
                            for kk=1,#v do
                                v[kk] = pack(v[kk])
                            end
                        end
                    end
                end
                local ls = data.luatex.sequences
                if ls then
                    for feature, fdata in next, ls do
                        fdata.features = pack(fdata.features)
                    end
                end
                if not success(2,pass) then
--~                     return
                end
            end
        end
    end
end

function fonts.otf.enhancers.unpack(data)
    if data then
        local t = data.tables
        if t then
            local unpacked = { }
            for k, v in next, data.glyphs do
                local tv = t[v.boundingbox] if tv then v.boundingbox = tv end
                local l = v.slookups
                if l then
                    for k,v in next, l do
                        local tv = t[v] if tv then l[k] = tv end
                    end
                end
                local l = v.mlookups
                if l then
                    for k,v in next, l do
                        for i=1,#v do
                            local vi = v[i]
                            local tv = t[vi]
                            if tv then
                                v[i] = tv
                                if unpacked[tv] then
                                    vi = false
                                else
                                    unpacked[tv], vi = true, tv
                                end
                            end
                            if vi then
                                local what = vi[1]
                                if what == "pair" then
                                    local tv = t[vi[3]] if tv then vi[3] = tv end
                                    local tv = t[vi[4]] if tv then vi[4] = tv end
                                elseif what == "position" then
                                    local tv = t[vi[2]] if tv then vi[2] = tv end
                                end
                            end
                        end
                    end
                end
                local m = v.mykerns
                if m then
                    local tm = t[m]
                    if tm then
                        v.mykerns = tm
                        if unpacked[tm] then
                            m = false
                        else
                            unpacked[tm], m = true, tm
                        end
                    end
                    if m then
                        for k,v in next, m do
                            local tv = t[v] if tv then m[k] = tv end
                        end
                    end
                end
                local m = v.math
                if m then
                    local mk = m.kerns
                    if mk then
                        local tm = t[mk]
                        if tm then
                            m.kerns = tm
                            if unpacked[tm] then
                                mk = false
                            else
                                unpacked[tm], mk = true, tm
                            end
                        end
                        if mk then
                            for k,v in next, mk do
                                local tv = t[v] if tv then mk[k] = tv end
                            end
                        end
                    end
                end
                local a = v.anchors
                if a then
                    local ta = t[a]
                    if ta then
                        v.anchors = ta
                        if not unpacked[ta] then
                            unpacked[ta], a = true, ta
                        else
                            a = false
                        end
                    end
                    if a then
                        for k,v in next, a do
                            if k == "baselig" then
                                for kk, vv in next, v do
                                    for kkk=1,#vv do
                                        local tv = t[vv[kkk]] if tv then vv[kkk] = tv end
                                    end
                                end
                            else
                                for kk, vv in next, v do
                                    local tv = t[vv] if tv then v[kk] = tv end
                                end
                            end
                        end
                    end
                end
            end
            if data.lookups then
                for k, v in next, data.lookups do
                    local r = v.rules
                    if r then
                        for kk, vv in next, r do
                            local l = vv.lookups
                            if l then
                                local tv = t[l] if tv then vv.lookups = tv end
                            end
                            local c = vv.coverage
                            if c then
                                local cc = c.before  if cc then local tv = t[cc] if tv then c.before  = tv end end
                                      cc = c.after   if cc then local tv = t[cc] if tv then c.after   = tv end end
                                      cc = c.current if cc then local tv = t[cc] if tv then c.current = tv end end
                            end
                            local c = vv.reversecoverage
                            if c then
                                local cc = c.before  if cc then local tv = t[cc] if tv then c.before  = tv end end
                                      cc = c.after   if cc then local tv = t[cc] if tv then c.after   = tv end end
                                      cc = c.current if cc then local tv = t[cc] if tv then c.current = tv end end
                            end
                            -- no need to unpack vv.glyphs
                        end
                    end
                end
            end
            local luatex = data.luatex
            if luatex then
                local la = luatex.anchor_to_lookup
                if la then
                    for lookup, ldata in next, la do
                        local tv = t[ldata] if tv then la[lookup] = tv end
                    end
                end
                local la = luatex.lookup_to_anchor
                if la then
                    for lookup, ldata in next, la do
                        local tv = t[ldata] if tv then la[lookup] = tv end
                    end
                end
                local ls = luatex.sequences
                if ls then
                    for feature, fdata in next, ls do
                        local flags = fdata.flags
                        if flags then
                            local tv = t[flags] if tv then fdata.flags = tv end
                        end
                        local subtables = fdata.subtables
                        if subtables then
                            local tv = t[subtables] if tv then fdata.subtables = tv end
                        end
                        local features = fdata.features
                        if features then
                            local tv = t[features]
                            if tv then
                                fdata.features = tv
                                if not unpacked[tv] then
                                    unpacked[tv], features = true, tv
                                else
                                    features = false
                                end
                            end
                            if features then
                                for script, sdata in next, features do
                                    local tv = t[sdata] if tv then features[script] = tv end
                                end
                            end
                        end
                    end
                end
                local ls = luatex.lookups
                if ls then
                    for lookups, fdata in next, ls do
                        local flags = fdata.flags
                        if flags then
                            local tv = t[flags] if tv then fdata.flags = tv end
                        end
                        local subtables = fdata.subtables
                        if subtables then
                            local tv = t[subtables] if tv then fdata.subtables = tv end
                        end
                    end
                end
                local lf = luatex.features
                if lf then
                    for _, g in next, fonts.otf.glists do
                        local gl = lf[g]
                        if gl then
                            for feature, spec in next, gl do
                                local tv = t[spec] if tv then gl[feature] = tv end
                            end
                        end
                    end
                end
            end
            data.tables = nil
        end
    end
end
