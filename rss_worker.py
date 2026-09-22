#!/usr/bin/env python3
"""
P3NOC RSS Feed Worker
Ingests Bitcoin/crypto news and analyzes with AI (Gemini 3 Flash)
"""

import feedparser
import psycopg2
from psycopg2.extras import RealDictCursor
import time
import logging
from datetime import datetime
import subprocess
import json
import os
from dotenv import load_dotenv

# Load environment
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)-8s %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://p3user:p3password@localhost:5432/p3lending")
OPENCODE_MODEL = os.getenv("OPENCODE_MODEL", "gemini-free/gemini-3-flash-preview")
POLL_INTERVAL = int(os.getenv("RSS_POLL_INTERVAL", "300"))  # 5 minutes

def get_db_connection():
    """Get database connection."""
    return psycopg2.connect(DATABASE_URL)

def fetch_rss_feeds():
    """Fetch all enabled RSS feeds and insert new articles."""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id, name, url FROM feed_sources WHERE enabled = TRUE")
            feeds = cur.fetchall()

            for feed in feeds:
                logger.info(f"[ingest] Polling RSS feed: {feed['name']}")
                try:
                    parsed = feedparser.parse(feed['url'])

                    if parsed.get('bozo'):
                        logger.warning(f"[ingest] Feed {feed['name']} returned errors")

                    new_articles = 0
                    for entry in parsed.entries[:10]:  # Limit to 10 most recent
                        title = entry.get('title', 'No title')
                        url = entry.get('link', '')
                        published = entry.get('published_parsed', None)
                        content = entry.get('summary', '')[:1000]  # Limit content size

                        if not url:
                            continue

                        # Convert published time
                        published_at = None
                        if published:
                            published_at = datetime(*published[:6])

                        # Insert article (ignore duplicates)
                        try:
                            cur.execute("""
                                INSERT INTO articles (feed_source_id, title, url, published_at, content)
                                VALUES (%s, %s, %s, %s, %s)
                                RETURNING id
                            """, (feed['id'], title, url, published_at, content))
                            article_id = cur.fetchone()['id']
                            conn.commit()

                            # Add to processing queue
                            cur.execute("""
                                INSERT INTO processing_queue (article_id, status)
                                VALUES (%s, 'pending')
                            """, (article_id,))
                            conn.commit()

                            new_articles += 1
                            logger.info(f"[database] New article added: {title[:60]}...")

                        except psycopg2.errors.UniqueViolation:
                            conn.rollback()
                            # Article already exists, skip
                            continue

                    # Update last_successful_poll
                    cur.execute("""
                        UPDATE feed_sources
                        SET last_successful_poll = NOW()
                        WHERE id = %s
                    """, (feed['id'],))
                    conn.commit()

                    logger.info(f"[ingest] {feed['name']}: {new_articles} new articles")

                except Exception as e:
                    logger.error(f"[ingest] Error polling {feed['name']}: {e}")
                    # Update error
                    cur.execute("""
                        UPDATE feed_sources
                        SET last_error = %s
                        WHERE id = %s
                    """, (str(e), feed['id']))
                    conn.commit()

    finally:
        conn.close()

def analyze_with_ai(article_title, article_content):
    """Analyze article using OpenCode Gemini 3 Flash."""
    prompt = f"""Analyze this Bitcoin/crypto news article and provide:
1. Sentiment (positive/negative/neutral)
2. Sentiment score (-1.0 to 1.0)
3. Importance/risk score (0-100)
4. Confidence (high/medium/low)
5. Brief summary (50 words max)

Title: {article_title}
Content: {article_content[:500]}

Respond in JSON format:
{{"sentiment": "...", "sentiment_score": 0.0, "importance_score": 0, "confidence": "...", "summary": "..."}}"""

    try:
        result = subprocess.run(
            ["opencode", "run", prompt, "--model", OPENCODE_MODEL],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode == 0:
            # Parse JSON from output
            output = result.stdout.strip()

            # Log AI's full response (chain of thought)
            logger.info(f"[AI] Gemini response for '{article_title[:50]}':")
            logger.info(f"[AI] {output[:500]}")  # First 500 chars

            # Extract JSON (opencode adds formatting)
            json_start = output.find('{')
            json_end = output.rfind('}') + 1
            if json_start >= 0 and json_end > json_start:
                json_str = output[json_start:json_end]
                analysis = json.loads(json_str)

                # Log parsed analysis
                logger.info(f"[AI] Parsed: sentiment={analysis.get('sentiment')}, " +
                           f"score={analysis.get('importance_score')}, " +
                           f"confidence={analysis.get('confidence')}")

                return analysis

        logger.warning(f"[AI] OpenCode returned non-zero exit: {result.stderr[:200]}")
        return None

    except subprocess.TimeoutExpired:
        logger.error("[AI] OpenCode timeout")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"[AI] JSON parse error: {e}")
        return None
    except Exception as e:
        logger.error(f"[AI] Analysis error: {e}")
        return None

def process_queue():
    """Process pending articles in the queue."""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Get pending articles (limit to 5 per cycle)
            cur.execute("""
                SELECT pq.id as queue_id, pq.article_id, a.title, a.content
                FROM processing_queue pq
                JOIN articles a ON pq.article_id = a.id
                WHERE pq.status = 'pending'
                ORDER BY pq.created_at ASC
                LIMIT 5
            """)
            items = cur.fetchall()

            for item in items:
                logger.info(f"[main] Processing article {item['article_id']}: {item['title'][:50]}...")

                # Update status to processing
                cur.execute("""
                    UPDATE processing_queue
                    SET status = 'processing', updated_at = NOW()
                    WHERE id = %s
                """, (item['queue_id'],))
                conn.commit()

                # Analyze with AI
                analysis = analyze_with_ai(item['title'], item['content'] or '')

                if analysis:
                    # Save analysis
                    try:
                        cur.execute("""
                            INSERT INTO analyses (
                                article_id, sentiment, sentiment_score,
                                importance_score, confidence, summary
                            ) VALUES (%s, %s, %s, %s, %s, %s)
                        """, (
                            item['article_id'],
                            analysis.get('sentiment', 'neutral'),
                            analysis.get('sentiment_score', 0.0),
                            analysis.get('importance_score', 50),
                            analysis.get('confidence', 'medium'),
                            analysis.get('summary', '')
                        ))
                        conn.commit()

                        # Mark as completed
                        cur.execute("""
                            UPDATE processing_queue
                            SET status = 'completed', updated_at = NOW()
                            WHERE id = %s
                        """, (item['queue_id'],))
                        conn.commit()

                        logger.info(f"[database] Analysis saved for article {item['article_id']}")

                    except Exception as e:
                        logger.error(f"[database] Error saving analysis: {e}")
                        conn.rollback()
                        # Mark as failed
                        cur.execute("""
                            UPDATE processing_queue
                            SET status = 'failed',
                                error_message = %s,
                                retry_count = retry_count + 1,
                                updated_at = NOW()
                            WHERE id = %s
                        """, (str(e), item['queue_id']))
                        conn.commit()
                else:
                    # AI analysis failed
                    cur.execute("""
                        UPDATE processing_queue
                        SET status = 'failed',
                            error_message = 'AI analysis returned no result',
                            retry_count = retry_count + 1,
                            updated_at = NOW()
                        WHERE id = %s
                    """, (item['queue_id'],))
                    conn.commit()
                    logger.warning(f"[main] AI analysis failed for article {item['article_id']}")

    finally:
        conn.close()

def main():
    """Main worker loop."""
    logger.info("[main] Starting P3 NOC RSS Worker...")
    logger.info(f"[main] Database: {DATABASE_URL.split('@')[1]}")
    logger.info(f"[main] AI Model: {OPENCODE_MODEL}")
    logger.info(f"[main] Poll interval: {POLL_INTERVAL}s")

    cycle = 0
    while True:
        try:
            cycle += 1
            logger.info(f"[main] === Cycle {cycle} ===")

            # Fetch new articles from RSS feeds
            fetch_rss_feeds()

            # Process queued articles
            process_queue()

            logger.info(f"[main] Cycle {cycle} complete. Sleeping {POLL_INTERVAL}s...")
            time.sleep(POLL_INTERVAL)

        except KeyboardInterrupt:
            logger.info("[main] Shutting down...")
            break
        except Exception as e:
            logger.error(f"[main] Worker error: {e}")
            time.sleep(60)  # Wait before retry

if __name__ == "__main__":
    main()
