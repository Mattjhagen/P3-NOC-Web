# P3NOC RSS Feed System

## What Was Set Up

✅ **Database Schema**: 4 tables created
- `feed_sources` - RSS feed URLs (5 crypto news sites)
- `articles` - Ingested news articles
- `analyses` - AI-generated analysis results
- `processing_queue` - Article processing queue

✅ **RSS Sources** (5 feeds):
1. CoinDesk
2. Cointelegraph  
3. Bitcoin Magazine
4. The Block
5. Decrypt

✅ **RSS Worker** (`rss_worker.py`):
- Fetches articles every 5 minutes
- Analyzes with Gemini 3 Flash
- Extracts sentiment, risk score, summary

## Installation

Run the complete setup:
```bash
cd ~/P3_Official/P3-NOC-Web
sudo ./setup-rss-complete.sh
```

Or manually:
```bash
sudo cp /tmp/bitcoin-worker-real.service /etc/systemd/system/bitcoin-worker.service
sudo systemctl daemon-reload
sudo systemctl restart bitcoin-worker
sudo systemctl enable bitcoin-worker
```

## Monitoring

### Check worker status:
```bash
sudo systemctl status bitcoin-worker
```

### View live logs:
```bash
sudo journalctl -u bitcoin-worker -f
```

### Check database:
```bash
# Count articles
docker exec p3-postgres psql -U p3user -d p3lending -c \
  "SELECT COUNT(*) FROM articles;"

# View recent articles
docker exec p3-postgres psql -U p3user -d p3lending -c \
  "SELECT title, published_at FROM articles ORDER BY created_at DESC LIMIT 5;"

# Check analyses
docker exec p3-postgres psql -U p3user -d p3lending -c \
  "SELECT COUNT(*) FROM analyses;"

# Queue status
docker exec p3-postgres psql -U p3user -d p3lending -c \
  "SELECT status, COUNT(*) FROM processing_queue GROUP BY status;"
```

## How It Works

1. **Every 5 minutes**: Worker polls RSS feeds
2. **New articles**: Inserted into `articles` table
3. **Queue**: Articles added to `processing_queue` as 'pending'
4. **AI Analysis**: Gemini 3 Flash analyzes each article:
   - Sentiment (positive/negative/neutral)
   - Sentiment score (-1.0 to 1.0)
   - Risk/importance score (0-100)
   - Confidence (high/medium/low)
   - Summary (50 words)
5. **Storage**: Analysis saved to `analyses` table
6. **Display**: P3NOC dashboard shows in news feed panel

## Timeline

- **5 minutes**: First articles appear in database
- **10 minutes**: First AI analyses complete
- **15 minutes**: News feed populated in dashboard

## Configuration

Edit `/etc/systemd/system/bitcoin-worker.service`:

```ini
Environment=RSS_POLL_INTERVAL=300  # Seconds (300 = 5 min)
Environment=OPENCODE_MODEL=gemini-free/gemini-3-flash-preview
```

Then restart:
```bash
sudo systemctl restart bitcoin-worker
```

## Troubleshooting

### Worker not starting:
```bash
sudo journalctl -u bitcoin-worker -n 50
```

### No articles appearing:
1. Check RSS feeds are responding:
   ```bash
   curl -I https://www.coindesk.com/arc/outboundfeeds/rss/
   ```

2. Check database connection:
   ```bash
   docker exec p3-postgres psql -U p3user -d p3lending -c "SELECT 1;"
   ```

### AI analysis failing:
Test OpenCode manually:
```bash
opencode run "What is Bitcoin?" --model gemini-free/gemini-3-flash-preview
```

## Stopping

```bash
sudo systemctl stop bitcoin-worker
sudo systemctl disable bitcoin-worker
```

## Files

- `/home/matt/P3_Official/P3-NOC-Web/rss_worker.py` - Main worker
- `/etc/systemd/system/bitcoin-worker.service` - Service definition
- `/home/matt/P3_Official/P3-NOC-Web/setup_rss_feeds.sql` - Database schema
