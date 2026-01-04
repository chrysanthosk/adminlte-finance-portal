import { Component, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { StoreService, User } from '../../services/store.service';

type Tab = 'general' | 'users' | 'email' | 'expenses';

@Component({
  selector: 'app-settings',
  imports: [CommonModule, ReactiveFormsModule],
  template: `
    <div class="card bg-white dark:bg-gray-800 rounded shadow transition-colors">
      <div class="card-header p-2 border-b dark:border-gray-700">
        <ul class="flex flex-wrap text-sm font-medium text-center text-gray-500 border-b border-gray-200 dark:border-gray-700 dark:text-gray-400">
          <li class="mr-2">
            <button (click)="activeTab.set('general')" [class.text-blue-600]="activeTab() === 'general'" [class.border-blue-600]="activeTab() === 'general'" class="inline-block p-4 rounded-t-lg hover:text-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800 dark:hover:text-gray-300 border-b-2 border-transparent">
              General
            </button>
          </li>
          <li class="mr-2">
            <button (click)="activeTab.set('users')" [class.text-blue-600]="activeTab() === 'users'" [class.border-blue-600]="activeTab() === 'users'" class="inline-block p-4 rounded-t-lg hover:text-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800 dark:hover:text-gray-300 border-b-2 border-transparent">
              Users
            </button>
          </li>
          <li class="mr-2">
            <button (click)="activeTab.set('email')" [class.text-blue-600]="activeTab() === 'email'" [class.border-blue-600]="activeTab() === 'email'" class="inline-block p-4 rounded-t-lg hover:text-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800 dark:hover:text-gray-300 border-b-2 border-transparent">
              Email Settings
            </button>
          </li>
          <li class="mr-2">
            <button (click)="activeTab.set('expenses')" [class.text-blue-600]="activeTab() === 'expenses'" [class.border-blue-600]="activeTab() === 'expenses'" class="inline-block p-4 rounded-t-lg hover:text-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800 dark:hover:text-gray-300 border-b-2 border-transparent">
              Expense Config
            </button>
          </li>
        </ul>
      </div>

      <div class="card-body p-6">
        
        <!-- General Tab -->
        @if(activeTab() === 'general') {
          <div class="max-w-md">
            <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Company Settings</h3>
            <form [formGroup]="generalForm" (ngSubmit)="saveGeneral()">
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Company Name</label>
                <input type="text" formControlName="companyName" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
              <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">Save Changes</button>
            </form>
          </div>
        }

        <!-- Users Tab -->
        @if(activeTab() === 'users') {
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">{{ editingUser() ? 'Edit User' : 'Add User' }}</h3>
              <form [formGroup]="userForm" (ngSubmit)="onSubmitUser()">
                <div class="mb-3">
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Username</label>
                  <input type="text" formControlName="username" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white" [readonly]="!!editingUser()">
                </div>
                <div class="mb-3">
                   <div class="grid grid-cols-2 gap-2">
                      <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Name</label>
                        <input type="text" formControlName="name" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                      </div>
                      <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Surname</label>
                        <input type="text" formControlName="surname" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                      </div>
                   </div>
                </div>
                <div class="mb-3">
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email</label>
                  <input type="email" formControlName="email" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                </div>
                <div class="mb-3">
                  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Role</label>
                  <select formControlName="role" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                    <option value="user">User</option>
                    <option value="admin">Admin</option>
                  </select>
                </div>
                <div class="mb-3">
                   <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Password</label>
                   <input type="password" formControlName="password" (input)="checkPasswordStrength($event)" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white" placeholder="{{ editingUser() ? 'Leave blank to keep current' : 'Required' }}">
                   <!-- Strength Meter -->
                   <div class="h-1 w-full bg-gray-200 rounded mt-1 overflow-hidden">
                      <div class="h-full transition-all duration-300" [style.width.%]="passwordStrength()" [class.bg-red-500]="passwordStrength() < 40" [class.bg-yellow-500]="passwordStrength() >= 40 && passwordStrength() < 70" [class.bg-green-500]="passwordStrength() >= 70"></div>
                   </div>
                   <p class="text-xs text-gray-500 mt-1">Strength: {{ passwordStrengthLabel() }}</p>
                </div>
                <div class="flex gap-2">
                  <button type="submit" [disabled]="userForm.invalid && !editingUser()" class="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700 disabled:opacity-50">
                    {{ editingUser() ? 'Update User' : 'Add User' }}
                  </button>
                  @if(editingUser()) {
                     <button type="button" (click)="cancelEditUser()" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">Cancel</button>
                  }
                </div>
              </form>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Existing Users</h3>
              <ul class="divide-y divide-gray-200 dark:divide-gray-700">
                @for(user of store.users(); track user.username) {
                  <li class="py-3 flex justify-between items-center">
                    <div>
                      <p class="text-sm font-medium text-gray-900 dark:text-white">{{ user.username }} <span class="text-xs text-gray-500">({{ user.role }})</span></p>
                      <p class="text-sm text-gray-500 dark:text-gray-400">{{ user.email }}</p>
                    </div>
                    <div class="flex gap-2 items-center">
                       <button (click)="editUser(user)" class="text-blue-600 hover:text-blue-900 text-sm">Edit</button>
                       @if(user.username !== 'admin') {
                         @if(userToDelete() === user.username) {
                            <div class="flex items-center gap-2 animate-pulse bg-red-50 dark:bg-red-900/20 px-2 py-1 rounded">
                                <span class="text-xs text-red-600 dark:text-red-400 font-bold">Sure?</span>
                                <button (click)="performDeleteUser(user.username)" class="text-red-700 dark:text-red-300 text-xs font-bold hover:underline">Yes</button>
                                <button (click)="userToDelete.set(null)" class="text-gray-500 dark:text-gray-400 text-xs hover:text-gray-700">No</button>
                            </div>
                         } @else {
                             <button (click)="userToDelete.set(user.username)" class="text-red-600 hover:text-red-900 text-sm">Remove</button>
                         }
                       }
                    </div>
                  </li>
                }
              </ul>
            </div>
          </div>
        }

        <!-- Email Settings Tab -->
        @if(activeTab() === 'email') {
           <div class="max-w-md">
            <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">SMTP Configuration</h3>
            <form [formGroup]="smtpForm" (ngSubmit)="saveSmtp()">
              <div class="mb-3">
                 <div class="grid grid-cols-2 gap-4">
                     <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">From Name</label>
                        <input type="text" formControlName="fromName" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                     </div>
                     <div>
                        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">From Email</label>
                        <input type="email" formControlName="fromEmail" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                     </div>
                 </div>
              </div>
              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">SMTP Host</label>
                <input type="text" formControlName="host" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Port</label>
                <input type="number" formControlName="port" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Username</label>
                <input type="text" formControlName="user" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
              <div class="mb-3">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Password</label>
                <input type="password" formControlName="password" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
              <div class="mb-4 flex items-center">
                 <input type="checkbox" formControlName="secure" class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600">
                 <label class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300">Use Secure Connection (TLS/SSL)</label>
              </div>
              <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">Save SMTP Settings</button>
            </form>
           </div>
        }

        <!-- Expenses Config Tab -->
        @if(activeTab() === 'expenses') {
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Categories -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Expense Categories</h3>
              <div class="flex gap-2 mb-4">
                <input #newCat type="text" placeholder="New Category" class="flex-1 rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                <button (click)="addCategory(newCat.value); newCat.value=''" class="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700">Add</button>
              </div>
              <ul class="bg-gray-50 dark:bg-gray-700 rounded p-4 space-y-2">
                @for(cat of store.expenseCategories(); track cat.id) {
                  <li class="flex justify-between items-center text-sm">
                    
                    @if(editingCatId() === cat.id) {
                        <!-- Inline Edit Mode -->
                        <div class="flex gap-2 flex-1">
                            <input #editCatInput type="text" [value]="cat.name" class="flex-1 rounded border dark:border-gray-600 px-2 py-1 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                            <button (click)="saveCategoryEdit(cat.id, editCatInput.value)" class="text-green-600 hover:text-green-800">Save</button>
                            <button (click)="editingCatId.set(null)" class="text-gray-500 hover:text-gray-700">Cancel</button>
                        </div>
                    } @else {
                        <!-- View Mode -->
                        <span class="text-gray-900 dark:text-white">{{ cat.name }}</span>
                        <div class="flex gap-2">
                           <button (click)="startEditCat(cat.id)" class="text-blue-500 hover:text-blue-700">Edit</button>
                           <button (click)="store.removeExpenseCategory(cat.id)" class="text-red-500 hover:text-red-700">×</button>
                        </div>
                    }
                  </li>
                }
              </ul>
            </div>

            <!-- Payment Methods (Types) -->
            <div>
              <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Payment Methods</h3>
              <div class="flex gap-2 mb-4">
                <input #newMethod type="text" placeholder="New Method" class="flex-1 rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                <button (click)="addMethod(newMethod.value); newMethod.value=''" class="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700">Add</button>
              </div>
              <ul class="bg-gray-50 dark:bg-gray-700 rounded p-4 space-y-2">
                @for(type of store.expenseTypes(); track type.id) {
                  <li class="flex justify-between items-center text-sm">
                    @if(editingMethodId() === type.id) {
                        <!-- Inline Edit Mode -->
                        <div class="flex gap-2 flex-1">
                            <input #editMethodInput type="text" [value]="type.name" class="flex-1 rounded border dark:border-gray-600 px-2 py-1 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                            <button (click)="saveMethodEdit(type.id, editMethodInput.value)" class="text-green-600 hover:text-green-800">Save</button>
                            <button (click)="editingMethodId.set(null)" class="text-gray-500 hover:text-gray-700">Cancel</button>
                        </div>
                    } @else {
                        <!-- View Mode -->
                        <span class="text-gray-900 dark:text-white">{{ type.name }}</span>
                        <div class="flex gap-2">
                           <button (click)="startEditMethod(type.id)" class="text-blue-500 hover:text-blue-700">Edit</button>
                           <button (click)="store.removeExpenseType(type.id)" class="text-red-500 hover:text-red-700">×</button>
                        </div>
                    }
                  </li>
                }
              </ul>
            </div>
          </div>
        }

      </div>
    </div>
  `
})
export class SettingsComponent {
  store = inject(StoreService);
  fb: FormBuilder = inject(FormBuilder);
  activeTab = signal<Tab>('general');
  editingUser = signal<User | null>(null);
  
  // Inline edit signals
  editingCatId = signal<string | null>(null);
  editingMethodId = signal<string | null>(null);
  
  // Delete confirm signal
  userToDelete = signal<string | null>(null);

  passwordStrength = signal(0);
  passwordStrengthLabel = signal('Empty');

  // Forms
  generalForm = this.fb.group({
    companyName: [this.store.settings().companyName, Validators.required]
  });

  userForm = this.fb.group({
    username: ['', Validators.required],
    name: [''],
    surname: [''],
    email: ['', [Validators.required, Validators.email]],
    role: ['user', Validators.required],
    password: ['']
  });

  smtpForm = this.fb.group({
    host: ['', Validators.required],
    port: [587, Validators.required],
    user: [''],
    password: [''],
    secure: [true],
    fromName: [''],
    fromEmail: ['', [Validators.email]]
  });

  constructor() {
    // Init smtp values
    const smtp = this.store.smtpSettings();
    if(smtp) {
        this.smtpForm.patchValue(smtp);
    }
  }

  saveGeneral() {
    if (this.generalForm.valid) {
      this.store.updateSettings({
        companyName: this.generalForm.value.companyName!
      });
      alert('Settings saved');
    }
  }

  saveSmtp() {
    if(this.smtpForm.valid) {
        this.store.updateSmtpSettings({
            host: this.smtpForm.value.host!,
            port: this.smtpForm.value.port!,
            user: this.smtpForm.value.user || '',
            password: this.smtpForm.value.password || '',
            secure: this.smtpForm.value.secure || false,
            fromName: this.smtpForm.value.fromName || '',
            fromEmail: this.smtpForm.value.fromEmail || ''
        });
        alert('SMTP Settings saved');
    }
  }

  editUser(user: User) {
    this.editingUser.set(user);
    this.userForm.patchValue({
        username: user.username,
        name: user.name || '',
        surname: user.surname || '',
        email: user.email,
        role: user.role,
        password: ''
    });
    this.passwordStrength.set(0);
    this.passwordStrengthLabel.set('Empty');
  }

  // Renamed to performDeleteUser to distinguish from trigger
  performDeleteUser(username: string) {
    this.store.removeUser(username);
    this.userToDelete.set(null);
  }

  cancelEditUser() {
    this.editingUser.set(null);
    this.userForm.reset({ role: 'user' });
    this.passwordStrength.set(0);
    this.passwordStrengthLabel.set('Empty');
  }

  checkPasswordStrength(event: any) {
    const p = event.target.value;
    let strength = 0;
    if (p.length > 5) strength += 20;
    if (p.length > 10) strength += 20;
    if (/[A-Z]/.test(p)) strength += 20;
    if (/[0-9]/.test(p)) strength += 20;
    if (/[^A-Za-z0-9]/.test(p)) strength += 20;

    this.passwordStrength.set(strength);
    if(strength === 0) this.passwordStrengthLabel.set('Empty');
    else if(strength < 40) this.passwordStrengthLabel.set('Weak');
    else if(strength < 70) this.passwordStrengthLabel.set('Medium');
    else this.passwordStrengthLabel.set('Strong');
  }

  onSubmitUser() {
    if (this.userForm.valid || (this.editingUser() && this.userForm.get('username')?.valid && this.userForm.get('email')?.valid)) {
      const val = this.userForm.value;
      const userData: any = {
        username: val.username!,
        email: val.email!,
        name: val.name || '',
        surname: val.surname || '',
        role: val.role as 'admin' | 'user'
      };
      
      if(val.password) {
        userData.password = val.password;
      }

      this.store.addUser(userData); // addUser handles update if username exists
      this.cancelEditUser();
    }
  }

  addCategory(name: string) {
    if (name.trim()) this.store.addExpenseCategory(name.trim());
  }

  startEditCat(id: string) {
    this.editingCatId.set(id);
  }

  saveCategoryEdit(id: string, newName: string) {
    if (newName.trim()) {
        this.store.updateExpenseCategory(id, newName.trim());
        this.editingCatId.set(null);
    }
  }

  addMethod(name: string) {
    if (name.trim()) this.store.addExpenseType(name.trim());
  }

  startEditMethod(id: string) {
    this.editingMethodId.set(id);
  }

  saveMethodEdit(id: string, newName: string) {
    if(newName.trim()) {
        this.store.updateExpenseType(id, newName.trim());
        this.editingMethodId.set(null);
    }
  }
}