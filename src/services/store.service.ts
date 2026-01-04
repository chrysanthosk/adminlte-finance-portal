// src/services/store.service.ts
import { Injectable, signal, computed, inject } from '@angular/core';
import { ApiService } from './api.service';

export interface IncomeMethod { id: number; name: string; }
export interface ExpenseType { id: number; name: string; }
export interface ExpenseCategory { id: number; name: string; }
export interface Account { id: number; name: string; type: string; currency: string; active: boolean; }

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
  id: number | string;
  date: string;
  lines: { methodId: number; amount: number }[];
  notes: string;
  createdBy: string;
}

export interface ExpenseEntry {
  id: number | string;
  date: string;
  vendor: string;
  amount: number;
  paymentTypeId: number;
  categoryId: number;
  chequeNo?: string;
  reason?: string;
  attachment?: string;
  createdBy: string;
}

export interface AccountSnapshot {
  id: number | string;
  month: string;
  balances: { accountId: number; balance: number }[];
  isLocked: boolean;
}

@Injectable({ providedIn: 'root' })
export class StoreService {
  private api = inject(ApiService);

  // Settings
  readonly settings = signal<AppSettings>({
    companyName: 'AdminLTE Finance'
  });

  readonly smtpSettings = signal<SmtpSettings>({
    host: 'smtp.example.com',
    port: 587,
    user: '',
    password: '',
    secure: true,
    fromName: 'Finance Portal',
    fromEmail: 'noreply@finance.com'
  });

  // Users
  readonly users = signal<User[]>([]);

  // Configuration
  readonly incomeMethods = signal<IncomeMethod[]>([]);
  readonly expenseTypes = signal<ExpenseType[]>([]);
  readonly expenseCategories = signal<ExpenseCategory[]>([]);
  readonly accounts = signal<Account[]>([]);

  // Data
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

  constructor() {
    this.loadAllData();
  }

  // ==================== LOAD ALL DATA ====================
  loadAllData() {
    this.loadSettings();
    this.loadUsers();
    this.loadIncomeMethods();
    this.loadExpenseTypes();
    this.loadExpenseCategories();
    this.loadAccounts();
    this.loadIncomeEntries();
    this.loadExpenseEntries();
    this.loadSnapshots();
  }

  // ==================== SETTINGS ====================
  loadSettings() {
    this.api.getSettings().subscribe({
      next: (data) => {
        this.settings.set({ companyName: data.companyName });
        if (data.smtpSettings) {
          this.smtpSettings.set(data.smtpSettings);
        }
      },
      error: (error) => console.error('Failed to load settings:', error)
    });
  }

  updateSettings(newSettings: AppSettings) {
    this.settings.set(newSettings);
    this.api.updateSettings({ companyName: newSettings.companyName }).subscribe({
      error: (error) => console.error('Failed to update settings:', error)
    });
  }

  updateSmtpSettings(settings: SmtpSettings) {
    this.smtpSettings.set(settings);
    this.api.updateSettings({ smtpSettings: settings }).subscribe({
      error: (error) => console.error('Failed to update SMTP settings:', error)
    });
  }

  // ==================== USERS ====================
  loadUsers() {
    this.api.getUsers().subscribe({
      next: (users) => this.users.set(users),
      error: (error) => console.error('Failed to load users:', error)
    });
  }

  addUser(user: User) {
    this.api.createUser(user).subscribe({
      next: () => this.loadUsers(),
      error: (error) => console.error('Failed to add user:', error)
    });
  }

  updateUser(user: User) {
    this.api.updateUser(user).subscribe({
      next: () => this.loadUsers(),
      error: (error) => console.error('Failed to update user:', error)
    });
  }

  removeUser(username: string) {
    this.api.deleteUser(username).subscribe({
      next: () => this.loadUsers(),
      error: (error) => console.error('Failed to delete user:', error)
    });
  }

  // ==================== INCOME METHODS ====================
  loadIncomeMethods() {
    this.api.getIncomeMethods().subscribe({
      next: (methods) => this.incomeMethods.set(methods),
      error: (error) => console.error('Failed to load income methods:', error)
    });
  }

  // ==================== EXPENSE TYPES ====================
  loadExpenseTypes() {
    this.api.getExpenseTypes().subscribe({
      next: (types) => this.expenseTypes.set(types),
      error: (error) => console.error('Failed to load expense types:', error)
    });
  }

  addExpenseType(name: string) {
    this.api.createExpenseType({ name }).subscribe({
      next: () => this.loadExpenseTypes(),
      error: (error) => console.error('Failed to add expense type:', error)
    });
  }

  updateExpenseType(id: number, name: string) {
    this.api.updateExpenseType({ id, name }).subscribe({
      next: () => this.loadExpenseTypes(),
      error: (error) => console.error('Failed to update expense type:', error)
    });
  }

  removeExpenseType(id: number) {
    this.api.deleteExpenseType(id).subscribe({
      next: () => this.loadExpenseTypes(),
      error: (error) => console.error('Failed to delete expense type:', error)
    });
  }

  // ==================== EXPENSE CATEGORIES ====================
  loadExpenseCategories() {
    this.api.getExpenseCategories().subscribe({
      next: (categories) => this.expenseCategories.set(categories),
      error: (error) => console.error('Failed to load expense categories:', error)
    });
  }

  addExpenseCategory(name: string) {
    this.api.createExpenseCategory({ name }).subscribe({
      next: () => this.loadExpenseCategories(),
      error: (error) => console.error('Failed to add expense category:', error)
    });
  }

  updateExpenseCategory(id: number, name: string) {
    this.api.updateExpenseCategory({ id, name }).subscribe({
      next: () => this.loadExpenseCategories(),
      error: (error) => console.error('Failed to update expense category:', error)
    });
  }

  removeExpenseCategory(id: number) {
    this.api.deleteExpenseCategory(id).subscribe({
      next: () => this.loadExpenseCategories(),
      error: (error) => console.error('Failed to delete expense category:', error)
    });
  }

  // ==================== ACCOUNTS ====================
  loadAccounts() {
    this.api.getAccounts().subscribe({
      next: (accounts) => this.accounts.set(accounts),
      error: (error) => console.error('Failed to load accounts:', error)
    });
  }

  addAccount(account: Omit<Account, 'id'>) {
    this.api.createAccount(account).subscribe({
      next: () => this.loadAccounts(),
      error: (error) => console.error('Failed to add account:', error)
    });
  }

  updateAccount(account: Account) {
    this.api.updateAccount(account).subscribe({
      next: () => this.loadAccounts(),
      error: (error) => console.error('Failed to update account:', error)
    });
  }

  // ==================== INCOME ENTRIES ====================
  loadIncomeEntries() {
    this.api.getIncome().subscribe({
      next: (entries) => this.incomeEntries.set(entries),
      error: (error) => console.error('Failed to load income:', error)
    });
  }

  addIncome(entry: Omit<IncomeEntry, 'id'>) {
    this.api.createIncome(entry).subscribe({
      next: () => this.loadIncomeEntries(),
      error: (error) => console.error('Failed to add income:', error)
    });
  }

  updateIncome(entry: IncomeEntry) {
    this.api.updateIncome(entry).subscribe({
      next: () => this.loadIncomeEntries(),
      error: (error) => console.error('Failed to update income:', error)
    });
  }

  // ==================== EXPENSE ENTRIES ====================
  loadExpenseEntries() {
    this.api.getExpenses().subscribe({
      next: (entries) => this.expenseEntries.set(entries),
      error: (error) => console.error('Failed to load expenses:', error)
    });
  }

  addExpense(entry: Omit<ExpenseEntry, 'id'>) {
    this.api.createExpense(entry).subscribe({
      next: () => this.loadExpenseEntries(),
      error: (error) => console.error('Failed to add expense:', error)
    });
  }

  updateExpense(entry: ExpenseEntry) {
    this.api.updateExpense(entry).subscribe({
      next: () => this.loadExpenseEntries(),
      error: (error) => console.error('Failed to update expense:', error)
    });
  }

  removeExpense(id: number | string) {
    this.api.deleteExpense(Number(id)).subscribe({
      next: () => this.loadExpenseEntries(),
      error: (error) => console.error('Failed to delete expense:', error)
    });
  }

  // ==================== SNAPSHOTS ====================
  loadSnapshots() {
    this.api.getSnapshots().subscribe({
      next: (snapshots) => this.snapshots.set(snapshots),
      error: (error) => console.error('Failed to load snapshots:', error)
    });
  }

  addSnapshot(snapshot: Omit<AccountSnapshot, 'id'>) {
    this.api.createSnapshot(snapshot).subscribe({
      next: () => {
        this.loadSnapshots();
        alert('Snapshot saved successfully!');
      },
      error: (error) => console.error('Failed to add snapshot:', error)
    });
  }
}
