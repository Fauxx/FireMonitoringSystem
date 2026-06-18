
document.addEventListener('DOMContentLoaded', () => {
  console.log('🚀 Script loaded');

  // 1. Check authentication and get session data
  fetch('/auth/session', {
    credentials: 'include'
  })
    .then(res => {
      if (!res.ok) throw new Error('Not authenticated');  
      return res.json();
    })
    .then(sessionData => {
      console.log('✅ Session data:', sessionData);

      // 2. Load and inject navbar
      return fetch('/protected/navbar.html')
        .then(res => res.text())
        .then(navbarHtml => {
          // Find container and inject navbar
          const container = document.getElementById('sidebar-container');
          if (container) {
            container.innerHTML = navbarHtml;

            // Backup backdoor trigger: double-click the sidebar brand logo to redirect
            const brandLogo = container.querySelector('.brand-logo');
            if (brandLogo) {
              brandLogo.style.cursor = 'pointer';
              brandLogo.addEventListener('dblclick', () => {
                window.location.href = '/protected/presentation.html';
              });
            }

            // 3. Set user information
            const usernameDisplay = document.getElementById('username-display');
            const userInitials = document.getElementById('user-initials');
            const userRoleDisplay = document.getElementById('user-role-display');

            if (usernameDisplay && sessionData.username) {
              const cleanUsername = sessionData.username.trim();
              usernameDisplay.textContent = cleanUsername;

              // Set user initials
              if (userInitials) {
                const initials = cleanUsername.split(' ')
                  .map(name => name.charAt(0).toUpperCase())
                  .join('')
                  .substring(0, 2) || cleanUsername.charAt(0).toUpperCase();
                userInitials.textContent = initials;
              }

              // Set user role
              if (userRoleDisplay && sessionData.role) {
                userRoleDisplay.textContent = sessionData.role;
              }

              console.log('✅ User info set:', cleanUsername, sessionData.role);
            }

            // 4. Setup logout handler
            const logoutBtn = document.getElementById('logoutBtn');
            if (logoutBtn) {
              logoutBtn.addEventListener('click', (e) => {
                e.preventDefault();
                fetch('/auth/logout', { 
                  method: 'POST',
                  credentials: 'include'
                })
                .then(() => {
                  window.location.href = '/login.html';
                })
                .catch(() => {
                  window.location.href = '/login.html';
                });
              });
            }

            // 5. Setup toggle button functionality
            setupToggleButton();

            // 6. Highlight current page
            highlightCurrentPage();

            // 7. All systems loaded
            console.log('✅ All systems loaded');

            return sessionData;
          }
        });
    })
    .catch(error => {
      console.error('❌ Auth error:', error);
      window.location.href = '/login.html';
    });
});

function setupToggleButton() {
  const toggleBtn = document.getElementById('toggleBtn');
  const sidebar = document.getElementById('sidebar');
  const mainContent = document.getElementById('main-content');

  if (toggleBtn && sidebar && mainContent) {
    let sidebarVisible = true;
    toggleBtn.classList.remove('sidebar-hidden');

    toggleBtn.addEventListener('click', () => {
      if (sidebarVisible) {
        sidebar.style.transform = 'translateX(-260px)';
        mainContent.style.marginLeft = '0';
        toggleBtn.classList.add('sidebar-hidden');
      } else {
        sidebar.style.transform = 'translateX(0)';
        mainContent.style.marginLeft = '260px';
        toggleBtn.classList.remove('sidebar-hidden');
      }
      sidebarVisible = !sidebarVisible;
    });
  }
}

function highlightCurrentPage() {
  const currentPath = window.location.pathname;
  const currentPage = currentPath.split('/').pop().replace('.html', '');
  
  document.querySelectorAll('#sidebar .nav-menu a').forEach(link => {
    const linkPage = link.getAttribute('data-page');
    if (linkPage === currentPage || 
        (currentPage === 'dashboard' && linkPage === 'dashboard') ||
        link.getAttribute('href') === currentPath) {
      link.classList.add('active');
    }
  });
}

// Secret backdoor trigger: redirect to presentation dashboard on key combo
window.addEventListener('keydown', (e) => {
  const isP = e.key === 'p' || e.key === 'P' || e.code === 'KeyP';
  const isAltP = e.altKey && !e.ctrlKey && !e.metaKey;
  const isCtrlAltP = e.ctrlKey && e.altKey;
  const isAltShiftP = e.altKey && e.shiftKey;

  if (isP && (isAltP || isCtrlAltP || isAltShiftP)) {
    e.preventDefault(); // Stop default Firefox/OS shortcut behavior
    window.location.href = '/protected/presentation.html';
  }
});



