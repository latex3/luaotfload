if not modules then modules = { } end modules ['luatex-plain-tfm'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- \font\foo=file:luatex-plain-tfm.lua:tfm=csr10;enc=csr;pfb=csr10 at 12pt
-- \font\bar=file:luatex-plain-tfm.lua:tfm=csr10;enc=csr           at 12pt
--
-- \foo áäčďěíĺľňóôŕřšťúýž ff ffi \input tufte\par
-- \bar áäčďěíĺľňóôŕřšťúýž ff ffi \input tufte\par

local outfiles = { }

return function(specification)

    local size = specification.size
    local name = specification.name
    local feat = specification.features and specification.features.normal

    if not feat then
        return
    end

    local tfm = feat.tfm
    local enc = feat.enc or tfm
    local pfb = feat.pfb

    if not tfm then
        return
    end

    local tfmfile = tfm .. ".tfm"
    local encfile = enc .. ".enc"

    local tfmdata, id = fonts.constructors.readanddefine("file:"..tfmfile,size)

    local encoding = fonts.encodings.load(encfile)
    if encoding then
        encoding = encoding.hash
    else
        encoding = false
    end

    local unicoding = fonts.encodings.agl and fonts.encodings.agl.unicodes

    if tfmdata and encoding and unicoding then

        tfmdata = table.copy(tfmdata) -- good enough for small fonts

        local characters = { }
        local originals  = tfmdata.characters
        local indices    = { }
        local parentfont = { "font", 1 }
        local private    = fonts.constructors.privateoffset

        -- create characters table

        for name, index in table.sortedhash(encoding) do -- predictable order
            local unicode  = unicoding[name]
            local original = originals[index]
            if not unicode then
                unicode = private
                private = private + 1
                report_tfm("glyph %a in font %a gets private unicode %U",name,tfmfile,private)
            end
            characters[unicode] = original
            indices[index]      = unicode
            original.name       = name -- so one can lookup weird names
            original.commands   = { parentfont, { "char", index } }
        end

        -- redo kerns and ligatures

        for k, v in next, characters do
            local kerns = v.kerns
            if kerns then
                local t = { }
                for k, v in next, kerns do
                    local i = indices[k]
                    t[i] = v
                end
                v.kerns = t
            end
            local ligatures = v.ligatures
            if ligatures then
                local t = { }
                for k, v in next, ligatures do
                    t[indices[k]] = v
                    v.char = indices[v.char]
                end
                v.ligatures = t
            end
        end

        -- wrap up

        tfmdata.fonts      = { { id = id } }
        tfmdata.characters = characters

        -- resources

        local outfile = outfiles[tfmfile]

        if outfile == nil then
            if pfb then
                outfile = pfb .. ".pfb"
                pdf.mapline(tfm .. "<" .. outfile)
            else
                outfile = false
            end
            outfiles[tfmfile] = outfile
        end

    end

    return tfmdata
end
