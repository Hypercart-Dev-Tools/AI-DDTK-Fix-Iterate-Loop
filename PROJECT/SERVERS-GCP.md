---
title: "GCP Server Infrastructure"
status: inbox
priority: P3
created: 2026-04-01
updated: 2026-04-01
author: noelsaw1
goal: 
---

# GCP Server Infrastructure

## Project: `wp-db-toolkit`

---

## VM: `binoid-rag-server`

| Field              | Value                  |
|--------------------|------------------------|
| Zone               | `us-central1-a`        |
| Internal IP        | `10.128.0.2`           |
| External IP        | `35.239.93.57`         |
| Subnet             | `default` (`us-central1`) |
| Primary use        | RAG server / Gemini API calls via Vertex AI |

---

## Networking Fix — 2026-04-01

### Problem
`privateIpGoogleAccess` was `False` on the `default` subnet in `us-central1`.

With Private Google Access disabled, outbound traffic to `*.googleapis.com`
(including Vertex AI / Gemini) routes through the public internet via the
VM's external IP — incurring internet egress charges (~$0.08–0.12/GB).

### Fix Applied
```bash
gcloud compute networks subnets update default \
  --region=us-central1 \
  --enable-private-ip-google-access \
  --project=wp-db-toolkit
```

**Result:** `privateIpGoogleAccess` → `True` ✅

### Effect
Calls from `binoid-rag-server` to `us-central1-aiplatform.googleapis.com`
now route via Google's internal backbone. Same-region Vertex AI / Gemini
traffic is **free** (no egress charges).

### Optional Hardening (not yet applied)
- **Remove external IP** — forces all traffic internal; requires Cloud NAT
  if the VM needs outbound internet for other purposes (apt, external APIs).
- **Cloud NAT** — attach to the `default` subnet if external internet access
  is still needed after removing the public IP.

---

## Subnet: `default`

| Field                    | Value           |
|--------------------------|-----------------|
| Region                   | `us-central1`   |
| CIDR                     | `10.128.0.0/20` |
| `privateIpGoogleAccess`  | `True` ✅ (fixed 2026-04-01) |

