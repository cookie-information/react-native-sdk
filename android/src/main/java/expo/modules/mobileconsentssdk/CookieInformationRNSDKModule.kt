package expo.modules.mobileconsentssdk

import android.util.Log
import androidx.activity.ComponentActivity
import com.cookieinformation.mobileconsents.sdk.ui.ConsentsUISDK
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.Typography
import com.cookieinformation.mobileconsents.core.ConsentSDK
import com.cookieinformation.mobileconsents.core.domain.entities.ConsentItemOption

import expo.modules.kotlin.Promise
import expo.modules.kotlin.exception.CodedException
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class CookieInformationRNSDKModule : Module() {
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

    private class ActivityUnavailableException : CodedException("Activity unavailable")
    private class SDKInitException(message: String) : CodedException(message)
    private class ConsentException(message: String) : CodedException(message)

    private fun withSDK(promise: Promise, action: suspend (ComponentActivity) -> Unit) {
        val activity = appContext.activityProvider?.currentActivity as? ComponentActivity
        if (activity == null) {
            Log.w(tag, "No active Activity")
            promise.reject(ActivityUnavailableException())
            return
        }

        if (!sdkReady || initError != null) {
            Log.w(tag, "SDK not initialized: $initError")
            promise.reject(SDKInitException("CookieInformationSDK not initialized: $initError"))
            return
        }

        CoroutineScope(Dispatchers.Main).launch {
            action(activity)
        }
    }

    private suspend fun initializeConsentsCoreSDK(activity: ComponentActivity, config: SDKConfig) {

        try {
            val localeLanguage = config.languageCode ?: try {
                ConsentsUISDK.languageCode
            } catch (e: Exception) {
                activity.resources.configuration.locales.get(0).language.uppercase()
            }

            cookieInformationSDK = ConsentSDK(
                context = activity,
                clientID = config.clientID,
                clientSecret = config.clientSecret,
                solutionId = config.solutionID,
                language = localeLanguage
            )

            cookieInformationSDK?.init()?.onSuccess {
                cookieInformationSDK?.cacheLatestConsentSolution()
                cookieInformationSDK?.getLatestSavedUserConsents()?.onSuccess { consent ->
                    Log.i(tag, "Latest saved consents: $consent")
                }
                Log.i(tag, "Core SDK initialized")
            }?.onFailure { error ->
                Log.e(tag, "Core SDK init failure", error)
                initError = "Core SDK init failed: ${error.message}"
            }
        } catch (e: Exception) {
            Log.e(tag, "Core SDK setup error", e)
            initError = "Core SDK setup failed: ${e.message}"
        }
    }

    private fun initializeConsentsUISDK(activity: ComponentActivity, config: SDKConfig) {
        try {
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

            sdkReady = true
            initError = null
            Log.i(tag, "UI SDK initialized")
        } catch (e: Exception) {
            initError = e.message ?: "Unexpected error during SDK initialization"
            sdkReady = false
            Log.e(tag, "UI SDK init error", e)
        }
    }

    override fun definition() = ModuleDefinition {
        Name("CookieInformationRNSDK")

        OnCreate {
            sdkReady = false
            initError = "Not initialized (call initialize)"
        }

        AsyncFunction("initialize") { options: Map<String, Any?>, promise: Promise ->
            val activity = appContext.activityProvider?.currentActivity as? ComponentActivity
            if (activity == null) {
                promise.reject(ActivityUnavailableException())
                return@AsyncFunction
            }
            val clientId = options["clientId"] as? String
            val clientSecret = options["clientSecret"] as? String
            val solutionId = options["solutionId"] as? String
            if (clientId.isNullOrEmpty() || clientSecret.isNullOrEmpty() || solutionId.isNullOrEmpty()) {
                promise.reject(SDKInitException("clientId, clientSecret, and solutionId are required"))
                return@AsyncFunction
            }
            val languageCode = (options["languageCode"] as? String)?.trim()?.uppercase()
            val ui = options["ui"] as? Map<*, *>
            val androidUi = ui?.get("android") as? Map<*, *>
            val lightColorScheme = UiParsing.buildColorScheme(androidUi?.get("lightColorScheme") as? Map<*, *>, isDark = false)
            val darkColorScheme = UiParsing.buildColorScheme(androidUi?.get("darkColorScheme") as? Map<*, *>, isDark = true)
            val typography = UiParsing.buildTypography(androidUi?.get("typography") as? Map<*, *>, activity)
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
                    promise.reject(SDKInitException("Required configuration missing"))
                    return@launch
                }
                initializeConsentsUISDK(activity, config)
                initializeConsentsCoreSDK(activity, config)
                sdkReady = true
                initError = null
                promise.resolve(null)
            }
        }

        AsyncFunction("showPrivacyPopUp") { promise: Promise ->
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    withSDK(promise) { activity ->
                        ConsentsUISDK.showPrivacyPopup(activity).collect { result ->
                            result.fold(
                                onSuccess = { consentItems ->
                                    val consentMap = mutableMapOf<String, Boolean>()
                                    consentItems.forEach { userConsent ->
                                        consentMap[userConsent.title] = userConsent.accepted
                                    }
                                    promise.resolve(consentMap)
                                },
                                onFailure = { throwable ->
                                    val errorMsg =
                                        throwable.message ?: "Consent dialog could not be shown"
                                    Log.w(tag, errorMsg, throwable)
                                    promise.reject(ConsentException(errorMsg))
                                }
                            )
                        }
                    }
                } catch (e: Exception) {
                    val errorMsg = e.message ?: "Unexpected issue while opening consent dialog"
                    Log.w(tag, errorMsg, e)
                    promise.reject(ConsentException(errorMsg))
                }
            }
        }

        AsyncFunction("showPrivacyPopUpIfNeeded") { options: Map<String, Any?>?, promise: Promise ->
            val userId = options?.get("userId") as? String
            CoroutineScope(Dispatchers.Main).launch {
                try {
                    withSDK(promise) { activity ->
                        ConsentsUISDK.showPrivacyPopupIfNeeded(activity, userId).collect { result ->
                            result.fold(
                                onSuccess = { consentItems ->
                                    val consentMap = mutableMapOf<String, Boolean>()
                                    consentItems.forEach { userConsent ->
                                        consentMap[userConsent.title] = userConsent.accepted
                                    }
                                    promise.resolve(consentMap)
                                },
                                onFailure = { throwable ->
                                    val errorMsg =
                                        throwable.message ?: "Consent dialog could not be shown"
                                    Log.w(tag, errorMsg, throwable)
                                    promise.reject(ConsentException(errorMsg))
                                }
                            )
                        }
                    }
                } catch (e: Exception) {
                    val errorMsg = e.message ?: "Unexpected issue while opening consent dialog"
                    Log.w(tag, errorMsg, e)
                    promise.reject(ConsentException(errorMsg))
                }
            }
        }

        AsyncFunction("acceptAllConsents") { userId: String?, promise: Promise ->
            withSDK(promise) {
                val sdk = cookieInformationSDK
                if (sdk == null) {
                    promise.reject(SDKInitException("CookieInformationSDK not initialized"))
                    return@withSDK
                }

                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        sdk.deleteUserData(userId).getOrThrow()
                        sdk.init().getOrThrow()
                        sdk.cacheLatestConsentSolution().getOrThrow()

                        val items = sdk.getLatestSavedUserConsents(userId).getOrElse { emptyList() }
                        if (items.isEmpty()) {
                            throw IllegalStateException("No consent items found. Make sure to cache the consent solution first.")
                        }

                        val options = items.map { consentItem ->
                            ConsentItemOption(
                                consentItemId = consentItem.id,
                                accepted = true
                            )
                        }
                        val savedConsents = sdk.saveConsents(userId, options).getOrThrow()

                        val consentsList = savedConsents.map { consent ->
                            mapOf(
                                "id" to consent.id,
                                "universalId" to consent.universalId,
                                "title" to consent.title,
                                "description" to consent.description,
                                "required" to consent.required,
                                "type" to consent.type.type,
                                "accepted" to consent.accepted
                            )
                        }

                        withContext(Dispatchers.Main) {
                            promise.resolve(
                                mapOf(
                                    "success" to true,
                                    "message" to "All consents saved successfully",
                                    "consents" to consentsList,
                                    "count" to savedConsents.size
                                )
                            )
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            promise.reject(
                                ConsentException(
                                    e.message ?: "Unable to save consent selections"
                                )
                            )
                        }
                    }
                }
            }
        }

        AsyncFunction("removeStoredConsents") { userId: String?, promise: Promise ->
            withSDK(promise) { activity ->
                ConsentsUISDK.deleteLocalConsentsData(activity, userId).fold(
                    onSuccess = { promise.resolve(null) },
                    onFailure = { e ->
                        val msg = e.message ?: "Failed to remove stored consents"
                        Log.w(tag, msg, e)
                        promise.reject(ConsentException(msg))
                    }
                )
            }
        }

        AsyncFunction("cacheConsentSolution") { promise: Promise ->
            withSDK(promise) {
                val sdk = cookieInformationSDK
                if (sdk == null) {
                    promise.reject(SDKInitException("CookieInformationSDK not initialized"))
                    return@withSDK
                }
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        sdk.cacheLatestConsentSolution().fold(
                            onSuccess = {
                                val items = sdk.getLatestSavedUserConsents(null).getOrElse { emptyList() }
                                val consentsList = items.map { consent ->
                                    mapOf(
                                        "id" to consent.id,
                                        "universalId" to consent.universalId,
                                        "title" to consent.title,
                                        "description" to consent.description,
                                        "required" to consent.required,
                                        "type" to consent.type.type,
                                        "accepted" to consent.accepted
                                    )
                                }
                                withContext(Dispatchers.Main) {
                                    promise.resolve(mapOf("consentItems" to consentsList))
                                }
                            },
                            onFailure = { e ->
                                val msg = e.message ?: "Failed to cache consent solution"
                                Log.w(tag, msg, e)
                                withContext(Dispatchers.Main) {
                                    promise.reject(ConsentException(msg))
                                }
                            }
                        )
                    } catch (e: Exception) {
                        val msg = e.message ?: "Failed to cache consent solution"
                        Log.w(tag, msg, e)
                        withContext(Dispatchers.Main) {
                            promise.reject(ConsentException(msg))
                        }
                    }
                }
            }
        }

        AsyncFunction("synchronizeIfNeeded") { promise: Promise ->
            withSDK(promise) {
                val sdk = cookieInformationSDK
                if (sdk == null) {
                    promise.reject(SDKInitException("CookieInformationSDK not initialized"))
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
                            promise.reject(ConsentException(msg))
                        }
                    }
                }
            }
        }

        AsyncFunction("getSavedConsents") { userId: String?, promise: Promise ->
            withSDK(promise) {
                val sdk = cookieInformationSDK
                if (sdk == null) {
                    promise.reject(SDKInitException("CookieInformationSDK not initialized"))
                    return@withSDK
                }
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val items = sdk.getLatestSavedUserConsents(userId).getOrElse { emptyList() }
                        val consentsList = items.map { consent ->
                            mapOf(
                                "id" to consent.id,
                                "universalId" to consent.universalId,
                                "title" to consent.title,
                                "description" to consent.description,
                                "required" to consent.required,
                                "type" to consent.type.type,
                                "accepted" to consent.accepted
                            )
                        }
                        withContext(Dispatchers.Main) {
                            promise.resolve(
                                mapOf("consentItems" to consentsList)
                            )
                        }
                    } catch (e: Exception) {
                        val msg = e.message ?: "Failed to read saved consents"
                        Log.w(tag, msg, e)
                        withContext(Dispatchers.Main) {
                            promise.reject(ConsentException(msg))
                        }
                    }
                }
            }
        }

        AsyncFunction("saveConsents") { consentItemsRaw: List<Map<String, Any?>>, customData: Map<String, Any?>?, userId: String?, _: String?, promise: Promise ->
            withSDK(promise) {
                val sdk = cookieInformationSDK
                if (sdk == null) {
                    promise.reject(SDKInitException("CookieInformationSDK not initialized"))
                    return@withSDK
                }
                val options = consentItemsRaw.mapNotNull { map ->
                    val id = (map["id"] as? Number)?.toLong() ?: return@mapNotNull null
                    val accepted = map["accepted"] as? Boolean ?: return@mapNotNull null
                    ConsentItemOption(consentItemId = id, accepted = accepted)
                }
                if (options.isEmpty()) {
                    promise.reject(ConsentException("At least one consent item is required"))
                    return@withSDK
                }
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        sdk.saveConsents(userId, options).getOrThrow()
                        withContext(Dispatchers.Main) {
                            promise.resolve(
                                mapOf(
                                    "success" to true,
                                    "savedCount" to options.size
                                )
                            )
                        }
                    } catch (e: Exception) {
                        val msg = e.message ?: "Failed to save consents"
                        Log.w(tag, msg, e)
                        withContext(Dispatchers.Main) {
                            promise.reject(ConsentException(msg))
                        }
                    }
                }
            }
        }
    }

}
