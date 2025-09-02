# Supabase Snapshot & Inventory

This repository contains a GitHub Actions workflow to automatically take a daily snapshot of a Supabase database schema and generate a detailed inventory of its objects.

## How it Works

The workflow runs on a daily schedule, on push to `main`, or on manual trigger. It performs the following steps:

1.  **Sets up Supabase CLI**: Installs and configures the Supabase CLI.
2.  **Builds DB URL**: Securely constructs the database connection URL from GitHub secrets.
3.  **Smoke Test**: Runs a quick connectivity test against the database.
4.  **Generate Report**: Runs `make report` which executes two main tasks:
    *   `supabase db dump` to save the database schema to `infra/dumps/schema.sql`.
    *   `scripts/inventory.sh` to generate several CSV files in `infra/inventory/` detailing tables, policies, functions, and more.
5.  **Commit Changes**: Automatically commits the updated schema dump and inventory files back to the `main` branch.

## Setup

1.  **Fork this repository.**

2.  **Add GitHub Secrets**: In your repository settings, go to `Settings` > `Secrets and variables` > `Actions` and add the following repository secrets:

    *   `SUPABASE_DB_HOST`: The host of your Supabase database.
    *   `SUPABASE_DB_NAME`: The name of your database (usually `postgres`).
    *   `SUPABASE_DB_USER`: The user for your database (usually `postgres`).
    *   `SUPABASE_DB_PASSWORD`: The password for your database. The workflow will automatically URL-encode it.
    *   `SB_PROJECT_REF`: Your Supabase project reference.
    *   `SUPABASE_ACCESS_TOKEN`: (Optional) Your Supabase personal access token, required if you want to download function bodies using `make functions`.

3.  **Enable Workflows**: Ensure GitHub Actions are enabled for your repository.

## Usage

The workflow will run automatically. You can also trigger it manually from the Actions tab in your repository.

### Local Usage

You can run the snapshot and inventory process locally.

1.  **Install Dependencies**:
    *   [Supabase CLI](https://supabase.com/docs/guides/cli)
    *   `postgresql-client` (for `psql`)
    *   `jq`

2.  **Set Environment Variables**: Create a `.env` file in the root of the project with the same secrets as above, or export them in your shell.

3.  **Run Make commands**:
    *   `make report`: Generate schema dump and inventory.
    *   `make dump-schema`: Only dump the schema.
    *   `make inventory`: Only generate the inventory.
    *   `make schemaspy`: (Optional, requires Docker) Generate a SchemaSpy report in `infra/docs/schemaspy`.
    *   `make erd`: (Optional, requires [Atlas](https://atlasgo.io/)) Generate an ERD diagram in `infra/docs/erd.mmd`.
    *   `make functions`: (Optional) Download function bodies into `supabase/functions`.

## Repository Structure

*   `.github/workflows/supabase-snapshot.yml`: The main GitHub Actions workflow.
*   `Makefile`: Defines the commands for generating snapshots and reports.
*   `scripts/inventory.sh`: The script that generates the CSV inventory.
*   `infra/dumps/`: Stores the database schema dumps.
*   `infra/inventory/`: Stores the generated CSV inventory files.
*   `infra/docs/`: (Optional) For generated documentation like SchemaSpy reports and ERDs.
