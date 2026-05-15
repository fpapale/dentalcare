import { ApplicationConfig, LOCALE_ID, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeIt from '@angular/common/locales/it';
import localeEn from '@angular/common/locales/en';
import localeDe from '@angular/common/locales/de';
import localeFr from '@angular/common/locales/fr';
import { routes } from './app.routes';
import { authInterceptor } from './core/interceptors/auth.interceptor';

registerLocaleData(localeIt);
registerLocaleData(localeEn);
registerLocaleData(localeDe);
registerLocaleData(localeFr);

function resolveLocale(): string {
  try {
    const raw = localStorage.getItem('dentalcare_app_settings');
    if (raw) {
      const s = JSON.parse(raw);
      if (s?.locale && ['it', 'en', 'de', 'fr'].includes(s.locale)) return s.locale;
    }
  } catch { /* ignore */ }
  return 'it';
}

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(withInterceptors([authInterceptor])),
    { provide: LOCALE_ID, useValue: resolveLocale() }
  ]
};
