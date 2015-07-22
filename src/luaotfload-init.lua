#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-init.lua
--  DESCRIPTION:  Luaotfload font loader initialization
-- REQUIREMENTS:  luatex v.0.80 or later; packages lualibs, luatexbase
--       AUTHOR:  Philipp Gesang (Phg), <phg@phi-gamma.net>
--      VERSION:  1.0
--      CREATED:  2015-05-26 07:50:54+0200
-----------------------------------------------------------------------
--

--[[doc--

  Initialization phases:

      - Load Lualibs from package
      - Set up the logger routines
      - Load Fontloader
          - as package specified in configuration
          - from Context install
          - (optional: from raw unpackaged files distributed with
            Luaotfload)

  The initialization of the Lualibs may be made configurable in the
  future as well allowing to load both the files and the merged package
  depending on a configuration setting. However, this would require
  separating out the configuration parser into a self-contained
  package, which might be problematic due to its current dependency on
  the Lualibs itself.

--doc]]--

local log        --- filled in after loading the log module
local logreport  --- filled in after loading the log module

--[[doc--

    \subsection{Preparing the Font Loader}
    We treat the fontloader as a black box so behavior is consistent
    between formats.
    We load the fontloader code directly in the same fashion as the
    Plain format \identifier{luatex-fonts} that is part of Context.
    How this is executed depends on the presence on the
    \emphasis{merged font loader code}.
    In \identifier{luaotfload} this is contained in the file
    \fileent{luaotfload-merged.lua}.
    If this file cannot be found, the original libraries from \CONTEXT
    of which the merged code was composed are loaded instead.
    Since these files are not shipped with Luaotfload, an installation
    of Context is required.
    (Since we pull the fontloader directly from the Context minimals,
    the necessary Context version is likely to be more recent than that
    of other TeX distributions like Texlive.)
    The imported font loader will call \luafunction{callback.register}
    once while reading \fileent{font-def.lua}.
    This is unavoidable unless we modify the imported files, but
    harmless if we make it call a dummy instead.
    However, this problem might vanish if we decide to do the merging
    ourselves, like the \identifier{lualibs} package does.
    With this step we would obtain the freedom to load our own
    overrides in the process right where they are needed, at the cost
    of losing encapsulation.
    The decision on how to progress is currently on indefinite hold.

--doc]]--


local init_pre = function ()

  local store                  = { }
  config                       = config or { } --- global
  config.luaotfload            = config.luaotfload or { }
  config.lualibs               = config.lualibs    or { }
  config.lualibs.verbose       = false
  config.lualibs.prefer_merged = true
  config.lualibs.load_extended = true

  require "lualibs"

  if not lualibs    then error "this module requires Luaotfload" end
  if not luaotfload then error "this module requires Luaotfload" end

  --[[doc--

    The logger needs to be in place prior to loading the fontloader due
    to order of initialization being crucial for the logger functions
    that are swapped.

  --doc]]--

  luaotfload.loaders.luaotfload "log"
  log       = luaotfload.log
  logreport = log.report
  log.set_loglevel (default_log_level)

  logreport ("log", 4, "init", "Concealing callback.register().")
  store.trapped_register = callback.register

  callback.register = function (id)
    logreport ("log", 4, "init",
               "Dummy callback.register() invoked on %s.",
               id)
  end

  --[[doc--

    By default, the fontloader requires a number of \emphasis{private
    attributes} for internal use.
    These must be kept consistent with the attribute handling methods
    as provided by \identifier{luatexbase}.
    Our strategy is to override the function that allocates new
    attributes before we initialize the font loader, making it a
    wrapper around \luafunction{luatexbase.new_attribute}.\footnote{%
        Many thanks, again, to Hans Hagen for making this part
        configurable!
    }
    The attribute identifiers are prefixed “\fileent{luaotfload@}” to
    avoid name clashes.

  --doc]]--

  local new_attribute    = luatexbase.new_attribute
  local the_attributes   = luatexbase.attributes

  attributes = attributes or { } --- this writes a global, sorry

  attributes.private = function (name)
    local attr   = "luaotfload@" .. name --- used to be: “otfl@”
    local number = the_attributes[attr]
    if not number then number = new_attribute(attr) end
    return number
  end

  return store
end --- [init_pre]

--[[doc--

    These next lines replicate the behavior of
    \fileent{luatex-fonts.lua}.

--doc]]--

local push_namespaces = function ()
    logreport ("log", 4, "init", "push namespace for font loader")
    local normalglobal = { }
    for k, v in next, _G do
        normalglobal[k] = v
    end
    return normalglobal
end

local pop_namespaces = function (normalglobal,
                                 isolate,
                                 context_environment)
    if normalglobal then
        local _G = _G
        local mode = "non-destructive"
        if isolate then mode = "destructive" end
        logreport ("log", 4, "init", "pop namespace from font loader -- " .. mode)
        for k, v in next, _G do
            if not normalglobal[k] then
                context_environment[k] = v
                if isolate then
                    _G[k] = nil
                end
            end
        end
        for k, v in next, normalglobal do
            _G[k] = v
        end
        -- just to be sure:
        setmetatable(context_environment, _G)
    else
        logreport ("both", 0, "init",
                   "irrecoverable error during pop_namespace: no globals to restore")
        os.exit ()
    end
end

local init_adapt = function ()

  local context_environment  = { }
  local our_environment      = push_namespaces ()

  --[[doc--

      The font loader requires that the attribute with index zero be
      zero. We happily oblige.
      (Cf. \fileent{luatex-fonts-nod.lua}.)

  --doc]]--

  tex.attribute[0] = 0

  return our_environment, context_environment

end --- [init_adapt]

local init_main = function ()

  local load_fontloader_module = luaotfload.loaders.fontloader

  --[[doc--

      Now that things are sorted out we can finally load the
      fontloader.

      For less current distibutions we ship the code from TL 2014 that
      should be compatible with Luatex 0.76.

  --doc]]--

  load_fontloader_module (luaotfload.fontloader_package)

  ---load_fontloader_module "font-odv.lua" --- <= Devanagari support from Context

  if not fonts then
    --- the loading sequence is known to change, so this might have to
    --- be updated with future updates!
    --- do not modify it though unless there is a change to the merged
    --- package!
    load_fontloader_module "l-lua"
    load_fontloader_module "l-lpeg"
    load_fontloader_module "l-function"
    load_fontloader_module "l-string"
    load_fontloader_module "l-table"
    load_fontloader_module "l-io"
    load_fontloader_module "l-file"
    load_fontloader_module "l-boolean"
    load_fontloader_module "l-math"
    load_fontloader_module "util-str"
    load_fontloader_module "luatex-basics-gen"
    load_fontloader_module "data-con"
    load_fontloader_module "luatex-basics-nod"
    load_fontloader_module "font-ini"
    load_fontloader_module "font-con"
    load_fontloader_module "luatex-fonts-enc"
    load_fontloader_module "font-cid"
    load_fontloader_module "font-map"
    load_fontloader_module "luatex-fonts-syn"
    load_fontloader_module "luatex-fonts-tfm"
    load_fontloader_module "font-oti"
    load_fontloader_module "font-otf"
    load_fontloader_module "font-otb"
    load_fontloader_module "luatex-fonts-inj"  --> since 2014-01-07, replaces node-inj.lua
    load_fontloader_module "luatex-fonts-ota"
    load_fontloader_module "luatex-fonts-otn"  --> since 2014-01-07, replaces font-otn.lua
    load_fontloader_module "font-otp"          --> since 2013-04-23
    load_fontloader_module "luatex-fonts-lua"
    load_fontloader_module "font-def"
    load_fontloader_module "luatex-fonts-def"
    load_fontloader_module "luatex-fonts-ext"
    load_fontloader_module "luatex-fonts-cbk"
  end --- non-merge fallback scope

end --- [init_main]

local init_cleanup = function (store)
  --- reinstate all the stuff we had to move out of the way to
  --- accomodate the loader

  --[[doc--

      Here we adjust the globals created during font loader
      initialization. If the second argument to
      \luafunction{pop_namespaces()} is \verb|true| this will restore the
      state of \luafunction{_G}, eliminating every global generated since
      the last call to \luafunction{push_namespaces()}. At the moment we
      see no reason to do this, and since the font loader is considered
      an essential part of \identifier{luatex} as well as a very well
      organized piece of code, we happily concede it the right to add to
      \luafunction{_G} if needed.

  --doc]]--

  pop_namespaces (store.our_environment,
                  false,
                  store.context_environment)

  --[[doc--

      \subsection{Callbacks}
        After the fontloader is ready we can restore the callback trap
        from \identifier{luatexbase}.

  --doc]]--

  logreport ("log", 4, "init",
             "Restoring original callback.register().")
  callback.register = store.trapped_register
end --- [init_cleanup]

local init_post_install_callbacks = function ()
  --[[doc--

    we do our own callback handling with the means provided by
    luatexbase.
    note: \luafunction{pre_linebreak_filter} and
    \luafunction{hpack_filter} are coupled in \context in the
    concept of \emphasis{node processor}.

  --doc]]--

  luatexbase.add_to_callback("pre_linebreak_filter",
                             nodes.simple_font_handler,
                             "luaotfload.node_processor",
                             1)
  luatexbase.add_to_callback("hpack_filter",
                             nodes.simple_font_handler,
                             "luaotfload.node_processor",
                             1)
end

local init_post_load_agl = function ()

  --[[doc--

      Adobe Glyph List.
      -----------------------------------------------------------------

      Context provides a somewhat different font-age.lua from an
      unclear origin. Unfortunately, the file name it reads from is
      hard-coded in font-enc.lua, so we have to replace the entire
      table.

      This shouldn’t cause any complications. Due to its implementation
      the glyph list will be loaded upon loading a OTF or TTF for the
      first time during a TeX run. (If one sticks to TFM/OFM then it is
      never read at all.) For this reason we can install a metatable
      that looks up the file of our choosing and only falls back to the
      Context one in case it cannot be found.

  --doc]]--

  local findfile  = resolvers.findfile
  local encodings = fonts.encodings

  if not findfile or not encodings then
    --- Might happen during refactoring; we continue graciously but in
    --- a somewhat defect state.
    logreport ("log", 0, "init",
               "preconditions unmet, skipping the Adobe Glyph List; "
               .. "this is a Luaotfload bug.")
    return
  end

  local agl_init = { }      --- start out empty, fill on demand
  encodings.agl  = agl_init --- ugh, replaced again later

  setmetatable (agl_init, { __index = function (t, k)

    if k ~= "unicodes" then
      return nil
    end

    local glyphlist = findfile "luaotfload-glyphlist.lua"
    if glyphlist then
      logreport ("log", 1, "init", "loading the Adobe glyph list")
    else
      glyphlist = findfile "font-age.lua"
      logreport ("both", 0, "init",
                 "loading the extended glyph list from ConTeXt")
    end

    if not glyphlist then
      logreport ("both", 4, "init",
                 "Adobe glyph list not found, please check your installation.")
      return nil
    end
    logreport ("both", 4, "init",
               "found Adobe glyph list file at ``%s``, using that.",
               glyphlist)

    local unicodes = dofile(glyphlist)
    encodings.agl  = { unicodes = unicodes }
    return unicodes
  end })

end

--- (unit -> unit) list
local init_post_actions = {
  init_post_install_callbacks,
  init_post_load_agl,
}

--- unit -> size_t
local init_post = function ()
  --- hook for actions that need to take place after the fontloader is
  --- installed

  local n = #init_post_actions
  for i = 1, n do
    local action = init_post_actions[i]
    local taction = type (action)
    if not action or taction ~= "function" then
      logreport ("both", 1, "init",
                 "post hook WARNING: action %d not a function but %s/%s; ignoring.",
                 i, action, taction)
    else
      --- call closure
      action ()
    end
  end

  return n
end --- [init_post]

return {
  init = function ()
    local starttime = os.gettimeofday ()
    local store = init_pre ()
    store.our_environment, store.context_environment = init_adapt ()
    init_main ()
    init_cleanup (store)
    logreport ("both", 1, "init",
               "fontloader loaded in %0.3f seconds",
               os.gettimeofday() - starttime)
    local n = init_post ()
    logreport ("both", 5, "init", "post hook terminated, %d actions performed", n)
  end
}

