terraform {
  required_version = ">= 1.7.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.21"
    }
  }

  # Remote state. Using Cloudflare R2 (S3-compatible) as the backend keeps
  # everything in one provider ecosystem and costs nothing at this scale.
  # Create the bucket manually ONCE (chicken-and-egg: Terraform can't create
  # its own backend), then uncomment. Until then, state is local
  # (terraform.tfstate) — gitignored, single operator, acceptable for now.
  #
  # backend "s3" {
  #   bucket                      = "patina-tfstate"
  #   key                         = "prod/terraform.tfstate"
  #   region                      = "auto"
  #   endpoints                   = { s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com" }
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   use_path_style              = true
  # }
}

provider "cloudflare" {
  # api_token read from CLOUDFLARE_API_TOKEN env var — never set here.
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (dashboard right sidebar, or `curl -H \"Authorization: Bearer $CLOUDFLARE_API_TOKEN\" https://api.cloudflare.com/client/v4/accounts`)"
  type        = string
}

variable "root_domain" {
  description = "The zone/domain, as added to Cloudflare"
  type        = string
  default     = "mojamojak.work"
}

variable "app_subdomain" {
  description = "Subdomain the catalog lives on"
  type        = string
  default     = "catalog"
}

variable "owner_email" {
  description = "The single allowed identity for the Access application"
  type        = string
}

variable "access_session_duration" {
  description = "How long an Access session lasts before re-auth (HLD OQ-8)"
  type        = string
  default     = "168h" # 7 days
}

variable "environment" {
  description = "Names all resources: patina-<env> / patina-store-<env>. MUST match the app's wrangler.toml database_name / bucket_name (currently 'production')."
  type        = string
  default     = "production"
}
