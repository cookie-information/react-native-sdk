package com.cookieinformation.reactnative

import com.cookieinformation.mobileconsents.core.domain.entities.ConsentItem
import com.cookieinformation.mobileconsents.core.domain.entities.ConsentItemOption
import com.cookieinformation.mobileconsents.sdk.ui.UIConsentItem
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.WritableArray
import com.facebook.react.bridge.WritableMap

object ConsentMapping {
    fun buildConsentWritableMap(consent: ConsentItem): WritableMap {
        val map = Arguments.createMap()
        map.putDouble("id", consent.id.toDouble())
        map.putString("universalId", consent.universalId)
        map.putString("title", consent.title)
        map.putString("description", consent.description)
        map.putBoolean("required", consent.required)
        map.putString("type", consent.type.type)
        map.putBoolean("accepted", consent.accepted)
        return map
    }

    fun buildConsentsWritableArray(items: List<ConsentItem>): WritableArray {
        val array = Arguments.createArray()
        items.forEach { array.pushMap(buildConsentWritableMap(it)) }
        return array
    }

    fun mapSelections(consents: List<UIConsentItem>): WritableMap {
        val map = Arguments.createMap()
        consents.forEach { map.putBoolean(it.type.type, it.accepted) }
        return map
    }

    fun parseConsentItemOptions(consentItemsRaw: ReadableArray): List<ConsentItemOption> {
        val options = mutableListOf<ConsentItemOption>()
        for (i in 0 until consentItemsRaw.size()) {
            val map = consentItemsRaw.getMap(i) ?: continue
            if (!map.hasKey("id") || !map.hasKey("accepted")) continue
            options.add(
                ConsentItemOption(
                    consentItemId = map.getDouble("id").toLong(),
                    accepted = map.getBoolean("accepted"),
                )
            )
        }
        return options
    }

    fun buildAcceptAllOptions(items: List<ConsentItem>): List<ConsentItemOption> {
        return items.map { ConsentItemOption(consentItemId = it.id, accepted = true) }
    }
}
