import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { UserContextService } from '../services/user-context.service';

export const tenantAdminGuard: CanActivateFn = () => {
  const userContext = inject(UserContextService);
  const router = inject(Router);
  if (userContext.role() === 'admin') {
    return true;
  }
  return router.createUrlTree(['/dashboard']);
};
