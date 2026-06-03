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

    /* Explicit theme styles for #dialog-box to avoid CSS variables */
    .matrix-green #dialog-box {
        border: thick #00ff00;
        background: #001100;
        color: #00ff00;
    }
    .amber-crt #dialog-box {
        border: thick #ffb000;
        background: #0a0600;
        color: #ffb000;
    }
    .cyber-blue #dialog-box {
        border: thick #00f0ff;
        background: #000911;
        color: #00f0ff;
    }
    .red-alert #dialog-box {
        border: thick #ff3333;
        background: #110000;
        color: #ff3333;
    }
    .matrix #dialog-box {
        border: thick #00ff00;
        background: #000000;
        color: #00ff00;
    }
    .bloomberg #dialog-box {
        border: thick #ff8800;
        background: #000022;
        color: #ff8800;
    }
    .trading-desk #dialog-box {
        border: thick #00ffff;
        background: #1c1c1c;
        color: #00ffff;
    }
    .midnight #dialog-box {
        border: thick #ffffff;
        background: #000000;
        color: #ffffff;
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
        self.add_class(self.theme_name)

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
