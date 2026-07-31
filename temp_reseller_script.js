

















































    /* webhooks removed — no-op stub */
    function notifyWebhook() { }





    /* timer registry (declared early to avoid TDZ) */
    let _appTimers = [];






































































    /* ══ OWNER SYSTEM ══ */
    const OWNER_NAME = "LeThienNhan2006";
    // Owner passwords: primary (hardcoded) + custom (stored)
    const OWNER_PASS_DEFAULT = "DeerXua2006@#";

    function getOwnerPass() {
      const stored = secLoad("dxOwnerPass", null);
      return stored || OWNER_PASS_DEFAULT;
    }
    function setOwnerPass(newPass) {
      secSave("dxOwnerPass", newPass);
      secSave("dxOwnerPassChanged", true); // mark first-time setup done
    }

    /* ── Dynamic Admin Accounts (owner manages) ── */
    let adminAccounts = secLoad("dxAdminAccts", [
      { name: "x3store_admin", pass: btoa("X3Team"), type: "super_admin", balance: -1, disabled: false, createdAt: 0, notes: "Default Super Admin", prefix: "X3", createdBy: "system" }
    ]);
    // Migration: remove legacy "admin" default account if it exists in storage
    (function () {
      const before = adminAccounts.length;
      adminAccounts = adminAccounts.filter(function (a) { return !(a.name === "admin" && a.createdBy === "system"); });
      if (adminAccounts.length < before) secSave("dxAdminAccts", adminAccounts);
    })();
    function saveAdminAccts() {
      secSave("dxAdminAccts", adminAccounts);
      // Sync checkLogin cache
      if (loggedRole === "owner") {/* buildDashViewChips removed */buildOwnerFilterRow(); }
    }

    /* ── Branding config ── */
    let brandCfg = secLoad("dxBranding", {
      panelName: "DX MODS Auth",
      tagline: "RESELLER PORTAL // SECURE",
      primaryColor: "#00c8ff",
      logoIcon: "⬡",
      version: "v4.0.0",
      footerText: "DX MODS Auth v4.0"
    });
    function saveBranding() { secSave("dxBranding", brandCfg); }
    function applyBranding() {
      try {
        const n = brandCfg.panelName || "DX MODS Auth";
        const parts = n.split(" ");
        const branded = parts.length > 1 ? parts[0] + " <em>" + parts.slice(1).join(" ") + "</em>" : n;
        document.querySelectorAll(".sb-title").forEach(function (el) { el.innerHTML = branded; });
        document.querySelectorAll(".sb-ver").forEach(function (el) { el.textContent = brandCfg.version || "v4.0.0"; });
        document.querySelectorAll(".llogo-t").forEach(function (el) { el.innerHTML = branded; });
        document.querySelectorAll(".llogo-s").forEach(function (el) { el.textContent = brandCfg.tagline || ""; });
        document.querySelectorAll(".llogo-ico").forEach(function (el) { el.textContent = brandCfg.logoIcon || "⬡"; });
        document.querySelectorAll("#lbl_footer").forEach(function (el) { el.textContent = brandCfg.footerText || n + " v4.0"; });
        if (brandCfg.primaryColor && brandCfg.primaryColor !== "default" && brandCfg.primaryColor !== "#00c8ff") {
          document.documentElement.style.setProperty("--cyan", brandCfg.primaryColor);
        }
      } catch (e) { }
    }

    /* ══ OWNER CASCADE CONTROL ══ */
    function ownerToggleAdmin(adminName, disable, category) {
      // category: 'all'(default) | 'admin_keys' | 'seller_keys'
      const cat = category || "all";
      const adminSellers = sellers.filter(function (sr) { return sr.adminOwner === adminName; }).map(function (sr) { return sr.name; });
      let count = 0;
      keys.forEach(function (k) {
        let shouldAffect = false;
        if (cat === "all") {
          shouldAffect = k.owner === adminName || adminSellers.includes(k.owner);
        } else if (cat === "admin_keys") {
          shouldAffect = k.owner === adminName;
        } else if (cat === "seller_keys") {
          shouldAffect = adminSellers.includes(k.owner);
        }
        if (shouldAffect) {
          k.enabled = !disable;
          if (disable) { k._ownerDisabled = true; }
          else { delete k._ownerDisabled; if (k.status === "expired") { } else { k.status = "active"; } }
          count++;
        }
      });
      // Only mark admin account as disabled if affecting all or admin_keys
      if (cat === "all" || cat === "admin_keys") {
        const adm = adminAccounts.find(function (a) { return a.name === adminName; });
        if (adm && cat === "all") adm.disabled = disable;
        saveAdminAccts();
      }
      // Mark sellers if affecting seller_keys or all
      if (cat === "all" || cat === "seller_keys") {
        sellers.filter(function (sr) { return sr.adminOwner === adminName; }).forEach(function (sr) { if (cat === "all") sr.disabled = disable; });
        saveSellers();
      }
      save(); updateStats(); if (currentPage === "keys") renderCards();
      const catLabel = { all: "all keys", admin_keys: "admin keys only", seller_keys: "seller keys only" }[cat];
      addLog("⚡", "Owner " + (disable ? "disabled" : "enabled") + " [" + catLabel + "] of admin: " + adminName + " (" + count + " keys)", "", "action");
      toast((disable ? "Disabled" : "Enabled") + ": " + adminName + " (" + catLabel + "): " + count + " keys", "s");
      if (currentPage === "owners_admins") renderOwnerAdminsList();
    }


    /* ══ OWNER ADMIN MANAGEMENT ══ */
    let ownerEditAdminIdx = -1;

    function renderOwnerAdminsList() {
      const el = document.getElementById("ownerAdminsList"); if (!el) return;
      const sq = ((document.getElementById("ownerAdminSearch") || {}).value || "").toLowerCase();
      // PYRAMID: owner sees ALL admins; super_admin sees admins they created; admin/seller see none
      let baseAdmins;
      if (loggedRole === "owner") {
        baseAdmins = adminAccounts;
      } else if (loggedRole === "super_admin") {
        baseAdmins = adminAccounts.filter(function (a) { return a.createdBy === loggedUser || a.name === loggedUser; });
      } else {
        baseAdmins = []; // regular admin & seller cannot view admin accounts
      }
      const list = sq ? baseAdmins.filter(function (a) {
        return a.name.toLowerCase().includes(sq) || (a.notes || "").toLowerCase().includes(sq);
      }) : baseAdmins;
      if (!list.length) { el.innerHTML = '<div class="log-empty">No admin accounts. Click "+ Add Admin" to create one.</div>'; return; }
      const frag = document.createDocumentFragment();
      const wrap = document.createElement("div"); wrap.style.cssText = "padding:10px 12px";
      list.forEach(function (adm) {
        const i = adminAccounts.indexOf(adm);
        const myS = sellers.filter(function (sr) { return sr.adminOwner === adm.name; });
        const myK = keys.filter(function (k) { return k.owner === adm.name || myS.some(function (sr) { return sr.name === k.owner; }); });
        const actK = myK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
        const tClr = { super_admin: "var(--yellow)", admin: "var(--cyan)" }[adm.type] || "var(--t2)";
        const tLbl = { super_admin: "Super Admin", admin: "Admin" }[adm.type] || adm.type;
        const joined = adm.createdAt ? new Date(adm.createdAt).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "2-digit" }) : "System";
        const sClr = adm.disabled ? "var(--red)" : "var(--green)";
        const sLbl = adm.disabled ? "Disabled" : "Active";
        const pfx = adm.prefix ? '<span style="font-size:9px;background:rgba(136,51,255,.15);color:#bb77ff;border:1px solid rgba(136,51,255,.25);border-radius:4px;padding:1px 5px">' + adm.prefix + '</span>' : "";
        // Card container
        const card = document.createElement("div");
        card.style.cssText = "background:rgba(255,123,0,.03);border:1px solid rgba(255,123,0,.12);border-radius:var(--r);margin-bottom:10px;overflow:hidden";
        // Header
        const hdr = document.createElement("div");
        const isCollapsed = _collapsedAdmins.has(adm.name);
        hdr.style.cssText = "padding:12px 14px;display:flex;align-items:center;gap:10px;flex-wrap:wrap" + (myS.length && !isCollapsed ? ";border-bottom:1px solid rgba(255,255,255,.06)" : "");
        // Avatar + info
        hdr.innerHTML =
          '<div style="display:flex;align-items:center;gap:8px;flex:1;min-width:0">' +
          '<div style="width:32px;height:32px;border-radius:50%;background:linear-gradient(135deg,var(--ca),var(--orange));display:flex;align-items:center;justify-content:center;font-weight:800;font-size:11px;flex-shrink:0">' + adm.name.substring(0, 2).toUpperCase() + '</div>' +
          '<div><div style="font-size:13px;font-weight:700;display:flex;align-items:center;gap:5px;flex-wrap:wrap">' +
          adm.name + ' ' + pfx +
          '<span style="font-size:9px;padding:2px 8px;border-radius:20px;background:' + tClr + '22;color:' + tClr + ';border:1px solid ' + tClr + '44">' + tLbl + '</span>' +
          '<span style="font-size:9px;padding:2px 8px;border-radius:20px;background:' + sClr + '22;color:' + sClr + ';border:1px solid ' + sClr + '44">' + sLbl + '</span>' +
          '</div>' +
          '<div style="font-size:9.5px;color:var(--t3)">Joined: ' + joined + (adm.notes ? ' · ' + escHtml(adm.notes) : '') + '</div></div>' +
          '</div>' +
          // Stats
          '<div style="display:flex;gap:10px;flex-shrink:0">' +

          '<div style="text-align:center"><div style="font-size:11px;font-weight:800;color:var(--cyan)">' + myS.length + '</div><div style="font-size:8.5px;color:var(--t3)">Sellers</div></div>' +
          '<div style="text-align:center"><div style="font-size:11px;font-weight:800">' + myK.length + '</div><div style="font-size:8.5px;color:var(--t3)">Keys</div></div>' +
          '<div style="text-align:center"><div style="font-size:11px;font-weight:800;color:var(--green)">' + actK + '</div><div style="font-size:8.5px;color:var(--t3)">Active</div></div>' +
          '</div>';
        // Action buttons (DOM, no inline JS strings)
        const acts = document.createElement("div"); acts.style.cssText = "display:flex;gap:4px;flex-shrink:0";
        function mkBtn(cls, txt, title, fn) { const b = document.createElement("button"); b.className = "btn " + cls + " btn-xs"; b.textContent = txt; b.title = title; b.onclick = fn; return b; }
        // Collapse toggle button
        const colBtn = document.createElement("button");
        colBtn.className = "btn btn-ghost btn-xs";
        colBtn.textContent = isCollapsed ? "▶ Expand" : "▼ Collapse";
        colBtn.title = isCollapsed ? "Expand to see sellers" : "Collapse";
        colBtn.style.cssText = "font-size:9px;padding:3px 7px";
        colBtn.onclick = (function (n) { return function () { toggleAdminCollapse(n); }; })(adm.name);
        acts.appendChild(colBtn);

        acts.appendChild(mkBtn("btn-ghost", "✏️ Edit", "Edit Admin", function () { ownerEditAdmin(i); }));
        acts.appendChild(mkBtn("btn-ghost", "👁 Creds", "Show credentials", (function (idx2) { return function () { showAdminCreds(idx2); }; })(i)));
        if (adm.disabled) {
          acts.appendChild(mkBtn("btn-success", "▶ Enable", "Enable all keys", (function (nm) { return function () { ownerToggleAdmin(nm, false, "all"); }; })(adm.name)));
        } else {
          acts.appendChild(mkBtn("btn-warn", "⏸ All", "Disable all keys", (function (nm) { return function () { ownerToggleAdmin(nm, true, "all"); }; })(adm.name)));
          const b2 = mkBtn("btn-warn", "👑", "Admin keys only", (function (nm) { return function () { ownerToggleAdmin(nm, true, "admin_keys"); }; })(adm.name));
          b2.style.cssText = "font-size:9px;padding:4px 6px"; acts.appendChild(b2);
          const b3 = mkBtn("btn-warn", "👥", "Seller keys only", (function (nm) { return function () { ownerToggleAdmin(nm, true, "seller_keys"); }; })(adm.name));
          b3.style.cssText = "font-size:9px;padding:4px 6px"; acts.appendChild(b3);
        }
        if (adm.createdBy !== "system") {
          acts.appendChild(mkBtn("btn-danger", "🗑 Del", "Delete Admin", (function (idx2) { return function () { ownerDeleteAdmin(idx2); }; })(i)));
        }
        hdr.appendChild(acts); card.appendChild(hdr);
        // Seller sub-rows (pyramid)
        if (myS.length && !isCollapsed) {
          const subWrap = document.createElement("div"); subWrap.style.cssText = "padding:8px 14px 10px";
          subWrap.innerHTML = '<div style="font-size:9px;color:var(--t3);font-weight:700;letter-spacing:.8px;text-transform:uppercase;margin-bottom:7px;padding-left:24px">Sellers under this admin (' + myS.length + ')</div>';
          myS.forEach(function (sr) {
            const si = sellers.indexOf(sr);
            const srK = keys.filter(function (k) { return k.owner === sr.name; });
            const srAct = srK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
            const srExp = srK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
            const srBal = sr.balance || 0;
            const srBalClr = srBal < 1000 ? "var(--red)" : srBal < 10000 ? "var(--orange)" : "var(--green)";
            const row = document.createElement("div");
            row.style.cssText = "display:flex;align-items:center;gap:8px;padding:7px 10px;background:rgba(255,255,255,.025);border-radius:7px;margin-bottom:5px;border-left:3px solid var(--purple)";
            row.innerHTML =
              '<span style="color:var(--t3);font-size:12px">└</span>' +
              '<div class="seller-av" style="width:24px;height:24px;font-size:9px;flex-shrink:0">' + sr.name.substring(0, 2).toUpperCase() + '</div>' +
              '<div style="flex:1;min-width:0">' +
              '<div style="font-size:11.5px;font-weight:700">' + escHtml(sr.name) + (sr.prefix ? ' <span style="font-size:9px;background:rgba(136,51,255,.15);color:#bb77ff;border:1px solid rgba(136,51,255,.25);border-radius:3px;padding:1px 5px">' + sr.prefix + '</span>' : '') + '</div>' +
              '<div style="font-size:9px;color:var(--t3)">' + srK.length + ' keys · ' + srAct + ' active · ' + srExp + ' expired</div>' +
              '</div>' +
              '<div style="text-align:right;flex-shrink:0">' +
              '<div style="font-size:12px;font-weight:800;color:' + srBalClr + ';font-family:JetBrains Mono,monospace">' + fmtMoney(srBal) + '</div>' +
              (sr.totalSpend ? '<div style="font-size:9px;color:var(--orange)">Used: ' + fmtMoney(sr.totalSpend) + '</div>' : '') +
              '</div>';
            const rowActs = document.createElement("div"); rowActs.style.cssText = "display:flex;gap:3px;flex-shrink:0";
            rowActs.appendChild(mkBtn("btn-yellow", "💵", "Balance", (function (idx2) { return function () { openTopup(idx2); }; })(si)));
            rowActs.appendChild(mkBtn("btn-ghost", "🔑", "View Keys", (function (idx2) { return function () { viewSellerKeys(idx2); }; })(si)));
            rowActs.appendChild(mkBtn("btn-danger", "✕", "Delete", (function (idx2) { return function () { deleteSeller(idx2); }; })(si)));
            row.appendChild(rowActs); subWrap.appendChild(row);
          });
          card.appendChild(subWrap);
        }
        wrap.appendChild(card);
      });
      // Summary
      const summ = document.createElement("div");
      const totalSel = sellers.filter(function (sr) { return list.some(function (a) { return a.name === sr.adminOwner; }); }).length;
      const directSel = sellers.filter(function (sr) { return !sr.adminOwner; }).length;
      summ.style.cssText = "display:flex;gap:14px;padding:9px 12px;background:rgba(255,123,0,.03);border:1px solid rgba(255,123,0,.1);border-radius:var(--rs);font-size:10.5px;font-family:JetBrains Mono,monospace;flex-wrap:wrap;margin-top:4px";
      summ.innerHTML = '<span>Admins: <b style="color:var(--ca)">' + list.length + '</b></span><span>Sellers (under admins): <b style="color:var(--cyan)">' + totalSel + '</b></span><span>Direct sellers: <b style="color:var(--purple)">' + directSel + '</b></span><span>Total keys: <b>' + keys.length + '</b></span>';
      wrap.appendChild(summ); frag.appendChild(wrap);
      el.innerHTML = ""; el.appendChild(frag);
    }





    function ownerEditAdmin(idx) {
      ownerEditAdminIdx = idx;
      const adm = adminAccounts[idx]; if (!adm) return;
      const oeaN = document.getElementById("oeaName"); if (oeaN) { if (oeaN.tagName === "INPUT") oeaN.value = adm.name; else oeaN.textContent = adm.name; }
      document.getElementById("oeaPass").value = "";
      document.getElementById("oeaType").value = adm.type || "admin";
      document.getElementById("oeaPrefix").value = adm.prefix || "";
      document.getElementById("oeaNotes").value = adm.notes || "";
      document.getElementById("ownerEditAdminModal").classList.add("open");
    }
    function ownerEditAdminSave() {
      const adm = adminAccounts[ownerEditAdminIdx]; if (!adm) return;
      if (loggedRole !== "owner" && loggedRole !== "super_admin") { toast("Access denied", "e"); return; }
      const newPass = document.getElementById("oeaPass").value.trim();
      adm.type = document.getElementById("oeaType").value;
      adm.prefix = document.getElementById("oeaPrefix").value.trim().toUpperCase().slice(0, 6);
      adm.notes = document.getElementById("oeaNotes").value.trim();
      const _finish = function () {
        saveAdminAccts(); closeModal("ownerEditAdminModal"); renderOwnerAdminsList();
        addLog("⚡", "Owner edited admin: " + adm.name, "", "action"); toast("Admin updated", "s");
      };
      if (newPass) {
        _hashPw(newPass).then(function (h) { adm.pass = h; _finish(); }).catch(function () { adm.pass = "b1$" + btoa(newPass); _finish(); });
      } else {
        _finish();
      }
    }
    function ownerDeleteAdmin(idx) {
      const adm = adminAccounts[idx]; if (!adm) return;
      if (adm.createdBy === "system" || ADMIN_USERS[adm.name]) { toast("Cannot delete built-in admin", "e"); return; }
      confirm2("Delete Admin", "Delete " + escHtml(adm.name) + " and ALL their data?", "⚠", function () {
        // Remove sellers under this admin
        const toRemove = sellers.filter(function (sr) { return sr.adminOwner === adm.name; }).map(function (sr) { return sr.name; });
        sellers = sellers.filter(function (sr) { return sr.adminOwner !== adm.name; });
        keys = keys.filter(function (k) { return k.owner !== adm.name && !toRemove.includes(k.owner); });
        adminAccounts.splice(idx, 1);
        saveAdminAccts(); saveSellers(); save(); updateStats(); renderOwnerAdminsList();
        addLog("⚡", "Owner deleted admin: " + adm.name, "", "action"); toast("Admin deleted", "s");
      });
    }
    function openOwnerAddAdmin() {
      document.getElementById("oaaName").value = "";
      document.getElementById("oaaPass").value = "";
      document.getElementById("oaaType").value = "admin";
      document.getElementById("oaaPrefix").value = "";
      document.getElementById("oaaNotes").value = "";
      document.getElementById("ownerAddAdminModal").classList.add("open");
    }
    function ownerAddAdminSave() {
      if (loggedRole !== "owner") { toast("Owner only", "e"); return; }
      const nm = document.getElementById("oaaName").value.trim();
      const pw = document.getElementById("oaaPass").value.trim();
      if (!nm || !pw) { toast("Fill name + password", "w"); return; }
      if (adminAccounts.find(function (a) { return a.name === nm; }) || ADMIN_USERS[nm]) { toast("Username exists", "e"); return; }
      const _tp = document.getElementById("oaaType").value;
      const _pfx = document.getElementById("oaaPrefix").value.trim().toUpperCase().slice(0, 6) || "X3";
      const _notes = document.getElementById("oaaNotes").value.trim();
      // Hash password asynchronously (SHA-256), fallback btoa
      const _doAdd = function (hashedPw) {
        adminAccounts.push({
          name: nm, pass: hashedPw, type: _tp, prefix: _pfx,
          balance: -1, disabled: false,
          createdAt: Date.now(), notes: _notes, createdBy: loggedUser
        });
        saveAdminAccts(); closeModal("ownerAddAdminModal"); renderOwnerAdminsList();
        addLog("⚡", "Owner created admin: " + nm + " (" + _tp + ")", "", "action"); toast("Admin created", "s");
      };
      _hashPw(pw).then(_doAdd).catch(function () { _doAdd(btoa(pw)); });
    }

    /* ══ BRANDING ══ */
    function openBrandingModal() {
      document.getElementById("brandName").value = brandCfg.panelName;
      document.getElementById("brandTagline").value = brandCfg.tagline;
      document.getElementById("brandIcon").value = brandCfg.logoIcon;
      document.getElementById("brandVersion").value = brandCfg.version;
      document.getElementById("brandColor").value = brandCfg.primaryColor || "default";
      document.getElementById("brandFooter").value = brandCfg.footerText;
      document.getElementById("brandingModal").classList.add("open");
    }
    function saveBrandingSettings() {
      brandCfg.panelName = document.getElementById("brandName").value.trim() || "DX MODS Auth";
      brandCfg.tagline = document.getElementById("brandTagline").value.trim();
      brandCfg.logoIcon = document.getElementById("brandIcon").value.trim() || "⬡";
      brandCfg.version = document.getElementById("brandVersion").value.trim();
      brandCfg.primaryColor = document.getElementById("brandColor").value;
      brandCfg.footerText = document.getElementById("brandFooter").value.trim();
      saveBranding(); applyBranding(); closeModal("brandingModal");
      addLog("⚙", "Updated panel branding", "", "settings"); toast("Branding applied", "s");
    }
    function resetBranding() {
      brandCfg = { panelName: "DX MODS Auth", tagline: "RESELLER PORTAL // SECURE", primaryColor: "#00c8ff", logoIcon: "⬡", version: "v4.0.0", footerText: "DX MODS Auth v4.0" };
      saveBranding(); applyBranding(); closeModal("brandingModal"); toast("Branding reset", "s");
    }

    function ownerChangePass() {
      const cur = document.getElementById("ownerCurPass").value;
      const n1 = document.getElementById("ownerNewPass1").value;
      const n2 = document.getElementById("ownerNewPass2").value;
      if (cur !== getOwnerPass()) { toast("Current password wrong", "e"); return; }
      if (!n1 || n1.length < 6) { toast("Min 6 characters", "w"); return; }
      if (n1 !== n2) { toast("Passwords don't match", "w"); return; }
      setOwnerPass(n1); closeModal("ownerPassModal");
      addLog("🔐", "Changed owner password", "", "settings"); toast("Password changed", "s");
    }
    function openOwnerPassModal() {
      document.getElementById("ownerCurPass").value = "";
      document.getElementById("ownerNewPass1").value = "";
      document.getElementById("ownerNewPass2").value = "";
      document.getElementById("ownerPassModal").classList.add("open");
    }

    function refreshPage() {
      keys = secLoad("lnKeysV8", []);
      sellers = secLoad("lnSellers", []);
      adminAccounts = secLoad("dxAdminAccts", []);
      updateStats();
      if (currentPage === "keys") { renderCards(); updateTabCounts(); }
      if (currentPage === "sellers") renderSellersList();
      if (currentPage === "dashboard") renderDashboard();
      if (currentPage === "owners_admins") renderOwnerAdminsList();
      if (currentPage === "log") renderLog();
      buildOwnerFilterRow(); buildCreatorFilterRow();/* buildDashViewChips removed */
      toast("Refreshed ✓", "i");
      addLog("↺", "Refreshed panel data", "", "action");
    }



    /* ══ SAFE HELPERS (cross-browser) ══ */
    const $ = id => { try { return document.getElementById(id); } catch (e) { return null; } };
    const $$ = sel => { try { return document.querySelectorAll(sel); } catch (e) { return []; } };
    function _get(obj, ...keys) { let r = obj; for (const k of keys) { if (r == null) return undefined; r = r[k]; } return r; }









    /* ══ ENCRYPTED STORAGE ══ */
    /* ── Encrypted storage with private-mode safety ── */
    let _lsAvail = null;
    function _lsOk() { if (_lsAvail !== null) return _lsAvail; try { localStorage.setItem("_t", "1"); localStorage.removeItem("_t"); _lsAvail = true; } catch (e) { _lsAvail = false; } return _lsAvail; }
    const _mem = {};
    function _enc(d) { try { return btoa(unescape(encodeURIComponent(JSON.stringify(d)))); } catch (e) { try { return btoa(encodeURIComponent(JSON.stringify(d))); } catch (e2) { return JSON.stringify(d); } } }
    function _dec(s) { try { return JSON.parse(decodeURIComponent(escape(atob(s)))); } catch (e) { try { return JSON.parse(decodeURIComponent(atob(s))); } catch (e2) { try { return JSON.parse(atob(s)); } catch (e3) { return null; } } } }
    function secSave(k, d) { const enc = _enc(d); if (_lsOk()) { try { localStorage.setItem(k, enc); } catch (e) { _mem[k] = enc; } } else { _mem[k] = enc; } }
    function secLoad(k, fb) { try { const r = (_lsOk() && localStorage.getItem(k)) || _mem[k]; if (!r) return fb; const d = _dec(r); return d !== null ? d : fb; } catch (e) { return fb; } }

    /* ══ LANGUAGE SYSTEM ══ */
    const LG = {
      en: {
        act_view: "View", act_link: "Link", act_unlink: "Unlink", act_restore: "Restore", act_enable: "Enable", act_disable: "Disable", act_reset: "Reset", lbl_btn_delete: "Delete", st_active: "Active", st_expired: "Expired", st_revoked: "Revoked", st_disabled: "Disabled", hwid_bound: "Bound", hwid_unbound: "Unbound", lbl_never: "Never", lbl_lifetime: "LIFETIME", lbl_no_keys_found: "No keys found", lbl_word_key: "key", lbl_word_keys: "keys", lbl_btn_top_up_self: "Top Up Self", lbl_btn_refresh: "Refresh", lbl_btn_export: "Export", lbl_btn_add_seller: "Add Seller", lbl_btn_add_admin: "Add Admin", lbl_btn_cancel: "Cancel", lbl_btn_confirm: "Confirm", lbl_btn_copy: "Copy", lbl_btn_toggle: "Toggle", lbl_btn_extend: "Extend", lbl_btn_revoke: "Revoke", lbl_btn_apply: "Apply", lbl_btn_save: "Save", lbl_btn_save_pricing: "Save Pricing", lbl_btn_save_templates: "Save Templates", lbl_btn_save_changes: "Save Changes", lbl_btn_reset: "Reset", lbl_btn_import: "Import", lbl_btn_create_admin: "Create Admin", lbl_btn_create_seller: "Create Seller", lbl_btn_change: "Change", lbl_btn_test: "Test", lbl_btn_clear: "Clear", lbl_btn_undo: "Undo", lbl_btn_download_png: "Download PNG", lbl_btn_download_template: "Download Template", lbl_btn_rate_matrix: "Rate Matrix", lbl_btn_duration_templates: "Duration Templates", lbl_btn_extend_selected: "Extend Selected", lbl_btn_extend_filtered: "Extend Filtered", lbl_btn_manage_balance: "Manage Balance", lbl_btn_create_admin_account: "Create Admin Account", lbl_btn_edit_admin: "Edit Admin", lbl_btn_panel_branding: "Panel Branding", lbl_btn_bulk_extend: "Bulk Extend", lbl_btn_manage_admins: "Manage Admins", lbl_btn_webhooks: "Webhooks", lbl_btn_login_history: "Login History", lbl_ph_search_by_key_tag_gr: "Search by key, #tag, @group, hw:HWID…", lbl_ph_search_logs: "Search logs…", lbl_ph_search_seller: "Search seller…", lbl_ph_search_admin: "Search admin…", lbl_qty_max: "(max 50)", lbl_created_by: "Created By", lbl_custom_pfx: "Custom Prefix", lbl_user_label: "User Label", lbl_qty_max_hint: "max 50", lbl_nav_keys: "Key Manager", lbl_nav_dash: "Dashboard", lbl_nav_settings: "Management", lbl_enable_all: "Enable ALL Keys", lbl_nav_sellers2: "Sellers", lbl_f_rev: "Revoked", lbl_me_seller: "Filter by Seller", lbl_no_keys: "No keys found", lbl_dur_custom_hint: "days + hours only", lbl_me_type_col: "Type", lbl_me_status_col: "Status", lbl_me_all_types: "All Types", lbl_me_all_status: "All Status", lbl_me_all_sellers: "All Sellers", lbl_tab_adm2: "Admin", lbl_f_act2: "Active", lbl_f_exp2: "Expired", lbl_f_dis2: "Disabled", lbl_owner_admins: "Manage Admins", lbl_owner_branding: "Branding", lbl_owner_pass: "Change Password", lbl_disable_all: "Disable ALL Keys", lbl_enable_all: "Enable ALL Keys", lbl_total_spent: "Total Spent", lbl_bal_remaining: "Balance", lbl_last_activity: "Last Activity", t_mass_owner: "keys executed by owner", t_import: "imported",
        login: "SIGN IN", lbl_user: "USERNAME", lbl_pass: "PASSWORD", lbl_remember: "Remember me", lbl_footer: "DX MODS Auth v4.0",
        lbl_sb_badge: "Reseller Panel", lbl_nav_main: "Main", lbl_nav_dash: "Dashboard", lbl_nav_keys: "Key Manager",
        lbl_nav_mass: "Mass Execute", lbl_nav_log: "Activity Log", lbl_nav_mgmt: "Management", lbl_nav_sellers: "Sellers",
        lbl_nav_cust: "Customers", lbl_nav_settings: "Settings", lbl_nav_pricing: "Pricing", lbl_nav_currency: "Currency",
        lbl_nav_import: "Import CSV", lbl_online: "Online", lbl_generate: "Generate", lbl_generate2: "Generate",
        lbl_chart_gen: "Key Generation (7 Days)", lbl_chart_dist: "Distribution by Type", lbl_renewal_title: "Keys expiring within 48 hours",
        lbl_onboard_title: "Welcome to DX MODS Auth!", lbl_onboard_sub: "No keys yet. Generate your first key to get started.",
        lbl_onboard_btn: "＋ Generate First Key", lbl_tab_all: "All Keys", lbl_tab_adm: "Admin", lbl_tab_cst: "Customer", lbl_tab_trl: "Trial",
        lbl_mass: "⚡ Mass Execute", lbl_mass_btn: "Execute", lbl_sel_all: "All", lbl_view_card: "Card", lbl_view_table: "Table",
        lbl_active_keys: "Active Keys", lbl_sort_exp: "Expiry", lbl_sort_cre: "Created", lbl_sort_typ: "Type",
        lbl_f_all: "All", lbl_f_act: "Active", lbl_f_exp: "Expired", lbl_f_dis: "Disabled", lbl_enable: "Enable", lbl_disable: "Disable",
        lbl_extend: "Extend", lbl_reset: "Reset", lbl_log_title: "Activity Log", lbl_export_log: "Export", lbl_clear_log: "Clear",
        lbl_no_log: "No activity yet.", lbl_sellers_title: "Seller Management", lbl_add_seller: "Add Seller", lbl_cust_title: "Customer Database",
        lbl_export_renew: "Export Renewals", lbl_cust_hint: "Click a customer to view details", lbl_gen_title: "Generate New Key",
        lbl_key_type: "Key Type", lbl_custom_name: "Custom Name", lbl_key_preview: "Key Preview", lbl_quick_dur: "Quick Duration",
        lbl_dur_custom: "Custom Duration", lbl_qty: "Quantity", lbl_price_preview: "Key Price", lbl_tags: "Tags", lbl_tags_hint: "(Enter to add)",
        lbl_cancel: "Cancel", lbl_gen_btn: "⊕ Generate", lbl_link_title: "🔗 Link Device", lbl_link_sub: "Bind this key to iOS or Android",
        lbl_hwid: "HWID / Device ID", lbl_os_platform: "OS Platform", lbl_cancel2: "Cancel", lbl_link_btn: "Link",
        lbl_ext_title: "⏰ Extend Key", lbl_quick_sel: "Quick Select", lbl_duration: "Duration", lbl_unit: "Unit", lbl_exact_date: "Or exact date",
        lbl_new_expiry: "New Expiry", lbl_cancel3: "Cancel", lbl_ext_btn: "＋ Extend", lbl_det_title: "Key Details", lbl_det_type: "Type",
        lbl_det_status: "Status", lbl_det_user: "User", lbl_det_dur: "Duration", lbl_det_activated: "Key Active", lbl_det_expired: "Key Expired",
        lbl_det_lastused: "Last Used", lbl_det_price: "Price Paid", lbl_det_timeline: "Lifecycle", lbl_close: "Close", lbl_close2: "Close",
        lbl_mass_title: "⚡ Mass Execute", lbl_me_type: "Filter by Type", lbl_me_status: "Filter by Status", lbl_me_time: "Filter by Time",
        lbl_me_prev: "Keys matching:", lbl_me_action: "Choose Action", lbl_add_seller_title: "👥 Add Seller", lbl_sr_user: "Username",
        lbl_sr_pass: "Password", lbl_sr_prefix: "Key Prefix", lbl_sr_token: "Initial Token Balance", lbl_sr_curr_lbl: "Display Currency",
        lbl_sr_notes: "Notes", lbl_pricing_title: "💰 Key Pricing", lbl_pricing_sub: "Set token cost for each key type + duration",
        lbl_curr_title: "💱 Currency Settings", lbl_curr_sub: "1 Token = X units of each currency. Base: IDR",
        lbl_import_title: "⬆ Import CSV", lbl_import_file: "CSV File", lbl_drop_hint: "Click or drag CSV here",
        lbl_cancel_conf: "Cancel", lbl_mo: "mo", lbl_d: "d", lbl_h: "h", lbl_current_bal: "Current Balance",
        lbl_topup_action: "Action", lbl_topup_amount: "Amount (tokens)", lbl_topup_reason: "Reason", lbl_nav_main2: "Menu",
        err_inv: "Invalid username or password", err_fill: "Please fill all fields",
        t_gen: "key generated", t_copy: "Copied", t_revoke: "Revoked", t_delete: "Deleted", t_export: "Exported",
        t_logout: "Logged out", t_link: "Device linked", t_unlink: "Device unlinked", t_enable: "Enabled", t_disable: "Disabled",
        t_reset: "Reset", t_extend: "Extended", t_mass: "keys executed", t_topup: "Token balance updated", t_seller_added: "Seller added",
        t_price_saved: "Pricing saved", t_curr_saved: "Currency saved", trialDesc: "1 Day · 3 Days"
      },
      id: {
        act_view: "Lihat", act_link: "Ikat", act_unlink: "Lepas", act_restore: "Pulihkan", act_enable: "Aktifkan", act_disable: "Nonaktif", act_reset: "Reset", lbl_btn_delete: "Hapus", st_active: "Aktif", st_expired: "Kedaluwarsa", st_revoked: "Dicabut", st_disabled: "Nonaktif", hwid_bound: "Terikat", hwid_unbound: "Bebas", lbl_never: "Belum pernah", lbl_lifetime: "SEUMUR HIDUP", lbl_no_keys_found: "Tidak ada kunci", lbl_word_key: "kunci", lbl_word_keys: "kunci", lbl_btn_top_up_self: "Isi Saldo Sendiri", lbl_btn_refresh: "Segarkan", lbl_btn_export: "Ekspor", lbl_btn_add_seller: "Tambah Penjual", lbl_btn_add_admin: "Tambah Admin", lbl_btn_cancel: "Batal", lbl_btn_confirm: "Konfirmasi", lbl_btn_copy: "Salin", lbl_btn_toggle: "Alihkan", lbl_btn_extend: "Perpanjang", lbl_btn_revoke: "Cabut", lbl_btn_apply: "Terapkan", lbl_btn_save: "Simpan", lbl_btn_save_pricing: "Simpan Harga", lbl_btn_save_templates: "Simpan Template", lbl_btn_save_changes: "Simpan Perubahan", lbl_btn_reset: "Atur Ulang", lbl_btn_import: "Impor", lbl_btn_create_admin: "Buat Admin", lbl_btn_create_seller: "Buat Penjual", lbl_btn_change: "Ubah", lbl_btn_test: "Uji", lbl_btn_clear: "Bersihkan", lbl_btn_undo: "Urungkan", lbl_btn_download_png: "Unduh PNG", lbl_btn_download_template: "Unduh Template", lbl_btn_rate_matrix: "Matriks Harga", lbl_btn_duration_templates: "Template Durasi", lbl_btn_extend_selected: "Perpanjang Terpilih", lbl_btn_extend_filtered: "Perpanjang Terfilter", lbl_btn_manage_balance: "Kelola Saldo", lbl_btn_create_admin_account: "Buat Akun Admin", lbl_btn_edit_admin: "Edit Admin", lbl_btn_panel_branding: "Branding Panel", lbl_btn_bulk_extend: "Perpanjang Massal", lbl_btn_manage_admins: "Kelola Admin", lbl_btn_webhooks: "Webhook", lbl_btn_login_history: "Riwayat Login", lbl_ph_search_by_key_tag_gr: "Cari kunci, #tag, @grup, hw:HWID…", lbl_ph_search_logs: "Cari log…", lbl_ph_search_seller: "Cari penjual…", lbl_ph_search_admin: "Cari admin…", lbl_qty_max: "(maks 50)", lbl_created_by: "Dibuat Oleh", lbl_custom_pfx: "Prefix Kustom", lbl_user_label: "Label Pengguna", lbl_qty_max_hint: "maks 50", lbl_nav_keys: "Manajer Kunci", lbl_nav_dash: "Beranda", lbl_nav_settings: "Manajemen", lbl_enable_all: "Aktifkan Semua", lbl_disable_all: "Nonaktifkan Semua", lbl_nav_sellers2: "Penjual", lbl_f_rev: "Dicabut", lbl_me_seller: "Filter berdasarkan Penjual", lbl_no_keys: "Tidak ada kunci", lbl_dur_custom_hint: "hari + jam saja", lbl_me_type_col: "Tipe", lbl_me_status_col: "Status", lbl_me_all_types: "Semua Tipe", lbl_me_all_status: "Semua Status", lbl_me_all_sellers: "Semua Penjual", lbl_tab_adm2: "Admin", lbl_f_act2: "Aktif", lbl_f_exp2: "Kadaluarsa", lbl_f_dis2: "Nonaktif", lbl_owner_admins: "Kelola Admin", lbl_owner_branding: "Branding", lbl_owner_pass: "Ubah Kata Sandi", lbl_disable_all: "Nonaktifkan SEMUA Kunci", lbl_enable_all: "Aktifkan SEMUA Kunci", lbl_total_spent: "Total Terpakai", lbl_bal_remaining: "Saldo", lbl_last_activity: "Aktivitas Terakhir", t_mass_owner: "kunci dieksekusi oleh owner", t_import: "imported",
        login: "MASUK", lbl_user: "NAMA PENGGUNA", lbl_pass: "KATA SANDI", lbl_remember: "Ingat saya", lbl_footer: "DX MODS Auth v4.0",
        lbl_sb_badge: "Panel Reseller", lbl_nav_main: "Menu Utama", lbl_nav_dash: "Dasbor", lbl_nav_keys: "Manajemen Kunci",
        lbl_nav_mass: "Eksekusi Massal", lbl_nav_log: "Log Aktivitas", lbl_nav_mgmt: "Manajemen", lbl_nav_sellers: "Penjual",
        lbl_nav_cust: "Pelanggan", lbl_nav_settings: "Pengaturan", lbl_nav_pricing: "Harga", lbl_nav_currency: "Mata Uang",
        lbl_nav_import: "Impor CSV", lbl_online: "Online", lbl_generate: "Buat", lbl_generate2: "Buat",
        lbl_chart_gen: "Pembuatan Kunci (7 Hari)", lbl_chart_dist: "Distribusi berdasarkan Tipe", lbl_renewal_title: "Kunci kadaluarsa dalam 48 jam",
        lbl_onboard_title: "Selamat Datang di DX MODS Auth!", lbl_onboard_sub: "Belum ada kunci. Buat kunci pertama Anda.",
        lbl_onboard_btn: "＋ Buat Kunci Pertama", lbl_tab_all: "Semua Kunci", lbl_tab_adm: "Admin", lbl_tab_cst: "Customer", lbl_tab_trl: "Trial",
        lbl_mass: "⚡ Eksekusi Massal", lbl_mass_btn: "Eksekusi", lbl_sel_all: "Semua", lbl_view_card: "Kartu", lbl_view_table: "Tabel",
        lbl_active_keys: "Kunci Aktif", lbl_sort_exp: "Kadaluarsa", lbl_sort_cre: "Dibuat", lbl_sort_typ: "Tipe",
        lbl_f_all: "Semua", lbl_f_act: "Aktif", lbl_f_exp: "Kadaluarsa", lbl_f_dis: "Nonaktif", lbl_enable: "Aktifkan", lbl_disable: "Nonaktifkan",
        lbl_extend: "Perpanjang", lbl_reset: "Reset", lbl_log_title: "Log Aktivitas", lbl_export_log: "Ekspor", lbl_clear_log: "Hapus",
        lbl_no_log: "Belum ada aktivitas.", lbl_sellers_title: "Manajemen Penjual", lbl_add_seller: "Tambah Penjual",
        lbl_cust_title: "Database Pelanggan", lbl_export_renew: "Ekspor Pembaruan", lbl_cust_hint: "Klik pelanggan untuk melihat detail",
        lbl_gen_title: "Buat Kunci Baru", lbl_key_type: "Tipe Kunci", lbl_custom_name: "Nama Kustom", lbl_key_preview: "Pratinjau Kunci",
        lbl_quick_dur: "Durasi Cepat", lbl_dur_custom: "Durasi Kustom", lbl_qty: "Kuantitas", lbl_price_preview: "Harga Kunci",
        lbl_tags: "Tag", lbl_tags_hint: "(Enter untuk tambah)", lbl_cancel: "Batal", lbl_gen_btn: "⊕ Buat",
        lbl_link_title: "🔗 Tautkan Perangkat", lbl_link_sub: "Ikat kunci ini ke iOS atau Android", lbl_hwid: "HWID / ID Perangkat",
        lbl_os_platform: "Platform OS", lbl_cancel2: "Batal", lbl_link_btn: "Tautkan", lbl_ext_title: "⏰ Perpanjang Kunci",
        lbl_quick_sel: "Pilih Cepat", lbl_duration: "Durasi", lbl_unit: "Satuan", lbl_exact_date: "Atau tanggal tepat",
        lbl_new_expiry: "Kadaluarsa Baru", lbl_cancel3: "Batal", lbl_ext_btn: "＋ Perpanjang", lbl_det_title: "Detail Kunci",
        lbl_det_type: "Tipe", lbl_det_status: "Status", lbl_det_user: "Pengguna", lbl_det_dur: "Durasi", lbl_det_activated: "Kunci Aktif",
        lbl_det_expired: "Kunci Kadaluarsa", lbl_det_lastused: "Terakhir Digunakan", lbl_det_price: "Harga Dibayar",
        lbl_det_timeline: "Riwayat", lbl_close: "Tutup", lbl_close2: "Tutup", lbl_mass_title: "⚡ Eksekusi Massal",
        lbl_me_type: "Filter berdasarkan Tipe", lbl_me_status: "Filter berdasarkan Status", lbl_me_time: "Filter berdasarkan Waktu",
        lbl_me_prev: "Kunci cocok:", lbl_me_action: "Pilih Aksi", lbl_add_seller_title: "👥 Tambah Penjual", lbl_sr_user: "Nama Pengguna",
        lbl_sr_pass: "Kata Sandi", lbl_sr_prefix: "Prefix Kunci", lbl_sr_token: "Saldo Token Awal", lbl_sr_curr_lbl: "Mata Uang",
        lbl_sr_notes: "Catatan", lbl_pricing_title: "💰 Harga Kunci", lbl_pricing_sub: "Atur biaya token untuk setiap tipe + durasi",
        lbl_curr_title: "💱 Pengaturan Mata Uang", lbl_curr_sub: "1 Token = X unit setiap mata uang. Dasar: IDR",
        lbl_import_title: "⬆ Impor CSV", lbl_import_file: "File CSV", lbl_drop_hint: "Klik atau seret CSV ke sini",
        lbl_cancel_conf: "Batal", lbl_mo: "bln", lbl_d: "hr", lbl_h: "jam", lbl_current_bal: "Saldo Saat Ini",
        lbl_topup_action: "Aksi", lbl_topup_amount: "Jumlah (token)", lbl_topup_reason: "Alasan", lbl_nav_main2: "Menu",
        err_inv: "Nama pengguna atau kata sandi salah", err_fill: "Harap isi semua kolom",
        t_gen: "kunci berhasil dibuat", t_copy: "Disalin", t_revoke: "Dicabut", t_delete: "Dihapus", t_export: "Diekspor",
        t_logout: "Keluar", t_link: "Perangkat ditautkan", t_unlink: "Perangkat dilepas", t_enable: "Diaktifkan", t_disable: "Dinonaktifkan",
        t_reset: "Direset", t_extend: "Diperpanjang", t_mass: "kunci dieksekusi", t_topup: "Saldo token diperbarui",
        t_seller_added: "Penjual ditambahkan", t_price_saved: "Harga disimpan", t_curr_saved: "Mata uang disimpan", trialDesc: "1 Hari · 3 Hari"
      },
      vi: {
        act_view: "Xem", act_link: "Gan", act_unlink: "Go", act_restore: "Khoi phuc", act_enable: "Bat", act_disable: "Tat", act_reset: "Dat lai", lbl_btn_delete: "Xoa", st_active: "Hoat dong", st_expired: "Het han", st_revoked: "Thu hoi", st_disabled: "Vo hieu", hwid_bound: "Da gan", hwid_unbound: "Chua gan", lbl_never: "Chua bao gio", lbl_lifetime: "TRON DOI", lbl_no_keys_found: "Khong tim thay khoa", lbl_word_key: "khóa", lbl_word_keys: "khóa", lbl_btn_top_up_self: "Nạp Cho Mình", lbl_btn_refresh: "Làm mới", lbl_btn_export: "Xuất", lbl_btn_add_seller: "Thêm Đại lý", lbl_btn_add_admin: "Thêm Admin", lbl_btn_cancel: "Hủy", lbl_btn_confirm: "Xác nhận", lbl_btn_copy: "Sao chép", lbl_btn_toggle: "Bật/Tắt", lbl_btn_extend: "Gia hạn", lbl_btn_revoke: "Thu hồi", lbl_btn_apply: "Áp dụng", lbl_btn_save: "Lưu", lbl_btn_save_pricing: "Lưu Giá", lbl_btn_save_templates: "Lưu Mẫu", lbl_btn_save_changes: "Lưu Thay đổi", lbl_btn_reset: "Đặt lại", lbl_btn_import: "Nhập", lbl_btn_create_admin: "Tạo Admin", lbl_btn_create_seller: "Tạo Đại lý", lbl_btn_change: "Đổi", lbl_btn_test: "Kiểm tra", lbl_btn_clear: "Xóa", lbl_btn_undo: "Hoàn tác", lbl_btn_download_png: "Tải PNG", lbl_btn_download_template: "Tải Mẫu", lbl_btn_rate_matrix: "Bảng Giá", lbl_btn_duration_templates: "Mẫu Thời hạn", lbl_btn_extend_selected: "Gia hạn Đã chọn", lbl_btn_extend_filtered: "Gia hạn Đã lọc", lbl_btn_manage_balance: "Quản lý Số dư", lbl_btn_create_admin_account: "Tạo Tài khoản Admin", lbl_btn_edit_admin: "Sửa Admin", lbl_btn_panel_branding: "Thương hiệu Panel", lbl_btn_bulk_extend: "Gia hạn Hàng loạt", lbl_btn_manage_admins: "Quản lý Admin", lbl_btn_webhooks: "Webhook", lbl_btn_login_history: "Lịch sử Đăng nhập", lbl_ph_search_by_key_tag_gr: "Tìm khóa, #tag, @nhóm, hw:HWID…", lbl_ph_search_logs: "Tìm nhật ký…", lbl_ph_search_seller: "Tìm đại lý…", lbl_ph_search_admin: "Tìm admin…", lbl_qty_max: "(tối đa 50)", lbl_created_by: "Tạo Bởi", lbl_custom_pfx: "Prefix Tùy Chỉnh", lbl_user_label: "Nhãn Người Dùng", lbl_qty_max_hint: "tối đa 50", lbl_nav_keys: "Quản Lý Key", lbl_nav_dash: "Tổng Quan", lbl_nav_settings: "Quản Lý", lbl_enable_all: "Bật Tất Cả Key", lbl_disable_all: "Tắt Tất Cả Key", lbl_nav_sellers2: "Đại Lý", lbl_f_rev: "Đã Thu Hồi", lbl_me_seller: "Lọc theo Đại Lý", lbl_no_keys: "Không tìm thấy key", lbl_dur_custom_hint: "ngày + giờ", lbl_me_type_col: "Loại", lbl_me_status_col: "Trạng Thái", lbl_me_all_types: "Tất Cả Loại", lbl_me_all_status: "Tất Cả Trạng Thái", lbl_me_all_sellers: "Tất Cả Đại Lý", lbl_tab_adm2: "Admin", lbl_f_act2: "Hoạt Động", lbl_f_exp2: "Hết Hạn", lbl_f_dis2: "Tắt", lbl_owner_admins: "Quản Lý Admin", lbl_owner_branding: "Thương Hiệu", lbl_owner_pass: "Đổi Mật Khẩu", lbl_disable_all: "Tắt TẤT CẢ Key", lbl_enable_all: "Bật TẤT CẢ Key", lbl_total_spent: "Tổng Đã Dùng", lbl_bal_remaining: "Số Dư", lbl_last_activity: "Hoạt Động Cuối", t_mass_owner: "key đã thực thi bởi owner", lbl_nav_main2: "Bảng điều hướng", t_import: "imported",
        login: "ĐĂNG NHẬP", lbl_user: "TÊN NGƯỜI DÙNG", lbl_pass: "MẬT KHẨU", lbl_remember: "Ghi nhớ tôi", lbl_footer: "DX MODS Auth v4.0",
        lbl_sb_badge: "Bảng Đại Lý", lbl_nav_main: "Menu Chính", lbl_nav_dash: "Bảng Điều Khiển", lbl_nav_keys: "Quản Lý Key",
        lbl_nav_mass: "Thực Thi Hàng Loạt", lbl_nav_log: "Nhật Ký", lbl_nav_mgmt: "Quản Lý", lbl_nav_sellers: "Đại Lý",
        lbl_nav_cust: "Khách Hàng", lbl_nav_settings: "Cài Đặt", lbl_nav_pricing: "Giá Cả", lbl_nav_currency: "Tiền Tệ",
        lbl_nav_import: "Nhập CSV", lbl_online: "Trực Tuyến", lbl_generate: "Tạo", lbl_generate2: "Tạo",
        lbl_chart_gen: "Tạo Key (7 Ngày)", lbl_chart_dist: "Phân Bổ theo Loại", lbl_renewal_title: "Key hết hạn trong 48 giờ",
        lbl_onboard_title: "Chào mừng đến DX MODS Auth!", lbl_onboard_sub: "Chưa có key. Tạo key đầu tiên của bạn.",
        lbl_onboard_btn: "＋ Tạo Key Đầu Tiên", lbl_tab_all: "Tất Cả", lbl_tab_adm: "Admin", lbl_tab_cst: "Khách", lbl_tab_trl: "Thử",
        lbl_mass: "⚡ Thực Thi Hàng Loạt", lbl_mass_btn: "Thực Thi", lbl_sel_all: "Tất Cả", lbl_view_card: "Thẻ", lbl_view_table: "Bảng",
        lbl_active_keys: "Key Hoạt Động", lbl_sort_exp: "Hết Hạn", lbl_sort_cre: "Ngày Tạo", lbl_sort_typ: "Loại",
        lbl_f_all: "Tất Cả", lbl_f_act: "Hoạt Động", lbl_f_exp: "Hết Hạn", lbl_f_dis: "Tắt", lbl_enable: "Bật", lbl_disable: "Tắt",
        lbl_extend: "Gia Hạn", lbl_reset: "Đặt Lại", lbl_log_title: "Nhật Ký Hoạt Động", lbl_export_log: "Xuất", lbl_clear_log: "Xóa",
        lbl_no_log: "Chưa có hoạt động.", lbl_sellers_title: "Quản Lý Đại Lý", lbl_add_seller: "Thêm Đại Lý",
        lbl_cust_title: "Cơ Sở Dữ Liệu Khách", lbl_export_renew: "Xuất Danh Sách Gia Hạn", lbl_cust_hint: "Nhấp vào khách để xem chi tiết",
        lbl_gen_title: "Tạo Key Mới", lbl_key_type: "Loại Key", lbl_custom_name: "Tên Tùy Chỉnh", lbl_key_preview: "Xem Trước Key",
        lbl_quick_dur: "Thời Hạn Nhanh", lbl_dur_custom: "Thời Hạn Tùy Chỉnh", lbl_qty: "Số Lượng", lbl_price_preview: "Giá Key",
        lbl_tags: "Nhãn", lbl_tags_hint: "(Enter để thêm)", lbl_cancel: "Hủy", lbl_gen_btn: "⊕ Tạo",
        lbl_link_title: "🔗 Liên Kết Thiết Bị", lbl_link_sub: "Liên kết key này với iOS hoặc Android", lbl_hwid: "HWID",
        lbl_os_platform: "Nền Tảng OS", lbl_cancel2: "Hủy", lbl_link_btn: "Liên Kết", lbl_ext_title: "⏰ Gia Hạn Key",
        lbl_quick_sel: "Chọn Nhanh", lbl_duration: "Thời Hạn", lbl_unit: "Đơn Vị", lbl_exact_date: "Hoặc ngày chính xác",
        lbl_new_expiry: "Hết Hạn Mới", lbl_cancel3: "Hủy", lbl_ext_btn: "＋ Gia Hạn", lbl_det_title: "Chi Tiết Key",
        lbl_det_type: "Loại", lbl_det_status: "Trạng Thái", lbl_det_user: "Người Dùng", lbl_det_dur: "Thời Hạn",
        lbl_det_activated: "Kích Hoạt", lbl_det_expired: "Hết Hạn", lbl_det_lastused: "Lần Cuối Dùng", lbl_det_price: "Giá Đã Trả",
        lbl_det_timeline: "Lịch Sử", lbl_close: "Đóng", lbl_close2: "Đóng", lbl_mass_title: "⚡ Thực Thi Hàng Loạt",
        lbl_me_type: "Lọc theo Loại", lbl_me_status: "Lọc theo Trạng Thái", lbl_me_time: "Lọc theo Thời Gian",
        lbl_me_prev: "Key phù hợp:", lbl_me_action: "Chọn Hành Động", lbl_add_seller_title: "👥 Thêm Đại Lý",
        lbl_sr_user: "Tên Người Dùng", lbl_sr_pass: "Mật Khẩu", lbl_sr_prefix: "Tiền Tố Key", lbl_sr_token: "Số Dư Token Ban Đầu",
        lbl_sr_curr_lbl: "Tiền Tệ", lbl_sr_notes: "Ghi Chú", lbl_pricing_title: "💰 Giá Key", lbl_pricing_sub: "Đặt chi phí token",
        lbl_curr_title: "💱 Cài Đặt Tiền Tệ", lbl_curr_sub: "1 Token = X đơn vị mỗi tiền tệ. Cơ sở: IDR",
        lbl_import_title: "⬆ Nhập CSV", lbl_import_file: "File CSV", lbl_drop_hint: "Nhấp hoặc kéo CSV vào đây",
        lbl_cancel_conf: "Hủy", lbl_mo: "th", lbl_d: "ng", lbl_h: "h", lbl_current_bal: "Số Dư Hiện Tại",
        lbl_topup_action: "Hành Động", lbl_topup_amount: "Số Lượng (token)", lbl_topup_reason: "Lý Do", lbl_nav_main2: "Menu",
        err_inv: "Tên hoặc mật khẩu sai", err_fill: "Vui lòng điền đủ",
        t_gen: "key đã tạo", t_copy: "Đã sao chép", t_revoke: "Đã thu hồi", t_delete: "Đã xóa", t_export: "Đã xuất",
        t_logout: "Đã đăng xuất", t_link: "Đã liên kết", t_unlink: "Đã hủy liên kết", t_enable: "Đã bật", t_disable: "Đã tắt",
        t_reset: "Đã đặt lại", t_extend: "Đã gia hạn", t_mass: "key đã thực thi", t_topup: "Số dư token đã cập nhật",
        t_seller_added: "Đã thêm đại lý", t_price_saved: "Đã lưu giá", t_curr_saved: "Đã lưu tiền tệ", trialDesc: "1 Ngày · 3 Ngày"
      },
      zh: {
        act_view: "查看", act_link: "绑定", act_unlink: "解绑", act_restore: "恢复", act_enable: "启用", act_disable: "禁用", act_reset: "重置", lbl_btn_delete: "删除", st_active: "有效", st_expired: "已过期", st_revoked: "已撤销", st_disabled: "已禁用", hwid_bound: "已绑定", hwid_unbound: "未绑定", lbl_never: "从未", lbl_lifetime: "永久", lbl_no_keys_found: "未找到密钥", lbl_word_key: "个密钥", lbl_word_keys: "个密钥", lbl_btn_top_up_self: "自充值", lbl_btn_refresh: "刷新", lbl_btn_export: "导出", lbl_btn_add_seller: "添加卖家", lbl_btn_add_admin: "添加管理员", lbl_btn_cancel: "取消", lbl_btn_confirm: "确认", lbl_btn_copy: "复制", lbl_btn_toggle: "切换", lbl_btn_extend: "延长", lbl_btn_revoke: "撤销", lbl_btn_apply: "应用", lbl_btn_save: "保存", lbl_btn_save_pricing: "保存价格", lbl_btn_save_templates: "保存模板", lbl_btn_save_changes: "保存更改", lbl_btn_reset: "重置", lbl_btn_import: "导入", lbl_btn_create_admin: "创建管理员", lbl_btn_create_seller: "创建卖家", lbl_btn_change: "更改", lbl_btn_test: "测试", lbl_btn_clear: "清除", lbl_btn_undo: "撤销", lbl_btn_download_png: "下载PNG", lbl_btn_download_template: "下载模板", lbl_btn_rate_matrix: "价格矩阵", lbl_btn_duration_templates: "时长模板", lbl_btn_extend_selected: "延长所选", lbl_btn_extend_filtered: "延长筛选", lbl_btn_manage_balance: "管理余额", lbl_btn_create_admin_account: "创建管理员账户", lbl_btn_edit_admin: "编辑管理员", lbl_btn_panel_branding: "面板品牌", lbl_btn_bulk_extend: "批量延长", lbl_btn_manage_admins: "管理管理员", lbl_btn_webhooks: "Webhook", lbl_btn_login_history: "登录历史", lbl_ph_search_by_key_tag_gr: "搜索密钥、#标签、@组、hw:HWID…", lbl_ph_search_logs: "搜索日志…", lbl_ph_search_seller: "搜索卖家…", lbl_ph_search_admin: "搜索管理员…", lbl_qty_max: "(最多50)", lbl_created_by: "创建者", lbl_custom_pfx: "自定义前缀", lbl_user_label: "用户标签", lbl_qty_max_hint: "最多50", lbl_nav_keys: "密钥管理", lbl_nav_dash: "仪表板", lbl_nav_settings: "管理", lbl_nav_sellers2: "销售商", lbl_f_rev: "已撤销", lbl_me_seller: "按销售商筛选", lbl_no_keys: "未找到密钥", lbl_dur_custom_hint: "天 + 小时", lbl_me_type_col: "类型", lbl_me_status_col: "状态", lbl_me_all_types: "全部类型", lbl_me_all_status: "全部状态", lbl_me_all_sellers: "全部销售商", lbl_tab_adm2: "管理员", lbl_f_act2: "活跃", lbl_f_exp2: "过期", lbl_f_dis2: "禁用", lbl_owner_admins: "管理账号", lbl_owner_branding: "品牌定制", lbl_owner_pass: "修改密码", lbl_disable_all: "禁用所有密钥", lbl_enable_all: "启用所有密钥", lbl_total_spent: "总消费", lbl_bal_remaining: "余额", lbl_last_activity: "最近活动", t_mass_owner: "个密钥已由owner执行", t_import: "imported",
        login: "登 录", lbl_user: "用户名", lbl_pass: "密码", lbl_remember: "记住我", lbl_footer: "DX MODS Auth v4.0",
        lbl_sb_badge: "经销商控制台", lbl_nav_main: "主菜单", lbl_nav_dash: "仪表板", lbl_nav_keys: "密钥管理",
        lbl_nav_mass: "批量执行", lbl_nav_log: "活动日志", lbl_nav_mgmt: "管理", lbl_nav_sellers: "销售商",
        lbl_nav_cust: "客户", lbl_nav_settings: "设置", lbl_nav_pricing: "定价", lbl_nav_currency: "货币",
        lbl_nav_import: "导入CSV", lbl_online: "在线", lbl_generate: "生成", lbl_generate2: "生成",
        lbl_chart_gen: "密钥生成（7天）", lbl_chart_dist: "按类型分布", lbl_renewal_title: "48小时内到期的密钥",
        lbl_onboard_title: "欢迎使用 DX MODS Auth！", lbl_onboard_sub: "暂无密钥。生成您的第一个密钥。",
        lbl_onboard_btn: "＋ 生成第一个密钥", lbl_tab_all: "所有密钥", lbl_tab_adm: "管理员", lbl_tab_cst: "客户", lbl_tab_trl: "试用",
        lbl_mass: "⚡ 批量执行", lbl_mass_btn: "执行", lbl_sel_all: "全选", lbl_view_card: "卡片", lbl_view_table: "表格",
        lbl_active_keys: "活跃密钥", lbl_sort_exp: "到期", lbl_sort_cre: "创建日期", lbl_sort_typ: "类型",
        lbl_f_all: "全部", lbl_f_act: "活跃", lbl_f_exp: "过期", lbl_f_dis: "已禁用", lbl_enable: "启用", lbl_disable: "禁用",
        lbl_extend: "延长", lbl_reset: "重置", lbl_log_title: "活动日志", lbl_export_log: "导出", lbl_clear_log: "清除",
        lbl_no_log: "暂无活动。", lbl_sellers_title: "销售商管理", lbl_add_seller: "添加销售商",
        lbl_cust_title: "客户数据库", lbl_export_renew: "导出续费列表", lbl_cust_hint: "点击客户查看详情",
        lbl_gen_title: "生成新密钥", lbl_key_type: "密钥类型", lbl_custom_name: "自定义名称", lbl_key_preview: "密钥预览",
        lbl_quick_dur: "快速选择时长", lbl_dur_custom: "自定义时长", lbl_qty: "数量", lbl_price_preview: "密钥价格",
        lbl_tags: "标签", lbl_tags_hint: "(回车添加)", lbl_cancel: "取消", lbl_gen_btn: "⊕ 生成",
        lbl_link_title: "🔗 绑定设备", lbl_link_sub: "将此密钥绑定到iOS或Android", lbl_hwid: "HWID / 设备ID",
        lbl_os_platform: "操作系统", lbl_cancel2: "取消", lbl_link_btn: "绑定", lbl_ext_title: "⏰ 延长密钥",
        lbl_quick_sel: "快速选择", lbl_duration: "时长", lbl_unit: "单位", lbl_exact_date: "或指定日期",
        lbl_new_expiry: "新到期时间", lbl_cancel3: "取消", lbl_ext_btn: "＋ 延长", lbl_det_title: "密钥详情",
        lbl_det_type: "类型", lbl_det_status: "状态", lbl_det_user: "用户", lbl_det_dur: "时长", lbl_det_activated: "激活时间",
        lbl_det_expired: "到期时间", lbl_det_lastused: "最后使用", lbl_det_price: "已付价格", lbl_det_timeline: "生命周期",
        lbl_close: "关闭", lbl_close2: "关闭", lbl_mass_title: "⚡ 批量执行", lbl_me_type: "按类型筛选",
        lbl_me_status: "按状态筛选", lbl_me_time: "按时间筛选", lbl_me_prev: "匹配密钥：", lbl_me_action: "选择操作",
        lbl_add_seller_title: "👥 添加销售商", lbl_sr_user: "用户名", lbl_sr_pass: "密码", lbl_sr_prefix: "密钥前缀",
        lbl_sr_token: "初始代币余额", lbl_sr_curr_lbl: "货币", lbl_sr_notes: "备注", lbl_pricing_title: "💰 密钥定价",
        lbl_pricing_sub: "为每种密钥类型+时长设置代币成本", lbl_curr_title: "💱 货币设置",
        lbl_curr_sub: "1代币=X单位货币。基础：IDR", lbl_import_title: "⬆ 导入CSV", lbl_import_file: "CSV文件",
        lbl_drop_hint: "点击或拖放CSV文件", lbl_cancel_conf: "取消", lbl_mo: "月", lbl_d: "天", lbl_h: "时",
        lbl_current_bal: "当前余额", lbl_topup_action: "操作", lbl_topup_amount: "数量（代币）", lbl_topup_reason: "原因",
        lbl_nav_main2: "菜单", err_inv: "用户名或密码错误", err_fill: "请填写所有字段",
        t_gen: "个密钥已生成", t_copy: "已复制", t_revoke: "已撤销", t_delete: "已删除", t_export: "已导出",
        t_logout: "已登出", t_link: "设备已绑定", t_unlink: "设备已解绑", t_enable: "已启用", t_disable: "已禁用",
        t_reset: "已重置", t_extend: "已延长", t_mass: "个密钥已执行", t_topup: "代币余额已更新",
        t_seller_added: "已添加销售商", t_price_saved: "价格已保存", t_curr_saved: "货币已保存", trialDesc: "1天 · 3天"
      }
    };
    let lang = "en";
    const T = k => (LG[lang] && LG[lang][k] !== undefined ? LG[lang][k] : LG.en[k]) || k;

    
    function setLang(l, el) {
      if (!l) l = "vi";
      lang = l;
      try { localStorage.setItem("dx_lang", l); } catch(e){}
      
      // Sync langSelect dropdown if present
      const ls = document.getElementById("langSelect");
      if (ls && ls.value !== l) ls.value = l;

      // Update all elements with id matching lbl_* keys
      document.querySelectorAll("[id^='lbl_']").forEach(function (e) {
        const t = T(e.id);
        if (t && t !== e.id && e.tagName !== "INPUT" && e.tagName !== "SELECT" && e.tagName !== "TEXTAREA") {
          e.textContent = t;
        }
      });
      // Update elements with data-i18n attribute
      document.querySelectorAll("[data-i18n]").forEach(function (e) {
        const key = e.getAttribute("data-i18n");
        const t = T(key);
        if (t && t !== key) {
          if (e.tagName === "INPUT" || e.tagName === "TEXTAREA") e.placeholder = t;
          else e.textContent = t;
        }
      });
      // Update placeholders with data-i18n-ph attribute
      document.querySelectorAll("[data-i18n-ph]").forEach(function (e) {
        const key = e.getAttribute("data-i18n-ph");
        const t = T(key);
        if (t && t !== key) e.placeholder = t;
      });
      // Update page title
      const pageNames = { 
        dashboard: T("lbl_nav_dash"), 
        keys: T("lbl_nav_keys"), 
        log: T("lbl_nav_log") || T("lbl_log_title"), 
        sellers: T("lbl_nav_sellers") || T("lbl_sellers_title"), 
        owners_admins: T("lbl_owner_admins") 
      };
      const pt = document.getElementById("pageTitle");
      if (pt && pageNames[currentPage]) pt.textContent = pageNames[currentPage];

      // Lang buttons
      document.querySelectorAll(".lbtn-lang").forEach(b => {
        b.classList.remove("on");
        if (el && b === el) { b.classList.add("on"); return; }
        const flags = { en: "EN", id: "ID", vi: "VI", zh: "ZH" };
        if (!el && (b.textContent.includes(flags[l]) || b.dataset.lang === l)) b.classList.add("on");
      });
      if (el) el.classList.add("on");

      // Update login button & trial desc
      const lb = document.getElementById("lbtnEl"); if (lb) lb.textContent = T("login");
      const td = document.getElementById("trialDesc"); if (td) td.textContent = T("trialDesc");

      // Re-render ALL dynamic components immediately in pure selected language
      if (typeof renderCards === "function" && currentPage === "keys") renderCards();
      if (typeof renderLog === "function" && currentPage === "log") renderLog();
      if (typeof renderDashboard === "function" && currentPage === "dashboard") renderDashboard();
      if (typeof renderSellersList === "function" && currentPage === "sellers") renderSellersList();
      if (typeof renderOwnerAdminsList === "function" && currentPage === "owners_admins") renderOwnerAdminsList();
    }

    // Auto-initialize saved language on load
    document.addEventListener("DOMContentLoaded", function() {
      const savedLang = (function(){ try{ return localStorage.getItem("dx_lang"); }catch(e){ return "vi"; } })() || "vi";
      setLang(savedLang);
    });
    (function () {
      if ('ontouchstart' in window) return; // skip on touch devices
      const clrs = ["rgba(0,200,255,.55)", "rgba(136,51,255,.45)", "rgba(0,229,160,.45)", "rgba(0,85,255,.4)"];
      let lx = 0, ly = 0, thr = 0;
      document.addEventListener("mousemove", ev => {
        const now = Date.now(); if (now - thr < 40) return; thr = now;
        const dx = Math.abs(ev.clientX - lx), dy = Math.abs(ev.clientY - ly); if (dx < 4 && dy < 4) return;
        lx = ev.clientX; ly = ev.clientY;
        const sz = 3 + Math.random() * 5; const s = document.createElement("div"); s.className = "cursor-spark";
        s.style.cssText = `left:${lx - sz / 2}px;top:${ly - sz / 2}px;width:${sz}px;height:${sz}px;background:${clrs[Math.floor(Math.random() * clrs.length)]};animation-duration:${.35 + Math.random() * .2}s`;
        document.body.appendChild(s); setTimeout(() => s.remove(), 550);
      });
    })();

    /* ══ SIDEBAR ══ */
    let sbCollapsed = false;
    function toggleSidebar() {
      sbCollapsed = !sbCollapsed;
      const sb = document.getElementById("sidebar");
      sb.classList.toggle("hidden", sbCollapsed);
      // Inline reopen button in topbar (no overlap with content)
      const inlineBtn = document.getElementById("sbReopenInline");
      if (inlineBtn) inlineBtn.style.display = sbCollapsed ? "flex" : "none";
      const tgl = document.getElementById("sbToggle"); if (tgl) tgl.textContent = "\u25c0";
      localStorage.setItem("sbCollapsed", sbCollapsed ? "1" : "0");
    }
    function toggleMobile() {
      const sb = document.getElementById("sidebar"), ov = document.getElementById("sbOverlay");
      sb.classList.toggle("mobile-open");
      document.body.classList.toggle("mobile-open", sb.classList.contains("mobile-open")); ov.classList.toggle("show");
    }
    function closeMobile() { document.getElementById("sidebar").classList.remove("mobile-open"); document.getElementById("sbOverlay").classList.remove("show"); }
    (function () { if (localStorage.getItem("sbCollapsed") === "1") { sbCollapsed = false; toggleSidebar(); } })();;

    /* ══ AUTH + USERS ══ */
    const ADMIN_USERS = { "x3store_admin": "X3Team" }; // Only super admin remains
    let loggedUser = null, loggedRole = "admin", loggedSeller = null, loggedAdmin = null, passVis = false;
    let sellers = secLoad("lnSellers", []);
    function saveSellers() { secSave("lnSellers", sellers); }

    function checkLogin(u, p) {
      // Rate limit check
      const rl = _canAttemptLogin(u);
      if (!rl.ok) return { role: "ratelimited", user: u, wait: rl.wait };
      // Owner check (highest privilege)
      if (u === OWNER_NAME && p === getOwnerPass()) { _clearLoginAttempts(u); return { role: "owner", user: u }; }
      // Dynamic admin accounts
      const adm = adminAccounts.find(function (a) { return a.name === u; });
      if (adm) {
        // Check password (supports both old btoa and new hash formats)
        const stored = adm.pass || "";
        let ok = false;
        if (stored.startsWith("h1$") || stored.startsWith("b1$")) {
          ok = stored === "b1$" + btoa(p); // sync check for new format
        } else {
          try { ok = atob(stored) === p; } catch (e) { ok = false; }
        }
        if (!ok) { _recordFailedLogin(u); return null; }
        _clearLoginAttempts(u);
        if (adm.disabled) return { role: "blocked", user: u };
        return { role: adm.type === "super_admin" ? "super_admin" : "admin", user: u, admin: adm };
      }
      // Legacy static admins (still hardcoded — only x3store_admin remains)
      if (ADMIN_USERS[u] === p) { _clearLoginAttempts(u); return { role: "super_admin", user: u }; }
      // Seller check (supports both old btoa and new hash formats)
      const sl = sellers.find(function (x) { return x.name === u; });
      if (sl) {
        const sStored = sl.pass || "";
        let sOk = false;
        if (sStored.startsWith("h1$") || sStored.startsWith("b1$")) { sOk = sStored === "b1$" + btoa(p); }
        else { try { sOk = atob(sStored) === p; } catch (e) { sOk = false; } }
        if (!sOk) { _recordFailedLogin(u); return null; }
        _clearLoginAttempts(u);
        if (sl.disabled) return { role: "blocked", user: u };
        return { role: "seller", user: u, seller: sl };
      }
      _recordFailedLogin(u);
      return null;
    }
    function togglePass() { passVis = !passVis; document.getElementById("linPass").type = passVis ? "text" : "password"; }
    function checkPassStrength(p) {
      const bar = document.getElementById("passStrBar"), lbl = document.getElementById("passStrLbl");
      if (!bar || !lbl) return;
      if (!p) { bar.style.display = "none"; lbl.style.display = "none"; return; }
      bar.style.display = "block"; lbl.style.display = "block";
      let s = 0; if (p.length >= 6) s++; if (p.length >= 10) s++; if (/[A-Z]/.test(p)) s++; if (/[0-9]/.test(p)) s++; if (/[^A-Za-z0-9]/.test(p)) s++;
      const L = [{ l: "Weak", c: "var(--red)" }, { l: "Fair", c: "var(--orange)" }, { l: "Good", c: "var(--yellow)" }, { l: "Strong", c: "var(--green)" }];
      const lv = L[Math.min(Math.floor(s / 1.3), 3)];
      bar.style.cssText = `display:block;height:3px;border-radius:2px;transition:all .3s;background:${lv.c};width:${25 * (Math.min(Math.floor(s / 1.3), 3) + 1)}%`;
      lbl.style.cssText = `display:block;font-size:9.5px;margin-top:2px;font-family:'JetBrains Mono',monospace;color:${lv.c}`;
      lbl.textContent = lv.l;
    }
    function saveRemember(u, p) { const cb = document.getElementById("rememberCb"); if (cb && cb.checked) localStorage.setItem("lnRemember", btoa(JSON.stringify({ u, p }))); else localStorage.removeItem("lnRemember"); }
    (function () {
      const s = localStorage.getItem("lnRemember");
      if (s) { try { const d = JSON.parse(atob(s)); if (document.getElementById("linUser")) document.getElementById("linUser").value = d.u || ""; if (document.getElementById("linPass")) document.getElementById("linPass").value = d.p || ""; if (document.getElementById("rememberCb")) document.getElementById("rememberCb").checked = true; } catch (e) { } }
    })();

    function doLogin() {
      const u = document.getElementById("linUser").value.trim(), p = document.getElementById("linPass").value;
      const btn = document.getElementById("lbtnEl"), err = document.getElementById("lerr");
      err.style.display = "none";
      if (!u || !p) { document.getElementById("lerrMsg").textContent = T("err_fill"); err.style.display = "flex"; return; }
      btn.classList.add("loading"); btn.textContent = "";
      setTimeout(() => {
        btn.classList.remove("loading"); btn.textContent = T("login");
        const res = checkLogin(u, p);
        if (res) {
          if (res.role === "blocked") {
            document.getElementById("lerrMsg").textContent = "Account disabled. Contact your administrator.";
            document.getElementById("lerr").style.display = "flex";
            btn.classList.remove("loading"); btn.textContent = T("login"); return;
          }
          loggedUser = u; loggedRole = res.role;
          loggedSeller = res.seller || null;
          loggedAdmin = res.admin || null;
          _recordLogin(u, res.role); if (res.role !== "seller") notifyWebhook("🔑 Login: **" + u + "** (" + res.role + ")" + (new Date().toLocaleTimeString()), "login");
          setTimeout(_checkFirstTimeSetup, 1200);
          applyRoleRestrictions();
          _initCurrency();
          _initIdleTracking();
          saveRemember(u, p);
          const ls = document.getElementById("loginScreen");
          ls.style.transition = "opacity .35s"; ls.style.opacity = "0";
          setTimeout(() => {
            ls.style.display = "none"; document.getElementById("app").style.display = "block";
            initApp();
          }, 380);
        } else { document.getElementById("lerrMsg").textContent = T("err_inv"); err.style.display = "flex"; }
      }, 700);
    }
    function initApp() {
      // Theme
      const thm = localStorage.getItem("lnTheme_" + loggedUser) || localStorage.getItem("lnTheme") || "dark";
      document.body.className = document.body.className.replace(/theme-\w+/g, "").trim();
      document.body.classList.add("theme-" + thm);
      const T2 = ["dark", "light", "neon", "gaming", "cyber", "ocean"];
      document.querySelectorAll(".theme-dot").forEach(function (d, i) { d.classList.toggle("active", T2[i] === thm); });
      // User info
      const sbAv = document.getElementById("sbAv"); if (sbAv) sbAv.textContent = loggedUser.substring(0, 2).toUpperCase();
      const sbUn = document.getElementById("sbUn"); if (sbUn) sbUn.textContent = loggedUser;
      // Role flags
      const isOwner = loggedRole === "owner";
      const isAdmin = loggedRole === "admin" || loggedRole === "super_admin" || isOwner;
      const isSeller = loggedRole === "seller";
      // Role badge
      const rolEl = document.getElementById("sbRol");
      if (rolEl) {
        const labels = { owner: "⚡ OWNER", super_admin: "★ SUPER ADMIN", admin: "● ADMIN", seller: "● SELLER" };
        rolEl.textContent = labels[loggedRole] || "● USER";
        rolEl.className = "sb-rol " + (isOwner ? "owner" : isSeller ? "seller" : "admin");
      }
      // Nav visibility
      const navAdmin = document.getElementById("navAdmin"); if (navAdmin) navAdmin.style.display = isAdmin ? "" : "none";
      const navSeller = document.getElementById("navSeller"); if (navSeller) navSeller.style.display = isSeller ? "" : "none";
      const navOwner = document.getElementById("navOwner"); if (navOwner) navOwner.style.display = isOwner ? "block" : "none";
      // Topbar buttons
      const adminTB = document.getElementById("adminTopBtns"); if (adminTB) adminTB.style.display = isAdmin ? "" : "none";
      const sellerTB = document.getElementById("sellerTopBtns"); if (sellerTB) sellerTB.style.display = isSeller ? "" : "none";
      const icb = document.getElementById("importCsvBtn"); if (icb) icb.style.display = isAdmin ? "" : "none";
      // Owner-only sidebar items — FORCE show for owner
      document.querySelectorAll(".owner-only").forEach(function (el) {
        el.style.setProperty("display", isOwner ? "flex" : "none", "important");
      });
      // niSellersAdmin: visible for admin only (owner/super_admin delegasikan ke admin)
      const nsa = document.getElementById("niSellersAdmin"); if (nsa) nsa.style.display = (loggedRole === "admin") ? "flex" : "none";
      // Currency
      buildCurrSelect();
      const cs = document.getElementById("currSelect"); if (cs) cs.style.display = "";
      // Token display
      updateTokenDisplay();
      // Language
      const sl = localStorage.getItem("lnLang") || "en";
      setLang(sl);
      const langSel = document.getElementById("langSelect"); if (langSel) langSel.value = sl;
      // Branding
      setTimeout(applyBranding, 80);
      // Data
      updateStats();
      buildOwnerFilterRow();
      buildCreatorFilterRow();
      /* buildDashViewChips removed */

      // Restore filter state
      try {
        const sf = sessionStorage.getItem("lnFilt");
        if (sf) { const d = JSON.parse(sf); if (d.activeFilts) activeFilts = new Set(d.activeFilts); if (d.searchQ) searchQ = d.searchQ; }
      } catch (e) { }
      addLog("⭐", "Session started: " + loggedUser, "", "auth", { note: _getDeviceInfo().summary });
      switchPage("dashboard");
      startAutoRefresh();
    }

    function doLogout() {
      confirm2("Logout", "Sure to logout?", "⏻", () => {
        _clearAllTimers();
        clearTimeout(_idleTimer); clearTimeout(_idleWarnTimer); if (_idleCountdown) clearInterval(_idleCountdown);
        document.getElementById("app").style.display = "none";
        const ls = document.getElementById("loginScreen"); if (ls) { ls.style.opacity = "0"; ls.style.display = "flex"; }
        requestAnimationFrame(() => { ls.style.transition = "opacity .35s"; ls.style.opacity = "1"; });
        const cb = document.getElementById("rememberCb");
        if (!cb || !cb.checked) localStorage.removeItem("lnRemember");
        loggedUser = null; loggedRole = "admin"; loggedSeller = null;
        toast(T("t_logout"), "i");
      });
    }
    document.addEventListener("keydown", e => {
      if (e.key === "Enter" && document.getElementById("loginScreen").style.display !== "none" && !loggedUser) { doLogin(); return; }
      if (!loggedUser) return;
      if (e.key === "Escape") { document.querySelectorAll(".overlay.open").forEach(o => { if (o.id !== "confModal") o.classList.remove("open"); }); return; }
      if ((e.metaKey || e.ctrlKey) && e.key === "n") { e.preventDefault(); openGenModal(); return; }
      if ((e.metaKey || e.ctrlKey) && e.key === "e" && loggedRole === "admin") { e.preventDefault(); exportKeys(); return; }
      if (e.key === "/" && !e.target.closest("input,textarea,select")) { e.preventDefault(); const si = document.getElementById("searchInp"); if (si) { switchPage("keys"); si.focus(); } }
      if (e.key === "ArrowDown" && !e.target.closest("input,textarea,select")) { e.preventDefault(); kbNav(1); }
      if (e.key === "ArrowUp" && !e.target.closest("input,textarea,select")) { e.preventDefault(); kbNav(-1); }
    });

    /* ══ STATE ══ */
    let keys = secLoad("lnKeysV8", []);
    let expArchive = secLoad("lnExpV8", []);
    const MS = { hours: 3600000, days: 86400000, months: 2592000000 };
    function save() {
      _lastDataVer = (_lastDataVer || 0) + 1; _invalidateFilterCache && _invalidateFilterCache();
      secSave("lnKeysV8", keys);
      secSave("lnDataVer", Date.now());
      updateExpireBadge(); // update badge for efficient sync
      if (loggedUser) { buildCreatorFilterRow(); buildOwnerFilterRow(); }
    }
    function saveArch() { secSave("lnExpV8", expArchive); }
    // Migrate
    (function () { for (const k of ["lnKeysV7", "lnkeys_v6", "lnkeys_v5"]) { const old = localStorage.getItem(k); if (old && !keys.length) { try { keys = JSON.parse(old); save(); break; } catch (e) { } } } })();

    let filt = "all", searchQ = "", selTypeV = "customer", selOsV = "", selected = new Set();
    let pendingTags = [], extKeyId = null, linkKeyId = null, detId = null, confCb = null, undoCb = null;
    let meTypeF = "all", meStatusF = "all", meTimeF = "all";
    let currentPage = "dashboard", viewMode = "card", pgPage = 1, pgSizeOld = 20;
    let sortBy = "expiry", sortDir = 1;
    let isLifetime = false, selPresetDur = null;
    let undoTimer = null, kbSelIdx = -1;
    let pendingImport = [];
    let salesPeriod = "7d";

    /* ══ CURRENCY ══ */
    const CURRENCIES = {
      IDR: { sym: "Rp", name: "Indonesian Rupiah", rate: 1 },
      USD: { sym: "$", name: "US Dollar", rate: 0.000063 },
      EUR: { sym: "€", name: "Euro", rate: 0.000058 },
      GBP: { sym: "£", name: "British Pound", rate: 0.000050 },
      JPY: { sym: "¥", name: "Japanese Yen", rate: 0.0094 },
      CNY: { sym: "¥", name: "Chinese Yuan", rate: 0.00046 },
      VND: { sym: "₫", name: "Vietnamese Dong", rate: 1.6 },
      MYR: { sym: "RM", name: "Malaysian Ringgit", rate: 0.000295 },
      SGD: { sym: "S$", name: "Singapore Dollar", rate: 0.000085 },
      PHP: { sym: "₱", name: "Philippine Peso", rate: 0.00358 }
    };
    let currSettings = secLoad("lnCurrV1", { IDR: 1, USD: 0.000063, EUR: 0.000058, GBP: 0.000050, JPY: 0.0094, CNY: 0.00046, VND: 1.6, MYR: 0.000295, SGD: 0.000085, PHP: 0.00358 });
    let activeCurr = localStorage.getItem("lnActiveCurr") || "IDR";

    function fmtMoney(tokens) {
      const rate = currSettings[activeCurr] || 1;
      const sym = (CURRENCIES[activeCurr] && CURRENCIES[activeCurr].sym) || "Rp";
      const amt = (tokens * rate);
      // No-decimal currencies
      const noDecimals = ["IDR", "JPY", "VND", "KRW"];
      if (noDecimals.includes(activeCurr)) {
        return sym + " " + Math.round(amt).toLocaleString("en-US");
      }
      return sym + " " + amt.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    }
    function onCurrChange(c) {
      activeCurr = c;
      localStorage.setItem("lnActiveCurr", c);
      // Sync the topbar currency selector UI
      const cs = document.getElementById("currSelect"); if (cs && cs.value !== c) cs.value = c;
      // Update every money display across the app
      updateTokenDisplay();

      if (typeof onGenChange === "function") onGenChange();
      if (typeof updateKeyDetailPreview === "function") updateKeyDetailPreview();
      // Re-render current page so all prices/balances refresh instantly
      if (currentPage === "keys" && typeof renderCards === "function") renderCards();
      if (currentPage === "dashboard" && typeof renderDashboard === "function") renderDashboard();
      if (currentPage === "sellers" && typeof renderSellersList === "function") renderSellersList();
      if (currentPage === "owners_admins" && typeof renderOwnerAdminsList === "function") renderOwnerAdminsList();
      if (currentPage === "log" && typeof renderLog === "function") renderLog();
      // Pricing modal: re-render values HANYA jika sedang terbuka (jangan pop-open otomatis)
      {
        const _pm = document.getElementById("pricingModal");
        if (_pm && _pm.classList.contains("open") && typeof openPricingModal === "function") openPricingModal();
      }
      if (typeof buildDurPresets === "function") buildDurPresets();
      toast("Currency: " + c, "i");
    }
    function buildCurrSelect() {
      const cs = document.getElementById("currSelect"); if (!cs) return;
      cs.innerHTML = Object.entries(CURRENCIES).map(([k, v]) => `<option value="${k}"${k === activeCurr ? " selected" : ""}>${v.sym} ${k}</option>`).join("");
      cs.style.display = "";
    }
    (function () { activeCurr = localStorage.getItem("lnActiveCurr") || "IDR"; })();

    /* ══ PRICING ══ */
    // Presets: {type_durKey: tokenCost}  durKey = "1h","3d","7d","14d","30d","60d","90d","lifetime"
    let pricing = secLoad("lnPricingV1", {
      admin_4h: 2000, admin_1d: 5000, admin_3d: 12000, admin_7d: 25000, admin_30d: 80000, admin_lifetime: 200000,
      customer_4h: 1000, customer_1d: 3000, customer_3d: 7000, customer_7d: 15000, customer_30d: 50000,
      trial_4h: 500, trial_1d: 1000, trial_3d: 2500
    });
    function savePricing() { secSave("lnPricingV1", pricing); }
    const PRESET_DURS = {
      admin: [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }, { k: "7d", l: "7 Days" }, { k: "30d", l: "30 Days" }, { k: "lifetime", l: "∞ Lifetime" }],
      customer: [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }, { k: "7d", l: "7 Days" }, { k: "30d", l: "30 Days" }],
      trial: [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }]
    };
    function durKeyToMs(k) {
      if (k === "lifetime") return null;
      if (k === "1h") return MS.hours;
      if (k === "4h") return 4 * MS.hours;
      if (k === "1d") return MS.days;
      const m = k.match(/^(\d+)(d|h|mo)$/);
      if (!m) return null;
      const n = parseInt(m[1]);
      if (m[2] === "h") return n * MS.hours;
      if (m[2] === "d") return n * MS.days;
      if (m[2] === "mo") return n * MS.months;
      return null;
    }
    function durKeyLabel(k) {
      // Look up in all preset lists first
      for (const type of ["admin", "customer", "trial"]) {
        const found = (PRESET_DURS[type] || []).find(function (p) { return p.k === k; });
        if (found) return found.l;
      }
      // Fallback: parse from key string
      if (k === "lifetime") return "∞ Lifetime";
      const m = k.match(/^(\d+)(h|d|mo)$/);
      if (!m) return k;
      const n = parseInt(m[1]);
      if (m[2] === "h") return n + (n === 1 ? " Hour" : " Hours");
      if (m[2] === "d") return n + (n === 1 ? " Day" : " Days");
      if (m[2] === "mo") return n + (n === 1 ? " Month" : " Months");
      return k;
    }
    function getPricingKey() {
      if (!selPresetDur) return null;
      return selTypeV + "_" + selPresetDur;
    }
    function getTokenCost() {
      const pk = getPricingKey();
      if (!pk) return 0;
      return pricing[pk] || 0;
    }
    function getSellerBalance() {
      const s = sellers.find(x => x.name === loggedUser);
      return s ? (typeof s.balance === "number" ? s.balance : 0) : 0;
    }
    function deductBalance(amount) {
      if (loggedRole === "admin") return true;
      const s = sellers.find(function (x) { return x.name === loggedUser; });
      if (!s || s.balance < amount) return false;
      s.balance -= amount; saveSellers();
      _recordBalHistory(loggedUser, -amount, "Key purchase");
      return true;
    }
    function updateTokenDisplay() {
      const pill = document.getElementById("topTokenPill");
      const sbBox = document.getElementById("sbTokenBox");
      const sbVal = document.getElementById("sbTokenVal");
      const sbCurr = document.getElementById("sbTokenCurr");
      const topVal = document.getElementById("topTokenVal");
      const topCurr = document.getElementById("topTokenCurr");
      // Owner/Admin: no balance pill
      if (loggedRole === "owner" || loggedRole === "admin" || loggedRole === "super_admin") {
        if (pill) pill.style.display = "none";
        if (sbBox) sbBox.classList.remove("show");
        return;
      }
      // Seller: show balance
      if (loggedRole === "seller") {
        const sr = sellers.find(function (x) { return x.name === loggedUser; });
        const bal = getSellerBalance();
        const balStr = fmtMoney(bal);
        const selCurr = activeCurr;
        if (pill) pill.style.display = "flex";
        if (sbBox) sbBox.classList.add("show");
        if (sbVal) sbVal.textContent = balStr;
        if (sbCurr) sbCurr.textContent = selCurr + " Balance";
        if (topVal) topVal.textContent = balStr;
        if (topCurr) topCurr.textContent = "";
      }
    }


    /* ══ CLOCK ══ */
    const p2 = n => String(n).padStart(2, "0");
    function fmtDT(ms) { if (!ms) return "—"; const d = new Date(ms); return d.toLocaleDateString("en-GB", { day: "2-digit", month: "2-digit", year: "numeric" }) + ", " + p2(d.getHours()) + "." + p2(d.getMinutes()) + "." + p2(d.getSeconds()); }
    function fmtLast(ts) { if (!ts) return "Never"; const d = Date.now() - ts; if (d < 60000) return "Just now"; if (d < 3600000) return Math.floor(d / 60000) + "m ago"; if (d < 86400000) return Math.floor(d / 3600000) + "h ago"; return Math.floor(d / 86400000) + "d ago"; }
    function tick() { const n = new Date(); const el = document.getElementById("tbDt"); if (el) el.textContent = n.toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short", year: "2-digit" }) + " · " + p2(n.getHours()) + ":" + p2(n.getMinutes()) + ":" + p2(n.getSeconds()); }
    _appTimers.push(setInterval(tick, 1000)); tick();

    /* ══ LOG ══ */
    const actLog = secLoad("lnActivityLog", []); const MAX_LOG = 500;
    function addLog(icon, msg, keyStr, cat, meta) {
      const n = new Date();
      const time = p2(n.getHours()) + ":" + p2(n.getMinutes()) + ":" + p2(n.getSeconds());
      const date = n.toLocaleDateString("en-GB", { day: "2-digit", month: "2-digit", year: "2-digit" });
      const ua = _getUA();
      const entry = {
        icon, msg, key: keyStr || "", time, date, ts: Date.now(),
        user: loggedUser || "", category: cat || "action", ua
      };
      if (meta && meta.before !== undefined) entry.before = meta.before;
      if (meta && meta.after !== undefined) entry.after = meta.after;
      if (meta && meta.note) entry.note = meta.note;
      actLog.unshift(entry);
      if (actLog.length > MAX_LOG) actLog = actLog.slice(0, MAX_LOG);
      secSave("lnActivityLog", actLog);
      if (currentPage === "log") renderLog();
      const _visLogCnt = loggedRole === "owner" ? actLog.length : actLog.filter(function (r) { return _canSeeUser(r.user || ""); }).length;
      const b = document.getElementById("logBadge"); if (b) { b.textContent = _visLogCnt; b.style.display = _visLogCnt ? "" : "none"; }
      const bLB = document.getElementById("bnavLogBadge"); if (bLB) { bLB.textContent = _visLogCnt > 99 ? "99+" : String(_visLogCnt); bLB.style.display = _visLogCnt ? "" : "none"; }
      const lc = document.getElementById("logCount"); if (lc) lc.textContent = actLog.length + " entries";
    }
    function _getUA() {
      try {
        const ua = navigator.userAgent || "";
        // OS detection
        let os = "Unknown", icon = "\ud83d\udcbb";
        if (/iPhone/i.test(ua)) { os = "iPhone"; icon = "\ud83d\udcf1"; }
        else if (/iPad/i.test(ua)) { os = "iPad"; icon = "\ud83d\udcf1"; }
        else if (/Android/i.test(ua)) { os = "Android"; icon = "\ud83d\udcf1"; }
        else if (/Macintosh|Mac OS/i.test(ua)) { os = "macOS"; icon = "\ud83c\udf4e"; }
        else if (/Windows/i.test(ua)) { os = "Windows"; icon = "\ud83e\ude9f"; }
        else if (/Linux/i.test(ua)) { os = "Linux"; icon = "\ud83d\udc27"; }
        return icon + " " + os;
      } catch (e) { return "?"; }
    }
    function _getDeviceInfo() {
      // Detailed: OS + version + browser + device type
      try {
        const ua = navigator.userAgent || "";
        // OS + version
        let os = "Unknown", osVer = "";
        if (/iPhone|iPad|iPod/i.test(ua)) {
          os = /iPad/i.test(ua) ? "iPadOS" : "iOS";
          const m = ua.match(/OS (\d+[_\.]\d+)/); if (m) osVer = m[1].replace(/_/g, ".");
        } else if (/Android/i.test(ua)) {
          os = "Android"; const m = ua.match(/Android (\d+(?:\.\d+)?)/); if (m) osVer = m[1];
        } else if (/Windows NT/i.test(ua)) {
          os = "Windows"; const m = ua.match(/Windows NT (\d+\.\d+)/);
          const map = { "10.0": "10/11", "6.3": "8.1", "6.2": "8", "6.1": "7" };
          if (m) osVer = map[m[1]] || m[1];
        } else if (/Mac OS X/i.test(ua)) {
          os = "macOS"; const m = ua.match(/Mac OS X (\d+[_\.]\d+)/); if (m) osVer = m[1].replace(/_/g, ".");
        } else if (/Linux/i.test(ua)) { os = "Linux"; }
        // Browser + version
        let br = "Unknown", brVer = "";
        if (/Edg\//i.test(ua)) { br = "Edge"; const m = ua.match(/Edg\/(\d+)/); if (m) brVer = m[1]; }
        else if (/OPR\/|Opera/i.test(ua)) { br = "Opera"; const m = ua.match(/OPR\/(\d+)/); if (m) brVer = m[1]; }
        else if (/SamsungBrowser/i.test(ua)) { br = "Samsung"; const m = ua.match(/SamsungBrowser\/(\d+)/); if (m) brVer = m[1]; }
        else if (/Chrome\//i.test(ua)) { br = "Chrome"; const m = ua.match(/Chrome\/(\d+)/); if (m) brVer = m[1]; }
        else if (/CriOS/i.test(ua)) { br = "Chrome"; const m = ua.match(/CriOS\/(\d+)/); if (m) brVer = m[1]; }
        else if (/Firefox/i.test(ua)) { br = "Firefox"; const m = ua.match(/Firefox\/(\d+)/); if (m) brVer = m[1]; }
        else if (/FxiOS/i.test(ua)) { br = "Firefox"; const m = ua.match(/FxiOS\/(\d+)/); if (m) brVer = m[1]; }
        else if (/Safari/i.test(ua)) { br = "Safari"; const m = ua.match(/Version\/(\d+)/); if (m) brVer = m[1]; }
        // Device type
        let dev = "Desktop";
        if (/iPad|Tablet/i.test(ua)) dev = "Tablet";
        else if (/Mobile|iPhone|Android/i.test(ua)) dev = "Mobile";
        return {
          os: os, osVer: osVer, browser: br, browserVer: brVer, device: dev,
          summary: (os + (osVer ? " " + osVer : "")) + " · " + br + (brVer ? " " + brVer : "") + " · " + dev,
          icon: _getUA()
        };
      } catch (e) { return { os: "Unknown", browser: "Unknown", device: "Unknown", summary: "Unknown device", icon: "?" }; }
    }
    function renderLog() {
      const c = document.getElementById("logContainer"); if (!c) return;
      const fv = (document.getElementById("logFiltSel") || {}).value || "all";
      const sq = (document.getElementById("logSearch") || {}).value || "";
      // Role-based visibility (pyramid)
      let src = actLog.filter(function (r) {
        const logUser = r.user || "";
        if (!logUser) return loggedRole === "owner";
        return _canSeeUser(logUser);
      });
      if (fv !== "all") src = src.filter(function (r) { return r.category === fv; });
      if (sq) {
        const q = sq.toLowerCase(); src = src.filter(function (r) {
          return (r.msg || "").toLowerCase().includes(q) || (r.user || "").toLowerCase().includes(q) || (r.key || "").toLowerCase().includes(q);
        });
      }
      // Update count
      const lc = document.getElementById("logCount");
      if (lc) lc.textContent = src.length + " of " + actLog.length + " events";
      if (!src.length) { c.innerHTML = '<div class="log-empty">📭 ' + (sq || fv !== "all" ? "No matching events" : "No activity yet") + '</div>'; return; }

      // Category metadata: color + label + icon
      const CATMETA = {
        action: { c: "var(--cyan)", l: "KEY", bg: "rgba(0,200,255,.12)" },
        token: { c: "var(--yellow)", l: "BAL", bg: "rgba(255,215,0,.12)" },
        mass: { c: "var(--purple)", l: "MASS", bg: "rgba(136,51,255,.12)" },
        auth: { c: "var(--green)", l: "AUTH", bg: "rgba(0,230,118,.12)" },
        settings: { c: "var(--orange)", l: "CONF", bg: "rgba(255,140,0,.12)" }
      };
      function relTime(ts) {
        const d = Date.now() - ts;
        if (d < 60000) return "just now";
        if (d < 3600000) return Math.floor(d / 60000) + "m ago";
        if (d < 86400000) return Math.floor(d / 3600000) + "h ago";
        if (d < 604800000) return Math.floor(d / 86400000) + "d ago";
        return "";
      }
      function dayLabel(ts) {
        const d = new Date(ts), now = new Date();
        const sameDay = function (a, b) { return a.toDateString() === b.toDateString(); };
        if (sameDay(d, now)) return "Today";
        const yest = new Date(now); yest.setDate(now.getDate() - 1);
        if (sameDay(d, yest)) return "Yesterday";
        return d.toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short", year: "numeric" });
      }

      // Group by day
      let html = "";
      let lastDay = "";
      src.forEach(function (r, i) {
        const dl = dayLabel(r.ts);
        if (dl !== lastDay) {
          // count events for this day
          html += '<div class="log-day-sep"><span class="log-day-lbl">' + dl + '</span></div>';
          lastDay = dl;
        }
        const cat = CATMETA[r.category] || { c: "var(--t3)", l: "LOG", bg: "rgba(255,255,255,.06)" };
        const rel = relTime(r.ts);
        const hasMeta = r.before !== undefined || r.after !== undefined || r.note;
        const keyHtml = r.key ? '<span class="log-key" title="' + escHtml(r.key) + '">🔑 ' + escHtml(r.key.substring(0, 22)) + (r.key.length > 22 ? "…" : "") + '</span>' : "";
        const userBadge = r.user ? '<span class="log-user-badge" title="By ' + escHtml(r.user) + '">' + escHtml(r.user) + '</span>' : '<span class="log-user-badge log-sys">SYSTEM</span>';
        const metaHtml = hasMeta ?
          '<div class="log-detail" style="display:none">' +
          (r.before !== undefined ? '<div class="log-meta-row"><span class="log-meta-k">Before</span><span class="log-before">' + escHtml(String(r.before)) + '</span></div>' : '') +
          (r.after !== undefined ? '<div class="log-meta-row"><span class="log-meta-k">After</span><span class="log-after">' + escHtml(String(r.after)) + '</span></div>' : '') +
          (r.note ? '<div class="log-meta-row"><span class="log-meta-k">Note</span><span class="log-note">' + escHtml(r.note) + '</span></div>' : '') +
          (r.ua ? '<div class="log-meta-row"><span class="log-meta-k">Device</span><span class="log-note">' + escHtml(r.ua) + '</span></div>' : '') +
          '<div class="log-meta-row"><span class="log-meta-k">Time</span><span class="log-note">' + r.date + ' · ' + r.time + '</span></div>' +
          '</div>' : '';
        html +=
          '<div class="log-entry' + (hasMeta ? ' has-detail' : '') + '"' + (hasMeta ? ' onclick="toggleLogDetail(this)"' : '') + '>' +
          '<div class="log-entry-main">' +
          '<span class="log-cat" style="color:' + cat.c + ';background:' + cat.bg + ';border-color:' + cat.c + '44">' + cat.l + '</span>' +
          '<span class="log-ico">' + r.icon + '</span>' +
          '<span class="log-msg">' + escHtml(r.msg) + '</span>' +
          keyHtml +
          '<span class="log-spacer"></span>' +
          userBadge +
          '<span class="log-time" title="' + r.date + ' ' + r.time + '">' + (rel || r.time) + '</span>' +
          (hasMeta ? '<span class="log-expand">▾</span>' : '') +
          '</div>' +
          metaHtml +
          '</div>';
      });
      c.innerHTML = html;
    }
    function toggleLogDetail(el) {
      const d = el.querySelector(".log-detail");
      const ex = el.querySelector(".log-expand");
      if (!d) return;
      const open = d.style.display === "none";
      d.style.display = open ? "block" : "none";
      if (ex) ex.style.transform = open ? "rotate(180deg)" : "";
      el.classList.toggle("expanded", open);
    }
    function clearLog() { actLog.length = 0; renderLog(); const b = document.getElementById("logBadge"); if (b) b.style.display = "none"; }
    function exportLog() {
      if (!actLog.length) { toast("No log entries", "w"); return; }
      const headers = ["Date", "Time", "Icon", "Category", "Message", "Key", "User", "Device", "Before", "After"];
      const rows = actLog.map(function (r) {
        return [
          r.date || "", r.time || "", r.icon || "", r.category || "",
          '"' + (r.msg || "").replace(/"/g, '""') + '"',
          '"' + (r.key || "").replace(/"/g, '""') + '"',
          r.user || "", r.ua || "",
          '"' + String(r.before !== undefined ? r.before : "").replace(/"/g, '""') + '"',
          '"' + String(r.after !== undefined ? r.after : "").replace(/"/g, '""') + '"'
        ].join(",");
      });
      const csv = [headers.join(",")].concat(rows).join("\n");
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
      a.download = "audit_log_" + new Date().toISOString().slice(0, 10) + ".csv";
      a.click(); toast("Audit log exported (CSV)", "s");
      addLog("⬇", "Exported activity log", "", "settings");
    }

    /* ══ PAGE NAVIGATION ══ */
    function switchPage(page, navEl) {
      // PYRAMID page access control
      if (page === "owners_admins" && loggedRole !== "owner" && loggedRole !== "super_admin") {
        toast("Access denied", "e"); return;
      }
      if (page === "sellers" && loggedRole === "seller") {
        toast("Access denied", "e"); return;
      }
      currentPage = page;
      // Page visibility map
      const pageMap = {
        dashboard: "pageDashboard",
        keys: "pageKeys",
        log: "pageLog",
        sellers: "pageSellers",
        owners_admins: "pageOwners_admins"
      };
      Object.entries(pageMap).forEach(function (kv) {
        const el = document.getElementById(kv[1]);
        if (el) el.style.display = kv[0] === page ? "" : "none";
      });
      // Nav active states
      document.querySelectorAll(".ni").forEach(function (n) { n.classList.remove("active"); });
      const niMap = {
        dashboard: ["niDash", "niDash2"],
        keys: ["niKeys", "niKeys2"],
        log: ["niLog"],
        sellers: ["niSellersAdmin"],
        owners_admins: ["niOwnerAdmins2"]
      };
      (niMap[page] || []).forEach(function (id) {
        const el = document.getElementById(id); if (el) el.classList.add("active");
      });
      if (navEl) navEl.classList.add("active");
      // Page title
      const pageNames = {
        dashboard: T("lbl_nav_dash") || "Dashboard",
        keys: T("lbl_nav_keys") || "Key Manager",
        log: T("lbl_log_title") || "Activity Log",
        sellers: T("lbl_sellers_title") || "Sellers",
        owners_admins: T("lbl_owner_admins") || "Manage Admins"
      };
      const pt = document.getElementById("pageTitle"); if (pt) pt.textContent = pageNames[page] || page;
      // Render
      if (page === "dashboard") renderDashboard();
      if (page === "keys") {
        applyRoleRestrictions();
        // Restore search input value
        const _si = document.getElementById("searchInp");
        if (_si && searchQ) _si.value = searchQ;
        const _scb = document.getElementById("searchClearBtn");
        if (_scb) _scb.style.display = searchQ ? "inline" : "none"; buildOwnerFilterRow(); buildCreatorFilterRow(); renderCards(); updateTabCounts();
      }
      // Show FAB only on keys page
      const fab = document.getElementById("fabGen");
      if (fab) fab.style.display = (page === "keys") ? "flex" : "none";
      updateBottomNav(page);
      if (page === "log") renderLog();
      if (page === "sellers") renderSellersList();
      if (page === "owners_admins") renderOwnerAdminsList();
      // Reapply branding (for page title, etc.)
      setTimeout(applyBranding, 30);
      if (window.innerWidth < 1024) closeMobile();
    }


    /* ══ TAGS ══ */
    const TAGS_S = [{ l: "VIP", c: "tc-purple" }, { l: "PRO", c: "tc-cyan" }, { l: "GAME", c: "tc-orange" }, { l: "STREAM", c: "tc-green" }, { l: "TEST", c: "tc-yellow" }, { l: "DEV", c: "tc-blue" }, { l: "PREMIUM", c: "tc-pink" }, { l: "FREE", c: "tc-red" }];
    const TC = ["tc-purple", "tc-cyan", "tc-orange", "tc-green", "tc-yellow", "tc-blue", "tc-pink", "tc-red"];
    function getTC(l) { const f = TAGS_S.find(s => s.l === l.toUpperCase()); if (f) return f.c; return TC[l.split("").reduce((a, c) => a + c.charCodeAt(0), 0) % TC.length]; }
    function tagEl(l) { return `<span class="tag ${getTC(l)}"><span class="tx">#</span>${l.toUpperCase()}</span>`; }
    function buildPresets() { document.getElementById("tagPresets").innerHTML = TAGS_S.map(s => `<span class="tpreset ${s.c}" onclick="addPTag('${s.l}')"># ${s.l}</span>`).join(""); }
    function addPTag(l) { if (!pendingTags.includes(l) && pendingTags.length < 6) { pendingTags.push(l); renderTagEd(); } }
    function handleTag(e) {
      const inp = document.getElementById("tagInp");
      if (e.key === "Enter" || e.key === ",") { e.preventDefault(); const v = inp.value.trim().replace(/^#+/, "").toUpperCase(); if (v && !pendingTags.includes(v) && pendingTags.length < 6) { pendingTags.push(v); inp.value = ""; renderTagEd(); } }
      else if (e.key === "Backspace" && inp.value === "" && pendingTags.length > 0) { pendingTags.pop(); renderTagEd(); }
    }
    function renderTagEd() {
      const ed = document.getElementById("tagEd"), inp = document.getElementById("tagInp");
      ed.querySelectorAll(".tag").forEach(x => x.remove());
      pendingTags.forEach((l, i) => { const sp = document.createElement("span"); sp.className = "tag " + getTC(l); sp.innerHTML = `<span class="tx">#</span>${l} <span style="opacity:.5;cursor:pointer;margin-left:2px" onclick="rmTag(${i})">✕</span>`; ed.insertBefore(sp, inp); });
    }
    function rmTag(i) { pendingTags.splice(i, 1); renderTagEd(); }

    /* ══ GENERATE KEY ══ */
    const TPX = { admin: "ADM", customer: "CST", trial: "TRL" };
    function mkKey(type, suf, prefix) {
      function seg() { return Math.random().toString(36).substr(2, 4).toUpperCase(); }
      const pfx = prefix || ((loggedRole === "seller" && loggedSeller && loggedSeller.prefix) ? loggedSeller.prefix : "X3");
      const tp = TPX[type] || "KEY";
      const su = (suf || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8);
      return su ? (pfx + "-" + tp + su + "-" + seg() + "-" + seg()) : (pfx + "-" + tp + "-" + seg() + "-" + seg() + "-" + seg());
    }
    function selType(tp) {
      // Sellers cannot create trial keys
      if (tp === "trial" && loggedRole === "seller") {
        toast("Sellers cannot generate trial keys", "e");
        tp = "customer"; // fallback to customer
      }
      selTypeV = tp; selPresetDur = null; isLifetime = false;
      ["admin", "customer", "trial"].forEach(x => { const el = document.getElementById("to-" + x); if (el) { el.className = "topt"; if (x === tp) el.classList.add("sel-" + tp); } });
      const customPfxVal = (document.getElementById("inCustomPfx") || {}).value || "";
      let basePfx = customPfxVal.trim().toUpperCase();
      if (!basePfx) { if (loggedRole === "seller" && loggedSeller && loggedSeller.prefix) basePfx = loggedSeller.prefix; else if (loggedAdmin && loggedAdmin.prefix) basePfx = loggedAdmin.prefix; else { const ma = adminAccounts.find(function (a) { return a.name === loggedUser; }); basePfx = ma && ma.prefix ? ma.prefix : "X3"; } }
      const pfxLockEl = document.getElementById("pfxLock");
      if (pfxLockEl) pfxLockEl.textContent = basePfx + "-" + TPX[tp];
      updateKeyDetailPreview();
      // Show/hide custom duration
      const cw = document.getElementById("customDurWrap"), mw = document.getElementById("durMonthWrap"), lw = document.getElementById("durLifetimeWrap");
      // Trial: show custom duration (h+d only), hide months + lifetime
      if (cw) cw.style.display = ""; // always visible
      if (mw) mw.style.display = tp === "trial" ? "none" : "flex"; // hide months for trial
      if (lw) lw.style.display = (tp === "admin" && loggedRole !== "seller") ? "flex" : "none"; // lifetime only for admin, never seller
      // Label hint for trial
      const cdLbl = document.getElementById("lbl_dur_custom_hint");
      if (cdLbl) cdLbl.style.display = tp === "trial" ? "" : "none";
      buildDurPresets();
      onGenChange();
    }
    function buildDurPresets() {
      const el = document.getElementById("durPresets");
      if (!el) { console.warn("[LN] durPresets element not found"); return; }
      let presets = PRESET_DURS[selTypeV] || [];
      // Sellers cannot use lifetime duration
      if (loggedRole === "seller") {
        presets = presets.filter(function (p) { return p.k !== "lifetime"; });
      }
      const _hidePrice = loggedRole === "owner" || loggedRole === "super_admin";
      el.innerHTML = presets.map(p => {
        const cost = pricing[selTypeV + "_" + p.k] || 0;
        const costStr = (cost > 0 && !_hidePrice) ? `<span class="dp-price">${fmtMoney(cost)}</span>` : "";
        return `<button class="dur-preset-btn${selPresetDur === p.k ? " on" : ""}" onclick="applyPreset('${p.k}',this)" ondblclick="cancelPreset()" title="Double-click to cancel">${p.l}${costStr}</button>`;
      }).join("") + '<button class="dur-preset-btn" onclick="cancelPreset()" style="color:var(--red);border-color:rgba(255,48,96,.3);font-size:10px;padding:5px 9px" title="Clear preset">✕ Clear</button>';
    }
    function cancelPreset() {
      selPresetDur = null; isLifetime = false;
      document.querySelectorAll(".dur-preset-btn").forEach(function (b) { b.classList.remove("on"); });
      const cb3 = document.getElementById("durCancelBtn"); if (cb3) cb3.style.display = "none";
      const lb = document.getElementById("durLifeBtn"); if (lb) { lb.textContent = "∞ Lifetime"; lb.style.background = ""; }
      const lh = document.getElementById("durLifeHint"); if (lh) lh.style.display = "none";
      // Reset fields
      ["inMonths", "inDays", "inHours"].forEach(id => { const el = document.getElementById(id); if (el) { el.value = "0"; el.disabled = false; } });
      onGenChange();
      toast("Preset cleared", "i");
    }
    function applyPreset(durKey, el) {
      if (durKey === "lifetime" && loggedRole === "seller") { toast("Sellers cannot use lifetime", "e"); return; }
      selPresetDur = durKey; isLifetime = durKey === "lifetime";
      document.querySelectorAll(".dur-preset-btn").forEach(function (b) { b.classList.remove("on"); });
      if (el) el.classList.add("on");
      const cb2 = document.getElementById("durCancelBtn"); if (cb2) cb2.style.display = "inline-flex";
      onGenChange();
    }
    function toggleLifetime() {
      isLifetime = !isLifetime;
      const btn = document.getElementById("durLifeBtn"); if (btn) { btn.textContent = isLifetime ? "✓ Lifetime Active" : "∞ Lifetime"; btn.style.background = isLifetime ? "linear-gradient(135deg,var(--purple),var(--blue))" : " "; }
      if (isLifetime) selPresetDur = "lifetime";
      onGenChange();
    }
    function onGenChange() {
      // Sync custom prefix to lock display
      const cpv = (document.getElementById("inCustomPfx") || {}).value || "";
      if (cpv.trim()) {
        const lockEl = document.getElementById("pfxLock");
        if (lockEl) lockEl.textContent = cpv.trim().toUpperCase() + "-" + TPX[selTypeV];
      }
      const suf = (document.getElementById("inSuf") || {}).value || "";
      const _cpv = (document.getElementById("inCustomPfx") || {}).value || "";
      let _pfxForPreview = _cpv.trim().toUpperCase();
      if (!_pfxForPreview) {
        if (loggedRole === "seller" && loggedSeller && loggedSeller.prefix) _pfxForPreview = loggedSeller.prefix;
        else { const _ma = adminAccounts.find(function (a) { return a.name === loggedUser; }); _pfxForPreview = _ma && _ma.prefix ? _ma.prefix : "X3"; }
      }
      const _previewKey = mkKey(selTypeV, suf, _pfxForPreview);
      const kpEl = document.getElementById("kprev"); if (kpEl) kpEl.textContent = _previewKey;
      // Dup check
      const daEl = document.getElementById("dupAlert");
      if (daEl) daEl.style.display = keys.find(function (k) { return k.key === _previewKey; }) ? "block" : "none";
      // Update pfxLock subtitle
      const plEl = document.getElementById("pfxLock"); if (plEl) plEl.textContent = _pfxForPreview + "-" + TPX[selTypeV];
      // Dur preview
      let durTxt = "— Set duration";
      if (selPresetDur === "lifetime") durTxt = "∞ Lifetime";
      else if (selPresetDur) durTxt = durKeyLabel(selPresetDur);
      else {
        const mo = parseInt((document.getElementById("inMonths") || {}).value) || 0;
        const d = parseInt((document.getElementById("inDays") || {}).value) || 0;
        const h = parseInt((document.getElementById("inHours") || {}).value) || 0;
        const pts = []; if (mo) pts.push(mo + "mo"); if (d) pts.push(d + "d"); if (h) pts.push(h + "h");
        if (pts.length) durTxt = "= " + pts.join(" + ");
      }
      const dp = document.getElementById("durPrev"); if (dp) dp.textContent = durTxt;
      // Price preview
      const cost = getTokenCost();
      const qty = parseInt((document.getElementById("inQty") || {}).value) || 1;
      const total = cost * qty;
      // price preview handled by updateKeyDetailPreview()

      updateKeyDetailPreview();
    }
    function getTotalMs() {
      if (isLifetime || selPresetDur === "lifetime") return null;
      if (selPresetDur) return durKeyToMs(selPresetDur);
      const mo = selTypeV === "trial" ? 0 : (parseInt((document.getElementById("inMonths") || {}).value) || 0);
      const d = parseInt((document.getElementById("inDays") || {}).value) || 0;
      const h = parseInt((document.getElementById("inHours") || {}).value) || 0;
      return mo * MS.months + d * MS.days + h * MS.hours;
    }
    function getDurLabel() {
      if (isLifetime || selPresetDur === "lifetime") return "∞ Lifetime";
      if (selPresetDur) return durKeyLabel(selPresetDur);
      const mo = parseInt((document.getElementById("inMonths") || {}).value) || 0;
      const d = parseInt((document.getElementById("inDays") || {}).value) || 0;
      const h = parseInt((document.getElementById("inHours") || {}).value) || 0;
      const pts = []; if (mo) pts.push(mo + "mo"); if (d) pts.push(d + "d"); if (h) pts.push(h + "h");
      return pts.length ? pts.join(" + ") : "custom";
    }
    let _genLock = false;
    function doGenerate() {
      if (_genLock) return; _genLock = true; setTimeout(function () { _genLock = false; }, 2000);
      const suf = (document.getElementById("inSuf").value || "").trim();
      const userLabel = ""; // assign to user removed
      const customPfxInput = ((document.getElementById("inCustomPfx") || {}).value || "").trim().toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8);
      // Qty — owner unlimited, admin max 200, seller max 50
      const rawQty = parseInt((document.getElementById("inQty") || { value: "1" }).value) || 1;
      const maxQty = loggedRole === "owner" ? 9999 : loggedRole === "admin" || loggedRole === "super_admin" ? 200 : 50;
      const qty = Math.min(rawQty, maxQty);
      const totalMs = getTotalMs();
      // Seller restrictions (hard guard — checked FIRST)
      if (loggedRole === "seller") {
        if (selTypeV === "trial") { toast("Sellers cannot generate trial keys", "e"); return; }
        if (isLifetime || selPresetDur === "lifetime") { toast("Sellers cannot generate lifetime keys", "e"); return; }
      }
      if (totalMs === 0 && !isLifetime) { toast("Set a duration first", "w"); return; }
      const cost = getTokenCost(); const totalCost = cost * qty;
      if (loggedRole === "seller" && totalCost > 0) {
        const bal = getSellerBalance();
        if (bal < totalCost) { toast("Insufficient balance! Need " + fmtMoney(totalCost) + " have " + fmtMoney(bal), "e"); return; }
      }
      const exp = totalMs === null ? null : Date.now() + totalMs;
      const dl = getDurLabel(); const tags = [...pendingTags];
      // Determine prefix: custom > adminPrefix > sellerPrefix > default
      let pfx = "X3";
      if (customPfxInput) pfx = customPfxInput;
      else if (loggedRole === "seller" && loggedSeller && loggedSeller.prefix) pfx = loggedSeller.prefix;
      else if (loggedAdmin && loggedAdmin.prefix) pfx = loggedAdmin.prefix;
      else if (loggedRole === "admin" || loggedRole === "super_admin") { const ma = adminAccounts.find(function (a) { return a.name === loggedUser; }); if (ma && ma.prefix) pfx = ma.prefix; }
      const firstId = Date.now();
      let created = 0;
      for (let i = 0; i < qty; i++) {
        const newKey = mkKey(selTypeV, suf, pfx);
        if (keys.find(function (k) { return k.key === newKey; })) continue;
        keys.unshift({
          id: firstId + i, key: newKey, type: selTypeV,
          user: userLabel || "",
          status: "active", enabled: true,
          expiresAt: exp, createdAt: Date.now(),
          totalMs: exp ? (exp - Date.now()) : null, dur: dl, tags,
          hwid: null, os: null, lastUsed: null, usage: 0,
          pricePaid: totalCost > 0 ? cost : 0, currency: activeCurr,
          group: "",
          owner: loggedUser,
          createdBy: loggedUser,
          createdRole: loggedRole,  // 'owner'|'admin'|'super_admin'|'seller'
        });
        created++;
      }
      if (!created) { toast("No keys generated (duplicates?)", "w"); _genLock = false; return; }
      if (loggedRole === "seller" && totalCost > 0) {
        deductBalance(totalCost); // also records history
        const spendSr = sellers.find(function (x) { return x.name === loggedUser; });
        if (spendSr) { spendSr.totalSpend = (spendSr.totalSpend || 0) + totalCost; spendSr.lastActivity = Date.now(); saveSellers(); }
        updateTokenDisplay();
        addLog("💵", "Balance deducted: " + fmtMoney(totalCost), "", "token");
      }
      save(); updateStats(); buildOwnerFilterRow();
      document.getElementById("genModal").classList.remove("open");
      switchPage("keys");
      addLog("✨", "Generated " + created + " " + selTypeV + " key" + (created > 1 ? "s" : ""), "", "action", { note: "Cost: " + fmtMoney(totalCost) + " · Qty: " + created });
      notifyWebhook("✨ " + created + " " + selTypeV + " key" + (created > 1 ? "s" : "") + " generated by **" + loggedUser + "** [" + pfx + "]", "gen");
      toast(created + " key" + (created > 1 ? "s" : "") + " generated ✓", "s"); haptic([50, 20, 50]);
      if (created === 1) setTimeout(function () { openLinkModal(firstId); }, 400);
      // Reset
      pendingTags = []; renderTagEd();
      // Reset all gen modal fields
      const _si = document.getElementById("inSuf"); if (_si) _si.value = "";
      const cp2 = document.getElementById("inCustomPfx");// DON'T reset custom prefix - load saved
      const qi = document.getElementById("inQty"); if (qi) { qi.value = "1"; }
      ["inMonths", "inDays", "inHours"].forEach(function (id) { const el = document.getElementById(id); if (el) el.value = "0"; });
      selPresetDur = null; isLifetime = false; selType("customer");
    }


    /* ══ SALES TRACKING ══ */
    function trackSale(type) {
      const d = secLoad("lnSalesV2", {});
      const k = new Date().toISOString().slice(0, 10);
      if (!d[k]) d[k] = { admin: 0, customer: 0, trial: 0, total: 0 };
      d[k][type] = (d[k][type] || 0) + 1; d[k].total = (d[k].total || 0) + 1;
      const keys90 = Object.keys(d).sort().slice(-90);
      const c = {}; keys90.forEach(x => c[x] = d[x]);
      secSave("lnSalesV2", c);
    }
    function getSalesChart(period) {
      const d = secLoad("lnSalesV2", {}); const now = new Date();
      const labels = [], values = [];
      function dayEntry(dt) { const k = dt.toISOString().slice(0, 10); return d[k] || { total: 0 }; }
      function dayLbl(dt, isToday) { if (isToday) return "Today"; const d2 = new Date(now); d2.setDate(d2.getDate() - 1); if (dt.toDateString() === d2.toDateString()) return "Yesterday"; return dt.toLocaleDateString("en-GB", { weekday: "short", day: "2-digit", month: "short" }); }
      if (period === "1d") {
        // Hourly breakdown for today (last 24h in 6h blocks)
        for (let i = 3; i >= 0; i--) {
          const start = new Date(now); start.setHours(start.getHours() - i * 6, 0, 0, 0);
          const k = start.toISOString().slice(0, 10); const e = d[k] || { total: 0 };
          const lbl = i === 0 ? "Now" : (start.getHours().toString().padStart(2, "0") + ":00");
          labels.push(lbl); values.push(e.total || 0);
        }
      } else if (period === "7d") {
        for (let i = 6; i >= 0; i--) { const dt = new Date(now); dt.setDate(dt.getDate() - i); labels.push(dayLbl(dt, i === 0)); values.push(dayEntry(dt).total || 0); }
      } else if (period === "30d") {
        // 10 groups of 3 days
        for (let i = 9; i >= 0; i--) {
          const dt = new Date(now); dt.setDate(dt.getDate() - i * 3);
          let tot = 0; for (let j = 0; j < 3; j++) { const d2 = new Date(dt); d2.setDate(d2.getDate() - j); tot += dayEntry(d2).total || 0; }
          const lbl = i === 0 ? "Today" : dt.toLocaleDateString("en-GB", { day: "2-digit", month: "short" });
          labels.push(lbl); values.push(tot);
        }
      } else if (period === "90d") {
        // 9 groups of 10 days
        for (let i = 8; i >= 0; i--) {
          const dt = new Date(now); dt.setDate(dt.getDate() - i * 10);
          let tot = 0; for (let j = 0; j < 10; j++) { const d2 = new Date(dt); d2.setDate(d2.getDate() - j); tot += dayEntry(d2).total || 0; }
          const lbl = i === 0 ? "Today" : dt.toLocaleDateString("en-GB", { day: "2-digit", month: "short" });
          labels.push(lbl); values.push(tot);
        }
      } else {
        // All — by month, up to 12
        const monthMap = {};
        Object.entries(d).forEach(([k, v]) => { const mo = k.slice(0, 7); monthMap[mo] = (monthMap[mo] || 0) + (v.total || 0); });
        const months = Object.keys(monthMap).sort().slice(-12);
        months.forEach(mo => { const dt = new Date(mo + "-01"); labels.push(dt.toLocaleDateString("en-GB", { month: "short", year: "2-digit" })); values.push(monthMap[mo] || 0); });
        if (!months.length) { labels.push("No data"); values.push(0); }
      }
      return { labels, values, types: { admin: [], customer: [], trial: [] } };
    }

    /* ══ TIME ══ */
    function getRealStatus(k) { if (k.status === "revoked") return "revoked"; if (k.enabled === false) return "disabled"; if (k.expiresAt && k.expiresAt < Date.now()) return "expired"; return "active"; }
    function fmtTL(exp, rs, totalMs) {
      if (rs === "revoked") return { txt: "REVOKED", cls: "tl-exp", bar: "exp" };
      if (rs === "disabled") return { txt: "DISABLED", cls: "tl-exp", bar: "exp" };
      if (!exp) return { txt: "∞ LIFETIME", cls: "tl-life", bar: "life" };
      const d = exp - Date.now(); if (d <= 0) return { txt: "EXPIRED", cls: "tl-exp", bar: "exp" };
      const hh = Math.floor(d / 3600000), mm = Math.floor((d % 3600000) / 60000), ss = Math.floor((d % 60000) / 1000);
      const pct = totalMs && totalMs > 0 ? (d / totalMs) * 100 : 100;
      const cls = pct < 20 ? "tl-exp" : pct < 50 ? "tl-warn" : "tl-ok";
      const bar = pct < 20 ? "exp" : pct < 50 ? "warn" : "ok";
      const txt = hh >= 24 ? (Math.floor(hh / 24) + "d " + p2(hh % 24) + ":" + p2(mm) + ":" + p2(ss)) : p2(hh) + ":" + p2(mm) + ":" + p2(ss);
      return { txt, cls, bar };
    }
    function calcPct(k) { if (!k.expiresAt || !k.totalMs) return 0; return Math.max(0, Math.min(100, (k.expiresAt - Date.now()) / k.totalMs * 100)); }

    /* ══ STATS + DASHBOARD ══ */
    function updateStats() {
      // Only count keys the current user can see
      const _visibleKeys = loggedRole === "owner" ? keys : keys.filter(function (k) { return _canSeeUser(k.owner || null); });
      // Owner/super_admin sees all keys; admin sees own+sellers; seller sees own only
      const vk = loggedRole === "seller" ? keys.filter(function (k) { return !k.owner || k.owner === loggedUser; }) : keys;
      const tot = vk.length, adm = vk.filter(k => k.type === "admin").length;
      const cst = vk.filter(k => k.type === "customer").length, trl = vk.filter(k => k.type === "trial").length;
      const active = vk.filter(k => getRealStatus(k) === "active").length;
      const expired = vk.filter(k => getRealStatus(k) === "expired").length;
      const disabled = vk.filter(k => getRealStatus(k) === "disabled").length;
      const revoked = vk.filter(k => getRealStatus(k) === "revoked").length;
      // For admin: all keys. For seller: own keys only
      const visibleKeys = loggedRole === "seller" ? keys.filter(k => !k.owner || k.owner === loggedUser) : keys;
      const rev = visibleKeys.reduce((a, k) => a + (k.pricePaid || 0), 0);
      const set = (id, v) => { const e = document.getElementById(id); if (e) e.textContent = v; };
      set("nbAll", tot); set("nbAll2", tot);
      ["ktabCntAll", "ktabCntAdm", "ktabCntCst", "ktabCntTrl"].forEach((id, i) => set(id, [tot, adm, cst, trl][i]));
      // Expiry badge
      const soon = keys.filter(k => { if (getRealStatus(k) !== "active" || !k.expiresAt) return false; return k.expiresAt - Date.now() <= 48 * 3600000 && k.expiresAt > Date.now(); }).length;
      const eb = document.getElementById("expiryBadge"); if (eb) { eb.textContent = soon; eb.style.display = soon > 0 ? "" : "none"; }
      // Dashboard cards
      const dg = document.getElementById("dashStatsGrid"); if (!dg) return;
      const bal = loggedRole === "seller" ? getSellerBalance() : null;
      const isOwnerOrSA = loggedRole === "owner" || loggedRole === "super_admin";
      const cards = (loggedRole === "admin" || isOwnerOrSA) ? [
        { id: "total", ico: "🔑", pill: "All", val: tot, lbl: "Total Keys", clr: "var(--purple)", barPct: 100, barClr: "var(--purple)", filter: "all" },
        { id: "active", ico: "✅", pill: "Active", val: active, lbl: "Active Keys", clr: "var(--green)", barPct: tot ? active / tot * 100 : 0, barClr: "var(--green)", filter: "active" },
        { id: "expired", ico: "⌛", pill: "Expired", val: expired, lbl: "Expired Keys", clr: "var(--orange)", barPct: tot ? expired / tot * 100 : 0, barClr: "var(--orange)", filter: "expired" },
        { id: "revoked", ico: "🚫", pill: "Revoked", val: revoked, lbl: "Revoked Keys", clr: "var(--t3)", barPct: tot ? revoked / tot * 100 : 0, barClr: "var(--t3)", filter: "revoked" },

        { id: "adm", ico: "👑", pill: "Admin", val: adm, lbl: "Admin Keys", clr: "var(--ca)", barPct: tot ? adm / tot * 100 : 0, barClr: "var(--ca)", filter: "admin" },
        { id: "cst", ico: "🔒", pill: "Customer", val: cst, lbl: "Customer Keys", clr: "var(--cc)", barPct: tot ? cst / tot * 100 : 0, barClr: "var(--cc)", filter: "customer" },
        { id: "trl", ico: "⏱", pill: "Trial", val: trl, lbl: "Trial Keys", clr: "var(--ct)", barPct: tot ? trl / tot * 100 : 0, barClr: "var(--ct)", filter: "trial" },
        { id: "rev", ico: "💰", pill: "Revenue", val: fmtMoney(rev), lbl: "Revenue", clr: "var(--yellow)", barPct: 100, barClr: "var(--yellow)", filter: null, noNum: true },
      ] : [
        { id: "total", ico: "🔑", pill: "All", val: tot, lbl: "Total Keys", clr: "var(--purple)", barPct: 100, barClr: "var(--purple)", filter: "all" },
        { id: "active", ico: "✅", pill: "Active", val: active, lbl: "Active Keys", clr: "var(--green)", barPct: tot ? active / tot * 100 : 0, barClr: "var(--green)", filter: "active" },
        { id: "expired", ico: "⌛", pill: "Expired", val: expired, lbl: "Expired Keys", clr: "var(--orange)", barPct: tot ? expired / tot * 100 : 0, barClr: "var(--orange)", filter: "expired" },
        { id: "revoked", ico: "🚫", pill: "Revoked", val: revoked, lbl: "Revoked Keys", clr: "var(--t3)", barPct: tot ? revoked / tot * 100 : 0, barClr: "var(--t3)", filter: "revoked" },
        { id: "token", ico: "💵", pill: "Balance", val: fmtMoney(bal || 0), lbl: "My Balance", clr: "var(--cyan)", barPct: 100, barClr: "var(--cyan)", filter: null, noNum: true },
        { id: "rev", ico: "💰", pill: "Revenue", val: fmtMoney(rev), lbl: "My Revenue", clr: "var(--yellow)", barPct: 100, barClr: "var(--yellow)", filter: null, noNum: true },
      ];
      dg.innerHTML = cards.map(c => `
    <div class="sc sc-${c.id}" onclick="${c.filter ? `switchToKeys('${c.filter}')` : "void(0)"}" style="cursor:${c.filter ? "pointer" : "default"}">
      <div class="sc-top"><span class="sc-ico">${c.ico}</span><span class="sc-pill" style="background:${c.clr}22;color:${c.clr}">${c.pill}</span></div>
      <div class="sc-val" style="color:${c.clr}">${c.val}</div>
      <div class="sc-lbl">${c.lbl}</div>
      <div class="sc-bar"><div class="sc-bar-f" style="background:${c.barClr};width:${(c.barPct || 0).toFixed(1)}%"></div></div>
    </div>`).join("");
      // Onboard hint
      const ob = document.getElementById("dashOnboard"); if (ob) ob.style.display = tot === 0 ? "block" : "none";
      // Renewal alert
      renderRenewalAlert();
    }
    function renderDashboard() {
      // Reset view switcher on fresh render
      if (loggedRole === "seller") dashViewAs = null; // seller can only see own
      updateStats();
      buildDashViewSwitcher();
      if (dashViewAs !== null) {
        _refreshDashForView(); // viewing another account
      } else {
        _buildDashHeader();
      }
      setTimeout(function () {
        renderGenChart();
        renderPieChart();
        if (dashViewAs === null) renderHierarchyDash(); // only for own view

      }, 80);
    }

    function _buildDashHeader() {
      const el = document.getElementById("dashOwnSection"); if (!el) return;
      // Seller: dedicated mini dashboard
      if (loggedRole === "seller") { _buildSellerDash(el); return; }
      // Admin/Owner: use visible keys only
      const myK = loggedRole === "owner" ? keys : keys.filter(function (k) { return _canSeeUser(k.owner || null); });
      const total = myK.length;
      const active = myK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = myK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const disabled = myK.filter(function (k) { return getRealStatus(k) === "disabled"; }).length;
      const revoked = myK.filter(function (k) { return getRealStatus(k) === "revoked"; }).length;
      const rev = myK.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      // Growth: keys added last 7d vs prev 7d
      const now = Date.now(); const d7 = 7 * 86400000;
      const newThisWeek = myK.filter(function (k) { return k.createdAt && (now - k.createdAt) < d7; }).length;
      const newLastWeek = myK.filter(function (k) { return k.createdAt && (now - k.createdAt) >= d7 && (now - k.createdAt) < d7 * 2; }).length;
      const growthPct = newLastWeek > 0 ? Math.round((newThisWeek - newLastWeek) / newLastWeek * 100) : newThisWeek > 0 ? 100 : 0;
      const growthClr = growthPct >= 0 ? "var(--green)" : "var(--red)";
      const growthArrow = growthPct >= 0 ? "↑" : "↓";
      // Expiring soon (24h)
      const expiring24h = myK.filter(function (k) {
        if (getRealStatus(k) !== "active" || !k.expiresAt) return false;
        return k.expiresAt - now < 86400000 && k.expiresAt > now;
      }).length;
      // Top seller by keys
      const sellerCounts = {}; myK.forEach(function (k) { if (k.owner && k.owner !== loggedUser) sellerCounts[k.owner] = (sellerCounts[k.owner] || 0) + 1; });
      const topSeller = Object.entries(sellerCounts).sort(function (a, b) { return b[1] - a[1]; })[0];
      el.innerHTML =
        '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;margin-bottom:12px">' +
        _kpi("🔑 Total Keys", total, "var(--cyan)") +
        _kpi("✅ Active", active, "var(--green)") +
        _kpi("⏸ Disabled", disabled, "var(--t3)") +
        _kpi("⏰ Expired", expired, "var(--orange)") +
        _kpi("🚫 Revoked", revoked, "var(--red)") +
        '</div>';
      // Also update renewal alert
      _updateRenewalAlert(expiring24h, myK.filter(function (k) {
        if (getRealStatus(k) !== "active" || !k.expiresAt) return false;
        return k.expiresAt - now < 3 * 86400000 && k.expiresAt > now;
      }));
      updateExpireBadge();
    }
    function _kpi(label, value, clr) {
      return '<div style="background:rgba(255,255,255,.025);border:1px solid var(--b);border-radius:var(--rs);padding:10px 12px;position:relative;overflow:hidden">' +
        '<div style="position:absolute;top:0;left:0;width:3px;height:100%;background:' + clr + '"></div>' +
        '<div style="font-size:9px;color:var(--t3);text-transform:uppercase;letter-spacing:.7px;margin-bottom:4px;font-family:JetBrains Mono,monospace">' + label + '</div>' +
        '<div style="font-size:18px;font-weight:800;color:' + clr + ';font-family:JetBrains Mono,monospace;line-height:1">' + value + '</div>' +
        '</div>';
    }
    function _updateRenewalAlert(count, soonKeys) {
      const el = document.getElementById("renewalAlert"); if (!el) return;
      if (!count) { el.style.display = "none"; return; }
      el.style.display = "";
      const rl = document.getElementById("renewalList"); if (!rl) return;
      rl.innerHTML = soonKeys.slice(0, 5).map(function (k) {
        const tl = k.expiresAt ? Math.ceil((k.expiresAt - Date.now()) / 3600000) + "h" : "-";
        return '<div style="display:flex;justify-content:space-between;align-items:center;padding:4px 0;border-bottom:1px solid var(--b)">' +
          '<span style="font-family:JetBrains Mono,monospace;font-size:10px;color:var(--cyan)">' + k.key.substring(0, 18) + '…</span>' +
          '<span style="font-size:10px;color:var(--red);font-weight:700">' + tl + '</span>' +
          '</div>';
      }).join("") + (soonKeys.length > 5 ? '<div style="font-size:9px;color:var(--t3);padding-top:4px">+' + (soonKeys.length - 5) + ' more</div>' : "");
    }


    /* ══ HIERARCHY DASHBOARD ══ */
    function renderHierarchyDash() {
      const el = document.getElementById("dashHierarchy"); if (!el) return;
      if (loggedRole === "seller") { el.innerHTML = ""; return; }
      const frag = document.createDocumentFragment();

      if (loggedRole === "owner") {
        // Owner: show each admin as a section with their sellers inside
        const admSection = document.createElement("div");
        admSection.innerHTML = '<div style="display:flex;align-items:center;justify-content:space-between;margin:14px 0 8px"><div style="font-size:10px;font-weight:700;color:var(--ca);text-transform:uppercase;letter-spacing:1px;font-family:JetBrains Mono,monospace">⚡ Admin Sections</div><button class="btn btn-ghost btn-xs" onclick="switchPage(\'owners_admins\')">View Full Pyramid →</button></div>';
        frag.appendChild(admSection);
        adminAccounts.forEach(function (adm) {
          const card = _buildAdminDashCard(adm);
          frag.appendChild(card);
        });
        // Direct sellers (not under any admin)
        const directS = sellers.filter(function (sr) { return !sr.adminOwner; });
        if (directS.length) {
          const ds = document.createElement("div");
          ds.innerHTML = '<div style="font-size:10px;font-weight:700;color:var(--purple);text-transform:uppercase;letter-spacing:1px;font-family:JetBrains Mono,monospace;margin:14px 0 8px">👤 Direct Sellers (No Admin)</div>';
          frag.appendChild(ds);
          const dsgrid = document.createElement("div");
          dsgrid.style.cssText = "display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:9px;margin-bottom:10px";
          directS.forEach(function (sr) { dsgrid.appendChild(_buildSellerDashCard(sr)); });
          frag.appendChild(dsgrid);
        }
      } else if (loggedRole === "admin" || loggedRole === "super_admin") {
        // Admin: show their sellers
        const mySellers = sellers.filter(function (sr) {
          return sr.adminOwner === loggedUser || sr.createdBy === loggedUser;
        });
        if (!mySellers.length) { el.innerHTML = ""; return; }
        const hdr = document.createElement("div");
        hdr.innerHTML = '<div style="display:flex;align-items:center;justify-content:space-between;margin:14px 0 8px"><div style="font-size:10px;font-weight:700;color:var(--cyan);text-transform:uppercase;letter-spacing:1px;font-family:JetBrains Mono,monospace">👥 My Sellers (' + mySellers.length + ')</div><button class="btn btn-ghost btn-xs" onclick="switchPage(\'sellers\')">Manage →</button></div>';
        frag.appendChild(hdr);
        const grid = document.createElement("div");
        grid.style.cssText = "display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:9px";
        mySellers.forEach(function (sr) { grid.appendChild(_buildSellerDashCard(sr)); });
        frag.appendChild(grid);
      }
      el.innerHTML = ""; el.appendChild(frag);
    }

    function _buildAdminDashCard(adm) {
      const wrap = document.createElement("div");
      const isDashCollapsed = _dashCollapsed.has(adm.name);
      wrap.style.cssText = "margin-bottom:14px;background:rgba(255,123,0,.025);border:1px solid rgba(255,123,0,.12);border-radius:var(--r);overflow:hidden";
      const myS = sellers.filter(function (sr) { return sr.adminOwner === adm.name; });
      const myK = keys.filter(function (k) { return k.owner === adm.name || myS.some(function (sr) { return sr.name === k.owner; }); });
      const actK = myK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expK = myK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const revK = myK.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      const tClr = { super_admin: "var(--yellow)", admin: "var(--cyan)" }[adm.type] || "var(--t2)";
      const tLbl = { super_admin: "★ Super Admin", admin: "● Admin" }[adm.type] || adm.type;

      const sClr = adm.disabled ? "var(--red)" : "var(--green)";
      // Admin header row
      const hdr = document.createElement("div");
      hdr.style.cssText = "padding:10px 14px;display:flex;align-items:center;gap:10px;flex-wrap:wrap";
      hdr.innerHTML =
        '<div style="display:flex;align-items:center;gap:7px;flex:1;min-width:0">' +
        '<div style="width:28px;height:28px;border-radius:50%;background:linear-gradient(135deg,var(--ca),var(--orange));display:flex;align-items:center;justify-content:center;font-weight:800;font-size:10px;flex-shrink:0">' + adm.name.substring(0, 2).toUpperCase() + '</div>' +
        '<div>' +
        '<div style="font-size:13px;font-weight:800;display:flex;align-items:center;gap:6px">' +
        adm.name +
        '<span style="font-size:9px;padding:2px 7px;border-radius:20px;background:' + tClr + '22;color:' + tClr + ';border:1px solid ' + tClr + '44">' + tLbl + '</span>' +
        '<span style="font-size:9px;padding:2px 7px;border-radius:20px;background:' + sClr + '22;color:' + sClr + ';border:1px solid ' + sClr + '44">' + (adm.disabled ? "Disabled" : "Active") + '</span>' +
        '</div>' +
        '<div style="font-size:9.5px;color:var(--t3);font-family:JetBrains Mono,monospace">' +
        myS.length + ' sellers · ' + myK.length + ' keys · ' + actK + ' active · ' + expK + ' expired · ' + fmtMoney(revK) + ' revenue' +
        '</div>' +
        '</div>' +
        '</div>' +
        // Stat pills
        '<div style="display:flex;gap:10px;flex-shrink:0">' +
        '<div style="text-align:center"><div style="font-size:13px;font-weight:800;color:var(--green)">' + actK + '</div><div style="font-size:8.5px;color:var(--t3)">Active</div></div>' +
        '<div style="text-align:center"><div style="font-size:13px;font-weight:800;color:var(--orange)">' + expK + '</div><div style="font-size:8.5px;color:var(--t3)">Expired</div></div>' +
        '<div style="text-align:center"><div style="font-size:13px;font-weight:800;color:var(--yellow);font-family:JetBrains Mono,monospace">' + fmtMoney(revK) + '</div><div style="font-size:8.5px;color:var(--t3)">Revenue</div></div>' +

        '</div>' +
        '<button class="btn btn-ghost btn-xs" onclick="switchPage(\'owners_admins\')" title="View full tree" style="flex-shrink:0">→</button>';
      wrap.appendChild(hdr);
      // Sellers grid
      if (myS.length && !isDashCollapsed) {
        const selGrid = document.createElement("div");
        selGrid.style.cssText = "display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:8px;padding:8px 14px 12px;border-top:1px solid rgba(255,255,255,.04)";
        myS.forEach(function (sr) { selGrid.appendChild(_buildSellerDashCard(sr)); });
        wrap.appendChild(selGrid);
      }
      return wrap;
    }

    function _buildSellerDashCard(sr) {
      const myK = keys.filter(function (k) { return k.owner === sr.name; });
      const actK = myK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expK = myK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const revK = myK.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      const bal = sr.balance || 0;
      const balClr = bal < 1000 ? "var(--red)" : bal < 10000 ? "var(--orange)" : "var(--green)";
      const actPct = myK.length ? Math.round(actK / myK.length * 100) : 0;
      const card = document.createElement("div");
      card.className = "sc";
      card.style.cssText = "cursor:pointer;border-left:3px solid var(--purple)";
      card.title = "Click to view " + escHtml(sr.name) + "'s keys";
      card.onclick = function () {
        const si = sellers.indexOf(sr);
        if (si >= 0) viewSellerKeys(si);
      };
      card.innerHTML =
        '<div class="sc-top">' +
        '<div style="display:flex;align-items:center;gap:6px;flex:1;min-width:0">' +
        '<div class="seller-av" style="width:24px;height:24px;font-size:9px;flex-shrink:0">' + sr.name.substring(0, 2).toUpperCase() + '</div>' +
        '<div style="min-width:0">' +
        '<div style="font-size:12px;font-weight:700;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + escHtml(sr.name) + '</div>' +
        '<div style="font-size:9px;color:var(--t3)">' + myK.length + ' keys</div>' +
        '</div>' +
        '</div>' +
        '<div style="text-align:right;flex-shrink:0">' +
        '<div style="font-size:12px;font-weight:800;color:' + balClr + ';font-family:JetBrains Mono,monospace">' + fmtMoney(bal) + '</div>' +
        '<div style="font-size:8.5px;color:var(--t3)">Balance</div>' +
        '</div>' +
        '</div>' +
        // Stats row
        '<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:5px;margin-top:8px">' +
        '<div style="background:rgba(0,229,160,.07);border:1px solid rgba(0,229,160,.15);border-radius:5px;padding:5px;text-align:center">' +
        '<div style="font-size:15px;font-weight:800;color:var(--green)">' + actK + '</div>' +
        '<div style="font-size:8px;color:var(--t3)">Active</div>' +
        '</div>' +
        '<div style="background:rgba(255,123,0,.07);border:1px solid rgba(255,123,0,.15);border-radius:5px;padding:5px;text-align:center">' +
        '<div style="font-size:15px;font-weight:800;color:var(--orange)">' + expK + '</div>' +
        '<div style="font-size:8px;color:var(--t3)">Expired</div>' +
        '</div>' +
        '<div style="background:rgba(255,215,0,.07);border:1px solid rgba(255,215,0,.15);border-radius:5px;padding:5px;text-align:center">' +
        '<div style="font-size:12px;font-weight:800;color:var(--yellow);font-family:JetBrains Mono,monospace">' + fmtMoney(revK) + '</div>' +
        '<div style="font-size:8px;color:var(--t3)">Revenue</div>' +
        '</div>' +
        '</div>' +
        // Progress bar
        '<div style="margin-top:7px"><div style="display:flex;justify-content:space-between;font-size:8.5px;color:var(--t3);margin-bottom:3px"><span>Key Activity</span><span>' + actPct + '% active</span></div><div style="height:3px;background:rgba(255,255,255,.07);border-radius:2px"><div style="height:100%;background:linear-gradient(90deg,var(--green),var(--cyan));border-radius:2px;width:' + actPct + '%;transition:width .4s ease"></div></div></div>' +
        // Spend tracking
        (sr.totalSpend ? '<div style="margin-top:5px;font-size:9.5px;color:var(--t3)">Used: <span style="color:var(--orange);font-family:JetBrains Mono,monospace">' + fmtMoney(sr.totalSpend) + '</span></div>' : '') +
        '<div style="margin-top:5px;font-size:8.5px;color:var(--t3)">' +
        (sr.lastActivity ? 'Last active: ' + fmtLast(sr.lastActivity) : 'No activity yet') +
        '</div>';
      return card;
    }

    function switchToKeys(f) { switchPage("keys"); filt = f; document.querySelectorAll(".fbtn").forEach(b => b.classList.remove("on")); const m = { all: "fAll", active: "fAct", expired: "fExp", disabled: "fDis" }; const btn = document.getElementById(m[f] || "fAll"); if (btn) btn.classList.add("on"); renderCards(); updateActiveFilters(); }

    /* ══ CHARTS ══ */
    function renderGenChart() {
      const el = document.getElementById("genChartBars"); if (!el) return;
      const { labels, values, types } = getSalesChart(salesPeriod);
      const maxV = Math.max(...values, 1);
      const total = values.reduce((a, b) => a + b, 0);
      const avg = (total / values.length).toFixed(1);
      const peakIdx = values.indexOf(Math.max(...values));
      const todayV = values[values.length - 1] || 0;
      const yestV = values[values.length - 2] || 0;
      const diff = todayV - yestV;
      const diffStr = diff === 0 ? "= same" : (diff > 0 ? "▲ +" + diff + " vs yesterday" : "▼ " + diff + " vs yesterday");
      const diffClr = diff > 0 ? "var(--green)" : diff < 0 ? "var(--red)" : "var(--t3)";
      document.getElementById("chartTotalLbl").textContent = "Total: " + total;
      document.getElementById("chartAvgLbl").textContent = "Avg: " + avg + "/period";
      document.getElementById("chartPeakLbl").textContent = "Peak: " + (labels[peakIdx] || "—") + " (" + Math.max(...values) + ")";
      const dayCompEl = document.getElementById("chartDayComp");
      if (dayCompEl) dayCompEl.innerHTML = `Today: <b style="color:var(--cyan)">${todayV}</b> &nbsp;<span style="color:${diffClr};font-size:9.5px">${diffStr}</span>`;
      el.innerHTML = labels.map((lbl, i) => {
        const isToday = i === labels.length - 1; const isYest = i === labels.length - 2;
        const h = (values[i] / maxV * 100).toFixed(1);
        const clr = isToday ? "linear-gradient(to top,var(--cyan),#00ffff)" : isYest ? "linear-gradient(to top,rgba(0,200,255,.4),rgba(0,200,255,.7))" : values[i] === Math.max(...values) ? "linear-gradient(to top,var(--blue),var(--cyan))" : "linear-gradient(to top,rgba(0,85,255,.45),rgba(0,150,255,.65))";
        const border = isToday ? "2px solid var(--cyan)" : "";
        return `<div class="bar-col" title="${lbl}: ${values[i]} keys${isToday ? " (today)" : isYest ? " (yesterday)" : ""}">
      <div class="bar-val" style="${isToday ? "color:var(--cyan);font-weight:700" : ""}">${values[i] || ""}</div>
      <div class="bar-fill" style="height:${h}%;background:${clr};min-height:${values[i] ? 3 : 0}px;outline:${border};border-radius:4px 4px 0 0"></div>
      <div class="bar-lbl" style="${isToday ? "color:var(--cyan);font-weight:700" : isYest ? "color:var(--t2)" : ""}">${lbl}</div>
    </div>`;
      }).join("");
    }
    function setSalesPeriod(p, el) {
      salesPeriod = p;
      document.querySelectorAll(".sales-pb").forEach(b => b.classList.remove("on"));
      if (el) { el.classList.add("on"); }
      // Update chart title
      const titleMap = { "1d": "Today (Hourly)", "7d": "Last 7 Days", "30d": "Last 30 Days", "90d": "Last 90 Days", "all": "All Time" };
      const ct = document.getElementById("lbl_chart_gen");
      if (ct) ct.textContent = "Key Generation — " + (titleMap[p] || p);
      renderGenChart();
    }
    function renderPieChart() {
      const el = document.getElementById("dashPieWrap"); if (!el) return;
      const _pk = loggedRole === "owner" ? keys : keys.filter(function (k) { return _canSeeUser(k.owner || null); });
      const adm = keys.filter(k => k.type === "admin").length;
      const cst = keys.filter(k => k.type === "customer").length;
      const trl = keys.filter(k => k.type === "trial").length;
      const tot = adm + cst + trl || 1;
      let offset = 0;
      const seg = (pct, clr) => { const dash = pct / 100 * 62.83; const off = offset; offset += dash; return `<circle cx="10" cy="10" r="10" fill="none" stroke="${clr}" stroke-width="20" stroke-dasharray="${dash.toFixed(2)} ${(62.83 - dash).toFixed(2)}" stroke-dashoffset="${(-off).toFixed(2)}" transform="rotate(-90 10 10)"/>` };
      el.innerHTML = `<svg width="80" height="80" viewBox="-10 -10 40 40" class="pie-svg">${seg(adm / tot * 100 || .01, "var(--ca)")}${seg(cst / tot * 100 || .01, "var(--cc)")}${seg(trl / tot * 100 || .01, "var(--ct)")}</svg>
  <div class="pie-legend"><div class="pie-item"><div class="pie-dot" style="background:var(--ca)"></div>Admin (${adm})</div><div class="pie-item"><div class="pie-dot" style="background:var(--cc)"></div>Customer (${cst})</div><div class="pie-item"><div class="pie-dot" style="background:var(--ct)"></div>Trial (${trl})</div></div>`;
    }
    function renderRenewalAlert() {
      const limit = 48 * 3600000;
      const warn = keys.filter(k => { if (!_canSeeUser(k.owner)) return false; if (getRealStatus(k) !== "active" || !k.expiresAt) return false; const r = k.expiresAt - Date.now(); return r > 0 && r <= limit; });
      const el = document.getElementById("renewalAlert"), rl = document.getElementById("renewalList");
      if (!el || !rl) return;
      if (!warn.length) { el.style.display = "none"; return; }
      el.style.display = "block";
      rl.innerHTML = warn.slice(0, 5).map(k => { const tl = fmtTL(k.expiresAt, getRealStatus(k), k.totalMs); return `<div style="display:flex;justify-content:space-between;padding:2px 0;border-bottom:1px solid rgba(255,255,255,.04)"><span>${k.key.substring(0, 24)}…</span><span class="tl-mini ${tl.cls}">${tl.txt}</span></div>`; }).join("") + (warn.length > 5 ? `<div style="font-size:9.5px;color:var(--t3);margin-top:3px">...and ${warn.length - 5} more</div>` : "");
    }

    /* ══ SORT + FILTER ══ */
    function setSort(by, el) {
      if (sortBy === by) sortDir *= -1; else { sortBy = by; sortDir = 1; }
      document.querySelectorAll(".sort-btn").forEach(b => { b.classList.remove("on", "asc", "desc"); });
      if (el) { el.classList.add("on"); el.classList.add(sortDir === 1 ? "asc" : "desc"); }
      renderCards();

      // Update dropdown button label
      const lbl = document.getElementById("sortDropLbl");
      const activeOpt = document.querySelector(".sort-opt.on");
      if (lbl && activeOpt) lbl.textContent = activeOpt.textContent.trim();
      const menu = document.getElementById("sortDropMenu");
      if (menu) menu.style.display = "none";
    }
    /* ── MEMOIZED FILTER (perf) ── */
    let _filterCache = null, _filterCacheKey = "";
    function _filterCacheKeyGen() {
      // Build a cheap key from filter state + data length
      return [keys.length, searchQ || "", [...activeFilts].join(","), [...activeTypeTabs].join(","),
      [...ownerFilts].join(","), loggedUser, loggedRole, _lastDataVer || 0].join("|");
    }
    function getFiltered() {
      const k = _filterCacheKeyGen();
      if (_filterCache && _filterCacheKey === k) return _filterCache;
      _filterCache = _computeFiltered();
      _filterCacheKey = k;
      return _filterCache;
    }
    function _invalidateFilterCache() { _filterCache = null; _filterCacheKey = ""; }
    function _computeFiltered() {
      const now = Date.now();
      let filtered = keys.filter(function (k) {
        const rs = getRealStatus(k);
        // ── 1. Role-based visibility ──
        // Owner: sees ALL
        // Admin/super_admin: sees own keys + sellers they created
        // Seller: sees only their own keys
        if (!_canSeeUser(k.owner || null)) return false;
        // Admin: also respect ownerFilts (manual view filter)
        if ((loggedRole === "admin" || loggedRole === "super_admin") && !ownerFilts.has("all")) {
          const ok = [...ownerFilts].some(function (o) {
            if (o === "__admin__") return !k.owner || k.owner === loggedUser;
            if (o === "__self__") return k.owner === loggedUser;
            if (o.startsWith("admin:")) { const an = o.slice(6); const as2 = sellers.filter(function (sr) { return sr.adminOwner === an; }).map(function (sr) { return sr.name; }); return k.owner === an || as2.includes(k.owner); }
            if (o.startsWith("seller:")) return k.owner === o.slice(7);
            return k.owner === o;
          });
          if (!ok) return false;
        }
        // Owner: also respect ownerFilts if manually filtered
        if (loggedRole === "owner" && !ownerFilts.has("all")) {
          const ok = [...ownerFilts].some(function (o) {
            if (o === "__self__") return k.owner === loggedUser || !k.owner;
            if (o.startsWith("admin:")) { const an = o.slice(6); const as2 = sellers.filter(function (sr) { return sr.adminOwner === an; }).map(function (sr) { return sr.name; }); return k.owner === an || as2.includes(k.owner); }
            if (o.startsWith("seller:")) return k.owner === o.slice(7);
            return true;
          });
          if (!ok) return false;
        }
        // ── 2. Key type tab filter ──
        if (!activeTypeTabs.has("all")) {
          if (!activeTypeTabs.has(k.type)) return false;
        }
        // ── 3. Status multi-filter ──
        if (!activeFilts.has("all")) {
          const matchFilt = [...activeFilts].some(function (filt) {
            if (filt === "active") return rs === "active";
            if (filt === "expired") return rs === "expired";
            if (filt === "disabled") return rs === "disabled";
            if (filt === "revoked") return rs === "revoked";
            if (filt === "admin") return k.type === "admin";
            if (filt === "customer") return k.type === "customer";
            if (filt === "trial") return k.type === "trial";
            if (filt === "7d") { if (!k.expiresAt || rs !== "active") return false; const r = k.expiresAt - now; return r > 0 && r <= 7 * 86400000; }
            if (filt === "30d") { if (!k.expiresAt || rs !== "active") return false; const r = k.expiresAt - now; return r > 0 && r <= 30 * 86400000; }
            return true;
          });
          if (!matchFilt) return false;
        }
        // ── 4. Creator filter ──
        if (!creatorFilts.has("all")) {
          const cr = k.createdBy || k.owner || "?";
          if (!creatorFilts.has(cr)) return false;
        }
        // ── 5. Search ──
        const q = searchQ.toLowerCase().trim();
        if (q) {
          const kl = k.key.toLowerCase();
          if (q.startsWith("#")) { const tq = q.slice(1); return !tq || ((k.tags || []).some(function (t) { return t.toLowerCase().includes(tq); })); }
          if (q.startsWith("@")) { const gq = q.slice(1); return !gq || ((k.group || "").toLowerCase().includes(gq)); }
          if (q.startsWith("hw:")) { return (k.hwid || "").toLowerCase().includes(q.slice(3)); }
          if (q.startsWith("os:")) { return (k.os || "").toLowerCase().includes(q.slice(3)); }
          const tagMatch = (k.tags || []).some(function (t) { return t.toLowerCase().includes(q); });
          if (!kl.includes(q) && !(k.user || "").toLowerCase().includes(q) && !tagMatch && !(k.hwid || "").toLowerCase().includes(q)) return false;
        }
        return true;
      });
      // Sort
      filtered.sort(function (a, b) {
        let cmp = 0;
        if (sortBy === "expiry") cmp = (a.expiresAt || Infinity) - (b.expiresAt || Infinity);
        else if (sortBy === "created") cmp = (a.createdAt || 0) - (b.createdAt || 0);
        else if (sortBy === "type") cmp = (a.type || "").localeCompare(b.type || "");
        return cmp * sortDir;
      });
      return filtered;
    }

    function setFilt(f, el) {
      if (filt === f && f !== "all") { filt = "all"; document.querySelectorAll(".fbtn").forEach(b => b.classList.remove("on")); const ab = document.getElementById("fAll"); if (ab) ab.classList.add("on"); }
      else { filt = f; document.querySelectorAll(".fbtn").forEach(b => b.classList.remove("on")); if (el) el.classList.add("on"); }
      pgPage = 1; sessionStorage.setItem("lnFilt", JSON.stringify({ filt, searchQ }));
      renderCards(); updateActiveFilters();
    }
    let _searchDebounce = null;
    function onSearch(v) {
      searchQ = v;
      // Show/hide clear button immediately
      const scb = document.getElementById("searchClearBtn");
      if (scb) scb.style.display = v && v.length > 0 ? "inline" : "none";
      // Debounce the actual render
      if (_searchDebounce) clearTimeout(_searchDebounce);
      _searchDebounce = setTimeout(function () { _doSearch(v); }, 180);
    }
    function _doSearch(v) {
      searchQ = v; pgPage = 1; sessionStorage.setItem("lnFilt", JSON.stringify({ activeFilts: [...activeFilts], searchQ: v })); renderCardsDebounced(); updateActiveFilters();
      // Show/hide clear button
      const scb = document.getElementById("searchClearBtn");
      if (scb) scb.style.display = v && v.length > 0 ? "inline" : "none";
    }
    let activeTypeTabs = new Set(["all"]);
    function setKeyTab(type, el) {
      if (type === "all") {
        activeTypeTabs = new Set(["all"]);
        document.querySelectorAll(".km-tab,.ktab").forEach(function (t) { t.classList.remove("on"); });
        if (el) el.classList.add("on");
      } else {
        activeTypeTabs.delete("all");
        document.getElementById("ktabAll")?.classList.remove("on");
        if (activeTypeTabs.has(type)) {
          activeTypeTabs.delete(type); if (el) el.classList.remove("on");
          if (!activeTypeTabs.size) { activeTypeTabs.add("all"); document.getElementById("ktabAll")?.classList.add("on"); }
        } else {
          activeTypeTabs.add(type); if (el) el.classList.add("on");
        }
      }
      pgPage = 1; renderCards(); updateTabCounts(); updateActiveFilters();
    }
    function updateTabCounts() {
      // Visible keys for this role
      const _vk = loggedRole === "owner"
        ? keys
        : keys.filter(function (k) { return _canSeeUser(k.owner || null); });

      function sv(id, v) { const e = document.getElementById(id); if (e) e.textContent = v; }

      // Total visible
      sv("ktabCntAll", _vk.length);
      // By type
      sv("ktabCntAdm", _vk.filter(function (k) { return k.type === "admin"; }).length);
      sv("ktabCntCst", _vk.filter(function (k) { return k.type === "customer"; }).length);
      sv("ktabCntTrl", _vk.filter(function (k) { return k.type === "trial"; }).length);

      // Status counts (for active tab awareness)
      const now = Date.now();
      const active = _vk.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = _vk.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const disabled = _vk.filter(function (k) { return getRealStatus(k) === "disabled"; }).length;
      const revoked = _vk.filter(function (k) { return getRealStatus(k) === "revoked"; }).length;

      // Section badge (filtered count)
      const filtered = getFiltered();
      const sb = document.getElementById("sectionBadge");
      if (sb) sb.textContent = filtered.length + " " + T(filtered.length !== 1 ? "lbl_word_keys" : "lbl_word_key");

      // Expiry badge (sidebar)
      updateExpireBadge();
    }

    function updateActiveFilters() {
      const af = document.getElementById("activeFilters"); if (!af) return;
      const chips = [];
      if (!activeFilts.has("all")) [...activeFilts].forEach(f => chips.push({ l: "status:" + f, k: "filt:" + f }));
      if (!activeTypeTabs.has("all")) [...activeTypeTabs].forEach(t => chips.push({ l: "type:" + t, k: "type:" + t }));
      if (!ownerFilts.has("all")) [...ownerFilts].forEach(o => chips.push({ l: "owner:" + (o === "__admin__" ? "admin" : o), k: "owner:" + o }));
      if (searchQ) chips.push({ l: '"' + searchQ + '"', k: "search" });
      af.innerHTML = chips.map(c => `<div class="af-chip">${c.l} <span class="af-x" onclick="clearFilter('${c.k}')">✕</span></div>`).join("");
      af.style.display = chips.length ? "flex" : "none";
    }
    function clearFilter(key) {
      if (key === "search") { searchQ = ""; const si = document.getElementById("searchInp"); if (si) si.value = ""; }
      else if (key.startsWith("filt:")) { const f = key.slice(5); activeFilts.delete(f); if (!activeFilts.size) { activeFilts.add("all"); document.getElementById("fAll")?.classList.add("on"); } document.getElementById({ active: "fAct", expired: "fExp", disabled: "fDis", "7d": "f7d", "30d": "f30d" }[f] || "fAll")?.classList.remove("on"); }
      else if (key.startsWith("type:")) { const t = key.slice(5); activeTypeTabs.delete(t); if (!activeTypeTabs.size) { activeTypeTabs.add("all"); document.getElementById("ktabAll")?.classList.add("on"); } document.getElementById({ admin: "ktabAdm", customer: "ktabCst", trial: "ktabTrl" }[t] || "ktabAll")?.classList.remove("on"); }
      else if (key.startsWith("owner:")) { const o = key.slice(6); const realO = o === "admin" ? "__admin__" : o; ownerFilts.delete(realO); if (!ownerFilts.size) { ownerFilts.add("all"); document.getElementById("ownerAll")?.classList.add("on"); } buildOwnerFilterRow(); }
      pgPage = 1; renderCards(); updateActiveFilters();
    }

    /* ══ RENDER CARDS ══ */
    const TIC = { admin: "👑", customer: "🔒", trial: "⏱" };
    const TLBL = { admin: "Admin Key", customer: "Customer Key", trial: "Trial Key" };
    let _rcTimer = null;
    function renderCardsDebounced() { clearTimeout(_rcTimer); _rcTimer = setTimeout(renderCards, 250); } // search debounce
    function renderCards() {
      if (currentPage !== "keys") return;
      const all = getFiltered(); const total = all.length;
      const sb = document.getElementById("sectionBadge"); if (sb) sb.textContent = total + " " + T(total === 1 ? "lbl_word_key" : "lbl_word_keys");
      const totalPages = Math.ceil(total / pgSize) || 1; if (pgPage > totalPages) pgPage = totalPages;
      const rows = all.slice((pgPage - 1) * pgSize, pgPage * pgSize);
      if (viewMode === "mini") {
        (document.getElementById("cardsGrid") || { style: {} }).style.display = "none"; (document.getElementById("miniView") || { style: {} }).style.display = ""; renderMini(rows);
      } else {
        (document.getElementById("cardsGrid") || { style: {} }).style.display = ""; (document.getElementById("miniView") || { style: {} }).style.display = "none";
        const grid = document.getElementById("cardsGrid");
        if (!rows.length) {
          const _hasFilter = searchQ || !activeFilts.has("all") || !activeTypeTabs.has("all") || !ownerFilts.has("all");
          const _canGen = ["owner", "super_admin", "admin", "seller"].includes(loggedRole);
          grid.innerHTML = `<div class="empty"><div class="empty-ico">${_hasFilter ? "🔍" : "🔐"}</div>` +
            `<div id="lbl_no_keys" style="font-size:13px;color:var(--t2);margin-bottom:4px">${_hasFilter ? "No keys match your filter" : "No keys found"}</div>` +
            `<div style="font-size:11px;color:var(--t3);margin-bottom:12px">${_hasFilter ? "Try adjusting filters or search" : "Generate your first key to get started"}</div>` +
            (_hasFilter
              ? `<button class="btn btn-ghost btn-sm" onclick="clearAllFilters()">✕ Clear Filters</button>`
              : (_canGen ? `<button class="btn btn-primary btn-sm" onclick="openGenModal()">+ Generate Key</button>` : "")) +
            `</div>`;
          renderPagination(0, 1); return;
        }
        grid.innerHTML = rows.map((k, i) => buildCard(k, i)).join("");
      }
      renderPagination(total, totalPages);
    }
    function buildCard(k, i) {
      const rs = getRealStatus(k); const tl = fmtTL(k.expiresAt, rs, k.totalMs); const pct = calcPct(k);
      const isSel = selected.has(k.id), isOff = k.enabled === false, isLinked = !!k.hwid;
      const tagsH = (k.tags || []).map(t => tagEl(t)).join("");
      const luStr = k.lastUsed ? fmtDT(k.lastUsed) : "Never";
      const stLbl = { active: "Active", expired: "Expired", revoked: "Revoked", disabled: "Disabled" }[rs] || rs;
      const grpClr = { VIP: "#ffd600", Standard: "var(--cyan)", Reseller: "var(--purple)", Test: "var(--t2)", Event: "var(--green)", Partner: "var(--orange)" }[k.group || ""] || null;
      const priceTag = k.pricePaid > 0 ? `<span class="kc-price">${fmtMoney(k.pricePaid)}</span>` : "";
      const _hlQ = searchQ && !searchQ.startsWith("#") && !searchQ.startsWith("@") ? searchQ : "";
      return `<div class="key-card${isSel ? " kc-sel" : ""}${isOff ? " kc-off" : ""}" data-kid="${k.id}" style="animation-delay:${i * .025}s">
    <div class="kc-bar ${k.type}"></div>
    <div class="kc-hd">
      <div class="kc-hd-l">
        <div class="kc-type-row">${grpClr ? '<span style="font-size:9px;font-weight:700;padding:2px 6px;border-radius:3px;background:' + grpClr + '22;color:' + grpClr + ';border:1px solid ' + grpClr + '44;font-family:JetBrains Mono,monospace">' + k.group + '</span>' : ""}<span>${TIC[k.type]}</span><span class="kc-type-lbl">${TLBL[k.type]}</span><span class="kc-dur">· ${k.dur}</span>${k.createdBy && k.createdBy !== k.owner ? '<span style="font-size:8px;padding:1px 5px;border-radius:3px;background:rgba(0,200,255,.07);color:var(--t3);border:1px solid rgba(0,200,255,.12);font-family:JetBrains Mono,monospace">by ' + k.createdBy + '</span>' : ""}</div>
        ${tagsH ? `<div class="kc-tags-inline">${tagsH}</div>` : ""}
      </div>
      <div class="kc-hd-r">${priceTag}<span class="stbadge ${rs}"><span class="sd"></span>${stLbl}</span><input type="checkbox" class="kc-chk" ${isSel ? "checked" : ""} onchange="toggleSel(${k.id},this)"></div>
    </div>
    <div class="kc-key-row"><span class="kc-key-val" title="${k.key}">${k.key}</span><button class="kc-cpbtn" onclick="copyKey('${k.key}')">⧉</button></div>
    <div class="kc-info">
      <div class="ki"><div class="ki-lbl">Key Active</div><div class="ki-val" style="font-size:10px">${fmtDT(k.createdAt)}</div></div>
      <div class="ki"><div class="ki-lbl">Expired</div><div class="ki-val" style="font-size:10px">${k.expiresAt ? fmtDT(k.expiresAt) : '<span style="color:var(--purple)">∞ Never</span>'}</div></div>
      <div class="ki"><div class="ki-lbl">HWID</div><div class="ki-val" style="color:${isLinked ? "var(--cyan)" : "var(--t2)"};font-size:10px">${isLinked ? "Bound · " + k.hwid : "Unbound"}</div></div>
      <div class="ki" data-expires="${k.expiresAt || 0}" data-rs="${rs}" data-kid="${k.id}"><div class="ki-lbl">Time Left</div><div class="tl-txt ${tl.cls}">${tl.txt}</div>${k.expiresAt && rs !== "revoked" && rs !== "disabled" ? `<div class="ki-tl-bar"><div class="ki-tl-f ${tl.bar}" style="width:${pct.toFixed(1)}%"></div></div>` : ""}</div>
      <div class="ki"><div class="ki-lbl">Last Used</div><div class="ki-val" style="font-size:10px" ondblclick="inlineEdit(${k.id},'user',this)">${luStr}</div></div>
      <div class="ki"><div class="ki-lbl">OS</div><div class="ki-val" style="font-size:10px">${k.os || "—"}</div></div>
    </div>
    <div class="kc-foot"><div class="kc-lastused">Last: ${luStr} · HWID: ${k.hwid || "—"}</div></div>
    <div class="kc-acts">
      <div class="kc-act copy" onclick="copyKey('${k.key}')"><span class="kc-act-ico">⧉</span><span class="kc-act-lbl">Copy Key</span></div>
      <div class="kc-act info" onclick="openDetail(${k.id})"><span class="kc-act-ico">◎</span><span class="kc-act-lbl">Detail</span></div>
      <div class="kc-act ext" onclick="openExt(${k.id})"><span class="kc-act-ico">⏰</span><span class="kc-act-lbl">Extend</span></div>
      <div class="kc-act lnk${isLinked ? " linked" : ""}" onclick="${isLinked ? `doUnlink(${k.id})` : `openLinkModal(${k.id})`}"><span class="kc-act-ico">🔗</span><span class="kc-act-lbl">${isLinked ? "Unlink" : "Link"}</span></div>
      <div class="kc-act onoff${isOff ? " off-state" : ""}" onclick="toggleKey(${k.id})"><span class="kc-act-ico">${isOff ? "▶" : "⏸"}</span><span class="kc-act-lbl">Toggle</span></div>
      <div class="kc-act rst" onclick="${rs === "expired" ? `renewKey(${k.id})` : `resetKey(${k.id})`}"><span class="kc-act-ico">↺</span><span class="kc-act-lbl">${rs === "expired" ? "Renew" : "Reset"}</span></div>
      <div class="kc-act del" onclick="deleteKey(${k.id})"><span class="kc-act-ico">✕</span><span class="kc-act-lbl">Delete</span></div>
    </div>
  </div>`;
    }
    function renderMini(rows) {
      const body = document.getElementById("miniBody"); if (!body) return;
      if (!rows.length) { body.innerHTML = `<tr><td class="mt-td" colspan="7" style="text-align:center;color:var(--t3);padding:20px">${T("lbl_no_keys_found")}</td></tr>`; return; }
      body.innerHTML = rows.map(k => {
        const rs = getRealStatus(k); const tl = fmtTL(k.expiresAt, rs, k.totalMs);
        const stClr = { active: "var(--green)", expired: "var(--orange)", revoked: "var(--t3)", disabled: "var(--red)" }[rs];
        return `<tr>
      <td class="mt-td"><span class="mt-key" title="${k.key}">${k.key}</span><span style="display:block;font-size:9px;color:var(--t3)">${k.user || "—"}</span></td>
      <td class="mt-td"><span class="mt-hwid${k.hwid ? " bound" : ""}">${k.hwid ? T("hwid_bound") : T("hwid_unbound")}</span></td>
      <td class="mt-td">${k.os || "—"}</td>
      <td class="mt-td" style="font-size:10px;color:var(--t2)">${k.expiresAt ? fmtDT(k.expiresAt) : "∞"}<br><span class="tl-mini ${tl.cls}" data-mini-expires="${k.expiresAt || 0}" data-mini-rs="${rs}" data-mini-tm="${k.totalMs || 0}">${tl.txt}</span></td>
      <td class="mt-td" style="font-size:10px;color:var(--t3)">${k.lastUsed ? fmtDT(k.lastUsed) : T("lbl_never")}</td>
      <td class="mt-td"><span style="font-size:10px;font-weight:700;color:${stClr}">${(T("st_" + rs) || rs).toUpperCase()}</span></td>
      <td class="mt-td"><div class="mt-actions">${_miniActions(k, rs)}</div></td>
    </tr>`;
      }).join("");
    }
    function setView(v, el) { viewMode = v; document.querySelectorAll(".vt-btn").forEach(b => b.classList.remove("on")); if (el) el.classList.add("on"); renderCards(); }
    function renderPagination(total, totalPages) {
      const el = document.getElementById("paginationEl"); if (!el) return;
      if (total <= pgSize) { el.innerHTML = ""; return; }
      let html = `<button class="pg-btn" onclick="goPage(${pgPage - 1})" ${pgPage <= 1 ? "disabled" : ""}>‹</button>`;
      const maxShow = 5; let start = Math.max(1, pgPage - 2), end = Math.min(totalPages, start + maxShow - 1); if (end - start < maxShow - 1) start = Math.max(1, end - maxShow + 1);
      if (start > 1) html += `<button class="pg-btn" onclick="goPage(1)">1</button>${start > 2 ? `<span class="pg-info">…</span>` : ""}`;
      for (let i = start; i <= end; i++)html += `<button class="pg-btn${i === pgPage ? " on" : ""}" onclick="goPage(${i})">${i}</button>`;
      if (end < totalPages) html += `${end < totalPages - 1 ? `<span class="pg-info">…</span>` : ""}<button class="pg-btn" onclick="goPage(${totalPages})">${totalPages}</button>`;
      html += `<button class="pg-btn" onclick="goPage(${pgPage + 1})" ${pgPage >= totalPages ? "disabled" : ""}>›</button>`;
      html += `<span class="pg-info">${(pgPage - 1) * pgSize + 1}-${Math.min(pgPage * pgSize, total)} of ${total}</span>`;
      html += `<select class="pg-size" onchange="setPgSize(this.value)">${[10, 20, 50, 100].map(n => `<option value="${n}"${n === pgSize ? " selected" : ""}>${n}/pg</option>`).join("")}</select>`;
      el.innerHTML = html;
    }
    function goPage(p) { pgPage = p; renderCards(); }
    /* setPgSize: see improved version below */

    /* ══ LIVE TL UPDATE ══ */
    _appTimers.push(setInterval(() => {
      if (currentPage !== "keys") return;
      document.querySelectorAll("[data-expires]").forEach(el => {
        const exp = parseInt(el.getAttribute("data-expires")) || 0; const rs = el.getAttribute("data-rs") || "active";
        const kid = parseInt(el.getAttribute("data-kid") || "0"); const k = keys.find(x => x.id === kid);
        const tl = fmtTL(exp || null, rs, k ? k.totalMs : null);
        const span = el.querySelector(".tl-txt"); const bar = el.querySelector(".ki-tl-f");
        if (span && span.textContent !== tl.txt) { span.textContent = tl.txt; span.className = "tl-txt " + tl.cls; }
        if (bar && k) { bar.style.width = calcPct(k).toFixed(1) + "%"; }
      });
      document.querySelectorAll("[data-mini-expires]").forEach(el => {
        const exp = parseInt(el.getAttribute("data-mini-expires")) || 0; const rs = el.getAttribute("data-mini-rs") || "active";
        const tm = parseInt(el.getAttribute("data-mini-tm") || "0"); const tl = fmtTL(exp || null, rs, tm || null);
        if (el.textContent !== tl.txt) { el.textContent = tl.txt; el.className = "tl-mini " + tl.cls; }
      });
    }, 1000));

    /* ══ AUTO EXPIRE ══ */
    _appTimers.push(setInterval(() => {
      let ch = false;
      keys.forEach(k => { if (k.expiresAt && k.expiresAt < Date.now() && k.status === "active" && k.enabled !== false) { k.status = "expired"; ch = true; if (!expArchive.find(x => x.id === k.id)) { expArchive.unshift({ ...k, archivedAt: Date.now() }); if (expArchive.length > 200) expArchive.pop(); } addLog("⌛", "Key expired", k.key, "action"); } });
      if (ch) { save(); saveArch(); updateStats(); if (currentPage === "keys") renderCards(); }
    }, 5000));

    /* ══ KEY ACTIONS ══ */
    function deleteKey(id) { const k = keys.find(x => x.id === id); if (!k) return; if (!_canEditKey(k)) { toast("Access denied", "e"); return; } const snap = [...keys]; keys = keys.filter(x => x.id !== id); selected.delete(id); save(); updateStats(); renderCards(); updateBulk(); buildCreatorFilterRow(); addLog("🗑", "Deleted key [" + k.type + "]", k.key, "action"); notifyWebhook("🗑 Key deleted: **" + k.key.substring(0, 20) + "** by " + loggedUser, "delete"); showUndo("Deleted: " + k.key.substring(0, 18), function () { keys = snap; save(); updateStats(); renderCards(); buildCreatorFilterRow(); }); }
    function revokeKey(id) { const k0 = keys.find(x => x.id === id); if (!k0 || !_canEditKey(k0)) { toast("Access denied", "e"); return; } confirm2("Revoke", "Revoke this key?", "⚠", () => { const k = keys.find(x => x.id === id); if (k) { k.status = "revoked"; save(); renderCards(); addLog("🚫", "Revoked", k.key, "action"); toast(T("t_revoke"), "i"); } }); }
    function toggleKey(id) { const k = keys.find(x => x.id === id); if (!k) return; if (!_canEditKey(k)) { toast("Access denied", "e"); return; } k.enabled = k.enabled === false; save(); renderCards(); addLog(k.enabled !== false ? "▶" : "⏸", k.enabled !== false ? "Enabled" : "Disabled", k.key, "action"); toast(k.enabled !== false ? T("t_enable") : T("t_disable"), "i"); }
    function resetKey(id) { const k0 = keys.find(x => x.id === id); if (!k0 || !_canEditKey(k0)) { toast("Access denied", "e"); return; } confirm2("Reset", "Reset HWID & data?", "↺", () => { const k = keys.find(x => x.id === id); if (k) { k.hwid = null; k.os = null; k.lastUsed = null; k.usage = 0; k.ip = null; k.ipCountry = null; k.ipCity = null; k.ipOrg = null; k.ipTime = null; k.boundAt = null; save(); renderCards(); addLog("↺", "Reset key status", k.key, "action"); toast(T("t_reset"), "i"); } }); }
    function renewKey(id) { openExt(id); }
    function copyKey(key) {
      function _fallback() {
        try { const ta = document.createElement("textarea"); ta.value = key; ta.style.cssText = "position:fixed;left:-9999px;top:-9999px;opacity:0"; document.body.appendChild(ta); ta.select(); ta.setSelectionRange(0, 99999); document.execCommand("copy"); ta.remove(); toast(T("t_copy") + " ✓", "i"); addLog("📋", "Copied", key.substring(0, 22), "action"); } catch (e) { toast("Copy failed: tap and hold the key", "w"); }
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(key).then(() => { toast(T("t_copy") + " ✓", "i"); addLog("📋", "Copied", key.substring(0, 22), "action"); }).catch(_fallback);
      } else { _fallback(); }
    }
    function doUnlink(id) { const k0 = keys.find(x => x.id === id); if (!k0 || !_canEditKey(k0)) { toast("Access denied", "e"); return; } confirm2("Unlink", "Remove device binding?", "🔗", () => { const k = keys.find(x => x.id === id); if (k) { k.hwid = null; k.os = null; k.ip = null; k.ipCountry = null; k.ipCity = null; k.ipOrg = null; k.ipTime = null; k.boundAt = null; save(); renderCards(); addLog("🔗", "Unlinked device (HWID + IP reset)", k.key, "action"); toast(T("t_unlink"), "i"); } }); }
    function setKeyGroup(id, g) { const k = keys.find(x => x.id === id); if (k) { k.group = g; save(); renderCards(); addLog("🏷", "Group: " + g, k.key, "action"); } }
    function inlineEdit(id, field, el) { const k = keys.find(x => x.id === id); if (!k) return; const inp = document.createElement("input"); inp.value = k[field] || ""; inp.className = "fi"; inp.style.fontSize = "16px"; inp.style.cssText = "font-size:11px;padding:3px 7px;width:110px;display:inline-block"; el.replaceWith(inp); inp.focus(); inp.select(); const done = () => { const v = inp.value.trim(); if (v !== k[field]) { k[field] = v; save(); addLog("✏", "Edit " + field, k.key, "action"); } renderCards(); }; inp.addEventListener("blur", done); inp.addEventListener("keydown", ev => { if (ev.key === "Enter") done(); if (ev.key === "Escape") renderCards(); }); }
    function exportKeys(filtered) {
      // PYRAMID: even "all" export only includes keys the user can see
      let src;
      if (filtered) {
        src = getFiltered();
      } else {
        const vis = getMyVisibleUsers();
        src = vis ? keys.filter(function (k) { return _canSeeUser(k.owner); }) : keys;
      }
      const csv = ["Key,Type,User,Tags,Status,Activated,Expired,Duration,HWID,OS,LastUsed,PricePaid"].concat(src.map(k => k.key + "," + k.type + "," + (k.user || "") + "," + (k.tags || []).join("|") + "," + getRealStatus(k) + "," + fmtDT(k.createdAt) + "," + (k.expiresAt ? fmtDT(k.expiresAt) : "Never") + "," + k.dur + "," + (k.hwid || "") + "," + (k.os || "") + "," + (k.lastUsed ? fmtDT(k.lastUsed) : "") + "," + (k.pricePaid || 0))).join("\n");
      const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" })); a.download = "ln_keys_" + Date.now() + ".csv"; a.click(); addLog("⬇", "Exported " + src.length + " keys", "", "action"); toast(T("t_export"), "s");
    }


    /* ══ SELECT/BULK ══ */
    function toggleSel(id, el) { el.checked ? selected.add(id) : selected.delete(id); updateBulk(); }
    function selAll() { getFiltered().forEach(k => selected.add(k.id)); updateBulk(); renderCards(); }
    function clearSel() { selected.clear(); updateBulk(); renderCards(); }
    function updateBulk() { const n = selected.size; document.getElementById("bulkInfo").textContent = n + " selected"; document.getElementById("bulkBar").classList.toggle("show", n > 0); }
    function bulkDo(action) {
      const n = selected.size; if (!n) return; const snap = [...keys];
      confirm2(action, "Execute on " + n + " keys?", "⚡", () => {
        selected.forEach(id => {
          const k = keys.find(x => x.id === id); if (!k) return;
          if (action === "enable") { k.enabled = true; if (k.status === "revoked") k.status = "active"; }
          else if (action === "disable") { k.enabled = false; }
          else if (action === "reset") { k.hwid = null; k.os = null; k.lastUsed = null; }
          else if (action === "delete") { keys = keys.filter(x => x.id !== id); }
        });
        save(); updateStats(); clearSel(); renderCards();
        addLog("⚡", "Bulk " + action + ": " + n + " keys", "", "mass");
        if (action === "delete") showUndo("Deleted " + n + " keys", () => { keys = snap; save(); updateStats(); renderCards(); });
        toast(n + " done", "s");
      });
    }
    function kbNav(dir) { if (currentPage !== "keys") return; const rows = getFiltered(); if (!rows.length) return; kbSelIdx = Math.max(0, Math.min(rows.length - 1, kbSelIdx + dir)); selected.clear(); selected.add(rows[kbSelIdx].id); updateBulk(); renderCards(); const cards = document.querySelectorAll(".key-card"); if (cards[kbSelIdx]) cards[kbSelIdx].scrollIntoView({ behavior: "smooth", block: "nearest" }); }

    /* ══ EXTEND ══ */
    function openExt(id) { extKeyId = id; const k = keys.find(x => x.id === id); if (!k) return; document.getElementById("extSub").textContent = "// " + k.key; document.getElementById("extDur").value = "7"; document.getElementById("extUnit").value = "days"; document.getElementById("extExactDate").value = ""; document.querySelectorAll("#extModal .ext-qbtn").forEach(b => b.classList.remove("on")); updateExtPrev(); document.getElementById("extModal").classList.add("open"); }
    function extFromDetail() { closeModal("detailModal"); if (detId) openExt(detId); }
    function setEQ(days, el, ctx) { const cont = ctx === "mass" ? "#massModal" : ctx === "bext" ? "#bextModal" : "#extModal"; document.querySelectorAll(cont + " .ext-qbtn").forEach(b => b.classList.remove("on")); if (el) el.classList.add("on"); const dId = ctx === "bext" ? "bextDur" : ctx === "mass" ? "meDur" : "extDur"; const uId = ctx === "bext" ? "bextUnit" : ctx === "mass" ? "meUnit" : "extUnit"; document.getElementById(dId).value = days; document.getElementById(uId).value = "days"; if (ctx === "ext") updateExtPrev(); }
    function extFromDate() { const v = document.getElementById("extExactDate").value; if (!v) return; const ts = new Date(v).getTime(); if (!isNaN(ts)) document.getElementById("extPrev").textContent = fmtDT(ts); }
    function updateExtPrev() { const k = extKeyId ? keys.find(x => x.id === extKeyId) : null; const dur = parseInt(document.getElementById("extDur").value) || 7; const unit = document.getElementById("extUnit").value; const add = dur * (MS[unit] || 86400000); const base = k && k.expiresAt && k.expiresAt > Date.now() ? k.expiresAt : Date.now(); document.getElementById("extPrev").textContent = fmtDT(base + add); }
    function doExtend() {
      const k = keys.find(x => x.id === extKeyId); if (!k) return;
      if (!_canEditKey(k)) { toast("Access denied", "e"); return; }
      const ev = document.getElementById("extExactDate").value; let newExp;
      if (ev) { newExp = new Date(ev).getTime(); if (isNaN(newExp)) { toast("Invalid date", "e"); return; } }
      else { const dur = parseInt(document.getElementById("extDur").value) || 7; const unit = document.getElementById("extUnit").value; const add = dur * (MS[unit] || 86400000); const base = k.expiresAt && k.expiresAt > Date.now() ? k.expiresAt : Date.now(); newExp = base + add; }
      k.expiresAt = newExp; k.totalMs = k.expiresAt - k.createdAt; if (k.status === "expired") { k.status = "active"; k.enabled = true; }
      save(); renderCards(); closeModal("extModal"); addLog("⏰", "Extended expiry", k.key, "action"); toast(T("t_extend"), "s");
    }
    function openBulkExt() { document.getElementById("bextSub").textContent = "// " + selected.size + " keys"; document.getElementById("bextDur").value = "7"; document.getElementById("bextUnit").value = "days"; document.getElementById("bextModal").classList.add("open"); }
    function doBulkExt() { const dur = parseInt(document.getElementById("bextDur").value) || 7; const unit = document.getElementById("bextUnit").value; const add = dur * (MS[unit] || 86400000); const cnt = selected.size; selected.forEach(id => { const k = keys.find(x => x.id === id); if (!k) return; const base = k.expiresAt && k.expiresAt > Date.now() ? k.expiresAt : Date.now(); k.expiresAt = base + add; k.totalMs = k.expiresAt - k.createdAt; }); save(); renderCards(); closeModal("bextModal"); clearSel(); toast(cnt + " " + T("t_extend"), "s"); }

    /* ══ LINK ══ */
    function openLinkModal(id) { linkKeyId = id; const k = keys.find(x => x.id === id); if (!k) return; document.getElementById("lnkSub").textContent = "// " + k.key; document.getElementById("lnkKey").textContent = k.key; document.getElementById("lnkHwid").value = k.hwid || ""; selOsV = k.os || ""; document.querySelectorAll(".os-opt").forEach(o => o.classList.toggle("on", o.getAttribute("data-os") === selOsV)); document.getElementById("linkModal").classList.add("open"); }
    function selOS(el, os) { selOsV = os; document.querySelectorAll(".os-opt").forEach(o => o.classList.remove("on")); el.classList.add("on"); }
    function doLink() {
      const k = keys.find(x => x.id === linkKeyId); if (!k) return;
      if (!_canEditKey(k)) { toast("Access denied", "e"); return; }
      k.hwid = document.getElementById("lnkHwid").value.trim() || null;
      k.os = selOsV || null;
      k.boundAt = Date.now();
      save(); renderCards(); closeModal("linkModal");
      addLog("🔗", "Linked device", k.key, "action", { note: "HWID: " + (k.hwid || "-") + " · OS: " + (k.os || "-") });
      toast(T("t_link"), "s");
      // Capture IP at binding time (async, non-blocking)
      if (k.hwid) {
        _fetchIPInfo().then(function (info) {
          if (info && info.ip) {
            k.ip = info.ip;
            k.ipCountry = info.country || "";
            k.ipCity = info.city || "";
            k.ipOrg = info.org || "";
            k.ipTime = Date.now();
            save();
            addLog("🌐", "IP captured for binding", k.key, "action", { note: info.ip + (info.country ? " · " + info.country : "") });
            // Refresh detail modal if open
            if (typeof openDetail === "function" && document.getElementById("detailModal") && document.getElementById("detailModal").classList.contains("open")) openDetail(k.id);
          }
        });
      }
    }

    /* ══ DETAIL ══ */
    function openDetail(id) {
      const k = keys.find(x => x.id === id);
      if (!k) { toast("Key not found", "w"); return; }
      // Seller can only view their own keys
      if (loggedRole === "seller" && k.owner && k.owner !== loggedUser) { toast("Access denied", "e"); return; }
      detId = id;
      const rs = getRealStatus(k); const tl = fmtTL(k.expiresAt, rs, k.totalMs);
      document.getElementById("detSub").textContent = "// " + k.type.toUpperCase() + " KEY";
      document.getElementById("detKey").textContent = k.key;
      document.getElementById("detType").textContent = TLBL[k.type];
      document.getElementById("detStatus").textContent = rs.toUpperCase();
      document.getElementById("detDur").textContent = k.dur;
      document.getElementById("detActivated").textContent = fmtDT(k.createdAt);
      document.getElementById("detExpired").textContent = k.expiresAt ? fmtDT(k.expiresAt) : "∞ Never";
      document.getElementById("detHwid").textContent = k.hwid ? "Bound · " + k.hwid : "Unbound";
      document.getElementById("detLastUsed").textContent = k.lastUsed ? fmtDT(k.lastUsed) : "Never";
      document.getElementById("detDevice").textContent = (k.os || "Unknown") + " | HWID: " + (k.hwid || "Unbound");
      // IP info (captured at binding)
      const detIPEl = document.getElementById("detIP");
      if (detIPEl) {
        if (k.ip) {
          const loc = [k.ipCity, k.ipCountry].filter(Boolean).join(", ");
          detIPEl.textContent = k.ip + (loc ? " · " + loc : "") + (k.ipTime ? " · " + fmtDT(k.ipTime) : "");
          detIPEl.style.color = "var(--cyan)";
        } else {
          detIPEl.textContent = k.hwid ? "Capturing…" : "Not bound";
          detIPEl.style.color = "var(--t3)";
        }
      }
      document.getElementById("detPrice").textContent = k.pricePaid ? fmtMoney(k.pricePaid) : "—";
      const te = document.getElementById("detTL"); te.textContent = tl.txt; te.style.color = { "tl-ok": "var(--cyan)", "tl-warn": "var(--orange)", "tl-exp": "var(--red)", "tl-life": "var(--purple)" }[tl.cls] || "var(--cyan)";
      const gs = document.getElementById("detGroupSel"); if (gs) gs.value = k.group || "";
      // Timeline
      const timeline = document.getElementById("detTimeline");
      if (timeline) { const evs = []; if (k.createdAt) evs.push({ t: k.createdAt, ico: "⭐", lbl: "Created", c: "var(--cyan)" }); if (k.hwid) evs.push({ t: k.createdAt + 1, ico: "🔗", lbl: "Device Linked", c: "var(--purple)" }); if (k.lastUsed) evs.push({ t: k.lastUsed, ico: "▶", lbl: "Last Used", c: "var(--green)" }); if (k.expiresAt && k.expiresAt < Date.now()) evs.push({ t: k.expiresAt, ico: "⌛", lbl: "Expired", c: "var(--orange)" }); else if (k.expiresAt) evs.push({ t: k.expiresAt, ico: "📅", lbl: "Will Expire", c: "var(--yellow)" }); if (k.status === "revoked") evs.push({ t: Date.now(), ico: "🚫", lbl: "Revoked", c: "var(--red)" }); evs.sort((a, b) => a.t - b.t); timeline.innerHTML = evs.map(ev => `<div style="position:relative;padding:4px 0 4px 12px;margin-bottom:4px"><div class="timeline-dot" style="border-color:${ev.c}">${ev.ico}</div><div style="font-size:11px;font-weight:600;color:${ev.c}">${ev.lbl}</div><div style="font-size:9.5px;color:var(--t3);font-family:'JetBrains Mono',monospace">${fmtDT(ev.t)}</div></div>`).join(""); }
      _renderDetailTags(k);
      document.getElementById("detailModal").classList.add("open");
    }
    function toggleFromDetail() { if (detId) { toggleKey(detId); closeModal("detailModal"); } }
    function revokeFromDetail() { closeModal("detailModal"); if (detId) revokeKey(detId); }

    /* ══ MASS EXECUTE ══ */
    function openMassModal() {
      // Sellers cannot use Mass Execute
      if (loggedRole === "seller") {
        toast("Mass Execute is not available for sellers", "e");
        return;
      }
      meTypeFilts = new Set(["all"]); meStatusFilts = new Set(["all"]); meTimeF = "all"; meSellerF = "all"; meSellerFilts = new Set(["all"]); meCategoryF = "all";
      // Pre-sync with View Account filter from Key Manager
      meAccountFilts = ownerFilts.size > 0 ? new Set(ownerFilts) : new Set(["all"]);
      document.querySelectorAll("#meTypeChips .me-chip").forEach((c, i) => c.classList.toggle("on", i === 0));
      document.querySelectorAll("#meStatusChips .me-chip").forEach((c, i) => c.classList.toggle("on", i === 0));
      document.querySelectorAll(".me-time-btn").forEach((b, i) => b.classList.toggle("on", i === 0));
      const md = document.getElementById("meManualDays"); if (md) { md.value = ""; md.style.display = "none"; }
      const ep = document.getElementById("meExtPanel"); if (ep) ep.classList.remove("show");
      meCategoryF = "all";
      buildMassSellerChips();
      buildMeAccountChips(); // populate Filter by Account chips (owner + admin)
      updateMassPreview();
      document.getElementById("massModal").classList.add("open");
    }
    function meChip(el, group, val) {
      const setRef = group === "type" ? meTypeFilts : meStatusFilts;
      if (val === "all" || val === "All Types" || val === "All Status") {
        setRef.clear(); setRef.add("all");
        const cont = group === "type" ? "meTypeChips" : "meStatusChips";
        document.querySelectorAll("#" + cont + " .me-chip").forEach(c => c.classList.remove("on"));
        if (el) el.classList.add("on");
      } else {
        setRef.delete("all");
        const cont = group === "type" ? "meTypeChips" : "meStatusChips";
        document.querySelectorAll("#" + cont + " .me-chip:first-child").forEach(c => c.classList.remove("on"));
        if (setRef.has(val)) { setRef.delete(val); el.classList.remove("on"); if (!setRef.size) { setRef.add("all"); document.querySelectorAll("#" + cont + " .me-chip:first-child").forEach(c => c.classList.add("on")); } }
        else { setRef.add(val); el.classList.add("on"); }
      }
      updateMassPreview();
    }
    function meTime(el, val) { document.querySelectorAll(".me-time-btn").forEach(b => b.classList.remove("on")); if (el) el.classList.add("on"); meTimeF = val; const md = document.getElementById("meManualDays"); if (md) md.style.display = val === "manual" ? "block" : "none"; updateMassPreview(); }
    function getMassFiltered() {
      const _mfVis = loggedRole === "owner" ? keys : keys.filter(function (k) { return _canSeeUser(k.owner || null); });
      return _mfVis.filter(k => {
        const rs = getRealStatus(k);
        // Seller: only their own keys
        if (loggedRole === "seller" && k.owner && k.owner !== loggedUser) return false;
        // Account filter (Filter by Account section) — applies to owner + admin + super_admin
        if (!meAccountFilts.has("all")) {
          const acc = [...meAccountFilts];
          const ok = acc.some(function (f) {
            if (f === "all") return true;
            if (f === "__self__") return k.owner === loggedUser;
            if (f.startsWith("admin:")) {
              const an = f.slice(6);
              const admSellers = sellers.filter(function (sr) { return sr.adminOwner === an; }).map(function (sr) { return sr.name; });
              return k.owner === an || admSellers.includes(k.owner);
            }
            if (f.startsWith("seller:")) return k.owner === f.slice(7);
            return k.owner === f;
          });
          if (!ok) return false;
        }
        // Type multi-filter
        if (!meTypeFilts.has("all") && ![...meTypeFilts].some(t => k.type === t)) return false;
        // Status multi-filter
        if (!meStatusFilts.has("all") && ![...meStatusFilts].some(st => rs === st)) return false;
        if (meTimeF === "expired") return rs === "expired";
        if (meTimeF === "manual") { const d = parseInt((document.getElementById("meManualDays") || {}).value) || 0; if (!d) return true; if (!k.expiresAt) return false; const r = k.expiresAt - Date.now(); return r > 0 && r <= d * 86400000; }
        if (meTimeF !== "all") { const md = parseInt(meTimeF) || 0; if (!k.expiresAt) return false; const r = k.expiresAt - Date.now(); return r > 0 && r <= md * 86400000; }
        return true;
      });
    }
    function updateMassPreview() {
      const m = getMassFiltered();
      const ce = document.getElementById("meCount"); if (ce) ce.textContent = m.length;
      const td = { admin: 0, customer: 0, trial: 0 };
      m.forEach(k => td[k.type] = (td[k.type] || 0) + 1);
      const acctInfo = meAccountFilts.has("all") ? "All Accounts" : (meAccountFilts.size + " account(s) selected");
      const catInfo = "";
      const typeInfo = meTypeFilts.has("all") ? "All types" : [...meTypeFilts].join("+");
      const statusInfo = meStatusFilts.has("all") ? "All status" : [...meStatusFilts].join("+");
      const pd = document.getElementById("mePrevDetail");
      if (pd) pd.textContent = acctInfo + " · " + catInfo + " · " + typeInfo + " · " + statusInfo + " · A:" + td.admin + " C:" + td.customer + " T:" + td.trial;
    }
    function meShowExt() { const p = document.getElementById("meExtPanel"); if (p) p.classList.toggle("show"); }
    function doMassAction(action) {
      const matched = getMassFiltered(); const n = matched.length; if (!n) { toast("No keys match", "w"); return; }
      const snap = [...keys];
      if (action === "delete") { const inp = prompt("Type DELETE to confirm deleting " + n + " keys:"); if (inp !== "DELETE") { toast("Cancelled", "w"); return; } doMassExec(action, matched, n, snap); return; }
      confirm2(action, action + " — " + n + " keys?", "⚡", () => doMassExec(action, matched, n, snap));
    }
    function doMassExec(action, matched, n, snap) {
      if (action === "extend") {
        const dur = parseInt(document.getElementById("meDur").value) || 7;
        const unit = document.getElementById("meUnit").value;
        const add = dur * (MS[unit] || 86400000);
        matched.forEach(function (k) { const base = k.expiresAt && k.expiresAt > Date.now() ? k.expiresAt : Date.now(); k.expiresAt = base + add; k.totalMs = k.expiresAt - k.createdAt; });
      } else {
        const ids = new Set(matched.map(function (m) { return m.id; }));
        matched.forEach(function (k) {
          if (action === "enable") { k.enabled = true; if (k.status === "revoked") k.status = "active"; }
          else if (action === "disable") { k.enabled = false; }
          else if (action === "reset") { k.hwid = null; k.os = null; k.lastUsed = null; }
          else if (action === "revoke") { k.status = "revoked"; }
          else if (action === "delete") { keys = keys.filter(function (x) { return !ids.has(x.id); }); }
        });
      }
      save(); updateStats(); buildOwnerFilterRow(); buildCreatorFilterRow(); renderCards(); updateMassPreview(); closeModal("massModal");
      addLog("⚡", "Mass " + action + ": " + n + " keys", "", "mass");
      if (action === "delete") showUndo("Mass deleted " + n + " keys", function () { keys = snap; save(); updateStats(); renderCards(); });
      toast(n + " " + (T("t_mass") || "executed"), "s");
    }

    /* ══ SELLER MANAGEMENT ══ */
    function openAddSellerModal() {
      document.getElementById("srName").value = ""; document.getElementById("srPass").value = "";// srPrefix removed - auto-inherited
      document.getElementById("srToken").value = "100000"; document.getElementById("srNotes").value = ""; document.getElementById("addSellerModal").classList.add("open");
    }
    function doAddSeller() {
      const nm = document.getElementById("srName").value.trim(); const pw = document.getElementById("srPass").value.trim();
      // Prefix auto-inherited from creator (not editable by seller)
      let pfx = "X3";
      if (loggedRole === "owner") { pfx = secLoad("lnOwnerPrefix_" + loggedUser, "") || "X3"; }
      else if (loggedRole === "admin" || loggedRole === "super_admin") { const ma = adminAccounts.find(function (a) { return a.name === loggedUser; }); pfx = ma && ma.prefix ? ma.prefix : "X3"; }
      const tok = parseInt(document.getElementById("srToken").value) || 0;
      const curr = document.getElementById("srCurrency").value || "IDR";
      const notes = document.getElementById("srNotes").value.trim();
      if (!nm || !pw) { toast("Fill name and password", "w"); return; }
      if (ADMIN_USERS[nm]) { toast("Username reserved", "e"); return; }
      if (sellers.find(s => s.name === nm)) { toast("Username already exists", "e"); return; }
      sellers.push({ name: nm, pass: "b1$" + btoa(pw), prefix: pfx, balance: tok, currency: curr, notes, createdAt: Date.now(), keyCount: 0, totalSpend: 0, adminOwner: loggedUser });
      saveSellers(); closeModal("addSellerModal"); renderSellersList();
      addLog("👥", "Seller added: " + nm, "", "action"); toast(T("t_seller_added"), "s");
    }
    function renderSellersList() {
      const el = document.getElementById("sellersList"); if (!el) return;
      const sq = ((document.getElementById("sellerSearch") || {}).value || "").toLowerCase();
      // PYRAMID: owner/super_admin... NO — super_admin only sees THEIR sellers
      let base;
      if (loggedRole === "owner") {
        base = sellers; // owner sees ALL
      } else if (loggedRole === "super_admin" || loggedRole === "admin") {
        base = sellers.filter(function (sr) { return sr.adminOwner === loggedUser || sr.createdBy === loggedUser; });
      } else {
        base = []; // sellers cannot view sellers list
      }
      const visible = sq ? base.filter(sr => sr.name.toLowerCase().includes(sq) || (sr.notes || "").toLowerCase().includes(sq) || (sr.prefix || "").toLowerCase().includes(sq)) : base;
      if (!visible.length) { el.innerHTML = '<div class="log-empty">No sellers yet. Click "+ Add Seller" to create one.</div>'; return; }
      const totalBal = visible.reduce((a, sr) => a + (sr.balance || 0), 0);
      const totalRev = visible.reduce((a, sr) => a + keys.filter(k => k.owner === sr.name).reduce((b, k) => b + (k.pricePaid || 0), 0), 0);
      const totalKeys = visible.reduce((a, sr) => a + keys.filter(k => k.owner === sr.name).length, 0);
      el.innerHTML =
        '<div style="overflow-x:auto;-webkit-overflow-scrolling:touch">' +
        '<table style="width:100%;border-collapse:collapse;font-size:12px;min-width:700px">' +
        '<thead><tr style="background:rgba(0,200,255,.04);border-bottom:2px solid var(--b)">' +
        '<th style="padding:10px 12px;text-align:left;font-size:9px;color:var(--t3);font-weight:700;letter-spacing:1px;text-transform:uppercase;white-space:nowrap">Seller</th>' +
        '<th style="padding:10px 12px;text-align:right;font-size:9px;color:var(--t3);font-weight:700;letter-spacing:1px;text-transform:uppercase;white-space:nowrap">Balance</th>' +
        '<th style="padding:10px 12px;text-align:center;font-size:9px;color:var(--t3);font-weight:700;letter-spacing:1px;text-transform:uppercase">Total</th>' +
        '<th style="padding:10px 12px;text-align:center;font-size:9px;color:var(--green);font-weight:700;letter-spacing:1px;text-transform:uppercase">Active</th>' +
        '<th style="padding:10px 12px;text-align:center;font-size:9px;color:var(--orange);font-weight:700;letter-spacing:1px;text-transform:uppercase">Expired</th>' +
        '<th style="padding:10px 12px;text-align:right;font-size:9px;color:var(--yellow);font-weight:700;letter-spacing:1px;text-transform:uppercase">Revenue</th>' +
        '<th style="padding:10px 12px;text-align:center;font-size:9px;color:var(--orange);font-weight:700;letter-spacing:1px;text-transform:uppercase">Admin</th>' +
        '<th style="padding:10px 12px;text-align:center;font-size:9px;color:var(--t3);font-weight:700;letter-spacing:1px;text-transform:uppercase">Actions</th>' +
        '</tr></thead>' +
        '<tbody>' +
        visible.map(function (sr) {
          const i = sellers.indexOf(sr);
          const myKeys = keys.filter(function (k) { return k.owner === sr.name; });
          const active = myKeys.filter(function (k) { return getRealStatus(k) === "active"; }).length;
          const expired = myKeys.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
          const disabled = myKeys.filter(function (k) { return getRealStatus(k) === "disabled"; }).length;
          const rev = myKeys.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
          const curr = sr.currency || "IDR";
          const sym = (CURRENCIES[curr] && CURRENCIES[curr].sym) || "Rp";
          const rate = currSettings[curr] || 1;
          const bal = sr.balance || 0;
          const balVal = fmtMoney(bal);
          const revVal = fmtMoney(rev);
          const balClr = bal < 1000 ? "var(--red)" : bal < 10000 ? "var(--orange)" : "var(--green)";
          const lastActive = myKeys.length ? fmtLast(Math.max.apply(null, myKeys.map(function (k) { return k.createdAt || 0; }))) : "Never";
          const joinDate = new Date(sr.createdAt).toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "2-digit" });
          const adminBound = sr.adminOwner || "—";
          const pfxTag = sr.prefix ? ('<span style="font-size:9px;background:rgba(136,51,255,.15);color:#bb77ff;border:1px solid rgba(136,51,255,.25);border-radius:4px;padding:1px 5px;font-family:\'JetBrains Mono\',monospace">' + sr.prefix + '</span>') : "";
          return '<tr style="border-bottom:1px solid rgba(255,255,255,.025)">' +
            '<td style="padding:10px 12px">' +
            '<div style="display:flex;align-items:center;gap:8px">' +
            '<div class="seller-av" style="width:28px;height:28px;font-size:10px;flex-shrink:0">' + sr.name.substring(0, 2).toUpperCase() + '</div>' +
            '<div>' +
            '<div style="font-size:12px;font-weight:700;color:var(--t1)">' + escHtml(sr.name) + ' ' + pfxTag + '</div>' +
            '<div style="font-size:9px;color:var(--t3);margin-top:1px">' + joinDate + ' · ' + curr + ' · ' + lastActive + '</div>' +
            (sr.notes ? '<div style="font-size:9.5px;color:var(--t2);margin-top:1px">' + escHtml(sr.notes) + '</div>' : '') +
            '</div>' +
            '</div>' +
            '</td>' +
            '<td style="padding:10px 12px;text-align:right">' +
            '<div style="font-size:13px;font-weight:800;color:' + balClr + ';font-family:\'JetBrains Mono\',monospace">' + balVal + '</div>' +
            '<div style="font-size:9px;color:var(--t3)">' + bal.toLocaleString('en-US') + ' tokens</div>' +
            '</td>' +
            '<td style="padding:10px 12px;text-align:center;font-size:15px;font-weight:800;color:var(--t1)">' + myKeys.length + '</td>' +
            '<td style="padding:10px 12px;text-align:center;font-size:15px;font-weight:800;color:var(--green)">' + active + '</td>' +
            '<td style="padding:10px 12px;text-align:center">' +
            '<div style="font-size:15px;font-weight:800;color:var(--orange)">' + expired + '</div>' +
            '<div style="font-size:9px;color:var(--red)">' + disabled + ' off</div>' +
            '</td>' +
            '<td style="padding:10px 12px;text-align:right;font-size:12px;font-weight:700;color:var(--yellow);font-family:\'JetBrains Mono\',monospace">' + revVal + '</td>' +
            '<td style="padding:10px 12px;text-align:center">' +
            '<span style="font-size:10px;background:rgba(255,123,0,.1);border:1px solid rgba(255,123,0,.2);border-radius:4px;padding:2px 7px;color:var(--orange);font-weight:700;font-family:\'JetBrains Mono\',monospace">' + adminBound + '</span>' +
            '</td>' +
            '<td style="padding:10px 12px">' +
            '<div style="display:flex;gap:4px;flex-wrap:wrap;justify-content:center">' +
            '<button class="btn btn-yellow btn-xs" onclick="openTopup(' + i + ')" title="Balance">💵</button>' +
            '<button class="btn btn-ghost btn-xs" onclick="editSeller(' + i + ')" title="Edit">✏️</button>' +
            '<button class="btn btn-ghost btn-xs" onclick="showSellerCreds(' + i + ')" title="Credentials">👁</button>' +
            '<button class="btn btn-ghost btn-xs" onclick="viewSellerKeys(' + i + ')" title="Keys">🔑</button>' +
            '<button class="btn btn-ghost btn-xs" onclick="viewSellerActivity(' + i + ')" title="Activity">📋</button>' +
            '<button class="btn btn-danger btn-xs" onclick="deleteSeller(' + i + ')" title="Delete">✕</button>' +
            '</div>' +
            '</td>' +
            '</tr>';
        }).join("") +
        '</tbody></table></div>' +
        '<div style="display:flex;gap:14px;padding:9px 14px;background:rgba(0,200,255,.025);border-top:1px solid var(--b);font-size:10.5px;font-family:\'JetBrains Mono\',monospace;flex-wrap:wrap">' +
        '<span>Sellers: <b style="color:var(--t1)">' + visible.length + '</b></span>' +
        '<span>Keys: <b style="color:var(--cyan)">' + totalKeys + '</b></span>' +
        '<span>Balance: <b style="color:var(--yellow)">' + fmtMoney(totalBal) + '</b></span>' +
        '<span>Revenue: <b style="color:var(--green)">' + fmtMoney(totalRev) + '</b></span>' +
        '</div>';
    }
    let topupSellerIdx = -1;
    function openTopup(idx) {
      topupSellerIdx = idx; const sr = sellers[idx]; if (!sr) return;
      document.getElementById("topupSellerName").textContent = "Seller: " + sr.name;
      document.getElementById("topupCurrentBal").textContent = fmtMoney(sr.balance);
      document.getElementById("topupAmount").value = "10000";
      document.getElementById("topupReason").value = "";
      document.getElementById("topupModal").classList.add("open");
    }
    function doTopup() {
      const action = document.getElementById("topupAction").value;
      const amount = parseInt(document.getElementById("topupAmount").value) || 0;
      const reason = document.getElementById("topupReason").value.trim();
      const note = reason ? " (" + reason + ")" : "";
      const sr = sellers[topupSellerIdx]; if (!sr) return;
      if (loggedRole === "seller" || !_canSeeUser(sr.name)) { toast("Access denied", "e"); return; }
      const _prevBal = sr.balance;
      if (action === "add") { sr.balance += amount; _recordBalHistory(sr.name, amount, "Admin topup by " + loggedUser); }
      else if (action === "deduct") { const _prev = sr.balance; sr.balance = Math.max(0, sr.balance - amount); _recordBalHistory(sr.name, -((_prev) - sr.balance), "Admin deduct by " + loggedUser); }
      else if (action === "set") sr.balance = amount;
      saveSellers(); closeModal("topupModal"); renderSellersList(); updateTokenDisplay();
      addLog("💵", "Balance " + action + " for seller " + sr.name, "", "token", { before: fmtMoney(_prevBal), after: fmtMoney(sr.balance), note: reason || "" });
      toast(T("t_topup"), "s");

    }
    function viewSellerActivity(idx) {
      const sr = sellers[idx]; if (!sr) return;
      // Switch to log page and filter by seller name via search
      switchPage("log");
      const ls = document.getElementById("logSearch");
      if (ls) { ls.value = sr.name; }
      if (typeof renderLog === "function") renderLog();
      toast("Activity log for " + sr.name, "i");
    }
    function deleteSeller(idx) {
      const sr = sellers[idx]; if (!sr) return;
      if (loggedRole === "seller" || !_canSeeUser(sr.name)) { toast("Access denied", "e"); return; }
      confirm2("Delete Seller", "Delete " + escHtml(sr.name) + " and ALL their keys?", "⚠", () => {
        keys = keys.filter(k => k.owner !== sr.name); sellers.splice(idx, 1);
        saveSellers(); save(); updateStats(); renderSellersList();
        addLog("🗑", "Deleted seller: " + sr.name + " (prefix " + (sr.prefix || "-") + ")", "", "action"); toast("Deleted", "s");
      });
    }

    /* ══ PRICING SETTINGS ══ */
    function openPricingModal() {
      const f = document.getElementById("pricingForm"); if (!f) return;
      const sym = (CURRENCIES[activeCurr] && CURRENCIES[activeCurr].sym) || "Rp";
      const currCode = activeCurr;
      const cl = document.getElementById("pricingCurrLabel");
      if (cl) cl.textContent = "Currency: " + currCode + " (" + sym + ")";
      const matrix = [
        { tp: "admin", label: "ADMIN MATRIX VALUES", icon: "👑", clr: "var(--ca)", bg: "rgba(255,123,0,.04)", bord: "rgba(255,123,0,.18)", cols: 4 },
        { tp: "customer", label: "CUSTOMER MATRIX VALUES", icon: "🔒", clr: "var(--cc)", bg: "rgba(0,200,255,.03)", bord: "rgba(0,200,255,.12)", cols: 4 },
        { tp: "trial", label: "TRIAL MATRIX VALUES", icon: "⏱", clr: "var(--ct)", bg: "rgba(0,229,160,.03)", bord: "rgba(0,229,160,.12)", cols: 2 }
      ];
      f.innerHTML = matrix.map(function (m) {
        const durs = PRESET_DURS[m.tp] || [];
        const colCss = "repeat(" + m.cols + ",1fr)";
        return '<div style="margin-bottom:14px;background:' + m.bg + ';border:1px solid ' + m.bord + ';border-radius:var(--r);padding:14px 16px;position:relative">' +
          '<div style="position:absolute;left:0;top:0;bottom:0;width:3px;background:' + m.clr + ';border-radius:3px 0 0 3px"></div>' +
          '<div style="display:flex;align-items:center;gap:8px;margin-bottom:12px">' +
          '<span style="font-size:15px">' + m.icon + '</span>' +
          '<span style="font-size:11px;font-weight:800;color:' + m.clr + ';text-transform:uppercase;letter-spacing:1.3px">' + m.label + '</span>' +
          '<span style="margin-left:auto;font-size:9.5px;padding:2px 8px;border-radius:4px;background:' + m.clr + '22;color:' + m.clr + ';border:1px solid ' + m.clr + '44;font-family:JetBrains Mono,monospace;font-weight:700">' + sym + ' ' + currCode + '</span>' +
          '</div>' +
          '<div style="display:grid;grid-template-columns:' + colCss + ';gap:10px">' +
          durs.map(function (p) {
            const cur = pricing[m.tp + "_" + p.k] || 0;
            return '<div>' +
              '<label style="display:block;font-size:10px;font-weight:700;color:var(--t2);margin-bottom:5px;font-family:JetBrains Mono,monospace;letter-spacing:.4px">' + p.l + '</label>' +
              '<div style="position:relative">' +
              '<span style="position:absolute;left:9px;top:50%;transform:translateY(-50%);font-size:11px;color:' + m.clr + ';font-weight:800;pointer-events:none;font-family:JetBrains Mono,monospace;user-select:none">' + sym + '</span>' +
              '<input class="fi price-matrix-input" style="padding:10px 10px 10px 28px;font-size:13px;font-weight:700;font-family:JetBrains Mono,monospace;border-color:' + m.bord + '" ' +
              'id="price_' + m.tp + '_' + p.k + '" type="number" value="' + cur + '" min="0" placeholder="0" ' +
              'onfocus="this.select()" inputmode="numeric">' +
              '</div>' +
              '</div>';
          }).join("") +
          '</div>' +
          '</div>';
      }).join("");
      // Init tabs
      switchPDTab("pricing", document.getElementById("pdTabPricing"));
      document.getElementById("pricingModal").classList.add("open");
    }


    function savePricingSettings() {
      ["admin", "customer", "trial"].forEach(tp => { PRESET_DURS[tp].forEach(p => { const el = document.getElementById("price_" + tp + "_" + p.k); if (el) pricing[tp + "_" + p.k] = parseInt(el.value) || 0; }); });
      savePricing(); closeModal("pricingModal"); buildDurPresets(); addLog("💰", "Updated pricing matrix", "", "settings"); toast(T("t_price_saved"), "s");
    }

    /* ══ CURRENCY SETTINGS ══ */

    function saveCurrencySettings() {
      Object.keys(CURRENCIES).forEach(k => { const el = document.getElementById("curr_" + k); if (el) currSettings[k] = parseFloat(el.value) || 0; });
      secSave("lnCurrV1", currSettings); closeModal("currencyModal"); buildCurrSelect(); onGenChange();
      addLog("💱", "Updated currency rates", "", "settings"); toast(T("t_curr_saved"), "s");
    }


    /* ══ CUSTOMERS ══ */



    /* ══ IMPORT CSV ══ */
    function openImportModal() { pendingImport = []; document.getElementById("importPreview").style.display = "none"; document.getElementById("importSummary").textContent = ""; document.getElementById("importConfirmBtn").style.display = "none"; document.getElementById("importModal").classList.add("open"); }
    function importDragOver(e) { e.preventDefault(); document.getElementById("importDrop").style.borderColor = "var(--cyan)"; }
    function importDragLeave() { document.getElementById("importDrop").style.borderColor = ""; }
    function importDropEvt(e) { e.preventDefault(); importDragLeave(); const f = e.dataTransfer.files[0]; if (f) parseCSV(f); }
    function importFileSel(e) { const f = e.target.files[0]; if (f) parseCSV(f); }
    function parseCSV(file) {
      const reader = new FileReader();
      reader.onload = ev => {
        const lines = ev.target.result.split("\n").filter(l => l.trim());
        pendingImport = [];
        lines.slice(1).forEach(line => { const cols = line.split(","); if (cols.length < 2) return; const key = cols[0].trim(); if (key) pendingImport.push({ id: Date.now() + Math.random(), key, type: (cols[1] || "customer").toLowerCase(), user: cols[2]?.trim() || "imported", status: "active", enabled: true, expiresAt: null, createdAt: Date.now(), totalMs: null, dur: "Imported", tags: [], hwid: null, os: null, lastUsed: null, usage: 0, pricePaid: 0, owner: loggedUser }); });
        const prev = document.getElementById("importPreview"); prev.style.display = "block"; prev.textContent = pendingImport.slice(0, 5).map(k => k.key + " | " + k.type + " | " + k.user).join("\n") + (pendingImport.length > 5 ? "\n...and " + (pendingImport.length - 5) + " more" : "");
        document.getElementById("importSummary").textContent = pendingImport.length + " keys ready";
        document.getElementById("importConfirmBtn").style.display = "";
      };
      reader.readAsText(file);
    }
    function doImport() { if (!pendingImport.length) return; if (loggedRole === "seller") { toast("Access denied", "e"); return; } keys = [...pendingImport, ...keys]; save(); updateStats(); renderCards(); addLog("⬆", "Imported " + pendingImport.length + " keys", "", "action"); toast(pendingImport.length + " " + T("t_import") || "imported", "s"); closeModal("importModal"); pendingImport = []; }

    /* ══ MODALS ══ */
    function openGenModal() {
      // Clear stale preset if it's an old key that no longer exists
      const _oldKeys = new Set(["1h", "14d", "60d", "90d"]);
      if (selPresetDur && _oldKeys.has(selPresetDur)) selPresetDur = null;
      isLifetime = false;
      // Hide trial card for sellers
      const trialCard = document.getElementById("to-trial");
      if (trialCard) trialCard.style.display = loggedRole === "seller" ? "none" : "";
      selType("customer");
      pendingTags = []; renderTagEd(); buildPresets();
      // Show custom prefix for owner/admin
      const cpRow = document.getElementById("customPfxRow");
      const cpInp = document.getElementById("inCustomPfx");
      const canCustomPfx = loggedRole === "owner" || loggedRole === "admin" || loggedRole === "super_admin";
      if (cpRow) cpRow.style.display = canCustomPfx ? "" : "none";
      if (cpInp) {
        // Load saved prefix
        let savedPfx = "";
        if (loggedRole === "owner") savedPfx = secLoad("lnOwnerPrefix_" + loggedUser, "") || "";
        else if (loggedRole === "admin" || loggedRole === "super_admin") { const adm = adminAccounts.find(function (a) { return a.name === loggedUser; }); savedPfx = adm && adm.prefix ? adm.prefix : ""; }
        cpInp.value = savedPfx;
      }
      const spb = document.getElementById("savedPfxBadge"); if (spb) spb.style.display = "none";
      const dcb = document.getElementById("durCancelBtn"); if (dcb) dcb.style.display = "none";
      setTimeout(updateKeyDetailPreview, 30);
      // Show template button for owner/super_admin
      const tmplBtn = document.getElementById("customPresetsBtn");
      if (tmplBtn) tmplBtn.style.display = (loggedRole === "owner" || loggedRole === "super_admin") ? "flex" : "none";
      // Owner: unlimited qty
      const qMax = document.getElementById("lbl_qty_max");
      const qInp = document.getElementById("inQty");
      if (loggedRole === "owner") { if (qMax) qMax.textContent = "(unlimited)"; if (qInp && qInp.removeAttribute) qInp.removeAttribute("max"); }
      else if (loggedRole === "admin" || loggedRole === "super_admin") { if (qMax) qMax.textContent = "(max 200)"; if (qInp) qInp.setAttribute("max", "200"); }
      else { if (qMax) qMax.textContent = "(max 50)"; if (qInp) qInp.setAttribute("max", "50"); }
      // User label
      // inUserLabel removed
      const si = document.getElementById("inSuf"); if (si) si.value = "";
      const qi = document.getElementById("inQty"); if (qi) qi.value = "1";
      ["inMonths", "inDays", "inHours"].forEach(id => { const el = document.getElementById(id); if (el) { el.value = "0"; el.disabled = false; } });
      const da = document.getElementById("dupAlert"); if (da) da.style.display = "none";
      buildDurPresets(); // explicit refresh on every modal open
      onGenChange();
      document.getElementById("genModal").classList.add("open");
    }
    function closeModal(id, checkDirty) {
      if (checkDirty && id === "genModal") {
        const sufEl = document.getElementById("inSuf"); const suf = sufEl ? sufEl.value.trim() : "";
        if (suf || pendingTags.length > 0) { confirm2("Discard", "Discard unsaved data?", "⚠", () => { document.getElementById(id).classList.remove("open"); pendingTags = []; renderTagEd(); if (sufEl) sufEl.value = ""; selType("customer"); }); return; }
      }
      const el = document.getElementById(id); if (el) el.classList.remove("open");
    }
    document.querySelectorAll(".overlay").forEach(o => o.addEventListener("click", function (e) { if (e.target === this && this.id !== "confModal") this.classList.remove("open"); }));
    let _confCb = null;
    function confirm2(title, msg, ico, cb) { document.getElementById("confTitle").textContent = title; document.getElementById("confMsg").innerHTML = msg; document.getElementById("confIco").textContent = ico; _confCb = cb; document.getElementById("confOk").onclick = () => { closeModal("confModal"); _confCb && _confCb(); }; document.getElementById("confModal").classList.add("open"); }

    /* ══ UNDO ══ */
    function showUndo(msg, cb) { if (undoTimer) clearTimeout(undoTimer); undoCb = cb; const ut = document.getElementById("undoToast"), um = document.getElementById("undoMsg"); if (ut && um) { um.textContent = msg; ut.classList.add("show"); } undoTimer = setTimeout(dismissUndo, 5000); }
    function doUndo() { if (undoCb) { undoCb(); undoCb = null; } dismissUndo(); toast("Undo done", "s"); }
    function dismissUndo() { const ut = document.getElementById("undoToast"); if (ut) ut.classList.remove("show"); if (undoTimer) clearTimeout(undoTimer); }

    /* ══ TOAST ══ */
    function toast(msg, type, dur) {
      type = type || "s";
      const icons = { s: "✓", e: "✕", i: "ℹ", w: "⚠" };
      const tc = document.getElementById("toastC"); if (!tc) return;
      // Limit max 4 toasts
      while (tc.children.length >= 4) tc.removeChild(tc.firstChild);
      const el = document.createElement("div");
      el.className = "toast " + type;
      el.innerHTML = '<span>' + (icons[type] || "•") + '</span>' + msg;
      el.onclick = function () { el.remove(); };
      el.title = "Click to dismiss";
      tc.appendChild(el);
      const ms = dur || (type === "e" ? 5000 : 3400);
      setTimeout(function () { try { el.remove(); } catch (e) { } }, ms);
    }




    /* ══ SELLER DASHBOARD ══ */
    function renderSellersDash() { renderHierarchyDash(); }


    /* ══ MASS EXECUTE SELLER FILTER ══ */
    let meSellerF = "all";
    let meTypeFilts = new Set(["all"]);
    let meStatusFilts = new Set(["all"]);
    function buildMassSellerChips() {
      const el = document.getElementById("meSellerChips");
      const sec = document.getElementById("meSellerSection");
      if (!el || !sec) return;
      // Hide since meAccountChips replaces this for owner
      if (loggedRole === "owner" || loggedRole === "super_admin") { sec.style.display = "none"; return; }
      if (loggedRole !== "admin" || !sellers.length) { sec.style.display = "none"; return; }
      sec.style.display = "block";
      const mySellers = (loggedRole === "owner") ? sellers : sellers.filter(s => s.adminOwner === loggedUser || s.createdBy === loggedUser);
      el.innerHTML = '<div class="me-chip on" onclick="meSellerChip(this,\'all\')">All Sellers</div>' +
        mySellers.map(sr => '<div class="me-chip" onclick="meSellerChip(this,\'' + escHtml(sr.name) + '\')" style="border-color:rgba(136,51,255,.3)">👤 ' + escHtml(sr.name) + '</div>').join("");

      // Set current selection
      el.querySelectorAll(".me-chip").forEach(c => {
        const oc = c.getAttribute("onclick") || "";
        const m = oc.match(/meSellerChip\(this,'([^']+)'\)/);
        const val = m ? m[1] : "all";
        c.classList.toggle("on", val === meSellerF);
      });
    }
    let meSellerFilts = new Set(["all"]);
    function meSellerChip(el, val) {
      if (val === "all") {
        meSellerFilts = new Set(["all"]);
        document.querySelectorAll("#meSellerChips .me-chip").forEach(c => c.classList.remove("on"));
        if (el) el.classList.add("on");
      } else {
        meSellerFilts.delete("all");
        document.querySelector("#meSellerChips .me-chip") && document.querySelector("#meSellerChips .me-chip").classList.remove("on");
        if (meSellerFilts.has(val)) { meSellerFilts.delete(val); if (el) el.classList.remove("on"); if (!meSellerFilts.size) { meSellerFilts.add("all"); document.querySelectorAll("#meSellerChips .me-chip").forEach((c, i) => { if (i === 0) c.classList.add("on"); }); } }
        else { meSellerFilts.add(val); if (el) el.classList.add("on"); }
      }
      meSellerF = meSellerFilts.has("all") ? "all" : [...meSellerFilts][0]; // compat
      updateMassPreview();
    }

    /* ══ MULTI-TAB SYNC ══ */
    (function () {
      if (!window.BroadcastChannel) return;
      let bc; try { bc = new BroadcastChannel("ln_mods_sync"); } catch (e) { return; }
      bc.onmessage = ev => {
        if (!loggedUser) return;
        if (ev.data && ev.data.type === "keys_updated") {
          keys = secLoad("lnKeysV8", []);
          updateStats(); if (currentPage === "keys") renderCards();
        }
      };
      const _origSave = save;
      save = function () { _origSave(); try { bc.postMessage({ type: "keys_updated" }); } catch (e) { } };
    })();

    /* (custCount removed - using custTotalLbl) */

    /* ══ OWNER FILTER ══ */
    let ownerFilts = new Set(["all"]); // multi: 'all' | '__admin__' | seller names
    function setOwnerFilt(owner, el) {
      if (owner === "all") {
        ownerFilts = new Set(["all"]);
        document.querySelectorAll("#ownerFilterRow .ktab").forEach(b => b.classList.remove("on"));
        if (el) el.classList.add("on");
      } else {
        ownerFilts.delete("all");
        document.getElementById("ownerAll")?.classList.remove("on");
        if (ownerFilts.has(owner)) {
          ownerFilts.delete(owner); if (el) el.classList.remove("on");
          if (!ownerFilts.size) { ownerFilts.add("all"); document.getElementById("ownerAll")?.classList.add("on"); }
        } else {
          ownerFilts.add(owner); if (el) el.classList.add("on");
        }
      }
      _updateOwnerRowState();
      pgPage = 1; renderCards(); updateActiveFilters();
    }
    function buildOwnerFilterRow() {
      const section = document.getElementById("ownerFilterRow"); if (!section) return;
      const wrapper = document.getElementById("unifiedFilterRow");
      const canFilter = ["admin", "super_admin", "owner"].includes(loggedRole);
      if (!canFilter) { if (wrapper) wrapper.style.display = "none"; return; }

      // Clear previous chips (keep display:contents, just empty innerHTML)
      section.innerHTML = "";

      function mkB(html, val, color, indent) {
        const b = document.createElement("button");
        b.className = "ktab" + (ownerFilts.has(val) ? " on" : "");
        b.setAttribute("data-val", val);
        b.style.cssText = "font-size:9.5px;padding:2px 7px;" + (color ? "border-color:" + color + "44;color:" + color : "") +
          (indent ? ";margin-left:4px" : "");
        b.innerHTML = html;
        b.title = "Click to filter · dbl-click to reset";
        b.onclick = function () { setOwnerFilt(val, b); };
        b.ondblclick = function () { ownerFilts = new Set(["all"]); buildOwnerFilterRow(); renderCards(); updateActiveFilters(); toast("Filter reset", "i"); };
        return b;
      }

      const allBtn = mkB("🔑 All", "all", null, false);
      allBtn.id = "ownerAll";
      allBtn.ondblclick = function () { ownerFilts = new Set(["all"]); buildOwnerFilterRow(); renderCards(); updateActiveFilters(); toast("Filter reset", "i"); };
      section.appendChild(allBtn);

      let addedCount = 0;
      if (loggedRole === "owner" || loggedRole === "super_admin") {
        // Own keys for this user (only their own, not all)
        const ownK2 = keys.filter(function (k) { return k.owner === loggedUser; });
        if (ownK2.length) {
          const oc = loggedRole === "owner" ? "var(--ca)" : "var(--yellow)";
          const oi = loggedRole === "owner" ? "⚡" : "★";
          section.appendChild(mkB(oi + " " + escHtml(loggedUser) + " <span style='font-size:8px;opacity:.5'>(" + ownK2.length + ")</span>", "__self__", oc, false));
          addedCount++;
        } else ownerFilts.delete("__self__");

        adminAccounts.forEach(function (adm) {
          if (adm.name === loggedUser) return; // skip self — already shown as __self__
          const admK = keys.filter(function (k) { return k.owner === adm.name; });
          if (!admK.length) { ownerFilts.delete("admin:" + adm.name); return; }
          section.appendChild(mkB("👑 " + escHtml(adm.name) + " <span style='font-size:8px;opacity:.5'>(" + admK.length + ")</span>", "admin:" + adm.name, "var(--ca)", false));
          addedCount++;
          sellers.filter(function (sr) { return sr.adminOwner === adm.name; }).forEach(function (sr) {
            const srK = keys.filter(function (k) { return k.owner === sr.name; });
            if (!srK.length) { ownerFilts.delete("seller:" + sr.name); return; }
            section.appendChild(mkB("└ 👤 " + escHtml(sr.name) + " <span style='font-size:8px;opacity:.5'>(" + srK.length + ")</span>", "seller:" + sr.name, "var(--purple)", true));
            addedCount++;
          });
        });
        sellers.filter(function (sr) { return !sr.adminOwner; }).forEach(function (sr) {
          const srK = keys.filter(function (k) { return k.owner === sr.name; });
          if (!srK.length) { ownerFilts.delete("seller:" + sr.name); return; }
          section.appendChild(mkB("👤 " + escHtml(sr.name) + " <span style='font-size:8px;opacity:.5'>(" + srK.length + ")</span>", "seller:" + sr.name, "var(--purple)", false));
          addedCount++;
        });
      } else {
        const ownK = keys.filter(function (k) { return !k.owner || k.owner === loggedUser; });
        if (ownK.length) {
          section.appendChild(mkB("👑 Me <span style='font-size:8px;opacity:.5'>(" + ownK.length + ")</span>", "__admin__", "var(--cyan)", false));
          addedCount++;
        } else ownerFilts.delete("__admin__");
        sellers.filter(function (sr) { return !sr.adminOwner || sr.adminOwner === loggedUser; }).forEach(function (sr) {
          const srK = keys.filter(function (k) { return k.owner === sr.name; });
          if (!srK.length) { ownerFilts.delete("seller:" + sr.name); return; }
          section.appendChild(mkB("└ 👤 " + escHtml(sr.name) + " <span style='font-size:8px;opacity:.5'>(" + srK.length + ")</span>", "seller:" + sr.name, "var(--purple)", true));
          addedCount++;
        });
      }

      if (!addedCount) {
        // Hide wrapper if creator row also has nothing
        buildCreatorFilterRow();
        return;
      }
      if (!ownerFilts.size) ownerFilts = new Set(["all"]);
      if (wrapper) wrapper.style.display = "";
      _updateOwnerRowState(); // apply dim/bright states after rebuild
      buildCreatorFilterRow();
    }





    /* admin self-balance system removed */



    /* ══ DASHBOARD VIEW FILTER ══ */





    /* ══ MULTI-FILTER ══ */
    let activeFilts = new Set(["all"]);
    function toggleFilt(f, el) {
      if (f === "all") {
        activeFilts = new Set(["all"]);
        document.querySelectorAll(".fbtn").forEach(b => b.classList.remove("on"));
        if (el) el.classList.add("on");
      } else {
        activeFilts.delete("all"); document.getElementById("fAll").classList.remove("on");
        if (activeFilts.has(f)) {
          activeFilts.delete(f); if (el) el.classList.remove("on");
          if (!activeFilts.size) { activeFilts.add("all"); document.getElementById("fAll").classList.add("on"); }
        } else {
          activeFilts.add(f); if (el) el.classList.add("on");
        }
      }
      pgPage = 1; sessionStorage.setItem("lnFilt", JSON.stringify({ activeFilts: [...activeFilts], searchQ }));
      renderCards(); updateActiveFilters();
    }
    // Legacy compat
    /* setFilt: real implementation above */


    /* ══ TOUCH SUPPORT ══ */
    (function () {
      let touchStartX = 0, touchStartY = 0;
      document.addEventListener("touchstart", e => {
        touchStartX = e.changedTouches[0].screenX;
        touchStartY = e.changedTouches[0].screenY;
      }, { passive: true });
      document.addEventListener("touchend", e => {
        const dx = e.changedTouches[0].screenX - touchStartX;
        const dy = e.changedTouches[0].screenY - touchStartY;
        // Swipe right on narrow screen to open sidebar
        if (window.innerWidth < 1024 && dx > 60 && Math.abs(dy) < 40 && touchStartX < 30) {
          const sb = document.getElementById("sidebar");
          if (sb && !sb.classList.contains("mobile-open")) toggleMobile();
        }
        // Swipe left to close sidebar
        if (window.innerWidth < 1024 && dx < -60 && Math.abs(dy) < 40) {
          closeMobile();
        }
      }, { passive: true });
    })();


    function viewSellerKeys(idx) {
      const sr = sellers[idx]; if (!sr) return;
      switchPage("keys");
      ownerFilts = new Set(["seller:" + sr.name]);
      buildOwnerFilterRow();
      if (typeof _updateOwnerRowState === "function") _updateOwnerRowState();
      pgPage = 1; renderCards(); updateActiveFilters && updateActiveFilters();
      toast("Viewing " + escHtml(sr.name) + "'s keys", "i");
      addLog("👁", "View keys: " + sr.name, "", "action");
    }


    function exportSellersReport() {
      const rows = (loggedRole === "owner") ? sellers : sellers.filter(s => s.adminOwner === loggedUser || s.createdBy === loggedUser);
      if (!rows.length) { toast("No sellers", "w"); return; }
      const csv = ["Name,Prefix,Balance,Currency,AdminOwner,Keys,ActiveKeys,Revenue,Notes,Joined"].concat(rows.map(sr => {
        const myK = keys.filter(k => k.owner === sr.name);
        const act = myK.filter(k => getRealStatus(k) === "active").length;
        const rev = myK.reduce((a, k) => a + (k.pricePaid || 0), 0);
        const joined = new Date(sr.createdAt).toLocaleDateString("en-GB");
        return [sr.name, sr.prefix || "", sr.balance, sr.currency || "IDR", sr.adminOwner || "", myK.length, act, rev, sr.notes || "", joined].join(",");
      })).join("\n");
      const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
      a.download = "sellers_report_" + Date.now() + ".csv"; a.click();
      toast("Sellers exported", "s");
    }


    /* ══ MASS EXECUTE CATEGORY FILTER ══ */
    let meCategoryF = "all"; // 'all'|'admin_keys'|'seller_keys'



    /* ══ OWNER: ADD SELLER DIRECTLY ══ */
    function openOwnerAddSellerModal() {
      document.getElementById("oasName").value = "";
      document.getElementById("oasPass").value = "";
      // oasPrefix removed - auto-inherited

      document.getElementById("oasBalance").value = "100000";
      document.getElementById("oasNotes").value = "";
      // Populate admin dropdown
      const sel = document.getElementById("oasAdminOwner");
      sel.innerHTML = '<option value="">— No Admin (Direct) —</option>' +
        adminAccounts.map(function (a) { return '<option value="' + a.name + '">' + a.name + ' (' + a.type + ')</option>'; }).join('');
      document.getElementById("ownerAddSellerModal").classList.add("open");
    }
    function ownerAddSellerSave() {
      if (loggedRole === "seller") { toast("Access denied", "e"); return; }
      const nm = document.getElementById("oasName").value.trim();
      const pw = document.getElementById("oasPass").value.trim();
      if (!nm || !pw) { toast("Fill name + password", "w"); return; }
      if (sellers.find(function (s) { return s.name === nm; }) || adminAccounts.find(function (a) { return a.name === nm; })) { toast("Username exists", "e"); return; }
      const adminOwner = document.getElementById("oasAdminOwner").value || "";
      const bal = parseInt(document.getElementById("oasBalance").value) || 0;
      // Auto-assign prefix from assigned admin, or owner's prefix
      let pfxForSeller = "X3";
      if (adminOwner) { const ba = adminAccounts.find(function (a) { return a.name === adminOwner; }); if (ba && ba.prefix) pfxForSeller = ba.prefix; }
      else { pfxForSeller = secLoad("lnOwnerPrefix_" + loggedUser, "") || "X3"; }
      sellers.push({
        name: nm, pass: "b1$" + btoa(pw),
        prefix: pfxForSeller,
        balance: bal, currency: "IDR",
        notes: document.getElementById("oasNotes").value.trim(),
        createdAt: Date.now(), keyCount: 0, totalSpend: 0,
        adminOwner: adminOwner,
        createdBy: loggedUser
      });
      saveSellers(); closeModal("ownerAddSellerModal");
      // Rebuild views
      buildOwnerFilterRow();/* buildDashViewChips removed */buildMassSellerChips();
      if (currentPage === "sellers") renderSellersList();
      if (currentPage === "owners_admins") renderOwnerAdminsList();
      addLog("⚡", "Owner created seller: " + nm + (adminOwner ? " → " + adminOwner : ""), "", "action");
      toast("Seller created", "s");
    }


    /* ══ DOUBLE-CLICK RESET ══ */
    // Any .ktab double-click resets to "all"
    document.addEventListener("dblclick", function (ev) {
      const el = ev.target.closest(".ktab,.fbtn,.me-chip,.sales-pb,.vt-btn,.sort-btn,.owner-sel-btn");
      if (!el) return;
      // Key type tabs → reset to All
      if (el.classList.contains("ktab") && el.id !== "ktabAll" && !el.classList.contains("owner-sel-btn")) {
        ev.preventDefault();
        activeTypeTabs = new Set(["all"]);
        document.querySelectorAll(".ktab").forEach(function (b) { b.classList.remove("on"); });
        const allTab = document.getElementById("ktabAll"); if (allTab) allTab.classList.add("on");
        if (currentPage === "keys") { renderCards(); updateTabCounts(); }
        toast("Tab filter reset", "i"); return;
      }
      // Status filter buttons → reset to All
      if (el.classList.contains("fbtn") && el.id !== "fAll") {
        ev.preventDefault();
        activeFilts = new Set(["all"]);
        document.querySelectorAll(".fbtn").forEach(function (b) { b.classList.remove("on"); });
        const fa = document.getElementById("fAll"); if (fa) fa.classList.add("on");
        if (currentPage === "keys") renderCards();
        updateActiveFilters();
        toast("Status filter reset", "i"); return;
      }
      // Owner filter row → reset to All
      if (el.classList.contains("owner-sel-btn") || el.id === "ownerMe") {
        ev.preventDefault();
        ownerFilts = new Set(["all"]);
        document.querySelectorAll("#ownerFilterRow .ktab").forEach(function (b) { b.classList.remove("on"); });
        const oa = document.getElementById("ownerAll"); if (oa) oa.classList.add("on");
        if (currentPage === "keys") renderCards();
        updateActiveFilters();
        toast("Owner filter reset", "i"); return;
      }
      // Mass execute chips → reset section
      if (el.classList.contains("me-chip")) {
        ev.preventDefault();
        const parent = el.closest("#meTypeChips,#meStatusChips,#meSellerChips,#meCategorySection");
        if (!parent) return;
        if (parent.id === "meTypeChips") { meTypeFilts = new Set(["all"]); }
        else if (parent.id === "meStatusChips") { meStatusFilts = new Set(["all"]); }
        else if (parent.id === "meSellerChips") { meSellerFilts = new Set(["all"]); }
        else if (parent.id === "meCategorySection") { meCategoryF = "all"; }
        // Reset all chips in parent to first=on, rest=off
        parent.querySelectorAll(".me-chip").forEach(function (c, i) { c.classList.toggle("on", i === 0); });
        updateMassPreview();
        toast("Filter reset", "i"); return;
      }
      // Sales period buttons → reset to 7d
      if (el.classList.contains("sales-pb") && !el.classList.contains("on")) { return; }
      if (el.classList.contains("sales-pb")) {
        ev.preventDefault();
        setSalesPeriod("7d", null);
        document.querySelectorAll(".sales-pb").forEach(function (b) { b.classList.remove("on"); });
        document.querySelectorAll(".sales-pb").forEach(function (b) { if (b.textContent.includes("7")) b.classList.add("on"); });
        toast("Chart period reset", "i"); return;
      }
      // Sort buttons → reset
      if (el.classList.contains("sort-btn")) {
        ev.preventDefault();
        sortBy = "expiry"; sortDir = 1;
        document.querySelectorAll(".sort-btn").forEach(function (b) { b.classList.remove("on", "asc", "desc"); });
        if (currentPage === "keys") renderCards();
        toast("Sort reset", "i"); return;
      }
      // View mode → reset to card
      if (el.classList.contains("vt-btn")) {
        ev.preventDefault();
        setView("card", document.querySelector(".vt-btn"));
        toast("View reset to card", "i"); return;
      }
    });


    /* ══ MASS EXECUTE: PER-ACCOUNT FILTER ══ */
    let meAccountFilts = new Set(["all"]); // 'all' | 'admin:name' | 'seller:name'

    function buildMeAccountChips() {
      const el = document.getElementById("meAccountChips");
      const sec = document.getElementById("meCategorySection");
      if (!el || !sec) return;
      const canFilter = ["owner", "super_admin", "admin"].includes(loggedRole);
      if (!canFilter) { sec.style.display = "none"; return; }
      sec.style.display = "block";
      el.innerHTML = "";

      function mkC(html, val, color, indent) {
        const c = document.createElement("div");
        c.className = "me-chip" + (meAccountFilts.has(val) ? " on" : "");
        if (color) c.style.cssText = "border-color:" + color + "44;color:" + color + (indent ? ";margin-left:6px" : "");
        c.innerHTML = html;
        c.setAttribute("data-val", val);
        c.title = "Click to filter · dbl-click to remove";
        c.onclick = function () { meAccountChip(c, val); };
        c.ondblclick = function (e) {
          e.stopPropagation();
          meAccountFilts.delete(val);
          if (!meAccountFilts.size) meAccountFilts.add("all");
          buildMeAccountChips(); updateMassPreview();
        };
        return c;
      }

      // All Keys chip
      const allC = mkC("🔑 All Keys", "all", null, false);
      allC.ondblclick = function () { meAccountFilts = new Set(["all"]); buildMeAccountChips(); updateMassPreview(); };
      el.appendChild(allC);

      if (loggedRole === "owner" || loggedRole === "super_admin") {
        // Own keys chip
        const ownK = keys.filter(function (k) { return k.owner === loggedUser || (!k.owner && loggedRole === "owner"); });
        if (ownK.length) {
          const ico = loggedRole === "owner" ? "⚡" : "★";
          const clr = loggedRole === "owner" ? "var(--ca)" : "var(--yellow)";
          el.appendChild(mkC(ico + " " + escHtml(loggedUser) +
            " <span style='font-size:8px;opacity:.5'>(" + ownK.length + ")</span>",
            "__self__", clr, false));
        }
        // Each admin (skip self)
        adminAccounts.forEach(function (adm) {
          if (adm.name === loggedUser) return; // already shown as __self__
          const admK = keys.filter(function (k) { return k.owner === adm.name; });
          if (!admK.length) return;
          el.appendChild(mkC("👑 " + escHtml(adm.name) +
            " <span style='font-size:8px;opacity:.5'>(" + admK.length + ")</span>",
            "admin:" + adm.name, "var(--ca)", false));
          // Sellers under this admin
          sellers.filter(function (sr) { return sr.adminOwner === adm.name; }).forEach(function (sr) {
            const srK = keys.filter(function (k) { return k.owner === sr.name; });
            if (!srK.length) return;
            el.appendChild(mkC("└ 👤 " + escHtml(sr.name) +
              " <span style='font-size:8px;opacity:.5'>(" + srK.length + ")</span>",
              "seller:" + sr.name, "var(--purple)", true));
          });
        });
        // Direct sellers (no adminOwner)
        sellers.filter(function (sr) { return !sr.adminOwner; }).forEach(function (sr) {
          const srK = keys.filter(function (k) { return k.owner === sr.name; });
          if (!srK.length) return;
          el.appendChild(mkC("👤 " + escHtml(sr.name) +
            " <span style='font-size:8px;opacity:.5'>(" + srK.length + ")</span>",
            "seller:" + sr.name, "var(--purple)", false));
        });
      } else {
        // Admin: own keys + sellers they created
        const ownK = keys.filter(function (k) { return k.owner === loggedUser; });
        if (ownK.length) {
          el.appendChild(mkC("👑 Me" +
            " <span style='font-size:8px;opacity:.5'>(" + ownK.length + ")</span>",
            "__self__", "var(--cyan)", false));
        }
        sellers.filter(function (sr) {
          return sr.adminOwner === loggedUser || sr.createdBy === loggedUser;
        }).forEach(function (sr) {
          const srK = keys.filter(function (k) { return k.owner === sr.name; });
          if (!srK.length) return;
          el.appendChild(mkC("└ 👤 " + escHtml(sr.name) +
            " <span style='font-size:8px;opacity:.5'>(" + srK.length + ")</span>",
            "seller:" + sr.name, "var(--purple)", true));
        });
      }

      updateMeAccountPreview();
      _updateMeAccountState(); // apply dim/bright states
    }

    function meAccountChip(el, val) {
      if (val === "all") {
        meAccountFilts = new Set(["all"]);
        document.querySelectorAll("#meAccountChips .me-chip").forEach(function (c, i) { c.classList.toggle("on", i === 0); });
      } else {
        meAccountFilts.delete("all");
        document.querySelectorAll("#meAccountChips .me-chip").forEach(function (c, i) { if (i === 0) c.classList.remove("on"); });
        if (meAccountFilts.has(val)) { meAccountFilts.delete(val); if (el) el.classList.remove("on"); if (!meAccountFilts.size) { meAccountFilts.add("all"); document.querySelectorAll("#meAccountChips .me-chip").forEach(function (c, i) { c.classList.toggle("on", i === 0); }); } }
        else { meAccountFilts.add(val); if (el) el.classList.add("on"); }
      }
      updateMassPreview();
      updateMeAccountPreview();
      _updateMeAccountState();
    }
    function updateMeAccountPreview() {
      const el = document.getElementById("meAccountPreview"); if (!el) return;
      if (meAccountFilts.has("all")) { el.textContent = ""; return; }
      const parts = [...meAccountFilts].map(function (v) {
        if (v.startsWith("admin:")) { const n = v.slice(6); const k = keys.filter(function (x) { return x.owner === n; }).length; return "👑 " + n + " (" + k + " keys)"; }
        if (v.startsWith("seller:")) { const n = v.slice(7); const k = keys.filter(function (x) { return x.owner === n; }).length; return "👤 " + n + " (" + k + " keys)"; }
        return v;
      });
      el.textContent = "Selected: " + parts.join(", ");
    }


    /* ══ FLICKER-FREE AUTO REFRESH ══ */
    let _arTimer = null, _arActive = true, _lastDataVer = 0;

    function startAutoRefresh() {
      stopAutoRefresh();
      _arTimer = setInterval(silentRefresh, 5000); // 5s less aggressive
    }
    function stopAutoRefresh() {
      if (_arTimer) { clearInterval(_arTimer); _arTimer = null; }
    }
    // Pause auto-refresh when modal is open
    const _origClsModal = closeModal;
    closeModal = function (id) {
      _origClsModal(id);
      // Resume if no modals open
      setTimeout(function () {
        const open = document.querySelector(".overlay.open");
        if (!open) startAutoRefresh();
      }, 200);
    };

    function silentRefresh() {
      if (!loggedUser) return;
      if (document.querySelector(".overlay.open")) return; // pause when modal open
      if (document.hidden) return; // pause when tab not visible
      if (document.activeElement && document.activeElement.tagName === "INPUT") return; // pause when user typing
      // Fast version check first (avoids expensive JSON.stringify on large data)
      const newVer = secLoad("lnDataVer", 0);
      if (_lastDataVer === newVer) return; // No changes
      _lastDataVer = newVer;
      const newKeys = secLoad("lnKeysV8", []);
      const newSellers = secLoad("lnSellers", []);
      const newAdmins = secLoad("dxAdminAccts", []);
      keys = newKeys; sellers = newSellers; adminAccounts = newAdmins;
      // Rebuild dynamic filters silently
      if (currentPage === "keys") { buildCreatorFilterRow(); }
      // Only update stats numbers, not full re-render (avoids flicker)
      _silentUpdateStats();
      // Re-render current page silently
      if (currentPage === "dashboard") _silentDashboard();
      else if (currentPage === "keys") _silentKeys();
      else if (currentPage === "sellers") _silentSellers();
      else if (currentPage === "owners_admins") renderOwnerAdminsList();
    }

    function _silentUpdateStats() {
      // Update badge numbers only
      const vk = loggedRole === "seller" ? keys.filter(function (k) { return !k.owner || k.owner === loggedUser; }) : keys;
      const tot = vk.length;
      const active = vk.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = vk.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      function sv(id, v) { const e = document.getElementById(id); if (e && e.textContent !== String(v)) e.textContent = v; }
      sv("nbAll", tot); sv("nbAll2", tot);
      // Update tab counts
      sv("ktabCntAll", vk.length);
      sv("ktabCntAdm", vk.filter(function (k) { return k.type === "admin"; }).length);
      sv("ktabCntCst", vk.filter(function (k) { return k.type === "customer"; }).length);
      sv("ktabCntTrl", vk.filter(function (k) { return k.type === "trial"; }).length);
    }

    function _silentDashboard() {
      updateStats();
      _buildDashHeader();
      renderHierarchyDash();
      const vk = loggedRole === "seller" ? keys.filter(function (k) { return !k.owner || k.owner === loggedUser; }) : keys;
      const cards = document.querySelectorAll(".sc-val");
      const tot = vk.length, active = vk.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = vk.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const revoked = vk.filter(function (k) { return getRealStatus(k) === "revoked"; }).length;
      const rev = vk.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      // Cards are rebuilt by updateStats already — just avoid chart flicker
    }

    function _silentKeys() {
      // Re-render cards only if needed (debounced)
      if (!document.querySelector(".key-card:hover")) renderCards();
    }
    function _silentSellers() {
      if (currentPage === "sellers") renderSellersList();
    }


    /* ══ COLLAPSIBLE ADMIN CARDS ══ */
    const _collapsedAdmins = new Set(); // set of admin names that are collapsed
    function toggleAdminCollapse(admName) {
      if (_collapsedAdmins.has(admName)) _collapsedAdmins.delete(admName);
      else _collapsedAdmins.add(admName);
      renderOwnerAdminsList();
    }


    const _dashCollapsed = new Set();
    function toggleDashAdminCollapse(n) { if (_dashCollapsed.has(n)) _dashCollapsed.delete(n); else _dashCollapsed.add(n); renderHierarchyDash(); }


    /* ══ CREATOR FILTER (Key Manager) ══ */
    let creatorFilts = new Set(["all"]);

    function buildCreatorFilterRow() {
      /* BY section removed — creator filter disabled */
      const pipe = document.getElementById("unifiedPipe");
      const byLbl = document.getElementById("unifiedByLbl");
      const section = document.getElementById("creatorFilterRow");
      const chips = document.getElementById("creatorChips");
      if (pipe) pipe.style.display = "none";
      if (byLbl) byLbl.style.display = "none";
      if (section) section.style.display = "none";
      if (chips) chips.style.display = "none";
    }





    function saveCustomPrefix() {
      const v = (document.getElementById("inCustomPfx") || {}).value || "";
      if (!v.trim()) { toast("Enter a prefix first", "w"); return; }
      const pfx = v.trim().toUpperCase().slice(0, 8);
      // Save to admin account or seller profile
      if (loggedRole === "owner") {
        secSave("lnOwnerPrefix_" + loggedUser, pfx);
        toast("Prefix '" + pfx + "' saved for " + loggedUser, "s");
      } else if (loggedRole === "admin" || loggedRole === "super_admin") {
        const adm = adminAccounts.find(function (a) { return a.name === loggedUser; });
        if (adm) { adm.prefix = pfx; saveAdminAccts(); }
        toast("Prefix '" + pfx + "' saved for " + loggedUser, "s");
      } else if (loggedRole === "seller") {
        const sr = sellers.find(function (x) { return x.name === loggedUser; });
        if (sr) { sr.prefix = pfx; saveSellers(); }
        toast("Prefix '" + pfx + "' saved", "s");
      }
      const badge = document.getElementById("savedPfxBadge");
      if (badge) { badge.style.display = "flex"; badge.textContent = "✓ Saved: " + pfx; }
      addLog("💾", "Saved prefix: " + pfx, "", "action");
    }


    /* ══ CREDENTIALS VIEWER (Owner/Super Admin only) ══ */
    function showAdminCreds(idx) {
      if (loggedRole !== "owner" && loggedRole !== "super_admin") { toast("Access denied", "e"); return; }
      const adm = adminAccounts[idx]; if (!adm) return;
      const pw = _decodePw(adm.pass);
      const myS = sellers.filter(function (sr) { return sr.adminOwner === adm.name; });
      let html = '<div style="font-family:JetBrains Mono,monospace;font-size:12px">';
      html += '<div style="margin-bottom:10px;padding:10px;background:rgba(0,200,255,.05);border:1px solid rgba(0,200,255,.15);border-radius:var(--rs)">';
      html += '<div style="font-size:9px;color:var(--t3);text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px">Admin Account</div>';
      html += '<div style="display:flex;justify-content:space-between;margin-bottom:4px"><span style="color:var(--t3)">Username:</span><span style="color:var(--cyan);font-weight:700">' + escHtml(adm.name) + '</span></div>';
      html += '<div style="display:flex;justify-content:space-between"><span style="color:var(--t3)">Password:</span><span style="color:var(--green);font-weight:700">' + pw + '</span></div>';
      html += '</div>';
      if (myS.length) {
        html += '<div style="font-size:9px;color:var(--t3);text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px">Sellers (' + myS.length + ')</div>';
        myS.forEach(function (sr) {
          const srPw = _decodePw(sr.pass);
          html += '<div style="margin-bottom:6px;padding:8px;background:rgba(136,51,255,.05);border:1px solid rgba(136,51,255,.15);border-radius:var(--rs)">';
          html += '<div style="display:flex;justify-content:space-between;margin-bottom:3px"><span style="color:var(--t3)">Username:</span><span style="color:#bb77ff;font-weight:700">' + escHtml(sr.name) + '</span></div>';
          html += '<div style="display:flex;justify-content:space-between"><span style="color:var(--t3)">Password:</span><span style="color:var(--green);font-weight:700">' + srPw + '</span></div>';
          html += '</div>';
        });
      }
      html += '</div>';
      confirm2("🔐 Credentials: " + adm.name, html, "👁", function () { });
      addLog("👁", "Viewed credentials: " + adm.name, "", "auth");
    }
    function showSellerCreds(idx) {
      if (loggedRole !== "owner" && loggedRole !== "super_admin") { toast("Access denied", "e"); return; }
      const sr = sellers[idx]; if (!sr) return;
      const pw = _decodePw(sr.pass);
      const html = '<div style="font-family:JetBrains Mono,monospace;font-size:12px;padding:10px;background:rgba(136,51,255,.05);border:1px solid rgba(136,51,255,.15);border-radius:var(--rs)">' +
        '<div style="display:flex;justify-content:space-between;margin-bottom:6px"><span style="color:var(--t3)">Username:</span><span style="color:#bb77ff;font-weight:700">' + escHtml(sr.name) + '</span></div>' +
        '<div style="display:flex;justify-content:space-between"><span style="color:var(--t3)">Password:</span><span style="color:var(--green);font-weight:700">' + pw + '</span></div>' +
        (sr.adminOwner ? '<div style="margin-top:6px;display:flex;justify-content:space-between"><span style="color:var(--t3)">Admin Owner:</span><span style="color:var(--ca);font-weight:700">' + sr.adminOwner + '</span></div>' : '') +
        '</div>';
      confirm2("🔐 Credentials: " + sr.name, html, "👁", function () { });
      addLog("👁", "Viewed seller credentials: " + sr.name, "", "auth");
    }


    /* ══ CUSTOM DURATION TEMPLATES ══ */
    // Loaded from storage; owner/super_admin can edit
    let customPresets = secLoad("lnCustomPresets", null);
    (function () {
      const OLD_KEYS_SET = new Set(["1h", "14d", "60d", "90d"]);
      const NEW_DEFAULTS = {
        admin: [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }, { k: "7d", l: "7 Days" }, { k: "30d", l: "30 Days" }, { k: "lifetime", l: "∞ Lifetime" }],
        customer: [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }, { k: "7d", l: "7 Days" }, { k: "30d", l: "30 Days" }],
        trial: [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }]
      };
      if (!customPresets) { return; } // no saved presets, use new defaults
      // Check if any type has old keys — if so, reset that type to new defaults
      var needsMigration = false;
      ["admin", "customer", "trial"].forEach(function (tp) {
        var arr = customPresets[tp] || [];
        var hasOld = arr.some(function (p) { return OLD_KEYS_SET.has(p.k); });
        if (hasOld) {
          PRESET_DURS[tp] = NEW_DEFAULTS[tp]; // reset to new defaults
          needsMigration = true;
        } else if (arr.length > 0) {
          PRESET_DURS[tp] = arr; // use custom if no old keys
        }
      });
      if (needsMigration) {
        secSave("lnCustomPresets", null); // clear stale storage
        customPresets = null;

      }
    })();
    function saveCustomPresets() { secSave("lnCustomPresets", { admin: PRESET_DURS.admin, customer: PRESET_DURS.customer, trial: PRESET_DURS.trial }); }

    function openCustomPresetsModal() {
      if (loggedRole !== "owner" && loggedRole !== "super_admin") { toast("Access denied", "e"); return; }
      openPricingModal();
      setTimeout(function () { switchPDTab("templates", document.getElementById("pdTabTemplates")); }, 80);
    }

    function addPresetRow(tp) {
      const durs = PRESET_DURS[tp];
      durs.push({ k: "", l: "" });
      renderCustomPresetsForm();
      // Focus new input
      const idx = durs.length - 1;
      setTimeout(function () { const el = document.getElementById("pk_" + tp + "_" + idx); if (el) el.focus(); }, 50);
    }
    function removePresetRow(tp, idx) {
      PRESET_DURS[tp].splice(idx, 1);
      renderCustomPresetsForm();
    }
    function saveCustomPresetsFull() {
      // Read all form values back into PRESET_DURS
      ["admin", "customer", "trial"].forEach(function (tp) {
        const rows = [];
        const container = document.getElementById("presetRows_" + tp); if (!container) return;
        // Collect all pk_ inputs for this type
        let i = 0;
        while (true) {
          const kEl = document.getElementById("pk_" + tp + "_" + i);
          const lEl = document.getElementById("pl_" + tp + "_" + i);
          if (!kEl) break;
          if (kEl.value.trim()) rows.push({ k: kEl.value.trim(), l: lEl && lEl.value.trim() ? lEl.value.trim() : kEl.value.trim() });
          i++;
        }
        PRESET_DURS[tp] = rows;
      });
      saveCustomPresets();
      pricing = secLoad("lnPricingV1", {});
      closeModal("pricingModal");
      // Rebuild presets in gen modal if open
      buildDurPresets();
      addLog("⚙", "Saved duration templates", "", "settings");
      toast("Duration templates saved", "s");
    }


    function resetPresetsToDefault() {
      PRESET_DURS.admin = [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }, { k: "7d", l: "7 Days" }, { k: "30d", l: "30 Days" }, { k: "lifetime", l: "∞ Lifetime" }];
      PRESET_DURS.customer = [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }, { k: "7d", l: "7 Days" }, { k: "30d", l: "30 Days" }];
      PRESET_DURS.trial = [{ k: "4h", l: "4 Hours" }, { k: "1d", l: "1 Day" }, { k: "3d", l: "3 Days" }];
      secSave("lnCustomPresets", null);
      renderCustomPresetsForm();
      buildDurPresets();
      toast("Presets reset to default", "s");
    }

    function renderCustomPresetsForm() {
      const f = document.getElementById("customPresetsForm"); if (!f) return;
      const types = ["admin", "customer", "trial"];
      const typeClr = { admin: "var(--ca)", customer: "var(--cyan)", trial: "var(--ct)" };
      const typeIco = { admin: "👑", customer: "🔒", trial: "⏱" };
      f.innerHTML = "";
      types.forEach(function (tp) {
        const durs = PRESET_DURS[tp] || [];
        const sec = document.createElement("div");
        sec.style.cssText = "margin-bottom:16px;border:1px solid var(--b);border-radius:var(--rs);overflow:hidden";
        const hdr = document.createElement("div");
        hdr.style.cssText = "padding:9px 12px;background:rgba(255,255,255,.02);display:flex;align-items:center;justify-content:space-between";
        hdr.innerHTML = '<span style="font-size:11px;font-weight:700;color:' + typeClr[tp] + '">' + typeIco[tp] + ' ' + tp.toUpperCase() + '</span>';
        const addBtn = document.createElement("button");
        addBtn.className = "btn btn-ghost btn-xs"; addBtn.style.cssText = "font-size:10px";
        addBtn.textContent = "＋ Add"; addBtn.setAttribute("data-tp", tp);
        addBtn.onclick = function () { addPresetRow(this.getAttribute("data-tp")); };
        hdr.appendChild(addBtn); sec.appendChild(hdr);
        const rowsDiv = document.createElement("div"); rowsDiv.style.cssText = "padding:8px 12px"; rowsDiv.id = "presetRows_" + tp;
        durs.forEach(function (p, i) {
          const row = document.createElement("div");
          row.style.cssText = "display:flex;gap:6px;align-items:center;margin-bottom:6px";
          row.innerHTML =
            '<input class="fi" style="flex:1;padding:6px 9px;font-size:11px;font-family:JetBrains Mono,monospace" placeholder="Key e.g. 1h,3d,7d" value="' + p.k + '" id="pk_' + tp + '_' + i + '">' +
            '<input class="fi" style="flex:1;padding:6px 9px;font-size:11px" placeholder="Label e.g. 1 Hour, 3 Days" value="' + p.l + '" id="pl_' + tp + '_' + i + '">';
          const delBtn = document.createElement("button");
          delBtn.className = "btn btn-danger btn-xs"; delBtn.style.cssText = "padding:5px 8px;flex-shrink:0";
          delBtn.textContent = "✕"; delBtn.setAttribute("data-tp", tp); delBtn.setAttribute("data-i", String(i));
          delBtn.onclick = function () { removePresetRow(this.getAttribute("data-tp"), parseInt(this.getAttribute("data-i"))); };
          row.appendChild(delBtn); rowsDiv.appendChild(row);
        });
        sec.appendChild(rowsDiv); f.appendChild(sec);
      });
    }


    function switchPDTab(tab, el) {
      document.querySelectorAll(".pdtab").forEach(function (b) { b.classList.remove("on"); });
      if (el) el.classList.add("on");
      document.getElementById("pdSectionPricing").style.display = tab === "pricing" ? "" : "none";
      document.getElementById("pdSectionTemplates").style.display = tab === "templates" ? "" : "none";
      document.getElementById("pdFootPricing").style.display = tab === "pricing" ? "flex" : "none";
      document.getElementById("pdFootTemplates").style.display = tab === "templates" ? "flex" : "none";
      if (tab === "templates") renderCustomPresetsForm();
    }


    /* ══ SECURITY: PASSWORD HASHING ══ */
    async function _hashPw(plain) {
      try {
        if (window.crypto && window.crypto.subtle) {
          const enc = new TextEncoder().encode(plain + "_LN_SALT_v1");
          const buf = await window.crypto.subtle.digest("SHA-256", enc);
          return "h1$" + Array.from(new Uint8Array(buf)).map(function (b) { return b.toString(16).padStart(2, "0"); }).join("");
        }
      } catch (e) { }
      return "b1$" + btoa(plain); // fallback
    }

    async function _verifyPw(plain, stored) {
      if (!stored) return false;
      // New format: h1$<sha256>
      if (stored.startsWith("h1$")) { const h = await _hashPw(plain); return h === stored; }
      // New base64 format: b1$<base64>
      if (stored.startsWith("b1$")) return stored === "b1$" + btoa(plain);
      // Legacy: raw base64 (old btoa storage)
      try { return atob(stored) === plain; } catch (e) { return false; }
    }

    /* ══ SECURITY: RATE LIMITING ══ */
    const _loginAttempts = {}; // {username: {count, until}}
    function _canAttemptLogin(u) {
      const e = _loginAttempts[u];
      if (!e) return { ok: true };
      if (e.until && Date.now() < e.until) {
        const sec = Math.ceil((e.until - Date.now()) / 1000);
        return { ok: false, wait: sec };
      }
      if (e.until && Date.now() >= e.until) { delete _loginAttempts[u]; return { ok: true }; }
      return { ok: true };
    }
    function _recordFailedLogin(u) {
      if (!_loginAttempts[u]) _loginAttempts[u] = { count: 0 };
      _loginAttempts[u].count++;
      if (_loginAttempts[u].count >= 5) {
        _loginAttempts[u].until = Date.now() + 15 * 60 * 1000; // 15min lockout
        addLog("🔒", "Account locked: " + u + " — too many failed attempts", "", "auth");
      }
    }
    function _clearLoginAttempts(u) { delete _loginAttempts[u]; }



    /* ══ BACKUP & RESTORE ══ */
    /* ══ AUTO-CLEANUP OLD KEYS ══ */
    function autoCleanExpiredKeys(daysOld) {
      daysOld = daysOld || 90;
      const cutoff = Date.now() - daysOld * 86400000;
      const before = keys.length;
      keys = keys.filter(function (k) {
        // Keep active, lifetime, or recent
        if (!k.expiresAt) return true;
        if (getRealStatus(k) === "active") return true;
        return k.expiresAt > cutoff; // keep if expired less than X days ago
      });
      const removed = before - keys.length;
      if (removed > 0) { save(); updateStats(); renderCards(); addLog("🧹", "Auto-cleaned " + removed + " old expired keys", "", "action"); toast(removed + " old keys cleaned", "s"); }
      return removed;
    }


    /* ── EXPIRY BADGE ── */
    function updateExpireBadge() {
      const el = document.getElementById("expireBadge"); if (!el) return;
      const h24 = Date.now() + 24 * 3600000;
      const expiring = keys.filter(function (k) {
        if (!loggedUser) return false;
        if (!_canSeeUser(k.owner)) return false; // PYRAMID: only visible keys
        const rs = getRealStatus(k);
        if (rs !== "active") return false;
        if (!k.expiresAt) return false; // lifetime
        return k.expiresAt <= h24 && k.expiresAt > Date.now();
      }).length;
      if (expiring > 0) {
        el.style.display = "flex";
        el.textContent = expiring > 99 ? "99+" : String(expiring);
        el.title = expiring + " key" + (expiring > 1 ? "s" : "") + " expiring in 24h";
      } else {
        el.style.display = "none";
      }
      // Sync to bottom nav badge
      const bEl = document.getElementById("bnavExpireBadge");
      if (bEl) { bEl.style.display = el.style.display; bEl.textContent = el.textContent || ""; }
    }


    /* ── QR CODE ── */
    let _qrInstance = null, _qrKey = "";
    function openQR(keyStr) {
      _qrKey = keyStr;
      const lbl = document.getElementById("qrKeyLabel");
      if (lbl) lbl.textContent = keyStr;
      const div = document.getElementById("qrDiv");
      if (!div) return;
      div.innerHTML = "";
      try {
        if (typeof QRCode === "undefined") {
          div.innerHTML = '<div style="padding:20px;color:var(--t3);font-size:12px">QR library loading...<br>Please try again.</div>';
        } else {
          _qrInstance = new QRCode(div, {
            text: keyStr, width: 220, height: 220,
            colorDark: "#000000", colorLight: "#ffffff",
            correctLevel: QRCode.CorrectLevel.M
          });
        }
      } catch (e) { div.innerHTML = '<div style="color:var(--red);padding:10px;font-size:11px">QR Error: ' + e.message + '</div>'; }
      document.getElementById("qrModal").classList.add("open");
    }
    function downloadQR() {
      const div = document.getElementById("qrDiv");
      if (!div) return;
      const canvas = div.querySelector("canvas");
      const img = div.querySelector("img");
      if (canvas) {
        const a = document.createElement("a");
        a.href = canvas.toDataURL("image/png");
        a.download = "key_" + (_qrKey || "key").replace(/[^A-Z0-9]/gi, "_") + ".png";
        a.click();
      } else if (img) {
        const a = document.createElement("a");
        a.href = img.src; a.download = "key_qr.png"; a.click();
      }
    }


    /* ── SEARCH HIGHLIGHT ── */

    function escHtml(t) { return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
    function escJsAttr(t) { return String(t).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/"/g, '&quot;'); }


    /* ── PAGE SIZE CONTROL ── */
    let pgSize = parseInt(sessionStorage.getItem("lnPgSize") || "20") || 20;
    function setPgSize(n) {
      pgSize = n;
      sessionStorage.setItem("lnPgSize", String(n));
      document.querySelectorAll("[id^='pgBtn']").forEach(function (b) { b.classList.remove("on"); });
      const active = document.getElementById("pgBtn" + n); if (active) active.classList.add("on");
      pgPage = 1; renderCards(); updateTabCounts();
    }
    function initPgSizeBtns() {
      document.querySelectorAll("[id^='pgBtn']").forEach(function (b) { b.classList.remove("on"); });
      const active = document.getElementById("pgBtn" + pgSize); if (active) active.classList.add("on");
    }


    /* ── WEBHOOK NOTIFICATIONS ── */
    let whCfg = secLoad("lnWebhook", { discord: "", tgToken: "", tgChat: "", evtGen: true, evtDel: true, evtExp: false, evtLogin: false, evtMass: false });
    /* ══ LOGIN HISTORY ══ */
    let loginHistory = secLoad("lnLoginHist", []);
    const MAX_LOGIN_HIST = 50;
    function _recordLogin(username, role) {
      const dev = _getDeviceInfo();
      const entry = {
        user: username, role,
        ts: Date.now(),
        ua: dev.icon,
        device: dev.summary,
        os: dev.os, osVer: dev.osVer,
        browser: dev.browser, browserVer: dev.browserVer,
        deviceType: dev.device,
        uaFull: navigator.userAgent ? navigator.userAgent.substring(0, 120) : "unknown",
        ip: "", ipCountry: "", ipCity: ""
      };
      loginHistory.unshift(entry);
      if (loginHistory.length > MAX_LOGIN_HIST) loginHistory = loginHistory.slice(0, MAX_LOGIN_HIST);
      secSave("lnLoginHist", loginHistory);
      // Initial log (device info immediately, IP follows async)
      addLog("\ud83d\udd11", "Login: " + username + " (" + role + ")", "", "auth", { note: dev.summary, device: dev.icon });
      // Capture IP asynchronously for ALL roles
      _fetchIPInfo().then(function (info) {
        if (info && info.ip) {
          entry.ip = info.ip; entry.ipCountry = info.country || ""; entry.ipCity = info.city || ""; entry.ipOrg = info.org || "";
          secSave("lnLoginHist", loginHistory);
          const loc = [info.city, info.country].filter(Boolean).join(", ");
          addLog("\ud83c\udf10", "IP: " + info.ip + (loc ? " (" + loc + ")" : ""), "", "auth", { note: "User: " + username + " \u00b7 " + dev.summary, before: "", after: info.ip });
          // Notify webhook for non-sellers with full detail
          if (role !== "seller" && typeof notifyWebhook === "function") {
            notifyWebhook("\ud83c\udf10 **" + username + "** (" + role + ") logged in\nIP: " + info.ip + (loc ? " \u00b7 " + loc : "") + "\nDevice: " + dev.summary, "login");
          }
          // login history now in activity log — auto-rendered via addLog
          // Check for suspicious login (new IP/country/device)
          _checkSuspiciousLogin(username, role, info, dev);
        } else {
          // IP could not be fetched (offline or blocked) — still log the attempt
          entry.ip = "(unavailable)";
          secSave("lnLoginHist", loginHistory);
          addLog("\ud83c\udf10", "IP unavailable for " + username, "", "auth", { note: "Network blocked or offline \u00b7 " + dev.summary });
        }
      }).catch(function () {
        entry.ip = "(error)";
        addLog("\ud83c\udf10", "IP fetch failed for " + username, "", "auth", { note: dev.summary });
      });
    }
    function openLoginHistModal() {
      // Login history is now merged into Activity Log — switch to it + filter Auth
      if (typeof switchPage === "function") switchPage("log");
      const fs = document.getElementById("logFiltSel");
      if (fs) { fs.value = "auth"; if (typeof renderLog === "function") renderLog(); }
    }

    function clearLoginHist() { loginHistory = []; secSave("lnLoginHist", []); toast("Login history cleared", "s"); closeModal("loginHistModal"); }

    /* ══ HAPTIC FEEDBACK ══ */
    function haptic(pattern) {
      try { if (navigator.vibrate) navigator.vibrate(pattern); }
      catch (e) { }
    }


    /* ══ BOTTOM NAV ══ */
    function updateBottomNav(page) {
      document.querySelectorAll(".bnav-item").forEach(function (b) { b.classList.remove("active"); });
      const active = document.getElementById("bnav-" + page);
      if (active) active.classList.add("active");
      // Sync badges
      const expB = document.getElementById("bnavExpireBadge");
      const mainExpB = document.getElementById("expireBadge");
      if (expB && mainExpB) { expB.style.display = mainExpB.style.display; expB.textContent = mainExpB.textContent; }
      const logB = document.getElementById("bnavLogBadge");
      const mainLogB = document.getElementById("logBadge");
      if (logB && mainLogB) { logB.style.display = mainLogB.style.display; logB.textContent = mainLogB.textContent; }
    }


    /* ══ PULL-TO-REFRESH ══ */
    let _ptrStartY = 0, _ptrActive = false, _ptrThreshold = 72;
    function _initPTR() {
      const mc = document.querySelector(".main");
      if (!mc || !('ontouchstart' in window)) return;
      mc.addEventListener("touchstart", function (e) {
        if (mc.scrollTop === 0) _ptrStartY = e.changedTouches[0].clientY;
        else _ptrStartY = -1;
      }, { passive: true });
      mc.addEventListener("touchmove", function (e) {
        if (_ptrStartY < 0) return;
        const dy = e.changedTouches[0].clientY - _ptrStartY;
        if (dy > 10 && dy < 150) {
          const ptr = document.getElementById("ptrIndicator");
          const txt = document.getElementById("ptrText");
          if (ptr) {
            ptr.classList.add("visible");
            ptr.style.opacity = Math.min(1, dy / 50);
            if (txt) txt.textContent = dy > _ptrThreshold ? "Release to refresh" : "Pull to refresh";
            if (dy > _ptrThreshold && !_ptrActive) haptic(10);
            _ptrActive = dy > _ptrThreshold;
          }
        }
      }, { passive: true });
      mc.addEventListener("touchend", function (e) {
        const ptr = document.getElementById("ptrIndicator");
        if (ptr) { ptr.classList.remove("visible"); ptr.style.opacity = "0"; }
        if (_ptrActive) {
          haptic([30, 20, 30]);
          refreshPage();
          toast("Refreshed ✓", "i");
        }
        _ptrStartY = -1; _ptrActive = false;
      }, { passive: true });
    }


    /* ══ SWIPE ACTIONS ON KEY CARDS ══ */
    function _initCardSwipe() {
      if (!('ontouchstart' in window)) return;
      document.addEventListener("touchstart", function (e) {
        const card = e.target.closest(".key-card");
        if (!card) return;
        card._swipeStartX = e.changedTouches[0].clientX;
        card._swipeStartY = e.changedTouches[0].clientY;
        card._swipeDelta = 0;
      }, { passive: true });
      document.addEventListener("touchmove", function (e) {
        const card = e.target.closest(".key-card");
        if (!card || card._swipeStartX === undefined) return;
        const dx = e.changedTouches[0].clientX - card._swipeStartX;
        const dy = e.changedTouches[0].clientY - card._swipeStartY;
        if (Math.abs(dy) > Math.abs(dx)) return; // vertical scroll
        card._swipeDelta = dx;
        // Visual feedback
        card.classList.toggle("swiping-left", dx < -30);
        card.classList.toggle("swiping-right", dx > 30);
        if (Math.abs(dx) > 60 && Math.abs(dx) < 65) haptic(15); // threshold haptic
      }, { passive: true });
      document.addEventListener("touchend", function (e) {
        const card = e.target.closest(".key-card");
        if (!card || card._swipeDelta === undefined) return;
        const dx = card._swipeDelta;
        card.classList.remove("swiping-left", "swiping-right");
        const idAttr = card.getAttribute("onclick") || card.querySelector("[onclick]") ? card.id : "";
        const idMatch = card.getAttribute("data-kid");
        if (idMatch) {
          const kid = parseInt(idMatch);
          if (dx < -80) {
            // Swipe left → delete
            haptic([30, 15, 30]);
            deleteKey(kid);
          } else if (dx > 80) {
            // Swipe right → open detail
            haptic(20);
            openDetail(kid);
          }
        }
        card._swipeDelta = 0;
      }, { passive: true });
    }


    /* ── KEY DETAIL PREVIEW ── */
    function updateKeyDetailPreview() {
      const now = Date.now();
      const totalMs = getTotalMs();
      const isLife = (totalMs === null);
      const dl = getDurLabel();
      const cost = getTokenCost();
      const qty = Math.max(1, parseInt((document.getElementById("inQty") || { value: "1" }).value) || 1);
      const totalCost = cost * qty;
      // Dates
      const createdDate = new Date(now);
      const createdStr = createdDate.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" });
      let expiresStr = "—";
      let expiresClr = "var(--t1)";
      if (isLife) { expiresStr = "∞ Lifetime"; expiresClr = "var(--purple)"; }
      else if (totalMs) {
        const expDate = new Date(now + totalMs);
        expiresStr = expDate.toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" })
          + " " + expDate.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
        // Colour by urgency
        if (totalMs < 86400000) expiresClr = "var(--red)";
        else if (totalMs < 604800000) expiresClr = "var(--orange)";
        else expiresClr = "var(--green)";
      }
      // Balance (seller only — owner/admin/super_admin tidak punya konsep saldo)
      const bal = loggedRole === "seller" ? getSellerBalance() : -1;
      const balAfterStr = fmtMoney(bal - totalCost);
      const balAfterClr = bal - totalCost < 0 ? "var(--red)" : "var(--cyan)";
      { const _balRow = document.getElementById("kdpBalAfterRow"); if (_balRow) _balRow.style.display = (loggedRole === "seller") ? "" : "none"; }
      {
        const _hidePriceRows = loggedRole === "owner" || loggedRole === "super_admin";
        const _costRow = document.getElementById("kdpCostRow"); if (_costRow) _costRow.style.display = _hidePriceRows ? "none" : "";
        const _totalRow = document.getElementById("kdpTotalRow"); if (_totalRow) _totalRow.style.display = _hidePriceRows ? "none" : "";
      }
      // Type chip
      const typeClr = { admin: "var(--ca)", customer: "var(--cyan)", trial: "var(--ct)" }[selTypeV] || "var(--t2)";
      const typeIco = { admin: "👑 ADMIN", customer: "🔒 CUSTOMER", trial: "⏱ TRIAL" }[selTypeV] || selTypeV.toUpperCase();
      // Apply to DOM
      function _sv(id, val, clr) { const el = document.getElementById(id); if (!el) return; el.textContent = val; if (clr) el.style.color = clr; }
      _sv("kdpCost", cost > 0 ? fmtMoney(cost) : "Free", cost > 0 ? "var(--yellow)" : "var(--green)");
      _sv("kdpTotal", totalCost > 0 ? fmtMoney(totalCost) + (qty > 1 ? " (×" + qty + ")" : "") : "Free", totalCost > 0 ? "var(--yellow)" : "var(--green)");
      _sv("kdpCreated", createdStr, "var(--t2)");
      _sv("kdpExpires", expiresStr, expiresClr);
      _sv("kdpDuration", (dl && dl !== "-" && dl !== "0s") ? dl : "— not set", dl && dl !== "-" && dl !== "0s" ? "var(--cyan)" : "var(--t3)");
      _sv("kdpBalAfter", balAfterStr, balAfterClr);
      // Type chip
      const chip = document.getElementById("kdpTypeChip");
      if (chip) { chip.textContent = typeIco; chip.style.background = typeClr + "22"; chip.style.color = typeClr; chip.style.borderColor = typeClr + "44"; }
      // Deduct note
      const note = document.getElementById("kdpDeductNote");
      if (note) {
        if (totalCost > 0 && bal !== -1) {
          note.style.display = "block";
          note.textContent = "⚠ " + (bal - totalCost < 0 ? "Insufficient balance! Need " : "") + fmtMoney(Math.abs(bal - totalCost)) + (bal - totalCost < 0 ? " more" : "") + " will be deducted";
          note.style.background = bal - totalCost < 0 ? "rgba(255,60,60,.07)" : "rgba(255,215,0,.05)";
          note.style.borderTopColor = bal - totalCost < 0 ? "rgba(255,60,60,.2)" : "rgba(255,215,0,.15)";
          note.style.color = bal - totalCost < 0 ? "var(--red)" : "var(--t3)";
        } else note.style.display = "none";
      }
      // pricePreviewVal/priceTokenDeduct/priceBalAfter removed from modal - no sync needed
    }


    // Close sidebar when overlay area (right side) is tapped on mobile
    document.addEventListener("click", function (e) {
      if (window.innerWidth >= 1024) return;
      const sb = document.getElementById("sidebar");
      if (!sb) return;
      if (sb.classList.contains("mobile-open") && !sb.contains(e.target)) {
        sb.classList.remove("mobile-open");
        document.body.classList.remove("mobile-open");
      }
    });


    /* ── SORT DROPDOWN ── */
    function toggleSortDrop() {
      const m = document.getElementById("sortDropMenu");
      if (!m) return;
      m.style.display = m.style.display === "none" ? "block" : "none";
      // Close on outside click
      if (m.style.display === "block") {
        setTimeout(function () {
          document.addEventListener("click", function closeDrop(e) {
            if (!m.contains(e.target) && e.target.id !== "sortDropBtn") { m.style.display = "none"; }
            document.removeEventListener("click", closeDrop);
          });
        }, 0);
      }
    }


    /* ══ ACCESS CONTROL: who can see what ══
     *  Owner      → sees ALL (keys + logs from everyone)
     *  Super_admin→ sees own keys + keys of sellers under them
     *  Admin      → sees own keys + keys of sellers THEY created
     *  Seller     → sees only their OWN keys + logs
     */
    function getMyVisibleUsers() {
      // Returns a Set of usernames whose data I can see
      // null = see EVERYONE (owner)
      if (loggedRole === "owner") return null; // null = all
      const mine = new Set([loggedUser]);
      if (loggedRole === "admin" || loggedRole === "super_admin") {
        // Add sellers this admin created
        sellers.forEach(function (sr) {
          if (sr.adminOwner === loggedUser || sr.createdBy === loggedUser) {
            mine.add(sr.name);
          }
        });
      }
      // seller: only themselves
      return mine;
    }
    function _canSeeUser(targetUser) {
      if (loggedRole === "owner") return true;
      const mine = getMyVisibleUsers();
      if (!mine) return true;
      if (!targetUser) return loggedRole !== "seller"; // no-owner key: visible to admin+
      return mine.has(targetUser);
    }


    /* ══ SELLER DASHBOARD ══ */
    function _buildSellerDash(el) {
      const myK = keys.filter(function (k) { return k.owner === loggedUser; });
      const active = myK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = myK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const h24 = Date.now() + 86400000;
      const expiring = myK.filter(function (k) {
        return getRealStatus(k) === "active" && k.expiresAt && k.expiresAt <= h24 && k.expiresAt > Date.now();
      }).length;
      const sr = sellers.find(function (x) { return x.name === loggedUser; }) || {};
      const bal = typeof sr.balance === "number" ? sr.balance : 0;
      const spent = myK.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      el.innerHTML =
        '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:8px;margin-bottom:12px">' +
        _kpi("🔑 My Keys", myK.length, "var(--cyan)") +
        _kpi("✅ Active", active, "var(--green)") +
        _kpi("⌛ Expired", expired, "var(--orange)") +
        _kpi("💰 Balance", fmtMoney(bal), (bal < 10000 ? "var(--red)" : "var(--yellow)")) +
        _kpi("💸 Total Spent", fmtMoney(spent), "var(--t2)") +
        (expiring > 0 ? _kpi("⚠ Expiring 24h", expiring, "var(--red)") : "") +
        '</div>' +
        (expiring > 0 ? '<div style="padding:8px 12px;background:rgba(255,60,60,.05);border:1px solid rgba(255,60,60,.15);border-radius:var(--rs);font-size:11px;color:var(--red);margin-bottom:8px">⚠ ' + expiring + ' key' + (expiring > 1 ? "s" : "") + " expiring within 24 hours — renew soon!" + '</div>' : "") +
        (bal < 10000 && bal >= 0 ? '<div style="padding:8px 12px;background:rgba(255,215,0,.05);border:1px solid rgba(255,215,0,.2);border-radius:var(--rs);font-size:11px;color:var(--yellow)">💰 Low balance: ' + fmtMoney(bal) + ' — contact your admin to top up</div>' : "") +
        '<div style="margin-top:8px;display:flex;gap:6px">' +
        '<button class="btn btn-ghost btn-sm" onclick="openBalHistory(null)" style="font-size:11px">📊 Balance History</button>' +
        '<button class="btn btn-ghost btn-sm" onclick="switchPage(\'keys\')" style="font-size:11px">🔑 My Keys</button>' +
        '</div>';
    }


    /* ══ EXTEND KEY ══ */
    function extendKey(id) {
      // Single-key extend — opens modal pre-filled for this key
      openBulkExt();
      // Pre-select this key
      selected.clear(); selected.add(id); updateBulk();
    }


    /* ══ FIRST-TIME SETUP ══ */
    function _checkFirstTimeSetup() {/* notification removed by user request */ }


    /* ══ BALANCE HISTORY ══ */
    function _recordBalHistory(sellerName, amount, reason) {
      const hist = secLoad("lnBalHist_" + sellerName, []);
      hist.unshift({ ts: Date.now(), amount, reason: reason || "Key purchase", bal: _getSellerBal(sellerName) });
      if (hist.length > 100) hist.pop();
      secSave("lnBalHist_" + sellerName, hist);
    }
    function _getSellerBal(name) {
      const sr = sellers.find(function (x) { return x.name === name; });
      return sr ? sr.balance : 0;
    }
    function openBalHistory(sellerName) {
      const hist = secLoad("lnBalHist_" + sellerName, []);
      const nm = sellerName || loggedUser;
      const modal = document.getElementById("balHistModal");
      const list = document.getElementById("balHistList");
      const title = document.getElementById("balHistTitle");
      if (title) title.textContent = "Balance History: " + nm;
      if (!list) return;
      if (!hist.length) {
        list.innerHTML = '<div style="text-align:center;color:var(--t3);padding:20px;font-size:12px">No balance history yet</div>';
      } else {
        list.innerHTML = hist.map(function (h) {
          const dt = new Date(h.ts);
          const dtStr = dt.toLocaleDateString("en-GB", { day: "2-digit", month: "2-digit", year: "2-digit" }) + " " + dt.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
          const isDeduct = h.amount < 0;
          return '<div style="display:flex;align-items:center;gap:10px;padding:7px 0;border-bottom:1px solid var(--b)">' +
            '<div style="flex:1;min-width:0">' +
            '<div style="font-size:11px;font-weight:700;color:' + (isDeduct ? "var(--red)" : "var(--green)") + '">' +
            (isDeduct ? "−" : "+") + (fmtMoney(Math.abs(h.amount))) +
            '</div>' +
            '<div style="font-size:9.5px;color:var(--t3);margin-top:1px">' + h.reason + '</div>' +
            '</div>' +
            '<div style="text-align:right;flex-shrink:0">' +
            '<div style="font-size:9.5px;color:var(--t2)">' + dtStr + '</div>' +
            '<div style="font-size:9px;color:var(--t3)">Bal: ' + fmtMoney(h.bal) + '</div>' +
            '</div>' +
            '</div>';
        }).join("");
      }
      if (modal) modal.classList.add("open");
    }


    /* ══ CSV IMPORT/EXPORT ══ */
    function downloadCSVTemplate() {
      const headers = "key,type,user,expiresAt,tags,group,notes";
      const example = "X3-CST-ABCD-EFGH-IJKL,customer,john123,2025-12-31,#vip @premium,";
      const csv = [headers, example].join("\n");
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
      a.download = "key_import_template.csv";
      a.click();
      toast("Template downloaded", "s");
    }

    function processImportCSV() {
      const inp = document.getElementById("csvFileInput");
      if (!inp || !inp.files || !inp.files[0]) { toast("Select a CSV file first", "w"); return; }
      const reader = new FileReader();
      reader.onload = function (e) {
        const lines = e.target.result.split("\n").filter(function (l) { return l.trim() && !l.startsWith("key,"); });
        let added = 0, skipped = 0;
        lines.forEach(function (line) {
          const parts = line.split(",");
          if (parts.length < 2) return;
          // Sanitize: hanya izinkan karakter aman (samakan dengan key hasil Generate)
          const keyStr = (parts[0] || "").trim().toUpperCase().replace(/[^A-Z0-9\-]/g, "").slice(0, 64);
          const type = (parts[1] || "customer").trim();
          const user = (parts[2] || "").trim().replace(/[<>&"']/g, "").slice(0, 64);
          const expStr = (parts[3] || "").trim();
          const tags = (parts[4] || "").trim().split(" ").filter(Boolean).map(t => t.replace(/[<>&"']/g, "").slice(0, 20)).slice(0, 6);
          if (!keyStr) { skipped++; return; }
          if (keys.find(function (k) { return k.key === keyStr; })) { skipped++; return; }
          const expDate = expStr ? new Date(expStr).getTime() : null;
          if (expStr && isNaN(expDate)) { skipped++; return; }
          keys.unshift({
            id: Date.now() + added, key: keyStr,
            type: ["admin", "customer", "trial"].includes(type) ? type : "customer",
            user: user, status: "active", enabled: true,
            expiresAt: expDate, createdAt: Date.now(),
            totalMs: expDate ? (expDate - Date.now()) : null,
            dur: expStr || "Imported", tags, hwid: null, os: null, lastUsed: null, usage: 0,
            pricePaid: 0, currency: activeCurr, group: "",
            owner: loggedUser, createdBy: loggedUser, createdRole: loggedRole
          });
          added++;
        });
        save(); updateStats(); renderCards(); buildOwnerFilterRow();
        closeModal("importModal");
        addLog("📥", "Imported " + added + " keys (" + (skipped) + " skipped)", "", "action");
        toast("Imported " + added + " keys, " + skipped + " skipped", "s");
      };
      reader.readAsText(inp.files[0]);
    }


    /* ── OWNER FILTER ROW STATE ── */
    function _updateOwnerRowState() {
      const row = document.getElementById("ownerFilterRow");
      if (!row) return;
      const isAll = ownerFilts.has("all") || ownerFilts.size === 0;
      // has-specific class → other chips dim when a specific account is chosen
      if (isAll) {
        row.classList.remove("has-specific");
      } else {
        row.classList.add("has-specific");
      }
      // Update individual .on classes
      row.querySelectorAll(".ktab").forEach(function (b) {
        const val = b.getAttribute("data-val");
        if (!val) return;
        if (ownerFilts.has(val)) b.classList.add("on");
        else b.classList.remove("on");
      });
    }


    /* ── MASS EXECUTE ACCOUNT STATE ── */
    function _updateMeAccountState() {
      const container = document.getElementById("meAccountChips");
      if (!container) return;
      const isAll = meAccountFilts.has("all") || meAccountFilts.size === 0;
      container.querySelectorAll(".me-chip").forEach(function (c) {
        const val = c.getAttribute("data-val");
        if (!val) return;
        const active = meAccountFilts.has(val);
        c.classList.toggle("on", active);
        // Dim logic
        if (isAll) {
          c.style.opacity = val === "all" ? "1" : "0.55";
        } else {
          c.style.opacity = active ? "1" : "0.3";
        }
      });
    }


    /* ══ DASHBOARD VIEW SWITCHER ══ */
    let dashViewAs = null; // null = own view, "username" = view as that user

    function buildDashViewSwitcher() {
      const el = document.getElementById("dashViewFilterRow");
      if (!el) return;
      // Only owner can switch views
      if (loggedRole !== "owner" && loggedRole !== "super_admin") { el.style.display = "none"; return; }

      const accounts = [];
      // Own view
      const ownLabel = loggedRole === "owner" ? "⚡ Owner View" : "★ My View";
      accounts.push({ name: null, label: ownLabel, color: "var(--ca)" });
      // Admins (for owner only)
      if (loggedRole === "owner") {
        adminAccounts.forEach(function (adm) {
          if (adm.name === loggedUser) return;
          accounts.push({ name: adm.name, label: "👑 " + adm.name, color: "var(--cyan)" });
        });
      }
      // Sellers (visible to this user)
      const visSellers = loggedRole === "owner"
        ? sellers
        : sellers.filter(function (sr) { return sr.adminOwner === loggedUser || sr.createdBy === loggedUser; });
      visSellers.forEach(function (sr) {
        accounts.push({ name: sr.name, label: "👤 " + sr.name, color: "var(--purple)" });
      });

      if (accounts.length <= 1) { el.style.display = "none"; return; }
      el.style.display = "flex";
      el.innerHTML = '<span style="font-size:9px;font-weight:700;color:var(--t3);text-transform:uppercase;letter-spacing:.7px;font-family:JetBrains Mono,monospace;align-self:center;margin-right:4px;white-space:nowrap">View</span>';

      accounts.forEach(function (acc) {
        const btn = document.createElement("button");
        btn.className = "ktab" + (dashViewAs === acc.name ? " on" : "");
        btn.style.cssText = "font-size:9.5px;padding:2px 8px;border-color:" + acc.color + "44;color:" + acc.color + (dashViewAs === acc.name ? ";background:" + acc.color + "15" : "");
        btn.textContent = acc.label;
        btn.title = "View dashboard as " + (acc.name || "yourself");
        btn.onclick = function () {
          dashViewAs = acc.name;
          buildDashViewSwitcher(); // refresh active state
          _refreshDashForView();   // reload dashboard data
        };
        el.appendChild(btn);
      });
    }

    function _refreshDashForView() {
      // Re-render dashboard header based on dashViewAs
      const el = document.getElementById("dashOwnSection"); if (!el) return;
      if (dashViewAs === null) {
        // Own view
        if (loggedRole === "seller") { _buildSellerDash(el); }
        else { _buildDashHeader(); }
        renderHierarchyDash();
      } else {
        // View as specific account
        const isSeller = sellers.some(function (x) { return x.name === dashViewAs; });
        if (isSeller) {
          // Show seller's dashboard
          const sr = sellers.find(function (x) { return x.name === dashViewAs; }) || { name: dashViewAs, balance: 0 };
          _buildSellerDashForUser(el, sr);
          document.getElementById("dashHierarchy").innerHTML = "";
        } else {
          // Show admin's dashboard
          const adm = adminAccounts.find(function (a) { return a.name === dashViewAs; }) || { name: dashViewAs };
          _buildAdminDashForUser(el, adm);
        }
      }
      // Update role header
      const lbl = document.getElementById("dashRoleLabel");
      const sub = document.getElementById("dashRoleSub");
      if (dashViewAs && lbl) {
        lbl.textContent = "👁 Viewing: " + dashViewAs;
        if (sub) {
          const sr2 = sellers.find(function (x) { return x.name === dashViewAs; });
          const adm2 = adminAccounts.find(function (a) { return a.name === dashViewAs; });
          sub.textContent = sr2 ? "Seller Account" : adm2 ? "Admin Account" : "Unknown";
        }
      }
    }

    /* Seller dashboard viewed by owner (same as _buildSellerDash but for any seller) */
    function _buildSellerDashForUser(el, sr) {
      const myK = keys.filter(function (k) { return k.owner === sr.name; });
      const active = myK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = myK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const h24 = Date.now() + 86400000;
      const expiring = myK.filter(function (k) {
        return getRealStatus(k) === "active" && k.expiresAt && k.expiresAt <= h24 && k.expiresAt > Date.now();
      }).length;
      const bal = typeof sr.balance === "number" ? sr.balance : 0;
      const spent = myK.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      el.innerHTML =
        '<div style="padding:8px 12px;background:rgba(136,51,255,.05);border:1px solid rgba(136,51,255,.15);border-radius:var(--rs);margin-bottom:10px;font-size:11px;color:var(--purple)">' +
        '👤 Seller view: <b>' + escHtml(sr.name) + '</b> · Balance: ' + fmtMoney(bal) +
        '</div>' +
        '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:8px;margin-bottom:10px">' +
        _kpi("🔑 Total Keys", myK.length, "var(--cyan)") +
        _kpi("✅ Active", active, "var(--green)") +
        _kpi("⌛ Expired", expired, "var(--orange)") +
        _kpi("💰 Balance", fmtMoney(bal), (bal < 10000 ? "var(--red)" : "var(--yellow)")) +
        _kpi("💸 Total Spent", fmtMoney(spent), "var(--t2)") +
        (expiring > 0 ? _kpi("⚠ Expiring 24h", expiring, "var(--red)") : "") +
        '</div>';
    }

    /* Admin dashboard viewed by owner */
    function _buildAdminDashForUser(el, adm) {
      const admSellers = sellers.filter(function (sr) { return sr.adminOwner === adm.name || sr.createdBy === adm.name; });
      const allK = keys.filter(function (k) {
        return k.owner === adm.name || admSellers.some(function (sr) { return sr.name === k.owner; });
      });
      const active = allK.filter(function (k) { return getRealStatus(k) === "active"; }).length;
      const expired = allK.filter(function (k) { return getRealStatus(k) === "expired"; }).length;
      const rev = allK.reduce(function (a, k) { return a + (k.pricePaid || 0); }, 0);
      el.innerHTML =
        '<div style="padding:8px 12px;background:rgba(255,165,0,.05);border:1px solid rgba(255,165,0,.15);border-radius:var(--rs);margin-bottom:10px;font-size:11px;color:var(--ca)">' +
        '👑 Admin view: <b>' + escHtml(adm.name) + '</b> · (' + adm.type + ') · Sellers: ' + admSellers.length +
        '</div>' +
        '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:8px;margin-bottom:10px">' +
        _kpi("🔑 Total Keys", allK.length, "var(--cyan)") +
        _kpi("✅ Active", active, "var(--green)") +
        _kpi("⌛ Expired", expired, "var(--orange)") +
        _kpi("👥 Sellers", admSellers.length, "var(--purple)") +
        _kpi("💰 Revenue", fmtMoney(rev), "var(--yellow)") +
        '</div>';
      // Show their sellers
      const dh = document.getElementById("dashHierarchy");
      if (dh) {
        if (!admSellers.length) { dh.innerHTML = "<p style='font-size:11px;color:var(--t3);padding:10px'>No sellers under this admin</p>"; return; }
        const grid = document.createElement("div");
        grid.style.cssText = "display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:9px;margin-top:10px";
        admSellers.forEach(function (sr) { grid.appendChild(_buildSellerDashCard(sr)); });
        dh.innerHTML = '<div style="font-size:10px;font-weight:700;color:var(--purple);text-transform:uppercase;letter-spacing:1px;font-family:JetBrains Mono,monospace;margin:14px 0 8px">👥 Sellers (' + admSellers.length + ')</div>';
        dh.appendChild(grid);
      }
    }


    /* ── AUTO CLEAN WRAPPER ── */



    /* ── XSS PROTECTION ── */
    function escapeHtml(str) {
      if (str == null) return "";
      return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
    }


    /* ── TIMER MANAGEMENT ── */
    function _trackTimer(id) { _appTimers.push(id); return id; }
    function _clearAllTimers() { _appTimers.forEach(function (id) { clearInterval(id); }); _appTimers = []; }


    /* ── CLEAR ALL FILTERS ── */
    function clearAllFilters() {
      searchQ = "";
      const _si = document.getElementById("searchInp"); if (_si) _si.value = "";
      const _scb = document.getElementById("searchClearBtn"); if (_scb) _scb.style.display = "none";
      activeFilts = new Set(["all"]);
      activeTypeTabs = new Set(["all"]);
      ownerFilts = new Set(["all"]);
      // Reset UI states
      document.querySelectorAll(".fbtn").forEach(function (b) { b.classList.remove("on"); });
      const fAll = document.getElementById("fAll"); if (fAll) fAll.classList.add("on");
      document.querySelectorAll(".km-tab,.ktab").forEach(function (b) { b.classList.remove("on"); });
      const ktabAll = document.getElementById("ktabAll"); if (ktabAll) ktabAll.classList.add("on");
      buildOwnerFilterRow();
      pgPage = 1;
      renderCards(); updateActiveFilters(); updateTabCounts();
      toast("Filters cleared", "i");
    }


    /* ── SELLER UI RESTRICTIONS ── */
    function applyRoleRestrictions() {
      const isSeller = loggedRole === "seller";
      const hideSellersPricing = loggedRole === "owner" || loggedRole === "super_admin";
      // Owner + Super_Admin: hide Sellers + Pricing nav (delegated fully to admin)
      document.querySelectorAll('#niSellersAdmin,[onclick="openPricingModal()"]').forEach(function (el) {
        el.style.display = hideSellersPricing ? "none" : "";
      });

      // Hide Mass Execute sidebar nav
      document.querySelectorAll('[onclick="openMassModal()"]').forEach(function (el) {
        el.style.display = isSeller ? "none" : "";
      });
      // Hide the ⚡ toolbar mass button
      const massToolBtn = document.querySelector('#kmToolbar [aria-label="Mass Execute"]');
      if (massToolBtn) massToolBtn.style.display = isSeller ? "none" : "";



      // PYRAMID: hide nav items by role
      const navSellers = document.querySelector('[onclick="switchPage(\'sellers\')"]');
      const navAdmins = document.querySelector('[onclick="switchPage(\'owners_admins\')"]');
      // Sellers page: hidden for sellers
      document.querySelectorAll('[onclick="switchPage(\'sellers\')"]').forEach(function (el) {
        el.style.display = isSeller ? "none" : "";
      });
      // Owners/Admins page: only owner + super_admin
      const canSeeAdmins = loggedRole === "owner" || loggedRole === "super_admin";
      document.querySelectorAll('[onclick="switchPage(\'owners_admins\')"]').forEach(function (el) {
        el.style.display = canSeeAdmins ? "" : "none";
      });
    }


    /* ── CURRENCY INIT ── */
    function _initCurrency() {
      const saved = localStorage.getItem("lnActiveCurr") || "IDR";
      activeCurr = saved;
      const cs = document.getElementById("currSelect");
      if (cs) cs.value = saved;
    }


    /* ── CURRENCY MIGRATION ── */
    (function () {
      // Ensure currSettings has all 10 currencies, drop obsolete
      const canonical = { IDR: 1, USD: 0.000063, EUR: 0.000058, GBP: 0.000050, JPY: 0.0094, CNY: 0.00046, VND: 1.6, MYR: 0.000295, SGD: 0.000085, PHP: 0.00358 };
      let changed = false;
      // Add missing
      Object.keys(canonical).forEach(function (c) {
        if (!(c in currSettings)) { currSettings[c] = canonical[c]; changed = true; }
      });
      // Remove obsolete (THB etc)
      Object.keys(currSettings).forEach(function (c) {
        if (!(c in canonical)) { delete currSettings[c]; changed = true; }
      });
      if (changed) secSave("lnCurrV1", currSettings);
      // If activeCurr is obsolete, reset to IDR
      if (!(activeCurr in canonical)) { activeCurr = "IDR"; localStorage.setItem("lnActiveCurr", "IDR"); }
    })();


    /* ── PASSWORD DISPLAY HELPER ── */
    function _decodePw(stored) {
      if (!stored) return "[none]";
      // h1$ = SHA-256 hash (one-way, cannot recover plaintext)
      if (stored.startsWith("h1$")) return "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022 (hashed - secure)";
      // b1$ = base64-encoded plaintext
      if (stored.startsWith("b1$")) {
        try { return atob(stored.slice(3)); } catch (e) { return "[encrypted]"; }
      }
      // Legacy raw base64
      try { return atob(stored); } catch (e) { return "[encrypted]"; }
    }


    /* ── EDIT SELLER ── */
    let editSellerIdx = -1;
    function editSeller(idx) {
      if (loggedRole !== "owner" && loggedRole !== "super_admin" && loggedRole !== "admin") { toast("Access denied", "e"); return; }
      const sr = sellers[idx]; if (!sr) return;
      // Pyramid: admin can only edit their own sellers
      if (loggedRole === "admin" && sr.adminOwner !== loggedUser && sr.createdBy !== loggedUser) { toast("Not your seller", "e"); return; }
      editSellerIdx = idx;
      const setV = function (id, v) { const el = document.getElementById(id); if (el) el.value = v; };
      setV("esName", sr.name);
      setV("esPass", "");
      setV("esPrefix", sr.prefix || "");
      setV("esCurrency", sr.currency || "IDR");
      setV("esNotes", sr.notes || "");
      document.getElementById("editSellerModal").classList.add("open");
    }
    function editSellerSave() {
      const sr = sellers[editSellerIdx]; if (!sr) return;
      if (loggedRole === "seller" || !_canSeeUser(sr.name)) { toast("Access denied", "e"); return; }
      const newPass = document.getElementById("esPass").value.trim();
      sr.prefix = document.getElementById("esPrefix").value.trim().toUpperCase().slice(0, 6) || sr.prefix;
      sr.currency = document.getElementById("esCurrency").value;
      sr.notes = document.getElementById("esNotes").value.trim();
      const _finish = function () {
        saveSellers(); closeModal("editSellerModal"); renderSellersList();
        if (currentPage === "owners_admins") renderOwnerAdminsList();
        addLog("✏️", "Edited seller: " + sr.name, "", "action"); toast("Seller updated", "s");
      };
      if (newPass) {
        _hashPw(newPass).then(function (h) { sr.pass = "b1$" + btoa(newPass); _finish(); }).catch(function () { sr.pass = "b1$" + btoa(newPass); _finish(); });
      } else {
        _finish();
      }
    }


    /* ── PWA SERVICE WORKER (offline support) ── */
    (function () {
      if (!("serviceWorker" in navigator)) return;
      // SW requires http/https (not file:// or blob:) — skip silently otherwise
      if (location.protocol !== "https:" && location.protocol !== "http:") return;
      // Inline service worker via Blob — caches this page for offline use
      const swCode = `
    const CACHE="ln-auth-v1";
    self.addEventListener("install",function(e){self.skipWaiting();});
    self.addEventListener("activate",function(e){e.waitUntil(self.clients.claim());});
    self.addEventListener("fetch",function(e){
      // Network-first for navigation, cache fallback
      if(e.request.mode==="navigate"){
        e.respondWith(
          fetch(e.request).then(function(resp){
            const clone=resp.clone();
            caches.open(CACHE).then(function(c){c.put(e.request,clone);});
            return resp;
          }).catch(function(){
            return caches.match(e.request).then(function(r){return r||caches.match("./");});
          })
        );
        return;
      }
      // Cache-first for fonts/assets
      if(e.request.url.includes("fonts.g")||e.request.url.includes(".woff")){
        e.respondWith(
          caches.match(e.request).then(function(r){
            return r||fetch(e.request).then(function(resp){
              const clone=resp.clone();
              caches.open(CACHE).then(function(c){c.put(e.request,clone);});
              return resp;
            });
          })
        );
      }
    });
  `;
      try {
        const blob = new Blob([swCode], { type: "application/javascript" });
        const swUrl = URL.createObjectURL(blob);
        navigator.serviceWorker.register(swUrl).then(function () {

        }).catch(function (err) {

        });
      } catch (e) { }
    })();

    /* ── PWA INSTALL PROMPT ── */
    let _deferredPrompt = null;
    window.addEventListener("beforeinstallprompt", function (e) {
      e.preventDefault();
      _deferredPrompt = e;
      // Show install button if present
      const btn = document.getElementById("pwaInstallBtn");
      if (btn) btn.style.display = "";
    });
    function pwaInstall() {
      if (!_deferredPrompt) { toast("App already installed or not available", "i"); return; }
      _deferredPrompt.prompt();
      _deferredPrompt.userChoice.then(function (choice) {
        if (choice.outcome === "accepted") { toast("Installing app…", "s"); }
        _deferredPrompt = null;
        const btn = document.getElementById("pwaInstallBtn");
        if (btn) btn.style.display = "none";
      });
    }
    window.addEventListener("appinstalled", function () {
      toast("App installed successfully!", "s");
      const btn = document.getElementById("pwaInstallBtn");
      if (btn) btn.style.display = "none";
    });

    /* ── THROTTLED STATS REFRESH (perf) ── */
    let _statsRefreshPending = false;
    function _scheduleStatsRefresh() {
      if (_statsRefreshPending) return;
      _statsRefreshPending = true;
      requestAnimationFrame(function () {
        _statsRefreshPending = false;
        if (typeof updateStats === "function") updateStats();
        if (typeof updateTabCounts === "function") updateTabCounts();
      });
    }


    /* ── IP CAPTURE (on device binding) ── */
    function _fetchIP() {
      // Try multiple free IP APIs with fallback (no key needed)
      return new Promise(function (resolve) {
        const apis = [
          { url: "https://api.ipify.org?format=json", field: "ip" },
          { url: "https://api64.ipify.org?format=json", field: "ip" },
          { url: "https://ipapi.co/json/", field: "ip" }
        ];
        let i = 0;
        function tryNext() {
          if (i >= apis.length) { resolve(null); return; }
          const api = apis[i++];
          const ctrl = typeof AbortController !== "undefined" ? new AbortController() : null;
          const timer = setTimeout(function () { if (ctrl) ctrl.abort(); }, 4000);
          fetch(api.url, ctrl ? { signal: ctrl.signal } : {})
            .then(function (r) { return r.json(); })
            .then(function (d) {
              clearTimeout(timer);
              const ip = d && d[api.field];
              if (ip) resolve(String(ip)); else tryNext();
            })
            .catch(function () { clearTimeout(timer); tryNext(); });
        }
        tryNext();
      });
    }
    function _fetchIPInfo() {
      // Try multiple free geo-IP APIs (CORS-friendly) with fallback
      return new Promise(function (resolve) {
        const apis = [
          // ipwho.is — CORS enabled, no key, returns ip+country+city
          { url: "https://ipwho.is/", parse: function (d) { return d && d.success !== false && d.ip ? { ip: d.ip, country: d.country || "", city: d.city || "", org: (d.connection && d.connection.org) || d.org || "" } : null; } },
          // ipapi.co — CORS enabled
          { url: "https://ipapi.co/json/", parse: function (d) { return d && d.ip ? { ip: d.ip, country: d.country_name || d.country || "", city: d.city || "", org: d.org || "" } : null; } },
          // freeipapi.com — CORS enabled
          { url: "https://freeipapi.com/api/json", parse: function (d) { return d && d.ipAddress ? { ip: d.ipAddress, country: d.countryName || "", city: d.cityName || "", org: "" } : null; } },
          // geojs.io — CORS enabled
          { url: "https://get.geojs.io/v1/ip/geo.json", parse: function (d) { return d && d.ip ? { ip: d.ip, country: d.country || "", city: d.city || "", org: d.organization_name || "" } : null; } },
          // ipify (IP only, very reliable)
          { url: "https://api.ipify.org?format=json", parse: function (d) { return d && d.ip ? { ip: d.ip, country: "", city: "", org: "" } : null; } }
        ];
        let i = 0;
        function tryNext() {
          if (i >= apis.length) { resolve(null); return; }
          const api = apis[i++];
          let done = false;
          const ctrl = typeof AbortController !== "undefined" ? new AbortController() : null;
          const timer = setTimeout(function () { if (!done) { done = true; if (ctrl) ctrl.abort(); tryNext(); } }, 3500);
          fetch(api.url, ctrl ? { signal: ctrl.signal, cache: "no-store" } : { cache: "no-store" })
            .then(function (r) { return r.json(); })
            .then(function (d) {
              if (done) return; done = true; clearTimeout(timer);
              const info = api.parse(d);
              if (info && info.ip) resolve(info); else tryNext();
            })
            .catch(function () { if (done) return; done = true; clearTimeout(timer); tryNext(); });
        }
        tryNext();
      });
    }


    /* ── MANUAL IP CHECK ── */
    function checkMyIP() {
      toast("Checking IP\u2026", "i");
      _fetchIPInfo().then(function (info) {
        if (info && info.ip) {
          const loc = [info.city, info.country].filter(Boolean).join(", ");
          const msg = "\ud83c\udf10 Your IP: " + info.ip + (loc ? "\n\ud83d\udccd Location: " + loc : "") + (info.org ? "\n\ud83c\udfe2 ISP: " + info.org : "");
          if (typeof confirm2 === "function") confirm2("IP Information", "<div style=\"font-family:JetBrains Mono,monospace;font-size:13px;line-height:1.8\"><div>\ud83c\udf10 <b>IP:</b> " + escHtml(info.ip) + "</div>" + (loc ? "<div>\ud83d\udccd <b>Location:</b> " + escHtml(loc) + "</div>" : "") + (info.org ? "<div>\ud83c\udfe2 <b>ISP:</b> " + escHtml(info.org) + "</div>" : "") + "</div>", "\ud83c\udf10", function () { });
          addLog("\ud83c\udf10", "Manual IP check: " + info.ip + (loc ? " (" + loc + ")" : ""), "", "auth", { note: loggedUser });
        } else {
          toast("Could not fetch IP (network blocked or offline)", "e");
        }
      });
    }


    /* ── SESSION AUTO-LOGOUT (idle timeout) ── */
    let _idleTimer = null, _idleWarnTimer = null, _idleCountdown = null;
    let _sessionConfig = secLoad("lnSessionCfg", { enabled: true, timeoutMin: 15 });
    function _getIdleMs() { return (_sessionConfig.timeoutMin || 15) * 60 * 1000; }
    function _resetIdleTimer() {
      if (!_sessionConfig.enabled || !loggedUser) return;
      clearTimeout(_idleTimer); clearTimeout(_idleWarnTimer);
      if (_idleCountdown) { clearInterval(_idleCountdown); _idleCountdown = null; }
      const warnEl = document.getElementById("idleWarn"); if (warnEl) warnEl.style.display = "none";
      const ms = _getIdleMs();
      // Warn 60s before logout
      _idleWarnTimer = setTimeout(_showIdleWarning, Math.max(ms - 60000, ms * 0.5));
      _idleTimer = setTimeout(_autoLogout, ms);
    }
    function _showIdleWarning() {
      if (!loggedUser) return;
      let warnEl = document.getElementById("idleWarn");
      if (!warnEl) {
        warnEl = document.createElement("div");
        warnEl.id = "idleWarn";
        warnEl.style.cssText = "position:fixed;top:16px;left:50%;transform:translateX(-50%);z-index:9999;background:var(--card);border:1px solid var(--orange);border-radius:12px;padding:12px 18px;box-shadow:0 8px 32px rgba(0,0,0,.5);display:flex;align-items:center;gap:12px;font-size:13px;color:var(--t1)";
        document.body.appendChild(warnEl);
      }
      let secs = 60;
      const update = function () {
        warnEl.innerHTML = '<span style="font-size:18px">\u23f1</span><span>Session expires in <b style="color:var(--orange)">' + secs + 's</b> due to inactivity</span><button class="btn btn-primary btn-sm" onclick="_resetIdleTimer()" style="margin-left:8px">Stay logged in</button>';
        warnEl.style.display = "flex";
      };
      update();
      _idleCountdown = setInterval(function () {
        secs--;
        if (secs <= 0) { clearInterval(_idleCountdown); return; }
        update();
      }, 1000);
    }
    function _autoLogout() {
      if (!loggedUser) return;
      clearTimeout(_idleTimer); clearTimeout(_idleWarnTimer);
      if (_idleCountdown) clearInterval(_idleCountdown);
      const warnEl = document.getElementById("idleWarn"); if (warnEl) warnEl.style.display = "none";
      addLog("\ud83d\udd12", "Auto-logout (idle timeout): " + loggedUser, "", "auth", { note: _sessionConfig.timeoutMin + " min inactivity" });
      _clearAllTimers();
      document.getElementById("app").style.display = "none";
      const ls = document.getElementById("loginScreen"); if (ls) { ls.style.display = "flex"; ls.style.opacity = "1"; }
      loggedUser = null; loggedRole = "admin"; loggedSeller = null;
      toast("Logged out due to inactivity", "i");
    }
    let _idleListenersAttached = false;
    function _initIdleTracking() {
      if (!_sessionConfig.enabled) return;
      if (!_idleListenersAttached) {
        ["mousedown", "mousemove", "keypress", "scroll", "touchstart", "click"].forEach(function (ev) {
          document.addEventListener(ev, _throttledIdleReset, { passive: true });
        });
        _idleListenersAttached = true;
      }
      _resetIdleTimer();
    }
    let _idleResetThrottle = 0;
    function _throttledIdleReset() {
      const now = Date.now();
      if (now - _idleResetThrottle < 2000) return; // throttle to every 2s
      _idleResetThrottle = now;
      _resetIdleTimer();
    }
    function saveSessionConfig() {
      const en = document.getElementById("sessAutoLogout");
      const mins = document.getElementById("sessTimeout");
      if (en) _sessionConfig.enabled = en.checked;
      if (mins) _sessionConfig.timeoutMin = Math.max(1, parseInt(mins.value) || 15);
      secSave("lnSessionCfg", _sessionConfig);
      if (_sessionConfig.enabled) _resetIdleTimer();
      else { clearTimeout(_idleTimer); clearTimeout(_idleWarnTimer); }
      addLog("\u2699", "Session settings updated", "", "settings", { note: "Auto-logout: " + (_sessionConfig.enabled ? _sessionConfig.timeoutMin + " min" : "off") });
      toast("Session settings saved", "s");
      if (typeof closeModal === "function") closeModal("sessionModal");
    }
    function openSessionModal() {
      if (loggedRole !== "owner" && loggedRole !== "super_admin") { toast("Access denied", "e"); return; }
      const en = document.getElementById("sessAutoLogout"); if (en) en.checked = _sessionConfig.enabled;
      const mins = document.getElementById("sessTimeout"); if (mins) mins.value = _sessionConfig.timeoutMin;
      document.getElementById("sessionModal").classList.add("open");
    }


    /* ── SUSPICIOUS LOGIN DETECTION ── */
    function _checkSuspiciousLogin(username, role, info, dev) {
      // Compare against this user's previous logins
      const prevLogins = loginHistory.filter(function (h) {
        return h.user === username && h.ip && h.ip !== "(unavailable)" && h.ip !== "(error)";
      });
      if (prevLogins.length <= 1) return; // first login, nothing to compare
      const reasons = [];
      // Get set of known IPs, countries, devices from history (excluding current)
      const knownIPs = new Set(), knownCountries = new Set(), knownDevices = new Set();
      prevLogins.slice(1).forEach(function (h) {
        if (h.ip) knownIPs.add(h.ip);
        if (h.ipCountry) knownCountries.add(h.ipCountry);
        if (h.os) knownDevices.add(h.os + "/" + h.browser);
      });
      // Check current login against known
      if (info && info.ip && knownIPs.size > 0 && !knownIPs.has(info.ip)) {
        reasons.push("New IP: " + info.ip);
      }
      if (info && info.country && knownCountries.size > 0 && !knownCountries.has(info.country)) {
        reasons.push("New country: " + info.country);
      }
      const curDev = dev.os + "/" + dev.browser;
      if (knownDevices.size > 0 && !knownDevices.has(curDev)) {
        reasons.push("New device: " + dev.os + " " + dev.browser);
      }
      if (reasons.length > 0) {
        const detail = reasons.join(" \u00b7 ");
        addLog("\u26a0\ufe0f", "Suspicious login: " + username, "", "auth", { note: detail, before: "Known login", after: "\u26a0 " + detail });
        // Alert via webhook (non-seller or always for owner visibility)
        if (typeof notifyWebhook === "function") {
          notifyWebhook("\u26a0\ufe0f **SUSPICIOUS LOGIN**\nUser: " + username + " (" + role + ")\n" + reasons.join("\n") + "\nIP: " + (info ? info.ip : "?") + "\nDevice: " + dev.summary, "login");
        }
        // Visual alert for the user themselves
        if (username === loggedUser) {
          setTimeout(function () {
            if (typeof confirm2 === "function") {
              confirm2("\u26a0 Security Alert", "<div style=\"font-size:13px;line-height:1.7\"><div style=\"color:var(--orange);font-weight:700;margin-bottom:8px\">Unusual login detected for your account:</div>" + reasons.map(function (r) { return "<div>\u2022 " + escHtml(r) + "</div>"; }).join("") + "<div style=\"margin-top:10px;color:var(--t3);font-size:11px\">If this was you, you can ignore this. Otherwise, change your password immediately.</div></div>", "\u26a0", function () { });
            }
          }, 1500);
        }
        return true;
      }
      return false;
    }

    /* ── DOM CACHE (perf) ── */
    const _domCache = {};
    function _$(id) {
      let el = _domCache[id];
      if (el && el.isConnected) return el;
      el = document.getElementById(id);
      if (el) _domCache[id] = el;
      return el;
    }


    /* ── DETAIL TAG EDITING (no regenerate) ── */
    function _canEditKey(k) {
      // Owner: all. Super_admin/admin: their visible keys. Seller: own keys only.
      if (loggedRole === "owner") return true;
      if (loggedRole === "seller") return k.owner === loggedUser;
      return _canSeeUser(k.owner || loggedUser);
    }
    function detAddTag() {
      const k = keys.find(x => x.id === detId); if (!k) return;
      if (!_canEditKey(k)) { toast("Access denied", "e"); return; }
      const inp = document.getElementById("detTagInp"); if (!inp) return;
      const v = inp.value.trim().replace(/^#+/, "").toUpperCase();
      if (!v) { toast("Enter a tag name", "w"); return; }
      if (!k.tags) k.tags = [];
      if (k.tags.includes(v)) { toast("Tag already exists", "w"); return; }
      if (k.tags.length >= 6) { toast("Max 6 tags per key", "w"); return; }
      k.tags.push(v);
      inp.value = "";
      save(); renderCards();
      _renderDetailTags(k);
      addLog("\ud83c\udff7", "Added tag: #" + v, k.key, "action", { note: "Tags: " + k.tags.join(", ") });
      toast("Tag added", "s");
    }
    function detRemoveTag(tag) {
      const k = keys.find(x => x.id === detId); if (!k || !k.tags) return;
      if (!_canEditKey(k)) { toast("Access denied", "e"); return; }
      const idx = k.tags.indexOf(tag);
      if (idx < 0) return;
      k.tags.splice(idx, 1);
      save(); renderCards();
      _renderDetailTags(k);
      addLog("\ud83c\udff7", "Removed tag: #" + tag, k.key, "action", { note: k.tags.length ? "Tags: " + k.tags.join(", ") : "No tags" });
      toast("Tag removed", "i");
    }
    function detTagKey(e) {
      if (e.key === "Enter" || e.key === ",") { e.preventDefault(); detAddTag(); }
    }
    function _renderDetailTags(k) {
      const wrap = document.getElementById("detTagsEdit");
      if (!wrap) return;
      const canEdit = _canEditKey(k);
      const tags = k.tags || [];
      let html = "";
      if (tags.length) {
        html = '<div style="display:flex;flex-wrap:wrap;gap:5px;margin-bottom:' + (canEdit ? "8px" : "0") + '">';
        html += tags.map(function (t) {
          return '<span class="tag ' + getTC(t) + '" style="display:inline-flex;align-items:center;gap:3px"><span class="tx">#</span>' + escHtml(t.toUpperCase()) + (canEdit ? '<span style="opacity:.6;cursor:pointer;margin-left:3px;font-size:11px" onclick="detRemoveTag(\'' + escHtml(t) + '\')" title="Remove tag">\u2715</span>' : '') + '</span>';
        }).join("");
        html += '</div>';
      } else {
        html = '<div style="font-size:11px;color:var(--t3);margin-bottom:' + (canEdit ? "8px" : "0") + '">No tags yet</div>';
      }
      // Input row (only if can edit)
      if (canEdit) {
        html += '<div style="display:flex;gap:6px;align-items:center">' +
          '<input id="detTagInp" class="fi" style="flex:1;font-size:11px;padding:6px 10px" placeholder="Add tag (e.g. VIP)" maxlength="16" onkeydown="detTagKey(event)">' +
          '<button class="btn btn-primary btn-sm" onclick="detAddTag()" style="white-space:nowrap">+ Add</button>' +
          '</div>';
      }
      wrap.innerHTML = html;
    }


    /* ── TABLE VIEW ACTIONS (minimalist icons) ── */
    function _miniActions(k, rs) {
      const canEdit = (typeof _canEditKey === "function") ? _canEditKey(k) : true;
      let b = "";
      b += '<button class="mt-act" onclick="copyKey(\'' + escJsAttr(k.key) + '\')">\u2398 ' + T("lbl_btn_copy") + '</button>';
      b += '<button class="mt-act" onclick="openDetail(' + k.id + ')">\ud83d\udc41 ' + T("act_view") + '</button>';
      if (canEdit) {
        if (k.hwid) {
          b += '<button class="mt-act" onclick="doUnlink(' + k.id + ')">\ud83d\udd13 ' + T("act_unlink") + '</button>';
        } else {
          b += '<button class="mt-act" onclick="openLinkModal(' + k.id + ')">\ud83d\udd17 ' + T("act_link") + '</button>';
        }
        b += '<button class="mt-act" onclick="openExt(' + k.id + ')">\u23f0 ' + T("lbl_btn_extend") + '</button>';
        if (rs === "revoked") {
          b += '<button class="mt-act mt-act-ok" onclick="resetKey(' + k.id + ')">\u21ba ' + T("act_restore") + '</button>';
        } else {
          b += '<button class="mt-act mt-act-warn" onclick="revokeKey(' + k.id + ')">\u26d4 ' + T("lbl_btn_revoke") + '</button>';
        }
        if (k.enabled === false) {
          b += '<button class="mt-act mt-act-ok" onclick="toggleKey(' + k.id + ')">\u2714 ' + T("act_enable") + '</button>';
        } else {
          b += '<button class="mt-act" onclick="toggleKey(' + k.id + ')">\u23f8 ' + T("act_disable") + '</button>';
        }
        b += '<button class="mt-act" onclick="resetKey(' + k.id + ')">\u267b ' + T("act_reset") + '</button>';
        b += '<button class="mt-act mt-act-danger" onclick="deleteKey(' + k.id + ')">\u2715 ' + T("lbl_btn_delete") + '</button>';
      }
      return b;
    }


    /* ── ACCESSIBILITY: keyboard nav untuk div[onclick] "fake buttons" ── */
    function _enhanceA11y(root) {
      (root || document).querySelectorAll('[onclick]:not([tabindex]):not(button):not(a):not(input):not(select):not(textarea)').forEach(function (el) {
        el.setAttribute('tabindex', '0');
        if (!el.hasAttribute('role')) el.setAttribute('role', 'button');
      });
    }
    function _initA11yObserver() {
      _enhanceA11y(document);
      // Delegated Enter/Space → click (works for ALL current + future elements, no per-render hook needed)
      document.addEventListener('keydown', function (e) {
        if ((e.key === 'Enter' || e.key === ' ') && e.target && e.target.getAttribute && e.target.getAttribute('role') === 'button' && e.target.hasAttribute('onclick')) {
          e.preventDefault();
          e.target.click();
        }
      });
      // Auto-enhance any new elements added later (cards, table rows, modals, etc.) — self-maintaining
      if (typeof MutationObserver !== "undefined") {
        const obs = new MutationObserver(function (muts) {
          let needsScan = false;
          for (const m of muts) { if (m.addedNodes && m.addedNodes.length) { needsScan = true; break; } }
          if (needsScan) _enhanceA11y(document);
        });
        obs.observe(document.body, { childList: true, subtree: true });
      }
    }

    /* ══ INIT ══ */
    addLog("⭐", "Panel ready", "", "action");
    // Init improvements
    updateExpireBadge();
    initPgSizeBtns();
    _initPTR();
    _initCardSwipe();
    _initA11yObserver();



























































































































































































  