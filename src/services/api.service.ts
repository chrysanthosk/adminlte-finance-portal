// src/services/api.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../environments/environment';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private http = inject(HttpClient);
  private baseUrl = environment.apiUrl;

  private handleError(error: any) {
    console.error('API Error:', error);
    return throwError(() => error);
  }

  // ==================== AUTH ====================
  login(username: string, password: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/auth.php/login`, { username, password })
      .pipe(catchError(this.handleError));
  }

  verify2FA(code: string): Observable<any> {
    return this.http.post(`${this.baseUrl}/auth.php/verify-2fa`, { code })
      .pipe(catchError(this.handleError));
  }

  // ==================== USERS ====================
  getUsers(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/users.php`)
      .pipe(catchError(this.handleError));
  }

  createUser(user: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/users.php`, user)
      .pipe(catchError(this.handleError));
  }

  updateUser(user: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/users.php`, user)
      .pipe(catchError(this.handleError));
  }

  deleteUser(username: string): Observable<any> {
    return this.http.delete(`${this.baseUrl}/users.php`, { body: { username } })
      .pipe(catchError(this.handleError));
  }

  // ==================== INCOME ====================
  getIncome(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/income.php`)
      .pipe(catchError(this.handleError));
  }

  createIncome(entry: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/income.php`, entry)
      .pipe(catchError(this.handleError));
  }

  updateIncome(entry: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/income.php`, entry)
      .pipe(catchError(this.handleError));
  }

  deleteIncome(id: number): Observable<any> {
    return this.http.delete(`${this.baseUrl}/income.php`, { body: { id } })
      .pipe(catchError(this.handleError));
  }

  // ==================== EXPENSES ====================
  getExpenses(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/expenses.php`)
      .pipe(catchError(this.handleError));
  }

  createExpense(entry: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/expenses.php`, entry)
      .pipe(catchError(this.handleError));
  }

  updateExpense(entry: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/expenses.php`, entry)
      .pipe(catchError(this.handleError));
  }

  deleteExpense(id: number): Observable<any> {
    return this.http.delete(`${this.baseUrl}/expenses.php`, { body: { id } })
      .pipe(catchError(this.handleError));
  }

  // ==================== ACCOUNTS ====================
  getAccounts(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/accounts.php`)
      .pipe(catchError(this.handleError));
  }

  createAccount(account: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/accounts.php`, account)
      .pipe(catchError(this.handleError));
  }

  updateAccount(account: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/accounts.php`, account)
      .pipe(catchError(this.handleError));
  }

  deleteAccount(id: number): Observable<any> {
    return this.http.delete(`${this.baseUrl}/accounts.php`, { body: { id } })
      .pipe(catchError(this.handleError));
  }

  // ==================== SNAPSHOTS ====================
  getSnapshots(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/snapshots.php`)
      .pipe(catchError(this.handleError));
  }

  createSnapshot(snapshot: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/snapshots.php`, snapshot)
      .pipe(catchError(this.handleError));
  }

  // ==================== INCOME METHODS ====================
  getIncomeMethods(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/income-methods.php`)
      .pipe(catchError(this.handleError));
  }

  createIncomeMethod(method: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/income-methods.php`, method)
      .pipe(catchError(this.handleError));
  }

  updateIncomeMethod(method: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/income-methods.php`, method)
      .pipe(catchError(this.handleError));
  }

  deleteIncomeMethod(id: number): Observable<any> {
    return this.http.delete(`${this.baseUrl}/income-methods.php`, { body: { id } })
      .pipe(catchError(this.handleError));
  }

  // ==================== EXPENSE TYPES ====================
  getExpenseTypes(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/expense-types.php`)
      .pipe(catchError(this.handleError));
  }

  createExpenseType(type: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/expense-types.php`, type)
      .pipe(catchError(this.handleError));
  }

  updateExpenseType(type: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/expense-types.php`, type)
      .pipe(catchError(this.handleError));
  }

  deleteExpenseType(id: number): Observable<any> {
    return this.http.delete(`${this.baseUrl}/expense-types.php`, { body: { id } })
      .pipe(catchError(this.handleError));
  }

  // ==================== EXPENSE CATEGORIES ====================
  getExpenseCategories(): Observable<any[]> {
    return this.http.get<any[]>(`${this.baseUrl}/expense-categories.php`)
      .pipe(catchError(this.handleError));
  }

  createExpenseCategory(category: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/expense-categories.php`, category)
      .pipe(catchError(this.handleError));
  }

  updateExpenseCategory(category: any): Observable<any> {
    return this.http.put(`${this.baseUrl}/expense-categories.php`, category)
      .pipe(catchError(this.handleError));
  }

  deleteExpenseCategory(id: number): Observable<any> {
    return this.http.delete(`${this.baseUrl}/expense-categories.php`, { body: { id } })
      .pipe(catchError(this.handleError));
  }

  // ==================== SETTINGS ====================
  getSettings(): Observable<any> {
    return this.http.get(`${this.baseUrl}/settings.php`)
      .pipe(catchError(this.handleError));
  }

  updateSettings(settings: any): Observable<any> {
    return this.http.post(`${this.baseUrl}/settings.php`, settings)
      .pipe(catchError(this.handleError));
  }
}
