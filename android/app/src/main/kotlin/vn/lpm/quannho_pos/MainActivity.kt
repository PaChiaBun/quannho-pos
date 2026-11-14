package vn.lpm.quannho_pos

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Mở trình cài của Android cho tệp APK cập nhật vừa tải (app_update_manager.dart).
        // Phải cấp quyền đọc tệp cho trình cài, nên không mở bằng url_launcher được.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.lpm.quannho_pos/cap_nhat")
            .setMethodCallHandler { call, result ->
                if (call.method != "caiApk") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val uri = FileProvider.getUriForFile(
                        this, "$packageName.fileprovider", File(call.argument<String>("path")!!)
                    )
                    startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            // Trình cài chạy ngăn riêng: chung ngăn với app thì cài xong (app bị tắt) bấm "Mở" không lên app (Sunmi 14/11).
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            }
    }
}
