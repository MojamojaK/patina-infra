# infra/ — Terraform for the Cloudflare side of patina

# patina-infra — Terraform for the Cloudflare side of Patina

This is a **separate repo from the app** (`patina`) on purpose: this
repo's GitHub Actions hold an account-level Cloudflare API token
(Pages/D1/R2/Access edit) — meaningfully more powerful than anything the
app repo needs day to day. Keeping it isolated means the app repo's much
larger dependency surface (npm, pip packages accumulating over time)
never shares a blast radius with the credential that can reprovision the
whole account. Same least-privilege logic as HLD §13.6 / LLD-07 SEC-6,
applied at the repo boundary instead of only the workflow-permissions one.

## What this repo does

Provisions: DNS records on `mojamojak.work` (app subdomain + email auth
records), a Pages project (production branch `mainline`), a D1 database, an
R2 bucket, and Cloudflare Access — an owner-login application plus one
service-token-only application per scraper route. Matches HLD v0.7 §13 and
LLD-07.

## Prerequisites (you do these once, outside Terraform)

1. **Zone exists in Cloudflare** — done (mojamojak.work, propagating).
2. **Scoped API token** — dashboard → My Profile → API Tokens → Create
   Custom Token with: `Zone:DNS:Edit` (this zone only),
   `Account:Cloudflare Pages:Edit`, `Account:D1:Edit`, `Account:R2:Edit`,
   `Account:Access: Apps and Policies:Edit`, `Account:Access: Service
   Tokens:Edit`. This token is what Terraform authenticates as — it never
   goes in a file in this repo.
3. **Account ID** — dashboard right sidebar on any domain overview page.
4. **Cloudflare Zero Trust team name** — Zero Trust dashboard → onboarding
   screen, pick any team name (free tier, ≤50 users). Required before
   `cloudflare_zero_trust_access_application` can be created.
5. **GitHub repo secrets** (Settings → Secrets and variables → Actions):
   - `CLOUDFLARE_API_TOKEN` — from step 2
   - `CLOUDFLARE_ACCOUNT_ID` — from step 3
   - `OWNER_EMAIL` — the one address allowed through Access
6. **GitHub Environments** (Settings → Environments):
   - `infra-plan` — no protection rules
   - `infra-apply` — add yourself as a required reviewer. This is the gate:
     nothing applies to the Cloudflare account without a manual approval
     click on the Actions run.

## Running it

- Open a PR → `plan` job runs automatically, output visible in the Actions
  log (sensitive outputs are redacted by Terraform itself, since
  `outputs.tf` marks them `sensitive = true`).
- Merge to `mainline` → `apply` job queues, waits for your approval in the
  `infra-apply` environment, then runs.
- One-off changes: `workflow_dispatch` from the Actions tab.

You do not need Terraform installed locally, and you never need to paste
the API token anywhere but the one GitHub secret field.

## After the first apply

- **GitHub↔Pages connection**: the initial link between the Pages project
  and this GitHub repo (for branch deploys) is a click-through OAuth flow
  in the dashboard — there's no clean Terraform path for the first grant.
  Do this once: Pages project → Settings → Builds & deployments → connect
  to GitHub → select this repo.
- **Scraper credentials**: `terraform output -json scraper_service_token_client_id`
  and `..._client_secret` → paste into GHA secrets `CF_ACCESS_CLIENT_ID` /
  `CF_ACCESS_CLIENT_SECRET` (used by LLD-01's scraper, per LLD-07 §1).
  Pull these directly from `terraform output`, not from any log — the
  apply step's own log has them redacted.
- **D1 binding**: attach `cloudflare_d1_database.catalog`'s ID to the Pages
  project's D1 binding (`DB`) — currently a dashboard step; Pages-Functions
  D1 bindings aren't yet exposed as a stable field on
  `cloudflare_pages_project` as of provider 5.21. Revisit.
- **Resend DNS records**: `dns.tf`'s SPF/DMARC are placeholders; add the
  sending domain in Resend first, copy the exact TXT/DKIM values it gives
  you, then fill in the real records (a DKIM CNAME resource per key Resend
  issues — usually two).

## Known unknowns to verify at `terraform plan` time

- **`cloudflare_zero_trust_access_*` naming** — RESOLVED against provider
  v5.22 (what `~> 5.21` resolves to): the `zero_trust_` prefix is correct, and
  in v5 Access policies are standalone account-level resources referenced from
  an application's `policies` list, NOT attached via `application_id` (the v4
  model, which v5 rejects). `access.tf` reflects the v5 model.
- **Multi-path Access policies** — RESOLVED: v5's `destinations` list holds all
  scraper paths (the seven API routes + `/api/admin/backup`) in a single
  service-token-only Application; a more specific path match takes precedence
  over the owner app on the same hostname.
- **R2 lifecycle rules** (30-day snapshot expiry, backup retention per
  LLD-07 §3) aren't modeled here — not a stable field on `cloudflare_r2_bucket`
  as of 5.22. Apply via `wrangler r2 bucket lifecycle add` or the dashboard
  until it lands in the provider.
- **Remote state**: currently local `terraform.tfstate` (`.gitignore`
  already excludes it). The R2 backend is commented out in `versions.tf`
  because Terraform can't create the bucket it then needs to read from —
  bootstrap order is: apply once with local state to create the R2
  bucket, then migrate state (`terraform init -migrate-state`) once the
  backend block is uncommented.
