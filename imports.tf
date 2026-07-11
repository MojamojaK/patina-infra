# One-off adoption of a resource that already existed outside Terraform's
# state. `resend_mx` (send.mojamojak.work MX) was created directly via the
# Cloudflare API — likely by Resend's one-click "connect to Cloudflare" DNS
# setup — before Terraform tried to create it, causing a 400 "identical
# record already exists". This block imports it into state instead of
# creating a duplicate. Delete this file once the apply that adopts it
# succeeds (same pattern used for the original 6-resource orphan cleanup).

import {
  to = cloudflare_dns_record.resend_mx
  id = "50b59954622717baebfe6095ff02297c/fb469b6a629da2d30e1ffa6be909d367"
}
