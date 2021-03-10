rem */\(1+[a-z\-]\)\.\(2+[a-z]\)\.*
rem */\(1+[a-zA-Z0-9\-\_]\)\.\(2+[a-z]\)\.*
rem l3build save -e\2 \1
rem l3build save -cconfig-XXXX -e\2 \1

rem Failed tests for configuration build:
rem
rem   Check failed with difference files
rem   - ./build/test/aaaaa-luakern.luatexdev.fc
rem   - ./build/test/add-uppercase-feature.luatex.fc
rem   - ./build/test/add-uppercase-feature.luatexdev.fc
rem   - ./build/test/arab1.luatexdev.fc
rem   - ./build/test/arab2.luatexdev.fc
rem   - ./build/test/arab3.luatexdev.fc
rem   - ./build/test/automatichyphenmode.luatexdev.fc
rem   - ./build/test/color.luatex.fc
rem   - ./build/test/color.luatexdev.fc
rem   - ./build/test/embolden-math.luatexdev.fc
rem   - ./build/test/embolden-text.luatex.fc
rem   - ./build/test/embolden-text.luatexdev.fc
rem   - ./build/test/invisible-chars.luatexdev.fc
rem   - ./build/test/issue11.luatexdev.fc
rem   - ./build/test/issue47-mac-only-font-family.luatexdev.fc
rem   - ./build/test/issue53-whatsits.luatexdev.fc
rem   - ./build/test/iwona-PR42.luatexdev.fc
rem   - ./build/test/latex-font-input-syntax.luatexdev.fc
rem   - ./build/test/latex-font-lower-uppercase-filename.luatexdev.fc
rem   - ./build/test/letterspace1.luatex.fc
rem   - ./build/test/letterspace1.luatexdev.fc
rem   - ./build/test/letterspace2.luatexdev.fc
rem   - ./build/test/luacolor.luatexdev.fc
rem   - ./build/test/luatex-ja.luatexdev.fc
rem   - ./build/test/luatexko-1.luatexdev.fc
rem   - ./build/test/mac-only-font-family.luatexdev.fc
rem   - ./build/test/math-stix2.luatexdev.fc
rem   - ./build/test/missingchars.luatexdev.fc
rem   - ./build/test/my-resolver.luatexdev.fc
rem   - ./build/test/pua-coelacanth.luatexdev.fc
rem   - ./build/test/pua-fontawesome.luatexdev.fc
rem   - ./build/test/pua-libertine.luatex.fc
rem   - ./build/test/pua-libertine.luatexdev.fc
rem   - ./build/test/setxheight.luatex.fc
rem   - ./build/test/setxheight.luatexdev.fc
rem
rem Failed tests for configuration config-harf:
rem
rem   Check failed with difference files
rem   - ./build/test-config-harf/arabic-gr.luatexdev.fc
rem   - ./build/test-config-harf/arabic.luatex.fc
rem   - ./build/test-config-harf/arabic.luatexdev.fc
rem   - ./build/test-config-harf/color.luatex.fc
rem   - ./build/test-config-harf/color.luatexdev.fc
rem   - ./build/test-config-harf/discretionaries.luatex.fc
rem   - ./build/test-config-harf/discretionaries.luatexdev.fc
rem   - ./build/test-config-harf/fallback.luatexdev.fc
rem   - ./build/test-config-harf/math.luatexdev.fc
rem   - ./build/test-config-harf/multiscript-auto.luatexdev.fc
rem   - ./build/test-config-harf/scripts.luatex.fc
rem   - ./build/test-config-harf/scripts.luatexdev.fc
rem   - ./build/test-config-harf/story.luatex.fc
rem   - ./build/test-config-harf/story.luatexdev.fc
rem
rem Failed tests for configuration config-loader-unpackaged:
rem
rem   Check failed with difference files
rem   - ./build/test-config-loader-unpackaged/add-uppercase-feature.luatex.fc
rem   - ./build/test-config-loader-unpackaged/add-uppercase-feature.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/arab1.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/arab2.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/arab3.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/automatichyphenmode.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/color.luatex.fc
rem   - ./build/test-config-loader-unpackaged/color.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/embolden-math.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/embolden-text.luatex.fc
rem   - ./build/test-config-loader-unpackaged/embolden-text.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/invisible-chars.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/issue11.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/issue47-mac-only-font-family.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/issue53-whatsits.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/iwona-PR42.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/latex-font-input-syntax.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/latex-font-lower-uppercase-filename.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/letterspace1.luatex.fc
rem   - ./build/test-config-loader-unpackaged/letterspace1.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/letterspace2.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/luacolor.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/luatex-ja.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/luatexko-1.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/mac-only-font-family.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/math-stix2.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/missingchars.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/my-resolver.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/pua-coelacanth.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/pua-fontawesome.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/pua-libertine.luatex.fc
rem   - ./build/test-config-loader-unpackaged/pua-libertine.luatexdev.fc
rem   - ./build/test-config-loader-unpackaged/setxheight.luatex.fc
rem   - ./build/test-config-loader-unpackaged/setxheight.luatexdev.fc
rem
rem Failed tests for configuration config-loader-reference:
rem
rem   Check failed with difference files
rem   - ./build/test-config-loader-reference/add-uppercase-feature.luatex.fc
rem   - ./build/test-config-loader-reference/add-uppercase-feature.luatexdev.fc
rem   - ./build/test-config-loader-reference/arab1.luatexdev.fc
rem   - ./build/test-config-loader-reference/arab2.luatexdev.fc
rem   - ./build/test-config-loader-reference/arab3.luatexdev.fc
rem   - ./build/test-config-loader-reference/automatichyphenmode.luatexdev.fc
rem   - ./build/test-config-loader-reference/color.luatex.fc
rem   - ./build/test-config-loader-reference/color.luatexdev.fc
rem   - ./build/test-config-loader-reference/embolden-math.luatexdev.fc
rem   - ./build/test-config-loader-reference/embolden-text.luatex.fc
rem   - ./build/test-config-loader-reference/embolden-text.luatexdev.fc
rem   - ./build/test-config-loader-reference/invisible-chars.luatexdev.fc
rem   - ./build/test-config-loader-reference/issue11.luatexdev.fc
rem   - ./build/test-config-loader-reference/issue47-mac-only-font-family.luatexdev.fc
rem   - ./build/test-config-loader-reference/issue53-whatsits.luatexdev.fc
rem   - ./build/test-config-loader-reference/iwona-PR42.luatexdev.fc
rem   - ./build/test-config-loader-reference/latex-font-input-syntax.luatexdev.fc
rem   - ./build/test-config-loader-reference/latex-font-lower-uppercase-filename.luatexdev.fc
rem   - ./build/test-config-loader-reference/letterspace1.luatex.fc
rem   - ./build/test-config-loader-reference/letterspace1.luatexdev.fc
rem   - ./build/test-config-loader-reference/letterspace2.luatexdev.fc
rem   - ./build/test-config-loader-reference/luacolor.luatexdev.fc
rem   - ./build/test-config-loader-reference/luatex-ja.luatexdev.fc
rem   - ./build/test-config-loader-reference/luatexko-1.luatexdev.fc
rem   - ./build/test-config-loader-reference/mac-only-font-family.luatexdev.fc
rem   - ./build/test-config-loader-reference/math-stix2.luatexdev.fc
rem   - ./build/test-config-loader-reference/missingchars.luatexdev.fc
rem   - ./build/test-config-loader-reference/my-resolver.luatexdev.fc
rem   - ./build/test-config-loader-reference/pua-coelacanth.luatexdev.fc
rem   - ./build/test-config-loader-reference/pua-fontawesome.luatexdev.fc
rem   - ./build/test-config-loader-reference/pua-libertine.luatex.fc
rem   - ./build/test-config-loader-reference/pua-libertine.luatexdev.fc
rem   - ./build/test-config-loader-reference/setxheight.luatex.fc
rem   - ./build/test-config-loader-reference/setxheight.luatexdev.fc
rem
rem Failed tests for configuration config-latex-TU:
rem
rem   Check failed with difference files
rem   - ./build/test-config-latex-TU/tu-tl2e7.luatexdev.fc
rem
rem Failed tests for configuration config-fontspec:
rem
rem   Check failed with difference files
rem   - ./build/test-config-fontspec/00-test.luatexdev.fc
 l3build save -cconfig-fontspec  aff-group
l3build save -cconfig-fontspec  aff-numbers
l3build save -cconfig-fontspec  colour-basic
l3build save -cconfig-fontspec  colour-opacity
l3build save -cconfig-fontspec  em-declare
l3build save -cconfig-fontspec  feat-scale-match
l3build save -cconfig-fontspec  fontload-defaults-adding
l3build save -cconfig-fontspec  fontload-defaults
l3build save -cconfig-fontspec  fontload-fontface-1
l3build save -cconfig-fontspec  fontload-fontface-2-sc
l3build save -cconfig-fontspec  fontload-fontface-3-sizing
l3build save -cconfig-fontspec  fontload-fontspec-file
l3build save -cconfig-fontspec  fontload-nfssfamily-1
l3build save -cconfig-fontspec  fontload-nfssfamily-2
l3build save -cconfig-fontspec  fontload-scfeat-nesting
l3build save -cconfig-fontspec  fontload-sizefeatures-1
l3build save -cconfig-fontspec  fontload-sizefeatures-2-nesting
l3build save -cconfig-fontspec  user-alias-feature
