package xyz.mattyhagen.p3noc

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

@Immutable
data class NocColors(
    val background: Color,
    val surface: Color,
    val primary: Color,
    val accent: Color,
    val healthy: Color,
    val warning: Color,
    val error: Color,
    val isLight: Boolean = false
)

val MatrixGreenColors = NocColors(
    background = Color(0xFF020A02),
    surface = Color(0xFF041404),
    primary = Color(0xFF00FF00),
    accent = Color(0xFF008800),
    healthy = Color(0xFF00FF00),
    warning = Color(0xFFFFB000),
    error = Color(0xFFFF3333)
)

val AmberCrtColors = NocColors(
    background = Color(0xFF0A0600),
    surface = Color(0xFF140D00),
    primary = Color(0xFFFFAA00),
    accent = Color(0xFF996600),
    healthy = Color(0xFFFFAA00),
    warning = Color(0xFFFFCC00),
    error = Color(0xFFFF3333)
)

val CyberBlueColors = NocColors(
    background = Color(0xFF000814),
    surface = Color(0xFF001222),
    primary = Color(0xFF00F0FF),
    accent = Color(0xFF006699),
    healthy = Color(0xFF00F0FF),
    warning = Color(0xFFFF007F),
    error = Color(0xFFFF2222)
)

val LocalNocColors = staticCompositionLocalOf { MatrixGreenColors }

val NocTypography = Typography(
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium,
        fontSize = 15.sp,
        lineHeight = 20.sp,
        letterSpacing = 0.5.sp
    ),
    titleLarge = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Bold,
        fontSize = 20.sp,
        lineHeight = 26.sp,
        letterSpacing = 0.75.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium,
        fontSize = 11.sp,
        lineHeight = 14.sp,
        letterSpacing = 0.25.sp
    )
)

@Composable
fun NocTheme(
    themeColors: NocColors = MatrixGreenColors,
    content: @Composable () -> Unit
) {
    androidx.compose.runtime.CompositionLocalProvider(
        LocalNocColors provides themeColors
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(themeColors.background)
        ) {
            content()
            CrtScanlineOverlay()
        }
    }
}

@Composable
fun CrtScanlineOverlay() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val strokeWidth = 1f
        val spacing = 8f
        var y = 0f
        while (y < size.height) {
            drawLine(
                color = Color.Black.copy(alpha = 0.15f),
                start = Offset(0f, y),
                end = Offset(size.width, y),
                strokeWidth = strokeWidth
            )
            y += spacing
        }
    }
}
