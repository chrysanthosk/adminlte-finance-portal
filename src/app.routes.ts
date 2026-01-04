import { Routes } from '@angular/router';
import { DashboardComponent } from './components/dashboard/dashboard.component';
import { IncomeComponent } from './components/income/income.component';
import { ExpensesComponent } from './components/expenses/expenses.component';
import { AccountsComponent } from './components/accounts/accounts.component';
import { ReportsComponent } from './components/reports/reports.component';
import { SettingsComponent } from './components/settings/settings.component';
import { LoginComponent } from './components/login/login.component';
import { ProfileComponent } from './components/profile/profile.component';
import { inject } from '@angular/core';
import { AuthService } from './services/auth.service';
import { Router } from '@angular/router';

const authGuard = () => {
  const auth = inject(AuthService);
  return auth.isAuthenticated() || (inject(Router) as Router).createUrlTree(['/login']);
};

const adminGuard = () => {
  const auth = inject(AuthService);
  return (auth.isAuthenticated() && auth.isAdmin()) || (inject(Router) as Router).createUrlTree(['/']);
};

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { 
    path: '', 
    canActivate: [authGuard],
    children: [
      { path: '', component: DashboardComponent },
      { path: 'income', component: IncomeComponent },
      { path: 'expenses', component: ExpensesComponent },
      { path: 'profile', component: ProfileComponent },
      { path: 'accounts', canActivate: [adminGuard], component: AccountsComponent },
      { path: 'reports', canActivate: [adminGuard], component: ReportsComponent },
      { path: 'settings', canActivate: [adminGuard], component: SettingsComponent }
    ]
  },
  { path: '**', redirectTo: '' }
];