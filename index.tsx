
import { bootstrapApplication } from '@angular/platform-browser';
import { APP_INITIALIZER, NgZone, EventEmitter } from '@angular/core';
import { provideRouter, withHashLocation } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { AppComponent } from './src/app.component';
import { routes } from './src/app.routes';
import { StoreService } from './src/services/store.service';

/**
 * A null `NgZone` implementation that does nothing, effectively making the application "zoneless".
 * This is used as a fallback when `provideZonelessChangeDetection` is not available or not working
 * in the build environment.
 */
class NoopNgZone implements NgZone {
  readonly hasPendingMicrotasks = false;
  readonly hasPendingMacrotasks = false;
  readonly isStable = true;
  readonly onUnstable = new EventEmitter<false>();
  readonly onMicrotaskEmpty = new EventEmitter<true>();
  readonly onStable = new EventEmitter<true>();
  readonly onError = new EventEmitter<any>();

  run<T>(fn: (...args: any[]) => T, applyThis?: any, applyArgs?: any[]): T {
    return fn.apply(applyThis, applyArgs ?? []);
  }

  runGuarded<T>(fn: (...args: any[]) => T, applyThis?: any, applyArgs?: any[]): T {
    return fn.apply(applyThis, applyArgs ?? []);
  }

  runTask<T>(fn: (...args: any[]) => T, applyThis?: any, applyArgs?: any[], source?: string): T {
    return fn.apply(applyThis, applyArgs ?? []);
  }

  runOutsideAngular<T>(fn: (...args: any[]) => T): T {
    return fn();
  }
}

// Factory for APP_INITIALIZER
// This function will be executed when the app is initialized.
export function initializeApp(store: StoreService) {
  return () => store.loadAll();
}

bootstrapApplication(AppComponent, {
  providers: [
    // Manually provide a 'noop' zone to run the application without Zone.js.
    { provide: NgZone, useClass: NoopNgZone },
    provideRouter(routes, withHashLocation()),
    provideHttpClient(),
    {
      provide: APP_INITIALIZER,
      useFactory: initializeApp,
      deps: [StoreService],
      multi: true,
    },
  ]
}).catch((err: any) => console.error(err));

// AI Studio always uses an `index.tsx` file for all project types.