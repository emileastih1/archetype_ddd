#!/bin/bash
# Create required schemas in each database after databases are created.
# This ensures Liquibase can run migrations on first boot.

set -e
set -u

echo "Creating schema 'documentcontent' in doc_management_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "doc_management_db" \
  -c "CREATE SCHEMA IF NOT EXISTS documentcontent;"

echo "Creating schemas 'vectorcontent' in dms_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "dms_db" \
  -c "CREATE SCHEMA IF NOT EXISTS vectorcontent;"

echo "Enabling pgvector extension in dms_db..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "dms_db" \
  -c "CREATE EXTENSION IF NOT EXISTS vector;"

echo "Schema initialisation complete."
