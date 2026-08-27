# Growww Frappe Demos

White-labeled Frappe demo farm for Growww Tech. One bench, one stack, six demo
sites on `*.demo.growwwtech.com`, deployed via Coolify on the Hostinger VPS.

Based on [frappe_docker](https://github.com/frappe/frappe_docker) (layered
custom image + pwd.yml), pinned to **version-15**.

## Apps in the image

erpnext, payments, hrms, healthcare (Frappe Health), crm, helpdesk, lms,
insights, whitelabel (branding). See `apps.json`.

## Demo sites

| Site | Apps |
|---|---|
| erp.demo.growwwtech.com | erpnext + hrms |
| health.demo.growwwtech.com | erpnext + healthcare |
| crm.demo.growwwtech.com | crm |
| helpdesk.demo.growwwtech.com | helpdesk |
| lms.demo.growwwtech.com | lms |
| insights.demo.growwwtech.com | insights |

## Deploy (Coolify)

1. DNS: wildcard A record `*.demo.growwwtech.com` -> VPS IP.
2. Coolify -> project "Frappe Apps" -> new resource -> Docker Compose,
   point at this repo, compose file `compose.yml`.
3. Set env vars on the resource: `DB_PASSWORD` (generate strong).
4. Domains on the `frontend` service (port 8080): all six hostnames above,
   comma-separated. Let's Encrypt per-host HTTP challenge handles certs.
5. Deploy. First build compiles all frontend apps — expect 30-45 min.
6. Create sites (once):
   `docker exec -e DB_PASSWORD=... -e ADMIN_PASSWORD=... <backend> create-sites.sh`
7. Brand each site (whitelabel settings + logos), seed demo data, create
   `demo@growwwtech.com` users, then snapshot:
   `docker exec -e DB_PASSWORD=... <backend> reset-demos.sh take-golden`
8. Coolify Scheduled Task on `backend`, daily 02:00 IST:
   `reset-demos.sh` (env `DB_PASSWORD` is on the container already).

## Notes

- Multi-tenancy: `FRAPPE_SITE_NAME_HEADER: $host` on the frontend routes each
  hostname to its site. New demo site = `bench new-site`, add the hostname in
  Coolify domains — no new stack.
- If the on-VPS image build starves the box, build in GitHub Actions and push
  to GHCR instead; swap `build:` for the GHCR image in `compose.yml`.
- All apps GPL/AGPL: UI rebranding is fine; LICENSE files stay in the image.
- Demos have `disable_emails` + `disable_signup` set at site creation.
