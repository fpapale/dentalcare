import { CanActivateFn, Router } from '@angular/router';
import { inject } from '@angular/core';
import { AuthService } from '../auth/auth.service';
import { UserContextService, MEDICAL_JWT_ROLES } from '../services/user-context.service';

export type RouteRole = 'admin' | 'secretary' | 'medical';

function categorize(role: string): RouteRole {
  if (role === 'admin') return 'admin';
  if (role === 'secretary') return 'secretary';
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

  // Use effective role (demo-overridden in demo mode, same as JWT in production)
  const effectiveRole = userContext.role() || userContext.authRole() || auth.getCurrentUser()?.role || '';
  const category = categorize(effectiveRole);

  if (allowed.includes(category)) return true;

  const jwtRole = userContext.authRole() || auth.getCurrentUser()?.role || '';
  return router.createUrlTree([defaultRoute(jwtRole)]);
};
