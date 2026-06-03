from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class AutopilotPanel(Static):
    """
    Autopilot Status Widget.
    Displays health scores, uptime, current automation mode (ACTIVE/LOCKED/SAFE),
    and a persistent log of the last 4 self-healing recovery actions.
    """
    status_str = reactive("ACTIVE")
    health_score = reactive(100)
    uptime_days = reactive(37)
    actions_today = reactive(0)
    last_actions_list = reactive([]) # list of dicts with timestamp, action_taken, result
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "AUTOPILOT STATUS"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]
        error = theme["error"]
        warning = theme["warning"]
        healthy = theme["healthy"]

        content = Text()
        content.append("\n Automation Brain:\n\n", style=f"bold {primary}")

        # Status row
        content.append("  Status:  ", style="white")
        if "LOCKED" in self.status_str.upper():
            status_style = f"bold {error} reverse"
        elif "SAFE" in self.status_str.upper():
            status_style = f"bold {warning}"
        else:
            status_style = f"bold {healthy}"
        content.append(f"{self.status_str}\n", style=status_style)

        # Health score
        content.append("  Health:  ", style="white")
        score_style = healthy if self.health_score > 90 else (warning if self.health_score > 50 else error)
        content.append(f"{self.health_score}/100\n", style=f"bold {score_style}")

        # Uptime
        content.append("  Uptime:  ", style="white")
        content.append(f"{self.uptime_days} Days\n", style=accent)

        # Actions today
        content.append("  Actions: ", style="white")
        content.append(f"{self.actions_today} Today\n\n", style=healthy if self.actions_today == 0 else warning)

        # Last Auto Actions sub-list
        content.append("  LAST AUTO ACTIONS:\n", style=f"bold {primary}")
        if self.last_actions_list:
            for act in self.last_actions_list[:4]:
                action = act.get("action_taken", "Unknown Action")
                # Format: "Restart Worker"
                # Strip underscores
                action_clean = action.replace("_", " ").title()
                result = act.get("result", "SUCCESS")
                
                icon = "✓" if result == "SUCCESS" else "✗"
                res_color = healthy if result == "SUCCESS" else error
                
                content.append(f"   {icon} ", style=f"bold {res_color}")
                content.append(f"{action_clean}\n", style="white")
        else:
            content.append("   - No self-healing actions taken -\n", style=muted)

        return content
