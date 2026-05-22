import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { UserContextService } from '../../core/services/user-context.service';

@Component({
  selector: 'app-admin-tenant',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './admin-tenant.component.html'
})
export class AdminTenantComponent {
  private readonly userContext = inject(UserContextService);

  readonly tenantName = this.userContext.tenantName;
  readonly userName = this.userContext.userName;
  readonly userInitials = this.userContext.userInitials;
}
