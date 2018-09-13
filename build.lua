-- l3build check settings for luaotfload

module="luaotfload"

stdengine    = "luatex"
checkengines = {"luatex"}
checkconfigs = {"build","config-latex-TU","config-unicode-math","config-plain","config-fontspec"}

checkruns = 3

kpse.set_program_name ("kpsewhich")
if not release_date then
 dofile ( kpse.lookup ("l3build.lua"))
end
