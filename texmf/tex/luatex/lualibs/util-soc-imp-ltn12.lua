-- original file : ltn12.lua
-- for more into : see util-soc.lua

local select, unpack = select, unpack
local insert, remove = table.insert, table.remove
local sub = string.sub

local function report(fmt,first,...)
    if logs then
        report = logs and logs.reporter("ltn12")
        report(fmt,first,...)
    elseif fmt then
        fmt = "ltn12: " .. fmt
        if first then
            print(format(fmt,first,...))
        else
            print(fmt)
        end
    end
end

local filter = { }
local source = { }
local sink   = { }
local pump   = { }

local ltn12 = {

    _VERSION  = "LTN12 1.0.3",

    BLOCKSIZE = 2048,

    filter    = filter,
    source    = source,
    sink      = sink,
    pump      = pump,

    report    = report,

}

-- returns a high level filter that cycles a low-level filter

function filter.cycle(low, ctx, extra)
    if low then
        return function(chunk)
            return (low(ctx, chunk, extra))
        end
    end
end

-- chains a bunch of filters together

function filter.chain(...)
    local arg   = { ... }
    local n     = select('#',...)
    local top   = 1
    local index = 1
    local retry = ""
    return function(chunk)
        retry = chunk and retry
        while true do
            local action = arg[index]
            if index == top then
                chunk = action(chunk)
                if chunk == "" or top == n then
                    return chunk
                elseif chunk then
                    index = index + 1
                else
                    top   = top + 1
                    index = top
                end
            else
                chunk = action(chunk or "")
                if chunk == "" then
                    index = index - 1
                    chunk = retry
                elseif chunk then
                    if index == n then
                        return chunk
                    else
                        index = index + 1
                    end
                else
                    report("error: filter returned inappropriate 'nil'")
                    return
                end
            end
        end
    end
end

-- create an empty source

local function empty()
    return nil
end

function source.empty()
    return empty
end

-- returns a source that just outputs an error

local function sourceerror(err)
    return function()
        return nil, err
    end
end

source.error = sourceerror

-- creates a file source

function source.file(handle, io_err)
    if handle then
        local blocksize = ltn12.BLOCKSIZE
        return function()
            local chunk = handle:read(blocksize)
            if not chunk then
                handle:close()
            end
            return chunk
        end
    else
        return sourceerror(io_err or "unable to open file")
    end
end

-- turns a fancy source into a simple source

function source.simplify(src)
    return function()
        local chunk, err_or_new = src()
        if err_or_new then
            src = err_or_new
        end
        if chunk then
            return chunk
        else
            return nil, err_or_new
        end
    end
end

-- creates string source

function source.string(s)
    if s then
        local blocksize = ltn12.BLOCKSIZE
        local i = 1
        return function()
            local nexti = i + blocksize
            local chunk = sub(s, i, nexti - 1)
            i = nexti
            if chunk ~= "" then
                return chunk
            else
                return nil
            end
        end
    else return source.empty() end
end

-- creates rewindable source

function source.rewind(src)
    local t = { }
    return function(chunk)
        if chunk then
            insert(t, chunk)
        else
            chunk = remove(t)
            if chunk then
                return chunk
            else
                return src()
            end
        end
    end
end

-- chains a source with one or several filter(s)

function source.chain(src, f, ...)
    if ... then
        f = filter.chain(f, ...)
    end
    local last_in  = ""
    local last_out = ""
    local state    = "feeding"
    local err
    return function()
        if not last_out then
            report("error: source is empty")
            return
        end
        while true do
            if state == "feeding" then
                last_in, err = src()
                if err then
                    return nil, err
                end
                last_out = f(last_in)
                if not last_out then
                    if last_in then
                        report("error: filter returned inappropriate 'nil'")
                    end
                    return nil
                elseif last_out ~= "" then
                    state = "eating"
                    if last_in then
                        last_in = ""
                    end
                    return last_out
                end
            else
                last_out = f(last_in)
                if last_out == "" then
                    if last_in == "" then
                        state = "feeding"
                    else
                        report("error: filter returned nothing")
                        return
                    end
                elseif not last_out then
                    if last_in then
                        report("filter returned inappropriate 'nil'")
                    end
                    return nil
                else
                    return last_out
                end
            end
        end
    end
end

-- creates a source that produces contents of several sources, one after the
-- other, as if they were concatenated

function source.cat(...)
    local arg = { ... }
    local src = remove(arg,1)
    return function()
        while src do
            local chunk, err = src()
            if chunk then
                return chunk
            end
            if err then
                return nil, err
            end
            src = remove(arg,1)
        end
    end
end

-- creates a sink that stores into a table

function sink.table(t)
    if not t then
        t = { }
    end
    local f = function(chunk, err)
        if chunk then
            insert(t, chunk)
        end
        return 1
    end
    return f, t
end

-- turns a fancy sink into a simple sink

function sink.simplify(snk)
    return function(chunk, err)
        local ret, err_or_new = snk(chunk, err)
        if not ret then
            return nil, err_or_new
        end
        if err_or_new then
            snk = err_or_new
        end
        return 1
    end
end

-- creates a sink that discards data

local function null()
    return 1
end

function sink.null()
    return null
end

-- creates a sink that just returns an error

local function sinkerror(err)
    return function()
        return nil, err
    end
end

sink.error = sinkerror

-- creates a file sink

function sink.file(handle, io_err)
    if handle then
        return function(chunk, err)
            if not chunk then
                handle:close()
                return 1
            else
                return handle:write(chunk)
            end
        end
    else
        return sinkerror(io_err or "unable to open file")
    end
end

-- chains a sink with one or several filter(s)

function sink.chain(f, snk, ...)
    if ... then
        local args = { f, snk, ... }
        snk = remove(args, #args)
        f = filter.chain(unpack(args))
    end
    return function(chunk, err)
        if chunk ~= "" then
            local filtered = f(chunk)
            local done     = chunk and ""
            while true do
                local ret, snkerr = snk(filtered, err)
                if not ret then
                    return nil, snkerr
                end
                if filtered == done then
                    return 1
                end
                filtered = f(done)
            end
        else
            return 1
        end
    end
end

-- pumps one chunk from the source to the sink

function pump.step(src, snk)
    local chunk, src_err = src()
    local ret, snk_err = snk(chunk, src_err)
    if chunk and ret then
        return 1
    else
        return nil, src_err or snk_err
    end
end

-- pumps all data from a source to a sink, using a step function

function pump.all(src, snk, step)
    if not step then
        step = pump.step
    end
    while true do
        local ret, err = step(src, snk)
        if not ret then
            if err then
                return nil, err
            else
                return 1
            end
        end
    end
end

package.loaded["ltn12"] = ltn12

return ltn12
