terraform {
  required_version = ">= 1.7.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.21"
    }
  }

  # Remote state on Cloudflare R2 (S3-compatible). PARTIAL config: the
  # account-specific `endpoints.s3` URL is injected at `terraform init` via
  # `-backend-config` from a generated backend.hcl (see apply.yml), so the
  # account ID never lands in source. Auth is AWS_ACCESS_KEY_ID /
  # AWS_SECRET_ACCESS_KEY (an R2 S3 API token), also provided by the workflow.
  #
  # Prerequisite (one-time, chicken-and-egg — Terraform can't create its own
  # backend): create the `patina-tfstate` R2 bucket in the dashboard first.
  backend "s3" {
    bucket = "patina-tfstate"
    key    = "prod/terraform.tfstate"
    region = "auto"
    # endpoints = { s3 = "https://<ACCOUNT_ID>.r2.cloudflarestorage.com" }  ← via -backend-config
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
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
