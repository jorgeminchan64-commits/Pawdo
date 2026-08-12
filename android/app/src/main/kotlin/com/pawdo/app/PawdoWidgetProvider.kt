package com.pawdo.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews

class PawdoWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == actionMissYou) {
            context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                .edit().putBoolean("pendingMissYou", true).apply()
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            context.startActivity(launch)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {
        private const val preferencesName = "pawdo_widget_preferences"
        private const val actionMissYou = "com.pawdo.app.WIDGET_MISS_YOU"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, PawdoWidgetProvider::class.java)
            manager.getAppWidgetIds(component).forEach { updateWidget(context, manager, it) }
        }

        private fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
        ) {
            val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val enabled = preferences.getBoolean("enabled", true)
            val showContent = preferences.getBoolean("showContent", false)
            val title = when {
                !enabled -> "Widget de Pawdo pausado"
                !showContent -> "Pawdo tiene novedades"
                else -> preferences.getString("title", "Abre Pawdo para actualizar")
                    ?: "Abre Pawdo para actualizar"
            }
            val body = when {
                !enabled -> "Actívalo desde Perfil > Widget de Android"
                !showContent -> "Contenido oculto por privacidad"
                else -> preferences.getString("body", "Último estado no disponible")
                    ?: "Último estado no disponible"
            }
            val activity = if (enabled && showContent) {
                preferences.getString("activity", "") ?: ""
            } else {
                ""
            }
            val views = RemoteViews(context.packageName, R.layout.pawdo_widget).apply {
                val minWidth = manager.getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
                setTextViewText(R.id.pawdo_widget_title, title)
                setTextViewText(R.id.pawdo_widget_body, body)
                setTextViewText(R.id.pawdo_widget_activity, activity)
                setViewVisibility(
                    R.id.pawdo_widget_activity,
                    if (activity.isBlank() || minWidth < 250) View.GONE else View.VISIBLE,
                )
                setViewVisibility(
                    R.id.pawdo_widget_body,
                    if (minWidth < 180) View.GONE else View.VISIBLE,
                )
                val photoPath = preferences.getString("photoPath", null)
                val bitmap = photoPath?.let { path ->
                    runCatching { BitmapFactory.decodeFile(path) }.getOrNull()
                }
                if (enabled && showContent && bitmap != null) {
                    setImageViewBitmap(R.id.pawdo_widget_photo, bitmap)
                } else {
                    setImageViewResource(R.id.pawdo_widget_photo, R.mipmap.ic_launcher)
                }
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    7001,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.pawdo_widget_root, pendingIntent)
                val missIntent = Intent(context, PawdoWidgetProvider::class.java).apply {
                    action = actionMissYou
                }
                val missPendingIntent = PendingIntent.getBroadcast(
                    context,
                    7002,
                    missIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.pawdo_widget_miss_you, missPendingIntent)
                setViewVisibility(
                    R.id.pawdo_widget_miss_you,
                    if (enabled && showContent && minWidth >= 250) View.VISIBLE else View.GONE,
                )
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}
