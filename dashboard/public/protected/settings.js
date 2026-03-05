document.addEventListener('DOMContentLoaded', () => {
  const usersTableBody = document.getElementById('usersBody');
  const addUserForm = document.getElementById('addUserForm');
  const modal = document.getElementById('adminModal');
  const confirmBtn = document.getElementById('confirmAdminBtn');
  const cancelBtn = document.getElementById('cancelAdminBtn');

  let pendingAction = null;

  async function loadUsers() {
    const res = await fetch('/api/users');
    const users = await res.json();

    usersTableBody.innerHTML = '';
    users.forEach(user => {
      const row = document.createElement('tr');

      row.innerHTML = `
        <td>${user.username}</td>
        <td>${user.email}</td>
        <td>${user.role || 'N/A'}</td>
        <td><button class="change-role-btn" data-id="${user.id}" data-current="${user.role}">Change Role</button></td>
      `;

      usersTableBody.appendChild(row);
    });
  }

  usersTableBody.addEventListener('click', (e) => {
    if (e.target.classList.contains('change-role-btn')) {
      const userId = e.target.dataset.id;
      const currentRole = e.target.dataset.current;
      const newRole = currentRole === 'admin' ? 'responder' : 'admin';

      pendingAction = async (adminCred) => {
        const res = await fetch(`/api/users/${userId}/role`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ role: newRole, admin: adminCred })
        });

        const data = await res.json();
        if (res.ok) {
          Swal.fire('Success', 'Role updated!', 'success');
          loadUsers();
        } else {
          Swal.fire('Error', data.error || 'Update failed', 'error');
        }
      };

      showAdminModal();
    }
  });

  addUserForm.addEventListener('submit', (e) => {
    e.preventDefault();

    const newUser = {
      username: document.getElementById('newUsername').value,
      email: document.getElementById('newEmail').value,
      password: document.getElementById('newPassword').value,
      role: document.getElementById('newUserRole').value
    };

    pendingAction = async (adminCred) => {
      const res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...newUser, admin: adminCred })
      });

      const data = await res.json();
      if (res.ok) {
        Swal.fire('User Added', 'New user successfully created.', 'success');
        addUserForm.reset();
        loadUsers();
      } else {
        Swal.fire('Error', data.error || 'Add failed', 'error');
      }
    };

    showAdminModal();
  });

  confirmBtn.addEventListener('click', async () => {
    const adminEmail = document.getElementById('adminEmail').value;
    const adminPassword = document.getElementById('adminPassword').value;

    if (!adminEmail || !adminPassword) {
      return Swal.fire('Error', 'Admin credentials required', 'warning');
    }

    hideAdminModal();
    if (pendingAction) {
      await pendingAction({ email: adminEmail, password: adminPassword });
      pendingAction = null;
    }
  });

  cancelBtn.addEventListener('click', () => {
    hideAdminModal();
    pendingAction = null;
  });

  function showAdminModal() {
    document.getElementById('adminEmail').value = '';
    document.getElementById('adminPassword').value = '';
    modal.classList.remove('hidden');
  }

  function hideAdminModal() {
    modal.classList.add('hidden');
  }

  loadUsers();
});
