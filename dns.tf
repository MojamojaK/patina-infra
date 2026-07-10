# ─────────────────────────────────────────────────────────────────────────
# Zone
# ─────────────────────────────────────────────────────────────────────────
# The zone itself was created via "Add a site" in the dashboard (Terraform
# can't add a zone whose nameservers aren't pointed at Cloudflare yet — a
# genuine chicken-and-egg only the dashboard resolves). We import it as
# data so everything else can reference its ID.

data "cloudflare_zone" "root" {
  filter = {
    name = var.root_domain
  }
}

# ─────────────────────────────────────────────────────────────────────────
# DNS: point the app subdomain at Cloudflare Pages
# ─────────────────────────────────────────────────────────────────────────
# Pages projects get a `<project>.pages.dev` domain automatically; a CNAME
# here maps the friendly hostname to it. `proxied = true` keeps it behind
# Cloudflare (required for Access to intercept requests).

resource "cloudflare_dns_record" "app" {
  zone_id = data.cloudflare_zone.root.id
  name    = var.app_subdomain
  type    = "CNAME"
  content = "${cloudflare_pages_project.catalog.name}.pages.dev"
  proxied = true
  ttl     = 1 # "automatic" when proxied
  comment = "patina web app"
}

# Email auth for Resend (HLD §13.8 / LLD-07 §5). Values are placeholders —
# Resend's domain-verification screen gives you the exact records to paste
# in once you add the sending domain there; replace before applying.

resource "cloudflare_dns_record" "spf" {
  zone_id = data.cloudflare_zone.root.id
  name    = var.root_domain
  type    = "TXT"
  content = "v=spf1 include:_spf.resend.com ~all"
  ttl     = 3600
  comment = "SPF for Resend"
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = data.cloudflare_zone.root.id
  name    = "_dmarc.${var.root_domain}"
  type    = "TXT"
  content = "v=DMARC1; p=quarantine; rua=mailto:${var.owner_email}"
  ttl     = 3600
  comment = "DMARC policy"
}

# DKIM CNAME(s): Resend issues these per-domain at verification time
# (typically two, e.g. resend._domainkey / resend2._domainkey). Add as a
# resource per record once Resend shows them — placeholder left out here
# deliberately rather than guessing values that would silently fail.
