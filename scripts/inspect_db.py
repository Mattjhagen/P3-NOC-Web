import psycopg2
from psycopg2.extras import RealDictCursor

DATABASE_URL = "postgresql://researcher:secure_password_change_me@localhost:5432/bitcoin_research"

def inspect_db():
    try:
        conn = psycopg2.connect(DATABASE_URL, connect_timeout=3)
        print("Connected successfully!")
        with conn.cursor() as cur:
            # Get list of tables
            cur.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public'
                ORDER BY table_name;
            """)
            tables = [row[0] for row in cur.fetchall()]
            print("Tables in database:", tables)
            
            # For each table, get columns and types
            for table in tables:
                print(f"\nSchema for table: {table}")
                cur.execute(f"""
                    SELECT column_name, data_type, is_nullable
                    FROM information_schema.columns
                    WHERE table_name = %s
                    ORDER BY ordinal_position;
                """, (table,))
                for col in cur.fetchall():
                    print(f"  - {col[0]}: {col[1]} (nullable: {col[2]})")
                    
        conn.close()
    except Exception as e:
        print("Error connecting to database:", e)

if __name__ == "__main__":
    inspect_db()
