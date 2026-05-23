import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../auth/auth.service';

export const tenantAdminGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  const user = auth.getCurrentUser();
  if (user && (user.role === 'tenant_admin' || user.role === 'admin')) {
    return true;
  }
  return router.createUrlTree(['/dashboard']);
};
