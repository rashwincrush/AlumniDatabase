# Supabase Snapshot & Docs Kit

This repository contains a reusable kit for creating daily snapshots and documentation for a Supabase project.

## Local Usage

1.  **Install Dependencies:** Ensure you have `make`, `docker`, `bash`, `psql`, `npx`, and `atlas` installed.
2.  **Environment Variables:** Copy `.env.example` to `.env` and fill in the required values.
3.  **Run Report:** Execute `make report` to generate all dumps, inventory files, and documentation.

### Required Secrets

The following environment variables are required, both for local execution and for the GitHub Actions workflow:

-   `SUPABASE_DB_URL`: The full connection string for your Supabase database.
-   `SUPABASE_DB_HOST`: The hostname of your database.
-   `SUPABASE_DB_NAME`: The name of your database (usually `postgres`).
-   `SUPABASE_DB_USER`: The user for your database (usually `postgres`).
-   `SUPABASE_DB_PASSWORD`: The password for your database user.
-   `SUPABASE_ACCESS_TOKEN`: Your Supabase personal access token.
-   `SB_PROJECT_REF`: The project reference ID for your Supabase project.
