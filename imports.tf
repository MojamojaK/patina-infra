# ─────────────────────────────────────────────────────────────────────────
# One-time: adopt resources orphaned by the pre-remote-state apply
# ─────────────────────────────────────────────────────────────────────────
# An earlier apply ran with ephemeral local state (discarded by CI) and created
# six resources before failing on the not-yet-enabled R2/Access. They exist in
# the account but aren't tracked. These `import` blocks let the FIRST
# remote-state apply ADOPT them instead of erroring on "already exists" — no
# manual dashboard deletion needed.
#
# IDs are from the failed apply's log. Import-ID formats verified against the
# cloudflare provider v5.22 docs:
#   d1_database   <account_id>/<database_id>
#   pages_project <account_id>/<project_name>
#   pages_domain  <account_id>/<project_name>/<domain_name>
#   dns_record    <zone_id>/<dns_record_id>
#
# DELETE THIS FILE after the first successful apply (a subsequent commit) — the
# blocks are one-time and the resources will be in state thereafter.
# NOTE: leave the six resources in place in the dashboard; do NOT delete them,
# or these imports will fail. If any were already deleted, remove its block here
# and the apply will recreate it.

import {
  to = cloudflare_d1_database.catalog
  id = "${var.cloudflare_account_id}/e3443ece-ed38-4e1b-b898-bccd5a42cf16"
}

import {
  to = cloudflare_pages_project.catalog
  id = "${var.cloudflare_account_id}/patina-production"
}

import {
  to = cloudflare_pages_domain.catalog
  id = "${var.cloudflare_account_id}/patina-production/catalog.mojamojak.work"
}

import {
  to = cloudflare_dns_record.app
  id = "${data.cloudflare_zone.root.id}/dbb0ab0f6b92b5c6370e988b1e1d8869"
}

import {
  to = cloudflare_dns_record.spf
  id = "${data.cloudflare_zone.root.id}/f25a63267cfaca8866269cbcfff129a5"
}

import {
  to = cloudflare_dns_record.dmarc
  id = "${data.cloudflare_zone.root.id}/62e09b205483d7ebaa7d912a56c55b31"
}
