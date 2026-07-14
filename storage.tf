# ─────────────────────────────────────────────────────────────────────────
# Pages project
# ─────────────────────────────────────────────────────────────────────────
# Production branch deploys are triggered by the GitHub integration
# (connected once, manually, in the dashboard — Terraform can model the
# project but the initial GitHub OAuth grant is a click-through flow with
# no clean API/Terraform path). Custom domain attached below.

resource "cloudflare_pages_project" "catalog" {
  account_id        = var.cloudflare_account_id
  name              = "patina-${var.environment}"
  production_branch = "mainline" # the app repo (patina) deploys from mainline, not main
}

resource "cloudflare_pages_domain" "catalog" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.catalog.name
  name         = "${var.app_subdomain}.${var.root_domain}" # v5: `name`, not `domain`
}

# ─────────────────────────────────────────────────────────────────────────
# D1 — system of record (HLD §11)
# ─────────────────────────────────────────────────────────────────────────

# D1 #2 — item gallery images only (2026-07-14): the main database hit the
# free tier's size cap; galleries (770k rows) are the bulk and have no SQL
# joins that can't be done app-side, so they live in their own database.
resource "cloudflare_d1_database" "images" {
  account_id = var.cloudflare_account_id
  name       = "patina-images-${var.environment}"
  read_replication = {
    mode = "disabled"
  }
}

resource "cloudflare_d1_database" "catalog" {
  account_id = var.cloudflare_account_id
  name       = "patina-${var.environment}"
  # Set explicitly (single-user catalog needs no global read replicas). Also
  # required after import: the provider otherwise sends read_replication=null on
  # update, which the API rejects (400 "Expected object, received null").
  read_replication = {
    mode = "disabled"
  }
}

# ─────────────────────────────────────────────────────────────────────────
# R2 — images, HTML snapshots, backups (HLD §13.7)
# ─────────────────────────────────────────────────────────────────────────
# One bucket, prefix-separated (snapshots/, images/, backups/) rather than
# three buckets — simpler lifecycle rule management, and nothing here needs
# separate access policies per prefix (all access is mediated by the
# authenticated /api/media Function; the bucket itself has no public
# access either way, per HLD §13.7).

# HTML detail-page cache (owner request 2026-07-14): gallery backfills and the
# detail-rescue pass were re-fetching the same detail pages every run. Two
# cache layers: local disk on the scraping machine, and this bucket (shared
# across machines/runs). "Cleared eventually" = the 14-day lifecycle expiry,
# applied via `wrangler r2 bucket lifecycle` (see the note below — R2
# lifecycle isn't a stable Terraform resource yet on provider 5.x).
resource "cloudflare_r2_bucket" "htmlcache" {
  account_id = var.cloudflare_account_id
  name       = "patina-htmlcache-${var.environment}"
  location   = "apac"
}

resource "cloudflare_r2_bucket" "store" {
  account_id = var.cloudflare_account_id
  name       = "patina-store-${var.environment}"
  location   = "apac" # closest to JP-hosted target sites' irrelevant-for-us latency; owner is in JP
}

# Lifecycle rules (30d snapshot expiry, backup retention) are not yet a
# stable Terraform resource for R2 as of provider 5.21 — apply via
# `wrangler r2 bucket lifecycle` or the dashboard until cloudflare_r2_bucket
# exposes `lifecycle_rules` as stable. Tracked as an open item (see README).
