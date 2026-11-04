package com.klaviyo.klaviyo_flutter_sdk

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.klaviyo.core.Registry
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import kotlin.concurrent.Volatile

/**
 * Runs the Dart background silent push handler in a headless [FlutterEngine] when the process has
 * no engine of its own, e.g. after FCM starts a killed app to deliver a push.
 *
 * The engine starts on the first [dispatch] and stays alive for the life of the process. Pushes
 * that arrive before the Dart dispatcher reports `backgroundDispatcherInitialized` are queued and
 * sent once it does. All state is touched on the main thread only.
 *
 * Follows the approach of firebase_messaging's `FlutterFirebaseMessagingBackgroundExecutor`
 * (BSD-3-Clause, Copyright 2020 The Chromium Authors).
 */
internal object BackgroundSilentPushExecutor {
    private const val CHANNEL_NAME = "klaviyo_sdk_background"
    private const val METHOD_INITIALIZED = "backgroundDispatcherInitialized"
    private const val METHOD_HANDLE = "handleBackgroundSilentPush"

    private class PendingPush(
        val data: Map<String, Any?>,
        val onComplete: () -> Unit,
    )

    private val mainHandler = Handler(Looper.getMainLooper())

    private var engine: FlutterEngine? = null
    private var isStarting = false
    private var channel: MethodChannel? = null
    private var isDispatcherReady = false
    private val pending = ArrayDeque<PendingPush>()

    /**
     * True only while this object constructs its [FlutterEngine]. Plugins auto-registered during
     * construction read it to tell the headless engine apart from the app's own.
     */
    @Volatile
    internal var isCreatingEngine = false
        private set

    /**
     * Sends [data] to the Dart background handler, starting the headless engine if needed.
     * [onComplete] runs on the main thread when the handler finishes, fails, or can't run.
     */
    fun dispatch(
        context: Context,
        data: Map<String, Any?>,
        onComplete: () -> Unit,
    ) {
        val appContext = context.applicationContext
        mainHandler.post {
            val push = PendingPush(data, onComplete)
            if (isDispatcherReady) {
                invoke(appContext, push)
                return@post
            }
            pending.addLast(push)
            if (engine == null && !isStarting) {
                startEngine(appContext)
            }
        }
    }

    private fun startEngine(context: Context) {
        val dispatcherHandle = BackgroundSilentPushStore.dispatcherHandle(context)
        if (dispatcherHandle == 0L) {
            Registry.log.warning("No background silent push dispatcher registered")
            failPending()
            return
        }

        isStarting = true
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(context)
        loader.ensureInitializationCompleteAsync(context, null, mainHandler) {
            isStarting = false
            Registry.log.info("Starting headless FlutterEngine for background silent push")
            val newEngine =
                try {
                    isCreatingEngine = true
                    FlutterEngine(context)
                } finally {
                    isCreatingEngine = false
                }

            val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(dispatcherHandle)
            if (callbackInfo == null) {
                Registry.log.error("Background silent push dispatcher not found for stored handle")
                newEngine.destroy()
                failPending()
                return@ensureInitializationCompleteAsync
            }

            engine = newEngine
            channel =
                MethodChannel(newEngine.dartExecutor.binaryMessenger, CHANNEL_NAME).also {
                    it.setMethodCallHandler { call, result -> onDispatcherCall(context, call, result) }
                }
            newEngine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(context.assets, loader.findAppBundlePath(), callbackInfo),
            )
        }
    }

    private fun onDispatcherCall(
        context: Context,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (call.method != METHOD_INITIALIZED) {
            result.notImplemented()
            return
        }
        isDispatcherReady = true
        result.success(null)
        while (pending.isNotEmpty()) {
            invoke(context, pending.removeFirst())
        }
    }

    private fun invoke(
        context: Context,
        push: PendingPush,
    ) {
        val activeChannel = channel
        if (activeChannel == null) {
            push.onComplete()
            return
        }
        val arguments =
            buildMap<String, Any?> {
                put("data", push.data)
                put("handlerHandle", BackgroundSilentPushStore.handlerHandle(context))
                BackgroundSilentPushStore.apiKey(context)?.let { put("apiKey", it) }
            }
        activeChannel.invokeMethod(METHOD_HANDLE, arguments, CompletionResult(push.onComplete))
    }

    private fun failPending() {
        while (pending.isNotEmpty()) {
            pending.removeFirst().onComplete()
        }
    }
}

/** A [MethodChannel.Result] that logs failures and runs [onComplete] for every outcome. */
internal class CompletionResult(
    private val onComplete: () -> Unit,
) : MethodChannel.Result {
    override fun success(result: Any?) = onComplete()

    override fun error(
        errorCode: String,
        errorMessage: String?,
        errorDetails: Any?,
    ) {
        Registry.log.warning("Background silent push handler failed: $errorCode $errorMessage")
        onComplete()
    }

    override fun notImplemented() {
        Registry.log.warning("Background silent push handler is not listening")
        onComplete()
    }
}
