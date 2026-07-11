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

# Email auth for Resend (HLD §13.8 / LLD-07 §5). Resend sends via AWS SES
# under the hood, so the SPF/MX records it issues point at amazonses.com and
# live on a dedicated `send.` subdomain (keeps them from clobbering any MX/SPF
# already on the root domain). Values below are exactly what Resend's
# domain-verification screen showed at setup time — not guesses.

resource "cloudflare_dns_record" "resend_mx" {
  zone_id  = data.cloudflare_zone.root.id
  name     = "send.${var.root_domain}"
  type     = "MX"
  content  = "feedback-smtp.ap-northeast-1.amazonses.com"
  priority = 10
  ttl      = 3600
  comment  = "Resend (AWS SES) bounce/complaint handling"
}

resource "cloudflare_dns_record" "spf" {
  zone_id = data.cloudflare_zone.root.id
  name    = "send.${var.root_domain}"
  type    = "TXT"
  content = "v=spf1 include:amazonses.com ~all"
  ttl     = 3600
  comment = "SPF for Resend"
}

resource "cloudflare_dns_record" "dkim" {
  zone_id = data.cloudflare_zone.root.id
  name    = "resend._domainkey.${var.root_domain}"
  type    = "TXT"
  content = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCfBM0gl9mQBGMJxT+3eN5Z2jKLQ9gXVaJsqV4YhW6fSOZEBeACHTboylg/snAHGxHiFzHri0ajo+Ouq7pKgy/7stWR02B8GsIuB/HTzPSZEngbWJXJgep4HSkfPJIRapXFwe7Fmv3J6N4X5621ZwwEE1xCLlvL/HkXTu4lUY68NQIDAQAB"
  ttl     = 3600
  comment = "DKIM for Resend"
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = data.cloudflare_zone.root.id
  name    = "_dmarc.${var.root_domain}"
  type    = "TXT"
  content = "v=DMARC1; p=quarantine; rua=mailto:${var.owner_email}"
  ttl     = 3600
  comment = "DMARC policy"
}
