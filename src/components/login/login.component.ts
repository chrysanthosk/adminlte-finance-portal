import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators, FormsModule } from '@angular/forms';
import { AuthService } from '../../services/auth.service';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [ReactiveFormsModule, CommonModule, FormsModule],
  template: `
    <div class="login-page bg-gray-200 dark:bg-gray-900 min-h-screen flex flex-col justify-center items-center font-sans transition-colors duration-300">
      
      <div class="absolute top-4 right-4">
        <button (click)="toggleDarkMode()" class="p-2 rounded-full bg-white dark:bg-gray-800 text-gray-800 dark:text-gray-200 shadow-md hover:bg-gray-100 dark:hover:bg-gray-700 transition">
          @if(isDarkMode) {
            <span>☀️</span>
          } @else {
            <span>🌙</span>
          }
        </button>
      </div>

      <div class="login-box w-full max-w-md">
        <div class="card card-outline card-primary bg-white dark:bg-gray-800 rounded-lg shadow-lg overflow-hidden border-t-4 border-blue-600 dark:border-blue-500">
          <div class="card-header text-center py-6 border-b border-gray-100 dark:border-gray-700">
            <a href="javascript:void(0)" class="h1 text-3xl font-light text-gray-800 dark:text-white"><b>Admin</b>LTE</a>
          </div>
          <div class="card-body p-8">
            
            @if(step() === 'login') {
                <p class="login-box-msg text-center mb-6 text-gray-600 dark:text-gray-400">Sign in to start your session</p>

                <form [formGroup]="loginForm" (ngSubmit)="onLoginSubmit()">
                  <div class="mb-4">
                    <div class="relative">
                      <input type="text" formControlName="username" class="w-full pl-3 pr-10 py-2 border dark:border-gray-600 rounded focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-colors bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100" placeholder="Username">
                      <div class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none text-gray-400">
                        📧
                      </div>
                    </div>
                  </div>
                  <div class="mb-2">
                    <div class="relative">
                      <input type="password" formControlName="password" class="w-full pl-3 pr-10 py-2 border dark:border-gray-600 rounded focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-colors bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100" placeholder="Password">
                      <div class="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none text-gray-400">
                        🔒
                      </div>
                    </div>
                  </div>
                  
                  <div class="flex justify-end mb-6">
                      <button type="button" (click)="step.set('forgot')" class="text-sm text-blue-600 hover:text-blue-800 dark:text-blue-400">Forgot Password?</button>
                  </div>

                  @if (error()) {
                    <div class="mb-4 text-center text-red-600 text-sm">
                      {{ error() }}
                    </div>
                  }

                  <div class="mb-4">
                    <button type="submit" [disabled]="loginForm.invalid || isLoading()" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded transition duration-150 disabled:opacity-50">
                      {{ isLoading() ? 'Signing in...' : 'Sign In' }}
                    </button>
                  </div>
                </form>
            } 
            
            @else if (step() === '2fa') {
                <p class="login-box-msg text-center mb-6 text-gray-600 dark:text-gray-400">Two-Factor Authentication</p>
                <p class="text-center text-sm text-gray-500 mb-4">Please enter the code from your authenticator app.</p>
                
                <div class="mb-6">
                    <input type="text" [(ngModel)]="twoFactorCode" class="w-full text-center text-2xl tracking-widest py-2 border dark:border-gray-600 rounded focus:outline-none focus:border-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-white" maxlength="6" placeholder="000000">
                </div>

                @if (error()) {
                    <div class="mb-4 text-center text-red-600 text-sm">
                      {{ error() }}
                    </div>
                }

                <div class="mb-4">
                    <button type="button" (click)="verify2FA()" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded transition">
                      Verify Code
                    </button>
                </div>
                <div class="text-center">
                    <button (click)="step.set('login'); error.set('')" class="text-sm text-gray-500 hover:text-gray-700">Back to Login</button>
                </div>
            }

            @else if (step() === 'forgot') {
                <p class="login-box-msg text-center mb-6 text-gray-600 dark:text-gray-400">Reset Password</p>
                <p class="text-center text-sm text-gray-500 mb-4">Enter your email address to receive instructions.</p>
                
                <form [formGroup]="forgotForm" (ngSubmit)="onForgotSubmit()">
                    <div class="mb-6">
                        <input type="email" formControlName="email" class="w-full pl-3 py-2 border dark:border-gray-600 rounded focus:outline-none focus:border-blue-500 bg-white dark:bg-gray-700 text-gray-900 dark:text-white" placeholder="Email Address">
                    </div>
                    
                    @if(message()) {
                         <div class="mb-4 text-center text-green-600 text-sm">{{ message() }}</div>
                    }

                    <div class="mb-4">
                        <button type="submit" [disabled]="forgotForm.invalid" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded transition disabled:opacity-50">
                          Send Reset Link
                        </button>
                    </div>
                </form>
                <div class="text-center">
                    <button (click)="step.set('login'); message.set('')" class="text-sm text-gray-500 hover:text-gray-700">Back to Login</button>
                </div>
            }

          </div>
        </div>
      </div>
    </div>
  `
})
export class LoginComponent {
  fb: FormBuilder = inject(FormBuilder);
  auth = inject(AuthService);
  isDarkMode = false;
  
  step = signal<'login' | '2fa' | 'forgot'>('login');
  error = signal<string>('');
  message = signal<string>('');
  isLoading = signal(false);
  
  // Pending user for 2FA
  pendingUser: any = null;
  twoFactorCode = '';
  
  loginForm = this.fb.group({
    username: ['', Validators.required],
    password: ['', Validators.required]
  });

  forgotForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]]
  });

  constructor() {
    this.isDarkMode = document.documentElement.classList.contains('dark');
  }

  toggleDarkMode() {
    this.isDarkMode = !this.isDarkMode;
    if (this.isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }

  async onLoginSubmit() {
    if (this.loginForm.valid) {
      this.error.set('');
      this.isLoading.set(true);
      const { username, password } = this.loginForm.value;
      
      try {
        const user = await this.auth.validateCredentials(username!, password!);
        
        if (user) {
           if (user.twoFactorEnabled) {
               this.pendingUser = user;
               this.step.set('2fa');
           } else {
               this.auth.completeLogin(user);
           }
        } else {
          this.error.set('Invalid credentials');
        }
      } catch(e) {
         this.error.set('Connection error');
      } finally {
         this.isLoading.set(false);
      }
    }
  }

  verify2FA() {
      if(this.twoFactorCode.length === 6 && /^\d+$/.test(this.twoFactorCode)) {
          // Ideally verify this code with backend too
          this.auth.completeLogin(this.pendingUser);
      } else {
          this.error.set('Invalid authentication code.');
      }
  }

  onForgotSubmit() {
      if(this.forgotForm.valid) {
          this.message.set(`If an account exists for ${this.forgotForm.value.email}, a reset link has been sent.`);
      }
  }
}