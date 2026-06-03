import psycopg2
from psycopg2.extras import RealDictCursor
import logging
from datetime import datetime, timedelta
from config.settings import DATABASE_URL

logger = logging.getLogger("dashboard")

class DBService:
    def __init__(self):
        self.db_url = DATABASE_URL

    def get_connection(self):
        """Establish a connection to the database. May raise psycopg2 exceptions."""
        return psycopg2.connect(self.db_url, connect_timeout=3)

    def check_db_health(self) -> bool:
        """Test database connection health."""
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
            return True
        except Exception as e:
            logger.error(f"Database health check failed: {e}")
            return False
        finally:
            if conn:
                conn.close()

    def get_queue_counts(self) -> dict:
        """
        Query processing_queue counts by status.
        Returns: { 'pending': 0, 'processing': 0, 'completed': 0, 'failed': 0 }
        """
        counts = {'pending': 0, 'processing': 0, 'completed': 0, 'failed': 0}
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT status, COUNT(*) 
                    FROM processing_queue 
                    GROUP BY status;
                """)
                rows = cur.fetchall()
                for status, count in rows:
                    if status in counts:
                        counts[status] = count
                    elif status == 'dead_letter':
                        # Group dead_letter under failed for status displays if needed,
                        # or track it. Let's add it to failed count.
                        counts['failed'] += count
            return counts
        except Exception as e:
            logger.error(f"Failed to get queue counts: {e}")
            return counts  # Return default zeros on error
        finally:
            if conn:
                conn.close()

    def get_latest_articles(self, limit=50) -> list:
        """
        Get latest analyzed articles.
        Returns: list of dicts with title, sentiment_score, importance_score, sentiment, confidence.
        """
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT a.id, a.title, an.sentiment_score, an.importance_score, 
                           an.sentiment, an.confidence, an.created_at
                    FROM analyses an
                    JOIN articles a ON an.article_id = a.id
                    ORDER BY an.created_at DESC
                    LIMIT %s;
                """, (limit,))
                return cur.fetchall()
        except Exception as e:
            logger.error(f"Failed to fetch latest articles: {e}")
            return []
        finally:
            if conn:
                conn.close()

    def get_latest_analysis(self) -> dict:
        """
        Get the single latest article analysis details for the Risk Radar.
        """
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT a.title, an.sentiment_score, an.importance_score, 
                           an.sentiment, an.confidence, an.summary
                    FROM analyses an
                    JOIN articles a ON an.article_id = a.id
                    ORDER BY an.created_at DESC
                    LIMIT 1;
                """)
                row = cur.fetchone()
                return row if row else {}
        except Exception as e:
            logger.error(f"Failed to fetch latest analysis: {e}")
            return {}
        finally:
            if conn:
                conn.close()

    def get_queue_throughput(self) -> dict:
        """
        Compute queue throughput and ETA.
        Returns: {
            'processed_last_hour': int,
            'avg_time': float, (in seconds)
            'remaining': int,
            'eta_str': str, (e.g. "1h 29m")
            'max_retry': int
        }
        """
        stats = {
            'processed_last_hour': 0,
            'avg_time': 0.0,
            'remaining': 0,
            'eta_str': "0m",
            'max_retry': 0
        }
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                # 1. Processed in the last hour
                cur.execute("""
                    SELECT COUNT(*) FROM analyses 
                    WHERE created_at >= NOW() - INTERVAL '1 hour';
                """)
                stats['processed_last_hour'] = cur.fetchone()[0]

                # 2. Avg analysis time (in seconds)
                # First try last hour
                cur.execute("""
                    SELECT AVG(response_time_ms) FROM analysis_versions 
                    WHERE created_at >= NOW() - INTERVAL '1 hour';
                """)
                avg_ms = cur.fetchone()[0]
                if avg_ms is None:
                    # Fallback to overall average
                    cur.execute("SELECT AVG(response_time_ms) FROM analysis_versions;")
                    avg_ms = cur.fetchone()[0]
                
                stats['avg_time'] = (avg_ms / 1000.0) if avg_ms is not None else 224.0 # Fallback default 224s

                # 3. Queue remaining
                cur.execute("""
                    SELECT COUNT(*) FROM processing_queue 
                    WHERE status IN ('pending', 'processing', 'failed');
                """)
                stats['remaining'] = cur.fetchone()[0]

                # 4. Max retry count in active queue
                cur.execute("""
                    SELECT MAX(retry_count) FROM processing_queue 
                    WHERE status IN ('pending', 'processing', 'failed');
                """)
                val = cur.fetchone()[0]
                stats['max_retry'] = val if val is not None else 0

                # 5. ETA Calculation
                total_seconds = stats['remaining'] * stats['avg_time']
                if total_seconds > 0:
                    hours = int(total_seconds // 3600)
                    minutes = int((total_seconds % 3600) // 60)
                    if hours > 0:
                        stats['eta_str'] = f"{hours}h {minutes}m"
                    else:
                        stats['eta_str'] = f"{minutes}m"
                else:
                    stats['eta_str'] = "0m"

            return stats
        except Exception as e:
            logger.error(f"Failed to calculate queue throughput: {e}")
            return stats
        finally:
            if conn:
                conn.close()

    def get_processed_today(self) -> int:
        """Count analyses processed today since midnight local time."""
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                # Count analyses since start of today
                cur.execute("""
                    SELECT COUNT(*) FROM analyses 
                    WHERE created_at >= CURRENT_DATE;
                """)
                return cur.fetchone()[0]
        except Exception as e:
            logger.error(f"Failed to count processed today: {e}")
            return 0
        finally:
            if conn:
                conn.close()

    def get_hourly_risk_history(self) -> list:
        """
        Query average risk (importance_score) grouped by hour for the last 24 hours.
        Returns: list of exactly 24 integers representing hourly averages.
        """
        history = [0] * 24
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT DATE_TRUNC('hour', created_at) AS hr, AVG(importance_score) as avg_risk
                    FROM analyses
                    WHERE created_at >= NOW() - INTERVAL '24 hours'
                    GROUP BY hr
                    ORDER BY hr ASC;
                """)
                rows = cur.fetchall()
                
                # Align rows into 24-hour bins
                now = datetime.now()
                # Create 24 hourly timestamps ending now
                bins = [now - timedelta(hours=i) for i in range(23, -1, -1)]
                
                # Map query results to their closest bins
                row_map = {}
                for hr, avg_risk in rows:
                    if hr:
                        # Normalize timezone if necessary
                        hr_naive = hr.replace(tzinfo=None)
                        row_map[hr_naive.hour] = int(avg_risk)
                
                # Fill the history list
                last_val = 0
                for idx, b in enumerate(bins):
                    h = b.hour
                    if h in row_map:
                        history[idx] = row_map[h]
                        last_val = row_map[h]
                    else:
                        history[idx] = last_val # forward-fill last known risk level
            return history
        except Exception as e:
            logger.error(f"Failed to fetch hourly risk history: {e}")
            return [0] * 24
        finally:
            if conn:
                conn.close()

    def requeue_failed_items(self) -> bool:
        """Requeue failed and dead_letter queue items by setting status='pending' and retry_count=0."""
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE processing_queue 
                    SET status = 'pending', retry_count = 0, last_error = NULL, updated_at = CURRENT_TIMESTAMP
                    WHERE status IN ('failed', 'dead_letter');
                """)
                conn.commit()
            return True
        except Exception as e:
            logger.error(f"Failed to requeue failed items: {e}")
            if conn:
                conn.rollback()
            return False
        finally:
            if conn:
                conn.close()

    def clear_stuck_processing(self) -> bool:
        """Clear items stuck in 'processing' status for over 15 minutes by marking them 'failed'."""
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE processing_queue 
                    SET status = 'failed', updated_at = CURRENT_TIMESTAMP
                    WHERE status = 'processing' 
                      AND updated_at <= CURRENT_TIMESTAMP - INTERVAL '15 minutes';
                """)
                conn.commit()
            return True
        except Exception as e:
            logger.error(f"Failed to clear stuck processing items: {e}")
            if conn:
                conn.rollback()
            return False
        finally:
            if conn:
                conn.close()

    def get_rss_feed_health(self) -> bool:
        """Verify that RSS feeds are queryable and have successfully polled in the last 24 hours."""
        conn = None
        try:
            conn = self.get_connection()
            with conn.cursor() as cur:
                # Check if there's any successful feed poll in the last 24 hours
                cur.execute("""
                    SELECT COUNT(*) FROM feed_sources 
                    WHERE enabled = TRUE 
                      AND (last_successful_poll IS NULL OR last_successful_poll >= NOW() - INTERVAL '24 hours');
                """)
                count = cur.fetchone()[0]
                return count > 0
        except Exception as e:
            logger.error(f"Failed to check RSS feed health: {e}")
            return False
        finally:
            if conn:
                conn.close()

