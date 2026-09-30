package app.sefer.sefer

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sefer/app_icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    val name = call.argument<String>("name")
                    if (name == null || name !in ICONS) {
                        result.error("unknown_icon", "No icon called $name", null)
                    } else {
                        setIcon(name)
                        result.success(null)
                    }
                }
                "get" -> result.success(currentIcon())
                else -> result.notImplemented()
            }
        }
    }

    private fun component(name: String) = ComponentName(this, "$packageName.${ICONS.getValue(name)}")

    /// Enables the alias for [name] and disables the others. The launcher may
    /// take a few seconds to show the new icon.
    private fun setIcon(name: String) {
        for (other in ICONS.keys) {
            packageManager.setComponentEnabledSetting(
                component(other),
                if (other == name) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    private fun currentIcon(): String {
        for (name in ICONS.keys) {
            val state = packageManager.getComponentEnabledSetting(component(name))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return name
        }
        return "aleph"
    }

    companion object {
        private val ICONS = mapOf("aleph" to "IconAleph", "bet" to "IconBet")
    }
}
