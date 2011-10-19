local fonts       = fonts
local readers     = fonts.readers

fonts.formats.pfb = "pfb"
fonts.formats.pfa = "pfa"

function readers.pfb(specification) return readers.opentype(specification,"pfb","type1") end
function readers.pfa(specification) return readers.opentype(specification,"pfa","type1") end
