#!/bin/bash
# Idempotent demo setup, run automatically as Coolify post-deployment command.
# Per site: complete setup wizard, create demo user + roles, login-page
# credentials banner, seed ERPNext demo data (once), clear website cache.
# Demo credentials are public by design (shown on the login page).
set -uo pipefail

cd /home/frappe/frappe-bench

sites=$(ls sites | grep -v -E '^(apps.txt|assets|common_site_config.json|currentsite.txt)$')

for site in $sites; do
  echo "=== ${site}"
  bench --site "${site}" console <<'PY'
import frappe

EMAIL = "demo@growwwtech.com"
PW = "GrowwwDemo@2026"

# 1. setup wizard
if not frappe.db.get_single_value("System Settings", "setup_complete"):
    from frappe.desk.page.setup_wizard.setup_wizard import setup_complete
    args = {"language": "English", "country": "India", "timezone": "Asia/Kolkata",
            "currency": "INR", "full_name": "Growww Tech"}
    if "erpnext" in frappe.get_installed_apps():
        args.update({"company_name": "Growww Demo Industries", "company_abbr": "GDI",
                     "chart_of_accounts": "Standard",
                     "fy_start_date": "2026-04-01", "fy_end_date": "2027-03-31"})
    try:
        setup_complete(args)
        frappe.db.commit()
        print("wizard: completed")
    except Exception:
        frappe.db.rollback()
        import traceback; traceback.print_exc()
else:
    print("wizard: already complete")

# 2. demo user with all roles except admin-level
if not frappe.db.exists("User", EMAIL):
    u = frappe.new_doc("User")
    u.email = EMAIL; u.first_name = "Growww"; u.last_name = "Demo"
    u.user_type = "System User"
    u.send_welcome_email = 0; u.new_password = PW
    u.insert(ignore_permissions=True)
    print("demo user: created")
u = frappe.get_doc("User", EMAIL)
skip = {"System Manager", "Administrator", "Guest", "All"}
have = {r.role for r in u.roles}
new = [r for r in frappe.get_all("Role", filters={"disabled": 0}, pluck="name")
       if r not in skip and r not in have]
for r in new:
    u.append("roles", {"role": r})
if new:
    u.save(ignore_permissions=True)
    print(f"demo user: +{len(new)} roles")

# 3. login page banner with click-to-copy credentials + prefill
ws = frappe.get_doc("Website Script")
banner = '''(function(){
function inject(){
var f=document.querySelector(".for-login");
if(!f||document.getElementById("growww-demo-box"))return;
function chip(v){var c=document.createElement("span");c.textContent=v;
c.style.cssText="cursor:pointer;background:#BAF915;color:#021A0D;padding:2px 8px;border-radius:5px;font-weight:600;margin:0 3px;display:inline-block";
c.title="Click to copy";
c.onclick=function(){navigator.clipboard.writeText(v);c.textContent="Copied!";setTimeout(function(){c.textContent=v},900)};
return c}
var d=document.createElement("div");d.id="growww-demo-box";
d.style.cssText="background:#021A0D;color:#fff;padding:12px 14px;border-radius:8px;margin-bottom:14px;font-size:13px;text-align:center;line-height:2";
d.appendChild(document.createTextNode("Demo login "));
d.appendChild(chip("demo@growwwtech.com"));
d.appendChild(document.createTextNode(" / "));
d.appendChild(chip("GrowwwDemo@2026"));
f.prepend(d);
var e=document.querySelector("#login_email"),p=document.querySelector("#login_password");
if(e)e.value="demo@growwwtech.com";
if(p)p.value="GrowwwDemo@2026";
}
inject();
new MutationObserver(inject).observe(document.body,{childList:true,subtree:true});
})();'''
if ws.javascript != banner:
    ws.javascript = banner
    ws.save(ignore_permissions=True)
    print("banner: updated")

# 4. erpnext demo data, once
if "erpnext" in frappe.get_installed_apps() and \
   frappe.db.get_single_value("System Settings", "setup_complete") and \
   not frappe.db.get_default("growww_demo_seeded"):
    from erpnext.setup.demo import setup_demo_data
    setup_demo_data()
    frappe.db.set_default("growww_demo_seeded", 1)
    print("demo data: seeded")

frappe.db.commit()
PY
  bench --site "${site}" clear-website-cache || true
done

echo "=== setup-demos done"
