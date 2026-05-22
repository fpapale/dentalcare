import { Injectable, inject, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../../environments/environment';
import { AuthUser, LoginRequest, LoginResponse } from './auth.model';

const TOKEN_KEY = 'dentalcare_token';
const USER_KEY = 'dentalcare_user';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  private readonly _currentUser = signal<AuthUser | null>(this.readUserFromStorage());
  readonly currentUser = this._currentUser.asReadonly();

  private storeSession(res: LoginResponse): void {
    const user: AuthUser = {
      providerId: res.providerId,
      clinicId: res.clinicId,
      role: res.role,
      firstName: res.firstName,
      lastName: res.lastName,
      schemaName: res.schemaName,
      tenantName: res.tenantName,
      token: res.token
    };
    localStorage.setItem(TOKEN_KEY, res.token);
    localStorage.setItem(USER_KEY, JSON.stringify(user));
    this._currentUser.set(user);
  }

  login(request: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${environment.apiBaseUrl}/public/login`, request).pipe(
      tap(res => this.storeSession(res))
    );
  }

  getDemoToken(): Observable<LoginResponse> {
    return this.http.get<LoginResponse>(`${environment.apiBaseUrl}/public/demo-token`).pipe(
      tap(res => this.storeSession(res))
    );
  }

  logout(): void {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(USER_KEY);
    this._currentUser.set(null);
    this.router.navigate(['/login']);
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
