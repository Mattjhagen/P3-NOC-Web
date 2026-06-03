# Theme configuration for P3 NOC

THEMES = [
    "matrix-green",
    "amber-crt",
    "cyber-blue",
    "red-alert"
]

THEME_NAMES = {
    "matrix-green": "Matrix Green",
    "amber-crt": "Amber CRT",
    "cyber-blue": "Cyber Blue",
    "red-alert": "Red Alert"
}

# Color configurations for manual rendering fallback (e.g. Rich console markup inside widgets)
THEME_COLORS = {
    "matrix-green": {
        "primary": "green",
        "primary_bright": "bright_green",
        "muted": "dark_green",
        "accent": "spring_green1",
        "warning": "yellow",
        "error": "red",
        "critical": "bright_red",
        "healthy": "green",
        "tag": "[bold green]",
        "tag_muted": "[green]",
    },
    "amber-crt": {
        "primary": "orange3",
        "primary_bright": "bright_yellow",
        "muted": "dark_orange",
        "accent": "gold1",
        "warning": "orange1",
        "error": "red",
        "critical": "bright_red",
        "healthy": "orange3",
        "tag": "[bold orange3]",
        "tag_muted": "[orange3]",
    },
    "cyber-blue": {
        "primary": "cyan",
        "primary_bright": "bright_cyan",
        "muted": "blue",
        "accent": "deep_sky_blue1",
        "warning": "yellow",
        "error": "magenta",
        "critical": "bright_magenta",
        "healthy": "cyan",
        "tag": "[bold cyan]",
        "tag_muted": "[cyan]",
    },
    "red-alert": {
        "primary": "red",
        "primary_bright": "bright_red",
        "muted": "dark_red",
        "accent": "orange_red1",
        "warning": "yellow",
        "error": "red",
        "critical": "bright_red",
        "healthy": "green",
        "tag": "[bold red]",
        "tag_muted": "[red]",
    }
}
