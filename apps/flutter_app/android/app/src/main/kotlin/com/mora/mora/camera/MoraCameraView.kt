package com.mora.mora.camera

import android.content.Context
import android.view.View
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.File
import java.util.concurrent.Executors

/**
 * PlatformView hosting a CameraX [PreviewView]. Owns the CameraX bindings
 * and exposes capture/flash/switch through the plugin's method channel.
 *
 * Lifecycle:
 *
 *   - Constructed from the factory when Flutter mounts the AndroidView.
 *   - Binds use-cases on first attach; rebinds when [switchCamera] flips lens.
 *   - Disposed when the Flutter widget unmounts, releasing the CameraX
 *     binding (the ProcessCameraProvider lives at process scope so leaving
 *     it is fine — we just unbind our use cases).
 */
class MoraCameraView(
    private val context: Context,
    initialLens: String,
) : PlatformView {

    private val previewView = PreviewView(context).apply {
        // FILL_CENTER keeps the visible viewfinder undistorted (no crop).
        // COMPATIBLE forces a TextureView under the hood instead of the
        // default SurfaceView. SurfaceView punches through Flutter widgets
        // layered above it (shutter button, flash pill, frames counter all
        // disappear), which is a well-known Flutter PlatformView z-order
        // issue on Android. TextureView composes correctly with the Flutter
        // overlay tree; the marginal GPU cost is invisible on any modern
        // phone.
        scaleType = PreviewView.ScaleType.FILL_CENTER
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }

    private val executor = Executors.newSingleThreadExecutor()
    private var imageCapture: ImageCapture? = null
    /// Cached reference to the bound CameraX camera, used for zoom + future
    /// runtime camera-control work (focus point, exposure offset, etc.).
    private var camera: Camera? = null
    private var minZoom: Float = 1f
    private var maxZoom: Float = 1f
    private var currentZoom: Float = 1f
    private var currentLens: Int =
        if (initialLens == "front") CameraSelector.LENS_FACING_FRONT
        else CameraSelector.LENS_FACING_BACK
    private var flashMode: Int = ImageCapture.FLASH_MODE_OFF

    init {
        bindUseCases()
    }

    // ─── PlatformView surface ──────────────────────────────────────────────

    override fun getView(): View = previewView

    override fun dispose() {
        disposeController()
    }

    fun disposeController() {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            try {
                providerFuture.get().unbindAll()
            } catch (_: Throwable) {
                // App is tearing down — nothing useful to do here.
            }
        }, ContextCompat.getMainExecutor(context))
        executor.shutdown()
    }

    // ─── Method-channel surface ────────────────────────────────────────────

    fun setFlashMode(mode: String, result: MethodChannel.Result) {
        flashMode = when (mode) {
            "auto" -> ImageCapture.FLASH_MODE_AUTO
            "on" -> ImageCapture.FLASH_MODE_ON
            else -> ImageCapture.FLASH_MODE_OFF
        }
        imageCapture?.flashMode = flashMode
        result.success(null)
    }

    fun switchCamera(result: MethodChannel.Result) {
        currentLens =
            if (currentLens == CameraSelector.LENS_FACING_BACK) CameraSelector.LENS_FACING_FRONT
            else CameraSelector.LENS_FACING_BACK
        bindUseCases()
        result.success(currentLens == CameraSelector.LENS_FACING_FRONT)
    }

    fun takePicture(result: MethodChannel.Result) {
        val capture = imageCapture
        if (capture == null) {
            result.error("NOT_BOUND", "Camera not ready", null)
            return
        }

        // Write to a unique temp file the Flutter side can read once we hand
        // back the path. The file lives in app cache so the OS reaps it.
        val outFile = File.createTempFile("mora_capture_", ".jpg", context.cacheDir)
        val options = ImageCapture.OutputFileOptions.Builder(outFile).apply {
            if (currentLens == CameraSelector.LENS_FACING_FRONT) {
                // Without this, selfies come back mirrored — text reads
                // backwards, which is the classic "skewed front camera" feel
                // people complain about with plain Flutter camera plugins.
                setMetadata(ImageCapture.Metadata().apply { isReversedHorizontal = false })
            }
        }.build()

        capture.takePicture(
            options,
            executor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(saved: ImageCapture.OutputFileResults) {
                    ContextCompat.getMainExecutor(context).execute {
                        result.success(outFile.absolutePath)
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    ContextCompat.getMainExecutor(context).execute {
                        result.error(
                            "CAPTURE_FAILED",
                            exception.localizedMessage ?: exception.javaClass.simpleName,
                            null,
                        )
                    }
                }
            },
        )
    }

    // ─── Internals ────────────────────────────────────────────────────────

    private fun bindUseCases() {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val lifecycleOwner = context.findLifecycleOwner()
                ?: run {
                    // Without a host lifecycle (eg the activity hasn't fully
                    // attached yet) we can't bind — bail rather than crash.
                    return@addListener
                }

            val preview = Preview.Builder().build().also { p ->
                p.setSurfaceProvider(previewView.surfaceProvider)
            }
            val capture = ImageCapture.Builder()
                .setFlashMode(flashMode)
                // Optimize for image quality over latency on the still-image
                // path. Shutter is still ~150ms on a Pixel, but the JPEGs are
                // notably cleaner.
                .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                .build()

            val selector = CameraSelector.Builder().requireLensFacing(currentLens).build()

            try {
                provider.unbindAll()
                camera = provider.bindToLifecycle(lifecycleOwner, selector, preview, capture)
                imageCapture = capture
                // Snapshot zoom limits for this lens — they differ per camera
                // (back is usually 1–10×, front is 1–1× on most phones).
                camera?.cameraInfo?.zoomState?.value?.let { z ->
                    minZoom = z.minZoomRatio
                    maxZoom = z.maxZoomRatio
                    currentZoom = z.zoomRatio
                }
            } catch (e: Throwable) {
                camera = null
                imageCapture = null
            }
        }, ContextCompat.getMainExecutor(context))
    }

    // ─── Zoom ──────────────────────────────────────────────────────────────

    fun setZoom(ratio: Float, result: MethodChannel.Result) {
        val cam = camera
        if (cam == null) {
            result.error("NOT_BOUND", "Camera not ready", null)
            return
        }
        val clamped = ratio.coerceIn(minZoom, maxZoom)
        cam.cameraControl.setZoomRatio(clamped)
        currentZoom = clamped
        result.success(zoomStateMap())
    }

    fun getZoomState(result: MethodChannel.Result) {
        result.success(zoomStateMap())
    }

    private fun zoomStateMap(): Map<String, Float> = mapOf(
        "zoom" to currentZoom,
        "min" to minZoom,
        "max" to maxZoom,
    )
}

/** Walk the Context wrapper chain until we find a LifecycleOwner.
 *  PlatformView contexts are wrapped Activities — this is the cleanest way
 *  to get back to the FlutterActivity for CameraX's binding. */
private fun Context.findLifecycleOwner(): LifecycleOwner? {
    var ctx: Context? = this
    while (ctx != null) {
        if (ctx is LifecycleOwner) return ctx
        if (ctx is android.content.ContextWrapper) {
            ctx = ctx.baseContext
        } else {
            break
        }
    }
    return null
}
