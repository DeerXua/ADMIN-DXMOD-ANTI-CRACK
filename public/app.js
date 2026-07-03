document.addEventListener('DOMContentLoaded', () => {
    const API_BASE = ''; // Same origin
    let adminToken = localStorage.getItem('dx_admin_token') || '';
    let devices = [];

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

    const searchInput = document.getElementById('search-input');
    const statusFilter = document.getElementById('status-filter');
    const refreshBtn = document.getElementById('refresh-btn');
    const devicesTbody = document.getElementById('devices-tbody');
    const noDataMsg = document.getElementById('no-data-msg');

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

    const toastElement = document.getElementById('toast');

    // Initialize View
    if (adminToken) {
        showDashboard();
    } else {
        showLogin();
    }

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

        filtered.forEach(d => {
            const isExpired = d.expires_at && new Date(d.expires_at).getTime() < Date.now();
            
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

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>#${d.id}</strong></td>
                <td>${escapeHtml(d.label || 'Chưa đặt tên')}</td>
                <td><code class="code-uid">${escapeHtml(d.game_id)}</code></td>
                <td><span class="status-badge ${statusClass}">${statusText}</span></td>
                <td>${regDate}</td>
                <td><span class="${isExpired ? 'text-red' : ''}">${expiryText}</span></td>
                <td class="note-cell">${escapeHtml(d.note || '-')}</td>
                <td>
                    <div class="actions-cell">
                        <button class="btn-icon edit" data-uid="${escapeHtml(d.game_id)}" title="Sửa bản quyền"><i class="fa-solid fa-pen-to-square"></i></button>
                        <button class="btn-icon delete" data-uid="${escapeHtml(d.game_id)}" title="Xóa thiết bị"><i class="fa-solid fa-trash-can"></i></button>
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

    window.addEventListener('click', (e) => {
        if (e.target === editModal) editModal.style.display = 'none';
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
        if (!confirm(`Bạn có chắc chắn muốn xóa vĩnh viễn thiết bị UID: ${uid} khỏi hệ thống không?`)) {
            return;
        }

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
});
