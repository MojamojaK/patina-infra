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

resource "cloudflare_d1_database" "catalog" {
  account_id = var.cloudflare_account_id
  name       = "patina-${var.environment}"
}

# ─────────────────────────────────────────────────────────────────────────
# R2 — images, HTML snapshots, backups (HLD §13.7)
# ─────────────────────────────────────────────────────────────────────────
# One bucket, prefix-separated (snapshots/, images/, backups/) rather than
# three buckets — simpler lifecycle rule management, and nothing here needs
# separate access policies per prefix (all access is mediated by the
# authenticated /api/media Function; the bucket itself has no public
# access either way, per HLD §13.7).

resource "cloudflare_r2_bucket" "store" {
  account_id = var.cloudflare_account_id
  name       = "patina-store-${var.environment}"
  location   = "apac" # closest to JP-hosted target sites' irrelevant-for-us latency; owner is in JP
}

# Lifecycle rules (30d snapshot expiry, backup retention) are not yet a
# stable Terraform resource for R2 as of provider 5.21 — apply via
# `wrangler r2 bucket lifecycle` or the dashboard until cloudflare_r2_bucket
# exposes `lifecycle_rules` as stable. Tracked as an open item (see README).
