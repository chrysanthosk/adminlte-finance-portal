
import { Injectable, signal, computed, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { firstValueFrom } from 'rxjs';

export interface IncomeMethod { id: string; name: string; }
export interface ExpenseType { id: string; name: string; }
export interface ExpenseCategory { id: string; name: string; }
export interface Account { id: string; name: string; type: string; currency: string; active: boolean; }

export interface User {
  username: string;
  password?: string;
  role: 'admin' | 'user';
  email: string;
  name?: string;
  surname?: string;
  twoFactorEnabled?: boolean;
  twoFactorSecret?: string;
}

export interface AppSettings {
  companyName: string;
}

export interface SmtpSettings {
  host: string;
  port: number;
  user: string;
  password?: string;
  secure: boolean;
  fromName?: string;
  fromEmail?: string;
}

export interface IncomeEntry {
  id: string;
  date: string;
  lines: { methodId: string; amount: number }[];
  notes: string;
  createdBy: string;
}

export interface ExpenseEntry {
  id: string;
  date: string;
  vendor: string;
  amount: number;
  paymentTypeId: string;
  categoryId: string;
  chequeNo?: string;
  reason?: string;
  attachment?: string;
  createdBy: string;
}

export interface AccountSnapshot {
  id: string;
  month: string;
  balances: { accountId: string; balance: number }[];
  isLocked: boolean;
}

@Injectable({ providedIn: 'root' })
export class StoreService {
  private http: HttpClient = inject(HttpClient);
  private readonly API_URL = '/api'; // Use relative path for Nginx proxy

  // Global Settings
  readonly settings = signal<AppSettings>({ companyName: 'Loading...' });
  readonly smtpSettings = signal<SmtpSettings | undefined>(undefined);

  // Data Signals
  readonly users = signal<User[]>([]);
  readonly incomeMethods = signal<IncomeMethod[]>([]);
  readonly expenseTypes = signal<ExpenseType[]>([]);
  readonly expenseCategories = signal<ExpenseCategory[]>([]);
  readonly accounts = signal<Account[]>([]);
  readonly incomeEntries = signal<IncomeEntry[]>([]);
  readonly expenseEntries = signal<ExpenseEntry[]>([]);
  readonly snapshots = signal<AccountSnapshot[]>([]);

  // Computed Stats
  readonly todayIncome = computed(() => {
    const today = new Date().toISOString().split('T')[0];
    const entry = this.incomeEntries().find(e => e.date === today);
    return entry ? entry.lines.reduce((sum, line) => sum + line.amount, 0) : 0;
  });

  readonly currentMonthStats = computed(() => {
    const now = new Date();
    const currentMonthPrefix = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    
    let income = 0;
    this.incomeEntries().forEach(e => {
      if (e.date.startsWith(currentMonthPrefix)) {
        income += e.lines.reduce((s, l) => s + l.amount, 0);
      }
    });

    let expenses = 0;
    this.expenseEntries().forEach(e => {
      if (e.date.startsWith(currentMonthPrefix)) {
        expenses += e.amount;
      }
    });

    return { income, expenses, profit: income - expenses };
  });

  // --- Data Loading ---
  async loadAll() {
    try {
      const data: any = await firstValueFrom(this.http.get(`${this.API_URL}/loadAll`));
      if (data) {
        this.settings.set(data.settings);
        this.smtpSettings.set(data.smtpSettings);
        this.users.set(data.users || []);
        this.incomeMethods.set(data.incomeMethods || []);
        this.expenseTypes.set(data.expenseTypes || []);
        this.expenseCategories.set(data.expenseCategories || []);
        this.accounts.set(data.accounts || []);
        this.incomeEntries.set(data.incomeEntries || []);
        this.expenseEntries.set(data.expenseEntries || []);
        this.snapshots.set(data.snapshots || []);
      }
    } catch (e) {
      console.error('API call failed. Could not load data.', e);
      alert('Could not connect to the server. Please check your connection and try again.');
    }
  }

  // --- Settings ---
  async updateSettings(newSettings: AppSettings) {
    await this.post('updateSettings', newSettings);
    this.settings.set(newSettings);
  }

  async updateSmtpSettings(settings: SmtpSettings) {
    await this.post('updateSmtp', settings);
    this.smtpSettings.set(settings);
  }

  // --- Users ---
  async addUser(user: User) {
    await this.post('addUser', user);
    this.users.update(u => {
        const idx = u.findIndex(x => x.username === user.username);
        if(idx >= 0) {
            const arr = [...u];
            arr[idx] = { ...arr[idx], ...user };
            return arr;
        }
        return [...u, user];
    });
  }

  async updateUser(user: User) {
    await this.post('updateUser', user);
    this.users.update(users => users.map(u => u.username === user.username ? user : u));
  }

  async removeUser(username: string) {
    await this.post('removeUser', { username });
    this.users.update(u => u.filter(user => user.username !== username));
  }

  // --- Categories/Types ---
  async addIncomeMethod(name: string) {
    const res: any = await this.post('addIncomeMethod', { name });
    this.incomeMethods.update(c => [...c, res]);
  }

  async updateIncomeMethod(id: string, name: string) {
    await this.post('updateIncomeMethod', { id, name });
    this.incomeMethods.update(c => c.map(cat => cat.id === id ? { ...cat, name } : cat));
  }

  async removeIncomeMethod(id: string) {
    await this.post('removeIncomeMethod', { id });
    this.incomeMethods.update(c => c.filter(x => x.id !== id));
  }

  async addExpenseCategory(name: string) {
    const res: any = await this.post('addCategory', { name });
    this.expenseCategories.update(c => [...c, res]);
  }

  async updateExpenseCategory(id: string, name: string) {
    await this.post('updateCategory', { id, name });
    this.expenseCategories.update(c => c.map(cat => cat.id === id ? { ...cat, name } : cat));
  }

  async removeExpenseCategory(id: string) {
    await this.post('removeCategory', { id });
    this.expenseCategories.update(c => c.filter(x => x.id !== id));
  }

  async addExpenseType(name: string) {
    const res: any = await this.post('addType', { name });
    this.expenseTypes.update(t => [...t, res]);
  }

  async updateExpenseType(id: string, name: string) {
    await this.post('updateType', { id, name });
    this.expenseTypes.update(t => t.map(type => type.id === id ? { ...type, name } : type));
  }

  async removeExpenseType(id: string) {
    await this.post('removeType', { id });
    this.expenseTypes.update(t => t.filter(x => x.id !== id));
  }

  // --- Income ---
  async addIncome(entry: Omit<IncomeEntry, 'id'>) {
    const res: any = await this.post('addIncome', entry);
    this.incomeEntries.update(v => [res, ...v]);
  }

  async updateIncome(entry: IncomeEntry) {
    await this.post('updateIncome', entry);
    this.incomeEntries.update(v => v.map(e => e.id === entry.id ? entry : e));
  }

  // --- Expenses ---
  async addExpense(entry: Omit<ExpenseEntry, 'id'>) {
    const res: any = await this.post('addExpense', entry);
    this.expenseEntries.update(v => [res, ...v]);
  }

  async updateExpense(entry: ExpenseEntry) {
    await this.post('updateExpense', entry);
    this.expenseEntries.update(v => v.map(e => e.id === entry.id ? entry : e));
  }

  async removeExpense(id: string) {
    await this.post('removeExpense', { id });
    this.expenseEntries.update(v => v.filter(e => e.id !== id));
  }

  // --- Accounts ---
  async addSnapshot(snapshot: Omit<AccountSnapshot, 'id'>) {
    const res: any = await this.post('addSnapshot', snapshot);
    this.snapshots.update(v => [...v.filter(s => s.month !== snapshot.month), res]);
  }

  async addAccount(account: Omit<Account, 'id'>) {
    const res: any = await this.post('addAccount', account);
    this.accounts.update(v => [...v, res]);
  }

  async updateAccount(account: Account) {
    await this.post('updateAccount', account);
    this.accounts.update(v => v.map(a => a.id === account.id ? account : a));
  }

  private post(action: string, body: any) {
    return firstValueFrom(this.http.post(`${this.API_URL}/${action}`, body));
  }
}
