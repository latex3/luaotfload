-----------------------------------------------------------------------
--         FILE:  luaotfload-multiscript.lua
--  DESCRIPTION:  part of luaotfload / multiscript
-----------------------------------------------------------------------

local ProvidesLuaModule = {
    name          = "luaotfload-multiscript",
    version       = "3.1301-dev",     --TAGVERSION
    date          = "2020-02-02", --TAGDATE
    description   = "luaotfload submodule / multiscript",
    license       = "GPL v2.0",
    author        = "Marcel Krüger"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end

local nodenew            = node.direct.new
local getfont            = font.getfont
local setfont            = node.direct.setfont
local getwhd             = node.direct.getwhd
local insert_after       = node.direct.insert_after
local traverse_char      = node.direct.traverse_char
local protect_glyph      = node.direct.protect_glyph
local otffeatures        = fonts.constructors.newfeatures "otf"
-- local normalize          = fonts.handlers.otf.features.normalize
local definers           = fonts.definers
local define_font        = luaotfload.define_font
local scripts_lib        = require'luaotfload-scripts'.script
local script_to_iso      = scripts_lib.to_iso
local script_to_ot       = scripts_lib.to_ot

local harf = luaotfload.harfbuzz
local GSUBtag, GPOStag
if harf then
  GSUBtag = harf.Tag.new("GSUB")
  GPOStag = harf.Tag.new("GPOS")
end

local sep = lpeg.P' '^0 * ';' * lpeg.P' '^0
local codepoint = lpeg.S'0123456789ABCDEF'^4/function(c)return tonumber(c, 16)end
local codepoint_range = codepoint * ('..' * codepoint + lpeg.Cc(false))
local function multirawset(table, key1, key2, value)
  for key = key1,(key2 or key1) do
    rawset(table, key, value)
  end
  return table
end
local script_extensions do
  local entry = lpeg.Cg(codepoint_range * sep * lpeg.Ct((lpeg.C(lpeg.R'AZ' * lpeg.R'az'^1)/string.lower)^1 * ' ') * '#')^-1 * (1-lpeg.P'\n')^0 * '\n'
  local file = lpeg.Cf(
      lpeg.Ct''
    * entry^0
  , multirawset)

  local f = io.open(kpse.find_file"ScriptExtensions.txt")
  script_extensions = file:match(f:read'*a')
  f:close()
  for cp,t in next, script_extensions do
    for i=1,#t do
      t[t[i]] = true
    end
  end
end
local script_mapping do
  -- We could extract these from PropertyValueAliases.txt...
  local script_aliases = {
    Adlam = "Adlm", Caucasian_Albanian = "Aghb", Ahom = "Ahom", Arabic = "Arab",
    Imperial_Aramaic = "Armi", Armenian = "Armn", Avestan = "Avst",
    Balinese = "Bali", Bamum = "Bamu", Bassa_Vah = "Bass", Batak = "Batk",
    Bengali = "Beng", Bhaiksuki = "Bhks", Bopomofo = "Bopo", Brahmi = "Brah",
    Braille = "Brai", Buginese = "Bugi", Buhid = "Buhd", Chakma = "Cakm",
    Canadian_Aboriginal = "Cans", Carian = "Cari", Cham = "Cham",
    Cherokee = "Cher", Coptic = "Copt", Cypriot = "Cprt", Cyrillic = "Cyrl",
    Devanagari = "Deva", Dogra = "Dogr", Deseret = "Dsrt", Duployan = "Dupl",
    Egyptian_Hieroglyphs = "Egyp", Elbasan = "Elba", Elymaic = "Elym",
    Ethiopic = "Ethi", Georgian = "Geor", Glagolitic = "Glag",
    Gunjala_Gondi = "Gong", Masaram_Gondi = "Gonm", Gothic = "Goth",
    Grantha = "Gran", Greek = "Grek", Gujarati = "Gujr", Gurmukhi = "Guru",
    Hangul = "Hang", Han = "Hani", Hanunoo = "Hano", Hatran = "Hatr",
    Hebrew = "Hebr", Hiragana = "Hira", Anatolian_Hieroglyphs = "Hluw",
    Pahawh_Hmong = "Hmng", Nyiakeng_Puachue_Hmong = "Hmnp",
    Katakana_Or_Hiragana = "Hrkt", Old_Hungarian = "Hung", Old_Italic = "Ital",
    Javanese = "Java", Kayah_Li = "Kali", Katakana = "Kana",
    Kharoshthi = "Khar", Khmer = "Khmr", Khojki = "Khoj", Kannada = "Knda",
    Kaithi = "Kthi", Tai_Tham = "Lana", Lao = "Laoo", Latin = "Latn",
    Lepcha = "Lepc", Limbu = "Limb", Linear_A = "Lina", Linear_B = "Linb",
    Lisu = "Lisu", Lycian = "Lyci", Lydian = "Lydi", Mahajani = "Mahj",
    Makasar = "Maka", Mandaic = "Mand", Manichaean = "Mani", Marchen = "Marc",
    Medefaidrin = "Medf", Mende_Kikakui = "Mend", Meroitic_Cursive = "Merc",
    Meroitic_Hieroglyphs = "Mero", Malayalam = "Mlym", Modi = "Modi",
    Mongolian = "Mong", Mro = "Mroo", Meetei_Mayek = "Mtei", Multani = "Mult",
    Myanmar = "Mymr", Nandinagari = "Nand", Old_North_Arabian = "Narb",
    Nabataean = "Nbat", Newa = "Newa", Nko = "Nkoo", Nushu = "Nshu",
    Ogham = "Ogam", Ol_Chiki = "Olck", Old_Turkic = "Orkh", Oriya = "Orya",
    Osage = "Osge", Osmanya = "Osma", Palmyrene = "Palm", Pau_Cin_Hau = "Pauc",
    Old_Permic = "Perm", Phags_Pa = "Phag", Inscriptional_Pahlavi = "Phli",
    Psalter_Pahlavi = "Phlp", Phoenician = "Phnx", Miao = "Plrd",
    Inscriptional_Parthian = "Prti", Rejang = "Rjng", Hanifi_Rohingya = "Rohg",
    Runic = "Runr", Samaritan = "Samr", Old_South_Arabian = "Sarb",
    Saurashtra = "Saur", SignWriting = "Sgnw", Shavian = "Shaw",
    Sharada = "Shrd", Siddham = "Sidd", Khudawadi = "Sind", Sinhala = "Sinh",
    Sogdian = "Sogd", Old_Sogdian = "Sogo", Sora_Sompeng = "Sora",
    Soyombo = "Soyo", Sundanese = "Sund", Syloti_Nagri = "Sylo",
    Syriac = "Syrc", Tagbanwa = "Tagb", Takri = "Takr", Tai_Le = "Tale",
    New_Tai_Lue = "Talu", Tamil = "Taml", Tangut = "Tang", Tai_Viet = "Tavt",
    Telugu = "Telu", Tifinagh = "Tfng", Tagalog = "Tglg", Thaana = "Thaa",
    Thai = "Thai", Tibetan = "Tibt", Tirhuta = "Tirh", Ugaritic = "Ugar",
    Vai = "Vaii", Warang_Citi = "Wara", Wancho = "Wcho", Old_Persian = "Xpeo",
    Cuneiform = "Xsux", Yi = "Yiii", Zanabazar_Square = "Zanb",
    Inherited = "Zinh", Common = "Zyyy", Unknown = "Zzzz",
  }
  local entry = lpeg.Cg(codepoint_range * sep * ((lpeg.R'AZ' + lpeg.R'az' + '_')^1/script_aliases/string.lower))^-1 * (1-lpeg.P'\n')^0 * '\n'
  -- local entry = lpeg.Cg(codepoint_range * sep * lpeg.Cc(true))^-1 * (1-lpeg.P'\n')^0 * '\n'
  local file = lpeg.Cf(
      lpeg.Ct''
    * entry^0
  , multirawset)

  local f = io.open(kpse.find_file"Scripts.txt")
  script_mapping = file:match(f:read'*a')
  f:close()
end

local function load_on_demand(specifications, size)
  return setmetatable({}, { __index = function(t, k)
    local specification = specifications[k]
    if not specification then return end
    local f = define_font(specification, size)
    local fid
    if type(f) == 'table' then
      fid = font.define(f)
      definers.register(f, fid)
    elseif f then
      fid = f
    end
    t[k] = fid
    return fid
  end})
end

local function collect_scripts(tfmdata)
  local script_dict = {}
  local hbdata = tfmdata.hb
  if hbdata then
    local face = hbdata.shared.face
    for _, tag in next, { GSUBtag, GPOStag } do
      local script_tags = face:ot_layout_get_script_tags(tag) or {}
      for i = 1, #script_tags do
        script_dict[tostring(script_tags[i]):gsub(" +$", "")] = true
      end
    end
  else
    local features = tfmdata.resources.features
    for _, feature_table in next, features do
      for _, scripts in next, feature_table do
        for script in next, scripts do
          script_dict[script] = true
        end
      end
    end
    script_dict["*"] = nil
  end
  return script_dict
end

local additional_scripts_tables = { }

local additional_scripts_fonts = setmetatable({}, {
  __index = function(t, fid)
    local f = font.getfont(fid)
    -- table.tofile('myfont2', f)
    local res = f and f.additional_scripts or false
    t[fid] = res
    return res
  end,
})

local function is_dominant_script(scripts, script, first, ...)
  if script == first then return true end
  if scripts[first] or not first then return false end
  return is_dominant_script(scripts, script, ...)
end

local function makecombifont(tfmdata, _, additional_scripts)
  local has_auto
  additional_scripts = tostring(additional_scripts)
  if additional_scripts:sub(1, 5) == "auto+" then
    additional_scripts = additional_scripts:sub(6)
    has_auto = true
  elseif additional_scripts == "auto" then
    has_auto, additional_scripts = true, false
  end
  if additional_scripts then
    local t = additional_scripts_tables[tonumber(additional_scripts) or additional_scripts]
    if not t then error(string.format("Unknown multiscript table %s", additional_scripts)) end
    local lower_t = {}
    for k, v in next, t do if type(k) == "string" then
      local l = string.lower(k)
      if lower_t[l] ~= nil and lower_t[l] ~= v then
        error(string.format("Inconsistant multiscript table %q for script %s", additional_scripts, l))
      end
      lower_t[l] = v
    end end
    additional_scripts = lower_t
  else
    additional_scripts = {}
  end
  if has_auto then
    local fallback = tfmdata.fallback_lookup
    if fallback then -- FIXME: here be dragons
      local fallbacks = {}
      local current = tfmdata
      local i = 0
      while current do
        local collected = collect_scripts(current)
        for script in next, collected do
          local scr_fb = fallbacks[script]
          if not scr_fb then
            scr_fb = {}
            fallbacks[script] = scr_fb
          end
          scr_fb[#scr_fb + 1] = current.specification.specification .. ';script=' .. script .. ';-multiscript'
        end
        i = i - 1
        current = fallback[i]
      end
      current = tfmdata
      i = 0
      while current do
        local collected = collect_scripts(current)
        for script, scr_fb in next, fallbacks do
          if not collected[script] then
            scr_fb[#scr_fb + 1] = current.specification.specification .. ';-multiscript'
          end
        end
        i = i - 1
        current = fallback[i]
      end
      for script, scr_fb in next, fallbacks do
        local iso_script = script_to_iso(script)
        if not additional_scripts[iso_script] and is_dominant_script(scr_fb, script, script_to_ot(iso_script)) then
          local main = scr_fb[1]
          table.remove(scr_fb, 1)
          local fbid = luaotfload.add_fallback(scr_fb)
          additional_scripts[iso_script] = main .. ';fallback=' .. fbid
        end
      end
    else
      local spec = tfmdata.specification
      local collected = collect_scripts(tfmdata)
      for script in next, collected do
        local iso_script = script_to_iso(script)
        if not additional_scripts[iso_script] and is_dominant_script(collected, script, script_to_ot(iso_script)) then
          additional_scripts[iso_script] = spec.specification .. ';-multiscript;script=' .. script
          ---- FIXME: IMHO the following which just modiefies the spec
          --   would be nicer, but it breaks font patching callbacks
          --   (except if we ignore them, but that would be inconsistant to
          --    other fonts)
          -- local new_raw_features = {}
          -- local new_features = { raw = new_raw_features, normal = new_raw_features }
          -- for f, v in next, spec.features.raw do
          --   new_raw_features[f] = v
          -- end
          -- new_raw_features.multiscript = false
          -- new_raw_features.script = script
          -- local new_normal_features = luaotfload.apply_default_features(new_raw_features)
          -- new_normal_features.sub = nil
          -- new_normal_features.lookup = nil
          -- new_features.normal = normalize(new_normal_features)
          -- local new_spec = {}
          -- for k, v in next, spec do
          --   new_spec[k] = v
          -- end
          -- new_spec.hash = nil
          -- new_spec.features = new_features
          -- additional_scripts[script] = new_spec
        end
      end
    end
  end
  local basescript = tfmdata.properties.script or "dflt"
  tfmdata.additional_scripts = load_on_demand(additional_scripts, tfmdata.size)
  tfmdata.additional_scripts[basescript] = false
end

local glyph_id = node.id'glyph'
-- TODO: unset last_script, matching parentheses etc
function domultiscript(head, _, _, _, direction)
  head = node.direct.todirect(head)
  local last_fid, last_fonts, last_script
  for cur, cid, fid in traverse_char(head) do
    if fid ~= last_fid then
      last_fid, last_fonts, last_script = fid, additional_scripts_fonts[fid]
    end
    if last_fonts then
      local mapped_scr = script_mapping[cid]
      if mapped_scr == "zinh" then
        mapped_scr = last_script
      else
        local additional_scripts = script_extensions[cid]
        if additional_scripts then
          if additional_scripts[last_script] then
            mapped_scr = last_script
          elseif last_fonts[mapped_scr] == nil then
            for i = 1, #additional_scripts do
              local script = additional_scripts[i]
              if last_fonts[script] ~= nil then
                mapped_scr = script
                break
              end
            end
          end
        elseif mapped_scr == "zyyy" then
          mapped_scr = last_script
        end
      end
      last_script = mapped_scr
      local mapped_font = last_fonts[mapped_scr]
      if mapped_font then
        setfont(cur, mapped_font)
      end
    end
  end
end

function luaotfload.add_multiscript(name, fonts)
  if fonts == nil then
    fonts = name
    name = #additional_scripts_fonts + 1
  else
    name = name:lower()
  end
  additional_scripts_tables[name] = fonts
  return name
end

otffeatures.register {
  name        = "multiscript",
  description = "Combine fonts for multiple scripts",
  manipulators = {
    node = makecombifont,
    plug = makecombifont,
  },
  -- processors = { -- processors would be nice, but they are applied
  --                -- too late for our purposes
  --   node = donotdef,
  -- }
}

--- vim:sw=2:ts=2:expandtab:tw=71
