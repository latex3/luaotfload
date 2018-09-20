if not modules then modules = { } end modules ['l-macro-imp-optimize'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is for ConTeXt only and used in development. Only in rare cases we
-- will use this to gain a bit of performance or adapt to specific versions
-- of Lua.

-- There is no real gain as we hardly use these:
--
-- lua.macros.resolvestring [[
--     #define div(a,b) floor(a/b)
--     #define mod(a,b) (a % b)
--     #define odd(a)   (a % 2 ~= 0)
--     #define even(a)  (a % 2 == 0)
--     #define pow(x,y) (x^y)
-- ]]

if LUAVERSION >= 5.3 and lua.macros then

    -- For the moment we only optimize in Lua 5.3:

    lua.macros.enabled = true

    -- This indirect method makes it possible to use both the functions
    -- and the inline variant (which often looks better). Also, a mixed
    -- 5,2 and 5.3 source is not possible because the 5.2 doesn't deal
    -- with the newer 5.3 syntax.

    -- We need to check for 64 usage: 0xFFFFFFFFFFFFFFFF (-1)

 -- lua.macros.resolvestring [[
 --     #define band(a,b)      (a & b)
 --     #define bnot(a)        (~a & 0xFFFFFFFF)
 --     #define bor(a,b)       ((a | b) & 0xFFFFFFFF)
 --     #define btest(a,b)     ((a & b) ~= 0)
 --     #define bxor(a,b)      ((a ~ b) & 0xFFFFFFFF)
 --     #define rshift(a,b)    ((a & b) ~= 0)
 --     #define extract(a,b,c) ((a >> b) & ~(-1 << c))
 --     #define extract(a,b)   ((a >> b) & 0x1))
 --     #define lshift(a,b)    ((a << b) & 0xFFFFFFFF)
 --     #define rshift(a,b)    ((a >> b) & 0xFFFFFFFF)
 -- ]]

lua.macros.resolvestring [[
#define band(a,b)      (a&b)
#define bnot(a)        (~a&0xFFFFFFFF)
#define bor(a,b)       ((a|b)&0xFFFFFFFF)
#define btest(a,b)     ((a&b)~=0)
#define bxor(a,b)      ((a~b)&0xFFFFFFFF)
#define rshift(a,b)    ((a&b)~=0)
#define extract(a,b,c) ((a>>b)&~(-1<<c))
#define extract(a,b)   ((a>>b)&0x1)
#define lshift(a,b)    ((a<<b)&0xFFFFFFFF)
#define rshift(a,b)    ((a>>b)&0xFFFFFFFF)
]]

end
