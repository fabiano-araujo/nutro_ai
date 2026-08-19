package br.com.snapdark.apps.nutreai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.time.LocalDate

class NutritionStreakWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    companion object {
        internal const val ACTION_OPEN_STREAK =
            "br.com.snapdark.apps.nutreai.action.OPEN_NUTRITION_STREAK"

        private const val preferencesName = "nutrition_streak_widget"
        private const val caloriesKey = "calories"
        private const val calorieGoalKey = "calorie_goal"
        private const val streakKey = "streak"
        private const val dateKey = "date"

        fun persistSnapshotAndUpdate(
            context: Context,
            calories: Int,
            calorieGoal: Int,
            streak: Int,
            date: String
        ) {
            context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
                .edit()
                .putInt(caloriesKey, calories)
                .putInt(calorieGoalKey, calorieGoal)
                .putInt(streakKey, streak)
                .putString(dateKey, date)
                .apply()

            updateAllWidgets(context)
        }

        fun isWidgetAdded(context: Context): Boolean {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            return appWidgetManager.getAppWidgetIds(providerComponent(context)).isNotEmpty()
        }

        private fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            appWidgetManager.getAppWidgetIds(providerComponent(context)).forEach { appWidgetId ->
                updateWidget(context, appWidgetManager, appWidgetId)
            }
        }

        private fun providerComponent(context: Context): ComponentName {
            return ComponentName(context, NutritionStreakWidgetProvider::class.java)
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val preferences =
                context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
            val snapshotDate = preferences.getString(dateKey, null)
            val isCurrentDay = snapshotDate == LocalDate.now().toString()
            val calories = if (isCurrentDay) {
                preferences.getInt(caloriesKey, 0).coerceAtLeast(0)
            } else {
                0
            }
            val calorieGoal = preferences.getInt(calorieGoalKey, 0).coerceAtLeast(0)
            val streak = preferences.getInt(streakKey, 0).coerceAtLeast(0)
            val progressMaximum = calorieGoal.coerceAtLeast(1)
            val calorieProgress = calories.coerceAtMost(progressMaximum)

            val openStreakIntent = Intent(context, MainActivity::class.java).apply {
                action = ACTION_OPEN_STREAK
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            val openStreakPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                openStreakIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val views = RemoteViews(context.packageName, R.layout.nutrition_streak_widget).apply {
                setTextViewText(
                    R.id.widget_streak_value,
                    context.resources.getQuantityString(
                        R.plurals.widget_streak_days,
                        streak,
                        streak
                    )
                )
                setTextViewText(R.id.widget_calories_value, calories.toString())
                setTextViewText(
                    R.id.widget_goal_value,
                    context.getString(
                        R.string.widget_goal_format,
                        calories,
                        calorieGoal
                    )
                )
                setProgressBar(
                    R.id.widget_calorie_progress,
                    progressMaximum,
                    calorieProgress,
                    false
                )
                setOnClickPendingIntent(R.id.widget_root, openStreakPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
