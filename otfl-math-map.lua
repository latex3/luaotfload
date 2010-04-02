if not modules then modules = { } end modules ['math-map'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Remapping mathematics alphabets.</p>
--ldx]]--

-- oldstyle: not really mathematics but happened to be part of
-- the mathematics fonts in cmr
--
-- persian: we will also provide mappers for other
-- scripts

-- todo: alphabets namespace
-- maybe: script/scriptscript dynamic,

local type, next = type, next
local floor = math.floor

local texattribute = tex.attribute

local trace_greek  = false  trackers.register("math.greek",  function(v) trace_greek = v end)

mathematics = mathematics or { }

-- we could use one level less and have tf etc be tables directly but the
-- following approach permits easier remapping of a-a, A-Z and 0-9 to
-- fallbacks; symbols is currently mostly greek

mathematics.alphabets = {
    regular = {
        tf = {
            digits    = 0x00030,
            ucletters = 0x00041,
            lcletters = 0x00061,
            ucgreek   = {
                [0x0391]=0x0391, [0x0392]=0x0392, [0x0393]=0x0393, [0x0394]=0x0394, [0x0395]=0x0395,
                [0x0396]=0x0396, [0x0397]=0x0397, [0x0398]=0x0398, [0x0399]=0x0399, [0x039A]=0x039A,
                [0x039B]=0x039B, [0x039C]=0x039C, [0x039D]=0x039D, [0x039E]=0x039E, [0x039F]=0x039F,
                [0x03A0]=0x03A0, [0x03A1]=0x03A1, [0x03A3]=0x03A3, [0x03A4]=0x03A4, [0x03A5]=0x03A5,
                [0x03A6]=0x03A6, [0x03A7]=0x03A7, [0x03A8]=0x03A8, [0x03A9]=0x03A9,
                },
            lcgreek   = {
                [0x03B1]=0x03B1, [0x03B2]=0x03B2, [0x03B3]=0x03B3, [0x03B4]=0x03B4, [0x03B5]=0x03B5,
                [0x03B6]=0x03B6, [0x03B7]=0x03B7, [0x03B8]=0x03B8, [0x03B9]=0x03B9, [0x03BA]=0x03BA,
                [0x03BB]=0x03BB, [0x03BC]=0x03BC, [0x03BD]=0x03BD, [0x03BE]=0x03BE, [0x03BF]=0x03BF,
                [0x03C0]=0x03C0, [0x03C1]=0x03C1, [0x03C2]=0x03C2, [0x03C3]=0x03C3, [0x03C4]=0x03C4,
                [0x03C5]=0x03C5, [0x03C6]=0x03C6, [0x03C7]=0x03C7, [0x03C8]=0x03C8, [0x03C9]=0x03C9,
                [0x03D1]=0x03D1, [0x03D5]=0x03D5, [0x03D6]=0x03D6, [0x03F0]=0x03F0, [0x03F1]=0x03F1,
                [0x03F4]=0x03F4, [0x03F5]=0x03F5,
            },
            symbols   = {
                [0x2202]=0x2202, [0x2207]=0x2207,
            },
        },
        it = {
            ucletters = 0x1D434,
            lcletters = { -- H
                [0x00061]=0x1D44E, [0x00062]=0x1D44F, [0x00063]=0x1D450, [0x00064]=0x1D451, [0x00065]=0x1D452,
                [0x00066]=0x1D453, [0x00067]=0x1D454, [0x00068]=0x0210E, [0x00069]=0x1D456, [0x0006A]=0x1D457,
                [0x0006B]=0x1D458, [0x0006C]=0x1D459, [0x0006D]=0x1D45A, [0x0006E]=0x1D45B, [0x0006F]=0x1D45C,
                [0x00070]=0x1D45D, [0x00071]=0x1D45E, [0x00072]=0x1D45F, [0x00073]=0x1D460, [0x00074]=0x1D461,
                [0x00075]=0x1D462, [0x00076]=0x1D463, [0x00077]=0x1D464, [0x00078]=0x1D465, [0x00079]=0x1D466,
                [0x0007A]=0x1D467,
            },
            ucgreek   = {
                [0x0391]=0x1D6E2, [0x0392]=0x1D6E3, [0x0393]=0x1D6E4, [0x0394]=0x1D6E5, [0x0395]=0x1D6E6,
                [0x0396]=0x1D6E7, [0x0397]=0x1D6E8, [0x0398]=0x1D6E9, [0x0399]=0x1D6EA, [0x039A]=0x1D6EB,
                [0x039B]=0x1D6EC, [0x039C]=0x1D6ED, [0x039D]=0x1D6EE, [0x039E]=0x1D6EF, [0x039F]=0x1D6F0,
                [0x03A0]=0x1D6F1, [0x03A1]=0x1D6F2, [0x03A3]=0x1D6F4, [0x03A4]=0x1D6F5, [0x03A5]=0x1D6F6,
                [0x03A6]=0x1D6F7, [0x03A7]=0x1D6F8, [0x03A8]=0x1D6F9, [0x03A9]=0x1D6FA,
                },
            lcgreek   = {
                [0x03B1]=0x1D6FC, [0x03B2]=0x1D6FD, [0x03B3]=0x1D6FE, [0x03B4]=0x1D6FF, [0x03B5]=0x1D700,
                [0x03B6]=0x1D701, [0x03B7]=0x1D702, [0x03B8]=0x1D703, [0x03B9]=0x1D704, [0x03BA]=0x1D705,
                [0x03BB]=0x1D706, [0x03BC]=0x1D707, [0x03BD]=0x1D708, [0x03BE]=0x1D709, [0x03BF]=0x1D70A,
                [0x03C0]=0x1D70B, [0x03C1]=0x1D70C, [0x03C2]=0x1D70D, [0x03C3]=0x1D70E, [0x03C4]=0x1D70F,
                [0x03C5]=0x1D710, [0x03C6]=0x1D711, [0x03C7]=0x1D712, [0x03C8]=0x1D713, [0x03C9]=0x1D714,
                [0x03D1]=0x1D717, [0x03D5]=0x1D719, [0x03D6]=0x1D71B, [0x03F0]=0x1D718, [0x03F1]=0x1D71A,
                [0x03F4]=0x1D6F3, [0x03F5]=0x1D716,
            },
            symbols   = {
                [0x2202]=0x1D715, [0x2207]=0x1D6FB,
            },
        },
        bf= {
            digits    = 0x1D7CE,
            ucletters = 0x1D400,
            lcletters = 0x1D41A,
            ucgreek   = {
                [0x0391]=0x1D6A8, [0x0392]=0x1D6A9, [0x0393]=0x1D6AA, [0x0394]=0x1D6AB, [0x0395]=0x1D6AC,
                [0x0396]=0x1D6AD, [0x0397]=0x1D6AE, [0x0398]=0x1D6AF, [0x0399]=0x1D6B0, [0x039A]=0x1D6B1,
                [0x039B]=0x1D6B2, [0x039C]=0x1D6B3, [0x039D]=0x1D6B4, [0x039E]=0x1D6B5, [0x039F]=0x1D6B6,
                [0x03A0]=0x1D6B7, [0x03A1]=0x1D6B8, [0x03A3]=0x1D6BA, [0x03A4]=0x1D6BB, [0x03A5]=0x1D6BC,
                [0x03A6]=0x1D6BD, [0x03A7]=0x1D6BE, [0x03A8]=0x1D6BF, [0x03A9]=0x1D6C0,
                },
            lcgreek   = {
                [0x03B1]=0x1D6C2, [0x03B2]=0x1D6C3, [0x03B3]=0x1D6C4, [0x03B4]=0x1D6C5, [0x03B5]=0x1D6C6,
                [0x03B6]=0x1D6C7, [0x03B7]=0x1D6C8, [0x03B8]=0x1D6C9, [0x03B9]=0x1D6CA, [0x03BA]=0x1D6CB,
                [0x03BB]=0x1D6CC, [0x03BC]=0x1D6CD, [0x03BD]=0x1D6CE, [0x03BE]=0x1D6CF, [0x03BF]=0x1D6D0,
                [0x03C0]=0x1D6D1, [0x03C1]=0x1D6D2, [0x03C2]=0x1D6D3, [0x03C3]=0x1D6D4, [0x03C4]=0x1D6D5,
                [0x03C5]=0x1D6D6, [0x03C6]=0x1D6D7, [0x03C7]=0x1D6D8, [0x03C8]=0x1D6D9, [0x03C9]=0x1D6DA,
                [0x03D1]=0x1D6DD, [0x03D5]=0x1D6DF, [0x03D6]=0x1D6E1, [0x03F0]=0x1D6DE, [0x03F1]=0x1D6E0,
                [0x03F4]=0x1D6B9, [0x03F5]=0x1D6DC,
            },
            symbols   = {
                [0x2202]=0x1D6DB, [0x2207]=0x1D6C1,
            },
        },
        bi = {
            ucletters = 0x1D468,
            lcletters = 0x1D482,
            ucgreek   = {
                [0x0391]=0x1D71C, [0x0392]=0x1D71D, [0x0393]=0x1D71E, [0x0394]=0x1D71F, [0x0395]=0x1D720,
                [0x0396]=0x1D721, [0x0397]=0x1D722, [0x0398]=0x1D723, [0x0399]=0x1D724, [0x039A]=0x1D725,
                [0x039B]=0x1D726, [0x039C]=0x1D727, [0x039D]=0x1D728, [0x039E]=0x1D729, [0x039F]=0x1D72A,
                [0x03A0]=0x1D72B, [0x03A1]=0x1D72C, [0x03A3]=0x1D72E, [0x03A4]=0x1D72F, [0x03A5]=0x1D730,
                [0x03A6]=0x1D731, [0x03A7]=0x1D732, [0x03A8]=0x1D733, [0x03A9]=0x1D734,
                },
            lcgreek   = {
                [0x03B1]=0x1D736, [0x03B2]=0x1D737, [0x03B3]=0x1D738, [0x03B4]=0x1D739, [0x03B5]=0x1D73A,
                [0x03B6]=0x1D73B, [0x03B7]=0x1D73C, [0x03B8]=0x1D73D, [0x03B9]=0x1D73E, [0x03BA]=0x1D73F,
                [0x03BB]=0x1D740, [0x03BC]=0x1D741, [0x03BD]=0x1D742, [0x03BE]=0x1D743, [0x03BF]=0x1D744,
                [0x03C0]=0x1D745, [0x03C1]=0x1D746, [0x03C2]=0x1D747, [0x03C3]=0x1D748, [0x03C4]=0x1D749,
                [0x03C5]=0x1D74A, [0x03C6]=0x1D74B, [0x03C7]=0x1D74C, [0x03C8]=0x1D74D, [0x03C9]=0x1D74E,
                [0x03D1]=0x1D751, [0x03D5]=0x1D753, [0x03D6]=0x1D755, [0x03F0]=0x1D752, [0x03F1]=0x1D754,
                [0x03F4]=0x1D72D, [0x03F5]=0x1D750,
            },
            symbols   = {
                [0x2202]=0x1D74F, [0x2207]=0x1D735,
            },
        },
    },
    sansserif = {
        tf = {
            digits    = 0x1D7E2,
            ucletters = 0x1D5A0,
            lcletters = 0x1D5BA,
        },
        it = {
            ucletters = 0x1D608,
            lcletters = 0x1D622,
        },
        bf = {
            digits    = 0x1D7EC,
            ucletters = 0x1D5D4,
            lcletters = 0x1D5EE,
            ucgreek   = {
                [0x0391]=0x1D756, [0x0392]=0x1D757, [0x0393]=0x1D758, [0x0394]=0x1D759, [0x0395]=0x1D75A,
                [0x0396]=0x1D75B, [0x0397]=0x1D75C, [0x0398]=0x1D75D, [0x0399]=0x1D75E, [0x039A]=0x1D75F,
                [0x039B]=0x1D760, [0x039C]=0x1D761, [0x039D]=0x1D762, [0x039E]=0x1D763, [0x039F]=0x1D764,
                [0x03A0]=0x1D765, [0x03A1]=0x1D766, [0x03A3]=0x1D768, [0x03A4]=0x1D769, [0x03A5]=0x1D76A,
                [0x03A6]=0x1D76B, [0x03A7]=0x1D76C, [0x03A8]=0x1D76D, [0x03A9]=0x1D76E,
                },
            lcgreek   = {
                [0x03B1]=0x1D770, [0x03B2]=0x1D771, [0x03B3]=0x1D772, [0x03B4]=0x1D773, [0x03B5]=0x1D774,
                [0x03B6]=0x1D775, [0x03B7]=0x1D776, [0x03B8]=0x1D777, [0x03B9]=0x1D778, [0x03BA]=0x1D779,
                [0x03BB]=0x1D77A, [0x03BC]=0x1D77B, [0x03BD]=0x1D77C, [0x03BE]=0x1D77D, [0x03BF]=0x1D77E,
                [0x03C0]=0x1D77F, [0x03C1]=0x1D780, [0x03C2]=0x1D781, [0x03C3]=0x1D782, [0x03C4]=0x1D783,
                [0x03C5]=0x1D784, [0x03C6]=0x1D785, [0x03C7]=0x1D786, [0x03C8]=0x1D787, [0x03C9]=0x1D788,
                [0x03D1]=0x1D78B, [0x03D5]=0x1D78D, [0x03D6]=0x1D78F, [0x03F0]=0x1D78C, [0x03F1]=0x1D78E,
                [0x03F4]=0x1D767, [0x03F5]=0x1D78A,
            },
            symbols   = {
                [0x2202]=0x1D789, [0x2207]=0x1D76F,
            },
        },
        bi = {
            ucletters = 0x1D63C,
            lcletters = 0x1D656,
            ucgreek   = {
                [0x0391]=0x1D790, [0x0392]=0x1D791, [0x0393]=0x1D792, [0x0394]=0x1D793, [0x0395]=0x1D794,
                [0x0396]=0x1D795, [0x0397]=0x1D796, [0x0398]=0x1D797, [0x0399]=0x1D798, [0x039A]=0x1D799,
                [0x039B]=0x1D79A, [0x039C]=0x1D79B, [0x039D]=0x1D79C, [0x039E]=0x1D79D, [0x039F]=0x1D79E,
                [0x03A0]=0x1D79F, [0x03A1]=0x1D7A0, [0x03A3]=0x1D7A2, [0x03A4]=0x1D7A3, [0x03A5]=0x1D7A4,
                [0x03A6]=0x1D7A5, [0x03A7]=0x1D7A6, [0x03A8]=0x1D7A7, [0x03A9]=0x1D7A8,
                },
            lcgreek   = {
                [0x03B1]=0x1D7AA, [0x03B2]=0x1D7AB, [0x03B3]=0x1D7AC, [0x03B4]=0x1D7AD, [0x03B5]=0x1D7AE,
                [0x03B6]=0x1D7AF, [0x03B7]=0x1D7B0, [0x03B8]=0x1D7B1, [0x03B9]=0x1D7B2, [0x03BA]=0x1D7B3,
                [0x03BB]=0x1D7B4, [0x03BC]=0x1D7B5, [0x03BD]=0x1D7B6, [0x03BE]=0x1D7B7, [0x03BF]=0x1D7B8,
                [0x03C0]=0x1D7B9, [0x03C1]=0x1D7BA, [0x03C2]=0x1D7BB, [0x03C3]=0x1D7BC, [0x03C4]=0x1D7BD,
                [0x03C5]=0x1D7BE, [0x03C6]=0x1D7BF, [0x03C7]=0x1D7C0, [0x03C8]=0x1D7C1, [0x03C9]=0x1D7C2,
                [0x03D1]=0x1D7C5, [0x03D5]=0x1D7C7, [0x03D6]=0x1D7C9, [0x03F0]=0x1D7C6, [0x03F1]=0x1D7C8,
                [0x03F4]=0x1D7A1, [0x03F5]=0x1D7C4,
            },
            symbols   = {
                [0x2202]=0x1D7C3, [0x2207]=0x1D7A9,
            },
        },
    },
    monospaced = {
        tf = {
            digits    = 0x1D7F6,
            ucletters = 0x1D670,
            lcletters = 0x1D68A,
        },
    },
    blackboard = { -- ok
        tf = {
            digits    = 0x1D7D8,
            ucletters = { -- C H N P Q R Z
                [0x00041]=0x1D538, [0x00042]=0x1D539, [0x00043]=0x02102, [0x00044]=0x1D53B, [0x00045]=0x1D53C,
                [0x00046]=0x1D53D, [0x00047]=0x1D53E, [0x00048]=0x0210D, [0x00049]=0x1D540, [0x0004A]=0x1D541,
                [0x0004B]=0x1D542, [0x0004C]=0x1D543, [0x0004D]=0x1D544, [0x0004E]=0x02115, [0x0004F]=0x1D546,
                [0x00050]=0x02119, [0x00051]=0x0211A, [0x00052]=0x0211D, [0x00053]=0x1D54A, [0x00054]=0x1D54B,
                [0x00055]=0x1D54C, [0x00056]=0x1D54D, [0x00057]=0x1D54E, [0x00058]=0x1D54F, [0x00059]=0x1D550,
                [0x0005A]=0x02124,
            },
            lcletters = 0x1D552,
            lcgreek = { -- gamma pi
                [0x03B3]=0x0213C, [0x03C0]=0x0213D,
            },
            ucgreek = { -- Gamma pi
                [0x0393]=0x0213E, [0x03A0]=0x0213F,
            },
            symbols = { -- sum
              [0x2211]=0x02140,
            },
        },
    },
    fraktur = { -- ok
        tf= {
            ucletters = { -- C H I R Z
                [0x00041]=0x1D504, [0x00042]=0x1D505, [0x00043]=0x0212D, [0x00044]=0x1D507, [0x00045]=0x1D508,
                [0x00046]=0x1D509, [0x00047]=0x1D50A, [0x00048]=0x0210C, [0x00049]=0x02111, [0x0004A]=0x1D50D,
                [0x0004B]=0x1D50E, [0x0004C]=0x1D50F, [0x0004D]=0x1D510, [0x0004E]=0x1D511, [0x0004F]=0x1D512,
                [0x00050]=0x1D513, [0x00051]=0x1D514, [0x00052]=0x0211C, [0x00053]=0x1D516, [0x00054]=0x1D517,
                [0x00055]=0x1D518, [0x00056]=0x1D519, [0x00057]=0x1D51A, [0x00058]=0x1D51B, [0x00059]=0x1D51C,
                [0x0005A]=0x02128,
            },
            lcletters = 0x1D51E,
        },
        bf = {
            ucletters = 0x1D56C,
            lcletters = 0x1D586,
        },
    },
    script = {
        tf= {
            ucletters = { -- B E F H I L M R -- P 2118
                [0x00041]=0x1D49C, [0x00042]=0x0212C, [0x00043]=0x1D49E, [0x00044]=0x1D49F, [0x00045]=0x02130,
                [0x00046]=0x02131, [0x00047]=0x1D4A2, [0x00048]=0x0210B, [0x00049]=0x02110, [0x0004A]=0x1D4A5,
                [0x0004B]=0x1D4A6, [0x0004C]=0x02112, [0x0004D]=0x02133, [0x0004E]=0x1D4A9, [0x0004F]=0x1D4AA,
                [0x00050]=0x1D4AB, [0x00051]=0x1D4AC, [0x00052]=0x0211B, [0x00053]=0x1D4AE, [0x00054]=0x1D4AF,
                [0x00055]=0x1D4B0, [0x00056]=0x1D4B1, [0x00057]=0x1D4B2, [0x00058]=0x1D4B3, [0x00059]=0x1D4B4,
                [0x0005A]=0x1D4B5,
            },
            lcletters = { -- E G O -- L 2113
                [0x00061]=0x1D4B6, [0x00062]=0x1D4B7, [0x00063]=0x1D4B8, [0x00064]=0x1D4B9, [0x00065]=0x0212F,
                [0x00066]=0x1D4BB, [0x00067]=0x0210A, [0x00068]=0x1D4BD, [0x00069]=0x1D4BE, [0x0006A]=0x1D4BF,
                [0x0006B]=0x1D4C0, [0x0006C]=0x1D4C1, [0x0006D]=0x1D4C2, [0x0006E]=0x1D4C3, [0x0006F]=0x02134,
                [0x00070]=0x1D4C5, [0x00071]=0x1D4C6, [0x00072]=0x1D4C7, [0x00073]=0x1D4C8, [0x00074]=0x1D4C9,
                [0x00075]=0x1D4CA, [0x00076]=0x1D4CB, [0x00077]=0x1D4CC, [0x00078]=0x1D4CD, [0x00079]=0x1D4CE,
                [0x0007A]=0x1D4CF,
            }
        },
        bf = {
            ucletters = 0x1D4D0,
            lcletters = 0x1D4EA,
        },
    },
}

local alphabets = mathematics.alphabets
local mathremap = { }

for alphabet, styles in next, alphabets do
    for style, data in next, styles do
     -- let's keep the long names (for tracing)
        local n = #mathremap + 1
        data.attribute = n
        data.alphabet = alphabet
        data.style = style
        mathremap[n] = data
    end
end

-- beware, these are shared tables (no problem since they're not
-- in unicode)

alphabets.regular.it.digits     = alphabets.regular.tf.digits
alphabets.regular.bi.digits     = alphabets.regular.bf.digits

alphabets.sansserif.tf.symbols  = alphabets.regular.tf.symbols
alphabets.sansserif.tf.lcgreek  = alphabets.regular.tf.lcgreek
alphabets.sansserif.tf.ucgreek  = alphabets.regular.tf.ucgreek
alphabets.sansserif.tf.digits   = alphabets.regular.tf.digits
alphabets.sansserif.it.symbols  = alphabets.regular.tf.symbols
alphabets.sansserif.it.lcgreek  = alphabets.regular.tf.lcgreek
alphabets.sansserif.it.ucgreek  = alphabets.regular.tf.ucgreek
alphabets.sansserif.bi.digits   = alphabets.regular.bf.digits

alphabets.monospaced.tf.symbols = alphabets.sansserif.tf.symbols
alphabets.monospaced.tf.lcgreek = alphabets.sansserif.tf.lcgreek
alphabets.monospaced.tf.ucgreek = alphabets.sansserif.tf.ucgreek
alphabets.monospaced.it         = alphabets.sansserif.tf
alphabets.monospaced.bf         = alphabets.sansserif.tf
alphabets.monospaced.bi         = alphabets.sansserif.bf

alphabets.blackboard.tf.symbols = table.merge(alphabets.regular.tf.symbols, alphabets.blackboard.tf.symbols)
alphabets.blackboard.tf.lcgreek = table.merge(alphabets.regular.tf.lcgreek, alphabets.blackboard.tf.lcgreek)
alphabets.blackboard.tf.ucgreek = table.merge(alphabets.regular.tf.ucgreek, alphabets.blackboard.tf.ucgreek)

alphabets.blackboard.it         = alphabets.blackboard.tf
alphabets.blackboard.bf         = alphabets.blackboard.tf
alphabets.blackboard.bi         = alphabets.blackboard.bf

alphabets.fraktur.tf.digits     = alphabets.regular.tf.digits
alphabets.fraktur.tf.symbols    = alphabets.regular.tf.symbols
alphabets.fraktur.tf.lcgreek    = alphabets.regular.tf.lcgreek
alphabets.fraktur.tf.ucgreek    = alphabets.regular.tf.ucgreek
alphabets.fraktur.bf.digits     = alphabets.regular.bf.digits
alphabets.fraktur.bf.symbols    = alphabets.regular.bf.symbols
alphabets.fraktur.bf.lcgreek    = alphabets.regular.bf.lcgreek
alphabets.fraktur.bf.ucgreek    = alphabets.regular.bf.ucgreek
alphabets.fraktur.it            = alphabets.fraktur.tf
alphabets.fraktur.bi            = alphabets.fraktur.bf

alphabets.script.tf.digits      = alphabets.regular.tf.digits
alphabets.script.tf.symbols     = alphabets.regular.tf.symbols
alphabets.script.tf.lcgreek     = alphabets.regular.tf.lcgreek
alphabets.script.tf.ucgreek     = alphabets.regular.tf.ucgreek
alphabets.script.bf.digits      = alphabets.regular.bf.digits
alphabets.script.bf.symbols     = alphabets.regular.bf.symbols
alphabets.script.bf.lcgreek     = alphabets.regular.bf.lcgreek
alphabets.script.bf.ucgreek     = alphabets.regular.bf.ucgreek
alphabets.script.it             = alphabets.script.tf
alphabets.script.bi             = alphabets.script.bf

alphabets.tt = alphabets.monospaced
alphabets.ss = alphabets.sansserif
alphabets.rm = alphabets.regular
alphabets.bb = alphabets.blackboard
alphabets.fr = alphabets.fraktur
alphabets.sr = alphabets.script

alphabets.serif    = alphabets.regular
alphabets.type     = alphabets.monospaced
alphabets.teletype = alphabets.monospaced

function mathematics.to_a_style(attribute)
    local r = mathremap[attribute]
    return r and r.style or "tf"
end

function mathematics.to_a_name(attribute)
    local r = mathremap[attribute]
    return r and r.alphabet or "regular"
end

-- of course we could do some div/mod trickery instead

local mathalphabet = attributes.private("mathalphabet")

function mathematics.sync_a_both(alphabet,style)
    local data = alphabets[alphabet or "regular"] or alphabets.regular
    data = data[style or "tf"] or data.tf
    texattribute[mathalphabet] = data and data.attribute or texattribute[mathalphabet]
end

function mathematics.sync_a_style(style)
--~ local r = mathremap[mathalphabet]
    local r = mathremap[texattribute[mathalphabet]]
    local alphabet = r and r.alphabet or "regular"
    local data = alphabets[alphabet][style]
    texattribute[mathalphabet] = data and data.attribute or texattribute[mathalphabet]
end

function mathematics.sync_a_name(alphabet)
--~ local r = mathremap[mathalphabet]
    local r = mathremap[texattribute[mathalphabet]]
    local style = r and r.style or "tf"
    local data = alphabets[alphabet][style]
    texattribute[mathalphabet] = data and data.attribute or texattribute[mathalphabet]
end

local issymbol  = mathematics.alphabets.regular.tf.symbols
local islcgreek = mathematics.alphabets.regular.tf.lcgreek
local isucgreek = mathematics.alphabets.regular.tf.ucgreek

local remapping = {
    [1] = { what = "unchanged" }, -- upright
    [2] = { what = "upright", it = "tf", bi = "bf" }, -- upright
    [3] = { what = "italic",  tf = "it", bf = "bi" }, -- italic
}

function mathematics.remap_alphabets(char,mathalphabet,mathgreek)
    if mathgreek > 0 then
        local lc, uc = floor(mathgreek/10), mathgreek % 10 -- 2 == upright 3 == italic
        if lc > 1 or uc > 1 then
            local islc, isuc = islcgreek[char] and lc, isucgreek[char] and uc
            if islc or isuc then
                local r = mathremap[mathalphabet] -- what if 0
                local alphabet = r and r.alphabet or "regular"
                local style = r and r.style or "tf"
                if trace_greek then
                    logs.report("math","before: char: %05X, alphabet: %s %s, lcgreek: %s, ucgreek: %s",char,alphabet,style,remapping[lc].what,remapping[uc].what)
                end
                local s = remapping[islc or isuc][style]
                if s then
                    local data = alphabets[alphabet][s]
                    mathalphabet, style = data and data.attribute or mathalphabet, s
                end
                if trace_greek then
                    logs.report("math","after : char: %05X, alphabet: %s %s, lcgreek: %s, ucgreek: %s",char,alphabet,style,remapping[lc].what,remapping[uc].what)
                end
            end
        end
    end
    if mathalphabet > 0 then
        local newchar
        local offset = mathremap[mathalphabet]
        if not offset then
            -- nothing to remap
        elseif char >= 0x030 and char <= 0x039 then
            local o = offset.digits
            newchar = (type(o) == "table" and (o[char] or char)) or (char - 0x030 + o)
        elseif char >= 0x041 and char <= 0x05A then
            local o = offset.ucletters
            newchar = (type(o) == "table" and (o[char] or char)) or (char - 0x041 + o)
        elseif char >= 0x061 and char <= 0x07A then
            local o = offset.lcletters
            newchar = (type(o) == "table" and (o[char] or char)) or (char - 0x061 + o)
        elseif islcgreek[char] then
            newchar = offset.lcgreek[char]
        elseif isucgreek[char] then
            newchar = offset.ucgreek[char]
        elseif issymbol[char] then
            newchar = offset.symbols[char]
        end
        return newchar ~= char and newchar
    end
    return nil
end
