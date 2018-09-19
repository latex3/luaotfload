if not modules then modules = { } end modules ['luatex-swiglib'] = {
    version   = 1.001,
    comment   = "companion to luatex-swiglib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local savedrequire = require

local libsuffix = os.type == "windows" and ".dll"    or ".so"
local pathsplit = "([^" .. io.pathseparator .. "]+)"

function requireswiglib(required,version)
    local library = package.loaded[required]
    if library then
        return library
    else
        local full = string.gsub(required,"%.","/")
        local path = file.pathpart(full)
        local name = file.nameonly(full) .. libsuffix
        local list = kpse.show_path("clua")
        for root in string.gmatch(list,pathsplit) do
            local full = false
            if type(version) == "string" and version ~= "" then
                full = root .. "/" .. path .. "/" .. version .. "/" .. name
                full = lfs.isfile(full) and full
            end
            if not full then
                full = root .. "/" .. path .. "/" .. name
                full = lfs.isfile(full) and full
            end
            if full then
                local path, base = string.match(full,"^(.-)([^\\/]+)" .. libsuffix .."$")
                local savedlibrary = package.loaded[base]
                package.loaded[base] = nil
                local savedpath = lfs.currentdir()
                lfs.chdir(path)
                library = package.loadlib(full,"luaopen_" .. base)
                if type(library) == "function" then
                    library = library()
                    texio.write("<swiglib: '",required,"' is loaded>")
                end
                lfs.chdir(savedpath)
                package.loaded[base] = savedlibrary
                package.loaded[required] = library
                return library
            end
        end
        texio.write("<swiglib: '",name,"'is not found on '",list,"'")
    end
    texio.write("<swiglib: '",required,"' is not found>")
end

function require(name)
    if string.find(name,"^swiglib%.") then
        return requireswiglib(name)
    else
        return savedrequire(name)
    end
end

function swiglib(name,version)
    return requireswiglib("swiglib." .. name,version)
end
