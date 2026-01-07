
import { Injectable, signal, inject, computed } from '@angular/core';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { StoreService, User } from './store.service';
import { firstValueFrom } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private store = inject(StoreService);
  private router = inject(Router) as Router;
  private http: HttpClient = inject(HttpClient);

  currentUser = signal<User | null>(null);

  isAuthenticated = computed(() => this.currentUser() !== null);
  isAdmin = computed(() => this.currentUser()?.role === 'admin');

  // Checks credentials via API
  async validateCredentials(username: string, password: string): Promise<User | null> {
    try {
      const response: any = await firstValueFrom(this.http.post('/api/login', { username, password }));
      if (response && response.success) {
        return response.user;
      }
      return null;
    } catch (e) {
      console.error('Login API call failed', e);
      throw e;
    }
  }

  // Finalizes login
  completeLogin(user: User) {
      this.currentUser.set(user);
      this.store.loadAll(); // Reload data for the logged in user context
      this.router.navigate(['/']);
  }

  async updateCurrentUser(user: User) {
    await this.store.updateUser(user);
    this.currentUser.set(user);
  }

  logout() {
    this.currentUser.set(null);
    this.router.navigate(['/login']);
  }
}