package prozoft.com.vaia

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity es requerido por local_auth para la biometria.
class MainActivity : FlutterFragmentActivity() {
    private val notificationChannelName = "vaia/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        val title = call.argument<String>("title") ?: "Vaia"
                        val body = call.argument<String>("body") ?: ""
                        val id = call.argument<Int>("id")
                            ?: (System.currentTimeMillis() and 0x7FFFFFFF).toInt()
                        mostrarNotificacion(title, body, id)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Muestra una notificacion local cuando la app esta en primer plano.
    private fun mostrarNotificacion(title: String, body: String, id: Int) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "vaia_push",
                    "Vaia",
                    NotificationManager.IMPORTANCE_HIGH
                )
                channel.description = "Servicios y mensajes"
                manager.createNotificationChannel(channel)
            }

            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pending = PendingIntent.getActivity(this, id, intent, flags)

            val notificacion = NotificationCompat.Builder(this, "vaia_push")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(pending)
                .build()

            manager.notify(id, notificacion)
        } catch (_: Exception) {
        }
    }
}
