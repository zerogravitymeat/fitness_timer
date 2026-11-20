package io.github.zerogravitymeat.fitnesstimer

import android.app.LocaleManager
import android.content.Intent
import android.os.Build
import android.os.LocaleList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 기기 TTS 설정 화면 열기 (docs/02 6.4절: 한국어 음성이 없을 때 안내)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitness_timer/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openTtsSettings" -> {
                        try {
                            startActivity(
                                Intent("com.android.settings.TTS_SETTINGS")
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    // Android 13+ 앱별 언어. 그 미만이면 null (지원 안 함)
                    "getAppLocale" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val locales = getSystemService(LocaleManager::class.java).applicationLocales
                            result.success(if (locales.isEmpty) "" else locales[0].toLanguageTag())
                        } else {
                            result.success(null)
                        }
                    }
                    // 빈 문자열이면 기기 언어를 따른다
                    "setAppLocale" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val tag = call.arguments as? String ?: ""
                            getSystemService(LocaleManager::class.java).applicationLocales =
                                if (tag.isEmpty()) LocaleList.getEmptyLocaleList()
                                else LocaleList.forLanguageTags(tag)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
