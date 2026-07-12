# ─────────────────────────────────────────────────────────────────────────
# Cloudflare Access (HLD §13.1, §13.8; LLD-07 §2)
# ─────────────────────────────────────────────────────────────────────────
# Verified against cloudflare provider v5.22 (the version `~> 5.21` resolves
# to): the `cloudflare_zero_trust_*` resource names are correct, and in v5
# Access policies are standalone account-level resources referenced from an
# application's `policies` list — they are NOT attached via `application_id`
# (that was the v4 model and is rejected by v5).

locals {
  # Exactly the routes the scraper service token may reach — the seven scraper
  # API routes plus the admin backup route (LLD-07 §2, §4), plus the new
  # scraper-only /api/notifications (idempotency reservation for keyword
  # alerts, LLD-06 §2). Everything else on the hostname falls through to the
  # owner-only `catalog` app.
  #
  # /api/sites, /api/keywords, and /api/events are NOT here: all are also
  # used by the owner-facing webapp (site cards / onboarding; keyword-watch
  # CRUD; the site activity panel reading escalation events), so they get
  # dual-policy (owner OR scraper) applications below instead of the
  # scraper-only for_each — a scraper-only app on those paths would lock
  # the webapp itself out.
  scraper_paths = [
    "/api/registry",
    "/api/ingest",
    "/api/gallery",
    "/api/shadow",
    "/api/recipes",
    "/api/playbook",
    "/api/snapshot",
    "/api/admin/backup",
    "/api/notifications",
  ]

  # Routes both the owner (webapp UI) and the scraper service token must reach.
  dual_paths = ["/api/sites", "/api/keywords", "/api/events"]
}

# ── Policies (standalone, account-level) ──────────────────────────────────────

resource "cloudflare_zero_trust_access_policy" "owner" {
  account_id = var.cloudflare_account_id
  name       = "owner-allow"
  decision   = "allow"
  include = [
    { email = { email = var.owner_email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "scraper_service_token" {
  account_id = var.cloudflare_account_id
  name       = "scraper-service-token-only"
  decision   = "non_identity" # service tokens bypass identity-based rules entirely
  include = [
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.scraper.id } }
  ]
}

# ── Applications ──────────────────────────────────────────────────────────────

# The whole hostname: owner login only.
resource "cloudflare_zero_trust_access_application" "catalog" {
  account_id                = var.cloudflare_account_id
  name                      = "patina"
  domain                    = "${var.app_subdomain}.${var.root_domain}"
  type                      = "self_hosted"
  session_duration          = var.access_session_duration
  auto_redirect_to_identity = true

  policies = [
    { id = cloudflare_zero_trust_access_policy.owner.id, precedence = 1 }
  ]
}

# One Access application per scraper route, service-token only. Folding all
# paths into a single app via `destinations` hit Cloudflare's per-app
# destination cap ("too many destinations for one app"), so we go one-path-per-
# app via for_each — the per-path model the repo originally anticipated. Each
# references the shared service-token policy; a more specific path match takes
# precedence over the owner app on the same hostname.
resource "cloudflare_zero_trust_access_application" "scraper" {
  for_each = toset(local.scraper_paths)

  account_id                = var.cloudflare_account_id
  name                      = "patina-scraper ${each.value}"
  domain                    = "${var.app_subdomain}.${var.root_domain}${each.value}"
  type                      = "self_hosted"
  session_duration          = "1h"  # short-lived; machine-to-machine
  auto_redirect_to_identity = false # no human login flow for these routes

  policies = [
    { id = cloudflare_zero_trust_access_policy.scraper_service_token.id, precedence = 1 }
  ]
}

# Dual-policy apps: reachable by either the owner (email) or the scraper
# (service token) — both policies are 'allow'-type (one identity, one
# non_identity), and Access OR's multiple allow policies on one application, so
# either credential gets through. /api/sites (site cards + onboarding UI, and
# the escalation ladder's PATCH) and /api/keywords (keyword-watch CRUD UI, and
# the nightly job's keyword fetch) both need this — a scraper-only app here
# would lock the webapp itself out.
resource "cloudflare_zero_trust_access_application" "dual" {
  for_each = toset(local.dual_paths)

  account_id                = var.cloudflare_account_id
  name                      = "patina-dual ${each.value}"
  domain                    = "${var.app_subdomain}.${var.root_domain}${each.value}"
  type                      = "self_hosted"
  session_duration          = var.access_session_duration
  auto_redirect_to_identity = false # scraper hits this path too; no forced human login

  policies = [
    { id = cloudflare_zero_trust_access_policy.owner.id, precedence = 1 },
    { id = cloudflare_zero_trust_access_policy.scraper_service_token.id, precedence = 2 },
  ]
}

resource "cloudflare_zero_trust_access_service_token" "scraper" {
  account_id = var.cloudflare_account_id
  name       = "aggscraper-gha"
  duration   = "8760h" # 1 year; rotation runbook (LLD-07 §6) covers renewal
}

# The service token's client_id / client_secret are only ever readable from
# Terraform's state and outputs — never printed to a log, never pasted into
# chat. See outputs.tf: both are marked `sensitive = true`.
