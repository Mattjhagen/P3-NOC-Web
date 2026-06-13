package xyz.mattyhagen.p3noc

import android.os.Handler
import android.os.Looper
import android.util.Log
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.*
import java.util.concurrent.TimeUnit

class NocClient {
    private val client = OkHttpClient.Builder()
        .connectTimeout(5, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.MINUTES) // Long timeout for streaming
        .build()

    var hostUrl = "http://100.105.154.91:8080" // Default Tailscale Web IP/port
    var token: String? = null
    var isAuthenticated = false
    var isStreamingChat = false

    // State callback observers
    var onStatusUpdated: ((JSONObject) -> Unit)? = null
    var onConversationsUpdated: ((JSONArray) -> Unit)? = null
    var onMessagesUpdated: ((List<ChatMessage>) -> Unit)? = null
    var onConnectionError: ((String?) -> Unit)? = null

    // Cache local data
    var conversations = JSONArray()
    val messages = mutableListOf<ChatMessage>()
    var systemStatus: JSONObject? = null

    private var webSocket: WebSocket? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun login(username: String, password: String, callback: (Boolean, String?) -> Unit) {
        val formBody = FormBody.Builder()
            .add("username", username)
            .add("password", password)
            .build()

        val request = Request.Builder()
            .url("$hostUrl/api/auth/login")
            .post(formBody)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("NocClient", "Login failure", e)
                mainHandler.post { callback(false, e.localizedMessage) }
            }

            override fun onResponse(call: Call, response: Response) {
                val bodyStr = response.body?.string()
                if (response.isSuccessful && bodyStr != null) {
                    try {
                        val json = JSONObject(bodyStr)
                        token = json.getString("access_token")
                        isAuthenticated = true
                        mainHandler.post {
                            callback(true, null)
                            fetchConversations()
                            connectWebSocket()
                        }
                    } catch (e: Exception) {
                        mainHandler.post { callback(false, "Failed to parse token") }
                    }
                } else {
                    mainHandler.post { callback(false, "Login failed: ${response.code}") }
                }
            }
        })
    }

    fun connectWebSocket() {
        val cleanHost = hostUrl.replace("http://", "").replace("https://", "")
        val scheme = if (hostUrl.startsWith("https")) "wss" else "ws"
        val wsUrl = "$scheme://$cleanHost/ws/status"

        val request = Request.Builder()
            .url(wsUrl)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    val payload = JSONObject(text)
                    val event = payload.optString("event")
                    if (event == "status") {
                        val data = payload.optJSONObject("data")
                        if (data != null) {
                            systemStatus = data
                            mainHandler.post { onStatusUpdated?.invoke(data) }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("NocClient", "WebSocket parse error", e)
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e("NocClient", "WebSocket failure", t)
                mainHandler.post { onConnectionError?.invoke("WebSocket connection failed: ${t.localizedMessage}") }
                // Retry after 5s
                mainHandler.postDelayed({ connectWebSocket() }, 5000)
            }
        })
    }

    fun fetchConversations() {
        val request = Request.Builder()
            .url("$hostUrl/api/chat/conversations")
            .addHeader("Authorization", "Bearer $token")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("NocClient", "Fetch conversations failed", e)
            }

            override fun onResponse(call: Call, response: Response) {
                val bodyStr = response.body?.string()
                if (response.isSuccessful && bodyStr != null) {
                    try {
                        conversations = JSONArray(bodyStr)
                        mainHandler.post { onConversationsUpdated?.invoke(conversations) }
                    } catch (e: Exception) {
                        Log.e("NocClient", "Conversations parse error", e)
                    }
                }
            }
        })
    }

    fun fetchMessages(conversationId: Int) {
        val request = Request.Builder()
            .url("$hostUrl/api/chat/conversations/$conversationId/messages")
            .addHeader("Authorization", "Bearer $token")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("NocClient", "Fetch messages failed", e)
            }

            override fun onResponse(call: Call, response: Response) {
                val bodyStr = response.body?.string()
                if (response.isSuccessful && bodyStr != null) {
                    try {
                        val array = JSONArray(bodyStr)
                        messages.clear()
                        for (i in 0 until array.length()) {
                            val msgJson = array.getJSONObject(i)
                            messages.add(ChatMessage.fromJson(msgJson))
                        }
                        mainHandler.post { onMessagesUpdated?.invoke(messages) }
                    } catch (e: Exception) {
                        Log.e("NocClient", "Messages parse error", e)
                    }
                }
            }
        })
    }

    fun sendMessage(conversationId: Int, content: String, model: String = "qwen3:8b") {
        val payload = JSONObject().apply {
            put("content", content)
            put("model", model)
        }

        val requestBody = payload.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("$hostUrl/api/chat/conversations/$conversationId/messages")
            .addHeader("Authorization", "Bearer $token")
            .post(requestBody)
            .build()

        // Append User Message immediately
        messages.add(ChatMessage(role = "user", content = content))
        // Append Assistant Empty Message (placeholder)
        val assistantMessage = ChatMessage(role = "assistant", content = "")
        messages.add(assistantMessage)
        val assistantIndex = messages.size - 1
        mainHandler.post { onMessagesUpdated?.invoke(messages) }

        isStreamingChat = true

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                mainHandler.post {
                    messages[assistantIndex].content = "Connection failure: ${e.localizedMessage}"
                    isStreamingChat = false
                    onMessagesUpdated?.invoke(messages)
                }
            }

            override fun onResponse(call: Call, response: Response) {
                if (!response.isSuccessful) {
                    mainHandler.post {
                        messages[assistantIndex].content = "Server returned error: ${response.code}"
                        isStreamingChat = false
                        onMessagesUpdated?.invoke(messages)
                    }
                    return
                }

                val source = response.body?.source() ?: return
                var accumulatedText = ""
                var hasThinkingBlock = false

                try {
                    while (true) {
                        val line = source.readUtf8Line() ?: break
                        if (line.startsWith("data: ")) {
                            val dataStr = line.substring(6).trim()
                            if (dataStr.isEmpty()) continue
                            
                            val json = JSONObject(dataStr)
                            
                            // Check for custom sources or suggestions chunks
                            if (json.has("sources")) {
                                val sourcesArr = json.getJSONArray("sources")
                                val sourcesList = mutableListOf<ChatSource>()
                                for (i in 0 until sourcesArr.length()) {
                                    val srcJson = sourcesArr.getJSONObject(i)
                                    sourcesList.add(ChatSource(srcJson.getString("title"), srcJson.getString("url")))
                                }
                                messages[assistantIndex].sources = sourcesList
                            } else if (json.has("suggestions")) {
                                val sugsArr = json.getJSONArray("suggestions")
                                val sugsList = mutableListOf<String>()
                                for (i in 0 until sugsArr.length()) {
                                    sugsList.add(sugsArr.getString(i))
                                }
                                messages[assistantIndex].suggestions = sugsList
                            } else if (json.has("message")) {
                                val msgObj = json.getJSONObject("message")
                                val thinking = msgObj.optString("thinking")
                                val contentChunk = msgObj.optString("content")

                                if (thinking.isNotEmpty()) {
                                    if (!hasThinkingBlock) {
                                        accumulatedText += "[THINKING]"
                                        hasThinkingBlock = true
                                    }
                                    accumulatedText += thinking
                                }
                                if (contentChunk.isNotEmpty()) {
                                    if (hasThinkingBlock && !accumulatedText.contains("[/THINKING]")) {
                                        accumulatedText += "[/THINKING]\n\n"
                                    }
                                    accumulatedText += contentChunk
                                }
                                messages[assistantIndex].content = accumulatedText
                            }
                            
                            mainHandler.post { onMessagesUpdated?.invoke(messages) }
                        }
                    }
                } catch (e: Exception) {
                    Log.e("NocClient", "Stream read error", e)
                } finally {
                    isStreamingChat = false
                    mainHandler.post { onMessagesUpdated?.invoke(messages) }
                }
            }
        })
    }

    fun triggerRecoveryAction(actionName: String, callback: (Boolean) -> Unit) {
        val request = Request.Builder()
            .url("$hostUrl/api/recovery/$actionName")
            .addHeader("Authorization", "Bearer $token")
            .post("".toRequestBody())
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                mainHandler.post { callback(false) }
            }

            override fun onResponse(call: Call, response: Response) {
                mainHandler.post { callback(response.isSuccessful) }
            }
        })
    }

    fun toggleAutopilotLock(callback: (Boolean) -> Unit) {
        val request = Request.Builder()
            .url("$hostUrl/api/recovery/unlock-autopilot")
            .addHeader("Authorization", "Bearer $token")
            .post("".toRequestBody())
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                mainHandler.post { callback(false) }
            }

            override fun onResponse(call: Call, response: Response) {
                mainHandler.post { callback(response.isSuccessful) }
            }
        })
    }

    fun createConversation(title: String, callback: (Int?) -> Unit) {
        val payload = JSONObject().apply { put("title", title) }
        val requestBody = payload.toString().toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url("$hostUrl/api/chat/conversations")
            .addHeader("Authorization", "Bearer $token")
            .post(requestBody)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                mainHandler.post { callback(null) }
            }

            override fun onResponse(call: Call, response: Response) {
                val bodyStr = response.body?.string()
                if (response.isSuccessful && bodyStr != null) {
                    try {
                        val json = JSONObject(bodyStr)
                        val id = json.getInt("id")
                        mainHandler.post { callback(id) }
                    } catch (e: Exception) {
                        mainHandler.post { callback(null) }
                    }
                } else {
                    mainHandler.post { callback(null) }
                }
            }
        })
    }
}

data class ChatMessage(
    val role: String,
    var content: String,
    var sources: List<ChatSource>? = null,
    var suggestions: List<String>? = null
) {
    companion object {
        fun fromJson(json: JSONObject): ChatMessage {
            val role = json.getString("role")
            val content = json.getString("content")
            
            val sources = mutableListOf<ChatSource>()
            val sourcesArr = json.optJSONArray("sources")
            if (sourcesArr != null) {
                for (i in 0 until sourcesArr.length()) {
                    val srcObj = sourcesArr.getJSONObject(i)
                    sources.add(ChatSource(srcObj.getString("title"), srcObj.getString("url")))
                }
            }
            
            val suggestions = mutableListOf<String>()
            val sugsArr = json.optJSONArray("suggestions")
            if (sugsArr != null) {
                for (i in 0 until sugsArr.length()) {
                    suggestions.add(sugsArr.getString(i))
                }
            }
            
            return ChatMessage(
                role = role,
                content = content,
                sources = if (sources.isEmpty()) null else sources,
                suggestions = if (suggestions.isEmpty()) null else suggestions
            )
        }
    }
}

data class ChatSource(val title: String, val url: String)
