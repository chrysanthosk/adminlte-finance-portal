// src/services/auth.service.ts
import { Injectable, signal, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ApiService } from './api.service';
import { User } from './store.service';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private api = inject(ApiService);
  private router = inject(Router) as Router;
  
  currentUser = signal<User | null>(null);

  constructor() {
    // Try to restore session from localStorage
    const stored = localStorage.getItem('currentUser');
    if (stored) {
      try {
        this.currentUser.set(JSON.parse(stored));
      } catch (e) {
        console.error('Failed to restore user session', e);
      }
    }
  }

  // Validates credentials via API
  validateCredentials(username: string, password: string): Promise<User | null> {
    return new Promise((resolve) => {
      this.api.login(username, password).subscribe({
        next: (response) => {
          if (response.success && response.user) {
            resolve(response.user);
          } else {
            resolve(null);
          }
        },
        error: (error) => {
          console.error('Login error:', error);
          resolve(null);
        }
      });
    });
  }

  // Finalizes login and saves session
  completeLogin(user: User) {
    this.currentUser.set(user);
    localStorage.setItem('currentUser', JSON.stringify(user));
    this.router.navigate(['/']);
  }

  // Old method for compatibility
  async login(username: string, password: string): Promise<boolean> {
    const user = await this.validateCredentials(username, password);
    if (user && !user.twoFactorEnabled) {
      this.completeLogin(user);
      return true;
    }
    return false;
  }

  // Update current user (for profile changes)
  updateCurrentUser(user: User) {
    this.currentUser.set(user);
    localStorage.setItem('currentUser', JSON.stringify(user));
    
    // Also update in backend
    this.api.updateUser(user).subscribe({
      next: () => console.log('User updated in database'),
      error: (error) => console.error('Failed to update user:', error)
    });
  }

  logout() {
    this.currentUser.set(null);
    localStorage.removeItem('currentUser');
    this.router.navigate(['/login']);
  }

  isAuthenticated() {
    return this.currentUser() !== null;
  }

  isAdmin() {
    return this.currentUser()?.role === 'admin';
  }
}
