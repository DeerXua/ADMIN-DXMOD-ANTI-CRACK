document.addEventListener('DOMContentLoaded', () => {
    const API_BASE = ''; // Same origin
    let adminToken = localStorage.getItem('dx_admin_token') || '';
    let devices = [];
    let allSessions = [];
    let onlineStatusMap = {}; // {uid: 'in_match'|'online'|'offline'}
    let onlineStatusInterval = null;

    // DOM Elements
    const loginContainer = document.getElementById('login-container');
    const dashboardContainer = document.getElementById('dashboard-container');
    const loginForm = document.getElementById('login-form');
    const adminPasswordInput = document.getElementById('admin-password');
    const loginError = document.getElementById('login-error');
    const logoutBtn = document.getElementById('logout-btn');

    const statTotal = document.getElementById('stat-total');
    const statActive = document.getElementById('stat-active');
    const statPending = document.getElementById('stat-pending');
    const statExpired = document.getElementById('stat-expired');
    const statSessions = document.getElementById('stat-sessions');
    const statInMatch = document.getElementById('stat-in-match');

    const searchInput = document.getElementById('search-input');
    const statusFilter = document.getElementById('status-filter');
    const refreshBtn = document.getElementById('refresh-btn');
    const devicesTbody = document.getElementById('devices-tbody');
    const noDataMsg = document.getElementById('no-data-msg');
    const refreshTimestamp = document.getElementById('refresh-timestamp');

    // Bulk elements
    const selectAllCheckbox = document.getElementById('select-all');
    const bulkBar = document.getElementById('bulk-bar');
    const bulkCount = document.getElementById('bulk-count');
    const bulkApproveBtn = document.getElementById('bulk-approve-btn');
    const bulkDeleteBtn = document.getElementById('bulk-delete-btn');
    const bulkClearBtn = document.getElementById('bulk-clear-btn');
    const addDeviceBtn = document.getElementById('add-device-btn');
    const exportCsvBtn = document.getElementById('export-csv-btn');

    // Modal elements
    const editModal = document.getElementById('edit-modal');
    const editForm = document.getElementById('edit-form');
    const editUid = document.getElementById('edit-uid');
    const editLabel = document.getElementById('edit-label');
    const editGameId = document.getElementById('edit-game-id');
    const editStatus = document.getElementById('edit-status');
    const editExpirySelect = document.getElementById('edit-expiry-select');
    const customExpiryContainer = document.getElementById('custom-expiry-container');
    const editExpiryDate = document.getElementById('edit-expiry-date');
    const editNote = document.getElementById('edit-note');
    const closeModalBtns = document.querySelectorAll('.close-modal');

    // Confirm modal
    const confirmModal = document.getElementById('confirm-modal');
    const confirmTitle = document.getElementById('confirm-title');
    const confirmBody = document.getElementById('confirm-body');
    const confirmOkBtn = document.getElementById('confirm-ok-btn');
    const confirmCancelBtn = document.getElementById('confirm-cancel-btn');

    // Add device modal
    const addModal = document.getElementById('add-modal');
    const addForm = document.getElementById('add-form');
    const addUid = document.getElementById('add-uid');
    const addLabel = document.getElementById('add-label');
    const addExpirySelect = document.getElementById('add-expiry-select');
    const addCustomExpiryContainer = document.getElementById('add-custom-expiry-container');
    const addExpiryDate = document.getElementById('add-expiry-date');
    const addNote = document.getElementById('add-note');

    const toastElement = document.getElementById('toast');

    // Screenshot modal elements
    const screenshotModal = document.getElementById('screenshot-modal');
    const screenshotImg = document.getElementById('screenshot-img');
    const closeScreenshotModal = document.querySelector('.close-screenshot-modal');

    // Initialize View block has been moved to the bottom of the file

    // --- Authentication ---
    loginForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const password = adminPasswordInput.value;
        try {
            const res = await fetch(`${API_BASE}/api/admin/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ password })
            });

            const data = await res.json();
            if (res.ok && data.success) {
                adminToken = data.token;
                localStorage.setItem('dx_admin_token', adminToken);
                showDashboard();
                showToast('Đăng nhập thành công!', 'success');
            } else {
                loginError.textContent = data.error || 'Mật khẩu không chính xác!';
            }
        } catch (err) {
            loginError.textContent = 'Không thể kết nối đến máy chủ!';
        }
    });

    logoutBtn.addEventListener('click', () => {
        adminToken = '';
        localStorage.removeItem('dx_admin_token');
        showLogin();
        showToast('Đã đăng xuất.', 'success');
    });

    function showLogin() {
        loginContainer.classList.add('active');
        dashboardContainer.classList.remove('active');
        adminPasswordInput.value = '';
        loginError.textContent = '';
    }

    function showDashboard() {
        loginContainer.classList.remove('active');
        dashboardContainer.classList.add('active');
        fetchDevices();
        window.loadSessions();
        fetchOnlineStatus();
        if (onlineStatusInterval) clearInterval(onlineStatusInterval);
        onlineStatusInterval = setInterval(fetchOnlineStatus, 15000);
    }

    function updateRefreshTimestamp() {
        if (refreshTimestamp) {
            refreshTimestamp.textContent = 'Cập nhật lúc: ' + new Date().toLocaleString('vi-VN');
        }
    }

    // ── Confirm Dialog ──
    function showConfirm(title, body) {
        return new Promise(resolve => {
            confirmTitle.textContent = title;
            confirmBody.textContent = body;
            confirmModal.style.display = 'flex';

            const cleanup = () => {
                confirmModal.style.display = 'none';
                confirmOkBtn.removeEventListener('click', onOk);
                confirmCancelBtn.removeEventListener('click', onCancel);
                document.querySelectorAll('.close-confirm').forEach(el => el.removeEventListener('click', onCancel));
                confirmModal.removeEventListener('click', onOutsideClick);
            };

            const onOk = () => { cleanup(); resolve(true); };
            const onCancel = () => { cleanup(); resolve(false); };
            const onOutsideClick = (e) => { if (e.target === confirmModal) onCancel(); };

            confirmOkBtn.addEventListener('click', onOk);
            confirmCancelBtn.addEventListener('click', onCancel);
            document.querySelectorAll('.close-confirm').forEach(el => el.addEventListener('click', onCancel));
            confirmModal.addEventListener('click', onOutsideClick);
        });
    }

    // --- Fetch & Render Devices ---
    async function fetchDevices() {
        try {
            const res = await fetch(`${API_BASE}/api/admin/devices`, {
                headers: { 'Authorization': adminToken }
            });

            if (res.status === 401) {
                // Token invalid or expired
                adminToken = '';
                localStorage.removeItem('dx_admin_token');
                showLogin();
                showToast('Phiên đăng nhập hết hạn!', 'error');
                return;
            }

            if (!res.ok) throw new Error('Failed to fetch devices');

            devices = await res.json();
            renderDevices();
            updateStats();
        } catch (err) {
            showToast('Lỗi khi tải danh sách thiết bị!', 'error');
        }
    }

    async function fetchOnlineStatus() {
        if (!adminToken) return;
        try {
            const res = await fetch(`${API_BASE}/api/admin/online-status`, {
                headers: { 'Authorization': adminToken }
            });
            if (res.ok) {
                onlineStatusMap = await res.json();
                renderDevices(); // re-render to show updated badges
            }
        } catch (_) { /* silent */ }
    }

    function renderDevices() {
        const query = searchInput.value.toLowerCase().trim();
        const filter = statusFilter.value;

        const filtered = devices.filter(d => {
            const matchesQuery = 
                String(d.game_id || '').toLowerCase().includes(query) ||
                String(d.label || '').toLowerCase().includes(query) ||
                String(d.note || '').toLowerCase().includes(query);

            const isExpired = d.expires_at && new Date(d.expires_at).getTime() < Date.now();
            let matchesFilter = true;
            if (filter === 'approved') {
                matchesFilter = (d.status === 'approved' || d.status === 'active') && !isExpired;
            } else if (filter === 'pending') {
                matchesFilter = d.status === 'pending';
            } else if (filter === 'expired') {
                matchesFilter = isExpired;
            }

            return matchesQuery && matchesFilter;
        });

        devicesTbody.innerHTML = '';

        if (filtered.length === 0) {
            noDataMsg.style.display = 'flex';
            return;
        }

        noDataMsg.style.display = 'none';
        updateRefreshTimestamp();

        // Track which UIDs are currently visible (for select-all)
        window._visibleUIDs = [];

        filtered.forEach(d => {
            const isExpired = d.expires_at && new Date(d.expires_at).getTime() < Date.now();
            window._visibleUIDs.push(d.game_id);
            
            let statusText = 'Chờ duyệt';
            let statusClass = 'pending';
            if (isExpired) {
                statusText = 'Hết hạn';
                statusClass = 'expired';
            } else if (d.status === 'approved' || d.status === 'active') {
                statusText = 'Hoạt động';
                statusClass = 'approved';
            }

            const regDate = d.first_seen_at ? new Date(d.first_seen_at).toLocaleString('vi-VN') : 'Không rõ';
            const expiryText = d.expires_at ? new Date(d.expires_at).toLocaleString('vi-VN') : 'Vĩnh viễn';

            // Online badge
            const onlineState = onlineStatusMap[d.game_id] || 'offline';
            let onlineBadge;
            if (onlineState === 'in_match') {
                onlineBadge = `<span class="online-badge in-match"><span class="online-dot"></span>Đang trong trận</span>`;
            } else if (onlineState === 'online') {
                onlineBadge = `<span class="online-badge online"><span class="online-dot"></span>Online</span>`;
            } else {
                onlineBadge = `<span class="online-badge offline"><span class="online-dot"></span>Offline</span>`;
            }

            const safeUid = escapeHtml(d.game_id);
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><input type="checkbox" class="device-checkbox" value="${safeUid}"></td>
                <td><strong>#${d.id}</strong></td>
                <td>${escapeHtml(d.label || 'Chưa đặt tên')}</td>
                <td><code class="code-uid">${safeUid}</code> <button class="btn-copy-uid" data-uid="${safeUid}" title="Copy UID"><i class="fa-regular fa-copy"></i></button></td>
                <td><span class="status-badge ${statusClass}">${statusText}</span></td>
                <td>${onlineBadge}</td>
                <td>${regDate}</td>
                <td><span class="${isExpired ? 'text-red' : ''}">${expiryText}</span></td>
                <td class="note-cell">${escapeHtml(d.note || '-')}</td>
                <td>
                    <div class="actions-cell">
                        <button class="btn-icon edit" data-uid="${safeUid}" title="Sửa bản quyền"><i class="fa-solid fa-pen-to-square"></i></button>
                        <button class="btn-icon delete" data-uid="${safeUid}" title="Xóa thiết bị"><i class="fa-solid fa-trash-can"></i></button>
                    </div>
                </td>
            `;
            devicesTbody.appendChild(tr);
        });

        // Add action listeners
        document.querySelectorAll('.btn-icon.edit').forEach(btn => {
            btn.addEventListener('click', () => openEditModal(btn.dataset.uid));
        });

        document.querySelectorAll('.btn-icon.delete').forEach(btn => {
            btn.addEventListener('click', () => handleDeleteDevice(btn.dataset.uid));
        });

        // Copy UID listeners
        document.querySelectorAll('.btn-copy-uid').forEach(btn => {
            btn.addEventListener('click', () => {
                navigator.clipboard.writeText(btn.dataset.uid).then(() => {
                    showToast('Đã copy UID!', 'success');
                }).catch(() => {
                    // Fallback
                    const ta = document.createElement('textarea');
                    ta.value = btn.dataset.uid;
                    document.body.appendChild(ta);
                    ta.select();
                    document.execCommand('copy');
                    document.body.removeChild(ta);
                    showToast('Đã copy UID!', 'success');
                });
            });
        });

        // Checkbox listeners
        document.querySelectorAll('.device-checkbox').forEach(cb => {
            cb.addEventListener('change', updateBulkBar);
        });
    }

    function updateStats() {
        const total = devices.length;
        let active = 0;
        let pending = 0;
        let expired = 0;

        devices.forEach(d => {
            const isExpired = d.expires_at && new Date(d.expires_at).getTime() < Date.now();
            if (isExpired) {
                expired++;
            } else if (d.status === 'approved' || d.status === 'active') {
                active++;
            } else {
                pending++;
            }
        });

        statTotal.textContent = total;
        statActive.textContent = active;
        statPending.textContent = pending;
        statExpired.textContent = expired;

        // Session stats
        if (statSessions) statSessions.textContent = allSessions.length;
        if (statInMatch)  statInMatch.textContent  = allSessions.filter(s => s.status === 'in_match').length;
    }

    // ── Bulk Actions ──
    function getSelectedUIDs() {
        const checked = [];
        document.querySelectorAll('.device-checkbox:checked').forEach(cb => checked.push(cb.value));
        return checked;
    }

    function updateBulkBar() {
        const selected = getSelectedUIDs();
        if (selected.length === 0) {
            bulkBar.style.display = 'none';
            if (selectAllCheckbox) selectAllCheckbox.checked = false;
            return;
        }
        bulkBar.style.display = 'flex';
        bulkCount.textContent = `Đã chọn ${selected.length} thiết bị`;
    }

    if (selectAllCheckbox) {
        selectAllCheckbox.addEventListener('change', () => {
            const checked = selectAllCheckbox.checked;
            document.querySelectorAll('.device-checkbox').forEach(cb => cb.checked = checked);
            updateBulkBar();
        });
    }

    if (bulkClearBtn) {
        bulkClearBtn.addEventListener('click', () => {
            document.querySelectorAll('.device-checkbox').forEach(cb => cb.checked = false);
            if (selectAllCheckbox) selectAllCheckbox.checked = false;
            updateBulkBar();
        });
    }

    if (bulkApproveBtn) {
        bulkApproveBtn.addEventListener('click', async () => {
            const uids = getSelectedUIDs();
            if (uids.length === 0) return;
            const confirmed = await showConfirm('Duyệt thiết bị', `Bạn có chắc muốn duyệt ${uids.length} thiết bị đã chọn?`);
            if (!confirmed) return;
            try {
                const res = await fetch(`${API_BASE}/api/admin/bulk-approve`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': adminToken },
                    body: JSON.stringify({ uids })
                });
                if (res.ok) {
                    showToast(`Đã duyệt ${uids.length} thiết bị!`, 'success');
                    if (selectAllCheckbox) selectAllCheckbox.checked = false;
                    fetchDevices();
                } else {
                    const data = await res.json();
                    showToast(data.error || 'Lỗi khi duyệt!', 'error');
                }
            } catch { showToast('Lỗi kết nối!', 'error'); }
        });
    }

    if (bulkDeleteBtn) {
        bulkDeleteBtn.addEventListener('click', async () => {
            const uids = getSelectedUIDs();
            if (uids.length === 0) return;
            const confirmed = await showConfirm('Xoá thiết bị', `Bạn có chắc muốn xoá VĨNH VIỄN ${uids.length} thiết bị?`);
            if (!confirmed) return;
            try {
                const res = await fetch(`${API_BASE}/api/admin/bulk-delete`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': adminToken },
                    body: JSON.stringify({ uids })
                });
                if (res.ok) {
                    showToast(`Đã xoá ${uids.length} thiết bị!`, 'success');
                    if (selectAllCheckbox) selectAllCheckbox.checked = false;
                    fetchDevices();
                } else {
                    const data = await res.json();
                    showToast(data.error || 'Lỗi khi xoá!', 'error');
                }
            } catch { showToast('Lỗi kết nối!', 'error'); }
        });
    }

    // ── Add Device ──
    if (addDeviceBtn) {
        addDeviceBtn.addEventListener('click', () => {
            addUid.value = '';
            addLabel.value = '';
            addExpirySelect.value = '30days';
            addCustomExpiryContainer.style.display = 'none';
            addNote.value = '';
            addModal.style.display = 'flex';
        });
    }

    if (addExpirySelect) {
        addExpirySelect.addEventListener('change', () => {
            if (addExpirySelect.value === 'custom') {
                addCustomExpiryContainer.style.display = 'block';
                const def = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
                const offset = def.getTimezoneOffset();
                addExpiryDate.value = new Date(def.getTime() - offset * 60 * 1000).toISOString().slice(0, 16);
            } else {
                addCustomExpiryContainer.style.display = 'none';
            }
        });
    }

    document.querySelectorAll('.close-add').forEach(el => {
        el.addEventListener('click', () => addModal.style.display = 'none');
    });
    addModal.addEventListener('click', (e) => { if (e.target === addModal) addModal.style.display = 'none'; });

    if (addForm) {
        addForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const uid = addUid.value.trim();
            if (!uid) { showToast('Vui lòng nhập UID!', 'error'); return; }

            const label = addLabel.value.trim();
            const note = addNote.value.trim();
            let expires_at = null;
            const duration = addExpirySelect.value;
            if (duration === '1day') expires_at = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
            else if (duration === '7days') expires_at = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
            else if (duration === '30days') expires_at = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
            else if (duration === 'custom') expires_at = new Date(addExpiryDate.value).toISOString();

            try {
                const res = await fetch(`${API_BASE}/api/admin/create`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'Authorization': adminToken },
                    body: JSON.stringify({ uid, label, expires_at, note })
                });
                if (res.ok) {
                    addModal.style.display = 'none';
                    showToast('Thêm thiết bị thành công!', 'success');
                    fetchDevices();
                } else {
                    const data = await res.json();
                    showToast(data.error || 'Lỗi khi thêm!', 'error');
                }
            } catch { showToast('Lỗi kết nối!', 'error'); }
        });
    }

    // ── Export CSV ──
    if (exportCsvBtn) {
        exportCsvBtn.addEventListener('click', () => {
            window.open(`${API_BASE}/api/admin/export/devices`, '_blank');
            showToast('Đang tải file CSV...', 'success');
        });
    }

    // --- Search & Filter Listeners ---
    searchInput.addEventListener('input', renderDevices);
    statusFilter.addEventListener('change', renderDevices);
    refreshBtn.addEventListener('click', fetchDevices);

    // --- Modal Configuration ---
    function openEditModal(uid) {
        const d = devices.find(x => x.game_id === uid);
        if (!d) return;

        editUid.value = d.game_id;
        editGameId.value = d.game_id;
        editLabel.value = d.label || '';
        editStatus.value = d.status === 'active' ? 'approved' : d.status;
        editNote.value = d.note || '';

        // Handle expiry select init
        if (!d.expires_at) {
            editExpirySelect.value = 'lifetime';
            customExpiryContainer.style.display = 'none';
        } else {
            editExpirySelect.value = 'custom';
            customExpiryContainer.style.display = 'block';
            
            // Format to datetime-local string (YYYY-MM-DDThh:mm)
            const date = new Date(d.expires_at);
            const offset = date.getTimezoneOffset();
            const localDate = new Date(date.getTime() - (offset * 60 * 1000));
            editExpiryDate.value = localDate.toISOString().slice(0, 16);
        }

        editModal.style.display = 'flex';
    }

    // Toggle custom date picker
    editExpirySelect.addEventListener('change', () => {
        if (editExpirySelect.value === 'custom') {
            customExpiryContainer.style.display = 'block';
            // Set default default to +30 days from now
            const defaultDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
            const offset = defaultDate.getTimezoneOffset();
            const localDate = new Date(defaultDate.getTime() - (offset * 60 * 1000));
            editExpiryDate.value = localDate.toISOString().slice(0, 16);
        } else {
            customExpiryContainer.style.display = 'none';
        }
    });

    closeModalBtns.forEach(btn => {
        btn.addEventListener('click', () => editModal.style.display = 'none');
    });

    if (closeScreenshotModal) {
        closeScreenshotModal.addEventListener('click', () => screenshotModal.style.display = 'none');
    }

    window.addEventListener('click', (e) => {
        if (e.target === editModal) editModal.style.display = 'none';
        if (e.target === screenshotModal) screenshotModal.style.display = 'none';
    });

    // Save changes
    editForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const uid = editUid.value;
        const status = editStatus.value;
        const note = editNote.value;
        const label = editLabel.value;
        
        let expires_at = null;
        const duration = editExpirySelect.value;
        if (duration === '1day') {
            expires_at = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
        } else if (duration === '7days') {
            expires_at = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
        } else if (duration === '30days') {
            expires_at = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();
        } else if (duration === 'custom') {
            expires_at = new Date(editExpiryDate.value).toISOString();
        }

        try {
            // If status is approved
            const endpoint = status === 'approved' ? '/api/admin/approve' : '/api/admin/reject';
            const body = { uid, label, note };
            if (status === 'approved') {
                body.expires_at = expires_at;
            }

            const res = await fetch(`${API_BASE}${endpoint}`, {
                method: 'POST',
                headers: { 
                    'Content-Type': 'application/json',
                    'Authorization': adminToken
                },
                body: JSON.stringify(body)
            });

            if (res.ok) {
                editModal.style.display = 'none';
                showToast('Cập nhật bản quyền thành công!', 'success');
                fetchDevices();
            } else {
                const data = await res.json();
                showToast(data.error || 'Lỗi khi cập nhật bản quyền!', 'error');
            }
        } catch (err) {
            showToast('Lỗi kết nối máy chủ!', 'error');
        }
    });

    // Delete device handler
    async function handleDeleteDevice(uid) {
        const confirmed = await showConfirm('Xoá thiết bị', `Bạn có chắc muốn xoá vĩnh viễn thiết bị UID: ${uid}?`);
        if (!confirmed) return;

        try {
            const res = await fetch(`${API_BASE}/api/admin/delete`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': adminToken
                },
                body: JSON.stringify({ uid })
            });

            if (res.ok) {
                showToast('Đã xóa thiết bị thành công.', 'success');
                fetchDevices();
            } else {
                const data = await res.json();
                showToast(data.error || 'Không thể xóa thiết bị!', 'error');
            }
        } catch (err) {
            showToast('Lỗi kết nối máy chủ!', 'error');
        }
    }

    // --- Helpers ---
    function showToast(message, type = 'success') {
        toastElement.textContent = message;
        toastElement.className = `toast show ${type}`;
        setTimeout(() => {
            toastElement.classList.remove('show');
        }, 3000);
    }

    function escapeHtml(str) {
        if (!str) return '';
        return str.replace(/&/g, '&amp;')
                  .replace(/</g, '&lt;')
                  .replace(/>/g, '&gt;')
                  .replace(/"/g, '&quot;')
                  .replace(/'/g, '&#039;');
    }

    // --- Tab Switching ---
    window.switchTab = function(tab) {
        const devPanel = document.getElementById('panel-devices');
        const sesPanel = document.getElementById('panel-sessions');
        const tabDev   = document.getElementById('tab-devices');
        const tabSes   = document.getElementById('tab-sessions');
        if (tab === 'devices') {
            devPanel.style.display = '';
            sesPanel.style.display = 'none';
            tabDev.classList.add('active');
            tabSes.classList.remove('active');
        } else {
            devPanel.style.display = 'none';
            sesPanel.style.display = '';
            tabDev.classList.remove('active');
            tabSes.classList.add('active');
            window.loadSessions();  // Fix: dùng window. để tránh scope issue
        }
    };

    // Hook tab buttons bằng addEventListener (không phụ thuộc inline onclick)
    const tabDevices = document.getElementById('tab-devices');
    if (tabDevices) {
        tabDevices.addEventListener('click', function() { window.switchTab('devices'); });
    }
    const tabSessions = document.getElementById('tab-sessions');
    if (tabSessions) {
        tabSessions.addEventListener('click', function() { window.switchTab('sessions'); });
    }
    const refreshSessionsBtn = document.getElementById('refresh-sessions-btn');
    if (refreshSessionsBtn) {
        refreshSessionsBtn.addEventListener('click', function() { window.loadSessions(); });
    }

    // --- Sessions ---
    window.loadSessions = async function() {
        try {
            const res = await fetch(`${API_BASE}/api/admin/sessions`, {
                headers: { 'Authorization': adminToken }
            });
            if (!res.ok) return;
            allSessions = await res.json();
            renderSessions();
            updateStats();
        } catch (err) {
            console.error('Failed to load sessions', err);
        }
    };

    function renderSessions() {
        const searchEl = document.getElementById('session-search');
        const query = (searchEl ? searchEl.value : '').toLowerCase();
        
        const filterEl = document.getElementById('session-status-filter');
        const filter = filterEl ? filterEl.value : 'all';

        const tbody  = document.getElementById('sessions-tbody');
        const noMsg  = document.getElementById('no-sessions-msg');
        if (!tbody) return;

        const filtered = allSessions.filter(s => {
            const matchQ = String(s.uid || '').toLowerCase().includes(query) ||
                           String(s.player_name || '').toLowerCase().includes(query) ||
                           String(s.match_id || '').toLowerCase().includes(query);
            const matchF = filter === 'all' || s.status === filter;
            return matchQ && matchF;
        });

        if (filtered.length === 0) {
            tbody.innerHTML = '';
            if (noMsg) noMsg.style.display = '';
            return;
        }
        if (noMsg) noMsg.style.display = 'none';

        tbody.innerHTML = filtered.map(s => {
            const startVN  = s.started_at ? new Date(s.started_at).toLocaleString('vi-VN') : '--';
            const endVN    = s.ended_at   ? new Date(s.ended_at).toLocaleString('vi-VN')   : '--';
            const durText  = s.duration_sec != null ? formatDuration(s.duration_sec) : '--';
            const isLive   = s.status === 'in_match';
            const badge    = isLive
                ? `<span class="badge" style="background:rgba(34,211,238,.15);color:#22d3ee;border:1px solid #22d3ee40"><i class="fa-solid fa-person-running"></i> Đang chơi</span>`
                : `<span class="badge" style="background:rgba(100,116,139,.15);color:#94a3b8;border:1px solid #94a3b840"><i class="fa-solid fa-flag-checkered"></i> Đã xong</span>`;
            
            let top1Badge = '';
            if (s.top1) {
                top1Badge = `<span class="badge-victory"><i class="fa-solid fa-trophy"></i> Top 1</span>`;
            }
            
            let screenshotBtn = '--';
            if (s.victory_screenshot) {
                screenshotBtn = `<button class="btn-view-screenshot" data-img="${s.victory_screenshot}"><i class="fa-solid fa-image"></i> Xem ảnh</button>`;
            }

            return `<tr>
                <td><strong>${escapeHtml(s.player_name || 'Unknown')}</strong>${top1Badge}</td>
                <td><code class="code-uid">${escapeHtml(s.uid)}</code></td>
                <td>${escapeHtml(s.match_id || '--')}</td>
                <td><span class="kill-badge">${s.kill_num || 0} Kill</span></td>
                <td>${startVN}</td>
                <td>${endVN}</td>
                <td>${durText}</td>
                <td>${badge}</td>
                <td>${screenshotBtn}</td>
            </tr>`;
        }).join('');

        // Thêm click listener cho nút xem screenshot
        document.querySelectorAll('.btn-view-screenshot').forEach(btn => {
            btn.addEventListener('click', () => {
                screenshotImg.src = btn.dataset.img;
                screenshotModal.style.display = 'flex';
            });
        });
    }

    function formatDuration(sec) {
        if (sec < 60) return sec + 's';
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        if (m < 60) return `${m}m ${s}s`;
        const h = Math.floor(m / 60);
        return `${h}h ${m % 60}m`;
    }

    // Session search/filter live
    const sessionSearchInput = document.getElementById('session-search');
    if (sessionSearchInput) {
        sessionSearchInput.addEventListener('input', renderSessions);
    }
    const sessionStatusFilterInput = document.getElementById('session-status-filter');
    if (sessionStatusFilterInput) {
        sessionStatusFilterInput.addEventListener('change', renderSessions);
    }

    // --- Initialize View ---
    // Moved to the bottom to ensure all functions and event listeners are fully registered first
    if (adminToken) {
        showDashboard();
    } else {
        showLogin();
    }
});

