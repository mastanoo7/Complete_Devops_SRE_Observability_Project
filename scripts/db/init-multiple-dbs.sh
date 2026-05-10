#!/bin/bash
# ============================================================
# Database Initialization Script
# Creates multiple PostgreSQL databases for local development
# Used by docker-compose postgres container
# ============================================================

set -e

# Function to create database if it doesn't exist
create_database() {
    local database=$1
    echo "Creating database: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        SELECT 'CREATE DATABASE $database'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

# Create all service databases
DATABASES=(
    "auth_db"
    "product_db"
    "order_db"
    "payment_db"
    "inventory_db"
)

for db in "${DATABASES[@]}"; do
    create_database "$db"
done

echo "✅ All databases created successfully"

# Create initial schemas
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "auth_db" <<-EOSQL
    CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        provider VARCHAR(50) DEFAULT 'local',
        provider_id VARCHAR(255),
        first_name VARCHAR(100),
        last_name VARCHAR(100),
        is_active BOOLEAN DEFAULT true,
        is_verified BOOLEAN DEFAULT false,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS refresh_tokens (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        token_hash VARCHAR(255) NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "product_db" <<-EOSQL
    CREATE TABLE IF NOT EXISTS categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(255) NOT NULL,
        slug VARCHAR(255) UNIQUE NOT NULL,
        parent_id UUID REFERENCES categories(id),
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS products (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(500) NOT NULL,
        slug VARCHAR(500) UNIQUE NOT NULL,
        description TEXT,
        price DECIMAL(10,2) NOT NULL,
        category_id UUID REFERENCES categories(id),
        sku VARCHAR(100) UNIQUE,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
    CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug);
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "order_db" <<-EOSQL
    CREATE TYPE order_status AS ENUM (
        'pending', 'confirmed', 'processing',
        'shipped', 'delivered', 'cancelled', 'refunded'
    );

    CREATE TABLE IF NOT EXISTS orders (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID NOT NULL,
        status order_status DEFAULT 'pending',
        total_amount DECIMAL(10,2) NOT NULL,
        currency VARCHAR(3) DEFAULT 'USD',
        shipping_address JSONB,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS order_items (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
        product_id UUID NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price DECIMAL(10,2) NOT NULL,
        total_price DECIMAL(10,2) NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
    CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "payment_db" <<-EOSQL
    CREATE TYPE payment_status AS ENUM (
        'pending', 'authorized', 'captured',
        'failed', 'refunded', 'cancelled'
    );

    CREATE TABLE IF NOT EXISTS payments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        order_id UUID NOT NULL,
        user_id UUID NOT NULL,
        amount DECIMAL(10,2) NOT NULL,
        currency VARCHAR(3) DEFAULT 'USD',
        status payment_status DEFAULT 'pending',
        provider VARCHAR(50) DEFAULT 'stripe',
        provider_payment_id VARCHAR(255),
        provider_charge_id VARCHAR(255),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
    CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "inventory_db" <<-EOSQL
    CREATE TABLE IF NOT EXISTS inventory (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        product_id UUID UNIQUE NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        reserved_quantity INTEGER NOT NULL DEFAULT 0,
        warehouse_location VARCHAR(100),
        updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS reservations (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        product_id UUID NOT NULL,
        order_id UUID NOT NULL,
        quantity INTEGER NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX IF NOT EXISTS idx_inventory_product_id ON inventory(product_id);
    CREATE INDEX IF NOT EXISTS idx_reservations_order_id ON reservations(order_id);
EOSQL

echo "✅ All schemas initialized successfully"
