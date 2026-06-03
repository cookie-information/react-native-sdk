package com.cookieinformation.reactnative

import com.cookieinformation.mobileconsents.core.domain.entities.ConsentItem
import com.cookieinformation.mobileconsents.core.domain.entities.ConsentType
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.collections.shouldBeEmpty
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe

class ConsentMappingTest : DescribeSpec({
    val necessaryId = "a10853b5-85b8-4541-a9ab-fd203176bdce"
    val marketingId = "ef7d8f35-fc1a-4369-ada2-c00cc0eecc4b4"

    val necessaryItem = consentItem(
        id = 1L,
        universalId = necessaryId,
        title = "Necessary cookies",
        description = "Necessary description",
        required = true,
        type = ConsentType.NECESSARY,
        accepted = true,
    )
    val marketingItem = consentItem(
        id = 2L,
        universalId = marketingId,
        title = "Marketing cookies",
        description = "Marketing long text",
        required = false,
        type = ConsentType.MARKETING,
        accepted = false,
    )

    describe("ConsentMapping") {
        describe("parseConsentItemOptions") {
            it("maps id and accepted to ConsentItemOption") {
                val raw = JavaOnlyArray().apply {
                    pushMap(
                        JavaOnlyMap().apply {
                            putDouble("id", 1.0)
                            putBoolean("accepted", true)
                        }
                    )
                    pushMap(
                        JavaOnlyMap().apply {
                            putDouble("id", 2.0)
                            putBoolean("accepted", false)
                        }
                    )
                }

                val options = ConsentMapping.parseConsentItemOptions(raw)

                options shouldHaveSize 2
                options[0].consentItemId shouldBe 1L
                options[0].accepted shouldBe true
                options[1].consentItemId shouldBe 2L
                options[1].accepted shouldBe false
            }

            it("skips entries missing id or accepted") {
                val raw = JavaOnlyArray().apply {
                    pushMap(
                        JavaOnlyMap().apply {
                            putDouble("id", 1.0)
                        }
                    )
                    pushMap(
                        JavaOnlyMap().apply {
                            putBoolean("accepted", true)
                        }
                    )
                    pushMap(
                        JavaOnlyMap().apply {
                            putDouble("id", 3.0)
                            putBoolean("accepted", true)
                        }
                    )
                }

                val options = ConsentMapping.parseConsentItemOptions(raw)

                options shouldHaveSize 1
                options[0].consentItemId shouldBe 3L
            }

            it("returns empty list for empty input") {
                ConsentMapping.parseConsentItemOptions(JavaOnlyArray()).shouldBeEmpty()
            }
        }

        describe("buildAcceptAllOptions") {
            it("accepts all consent items") {
                val options = ConsentMapping.buildAcceptAllOptions(listOf(necessaryItem, marketingItem))

                options shouldHaveSize 2
                options.all { it.accepted } shouldBe true
                options[0].consentItemId shouldBe 1L
                options[1].consentItemId shouldBe 2L
            }
        }
    }
}    )

private fun consentItem(
    id: Long,
    universalId: String,
    title: String,
    description: String,
    required: Boolean,
    type: ConsentType,
    accepted: Boolean,
): ConsentItem =
    ConsentItem(
        id = id,
        universalId = universalId,
        title = title,
        description = description,
        required = required,
        type = type,
        accepted = accepted,
    )
