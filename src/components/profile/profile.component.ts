import { Component, inject, signal, effect, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators, FormsModule } from '@angular/forms';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-profile',
  imports: [CommonModule, ReactiveFormsModule, FormsModule],
  template: `
    <div class="max-w-2xl mx-auto">
      <div class="card bg-white dark:bg-gray-800 rounded shadow transition-colors">
        <div class="card-header p-4 border-b dark:border-gray-700">
          <h3 class="card-title text-lg font-medium dark:text-gray-100">User Profile</h3>
        </div>
        <div class="card-body p-6">
          
          @if(isVerifyingEmail()) {
             <div class="mb-6 p-4 bg-yellow-50 dark:bg-yellow-900/30 border border-yellow-200 dark:border-yellow-700 rounded">
                 <h4 class="font-bold text-yellow-800 dark:text-yellow-200 mb-2">Verify Email Address</h4>
                 <p class="text-sm text-yellow-700 dark:text-yellow-300 mb-3">
                    We have sent a verification code to <strong>{{ pendingEmail() }}</strong>. Please enter it below to confirm this change.
                    <br><span class="text-xs italic">(Simulated: Use code <strong>{{ verificationCode() }}</strong>)</span>
                 </p>
                 <div class="flex gap-2">
                    <input type="text" [(ngModel)]="inputCode" placeholder="Enter Code" class="rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
                    <button (click)="verifyEmail()" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">Confirm</button>
                    <button (click)="cancelVerify()" class="bg-gray-500 text-white px-4 py-2 rounded hover:bg-gray-600">Cancel</button>
                 </div>
                 @if(verifyError()) {
                    <p class="text-xs text-red-600 mt-2">{{ verifyError() }}</p>
                 }
             </div>
          }

          <form [formGroup]="profileForm" (ngSubmit)="onSubmit()">
            @if(successMessage()) {
               <div class="mb-4 p-3 bg-green-100 text-green-700 rounded text-sm dark:bg-green-900 dark:text-green-300">
                 {{ successMessage() }}
               </div>
            }

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">First Name</label>
                <input type="text" formControlName="name" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Surname</label>
                <input type="text" formControlName="surname" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              </div>
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Email</label>
              <input type="email" formControlName="email" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white">
              <p class="text-xs text-gray-500 mt-1">Changing email requires verification.</p>
            </div>

            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">New Password</label>
              <input type="password" formControlName="password" class="w-full rounded border dark:border-gray-600 px-3 py-2 bg-white dark:bg-gray-700 text-gray-900 dark:text-white" placeholder="Leave blank to keep current">
            </div>

            <div class="mb-6">
              <div class="flex items-center mb-2">
                <input type="checkbox" formControlName="twoFactorEnabled" class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600">
                <label class="ml-2 text-sm font-medium text-gray-900 dark:text-gray-300">Enable Two-Factor Authentication (2FA)</label>
              </div>
              
              @if(qrCodeUrl()) {
                  <div class="p-4 bg-gray-50 dark:bg-gray-700 rounded border dark:border-gray-600">
                      <p class="text-sm text-gray-700 dark:text-gray-300 mb-2">Scan this QR code with your Authenticator App:</p>
                      <img [src]="qrCodeUrl()" alt="2FA QR Code" class="w-32 h-32 bg-white p-1 rounded">
                      <p class="text-xs text-gray-500 mt-2">Secret: {{ twoFactorSecret() }}</p>
                  </div>
              }
            </div>

            <div class="flex justify-end">
              <button type="submit" [disabled]="profileForm.invalid || isVerifyingEmail()" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 disabled:opacity-50">Save Changes</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  `
})
export class ProfileComponent {
  auth = inject(AuthService);
  fb: FormBuilder = inject(FormBuilder);
  successMessage = signal('');
  
  // 2FA
  twoFactorSecret = signal('');
  
  // Email Verification
  isVerifyingEmail = signal(false);
  pendingEmail = signal('');
  verificationCode = signal('');
  inputCode = '';
  verifyError = signal('');
  
  // Create QR Code URL dynamically based on secret and user email
  qrCodeUrl = computed(() => {
     const secret = this.twoFactorSecret();
     const email = this.profileForm.get('email')?.value || 'user';
     if(this.profileForm.get('twoFactorEnabled')?.value && secret) {
         // Standard OTP Auth URL format
         const label = `FinancePortal:${email}`;
         const otpauth = `otpauth://totp/${label}?secret=${secret}&issuer=FinancePortal`;
         return `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(otpauth)}`;
     }
     return '';
  });

  profileForm = this.fb.group({
    name: ['', Validators.required],
    surname: ['', Validators.required],
    email: ['', [Validators.required, Validators.email]],
    password: [''],
    twoFactorEnabled: [false]
  });

  constructor() {
    // Effect to keep form in sync with current user (persisted state)
    effect(() => {
      const user = this.auth.currentUser();
      if (user) {
        // Use emitEvent: false to prevent potential infinite loops or unwanted side effects
        this.profileForm.patchValue({
          name: user.name || '',
          surname: user.surname || '',
          email: user.email,
          twoFactorEnabled: user.twoFactorEnabled || false
        }, { emitEvent: false });
        
        if(user.twoFactorSecret) {
            this.twoFactorSecret.set(user.twoFactorSecret);
        } else if (user.twoFactorEnabled) {
            // Generate one if missing but enabled
            this.twoFactorSecret.set(this.generateSecret());
        }
      }
    });

    // Watch for toggle to generate secret if needed
    this.profileForm.get('twoFactorEnabled')?.valueChanges.subscribe(enabled => {
        if(enabled && !this.twoFactorSecret()) {
            this.twoFactorSecret.set(this.generateSecret());
        }
    });
  }

  generateSecret() {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      let secret = '';
      for(let i=0; i<16; i++) {
          secret += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return secret;
  }

  onSubmit() {
    this.successMessage.set('');
    this.verifyError.set('');
    
    if (this.profileForm.valid) {
      const formVal = this.profileForm.value;
      const currentUser = this.auth.currentUser();
      
      if (currentUser) {
        // Check if email changed
        if (formVal.email !== currentUser.email) {
            this.pendingEmail.set(formVal.email!);
            // Generate simple 6 digit code
            const code = Math.floor(100000 + Math.random() * 900000).toString();
            this.verificationCode.set(code);
            this.isVerifyingEmail.set(true);
            // In a real app, send email here
            return;
        }

        this.updateProfile(formVal, currentUser.email);
      }
    }
  }

  verifyEmail() {
      if(this.inputCode === this.verificationCode()) {
          const formVal = this.profileForm.value;
          this.updateProfile(formVal, this.pendingEmail());
          this.isVerifyingEmail.set(false);
          this.pendingEmail.set('');
          this.inputCode = '';
      } else {
          this.verifyError.set('Invalid code. Please try again.');
      }
  }

  cancelVerify() {
      this.isVerifyingEmail.set(false);
      this.pendingEmail.set('');
      this.inputCode = '';
      this.verifyError.set('');
      // Reset email field to current user email
      this.profileForm.patchValue({ email: this.auth.currentUser()?.email });
  }

  updateProfile(formVal: any, emailToSave: string) {
      const currentUser = this.auth.currentUser();
      if(!currentUser) return;

      const updatedUser = {
          ...currentUser,
          name: formVal.name!,
          surname: formVal.surname!,
          email: emailToSave,
          twoFactorEnabled: formVal.twoFactorEnabled!,
          twoFactorSecret: formVal.twoFactorEnabled ? this.twoFactorSecret() : undefined,
          password: formVal.password ? formVal.password : currentUser.password
      };
      
      this.auth.updateCurrentUser(updatedUser);
      this.successMessage.set('Profile updated successfully!');
      this.profileForm.get('password')?.reset();
  }
}