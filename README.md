# P3 NOC — Bitcoin Intelligence Operations Center

A professional, terminal-based operations command center built using Python 3.11 and the Textual framework. Designed to run full-screen on dedicated monitoring displays, it provides a high-fidelity real-time dashboard for the Bitcoin Research System running on Dell T310 and Dell R510 servers.

## Features

- **Decoupled Architecture**: Abstracted service layer isolates database queries, systemd service checks, and API polls from the UI layer.
- **Dynamic Themes (F2)**: Real-time toggling of multiple terminal themes:
  - **Matrix Green** (Default NOC colorway)
  - **Amber CRT** (Warm phosphor orange)
  - **Cyber Blue** (Cyberpunk/sci-fi style)
  - **Red Alert** (Critical incident highlight)
- **Compact Mode (F3)**: Collapses top ASCII header logos to maximize vertical screen real estate for logging and tickers.
- **Fullscreen Logs (F4)**: Toggles the logs panel to occupy the entire interface.
- **Operational Alerts**: Tracks system-level health indicators (PostgreSQL status, Worker processes, Ollama timeout rates, queue processing queues).
- **Throughput Panel**: Displays operations-focused metrics: processed articles in the last hour, average analysis duration, remaining queue depth, and automated ETA calculation.
- **Robust Price Ticker**: Real-time Bloomberg-style market ticker with multi-tier fallback (CoinGecko -> Binance -> Local cache).
- **Wallboard Mode (`--wallboard`)**: Designed for headless display TVs. Disables footers, maximizes viewing, and automatically cycles panel focus to prevent burn-in.

---

## Directory Structure

```text
p3-noc/
│
├── dashboard.py             # Main Textual App Entrypoint
├── requirements.txt         # Project Dependencies
├── p3-dashboard.service     # Systemd unit template
├── README.md                # System Documentation
│
├── config/
│   ├── __init__.py
│   ├── settings.py          # Environment configuration loader
│   └── themes.py            # Dashboard theme color configurations
│
├── services/
│   ├── __init__.py
│   ├── db_service.py        # PostgreSQL transaction manager
│   ├── log_service.py       # journalctl log streamer / mock fallback
│   ├── ollama_service.py    # Ollama health and request performance metrics
│   ├── feed_service.py      # Systemd service monitoring
│   └── btc_ticker_service.py# Price fetching with API failovers
│
└── widgets/
    ├── __init__.py
    ├── header.py            # ASCII logo & clock top header
    ├── system_panel.py      # Queue status metric cards
    ├── throughput_panel.py  # Processing velocities & ETA
    ├── ollama_panel.py      # Inference diagnostics
    ├── alert_panel.py       # Operational warning registry
    ├── risk_radar.py        # Stylized ASCII risk dial
    ├── news_feed.py         # DataTable for articles
    ├── log_panel.py         # Worker console log terminal
    └── ticker.py            # Bloomberg bottom scrolling ticker
```

---

## Installation & Setup

### 1. Clone & Setup Dependencies
Clone the repository to your chosen installation directory (e.g. `/opt/p3-noc`):
```bash
git clone git@github.com:Mattjhagen/p3-noc.git /opt/p3-noc
cd /opt/p3-noc
pip install -r requirements.txt
```

### 2. Configure Environment
Create a `.env` file in the root directory to define local parameters:
```ini
DATABASE_URL=postgresql://researcher:secure_password_change_me@localhost:5432/bitcoin_research
OLLAMA_URL=http://192.168.1.47:11434
OLLAMA_HOST_NAME=r510
OLLAMA_MODEL=qwen2.5:8b
```

### 3. Create Global Command Symlink
Create a symlink to easily execute `p3noc` from anywhere:
```bash
sudo chmod +x /opt/p3-noc/dashboard.py
sudo ln -s /opt/p3-noc/dashboard.py /usr/local/bin/p3noc
```

---

## Usage

Start the dashboard in **Interactive Mode**:
```bash
p3noc
# or directly
python dashboard.py
```

Start the dashboard in **Wallboard Mode** (for TV displays):
```bash
p3noc --wallboard
```

### Keyboard Controls
- **`L`**: Shift focus directly to the live Logs console.
- **`N`**: Shift focus to the News Feed table (pauses auto-scroll for reading).
- **`R`**: Shift focus to the Center Risk Radar.
- **`F2`**: Cycle color theme.
- **`F3`**: Toggle Compact mode (show/hide the big ASCII logo).
- **`F4`**: Toggle Fullscreen logs mode.
- **`Q`**: Quit dashboard.

---

## Dedicated Systemd Deployment

To host this dashboard on a dedicated physical display (e.g. connected to your T310/R510) showing on `/dev/tty1` at boot:

1. Copy the systemd service file:
   ```bash
   sudo cp p3-dashboard.service /etc/systemd/system/p3-dashboard.service
   ```
2. Enable and start the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable p3-dashboard.service
   sudo systemctl start p3-dashboard.service
   ```
