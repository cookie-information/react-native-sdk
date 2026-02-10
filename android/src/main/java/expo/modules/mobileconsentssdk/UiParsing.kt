package expo.modules.mobileconsentssdk

import androidx.activity.ComponentActivity
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp

object UiParsing {
    fun parseColorCode(value: Any?): Int? {
        return when (value) {
            is Number -> value.toInt()
            is String -> parseHexColorString(value)
            else -> null
        }
    }

    fun parseHexColorString(value: String): Int? {
        val hex = value.trim().removePrefix("#")
        val normalized = when (hex.length) {
            6 -> "FF$hex"
            8 -> hex
            else -> return null
        }
        return try {
            normalized.toLong(16).toInt()
        } catch (_: Exception) {
            null
        }
    }

    fun buildColorScheme(map: Map<*, *>?, isDark: Boolean): ColorScheme? {
        if (map == null) return null
        val primary = parseColorCode(map["primary"])?.let { Color(it) }
        val secondary = parseColorCode(map["secondary"])?.let { Color(it) }
        val tertiary = parseColorCode(map["tertiary"])?.let { Color(it) }
        if (primary == null && secondary == null && tertiary == null) {
            return null
        }
        return if (isDark) {
            val defaults = darkColorScheme()
            darkColorScheme(
                primary = primary ?: defaults.primary,
                secondary = secondary ?: defaults.secondary,
                tertiary = tertiary ?: defaults.tertiary
            )
        } else {
            val defaults = lightColorScheme()
            lightColorScheme(
                primary = primary ?: defaults.primary,
                secondary = secondary ?: defaults.secondary,
                tertiary = tertiary ?: defaults.tertiary
            )
        }
    }

    fun buildTypography(map: Map<*, *>?, activity: ComponentActivity): Typography? {
        if (map == null) return null
        val bodyMedium = parseTextStyle(map["bodyMedium"] as? Map<*, *>, activity)
        if (bodyMedium == null) return null
        return Typography().copy(bodyMedium = bodyMedium)
    }

    private fun parseTextStyle(map: Map<*, *>?, activity: ComponentActivity): TextStyle? {
        if (map == null) return null
        val size = (map["size"] as? Number)?.toInt()
        val fontName = map["font"] as? String
        val fontFamily = fontName?.let {
            val resId = activity.resources.getIdentifier(it, "font", activity.packageName)
            if (resId == 0) null else FontFamily(Font(resId))
        }
        return when {
            fontFamily != null && size != null -> TextStyle(fontFamily = fontFamily, fontSize = size.sp)
            fontFamily != null -> TextStyle(fontFamily = fontFamily)
            size != null -> TextStyle(fontSize = size.sp)
            else -> null
        }
    }
}
