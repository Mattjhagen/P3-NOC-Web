from textual.screen import ModalScreen
from textual.widgets import Button, Static
from textual.containers import Grid
from textual.reactive import reactive
from config.themes import THEME_COLORS

class ConfirmationDialog(ModalScreen):
    """
    A self-contained modal confirmation dialog box
    reusable for F6-F9 database/service control operations.
    """
    CSS = """
    ConfirmationDialog {
        align: center middle;
    }
    #dialog-box {
        grid-size: 2;
        grid-gutter: 1;
        grid-rows: auto 3;
        padding: 1 2;
        width: 52;
        height: 12;
        border: thick var(--primary, #00ff00);
        background: var(--background, #001100);
        color: var(--text, #00ff00);
    }
    #dialog-message {
        column-span: 2;
        height: 1fr;
        content-align: center middle;
        text-align: center;
        text-style: bold;
    }
    #confirm-btn {
        width: 100%;
    }
    #cancel-btn {
        width: 100%;
    }
    """

    def __init__(self, message: str, theme_name="matrix-green", **kwargs):
        super().__init__(**kwargs)
        self.message = message
        self.theme_name = theme_name

    def compose(self):
        yield Grid(
            Static(self.message, id="dialog-message"),
            Button("Confirm [Enter/Y]", variant="success", id="confirm-btn"),
            Button("Cancel [Esc/N]", variant="error", id="cancel-btn"),
            id="dialog-box"
        )

    def on_mount(self):
        # Apply the current theme color to the border style
        theme = THEME_COLORS.get(self.theme_name, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        
        # Set classes or variables if needed
        self.styles.border = ("thick", primary)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button click events."""
        if event.button.id == "confirm-btn":
            self.dismiss(True)
        else:
            self.dismiss(False)

    def on_key(self, event) -> None:
        """Handle shortcut key events for instant action."""
        if event.key in ("enter", "y", "Y"):
            self.dismiss(True)
        elif event.key in ("escape", "n", "N"):
            self.dismiss(False)
