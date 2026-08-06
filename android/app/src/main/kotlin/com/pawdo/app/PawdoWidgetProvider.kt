package com.pawdo.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class PawdoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    companion object {
        private const val preferencesName = "pawdo_widget_preferences"

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
                setTextViewText(R.id.pawdo_widget_title, title)
                setTextViewText(R.id.pawdo_widget_body, body)
                setTextViewText(R.id.pawdo_widget_activity, activity)
                setViewVisibility(
                    R.id.pawdo_widget_activity,
                    if (activity.isBlank()) android.view.View.GONE else android.view.View.VISIBLE,
                )
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    7001,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                setOnClickPendingIntent(R.id.pawdo_widget_root, pendingIntent)
            }
            manager.updateAppWidget(widgetId, views)
        }
    }
}
