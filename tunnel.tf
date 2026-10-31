# ─────────────────────────────────────────────────────────────────────────
# Laptop hosting via Cloudflare Tunnel (owner decision 2026-10-31)
# ─────────────────────────────────────────────────────────────────────────
# The app can run on the owner's Mac (patina repo: scripts/serve-local.sh,
# the same Pages app under `wrangler pages dev` on 127.0.0.1:8788, with local
# D1/R2 files). This tunnel carries the app's hostname to it. It is a
# two-way door: Pages, D1 and R2 stay provisioned, and `app_origin` alone
# decides where `patina.<root>` points (dns.tf). Access is unchanged either
# way, because Access applies at Cloudflare's edge, not at the origin.
#
# The tunnel is remotely managed (config_src = "cloudflare"): the laptop
# runs `cloudflared tunnel run --token <tunnel_token>` and holds ONLY that
# token (macOS Keychain), never an account-level credential.

variable "app_origin" {
  description = "Where the app hostname points: \"pages\" (Cloudflare Pages) or \"tunnel\" (the owner's laptop)"
  type        = string
  default     = "pages"
  validation {
    condition     = contains(["pages", "tunnel"], var.app_origin)
    error_message = "app_origin must be \"pages\" or \"tunnel\"."
  }
}

locals {
  local_test_host = "${var.app_subdomain}-local.${var.root_domain}"
  tunnel_target   = "${cloudflare_zero_trust_tunnel_cloudflared.laptop.id}.cfargotunnel.com"
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "laptop" {
  account_id = var.cloudflare_account_id
  name       = "patina-laptop"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "laptop" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.laptop.id
  config = {
    ingress = [
      # The real hostname only reaches the laptop once app_origin = "tunnel"
      # points its DNS here; listing it now makes the switch DNS-only.
      { hostname = "${var.app_subdomain}.${var.root_domain}", service = "http://127.0.0.1:8788" },
      { hostname = local.local_test_host, service = "http://127.0.0.1:8788" },
      { service = "http_status:404" },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "laptop" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.laptop.id
}

# Test hostname: the laptop copy, reachable before (and independent of) the
# switch, so it can be checked end to end without touching the live site.
resource "cloudflare_dns_record" "app_local" {
  zone_id = data.cloudflare_zone.root.id
  name    = "${var.app_subdomain}-local"
  type    = "CNAME"
  content = local.tunnel_target
  proxied = true
  ttl     = 1
  comment = "patina on the owner's laptop (test hostname)"
}

# One Access app for the whole test hostname, owner OR scraper service token.
# Simpler than the per-path apps on the real hostname; the origin still
# checks the scraper bearer on every scraper route.
resource "cloudflare_zero_trust_access_application" "catalog_local" {
  account_id                = var.cloudflare_account_id
  name                      = "patina-local"
  domain                    = local.local_test_host
  type                      = "self_hosted"
  session_duration          = var.access_session_duration
  # true needs allowed_idps with exactly one IdP (API error on create); the
  # login page just shows the IdP choice instead of redirecting.
  auto_redirect_to_identity = false

  policies = [
    { id = cloudflare_zero_trust_access_policy.owner.id, precedence = 1 },
    { id = cloudflare_zero_trust_access_policy.scraper_service_token.id, precedence = 2 },
  ]
}

output "tunnel_token" {
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.laptop.token
  sensitive   = true
  description = "For the laptop's Keychain (patina.TUNNEL_TOKEN). Never print it; pipe it straight into `security add-generic-password`."
}
