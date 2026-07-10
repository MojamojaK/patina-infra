output "app_url" {
  value = "https://${var.app_subdomain}.${var.root_domain}"
}

output "d1_database_id" {
  value       = cloudflare_d1_database.catalog.id
  description = "Bind this in the Pages project's D1 binding (dashboard, or a future cloudflare_pages_project binding block once that resource stabilizes for D1)."
}

output "r2_bucket_name" {
  value = cloudflare_r2_bucket.store.name
}

output "scraper_service_token_client_id" {
  value       = cloudflare_zero_trust_access_service_token.scraper.client_id
  sensitive   = true
  description = "Goes into the GHA secret CF_ACCESS_CLIENT_ID. Never print with `terraform output` without -json | jq, and never paste into chat."
}

output "scraper_service_token_client_secret" {
  value       = cloudflare_zero_trust_access_service_token.scraper.client_secret
  sensitive   = true
  description = "Goes into the GHA secret CF_ACCESS_CLIENT_SECRET. Same handling as above."
}
