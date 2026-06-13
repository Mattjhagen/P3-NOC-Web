package xyz.mattyhagen.p3noc

import android.os.Bundle
import android.widget.Toast
import androidx.activity.compose.setContent
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executor

class MainActivity : FragmentActivity() {
    private val client = NocClient()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            var currentTheme by remember { mutableStateOf(MatrixGreenColors) }
            
            NocTheme(themeColors = currentTheme) {
                var screenState by remember { mutableStateOf<Screen>(Screen.Login) }
                var biometricRequired by remember { mutableStateOf(true) }

                if (biometricRequired) {
                    BiometricLockScreen(
                        onUnlocked = {
                            biometricRequired = false
                            if (client.isAuthenticated) {
                                screenState = Screen.Main
                            }
                        }
                    )
                } else {
                    when (screenState) {
                        is Screen.Login -> LoginScreen(
                            client = client,
                            onLoginSuccess = { screenState = Screen.Main }
                        )
                        is Screen.Main -> MainDashboardContainer(
                            client = client,
                            currentTheme = currentTheme,
                            onThemeChanged = { currentTheme = it },
                            onLogout = {
                                client.token = null
                                client.isAuthenticated = false
                                screenState = Screen.Login
                            }
                        )
                    }
                }
            }
        }
    }

    private fun showBiometricPrompt(onSuccess: () -> Unit) {
        val executor: Executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    onSuccess()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Toast.makeText(applicationContext, "Authentication error: $errString", Toast.LENGTH_SHORT).show()
                }
            })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("P3 NOC Authentication")
            .setSubtitle("Authenticate to access operational telemetry console")
            .setNegativeButtonText("Cancel")
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    @Composable
    fun BiometricLockScreen(onUnlocked: () -> Unit) {
        val context = LocalContext.current
        val colors = LocalNocColors.current

        LaunchedEffect(Unit) {
            val biometricManager = BiometricManager.from(context)
            if (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) == BiometricManager.BIOMETRIC_SUCCESS) {
                showBiometricPrompt(onUnlocked)
            } else {
                // If biometrics not available, bypass
                onUnlocked()
            }
        }

        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    imageVector = Icons.Filled.Lock,
                    contentDescription = "Locked",
                    tint = colors.primary,
                    modifier = Modifier.size(64.dp)
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "CONSOLE LOCKED",
                    color = colors.primary,
                    style = NocTypography.titleLarge
                )
                Spacer(modifier = Modifier.height(24.dp))
                Button(
                    onClick = { showBiometricPrompt(onUnlocked) },
                    colors = ButtonDefaults.buttonColors(containerColor = colors.accent)
                ) {
                    Text("UNLOCK SYSTEM", color = colors.background, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}

sealed class Screen {
    object Login : Screen()
    object Main : Screen()
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(client: NocClient, onLoginSuccess: () -> Unit) {
    var hostUrl by remember { mutableStateOf(client.hostUrl) }
    var username by remember { mutableStateOf("matty") }
    var password by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    val colors = LocalNocColors.current

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .width(340.dp)
                .border(BorderStroke(1.dp, colors.accent), RoundedCornerShape(8.dp))
                .background(colors.surface)
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("P3 OPERATIONS NOC", color = colors.primary, style = NocTypography.titleLarge)
            Spacer(modifier = Modifier.height(8.dp))
            Text("SECURE GATEWAY TERMINAL", color = colors.accent, style = NocTypography.labelSmall)
            Spacer(modifier = Modifier.height(24.dp))

            OutlinedTextField(
                value = hostUrl,
                onValueChange = { hostUrl = it },
                label = { Text("Server URL", color = colors.accent, fontFamily = FontFamily.Monospace) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = colors.primary,
                    unfocusedTextColor = colors.accent,
                    focusedBorderColor = colors.primary,
                    unfocusedBorderColor = colors.accent
                ),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = username,
                onValueChange = { username = it },
                label = { Text("Username", color = colors.accent, fontFamily = FontFamily.Monospace) },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = colors.primary,
                    unfocusedTextColor = colors.accent,
                    focusedBorderColor = colors.primary,
                    unfocusedBorderColor = colors.accent
                ),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = { Text("Password", color = colors.accent, fontFamily = FontFamily.Monospace) },
                visualTransformation = PasswordVisualTransformation(),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = colors.primary,
                    unfocusedTextColor = colors.accent,
                    focusedBorderColor = colors.primary,
                    unfocusedBorderColor = colors.accent
                ),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(24.dp))

            if (errorText != null) {
                Text(errorText!!, color = colors.error, style = NocTypography.labelSmall)
                Spacer(modifier = Modifier.height(12.dp))
            }

            Button(
                onClick = {
                    loading = true
                    errorText = null
                    client.hostUrl = hostUrl
                    client.login(username, password) { success, err ->
                        loading = false
                        if (success) {
                            onLoginSuccess()
                        } else {
                            errorText = err ?: "Access Denied"
                        }
                    }
                },
                enabled = !loading,
                colors = ButtonDefaults.buttonColors(containerColor = colors.primary),
                modifier = Modifier.fillMaxWidth()
            ) {
                if (loading) {
                    CircularProgressIndicator(color = colors.background, modifier = Modifier.size(20.dp))
                } else {
                    Text("AUTHORIZE CONNECTION", color = colors.background, fontFamily = FontFamily.Monospace)
                }
            }
        }
    }
}

@Composable
fun MainDashboardContainer(
    client: NocClient,
    currentTheme: NocColors,
    onThemeChanged: (NocColors) -> Unit,
    onLogout: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) }
    var statusData by remember { mutableStateOf<JSONObject?>(client.systemStatus) }
    var conversationsData by remember { mutableStateOf<JSONArray>(client.conversations) }
    var messagesList by remember { mutableStateOf<List<ChatMessage>>(client.messages) }
    val colors = LocalNocColors.current

    LaunchedEffect(Unit) {
        client.onStatusUpdated = { statusData = it }
        client.onConversationsUpdated = { conversationsData = it }
        client.onMessagesUpdated = { messagesList = it.toList() }
    }

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = colors.surface) {
                val items = listOf("DASHBOARD", "CHAT AI", "AUTOPILOT")
                val icons = listOf(Icons.Filled.Home, Icons.Filled.Send, Icons.Filled.Settings)
                items.forEachIndexed { index, item ->
                    NavigationBarItem(
                        selected = selectedTab == index,
                        onClick = { selectedTab = index },
                        icon = { Icon(icons[index], contentDescription = item, tint = if (selectedTab == index) colors.primary else colors.accent) },
                        label = { Text(item, color = if (selectedTab == index) colors.primary else colors.accent, fontSize = 9.sp, fontFamily = FontFamily.Monospace) },
                        colors = NavigationBarItemDefaults.colors(indicatorColor = colors.surface)
                    )
                }
            }
        },
        topBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(colors.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "P3 NOC // COMMAND",
                    color = colors.primary,
                    style = NocTypography.bodyLarge,
                    fontWeight = FontWeight.Bold
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = {
                        val themes = listOf(MatrixGreenColors, AmberCrtColors, CyberBlueColors)
                        val next = (themes.indexOf(currentTheme) + 1) % themes.size
                        onThemeChanged(themes[next])
                    }) {
                        Icon(Icons.Filled.Refresh, contentDescription = "Cycle theme", tint = colors.primary)
                    }
                    IconButton(onClick = onLogout) {
                        Icon(Icons.Filled.ExitToApp, contentDescription = "Disconnect", tint = colors.error)
                    }
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp)
        ) {
            when (selectedTab) {
                0 -> DashboardScreen(statusData)
                1 -> ChatScreen(client, conversationsData, messagesList)
                2 -> AutopilotScreen(client, statusData)
            }
        }
    }
}

@Composable
fun DashboardScreen(status: JSONObject?) {
    val colors = LocalNocColors.current
    if (status == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("WAITING FOR TELEMETRY STREAM...", color = colors.primary, style = NocTypography.bodyLarge)
        }
        return
    }

    val healthScore = status.optInt("overall_health_score", 100)
    val statusText = status.optString("overall_status", "GREEN")
    val uptime = status.optString("uptime", "Unknown")
    val activeIssues = status.optJSONArray("active_issues") ?: JSONArray()

    LazyColumn(modifier = Modifier.fillMaxSize()) {
        item {
            // Health Gauge
            NocCard(title = "OVERALL STATUS") {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("HEALTH SCORE: $healthScore%", color = colors.primary, style = NocTypography.bodyLarge)
                        Text(
                            text = statusText,
                            color = if (statusText == "GREEN") colors.healthy else if (statusText == "YELLOW") colors.warning else colors.error,
                            style = NocTypography.titleLarge
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    LinearProgressIndicator(
                        progress = { healthScore.toFloat() / 100f },
                        modifier = Modifier.fillMaxWidth(),
                        color = colors.primary,
                        trackColor = colors.accent.copy(alpha = 0.2f),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("SYSTEM UPTIME: $uptime", color = colors.accent, style = NocTypography.labelSmall)
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }

        item {
            // Queue counts
            val queues = status.optJSONObject("queue_counts")
            if (queues != null) {
                NocCard(title = "INGEST QUEUE STATUS") {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("Pending: ${queues.optInt("pending")}", color = colors.primary, style = NocTypography.labelSmall)
                            Text("Processing: ${queues.optInt("processing")}", color = colors.primary, style = NocTypography.labelSmall)
                            Text("Completed: ${queues.optInt("completed")}", color = colors.healthy, style = NocTypography.labelSmall)
                            Text("Failed: ${queues.optInt("failed")}", color = colors.error, style = NocTypography.labelSmall)
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }

        // T310 Local Host metrics
        val t310 = status.optJSONObject("t310")
        if (t310 != null) {
            item {
                NocCard(title = "T310 BITCOIN SERVER") {
                    Column(modifier = Modifier.padding(12.dp)) {
                        val isOnline = t310.optBoolean("online", false)
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("IP: Local Host", color = colors.accent, style = NocTypography.labelSmall)
                            Text(
                                text = if (isOnline) "ONLINE" else "OFFLINE",
                                color = if (isOnline) colors.healthy else colors.error,
                                style = NocTypography.labelSmall
                            )
                        }
                        if (isOnline) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("CPU: ${t310.optDouble("cpu_percent")}%", color = colors.primary, style = NocTypography.labelSmall)
                            Text("RAM: ${t310.optDouble("ram_percent")}%", color = colors.primary, style = NocTypography.labelSmall)
                            Text("Disk: ${t310.optDouble("disk_percent")}%", color = colors.primary, style = NocTypography.labelSmall)
                            Spacer(modifier = Modifier.height(4.dp))
                            Text("Rx Speed: ${t310.optDouble("network_rx_kbps")} KB/s", color = colors.accent, style = NocTypography.labelSmall)
                            Text("Tx Speed: ${t310.optDouble("network_tx_kbps")} KB/s", color = colors.accent, style = NocTypography.labelSmall)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }
        }

        // R510 Remote Server metrics
        val r510 = status.optJSONObject("r510")
        if (r510 != null) {
            item {
                NocCard(title = "R510 AI WALLBOARD") {
                    Column(modifier = Modifier.padding(12.dp)) {
                        val isOnline = r510.optBoolean("online", false)
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text("IP: 100.105.154.91", color = colors.accent, style = NocTypography.labelSmall)
                            Text(
                                text = if (isOnline) "ONLINE" else "OFFLINE",
                                color = if (isOnline) colors.healthy else colors.error,
                                style = NocTypography.labelSmall
                            )
                        }
                        if (isOnline) {
                            Spacer(modifier = Modifier.height(8.dp))
                            Text("Ping: ${r510.optDouble("ping_latency_ms")}ms", color = colors.primary, style = NocTypography.labelSmall)
                            Text("SSH: ${r510.optString("ssh_status")}", color = colors.primary, style = NocTypography.labelSmall)
                            Text("Ollama: ${r510.optString("ollama_status")}", color = colors.primary, style = NocTypography.labelSmall)
                            Text("Active Model: ${r510.optString("active_model")}", color = colors.accent, style = NocTypography.labelSmall)
                            Text("Active Requests: ${r510.optInt("active_requests")}", color = colors.accent, style = NocTypography.labelSmall)
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }
        }

        // Active operational issues list
        if (activeIssues.length() > 0) {
            item {
                NocCard(title = "ACTIVE ISSUES / WARNINGS") {
                    Column(modifier = Modifier.padding(12.dp)) {
                        for (i in 0 until activeIssues.length()) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Filled.Warning, contentDescription = "Warning", tint = colors.error, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = activeIssues.getString(i),
                                    color = colors.error,
                                    style = NocTypography.labelSmall
                                )
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(client: NocClient, conversations: JSONArray, messages: List<ChatMessage>) {
    val colors = LocalNocColors.current
    var textInput by remember { mutableStateOf("") }
    var selectedConvId by remember { mutableStateOf<Int?>(null) }
    var showModelsDropdown by remember { mutableStateOf(false) }
    var selectedModel by remember { mutableStateOf("qwen3:8b") }

    val lazyListState = rememberLazyListState()

    // Keep scroll to bottom on new message
    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            lazyListState.animateScrollToItem(messages.size - 1)
        }
    }

    // Load initial conversation messages if we just selected one
    LaunchedEffect(selectedConvId) {
        if (selectedConvId != null) {
            client.fetchMessages(selectedConvId!!)
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        if (selectedConvId == null) {
            // Render Conversation selection or creation panel
            NocCard(title = "CONVERSATIONS LIST") {
                Column(modifier = Modifier.padding(12.dp)) {
                    Button(
                        onClick = {
                            client.createConversation("Session " + Date().time % 10000) { id ->
                                if (id != null) {
                                    client.fetchConversations()
                                    selectedConvId = id
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = colors.primary),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("START NEW OPERATIONAL SESSION", color = colors.background, fontFamily = FontFamily.Monospace)
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    LazyColumn {
                        items(conversations.length()) { index ->
                            val conv = conversations.getJSONObject(index)
                            val id = conv.getInt("id")
                            val title = conv.getString("title")
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { selectedConvId = id }
                                    .padding(vertical = 12.dp, horizontal = 8.dp)
                                    .border(BorderStroke(0.5.dp, colors.accent), RoundedCornerShape(4.dp))
                                    .background(colors.surface)
                                    .padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(title, color = colors.primary, style = NocTypography.bodyLarge)
                                Icon(Icons.Filled.ArrowForward, contentDescription = "Enter", tint = colors.primary)
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }
                }
            }
        } else {
            // Render actual chat interface
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = { selectedConvId = null }) {
                    Icon(Icons.Filled.ArrowBack, contentDescription = "Back", tint = colors.primary)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("SESSIONS", color = colors.primary, fontFamily = FontFamily.Monospace)
                }

                Box {
                    Button(
                        onClick = { showModelsDropdown = true },
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accent)
                    ) {
                        Text(selectedModel, color = colors.primary, fontFamily = FontFamily.Monospace)
                    }
                    DropdownMenu(
                        expanded = showModelsDropdown,
                        onDismissRequest = { showModelsDropdown = false },
                        modifier = Modifier.background(colors.surface)
                    ) {
                        val models = listOf("qwen3:8b", "phi3:mini")
                        models.forEach { model ->
                            DropdownMenuItem(
                                text = { Text(model, color = colors.primary, fontFamily = FontFamily.Monospace) },
                                onClick = {
                                    selectedModel = model
                                    showModelsDropdown = false
                                }
                            )
                        }
                    }
                }
            }

            LazyColumn(
                state = lazyListState,
                modifier = Modifier
                    .weight(1f)
                    .border(BorderStroke(1.dp, colors.accent), RoundedCornerShape(4.dp))
                    .background(colors.surface)
                    .padding(8.dp)
            ) {
                items(messages) { msg ->
                    ChatBubble(msg)
                    Spacer(modifier = Modifier.height(12.dp))
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Text input row
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = textInput,
                    onValueChange = { textInput = it },
                    label = { Text("Query AI operator...", color = colors.accent, fontFamily = FontFamily.Monospace) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = colors.primary,
                        unfocusedTextColor = colors.accent,
                        focusedBorderColor = colors.primary,
                        unfocusedBorderColor = colors.accent
                    ),
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = {
                        val toSend = textInput.trim()
                        if (toSend.isNotEmpty() && !client.isStreamingChat) {
                            textInput = ""
                            client.sendMessage(selectedConvId!!, toSend, selectedModel)
                        }
                    },
                    modifier = Modifier
                        .size(48.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(colors.primary)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Send,
                        contentDescription = "Send",
                        tint = colors.background
                    )
                }
            }
        }
    }
}

@Composable
fun ChatBubble(message: ChatMessage) {
    val colors = LocalNocColors.current
    val isUser = message.role == "user"
    val alignment = if (isUser) Alignment.End else Alignment.Start
    val bg = if (isUser) colors.accent.copy(alpha = 0.3f) else Color.Transparent
    val border = if (isUser) BorderStroke(0.5.dp, colors.primary) else BorderStroke(0.5.dp, colors.accent)

    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = alignment
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 290.dp)
                .border(border, RoundedCornerShape(4.dp))
                .background(bg)
                .padding(12.dp)
        ) {
            Text(
                text = if (isUser) "MATTY_USER_HOST" else "R510_AI_AGENT",
                color = if (isUser) colors.primary else colors.accent,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace
            )
            Spacer(modifier = Modifier.height(4.dp))
            
            // Format thinking process box beautifully
            val textContent = message.content
            if (textContent.contains("[THINKING]")) {
                var showThinking by remember { mutableStateOf(false) }
                val startIdx = textContent.indexOf("[THINKING]") + 10
                val endIdx = textContent.indexOf("[/THINKING]")
                
                val thinkingText = if (endIdx > startIdx) {
                    textContent.substring(startIdx, endIdx)
                } else {
                    textContent.substring(startIdx)
                }

                val mainText = if (endIdx > 0 && endIdx + 11 < textContent.length) {
                    textContent.substring(endIdx + 11)
                } else if (endIdx > 0) {
                    ""
                } else {
                    ""
                }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(BorderStroke(0.5.dp, colors.warning), RoundedCornerShape(2.dp))
                        .background(colors.warning.copy(alpha = 0.05f))
                        .padding(8.dp)
                        .clickable { showThinking = !showThinking }
                ) {
                    Column {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.Info, contentDescription = "Info", tint = colors.warning, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = if (showThinking) "HIDE THINKING PROCESS" else "SHOW THINKING PROCESS",
                                color = colors.warning,
                                fontSize = 11.sp,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold
                            )
                        }
                        AnimatedVisibility(visible = showThinking) {
                            Text(
                                text = thinkingText.trim(),
                                color = colors.warning.copy(alpha = 0.8f),
                                fontSize = 12.sp,
                                fontFamily = FontFamily.Monospace,
                                modifier = Modifier.padding(top = 6.dp)
                            )
                        }
                    }
                }
                if (mainText.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(text = mainText.trim(), color = colors.primary, style = NocTypography.bodyLarge)
                }
            } else {
                Text(text = textContent, color = colors.primary, style = NocTypography.bodyLarge)
            }
        }
    }
}

@Composable
fun AutopilotScreen(client: NocClient, status: JSONObject?) {
    val colors = LocalNocColors.current
    if (status == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("WAITING FOR AUTOPILOT TELEMETRY...", color = colors.primary, style = NocTypography.bodyLarge)
        }
        return
    }

    val isLocked = status.optBoolean("autopilot_locked", false)
    val isSafeMode = status.optBoolean("autopilot_safe_mode", false)
    val totalRecoveries = status.optInt("total_recoveries_today", 0)

    LazyColumn(modifier = Modifier.fillMaxSize()) {
        item {
            NocCard(title = "AUTOPILOT DIAGNOSTICS") {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("AUTOPILOT MODULE:", color = colors.accent, style = NocTypography.bodyLarge)
                        Text(
                            text = if (isLocked) "LOCKED (ENGAGED)" else "UNLOCKED (MANUAL CONTROL)",
                            color = if (isLocked) colors.healthy else colors.warning,
                            style = NocTypography.bodyLarge,
                            fontWeight = FontWeight.Bold
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text("Safe Mode Status:", color = colors.accent, style = NocTypography.labelSmall)
                        Text(
                            text = if (isSafeMode) "ACTIVE" else "INACTIVE",
                            color = if (isSafeMode) colors.error else colors.accent,
                            style = NocTypography.labelSmall
                        )
                    }
                    Text("Total Recoveries Today: $totalRecoveries", color = colors.accent, style = NocTypography.labelSmall)
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = {
                            client.toggleAutopilotLock {
                                Toast.makeText(client.onStatusUpdated as? android.content.Context ?: return@toggleAutopilotLock, "Autopilot Toggle Triggered", Toast.LENGTH_SHORT).show()
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if (isLocked) colors.warning else colors.primary),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = if (isLocked) "RELEASE LOCK TO MANUAL" else "ENGAGE AUTOPILOT SYSTEM LOCK",
                            color = colors.background,
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }

        item {
            // Manual overrides
            NocCard(title = "MANUAL RECOVERY ACTION PANEL") {
                Column(modifier = Modifier.padding(12.dp)) {
                    Button(
                        onClick = {
                            client.triggerRecoveryAction("requeue-failed") { success ->
                                val txt = if (success) "Failed Queue Items Requeued" else "Action Failed"
                                Log.i("NocClient", txt)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accent),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("REQUEUE ALL FAILED QUEUE JOBS", color = colors.primary, fontFamily = FontFamily.Monospace)
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = {
                            client.triggerRecoveryAction("clear-stuck") { success ->
                                val txt = if (success) "Stuck Processing Jobs Cleared" else "Action Failed"
                                Log.i("NocClient", txt)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = colors.accent),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("CLEAR STUCK PROCESSING JOBS (>15M)", color = colors.primary, fontFamily = FontFamily.Monospace)
                    }
                }
            }
        }
    }
}

@Composable
fun NocCard(
    title: String,
    content: @Composable () -> Unit
) {
    val colors = LocalNocColors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(BorderStroke(1.dp, colors.accent), RoundedCornerShape(4.dp))
            .background(colors.surface)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(colors.accent.copy(alpha = 0.2f))
                .padding(vertical = 6.dp, horizontal = 12.dp)
        ) {
            Text(
                text = title,
                color = colors.primary,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace
            )
        }
        content()
    }
}
