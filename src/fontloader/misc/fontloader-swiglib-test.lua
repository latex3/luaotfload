local gm = swiglib("gmwand.core")

gm.InitializeMagick(".")

local magick_wand  = gm.NewMagickWand()
local drawing_wand = gm.NewDrawingWand()

gm.MagickSetSize(magick_wand,800,600)
gm.MagickReadImage(magick_wand,"xc:red")

gm.DrawPushGraphicContext(drawing_wand)

gm.DrawSetFillColor(drawing_wand,gm.NewPixelWand())

-- gm.DrawSetFont(drawing_wand, kpse.findfile("DejaVuSerifBold.ttf"))
-- gm.DrawSetFontSize(drawing_wand, 96)
-- gm.DrawAnnotation(drawing_wand,300,200, "LuaTeX")

gm.DrawPopGraphicContext(drawing_wand)
gm.MagickDrawImage(magick_wand,drawing_wand)

gm.MagickWriteImages(magick_wand,"./luatex-swiglib-test.jpg",1)

gm.DestroyDrawingWand(drawing_wand)
gm.DestroyMagickWand(magick_wand)
