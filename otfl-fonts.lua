if not modules then modules = { } end modules ['luatex-fonts'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The following code isolates the generic context code from already defined or to be defined
-- namespaces. This is the reference loader for plain, but the generic code is also used in
-- luaotfload (which is is a file meant for latex) and that used to be maintained by Khaled
-- Hosny. We do our best to keep the interface as clean as possible.
--
-- The code base is rather stable now, especially if you stay away from the non generic code. All
-- relevant data is organized in tables within the main table of a font instance. There are a few
-- places where in context other code is plugged in, but this does not affect the core code. Users
-- can (given that their macro package provides this option) access the font data (characters,
-- descriptions, properties, parameters, etc) of this main table.

utf = utf or unicode.utf8

-- We have some (global) hooks (for latex):

if not non_generic_context then
    non_generic_context = { }
end

if not non_generic_context.luatex_fonts then
    non_generic_context.luatex_fonts = {
     -- load_before  = nil,
     -- load_after   = nil,
     -- skip_loading = nil,
    }
end

if not generic_context then
    generic_context  = { }
end

if not generic_context.push_namespaces then

    function generic_context.push_namespaces()
        texio.write(" <push namespace>")
        local normalglobal = { }
        for k, v in next, _G do
            normalglobal[k] = v
        end
        return normalglobal
    end

    function generic_context.pop_namespaces(normalglobal,isolate)
        if normalglobal then
            texio.write(" <pop namespace>")
            for k, v in next, _G do
                if not normalglobal[k] then
                    generic_context[k] = v
                    if isolate then
                        _G[k] = nil
                    end
                end
            end
            for k, v in next, normalglobal do
                _G[k] = v
            end
            -- just to be sure:
            setmetatable(generic_context,_G)
        else
            texio.write(" <fatal error: invalid pop of generic_context>")
            os.exit()
        end
    end

end

local whatever = generic_context.push_namespaces()

-- We keep track of load time by storing the current time. That way we cannot be accused
-- of slowing down loading too much. Anyhow, there is no reason for this library to perform
-- slower in any other package as it does in context.
--
-- Please don't update to this version without proper testing. It might be that this version
-- lags behind stock context and the only formal release takes place around tex live code
-- freeze.

local starttime = os.gettimeofday()

-- As we don't use the context file searching, we need to initialize the kpse library. As the
-- progname can be anything we will temporary switch to the context namespace if needed. Just
-- adding the context paths to the path specification is somewhat faster.
--
-- Now, with lua 5.2 being used we might create a special ENV for this.

-- kpse.set_program_name("luatex")

local ctxkpse = nil
local verbose = true

local function loadmodule(name,continue)
    local foundname = kpse.find_file(name,"tex") or ""
    if not foundname then
        if not ctxkpse then
            ctxkpse = kpse.new("luatex","context")
        end
        foundname = ctxkpse:find_file(name,"tex") or ""
    end
    if foundname == "" then
        if not continue then
            texio.write_nl(string.format(" <luatex-fonts: unable to locate %s>",name))
            os.exit()
        end
    else
        if verbose then
            texio.write(string.format(" <%s>",foundname)) -- no file.basename yet
        end
        dofile(foundname)
    end
end

if non_generic_context.luatex_fonts.load_before then
    loadmodule(non_generic_context.luatex_fonts.load_before,true)
end

if non_generic_context.luatex_fonts.skip_loading ~= true then

    loadmodule('luatex-fonts-merged.lua',true)

    if fonts then

        if not fonts._merge_loaded_message_done_ then
            texio.write_nl("log", "!")
            texio.write_nl("log", "! I am using the merged version of 'luatex-fonts.lua' here. If")
            texio.write_nl("log", "! you run into problems or experience unexpected behaviour, and")
            texio.write_nl("log", "! if you have ConTeXt installed you can try to delete the file")
            texio.write_nl("log", "! 'luatex-font-merged.lua' as I might then use the possibly")
            texio.write_nl("log", "! updated libraries. The merged version is not supported as it")
            texio.write_nl("log", "! is a frozen instance. Problems can be reported to the ConTeXt")
            texio.write_nl("log", "! mailing list.")
            texio.write_nl("log", "!")
        end

        fonts._merge_loaded_message_done_ = true

    else

        -- The following helpers are a bit overkill but I don't want to mess up context code for the
        -- sake of general generality. Around version 1.0 there will be an official api defined.
        --
        -- So, I will strip these libraries and see what is really needed so that we don't have this
        -- overhead in the generic modules. The next section is only there for the packager, so stick
        -- to using luatex-fonts with luatex-fonts-merged.lua and forget about the rest. The following
        -- list might change without prior notice (for instance because we shuffled code around).

        loadmodule("l-lua.lua")
        loadmodule("l-lpeg.lua")
        loadmodule("l-function.lua")
        loadmodule("l-string.lua")
        loadmodule("l-table.lua")
        loadmodule("l-io.lua")
        ----------("l-number.lua")
        ----------("l-set.lua")
        ----------("l-os.lua")
        loadmodule("l-file.lua")
        ----------("l-md5.lua")
        ----------("l-url.lua")
        ----------("l-dir.lua")
        loadmodule("l-boolean.lua")
        ----------("l-unicode.lua")
        loadmodule("l-math.lua")
        loadmodule("util-str.lua")


        -- The following modules contain code that is either not used at all outside context or will fail
        -- when enabled due to lack of other modules.

        -- First we load a few helper modules. This is about the miminum needed to let the font modules do
        -- their work. Don't depend on their functions as we might strip them in future versions of his
        -- generic variant.

        loadmodule('luatex-basics-gen.lua')
        loadmodule('data-con.lua')

        -- We do need some basic node support. The code in there is not for general use as it might change.

        loadmodule('luatex-basics-nod.lua')

        -- Now come the font modules that deal with traditional tex fonts as well as open type fonts. We only
        -- support OpenType fonts here.
        --
        -- The font database file (if used at all) must be put someplace visible for kpse and is not shared
        -- with context. The mtx-fonts script can be used to genate this file (using the --names option).

        -- in 2013/14 we will merge/move some generic files into luatex-fonts-* files (copies) so that
        -- intermediate updates of context not interfere

        loadmodule('font-ini.lua')
        loadmodule('font-con.lua')
        loadmodule('luatex-fonts-enc.lua') -- will load font-age on demand
        loadmodule('font-cid.lua')
        loadmodule('font-map.lua')         -- for loading lum file (will be stripped)
        loadmodule('luatex-fonts-syn.lua') -- deals with font names (synonyms)
        loadmodule('luatex-fonts-tfm.lua')
        loadmodule('font-oti.lua')
        loadmodule('font-otf.lua')
        loadmodule('font-otb.lua')
        loadmodule('node-inj.lua')         -- will be replaced (luatex >= .70)
        loadmodule('font-ota.lua')
        loadmodule('font-otn.lua')
        ----------('luatex-fonts-chr.lua')
        loadmodule('luatex-fonts-lua.lua')
        loadmodule('font-def.lua')
        loadmodule('luatex-fonts-def.lua')
        loadmodule('luatex-fonts-ext.lua') -- some extensions

        -- We need to plug into a callback and the following module implements the handlers. Actual plugging
        -- in happens later.

        loadmodule('luatex-fonts-cbk.lua')

    end

end

if non_generic_context.luatex_fonts.load_after then
    loadmodule(non_generic_context.luatex_fonts.load_after,true)
end

resolvers.loadmodule = loadmodule

-- In order to deal with the fonts we need to initialize some callbacks. One can overload them later on if
-- needed. First a bit of abstraction.

generic_context.callback_ligaturing           = false
generic_context.callback_kerning              = false
generic_context.callback_pre_linebreak_filter = nodes.simple_font_handler
generic_context.callback_hpack_filter         = nodes.simple_font_handler
generic_context.callback_define_font          = fonts.definers.read

-- The next ones can be done at a different moment if needed. You can create a generic_context namespace
-- and set no_callbacks_yet to true, load this module, and enable the callbacks later. So, there is really
-- *no* need to create a alternative for luatex-fonts.lua and luatex-fonts-merged.lua: just load this one
-- and overload if needed.

if not generic_context.no_callbacks_yet then

    callback.register('ligaturing',           generic_context.callback_ligaturing)
    callback.register('kerning',              generic_context.callback_kerning)
    callback.register('pre_linebreak_filter', generic_context.callback_pre_linebreak_filter)
    callback.register('hpack_filter',         generic_context.callback_hpack_filter)
    callback.register('define_font' ,         generic_context.callback_define_font)

end

-- We're done.

texio.write(string.format(" <luatex-fonts.lua loaded in %0.3f seconds>", os.gettimeofday()-starttime))

generic_context.pop_namespaces(whatever)
