if not modules then modules = { } end modules ['font-tfm'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next = next
local match = string.match

local trace_defining           = false  trackers.register("fonts.defining", function(v) trace_defining = v end)
local trace_features           = false  trackers.register("tfm.features",   function(v) trace_features = v end)

local report_defining          = logs.reporter("fonts","defining")
local report_tfm               = logs.reporter("fonts","tfm loading")

local findbinfile              = resolvers.findbinfile

local fonts                    = fonts
local handlers                 = fonts.handlers
local readers                  = fonts.readers
local constructors             = fonts.constructors
local encodings                = fonts.encodings

local tfm                      = constructors.newhandler("tfm")
tfm.version                    = 1.000
tfm.maxnestingdepth            = 5
tfm.maxnestingsize             = 65536*1024

local tfmfeatures              = constructors.newfeatures("tfm")
local registertfmfeature       = tfmfeatures.register

constructors.resolvevirtualtoo = false -- wil be set in font-ctx.lua

fonts.formats.tfm              = "type1" -- we need to have at least a value here

--[[ldx--
<p>The next function encapsulates the standard <l n='tfm'/> loader as
supplied by <l n='luatex'/>.</p>
--ldx]]--

-- this might change: not scaling and then apply features and do scaling in the
-- usual way with dummy descriptions but on the other hand .. we no longer use
-- tfm so why bother

-- ofm directive blocks local path search unless set; btw, in context we
-- don't support ofm files anyway as this format is obsolete

-- we need to deal with nested virtual fonts, but because we load in the
-- frontend we also need to make sure we don't nest too deep (esp when sizes
-- get large)
--
-- (VTITLE Example of a recursion)
-- (MAPFONT D 0 (FONTNAME recurse)(FONTAT D 2))
-- (CHARACTER C A (CHARWD D 1)(CHARHT D 1)(MAP (SETRULE D 1 D 1)))
-- (CHARACTER C B (CHARWD D 2)(CHARHT D 2)(MAP (SETCHAR C A)))
-- (CHARACTER C C (CHARWD D 4)(CHARHT D 4)(MAP (SETCHAR C B)))
--
-- we added the same checks as below to the luatex engine

function tfm.setfeatures(tfmdata,features)
    local okay = constructors.initializefeatures("tfm",tfmdata,features,trace_features,report_tfm)
    if okay then
        return constructors.collectprocessors("tfm",tfmdata,features,trace_features,report_tfm)
    else
        return { } -- will become false
    end
end

local depth = { } -- table.setmetatableindex("number")

local function read_from_tfm(specification)
    local filename  = specification.filename
    local size      = specification.size
    depth[filename] = (depth[filename] or 0) + 1
    if trace_defining then
        report_defining("loading tfm file %a at size %s",filename,size)
    end
    local tfmdata = font.read_tfm(filename,size) -- not cached, fast enough
    if tfmdata then
        local features      = specification.features and specification.features.normal or { }
        local resources     = tfmdata.resources  or { }
        local properties    = tfmdata.properties or { }
        local parameters    = tfmdata.parameters or { }
        local shared        = tfmdata.shared     or { }
        properties.name     = tfmdata.name
        properties.fontname = tfmdata.fontname
        properties.psname   = tfmdata.psname
        properties.filename = specification.filename
        properties.format   = fonts.formats.tfm -- better than nothing
        parameters.size     = size
        --
        tfmdata.properties  = properties
        tfmdata.resources   = resources
        tfmdata.parameters  = parameters
        tfmdata.shared      = shared
        --
        shared.rawdata      = { }
        shared.features     = features
        shared.processes    = next(features) and tfm.setfeatures(tfmdata,features) or nil
        parameters.slant         = parameters.slant          or parameters[1] or 0
        parameters.space         = parameters.space          or parameters[2] or 0
        parameters.space_stretch = parameters.space_stretch  or parameters[3] or 0
        parameters.space_shrink  = parameters.space_shrink   or parameters[4] or 0
        parameters.x_height      = parameters.x_height       or parameters[5] or 0
        parameters.quad          = parameters.quad           or parameters[6] or 0
        parameters.extra_space   = parameters.extra_space    or parameters[7] or 0
        --
        constructors.enhanceparameters(parameters) -- official copies for us
        --
        if constructors.resolvevirtualtoo then
            fonts.loggers.register(tfmdata,file.suffix(filename),specification) -- strange, why here
            local vfname = findbinfile(specification.name, 'ovf')
            if vfname and vfname ~= "" then
                local vfdata = font.read_vf(vfname,size) -- not cached, fast enough
                if vfdata then
                    local chars = tfmdata.characters
                    for k,v in next, vfdata.characters do
                        chars[k].commands = v.commands
                    end
                    properties.virtualized = true
                    tfmdata.fonts = vfdata.fonts
                    tfmdata.type = "virtual" -- else nested calls with cummulative scaling
                    local fontlist = vfdata.fonts
                    local name = file.nameonly(filename)
                    for i=1,#fontlist do
                        local n = fontlist[i].name
                        local s = fontlist[i].size
                        local d = depth[filename]
                        s = constructors.scaled(s,vfdata.designsize)
                        if d > tfm.maxnestingdepth then
                            report_defining("too deeply nested virtual font %a with size %a, max nesting depth %s",n,s,tfm.maxnestingdepth)
                            fontlist[i] = { id = 0 }
                        elseif (d > 1) and (s > tfm.maxnestingsize) then
                            report_defining("virtual font %a exceeds size %s",n,s)
                            fontlist[i] = { id = 0 }
                        else
                            local t, id = fonts.constructors.readanddefine(n,s)
                            fontlist[i] = { id = id }
                        end
                    end
                end
            end
        end
        --
        local allfeatures = tfmdata.shared.features or specification.features.normal
        constructors.applymanipulators("tfm",tfmdata,allfeatures.normal,trace_features,report_tfm)
        if not features.encoding then
            local encoding, filename = match(properties.filename,"^(.-)%-(.*)$") -- context: encoding-name.*
            if filename and encoding and encodings.known and encodings.known[encoding] then
                features.encoding = encoding
            end
        end
        -- let's play safe:
        properties.haskerns     = true
        properties.haslogatures = true
        resources.unicodes      = { }
        resources.lookuptags    = { }
        --
        depth[filename] = depth[filename] - 1
        return tfmdata
    else
        depth[filename] = depth[filename] - 1
    end
end

local function check_tfm(specification,fullname) -- we could split up like afm/otf
    local foundname = findbinfile(fullname, 'tfm') or ""
    if foundname == "" then
        foundname = findbinfile(fullname, 'ofm') or "" -- not needed in context
    end
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"tfm") or ""
    end
    if foundname ~= "" then
        specification.filename = foundname
        specification.format   = "ofm"
        return read_from_tfm(specification)
    elseif trace_defining then
        report_defining("loading tfm with name %a fails",specification.name)
    end
end

readers.check_tfm = check_tfm

function readers.tfm(specification)
    local fullname = specification.filename or ""
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            fullname = specification.name .. "." .. forced
        else
            fullname = specification.name
        end
    end
    return check_tfm(specification,fullname)
end
