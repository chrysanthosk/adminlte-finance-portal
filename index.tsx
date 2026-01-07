
import { bootstrapApplication } from '@angular/platform-browser';
import { provideZonelessChangeDetection, APP_INITIALIZER } from '@angular/core';
import { provideRouter, withHashLocation } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { AppComponent } from './src/app.component';
import { routes } from './src/app.routes';
import { StoreService } from './src/services/store.service';

// Factory for APP_INITIALIZER
// This function will be executed when the app is initialized.
export function initializeApp(store: StoreService) {
  return () => store.loadAll();
}

bootstrapApplication(AppComponent, {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes, withHashLocation()),
    provideHttpClient(),
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [StoreService],
      multi: true,
    },
  ]
}).catch(err => console.error(err));

// AI Studio always uses an `index.tsx` file for all project types.