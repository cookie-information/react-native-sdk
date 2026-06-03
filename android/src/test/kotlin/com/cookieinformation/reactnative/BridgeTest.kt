package com.cookieinformation.reactnative

import androidx.activity.ComponentActivity
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.WritableMap
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

class BridgeTest : DescribeSpec({
    describe("CookieInformationRNSDKModule bridge") {
        lateinit var reactContext: ReactApplicationContext
        lateinit var module: CookieInformationRNSDKModule

        beforeEach {
            reactContext = mock(ReactApplicationContext::class.java)
            module = CookieInformationRNSDKModule(reactContext)
        }

        describe("initialize") {
            // Success path needs real ConsentsUISDK/ConsentSDK + coroutines; iOS resolves
            // synchronously after validation (ios/Tests/BridgeTests.swift). Android covers
            // error paths only here by design.
            it("rejects initialize when activity is unavailable") {
                `when`(reactContext.currentActivity).thenReturn(null)
                val promise = TestPromise()
                module.initialize(validInitOptions(), promise)

                promise.rejected shouldBe true
                promise.rejectCode shouldBe "ACTIVITY_UNAVAILABLE"
                promise.rejectMessage shouldBe "Activity unavailable"
            }

            it("rejects initialize when required fields are missing") {
                attachActivity(reactContext)
                val promise = TestPromise()
                module.initialize(JavaOnlyMap(), promise)

                promise.rejected shouldBe true
                promise.rejectCode shouldBe "INVALID_INIT"
                promise.rejectMessage shouldBe "clientId, clientSecret, and solutionId are required"
            }
        }

        it("rejects getSavedConsents when SDK is not initialized") {
            attachActivity(reactContext)
            val promise = TestPromise()
            module.getSavedConsents(null, promise)

            promise.rejected shouldBe true
            promise.rejectCode shouldBe "INIT_ERROR"
            promise.rejectMessage shouldBe "SDK not ready"
        }

        it("rejects cacheConsentSolution when SDK is not initialized") {
            attachActivity(reactContext)
            val promise = TestPromise()
            module.cacheConsentSolution(promise)

            promise.rejected shouldBe true
            promise.rejectCode shouldBe "INIT_ERROR"
        }

        it("rejects removeStoredConsents when SDK is not initialized") {
            attachActivity(reactContext)
            val promise = TestPromise()
            module.removeStoredConsents(null, promise)

            promise.rejected shouldBe true
            promise.rejectCode shouldBe "INIT_ERROR"
        }

        it("rejects synchronizeIfNeeded when SDK is not initialized") {
            attachActivity(reactContext)
            val promise = TestPromise()
            module.synchronizeIfNeeded(promise)

            promise.rejected shouldBe true
            promise.rejectCode shouldBe "INIT_ERROR"
        }

        it("rejects saveConsents when SDK is not initialized") {
            attachActivity(reactContext)
            val promise = TestPromise()
            module.saveConsents(
                JavaOnlyArray().apply {
                    pushMap(
                        JavaOnlyMap().apply {
                            putDouble("id", 1.0)
                            putBoolean("accepted", true)
                        }
                    )
                },
                null,
                null,
                promise
            )

            promise.rejected shouldBe true
            promise.rejectCode shouldBe "INIT_ERROR"
        }
    }
})

private fun attachActivity(reactContext: ReactApplicationContext) {
    val activity = mock(ComponentActivity::class.java)
    `when`(reactContext.currentActivity).thenReturn(activity)
}

private fun validInitOptions(): JavaOnlyMap =
    JavaOnlyMap().apply {
        putString("clientId", "test-client")
        putString("clientSecret", "test-secret")
        putString("solutionId", "test-solution")
    }

private class TestPromise : Promise {
    var resolved: Any? = null
    var rejected = false
    var rejectCode: String? = null
    var rejectMessage: String? = null

    override fun resolve(value: Any?) {
        resolved = value
    }

    override fun reject(code: String?, message: String?) {
        rejected = true
        rejectCode = code
        rejectMessage = message
    }

    override fun reject(code: String?, throwable: Throwable?) {
        rejected = true
        rejectCode = code
        rejectMessage = throwable?.message
    }

    override fun reject(code: String?, message: String?, throwable: Throwable?) {
        rejected = true
        rejectCode = code
        rejectMessage = message
    }

    override fun reject(throwable: Throwable) {
        rejected = true
        rejectMessage = throwable.message
    }

    override fun reject(throwable: Throwable, userInfo: WritableMap) {
        rejected = true
        rejectMessage = throwable.message
    }

    override fun reject(code: String?, userInfo: WritableMap) {
        rejected = true
        rejectCode = code
    }

    override fun reject(code: String?, message: String?, userInfo: WritableMap) {
        rejected = true
        rejectCode = code
        rejectMessage = message
    }

    override fun reject(code: String?, throwable: Throwable?, userInfo: WritableMap) {
        rejected = true
        rejectCode = code
        rejectMessage = throwable?.message
    }

    override fun reject(
        code: String?,
        message: String?,
        throwable: Throwable?,
        userInfo: WritableMap?,
    ) {
        rejected = true
        rejectCode = code
        rejectMessage = message
    }

    override fun reject(message: String) {
        rejected = true
        rejectMessage = message
    }
}
