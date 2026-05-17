import { Component, inject, OnInit, signal } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { CommonModule, NgTemplateOutlet } from '@angular/common';
import { filter } from 'rxjs/operators';
import { UserContextService, UserRole } from './core/services/user-context.service';
import { ProviderService } from './core/services/provider.service';
import { Provider } from './core/models/provider.model';
import { LayoutService } from './core/services/layout.service';

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

  readonly rightPanel = this.layoutService.rightPanel;
  readonly isPublicRoute = signal(false);

  title = 'dentalcare-frontend';

  readonly currentRole = this.userContext.role;
  readonly currentUserName = this.userContext.userName;
  readonly currentUserInitials = this.userContext.userInitials;
  currentTenant = signal('12345678-1234-1234-1234-123456789012');
  currentStudio = signal('Studio Roma Centro');

  providers = signal<Provider[]>([]);
  selectedKey = signal<string>('__secretary__');

  navItems = [
    { path: '/dashboard', icon: 'home', label: 'Dashboard' },
    { path: '/segretaria', icon: 'forum', label: 'SegretarIA' },
    { path: '/agenda', icon: 'event', label: 'Agenda' },
    { path: '/pazienti', icon: 'folder_shared', label: 'Pazienti' },
    { path: '/preventivi', icon: 'description', label: 'Preventivi' },
    { path: '/fatturazione', icon: 'receipt_long', label: 'Fatturazione' },
    { path: '/richiami', icon: 'notifications_active', label: 'Richiami' },
    { path: '/magazzino', icon: 'inventory_2', label: 'Magazzino' },
  ];

  private isPublic(url: string): boolean {
    return url.startsWith('/landing') || url.startsWith('/registrati');
  }

  ngOnInit(): void {
    this.userContext.setRole('secretary');
    this.providerService.findAll().subscribe({
      next: list => this.providers.set(list),
      error: () => {}
    });
    this.isPublicRoute.set(this.isPublic(this.router.url));
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(e => {
      this.isPublicRoute.set(this.isPublic((e as NavigationEnd).urlAfterRedirects));
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
