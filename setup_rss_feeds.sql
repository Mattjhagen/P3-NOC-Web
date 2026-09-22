-- P3NOC Bitcoin Intelligence RSS Feed System
-- Database schema for news ingestion and AI analysis

-- 1. RSS Feed Sources Configuration
CREATE TABLE IF NOT EXISTS feed_sources (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    last_successful_poll TIMESTAMP WITH TIME ZONE,
    last_error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Articles Storage
CREATE TABLE IF NOT EXISTS articles (
    id SERIAL PRIMARY KEY,
    feed_source_id INTEGER REFERENCES feed_sources(id),
    title TEXT NOT NULL,
    url TEXT UNIQUE NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE,
    content TEXT,
    author VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. AI Analysis Results
CREATE TABLE IF NOT EXISTS analyses (
    id SERIAL PRIMARY KEY,
    article_id INTEGER REFERENCES articles(id) UNIQUE,
    sentiment VARCHAR(50), -- 'positive', 'negative', 'neutral'
    sentiment_score FLOAT, -- -1.0 to 1.0
    importance_score INTEGER, -- 0-100 (risk score)
    confidence VARCHAR(50), -- 'high', 'medium', 'low'
    summary TEXT,
    reasoning TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Processing Queue
CREATE TABLE IF NOT EXISTS processing_queue (
    id SERIAL PRIMARY KEY,
    article_id INTEGER REFERENCES articles(id),
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    retry_count INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Insert default RSS feeds
INSERT INTO feed_sources (name, url, enabled) VALUES
    ('CoinDesk', 'https://www.coindesk.com/arc/outboundfeeds/rss/', true),
    ('Cointelegraph', 'https://cointelegraph.com/rss', true),
    ('Bitcoin Magazine', 'https://bitcoinmagazine.com/.rss/full/', true),
    ('The Block', 'https://www.theblock.co/rss.xml', true),
    ('Decrypt', 'https://decrypt.co/feed', true)
ON CONFLICT DO NOTHING;

-- 6. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_articles_published_at ON articles(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_url ON articles(url);
CREATE INDEX IF NOT EXISTS idx_analyses_article_id ON analyses(article_id);
CREATE INDEX IF NOT EXISTS idx_analyses_created_at ON analyses(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_queue_status ON processing_queue(status);
CREATE INDEX IF NOT EXISTS idx_queue_article_id ON processing_queue(article_id);

-- 7. Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO p3user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO p3user;
