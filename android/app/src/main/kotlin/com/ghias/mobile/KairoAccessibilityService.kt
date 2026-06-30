package com.ghias.mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class KairoAccessibilityService : AccessibilityService() {

    interface AccessibilityEventListener {
        fun onEventLogged(type: String, text: String, packageName: String)
    }

    companion object {
        var instance: KairoAccessibilityService? = null
            private set
        var eventListener: AccessibilityEventListener? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d("KairoAccessService", "Accessibility Service Connected")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        Log.d("KairoAccessService", "Accessibility Service Unbound")
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val type = when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_CLICKED -> "click"
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> "text_change"
            else -> null
        }
        if (type != null) {
            val textList = event.text
            if (textList != null && textList.isNotEmpty()) {
                val text = textList[0].toString()
                val pkg = event.packageName?.toString() ?: ""
                eventListener?.onEventLogged(type, text, pkg)
            }
        }
    }

    override fun onInterrupt() {
        Log.d("KairoAccessService", "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    // Launch an application by package name
    fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e("KairoAccessService", "Failed to launch app: $packageName", e)
            false
        }
    }

    // Perform tap at coordinate (x, y)
    fun performClick(x: Float, y: Float): Boolean {
        val path = Path()
        path.moveTo(x, y)
        val gestureBuilder = GestureDescription.Builder()
        val stroke = GestureDescription.StrokeDescription(path, 0, 50)
        gestureBuilder.addStroke(stroke)
        
        var completed = false
        dispatchGesture(gestureBuilder.build(), object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                super.onCompleted(gestureDescription)
                completed = true
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                super.onCancelled(gestureDescription)
                completed = false
            }
        }, null)
        
        return true
    }

    // Perform swipe from (startX, startY) to (endX, endY)
    fun performSwipe(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long): Boolean {
        val path = Path()
        path.moveTo(startX, startY)
        path.lineTo(endX, endY)
        val gestureBuilder = GestureDescription.Builder()
        val stroke = GestureDescription.StrokeDescription(path, 0, durationMs)
        gestureBuilder.addStroke(stroke)
        dispatchGesture(gestureBuilder.build(), null, null)
        return true
    }

    // Extract screen element tree as a JSON string
    fun getScreenHierarchy(): String {
        val rootNode = rootInActiveWindow ?: return "{}"
        val json = JSONObject()
        try {
            json.put("root", nodeToJson(rootNode))
        } catch (e: Exception) {
            Log.e("KairoAccessService", "Failed to dump node hierarchy", e)
        } finally {
            rootNode.recycle()
        }
        return json.toString()
    }

    private fun nodeToJson(node: AccessibilityNodeInfo): JSONObject {
        val obj = JSONObject()
        val rect = Rect()
        node.getBoundsInScreen(rect)

        obj.put("text", node.text?.toString() ?: "")
        obj.put("contentDescription", node.contentDescription?.toString() ?: "")
        obj.put("className", node.className?.toString() ?: "")
        obj.put("packageName", node.packageName?.toString() ?: "")
        obj.put("viewId", node.viewIdResourceName ?: "")
        obj.put("clickable", node.isClickable)
        obj.put("enabled", node.isEnabled)
        obj.put("focusable", node.isFocusable)
        obj.put("scrollable", node.isScrollable)
        obj.put("selected", node.isSelected)
        obj.put("bounds", JSONObject().apply {
            put("left", rect.left)
            put("top", rect.top)
            put("right", rect.right)
            put("bottom", rect.bottom)
            put("width", rect.width())
            put("height", rect.height())
        })

        if (node.childCount > 0) {
            val children = JSONArray()
            for (i in 0 until node.childCount) {
                val child = node.getChild(i)
                if (child != null) {
                    children.put(nodeToJson(child))
                    child.recycle()
                }
            }
            obj.put("children", children)
        }
        return obj
    }
}
