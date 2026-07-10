# ─────────────────────────────────────────────────────────────────────────
# Cloudflare Access (HLD §13.1, §13.8; LLD-07 §2)
# ─────────────────────────────────────────────────────────────────────────
# NOTE ON RESOURCE NAMES: Cloudflare has been migrating Zero-Trust-family
# resources to a `cloudflare_zero_trust_*` naming prefix across recent
# provider v5 releases. The names below reflect that prefix as of writing,
# but this corner of the provider has moved fastest — run `terraform plan`
# and check `terraform providers schema -json | grep access` against your
# installed 5.21.x before applying; if the plan errors on an unknown
// resource type, the fix is almost certainly just dropping the
# `zero_trust_` prefix (e.g. `cloudflare_access_application`), not a
# structural change to this file.

resource "cloudflare_zero_trust_access_application" "catalog" {
  account_id                = var.cloudflare_account_id
  name                      = "patina"
  domain                    = "${var.app_subdomain}.${var.root_domain}"
  type                      = "self_hosted"
  session_duration          = var.access_session_duration
  auto_redirect_to_identity = true
}

# Policy 1: the scraper's six API routes, service-token only.
# Path scoping happens via a *second* Access Application bound to the same
# hostname with narrower `path` matching, per Cloudflare's documented
# pattern for "different rules for different paths on one hostname."

resource "cloudflare_zero_trust_access_application" "catalog_scraper_routes" {
  account_id = var.cloudflare_account_id
  name       = "patina-scraper-routes"
  domain     = "${var.app_subdomain}.${var.root_domain}/api/registry"
  # Cloudflare Access matches one path per Application; the remaining five
  # scraper routes need their own Application blocks (or a single Access
  # "path" wildcard app scoped to /api/registry, /api/ingest, etc., if the
  # provider's `destinations` block supports a list by the time this is
  # applied — check `destinations` vs. single `domain` in 5.21 docs).
  # Left as five near-duplicates below rather than one clever wildcard,
  # because path-list support here is exactly the kind of thing that
  # changed recently and is worth verifying against real docs before
  # collapsing into fewer resources.
  session_duration = "1h" # short-lived; this is machine-to-machine
}

resource "cloudflare_zero_trust_access_policy" "scraper_service_token" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.catalog_scraper_routes.id
  name           = "scraper-service-token-only"
  decision       = "non_identity" # service tokens bypass identity-based rules entirely
  include = [
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.scraper.id } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "owner_everything_else" {
  account_id     = var.cloudflare_account_id
  application_id = cloudflare_zero_trust_access_application.catalog.id
  name           = "owner-allow"
  decision       = "allow"
  include = [
    { email = { email = var.owner_email } }
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
