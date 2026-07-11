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

# The scraper's authenticated routes, service-token only. Cloudflare Access
# matches one path per Application, so we create one Application per scraper
# route (for_each over the path list) rather than hand-duplicating blocks. The
# token can therefore reach EXACTLY these paths — everything else on the
# hostname falls through to the owner-only `catalog` app (LLD-07 §2). This is
# the seven scraper routes plus the admin backup route (LLD-07 §4).
#
# FUTURE (verify against provider 5.21 at plan time): if the installed provider
# exposes a `destinations` list on the Application, these collapse into ONE app
# with a path list. Kept as for_each near-duplicates until that's confirmed,
# per this repo's "known unknowns" discipline.
locals {
  scraper_paths = [
    "/api/registry",
    "/api/ingest",
    "/api/shadow",
    "/api/recipes",
    "/api/events",
    "/api/playbook",
    "/api/snapshot",
    "/api/admin/backup",
  ]
}

resource "cloudflare_zero_trust_access_application" "scraper" {
  for_each = toset(local.scraper_paths)

  account_id                = var.cloudflare_account_id
  name                      = "patina-scraper ${each.value}"
  domain                    = "${var.app_subdomain}.${var.root_domain}${each.value}"
  type                      = "self_hosted"
  session_duration          = "1h"  # short-lived; machine-to-machine
  auto_redirect_to_identity = false # no human login flow for these routes
}

resource "cloudflare_zero_trust_access_policy" "scraper_service_token" {
  for_each = cloudflare_zero_trust_access_application.scraper

  account_id     = var.cloudflare_account_id
  application_id = each.value.id
  name           = "scraper-service-token-only ${each.key}"
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
