if not modules then modules = { } end modules ['l-math'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local floor, sin, cos, tan = math.floor, math.sin, math.cos, math.tan

if not math.round then
    function math.round(x) return floor(x + 0.5) end
end

if not math.div then
    function math.div(n,m) return floor(n/m) end
end

if not math.mod then
    function math.mod(n,m) return n % m end
end

local pipi = 2*math.pi/360

if not math.sind then
    function math.sind(d) return sin(d*pipi) end
    function math.cosd(d) return cos(d*pipi) end
    function math.tand(d) return tan(d*pipi) end
end

if not math.odd then
    function math.odd (n) return n % 2 ~= 0 end
    function math.even(n) return n % 2 == 0 end
end
