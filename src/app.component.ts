import { Component, inject } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';
import { AuthService } from './services/auth.service';
import { StoreService } from './services/store.service';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './app.component.html'
})
export class AppComponent {
  auth = inject(AuthService);
  store = inject(StoreService);

  isSidebarOpen = true;
  isDarkMode = false;

  private readonly LS_DARK = 'finance_portal_dark_mode';
  private readonly LS_SIDEBAR = 'finance_portal_sidebar_open';

  constructor() {
    // Restore persisted UI state (if any)
    const storedDark = localStorage.getItem(this.LS_DARK);
    const storedSidebar = localStorage.getItem(this.LS_SIDEBAR);

    if (storedSidebar !== null) {
      this.isSidebarOpen = storedSidebar === 'true';
    }

    // Dark mode: prefer saved value, fallback to current DOM class
    if (storedDark !== null) {
      this.isDarkMode = storedDark === 'true';
    } else {
      this.isDarkMode = document.documentElement.classList.contains('dark');
    }

    this.applyDarkModeClass(this.isDarkMode);
  }

  toggleSidebar() {
    this.isSidebarOpen = !this.isSidebarOpen;
    localStorage.setItem(this.LS_SIDEBAR, String(this.isSidebarOpen));
  }

  toggleDarkMode() {
    this.isDarkMode = !this.isDarkMode;
    localStorage.setItem(this.LS_DARK, String(this.isDarkMode));
    this.applyDarkModeClass(this.isDarkMode);
  }

  private applyDarkModeClass(enabled: boolean) {
    if (enabled) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }
}