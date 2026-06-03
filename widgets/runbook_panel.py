from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

from config.settings import OLLAMA_REMOTE

class RunbookPanel(Static):
    """
    Operator Runbook Action panel.
    Displays available F6-F12 operations recovery controls.
    """
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "OPERATOR ACTIONS"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]

        content = Text()
        content.append("\n Operational Runbooks:\n\n", style=f"bold {primary}")

        # List action entries
        def add_action(key: str, desc: str):
            content.append(f"  {key:<5}", style=f"bold {accent}")
            content.append(f"{desc}\n", style="white")

        add_action("F6", "Restart Worker service")
        add_action("F7", "Restart RSS Ingest Timer")
        add_action("F8", "Requeue Failed Queue Jobs")
        add_action("F9", "Clear Stuck Processing (>15m)")
        if OLLAMA_REMOTE:
            add_action("F10", "Restart Ollama [DISABLED - REMOTE]")
        else:
            add_action("F10", "Restart Ollama Inference")
        add_action("F11", "Warm LLM Model Cache")
        add_action("F12", "Execute Full Health Recovery")

        return content
