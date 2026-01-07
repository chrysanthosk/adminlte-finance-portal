
import '@angular/compiler';
import { bootstrapApplication } from '@angular/platform-browser';
import { APP_INITIALIZER, provideZoneChangeDetection } from '@angular/core';
import { provideRouter, withHashLocation } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';

import { AppComponent } from './src/app.component';
import { routes } from './src/app.routes';
import { StoreService } from './src/services/store.service';

// Factory for APP_INITIALIZER
export function initializeApp(store: StoreService) {
  return () => store.loadAll();
}

bootstrapApplication(AppComponent, {
  providers: [
    // FIX: The `provideZonelessChangeDetection` export is not available from the CDN.
    // Reverting to the more established `provideZoneChangeDetection({ ngZone: 'noop' })`
    // to enable zoneless change detection.
    provideZoneChangeDetection({ ngZone: 'noop' }),
    provideRouter(routes, withHashLocation()),
    provideHttpClient(),
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [StoreService],
      multi: true,
    }
  ]
}).catch((err: any) => console.error(err));

// AI Studio always uses an `index.tsx` file for all project types.