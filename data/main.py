"""
Spot Platform - Dummy Data Generator V2
도메인별로 분리된 구조
"""
import os
import argparse
from datetime import datetime

try:
    import psycopg2
    PSYCOPG2_AVAILABLE = True
except ImportError:
    PSYCOPG2_AVAILABLE = False
    print("WARNING: psycopg2 not installed. Install it with: pip install psycopg2-binary")

from generators import (
    UserGenerator,
    CategoryGenerator,
    StoreGenerator,
    MenuGenerator,
    OrderGenerator,
    ReviewGenerator
)

# 설정
CONFIG = {
    'NUM_USERS': 500,
    'NUM_STORES': 1000,
    'NUM_CATEGORIES': 20,
    'MENUS_PER_STORE': (5, 15),
    'OPTIONS_PER_MENU': (0, 5),
    'ORIGINS_PER_MENU': (0, 3),
    'ITEMS_PER_ORDER': (1, 5),
    'REVIEWS_PER_STORE': (0, 20),
    'OWNER_RATIO': 0.1,
}

# Database Configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'spot_db'),
    'user': os.getenv('DB_USER', 'spot_user'),
    'password': os.getenv('DB_PASSWORD', 'spot_pwd'),
}


class DataGeneratorOrchestrator:
    """데이터 생성 오케스트레이터"""

    def __init__(self, direct_insert=False):
        self.direct_insert = direct_insert
        self.conn = None
        self.cursor = None

    def connect_db(self):
        """데이터베이스 연결"""
        if not PSYCOPG2_AVAILABLE:
            raise RuntimeError("psycopg2 is not installed")
        self.conn = psycopg2.connect(**DB_CONFIG)
        self.cursor = self.conn.cursor()
        print(f"Connected to PostgreSQL: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
        print()

    def close_db(self):
        """데이터베이스 연결 종료"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.commit()
            self.conn.close()
            print("Database connection closed.")

    def truncate_all_tables(self):
        """모든 테이블 데이터 삭제"""
        print("Truncating all tables...")
        truncate_sql = """
        TRUNCATE TABLE
          p_review,
          p_payment_key, p_payment_history, p_payment,
          p_order_item_option, p_order_item, p_order,
          p_origin, p_menu_option, p_menu,
          p_store_category, p_store_user, p_store,
          p_user_auth, p_user,
          p_category
        CASCADE;
        """
        self.cursor.execute(truncate_sql)
        self.conn.commit()
        print("All tables truncated successfully.")
        print()

    def generate_all(self):
        """모든 데이터 생성"""
        # 1. Users
        user_gen = UserGenerator(self.conn, self.cursor, self.direct_insert)
        user_gen.generate(num_users=CONFIG['NUM_USERS'], owner_ratio=CONFIG['OWNER_RATIO'])
        users = user_gen.get_users()
        owner_users = user_gen.get_owner_users()

        # 2. Categories
        category_gen = CategoryGenerator(self.conn, self.cursor, self.direct_insert)
        category_gen.generate(num_categories=CONFIG['NUM_CATEGORIES'])
        categories = category_gen.get_categories()

        # 3. Stores
        store_gen = StoreGenerator(self.conn, self.cursor, self.direct_insert,
                                   users=users, owner_users=owner_users, categories=categories)
        store_gen.generate(num_stores=CONFIG['NUM_STORES'])
        stores = store_gen.get_stores()

        # 4. Menus
        menu_gen = MenuGenerator(self.conn, self.cursor, self.direct_insert,
                                users=users, stores=stores)
        menu_gen.generate(menus_per_store=CONFIG['MENUS_PER_STORE'],
                         options_per_menu=CONFIG['OPTIONS_PER_MENU'],
                         origins_per_menu=CONFIG['ORIGINS_PER_MENU'])
        menus = menu_gen.get_menus()
        menu_options = menu_gen.get_menu_options()

        # 5. Orders & Payments
        order_gen = OrderGenerator(self.conn, self.cursor, self.direct_insert,
                                   users=users, owner_users=owner_users, stores=stores,
                                   menus=menus, menu_options=menu_options)
        order_gen.generate(items_per_order=CONFIG['ITEMS_PER_ORDER'])
        orders = order_gen.get_orders()

        # 6. Reviews
        review_gen = ReviewGenerator(self.conn, self.cursor, self.direct_insert,
                                     stores=stores, orders=orders)
        review_gen.generate(reviews_per_store=CONFIG['REVIEWS_PER_STORE'])
        reviews = review_gen.get_reviews()

        # Summary
        return {
            'users': len(users),
            'owners': len(owner_users),
            'categories': len(categories),
            'stores': len(stores),
            'menus': len(menus),
            'menu_options': len(menu_options),
            'orders': len(orders),
            'reviews': len(reviews),
        }


def main():
    parser = argparse.ArgumentParser(description='Generate dummy data for Spot platform (V2)')
    parser.add_argument('--direct', '-d', action='store_true',
                       help='Insert directly into PostgreSQL database')
    parser.add_argument('--truncate', '-t', action='store_true',
                       help='Truncate all tables before inserting (only with --direct)')
    parser.add_argument('--host', default=os.getenv('DB_HOST', 'localhost'),
                       help='Database host')
    parser.add_argument('--port', type=int, default=int(os.getenv('DB_PORT', '5432')),
                       help='Database port')
    parser.add_argument('--database', default=os.getenv('DB_NAME', 'myapp_db'),
                       help='Database name')
    parser.add_argument('--user', default=os.getenv('DB_USER', 'admin'),
                       help='Database user')
    parser.add_argument('--password', default=os.getenv('DB_PASSWORD', 'secret'),
                       help='Database password')
    args = parser.parse_args()

    # Update DB config from args
    if args.direct:
        DB_CONFIG['host'] = args.host
        DB_CONFIG['port'] = args.port
        DB_CONFIG['database'] = args.database
        DB_CONFIG['user'] = args.user
        DB_CONFIG['password'] = args.password

    orchestrator = DataGeneratorOrchestrator(direct_insert=args.direct)

    print("=" * 60)
    print("  Spot Platform - Dummy Data Generator V2")
    print("=" * 60)
    print(f"Mode: {'Direct DB Insert' if args.direct else 'SQL Output'}")
    if args.direct:
        print(f"Database: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    print(f"Generated at: {datetime.now()}")
    print()
    print("Configuration:")
    print(f"  Users: {CONFIG['NUM_USERS']} (OWNER: {int(CONFIG['NUM_USERS'] * CONFIG['OWNER_RATIO'])})")
    print(f"  Stores: {CONFIG['NUM_STORES']}")
    print(f"  Categories: {CONFIG['NUM_CATEGORIES']}")
    print(f"  Menus per store: {CONFIG['MENUS_PER_STORE'][0]}-{CONFIG['MENUS_PER_STORE'][1]}")
    print(f"  Options per menu: {CONFIG['OPTIONS_PER_MENU'][0]}-{CONFIG['OPTIONS_PER_MENU'][1]}")
    print(f"  Origins per menu: {CONFIG['ORIGINS_PER_MENU'][0]}-{CONFIG['ORIGINS_PER_MENU'][1]}")
    print(f"  Items per order: {CONFIG['ITEMS_PER_ORDER'][0]}-{CONFIG['ITEMS_PER_ORDER'][1]}")
    print(f"  Reviews per store: {CONFIG['REVIEWS_PER_STORE'][0]}-{CONFIG['REVIEWS_PER_STORE'][1]}")
    print("=" * 60)
    print()

    try:
        if args.direct:
            if not PSYCOPG2_AVAILABLE:
                print("ERROR: psycopg2 is required for direct insertion.")
                print("Install it with: pip install psycopg2-binary")
                return
            orchestrator.connect_db()

            if args.truncate:
                orchestrator.truncate_all_tables()

        summary = orchestrator.generate_all()

        print()
        print("=" * 60)
        print("  Data generation completed!")
        print("=" * 60)
        print(f"Generated records:")
        print(f"  Users: {summary['users']} (OWNER: {summary['owners']})")
        print(f"  Categories: {summary['categories']}")
        print(f"  Stores: {summary['stores']}")
        print(f"  Menus: {summary['menus']}")
        print(f"  Menu Options: {summary['menu_options']}")
        print(f"  Orders: {summary['orders']}")
        print(f"  Reviews: {summary['reviews']}")

    finally:
        if args.direct:
            orchestrator.close_db()


if __name__ == "__main__":
    main()
