import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  AuthUser,
  ClinicOption,
  DemoConfigResponse,
  LoginConfirmRequest,
  LoginPreflightResponse,
  LoginResponse
} from './auth.model';

interface PendingChoose {
  options: ClinicOption[];
  email: string;
  password: string;
}

const TOKEN_KEY = 'dentalcare_token';
const USER_KEY = 'dentalcare_user';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  private readonly _currentUser = signal<AuthUser | null>(this.readUserFromStorage());
  readonly currentUser = this._currentUser.asReadonly();

  private _pendingChoose: PendingChoose | null = null;

  storePendingChoose(options: ClinicOption[], email: string, password: string): void {
    this._pendingChoose = { options, email, password };
  }

  getPendingChoose(): PendingChoose | null {
    if (!this.isAuthenticated()) {
      this._pendingChoose = null;
    }
    return this._pendingChoose;
  }

  clearPendingChoose(): void {
    this._pendingChoose = null;
  }

  private storeSession(res: LoginResponse): void {
    const user: AuthUser = {
      email: res.email,
      providerId: res.providerId,
      clinicId: res.clinicId,
      role: res.role,
      firstName: res.firstName,
      lastName: res.lastName,
      schemaName: res.schemaName,
      tenantName: res.tenantName,
      token: res.token,
      mustChangePassword: res.mustChangePassword
    };
    localStorage.setItem(TOKEN_KEY, res.token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
    this._currentUser.set(user);
  }

  /** Switch session to a new token (es. "Entra in questo studio") senza logout. */
  storeLoginResponse(res: LoginResponse): void {
    this.storeSession(res);
  }

  storeDirectLogin(res: LoginPreflightResponse): void {
    if (!res.token || !res.providerId || !res.clinicId || !res.role
        || !res.firstName || !res.lastName || !res.schemaName || !res.tenantName) {
      throw new Error('Direct login response incomplete');
    }
    const user: AuthUser = {
      email: res.email,
      providerId: res.providerId,
      clinicId: res.clinicId,
      role: res.role,
      firstName: res.firstName,
      lastName: res.lastName,
      schemaName: res.schemaName,
      tenantName: res.tenantName,
      token: res.token,
      mustChangePassword: res.mustChangePassword
    };
    localStorage.setItem(TOKEN_KEY, res.token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
    this._currentUser.set(user);
  }

  login(request: { email: string; password: string }): Observable<LoginPreflightResponse> {
    return this.http.post<LoginPreflightResponse>(`${environment.apiBaseUrl}/public/login`, request);
  }

  confirmLogin(request: LoginConfirmRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${environment.apiBaseUrl}/public/login/confirm`, request).pipe(
      tap(res => this.storeSession(res))
    );
  }

  changePassword(currentPassword: string, newPassword: string): Observable<void> {
    return this.http.post<void>(`${environment.apiBaseUrl}/auth/change-password`, { currentPassword, newPassword });
  }

  forgotPassword(email: string): Observable<void> {
    return this.http.post<void>(`${environment.apiBaseUrl}/public/forgot-password`, { email });
  }

  getDemoConfig(): Observable<DemoConfigResponse> {
    return this.http.get<DemoConfigResponse>(`${environment.apiBaseUrl}/public/demo-config`);
  }

  logout(): void {
    this.clearAuthStorage();
    this.clearAllCookies();
    try { sessionStorage.clear(); } catch { /* ignore */ }
    this._currentUser.set(null);
    this._pendingChoose = null;
    this.router.navigate(['/landing']);
  }

  /** Remove JWT + user from localStorage. Sweeps any stale dentalcare_* auth key,
   *  preserving user preferences (app settings). */
  private clearAuthStorage(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    try {
      const keep = 'dentalcare_app_settings';
      for (let i = localStorage.length - 1; i >= 0; i--) {
        const key = localStorage.key(i);
        if (key && key.startsWith('dentalcare_') && key !== keep) {
          localStorage.removeItem(key);
        }
      }
    } catch { /* ignore */ }
  }

  /** Expire every cookie visible to the app (logout cleanup). */
  private clearAllCookies(): void {
    const cookies = document.cookie ? document.cookie.split(';') : [];
    for (const cookie of cookies) {
      const name = cookie.split('=')[0].trim();
      if (!name) continue;
      const expire = 'Thu, 01 Jan 1970 00:00:00 GMT';
      document.cookie = `${name}=; expires=${expire}; path=/`;
      document.cookie = `${name}=; expires=${expire}; path=/; domain=${location.hostname}`;
    }
  }

  /** Pulisce la sessione senza navigare (es. dopo cambio password forzato → re-login). */
  clearSession(): void {
    this.clearAuthStorage();
    this._currentUser.set(null);
    this._pendingChoose = null;
  }

  isAuthenticated(): boolean {
    return !!localStorage.getItem(TOKEN_KEY);
  }

  getToken(): string | null {
    return localStorage.getItem(TOKEN_KEY);
  }

  getCurrentUser(): AuthUser | null {
    return this._currentUser();
  }

  private readUserFromStorage(): AuthUser | null {
    try {
      const raw = localStorage.getItem(USER_KEY);
      return raw ? JSON.parse(raw) as AuthUser : null;
    } catch {
      return null;
    }
  }
}
