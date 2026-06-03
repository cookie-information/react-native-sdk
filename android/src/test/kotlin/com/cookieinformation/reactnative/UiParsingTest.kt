package com.cookieinformation.reactnative

import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe

class UiParsingTest : DescribeSpec({
    describe("UiParsing") {
        describe("parseColorCode") {
            it("returns null for null input") {
                UiParsing.parseColorCode(null).shouldBeNull()
            }

            it("returns null for unsupported types") {
                UiParsing.parseColorCode(true).shouldBeNull()
                UiParsing.parseColorCode(emptyList<Any>()).shouldBeNull()
            }

            it("parses numeric values") {
                UiParsing.parseColorCode(0xFFFF8040) shouldBe 0xFFFF8040.toInt()
            }
        }

        describe("parseHexColorString") {
            it("returns null for invalid hex") {
                UiParsing.parseHexColorString("#GGGGGG").shouldBeNull()
            }

            it("returns null for unsupported lengths") {
                UiParsing.parseHexColorString("#FFF").shouldBeNull()
                UiParsing.parseHexColorString("#FFFFFFFFFF").shouldBeNull()
            }

            it("parses six-digit hex with a hash prefix") {
                val argb = UiParsing.parseHexColorString("#FF8040").shouldNotBeNull()
                assertArgb(argb, alpha = 255, red = 255, green = 128, blue = 64)
            }

            it("parses six-digit hex without a hash prefix") {
                val argb = UiParsing.parseHexColorString("FF8040").shouldNotBeNull()
                assertArgb(argb, alpha = 255, red = 255, green = 128, blue = 64)
            }

            it("trims surrounding whitespace") {
                val argb = UiParsing.parseHexColorString("  #00FF00  ").shouldNotBeNull()
                assertArgb(argb, alpha = 255, red = 0, green = 255, blue = 0)
            }

            it("parses eight-digit hex") {
                val argb = UiParsing.parseHexColorString("#800000FF").shouldNotBeNull()
                assertArgb(argb, alpha = 128, red = 0, green = 0, blue = 255)
            }
        }

        describe("buildColorScheme") {
            it("returns null for a null map") {
                UiParsing.buildColorScheme(null, isDark = false).shouldBeNull()
            }

            it("returns null when no recognized colors are present") {
                UiParsing.buildColorScheme(emptyMap<String, Any>(), isDark = false).shouldBeNull()
                UiParsing.buildColorScheme(mapOf("primary" to "not-a-color"), isDark = false).shouldBeNull()
            }

            it("builds a light color scheme when primary is valid") {
                UiParsing.buildColorScheme(mapOf("primary" to "#FF8040"), isDark = false).shouldNotBeNull()
            }

            it("builds a dark color scheme when primary is valid") {
                UiParsing.buildColorScheme(mapOf("primary" to "#FF8040"), isDark = true).shouldNotBeNull()
            }

            it("builds a partial light color scheme when only secondary is set") {
                UiParsing.buildColorScheme(mapOf("secondary" to "#00FF00"), isDark = false).shouldNotBeNull()
            }
        }
    }
})

private fun assertArgb(
    argb: Int,
    alpha: Int,
    red: Int,
    green: Int,
    blue: Int,
) {
    val unsigned = argb.toUInt()
    ((unsigned shr 24) and 0xFFu).toInt() shouldBe alpha
    ((unsigned shr 16) and 0xFFu).toInt() shouldBe red
    ((unsigned shr 8) and 0xFFu).toInt() shouldBe green
    (unsigned and 0xFFu).toInt() shouldBe blue
}
