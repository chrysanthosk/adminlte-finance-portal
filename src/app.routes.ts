import { Routes } from '@angular/router';
import { AuthGuard } from './guards/auth.guard';

import { LoginComponent } from './components/login/login.component';
import { DashboardComponent } from './components/dashboard/dashboard.component';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: '',
    component: DashboardComponent,
    canActivate: [AuthGuard],
  },
  { path: '**', redirectTo: '' }
];