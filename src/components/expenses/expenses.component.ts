import { Component, inject, signal, computed } from '@angular/core';
import { CommonModule, CurrencyPipe } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators, FormsModule } from '@angular/forms';
import { StoreService, ExpenseEntry } from '../../services/store.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-expenses',
  imports: [CommonModule, ReactiveFormsModule, CurrencyPipe, FormsModule],
  template: `
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-1">
        <div class="card card-danger bg-white dark:bg-gray-800 rounded shadow border-t-4 border-red-600 dark:border-red-500 transition-colors">
          <div class="card-header p-4 border-b dark:border-gray-700 flex justify-between items-center">
            <h3 class="card-title text-lg font-medium dark:text-gray-100">{{ editingId() ? 'Edit Expense' : 'Add Expense' }}</h3>
             @if(editingId()) {
              <button (click)="cancelEdit()" class="text-xs text-red-500 hover:text-red-700">Cancel</button>
            }
          </div>
          <div class="card-body p-4">
            <form [formGroup]="expenseForm" (ngSubmit)="onSubmit()">
              <div class="mb-3">
                <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Vendor / Name</label>
                <input type="text" formControlName="vendor" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
              </div>

              <div class="grid grid-cols-2 gap-2 mb-3">
                <div>
                  <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Date</label>
                  <input type="date" formControlName="date" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
                </div>
                <div>
                  <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Amount</label>
                  <input type="number" formControlName="amount" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
                </div>
              </div>

              <div class="grid grid-cols-2 gap-2 mb-3">
                <div>
                  <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Category</label>
                  <select formControlName="categoryId" class="shadow border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
                    @for (cat of store.expenseCategories(); track cat.id) {
                      <option [value]="cat.id">{{ cat.name }}</option>
                    }
                  </select>
                </div>
                <div>
                  <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Payment</label>
                  <select formControlName="paymentTypeId" class="shadow border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
                    @for (type of store.expenseTypes(); track type.id) {
                      <option [value]="type.id">{{ type.name }}</option>
                    }
                  </select>
                </div>
              </div>

              @if (isCheque()) {
                <div class="mb-3">
                  <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Cheque No</label>
                  <input type="text" formControlName="chequeNo" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
                </div>
              }

              <div class="mb-3">
                <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Reason</label>
                <textarea formControlName="reason" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100" rows="2"></textarea>
              </div>
              
              <div class="mb-4">
                <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-1">Attachment</label>
                 <input type="file" (change)="onFileChange($event)" class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 dark:text-gray-300 dark:file:bg-blue-900 dark:file:text-blue-200"/>
                 @if(editingId() && currentAttachment) {
                   <p class="text-xs text-green-600 mt-1">Existing attachment present. Upload new to replace.</p>
                 }
              </div>

              <div class="flex justify-end">
                <button type="submit" [disabled]="expenseForm.invalid" class="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline transition disabled:opacity-50">
                   {{ editingId() ? 'Update Expense' : 'Save Expense' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <div class="lg:col-span-2">
        <div class="card bg-white dark:bg-gray-800 rounded shadow border-t-4 border-gray-600 dark:border-gray-500 transition-colors">
          <div class="card-header p-4 border-b dark:border-gray-700 flex flex-wrap gap-4 justify-between items-center">
            <h3 class="card-title text-lg font-medium dark:text-gray-100">Expense History</h3>
            <div class="flex items-center gap-2">
              <label class="text-sm text-gray-600 dark:text-gray-400">Filter Month:</label>
              <input type="month" [ngModel]="filterMonth()" (ngModelChange)="setFilterMonth($event)" class="text-sm border dark:border-gray-600 rounded px-2 py-1 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
            </div>
          </div>
          <div class="card-body p-0">
            <div class="overflow-x-auto">
              <table class="w-full text-sm text-left text-gray-500 dark:text-gray-400">
                <thead class="text-xs text-gray-700 dark:text-gray-200 uppercase bg-gray-50 dark:bg-gray-700">
                  <tr>
                    <th class="px-4 py-3">Date</th>
                    <th class="px-4 py-3">Vendor</th>
                    <th class="px-4 py-3">Reason</th>
                    <th class="px-4 py-3">Cat</th>
                    <th class="px-4 py-3">Type</th>
                    <th class="px-4 py-3 text-right">Amount</th>
                    <th class="px-4 py-3 text-center">Receipt</th>
                    <th class="px-4 py-3 text-center">Action</th>
                  </tr>
                </thead>
                <tbody>
                  @for (entry of filteredEntries(); track entry.id) {
                    <tr class="bg-white dark:bg-gray-800 border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
                      <td class="px-4 py-3 whitespace-nowrap">{{ entry.date }}</td>
                      <td class="px-4 py-3 font-medium text-gray-900 dark:text-gray-100">{{ entry.vendor }}</td>
                      <td class="px-4 py-3 text-xs truncate max-w-[150px]" [title]="entry.reason || ''">{{ entry.reason || '-' }}</td>
                      <td class="px-4 py-3 text-xs">
                        <span class="bg-gray-100 dark:bg-gray-600 text-gray-800 dark:text-gray-200 px-2 py-0.5 rounded border border-gray-200 dark:border-gray-500">
                           {{ getCategoryName(entry.categoryId) }}
                        </span>
                      </td>
                      <td class="px-4 py-3 text-xs">{{ getTypeName(entry.paymentTypeId) }}</td>
                      <td class="px-4 py-3 text-right font-bold text-red-600 dark:text-red-400">
                        {{ entry.amount | currency:'EUR' }}
                      </td>
                      <td class="px-4 py-3 text-center">
                        @if(entry.attachment) {
                          <a [href]="entry.attachment" download="receipt.png" class="text-blue-600 hover:text-blue-800" title="Download Receipt">
                             📎
                          </a>
                        } @else {
                          <span class="text-gray-300">-</span>
                        }
                      </td>
                      <td class="px-4 py-3 text-center">
                         @if (deleteConfirmation() === entry.id) {
                            <div class="flex items-center justify-center gap-2 animate-pulse">
                                <button (click)="performDelete(entry)" class="text-white bg-red-600 hover:bg-red-700 px-2 py-0.5 rounded text-xs font-bold shadow-sm transition-colors">Confirm</button>
                                <button (click)="deleteConfirmation.set(null)" class="text-gray-500 hover:text-gray-700 text-xs transition-colors">Cancel</button>
                            </div>
                         } @else {
                            <div class="flex items-center justify-center gap-2">
                               <button (click)="edit(entry)" class="text-blue-600 dark:text-blue-400 hover:underline">Edit</button>
                               <button (click)="deleteConfirmation.set(entry.id)" class="text-red-600 dark:text-red-400 hover:underline">Delete</button>
                            </div>
                         }
                      </td>
                    </tr>
                  } @empty {
                    <tr>
                      <td colspan="10" class="px-4 py-6 text-center text-gray-500">No expenses for selected month.</td>
                    </tr>
                  }
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
})
export class ExpensesComponent {
  store = inject(StoreService);
  auth = inject(AuthService);
  fb: FormBuilder = inject(FormBuilder);

  // Filter
  filterMonth = signal(new Date().toISOString().substring(0, 7));
  
  // Edit & UI State
  editingId = signal<string | null>(null);
  deleteConfirmation = signal<string | null>(null); // Track which row is confirming deletion

  currentAttachment = '';
  newAttachment = '';

  expenseForm = this.fb.group({
    vendor: ['', Validators.required],
    date: [new Date().toISOString().split('T')[0], Validators.required],
    amount: [0, [Validators.required, Validators.min(0.01)]],
    categoryId: [this.store.expenseCategories()[0]?.id || ''],
    paymentTypeId: [this.store.expenseTypes()[0]?.id || ''],
    chequeNo: [''],
    reason: ['']
  });

  filteredEntries = computed(() => {
    const month = this.filterMonth();
    return this.store.expenseEntries()
      .filter(e => e.date.startsWith(month))
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  });

  getCategoryName(id: string) { return this.store.expenseCategories().find(c => c.id === id)?.name || id; }
  getTypeName(id: string) { return this.store.expenseTypes().find(t => t.id === id)?.name || id; }

  setFilterMonth(val: string) {
    this.filterMonth.set(val);
  }

  isCheque() {
    const typeId = this.expenseForm.get('paymentTypeId')?.value;
    const type = this.store.expenseTypes().find(t => t.id === typeId);
    return type?.name.toLowerCase() === 'cheque';
  }

  onFileChange(event: any) {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = () => {
        this.newAttachment = reader.result as string;
      };
      reader.readAsDataURL(file);
    }
  }

  edit(entry: ExpenseEntry) {
    this.deleteConfirmation.set(null); // Clear any pending delete
    this.editingId.set(entry.id);
    this.currentAttachment = entry.attachment || '';
    this.newAttachment = ''; // reset new
    
    this.expenseForm.patchValue({
      vendor: entry.vendor,
      date: entry.date,
      amount: entry.amount,
      categoryId: entry.categoryId,
      paymentTypeId: entry.paymentTypeId,
      chequeNo: entry.chequeNo || '',
      reason: entry.reason || ''
    });
  }

  performDelete(entry: ExpenseEntry) {
    this.store.removeExpense(entry.id);
    // If we were editing this entry, cancel the edit
    if (this.editingId() === entry.id) {
        this.cancelEdit();
    }
    this.deleteConfirmation.set(null);
  }

  cancelEdit() {
    this.editingId.set(null);
    this.currentAttachment = '';
    this.newAttachment = '';
    this.expenseForm.reset({
      date: new Date().toISOString().split('T')[0],
      categoryId: this.store.expenseCategories()[0]?.id || '',
      paymentTypeId: this.store.expenseTypes()[0]?.id || '',
      amount: 0
    });
  }

  onSubmit() {
    if (this.expenseForm.valid) {
      if (this.isCheque() && !this.expenseForm.get('chequeNo')?.value) {
        alert('Cheque Number is required for Cheque payments');
        return;
      }

      const val = this.expenseForm.value;
      const attachmentToSave = this.newAttachment || this.currentAttachment;

      const entryData = {
        date: val.date!,
        vendor: val.vendor!,
        amount: val.amount!,
        categoryId: val.categoryId!,
        paymentTypeId: val.paymentTypeId!,
        chequeNo: val.chequeNo || undefined,
        reason: val.reason || undefined,
        attachment: attachmentToSave || undefined,
        createdBy: this.auth.currentUser()?.username || 'unknown'
      };

      if (this.editingId()) {
        this.store.updateExpense({
          ...entryData,
          id: this.editingId()!
        });
        this.cancelEdit();
      } else {
        this.store.addExpense(entryData);
        // Reset only some fields
        this.expenseForm.patchValue({
          vendor: '',
          amount: 0,
          chequeNo: '',
          reason: ''
        });
        this.newAttachment = '';
        this.currentAttachment = '';
        // Date stays same, cats stay same
      }
    }
  }
}