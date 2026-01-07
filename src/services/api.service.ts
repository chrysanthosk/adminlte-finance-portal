import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { BehaviorSubject, Observable } from 'rxjs';

@Injectable({
  providedIn: 'root'
})
export class ApiService {

  private tokenKey = 'finance_portal_token';
  private tokenSubject = new BehaviorSubject<string | null>(this.getStoredToken());

  constructor(private http: HttpClient) {}

  // ---------------- TOKEN HANDLING ----------------

  private getStoredToken(): string | null {
    return localStorage.getItem(this.tokenKey);
  }

  private storeToken(token: string) {
    localStorage.setItem(this.tokenKey, token);
    this.tokenSubject.next(token);
  }

  clearToken() {
    localStorage.removeItem(this.tokenKey);
    this.tokenSubject.next(null);
  }

  isAuthenticated(): boolean {
    return !!this.tokenSubject.value;
  }

  // ---------------- AUTH ----------------

  login(username: string, password: string): Observable<any> {
    return new Observable(observer => {
      this.http.post<any>('/api/login', { username, password }).subscribe({
        next: (res) => {
          if (res?.success && res.token) {
            this.storeToken(res.token);
          }
          observer.next(res);
          observer.complete();
        },
        error: (err) => observer.error(err)
      });
    });
  }

  logout() {
    this.clearToken();
  }

  // ---------------- CORE API ----------------

  loadAll(): Observable<any> {
    return this.http.get('/api/loadAll', {
      headers: this.authHeaders()
    });
  }

  action(action: string, payload: any = {}): Observable<any> {
    return this.http.post(`/api/${action}`, payload, {
      headers: this.authHeaders()
    });
  }

  // ---------------- HELPERS ----------------

  private authHeaders(): HttpHeaders {
    const token = this.tokenSubject.value;
    let headers = new HttpHeaders({
      'Content-Type': 'application/json'
    });

    if (token) {
      headers = headers.set('Authorization', `Bearer ${token}`);
    }

    return headers;
  }
}