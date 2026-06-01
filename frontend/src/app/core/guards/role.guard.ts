import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { UserContextService, MEDICAL_JWT_ROLES } from '../services/user-context.service';

export type RouteRole = 'admin' | 'secretary' | 'medical';

function resolveJwtRole(userContext: UserContextService, auth: AuthService): string {
  return userContext.authRole() || auth.getCurrentUser()?.role || '';
}

function categorize(jwtRole: string): RouteRole {
  if (jwtRole === 'admin') return 'admin';
  if (jwtRole === 'secretary') return 'secretary';
  return 'medical';
}

function defaultRoute(jwtRole: string): string {
  if (jwtRole === 'tenant_admin') return '/admin-tenant';
  return '/dashboard';
}

export const roleGuard = (...allowed: RouteRole[]): CanActivateFn => () => {
  const auth = inject(AuthService);
  const userContext = inject(UserContextService);
  const router = inject(Router);

  if (!auth.isAuthenticated()) {
    return router.createUrlTree(['/login']);
  }

  const jwtRole = resolveJwtRole(userContext, auth);
  const category = categorize(jwtRole);

  if (allowed.includes(category)) return true;

  return router.createUrlTree([defaultRoute(jwtRole)]);
};
