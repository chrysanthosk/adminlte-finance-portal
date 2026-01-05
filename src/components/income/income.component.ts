import { Component, inject, signal, computed, effect, untracked } from '@angular/core';
import { CommonModule, CurrencyPipe } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, FormArray, Validators, FormsModule } from '@angular/forms';
import { StoreService, IncomeEntry } from '../../services/store.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-income',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, CurrencyPipe, FormsModule],
  template: `
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Add/Edit Income Form -->
      <div class="lg:col-span-1">
        <div class="card card-primary bg-white dark:bg-gray-800 rounded shadow border-t-4 border-blue-600 dark:border-blue-500 transition-colors">
          <div class="card-header p-4 border-b dark:border-gray-700 flex justify-between items-center">
            <h3 class="card-title text-lg font-medium dark:text-gray-100">{{ editingId() ? 'Edit Income' : 'Add Daily Income' }}</h3>
            @if(editingId()) {
              <button (click)="cancelEdit()" class="text-xs text-red-500 hover:text-red-700">Cancel</button>
            }
          </div>
          <div class="card-body p-4">
            <form [formGroup]="incomeForm" (ngSubmit)="onSubmit()">
              <div class="mb-4">
                <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-2">Date</label>
                <input type="date" formControlName="date" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100">
              </div>

              <div formArrayName="amounts">
                @for (method of store.incomeMethods(); track $index; let i = $index) {
                  <div [formGroupName]="i" class="mb-3">
                    <label class="block text-gray-600 dark:text-gray-400 text-xs font-semibold mb-1">
                      {{ method.name }}
                    </label>
                    <div class="relative">
                      <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-500">€</div>
                      <input type="number" formControlName="amount" class="pl-7 shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100" min="0">
                    </div>
                  </div>
                }
              </div>

              <div class="mb-4">
                <label class="block text-gray-700 dark:text-gray-300 text-sm font-bold mb-2">Notes</label>
                <textarea formControlName="notes" class="shadow appearance-none border dark:border-gray-600 rounded w-full py-2 px-3 leading-tight focus:outline-none focus:shadow-outline bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100" rows="3"></textarea>
              </div>

              <div class="flex justify-end">
                <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline transition">
                  {{ editingId() ? 'Update Entry' : 'Save Entry' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <!-- Income List -->
      <div class="lg:col-span-2">
        <div class="card bg-white dark:bg-gray-800 rounded shadow border-t-4 border-gray-600 dark:border-gray-500 transition-colors">
          <div class="card-header p-4 border-b dark:border-gray-700 flex flex-wrap gap-4 justify-between items-center">
            <h3 class="card-title text-lg font-medium dark:text-gray-100">Income History</h3>
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
                    @for (m of store.incomeMethods(); track m.id) {
                      <th class="px-4 py-3 text-right hidden sm:table-cell">{{ m.name }}</th>
                    }
                    <th class="px-4 py-3 text-right">Total</th>
                    <th class="px-4 py-3">Notes</th>
                    <th class="px-4 py-3 text-center">Action</th>
                  </tr>
                </thead>
                <tbody>
                  @for (entry of filteredEntries(); track entry.id) {
                    <tr class="bg-white dark:bg-gray-800 border-b dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
                      <td class="px-4 py-3 font-medium text-gray-900 dark:text-gray-100 whitespace-nowrap">{{ entry.date }}</td>
                      @for (m of store.incomeMethods(); track m.id) {
                        <td class="px-4 py-3 text-right hidden sm:table-cell text-gray-400">
                          {{ getAmountForMethod(entry, m.id) | currency:'EUR' }}
                        </td>
                      }
                      <td class="px-4 py-3 text-right font-bold text-green-600 dark:text-green-400">
                        {{ getTotal(entry) | currency:'EUR' }}
                      </td>
                      <td class="px-4 py-3 truncate max-w-xs">{{ entry.notes }}</td>
                      <td class="px-4 py-3 text-center">
                        <button (click)="edit(entry)" class="text-blue-600 dark:text-blue-400 hover:underline">Edit</button>
                      </td>
                    </tr>
                  } @empty {
                    <tr>
                      <td colspan="10" class="px-4 py-6 text-center text-gray-500">No records for selected month.</td>
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
export class IncomeComponent {
  store = inject(StoreService);
  auth = inject(AuthService);
  fb: FormBuilder = inject(FormBuilder);

  // Filter state
  filterMonth = signal(new Date().toISOString().substring(0, 7)); // YYYY-MM

  // ✅ FIXED: Changed type to accept string | number | null
  editingId = signal<string | number | null>(null);

  incomeForm = this.fb.group({
    date: [new Date().toISOString().split('T')[0], Validators.required],
    amounts: this.fb.array([]),
    notes: ['']
  });

  filteredEntries = computed(() => {
    const month = this.filterMonth();
    return this.store.incomeEntries()
      .filter(e => e.date.startsWith(month))
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  });

  constructor() {
    // Initialize form ONCE based on methods.
    // Effect handles updates if methods config changes, but ignores editing state to prevent wipe.
    effect(() => {
      const methods = this.store.incomeMethods();
      untracked(() => {
        if (!this.editingId()) {
           this.initForm();
        }
      });
    });
  }

  setFilterMonth(val: string) {
    this.filterMonth.set(val);
  }

  // Initializes the FormArray structure.
  // Should only be called when not editing, or when config changes.
  initForm() {
    const amountsArray = this.incomeForm.get('amounts') as FormArray;
    amountsArray.clear();

    // Create controls for each method, in order.
    this.store.incomeMethods().forEach(m => {
      amountsArray.push(this.fb.group({
        methodId: [m.id],
        amount: [0, [Validators.min(0)]]
      }));
    });
  }

  // ✅ FIXED: Use String() conversion for safe comparison
  getAmountForMethod(entry: any, methodId: string | number) {
    const line = entry.lines.find((l: any) => String(l.methodId) === String(methodId));
    return line ? line.amount : 0;
  }

  getTotal(entry: any) {
    return entry.lines.reduce((s: number, l: any) => s + l.amount, 0);
  }

  edit(entry: IncomeEntry) {
    this.editingId.set(entry.id);

    // 1. Patch header fields
    this.incomeForm.patchValue({
      date: entry.date,
      notes: entry.notes
    });

    // 2. Patch existing FormArray controls instead of destroying them.
    // This ensures DOM stability and correct data binding.
    const amountsArray = this.incomeForm.get('amounts') as FormArray;
    const methods = this.store.incomeMethods();

    // Safety check: ensure form array matches methods length
    if (amountsArray.length !== methods.length) {
      this.initForm();
    }

    // ✅ FIXED: Use String() conversion for safe comparison
    // Iterate over the STORE methods to ensure we match index-for-index
    methods.forEach((m, index) => {
      // Find the value in the entry
      const line = entry.lines.find(l => String(l.methodId) === String(m.id));
      const val = line ? line.amount : 0;

      // Get the existing control at this index
      const control = amountsArray.at(index);
      if (control) {
        control.patchValue({
          methodId: m.id,
          amount: val
        });
      }
    });
  }

  cancelEdit() {
    this.editingId.set(null);
    this.incomeForm.patchValue({
       date: new Date().toISOString().split('T')[0],
       notes: ''
    });
    // Reset amounts to 0
    const amountsArray = this.incomeForm.get('amounts') as FormArray;
    amountsArray.controls.forEach(c => c.patchValue({ amount: 0 }));
  }

  onSubmit() {
    if (this.incomeForm.valid) {
      const formVal = this.incomeForm.value;

      const lines = (formVal.amounts as any[])
        .filter(a => a.amount >= 0)
        .map(a => ({ methodId: a.methodId, amount: a.amount }));

      const cleanLines = lines.filter(l => l.amount > 0);

      if (cleanLines.length === 0 && !this.editingId()) return;

      if (this.editingId()) {
        this.store.updateIncome({
          id: String(this.editingId()!),  // ✅ FIXED: Ensure string type
          date: formVal.date!,
          lines: cleanLines,
          notes: formVal.notes || '',
          createdBy: this.auth.currentUser()?.username || 'unknown'
        });
        this.cancelEdit();
      } else {
        this.store.addIncome({
          date: formVal.date!,
          lines: cleanLines,
          notes: formVal.notes || '',
          createdBy: this.auth.currentUser()?.username || 'unknown'
        });

        this.cancelEdit();
      }
    }
  }
}
