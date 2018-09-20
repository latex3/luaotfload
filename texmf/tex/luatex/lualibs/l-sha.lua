if not modules then modules = { } end modules ['l-sha'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if sha2 then

    local lpegmatch    = lpeg.match
    local lpegpatterns = lpeg.patterns
    local bytestohex   = lpegpatterns.bytestohex
    local bytestoHEX   = lpegpatterns.bytestoHEX

    local digest256 = sha2.digest256
    local digest384 = sha2.digest384
    local digest512 = sha2.digest512

    sha2.hash256 = function(str) return lpegmatch(bytestohex,digest256(str)) end
    sha2.hash384 = function(str) return lpegmatch(bytestohex,digest384(str)) end
    sha2.hash512 = function(str) return lpegmatch(bytestohex,digest512(str)) end
    sha2.HASH256 = function(str) return lpegmatch(bytestoHEX,digest256(str)) end
    sha2.HASH384 = function(str) return lpegmatch(bytestoHEX,digest384(str)) end
    sha2.HASH512 = function(str) return lpegmatch(bytestoHEX,digest512(str)) end

end
