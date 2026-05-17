package com.mora.mora.camera

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec

/**
 * Entry point that wires the Mora camera plugin into a FlutterEngine.
 *
 * Two surfaces:
 *
 *   1. A platform-view factory ("mora_camera_view") so the Flutter side can
 *      mount a CameraX preview through AndroidView.
 *   2. A method channel ("mora/camera") for control calls: takePicture,
 *      setFlashMode, switchCamera, etc.
 *
 * The factory keeps a registry of live MoraCameraView instances keyed by
 * the platform-view id so method-channel calls can route to the right one
 * (it's plausible we'd ever show more than one camera in this app, but the
 * registry costs nothing and makes the lifecycle clearer).
 */
class MoraCameraPlugin {
    private val views: MutableMap<Int, MoraCameraView> = mutableMapOf()
    private lateinit var methodChannel: MethodChannel

    fun register(engine: FlutterEngine) {
        val factory = MoraCameraViewFactory(views)
        engine.platformViewsController
            .registry
            .registerViewFactory("mora_camera_view", factory)

        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, "mora/camera")
        methodChannel.setMethodCallHandler { call, result ->
            // Every method takes a viewId in its arguments — we use it to
            // dispatch to the right MoraCameraView. Falling back with
            // NOT_READY when the view hasn't been created yet keeps Dart from
            // having to race the platform-view lifecycle.
            val args = (call.arguments as? Map<*, *>) ?: emptyMap<Any, Any>()
            val viewId = (args["viewId"] as? Number)?.toInt()
            val view = viewId?.let { views[it] }
            if (view == null) {
                result.error("NOT_READY", "No camera view for id $viewId", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "takePicture" -> view.takePicture(result)
                "setFlashMode" -> {
                    val mode = (args["mode"] as? String) ?: "off"
                    view.setFlashMode(mode, result)
                }
                "switchCamera" -> view.switchCamera(result)
                "setZoom" -> {
                    val ratio = (args["ratio"] as? Number)?.toFloat() ?: 1f
                    view.setZoom(ratio, result)
                }
                "getZoomState" -> view.getZoomState(result)
                "dispose" -> {
                    view.disposeController()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

/** Stores newly-created views in the shared map so the method channel can
 *  find them by id. We deliberately don't unregister on dispose — the view
 *  itself is responsible for cleaning up CameraX bindings. */
private class MoraCameraViewFactory(
    private val views: MutableMap<Int, MoraCameraView>,
) : io.flutter.plugin.platform.PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: android.content.Context, viewId: Int, args: Any?): MoraCameraView {
        val map = (args as? Map<*, *>) ?: emptyMap<Any, Any>()
        val view = MoraCameraView(
            context = context,
            initialLens = (map["lens"] as? String) ?: "back",
        )
        views[viewId] = view
        return view
    }
}
