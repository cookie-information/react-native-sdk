package com.cookieinformation.reactnative

import android.util.Log
import androidx.activity.ComponentActivity
import com.cookieinformation.mobileconsents.sdk.ui.ConsentsUISDK
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Typography
import com.cookieinformation.mobileconsents.core.ConsentSDK

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.Arguments
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class CookieInformationRNSDKModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    private val tag: String = "CookieInformationSDK"
    private var initError: String? = "Not initialized (call initialize)"
    private var sdkReady: Boolean = false

    private var cookieInformationSDK: ConsentSDK? = null
    private var sdkConfig: SDKConfig? = null

    private data class SDKConfig(
        val clientID: String,
        val clientSecret: String,
        val solutionID: String,
        val languageCode: String?,
        val lightColorScheme: ColorScheme?,
        val darkColorScheme: ColorScheme?,
        val typography: Typography?
    )

    override fun getName(): String = "CookieInformationRNSDK"

    init {
        resetSdkState()
    }

    private fun resetSdkState() {
        sdkReady = false
        initError = "Not initialized (call initialize)"
    }

    private fun withSDK(promise: Promise, action: suspend (ComponentActivity) -> Unit) {
        val activity = reactApplicationContext.currentActivity as? ComponentActivity
        if (activity == null) {
            Log.w(tag, "No active Activity")
            promise.reject("ACTIVITY_UNAVAILABLE", "Activity unavailable")
            return
        }

        if (!sdkReady || initError != null) {
            Log.w(tag, "SDK not initialized: $initError")
            promise.reject("INIT_ERROR", "SDK not ready")
            return
        }

        CoroutineScope(Dispatchers.Main).launch {
            action(activity)
        }
    }

    private suspend fun initializeConsentsCoreSDK(activity: ComponentActivity, config: SDKConfig) {
        withContext(Dispatchers.IO) {
            val localeLanguage = config.languageCode ?: try {
                ConsentsUISDK.languageCode
            } catch (e: Exception) {
                activity.resources.configuration.locales.get(0).language.uppercase()
            }

            val sdk = ConsentSDK(
                context = activity,
                clientID = config.clientID,
                clientSecret = config.clientSecret,
                solutionId = config.solutionID,
                language = localeLanguage
            )

            sdk.init().getOrThrow()
            sdk.getLatestSavedUserConsents().onSuccess { consent ->
                Log.i(tag, "Latest saved consents: $consent")
            }
            cookieInformationSDK = sdk
            Log.i(tag, "Core SDK initialized")
        }
    }

    private fun initializeConsentsUISDK(activity: ComponentActivity, config: SDKConfig) {
        val localeLanguage = config.languageCode ?: try {
            ConsentsUISDK.languageCode
        } catch (e: Exception) {
            activity.resources.configuration.locales.get(0).language.uppercase()
        }

        ConsentsUISDK.init(
            clientID = config.clientID,
            clientSecret = config.clientSecret,
            solutionId = config.solutionID,
            languageCode = localeLanguage,
            customLightColorScheme = config.lightColorScheme,
            customDarkColorScheme = config.darkColorScheme,
            typography = config.typography,
            context = activity
        )

        Log.i(tag, "UI SDK initialized")
    }

    @ReactMethod
    fun initialize(options: ReadableMap, promise: Promise) {
        resetSdkState()

        val activity = reactApplicationContext.currentActivity as? ComponentActivity
        if (activity == null) {
            promise.reject("ACTIVITY_UNAVAILABLE", "Activity unavailable")
            return
        }
        val clientId = if (options.hasKey("clientId")) options.getString("clientId") else null
        val clientSecret = if (options.hasKey("clientSecret")) options.getString("clientSecret") else null
        val solutionId = if (options.hasKey("solutionId")) options.getString("solutionId") else null
        if (clientId.isNullOrEmpty() || clientSecret.isNullOrEmpty() || solutionId.isNullOrEmpty()) {
            promise.reject("INVALID_INIT", "clientId, clientSecret, and solutionId are required")
            return
        }
        val languageCode = if (options.hasKey("languageCode")) options.getString("languageCode")?.trim()?.uppercase() else null

        var lightColorScheme: ColorScheme? = null
        var darkColorScheme: ColorScheme? = null
        var typography: Typography? = null

        if (options.hasKey("ui")) {
            val ui = options.getMap("ui")
            if (ui != null && ui.hasKey("android")) {
                val androidUi = ui.getMap("android")
                if (androidUi != null) {
                    lightColorScheme = UiParsing.buildColorSchemeFromReadableMap(
                        if (androidUi.hasKey("lightColorScheme")) androidUi.getMap("lightColorScheme") else null,
                        isDark = false
                    )
                    darkColorScheme = UiParsing.buildColorSchemeFromReadableMap(
                        if (androidUi.hasKey("darkColorScheme")) androidUi.getMap("darkColorScheme") else null,
                        isDark = true
                    )
                    typography = UiParsing.buildTypographyFromReadableMap(
                        if (androidUi.hasKey("typography")) androidUi.getMap("typography") else null,
                        activity
                    )
                }
            }
        }

        sdkConfig = SDKConfig(
            clientID = clientId,
            clientSecret = clientSecret,
            solutionID = solutionId,
            languageCode = languageCode,
            lightColorScheme = lightColorScheme,
            darkColorScheme = darkColorScheme,
            typography = typography
        )
        CoroutineScope(Dispatchers.Main).launch {
            val config = sdkConfig
            if (config == null) {
                initError = "Required configuration missing"
                promise.reject("INIT_ERROR", initError)
                return@launch
            }

            try {
                initializeConsentsUISDK(activity, config)
            } catch (e: Exception) {
                initError = e.message ?: "Unexpected error during UI SDK initialization"
                sdkReady = false
                Log.e(tag, "UI SDK init error", e)
                promise.reject("INIT_ERROR", initError)
                return@launch
            }

            try {
                initializeConsentsCoreSDK(activity, config)
            } catch (e: Exception) {
                initError = e.message ?: "Core SDK init failed"
                sdkReady = false
                Log.e(tag, "Core SDK init error", e)
                promise.reject("INIT_ERROR", initError)
                return@launch
            }

            sdkReady = true
            initError = null
            promise.resolve(null)
        }
    }

    @ReactMethod
    fun showPrivacyPopUp(promise: Promise) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                withSDK(promise) { activity ->
                    val result = ConsentsUISDK.showPrivacyPopup(activity).first()
                    result.fold(
                        onSuccess = { consentItems ->
                            promise.resolve(ConsentMapping.mapSelections(consentItems))
                        },
                        onFailure = { throwable ->
                            val errorMsg =
                                throwable.message ?: "Consent dialog could not be shown"
                            Log.w(tag, errorMsg, throwable)
                            promise.reject("UI_ERROR", errorMsg)
                        }
                    )
                }
            } catch (e: Exception) {
                val errorMsg = e.message ?: "Unexpected issue while opening consent dialog"
                Log.w(tag, errorMsg, e)
                promise.reject("UI_ERROR", errorMsg)
            }
        }
    }

    @ReactMethod
    fun showPrivacyPopUpIfNeeded(options: ReadableMap?, promise: Promise) {
        val userId = if (options != null && options.hasKey("userId")) options.getString("userId") else null
        CoroutineScope(Dispatchers.Main).launch {
            try {
                withSDK(promise) { activity ->
                    val result = ConsentsUISDK.showPrivacyPopupIfNeeded(activity, userId).first()
                    result.fold(
                        onSuccess = { consentItems ->
                            promise.resolve(ConsentMapping.mapSelections(consentItems))
                        },
                        onFailure = { throwable ->
                            val errorMsg =
                                throwable.message ?: "Consent dialog could not be shown"
                            Log.w(tag, errorMsg, throwable)
                            promise.reject("UI_ERROR", errorMsg)
                        }
                    )
                }
            } catch (e: Exception) {
                val errorMsg = e.message ?: "Unexpected issue while opening consent dialog"
                Log.w(tag, errorMsg, e)
                promise.reject("UI_ERROR", errorMsg)
            }
        }
    }

    @ReactMethod
    fun acceptAllConsents(userId: String?, promise: Promise) {
        withSDK(promise) {
            val sdk = cookieInformationSDK
            if (sdk == null) {
                promise.reject("INIT_ERROR", "SDK not ready")
                return@withSDK
            }

            CoroutineScope(Dispatchers.IO).launch {
                try {
                    sdk.init().getOrThrow()
                    sdk.cacheLatestConsentSolution().getOrThrow()

                    val items = sdk.getLatestSavedUserConsents(userId).getOrElse { emptyList() }
                    if (items.isEmpty()) {
                        withContext(Dispatchers.Main) {
                            promise.reject("FETCH_ERROR", "Unable to load consent configuration")
                        }
                        return@launch
                    }

                    val options = ConsentMapping.buildAcceptAllOptions(items)
                    try {
                        val savedConsents = sdk.saveConsents(userId, options).getOrThrow()

                        val consentsArray = ConsentMapping.buildConsentsWritableArray(savedConsents)

                        val resultMap = Arguments.createMap()
                        resultMap.putBoolean("success", true)
                        resultMap.putString("message", "All consents saved successfully")
                        resultMap.putArray("consents", consentsArray)
                        resultMap.putInt("count", savedConsents.size)

                        withContext(Dispatchers.Main) {
                            promise.resolve(resultMap)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            promise.reject(
                                "SAVE_ERROR",
                                e.message ?: "Unable to save consent selections"
                            )
                        }
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        promise.reject(
                            "FETCH_ERROR",
                            e.message ?: "Unable to load consent configuration"
                        )
                    }
                }
            }
        }
    }

    @ReactMethod
    fun removeStoredConsents(userId: String?, promise: Promise) {
        withSDK(promise) { activity ->
            ConsentsUISDK.deleteLocalConsentsData(activity, userId).fold(
                onSuccess = { promise.resolve(null) },
                onFailure = { e ->
                    val msg = e.message ?: "Failed to remove stored consents"
                    Log.w(tag, msg, e)
                    promise.reject("SAVE_ERROR", msg)
                }
            )
        }
    }

    @ReactMethod
    fun cacheConsentSolution(promise: Promise) {
        withSDK(promise) {
            val sdk = cookieInformationSDK
            if (sdk == null) {
                promise.reject("INIT_ERROR", "SDK not ready")
                return@withSDK
            }
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    sdk.cacheLatestConsentSolution().fold(
                        onSuccess = {
                            val items = sdk.getLatestSavedUserConsents(null).getOrElse { emptyList() }
                            val consentsArray = ConsentMapping.buildConsentsWritableArray(items)

                            withContext(Dispatchers.Main) {
                                promise.resolve(consentsArray)
                            }
                        },
                        onFailure = { e ->
                            val msg = e.message ?: "Failed to cache consent solution"
                            Log.w(tag, msg, e)
                            withContext(Dispatchers.Main) {
                                promise.reject("FETCH_ERROR", msg)
                            }
                        }
                    )
                } catch (e: Exception) {
                    val msg = e.message ?: "Failed to cache consent solution"
                    Log.w(tag, msg, e)
                    withContext(Dispatchers.Main) {
                        promise.reject("FETCH_ERROR", msg)
                    }
                }
            }
        }
    }

    @ReactMethod
    fun synchronizeIfNeeded(promise: Promise) {
        withSDK(promise) {
            val sdk = cookieInformationSDK
            if (sdk == null) {
                promise.reject("INIT_ERROR", "SDK not ready")
                return@withSDK
            }
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    sdk.resendAllFailedSaveConsentsRequests()
                    withContext(Dispatchers.Main) {
                        promise.resolve(null)
                    }
                } catch (e: Exception) {
                    val msg = e.message ?: "Failed to sync consents"
                    Log.w(tag, msg, e)
                    withContext(Dispatchers.Main) {
                        promise.reject("SAVE_CONSENTS_ERROR", msg)
                    }
                }
            }
        }
    }

    @ReactMethod
    fun getSavedConsents(userId: String?, promise: Promise) {
        withSDK(promise) {
            val sdk = cookieInformationSDK
            if (sdk == null) {
                promise.reject("INIT_ERROR", "SDK not ready")
                return@withSDK
            }
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val items = sdk.getLatestSavedUserConsents(userId).getOrElse { emptyList() }
                    val consentsArray = ConsentMapping.buildConsentsWritableArray(items)

                    withContext(Dispatchers.Main) {
                        promise.resolve(consentsArray)
                    }
                } catch (e: Exception) {
                    val msg = e.message ?: "Failed to read saved consents"
                    Log.w(tag, msg, e)
                    withContext(Dispatchers.Main) {
                        promise.reject("FETCH_ERROR", msg)
                    }
                }
            }
        }
    }

    @ReactMethod
    fun saveConsents(consentItemsRaw: ReadableArray, customData: ReadableMap?, userId: String?, promise: Promise) {
        withSDK(promise) {
            val sdk = cookieInformationSDK
            if (sdk == null) {
                promise.reject("INIT_ERROR", "SDK not ready")
                return@withSDK
            }
            val options = ConsentMapping.parseConsentItemOptions(consentItemsRaw)
            if (options.isEmpty()) {
                promise.reject(
                    "INVALID_ARGS",
                    "At least one valid consent item with universalId is required"
                )
                return@withSDK
            }
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val cachedItems = sdk.getLatestSavedUserConsents(userId).getOrElse { emptyList() }
                    if (cachedItems.isEmpty()) {
                        withContext(Dispatchers.Main) {
                            promise.reject("CACHE_ERROR", "Call cacheConsentSolution first")
                        }
                        return@launch
                    }

                    val savedConsents = sdk.saveConsents(userId, options).getOrThrow()
                    val consentsArray = ConsentMapping.buildConsentsWritableArray(savedConsents)

                    val resultMap = Arguments.createMap()
                    resultMap.putBoolean("success", true)
                    resultMap.putInt("savedCount", savedConsents.size)
                    resultMap.putArray("consents", consentsArray)
                    withContext(Dispatchers.Main) {
                        promise.resolve(resultMap)
                    }
                } catch (e: Exception) {
                    val msg = e.message ?: "Failed to save consents"
                    Log.w(tag, msg, e)
                    withContext(Dispatchers.Main) {
                        promise.reject("SAVE_CONSENTS_ERROR", msg)
                    }
                }
            }
        }
    }
}
