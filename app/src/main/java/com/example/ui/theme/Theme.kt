package com.example.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = VaultPrimaryDark,
    onPrimary = VaultOnPrimaryDark,
    primaryContainer = VaultPrimaryContainerDark,
    onPrimaryContainer = VaultOnPrimaryContainerDark,
    secondary = VaultSecondaryDark,
    onSecondary = VaultOnSecondaryDark,
    secondaryContainer = VaultSecondaryContainerDark,
    onSecondaryContainer = VaultOnSecondaryContainerDark,
    tertiary = VaultTertiaryDark,
    onTertiary = VaultOnTertiaryDark,
    tertiaryContainer = VaultTertiaryContainerDark,
    onTertiaryContainer = VaultOnTertiaryContainerDark,
    background = VaultBackgroundDark,
    surface = VaultSurfaceDark,
    surfaceVariant = VaultSurfaceVariantDark,
    onBackground = VaultOnSurfaceDark,
    onSurface = VaultOnSurfaceDark,
    onSurfaceVariant = VaultOnSurfaceVariantDark,
    outline = VaultOutlineDark,
    outlineVariant = VaultOutlineVariantDark,
    error = AccentError
)

private val LightColorScheme = lightColorScheme(
    primary = VaultPrimaryLight,
    onPrimary = VaultOnPrimaryLight,
    primaryContainer = VaultPrimaryContainerLight,
    onPrimaryContainer = VaultOnPrimaryContainerLight,
    secondary = VaultSecondaryLight,
    onSecondary = VaultOnSecondaryLight,
    secondaryContainer = VaultSecondaryContainerLight,
    onSecondaryContainer = VaultOnSecondaryContainerLight,
    tertiary = VaultTertiaryLight,
    onTertiary = VaultOnTertiaryLight,
    tertiaryContainer = VaultTertiaryContainerLight,
    onTertiaryContainer = VaultOnTertiaryContainerLight,
    background = VaultBackgroundLight,
    surface = VaultSurfaceLight,
    surfaceVariant = VaultSurfaceVariantLight,
    onBackground = VaultOnSurfaceLight,
    onSurface = VaultOnSurfaceLight,
    onSurfaceVariant = VaultOnSurfaceVariantLight,
    error = AccentError
)

@Composable
fun MediaVaultTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}
