#!/bin/bash
#
# First-init: create the demo role/database and seed sample data.

set -euo pipefail

# Role and database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE ROLE myuser WITH LOGIN PASSWORD 'myuserpassword';
    ALTER ROLE myuser CREATEDB;
    CREATE DATABASE myuserdb WITH OWNER myuser;
EOSQL

# Sample orders, owned by myuser so the demo role can read them
psql -v ON_ERROR_STOP=1 --username myuser --dbname myuserdb <<-EOSQL
    CREATE TABLE orders (
        id       SERIAL PRIMARY KEY,
        customer TEXT NOT NULL,
        amount   NUMERIC(10,2) NOT NULL,
        placed   TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    INSERT INTO orders (customer, amount) VALUES
        ('Acme Corp',        120.00),
        ('Globex',            75.50),
        ('Initech',          240.00);
EOSQL
