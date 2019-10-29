if not modules then modules = { } end modules ['l-gzip'] = {
    version   = 1.001,
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if gzip then

    local suffix, suffixes = file.suffix, file.suffixes

    function gzip.load(filename)
        local f = io.open(filename,"rb")
        if not f then
            -- invalid file
        elseif suffix(filename) == "gz" then
            f:close()
            local g = gzip.open(filename,"rb")
            if g then
                local str = g:read("*all")
                g:close()
                return str
            end
        else
            local str = f:read("*all")
            f:close()
            return str
        end
    end

    function gzip.save(filename,data)
        if suffix(filename) ~= "gz" then
            filename = filename .. ".gz"
        end
        local f = io.open(filename,"wb")
        if f then
            local s = zlib.compress(data or "",9,nil,15+16)
            f:write(s)
            f:close()
            return #s
        end
    end

    function gzip.suffix(filename)
        local suffix, extra = suffixes(filename)
        local gzipped = extra == "gz"
        return suffix, gzipped
    end

else

    -- todo: fallback on flate

end

if flate then

    local type = type
    local find = string.find

    local compress   = flate.gz_compress
    local decompress = flate.gz_decompress

    local absmax     = 128*1024*1024
    local initial    =       64*1024
    local identifier = "^\x1F\x8B\x08"

    function gzip.compressed(s)
        return s and find(s,identifier)
    end

    function gzip.compress(s,level)
        if s and not find(s,identifier) then -- the find check might go away
            if not level then
                level = 3
            elseif level <= 0 then
                return s
            elseif level > 9 then
                level = 9
            end
            return compress(s,level) or s
        end
    end

    function gzip.decompress(s,size,iterate)
        if s and find(s,identifier) then
            if type(size) ~= "number" then
                size = initial
            end
            if size > absmax then
                size = absmax
            end
            if type(iterate) == "number" then
                max = size * iterate
            elseif iterate == nil or iterate == true then
                iterate = true
                max     = absmax
            end
            if max > absmax then
                max = absmax
            end
            while true do
                local d = decompress(s,size)
                if d then
                    return d
                end
                size = 2 * size
                if not iterate or size > max then
                    return false
                end
            end
        else
            return s
        end
    end

end
