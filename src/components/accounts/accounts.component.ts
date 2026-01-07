
import { Component, inject, signal } from '@angular/core';
import { CommonModule, CurrencyPipe } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, FormArray, Validators } from '@angular/forms';
import { StoreService, Account } from '../../services/store.service';

@Component({
  selector: 'app-accounts',
  imports: [CommonModule, ReactiveFormsModule, CurrencyPipe],
  template: `
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Snapshots Card -->
      <div class="card card-warning bg-white dark:bg-gray-800 rounded shadow border-t-4 border-yellow-500 dark:border-yellow-600 transition-colors">
        <div class="card-header p-4 border-b dark:border-gray-700">
          <h3 class="card-title text-lg font-medium dark:text-gray-100">Monthly Snapshot</h3>
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">Capture account balances for the 1st of the month.</p>
        </div>
        <div class="card-body p-4">
          <form [formGroup]="snapshotForm" (ngSubmit)="onSubmitSnapshot()">
            <div class="mb-4">
              <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-2">Month</label>
              <input type="month" formControlName="month" class="shadow border dark:border-gray-600 rounded w-full py-2 px-3 text-gray-700 bg-white dark:bg-gray-700 dark:text-white focus:outline-none">
            </div>

            <div formArrayName="balances" class="space-y-3 mb-4">
              @for (account of store.accounts(); track account.id; let i = $index) {
                <div [formGroupName]="i" class="flex items-center justify-between p-2 bg-gray-50 dark:bg-gray-700 rounded">
                  <span class="text-sm font-medium text-gray-700 dark:text-gray-200 w-1/3">{{ account.name }}</span>
                  <div class="relative w-1/2">
                    <span class="absolute inset-y-0 left-0 pl-2 flex items-center text-gray-500">€</span>
                    <input type="number" formControlName="balance" class="pl-6 w-full shadow-sm border dark:border-gray-600 rounded py-1 px-2 text-sm bg-white dark:bg-gray-600 text-gray-900 dark:text-white focus:ring-1 focus:ring-yellow-500">
                  </div>
                </div>
              }
            </div>

            <button type="submit" class="w-full bg-yellow-500 hover:bg-yellow-600 text-white font-bold py-2 px-4 rounded focus:outline-none transition">
              Save Snapshot
            </button>
          </form>
        </div>
      </div>

      <!-- Accounts List & Management -->
      <div class="space-y-6">
        <!-- Add/Edit Account Form -->
        <div class="card bg-white dark:bg-gray-800 rounded shadow border-t-4 border-indigo-600 dark:border-indigo-500 transition-colors">
           <div class="card-header p-4 border-b dark:border-gray-700 flex justify-between items-center">
             <h3 class="card-title text-lg font-medium dark:text-gray-100">{{ editingAccount() ? 'Edit Account' : 'Add New Account' }}</h3>
              @if(editingAccount()) {
                <button (click)="cancelEdit()" class="text-xs text-red-500 hover:text-red-700">Cancel</button>
              }
           </div>
           <div class="card-body p-4">
             <form [formGroup]="accountForm" (ngSubmit)="onSubmitAccount()">
               <div class="mb-3">
                 <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Account Name</label>
                 <input type="text" formControlName="name" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 text-gray-700 bg-white dark:bg-gray-700 dark:text-white leading-tight focus:outline-none focus:shadow-outline">
               </div>
               <div class="grid grid-cols-2 gap-3 mb-3">
                 <div>
                    <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Type</label>
                    <select formControlName="type" class="shadow border dark:border-gray-600 rounded w-full py-2 px-3 text-gray-700 bg-white dark:bg-gray-700 dark:text-white leading-tight focus:outline-none focus:shadow-outline">
                      <option value="Bank">Bank</option>
                      <option value="Wallet">Wallet</option>
                      <option value="Card">Card</option>
                      <option value="Cash">Cash</option>
                    </select>
                 </div>
                 <div>
                    <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Currency</label>
                    <select formControlName="currency" class="shadow border dark:border-gray-600 rounded w-full py-2 px-3 text-gray-700 bg-white dark:bg-gray-700 dark:text-white leading-tight focus:outline-none focus:shadow-outline">
                      <option value="EUR">EUR</option>
                      <option value="USD">USD</option>
                      <option value="GBP">GBP</option>
                    </select>
                 </div>
               </div>
               <div class="flex items-center mb-4">
                  <input type="checkbox" formControlName="active" class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600">
                  <label class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300">Active</label>
               </div>
               <div class="flex justify-end">
                  <button type="submit" [disabled]="accountForm.invalid" class="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline transition">
                    {{ editingAccount() ? 'Update Account' : 'Create Account' }}
                  </button>
               </div>
             </form>
           </div>
        </div>

        <!-- List -->
        <div class="card bg-white dark:bg-gray-800 rounded shadow border-t-4 border-gray-600 dark:border-gray-500 transition-colors">
          <div class="card-header p-4 border-b dark:border-gray-700">
            <h3 class="card-title text-lg font-medium dark:text-gray-100">Active Accounts</h3>
          </div>
          <div class="card-body p-0">
            <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
              <thead class="text-xs text-gray-700 dark:text-gray-200 uppercase bg-gray-50 dark:bg-gray-700">
                <tr>
                  <th class="px-4 py-3">Name</th>
                  <th class="px-4 py-3">Type</th>
                  <th class="px-4 py-3">Currency</th>
                  <th class="px-4 py-3">Status</th>
                  <th class="px-4 py-3 text-center">Action</th>
                </tr>
              </thead>
              <tbody>
                @for (acc of store.accounts(); track acc.id) {
                  <tr class="bg-white dark:bg-gray-800 border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700">
                    <td class="px-4 py-3 font-medium text-gray-900 dark:text-gray-100">{{ acc.name }}</td>
                    <td class="px-4 py-3">{{ acc.type }}</td>
                    <td class="px-4 py-3">{{ acc.currency }}</td>
                    <td class="px-4 py-3">
                      @if(acc.active) {
                         <span class="px-2 py-1 text-xs font-semibold leading-tight text-green-700 bg-green-100 dark:bg-green-900 dark:text-green-300 rounded-full">Active</span>
                      } @else {
                         <span class="px-2 py-1 text-xs font-semibold leading-tight text-gray-700 bg-gray-100 dark:bg-gray-600 dark:text-gray-300 rounded-full">Inactive</span>
                      }
                    </td>
                    <td class="px-4 py-3 text-center">
                       <button (click)="editAccount(acc)" class="text-indigo-600 dark:text-indigo-400 hover:underline">Edit</button>
                    </td>
                  </tr>
                }
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  `
})
export class AccountsComponent {
  store = inject(StoreService);
  fb: FormBuilder = inject(FormBuilder);

  // Edit State
  editingAccount = signal<Account | null>(null);

  snapshotForm = this.fb.group({
    month: [new Date().toISOString().slice(0, 7), Validators.required],
    balances: this.fb.array([])
  });

  accountForm = this.fb.group({
    name: ['', Validators.required],
    type: ['Bank', Validators.required],
    currency: ['EUR', Validators.required],
    active: [true]
  });

  constructor() {
    this.initSnapshotForm();
  }

  initSnapshotForm() {
    const arr = this.snapshotForm.get('balances') as FormArray;
    arr.clear();
    this.store.accounts().forEach((acc: Account) => {
      arr.push(this.fb.group({
        accountId: [acc.id],
        balance: [0]
      }));
    });
  }

  // Account Management
  editAccount(acc: Account) {
    this.editingAccount.set(acc);
    this.accountForm.patchValue({
      name: acc.name,
      type: acc.type,
      currency: acc.currency,
      active: acc.active
    });
  }

  cancelEdit() {
    this.editingAccount.set(null);
    this.accountForm.reset({
      type: 'Bank',
      currency: 'EUR',
      active: true
    });
  }

  onSubmitAccount() {
    if (this.accountForm.valid) {
      const val = this.accountForm.value;
      const accountData = {
        name: val.name!,
        type: val.type!,
        currency: val.currency!,
        active: val.active!
      };

      if (this.editingAccount()) {
        this.store.updateAccount({
          ...accountData,
          id: this.editingAccount()!.id
        });
        this.cancelEdit();
      } else {
        this.store.addAccount(accountData);
        this.accountForm.reset({
           type: 'Bank',
           currency: 'EUR',
           active: true
        });
        // Re-init snapshot form to include new account
        this.initSnapshotForm();
      }
    }
  }

  // Snapshot
  onSubmitSnapshot() {
    if (this.snapshotForm.valid) {
      const val = this.snapshotForm.value;
      const monthDate = val.month + '-01'; 
      
      const balances = (val.balances as any[]).map(b => ({
        accountId: b.accountId,
        balance: b.balance
      }));

      this.store.addSnapshot({
        month: monthDate,
        balances: balances,
        isLocked: true
      });
      
      alert('Snapshot saved successfully!');
    }
  }
}