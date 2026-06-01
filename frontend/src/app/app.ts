import { Component, computed, inject, OnInit, signal } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { CommonModule, NgTemplateOutlet } from '@angular/common';
import { filter } from 'rxjs/operators';
import { UserContextService, UserRole } from './core/services/user-context.service';
import { ProviderService } from './core/services/provider.service';
import { Provider } from './core/models/provider.model';
import { LayoutService } from './core/services/layout.service';
import { AuthService } from './core/auth/auth.service';
import { ClinicSettingsService } from './core/services/clinic-settings.service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink, RouterLinkActive, CommonModule, NgTemplateOutlet],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit {
  private readonly userContext   = inject(UserContextService);
  private readonly providerService = inject(ProviderService);
  private readonly layoutService = inject(LayoutService);
  private readonly router        = inject(Router);
  private readonly authService   = inject(AuthService);
  private readonly clinicSettingsService = inject(ClinicSettingsService);

  readonly rightPanel = this.layoutService.rightPanel;
  readonly isPublicRoute = signal(false);

  title = 'dentalcare-frontend';

  readonly currentRole = this.userContext.role;
  readonly currentUserName = this.userContext.userName;
  readonly currentUserInitials = this.userContext.userInitials;
  today = new Date();
  readonly clinicName = this.userContext.clinicName;
  readonly tenantName = this.userContext.tenantName;

  providers = signal<Provider[]>([]);
  selectedKey = signal<string>('__secretary__');

  readonly showImpostazioni = computed(() => {
    const r = this.userContext.authRole();
    return r === 'admin';
  });

  readonly navItems = computed(() => {
    const r = this.userContext.authRole();
    if (r === 'tenant_admin') return [];
    const allItems = [
      { path: '/agenda',       icon: 'event',                label: 'Agenda' },
      { path: '/pazienti',     icon: 'folder_shared',        label: 'Pazienti' },
      { path: '/preventivi',   icon: 'description',          label: 'Preventivi' },
      { path: '/fatturazione', icon: 'receipt_long',         label: 'Fatturazione' },
      { path: '/richiami',     icon: 'notifications_active', label: 'Richiami' },
      { path: '/magazzino',    icon: 'inventory_2',          label: 'Magazzino' },
    ];
    return allItems;
  });

  private isPublic(url: string): boolean {
    return url.startsWith('/landing') || url.startsWith('/registrati') || url.startsWith('/features/') || url.startsWith('/login') || url.startsWith('/admin-tenant');
  }

  ngOnInit(): void {
    const user = this.authService.getCurrentUser();
    if (user) {
      this.userContext.initFromAuth(user);
      this.selectedKey.set(user.providerId);
      this.loadAppData();
    }
    this.isPublicRoute.set(this.isPublic(this.router.url));
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(e => {
      const url = (e as NavigationEnd).urlAfterRedirects;
      this.isPublicRoute.set(this.isPublic(url));
      if (!this.isPublic(url) && this.providers().length === 0 && this.authService.isAuthenticated()) {
        const u = this.authService.getCurrentUser();
        if (u) { this.userContext.initFromAuth(u); this.selectedKey.set(u.providerId); }
        this.loadAppData();
      }
    });
  }

  private loadAppData(): void {
    this.clinicSettingsService.get().subscribe({
      next: c => this.userContext.setClinicName(c.name),
      error: () => {}
    });
    this.providerService.findAll().subscribe({
      next: list => this.providers.set(list),
      error: () => {}
    });
  }

  onUserChange(event: Event): void {
    const value = (event.target as HTMLSelectElement).value;
    this.selectedKey.set(value);
    if (value === '__secretary__') {
      this.userContext.setRole('secretary');
      return;
    }
    const provider = this.providers().find(p => p.providerId === value);
    if (!provider) return;
    const initials = `${provider.firstName?.[0] ?? ''}${provider.lastName?.[0] ?? ''}`.toUpperCase();
    this.userContext.setProvider(provider.providerId, provider.fullName, initials, this.mapRole(provider.role));
  }

  providerIcon(role: string): string {
    const r = role.toLowerCase();
    if (r.includes('igien') || r.includes('hygien')) return '🦷';
    if (r.includes('admin')) return '🔑';
    return '👨‍⚕️';
  }

  private mapRole(role: string): UserRole {
    const r = role.toLowerCase();
    if (r.includes('igien') || r.includes('hygien')) return 'hygienist';
    if (r.includes('admin')) return 'admin';
    return 'doctor';
  }
}
