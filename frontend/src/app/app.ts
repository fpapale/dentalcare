import { Component, computed, effect, HostListener, inject, OnInit, signal, untracked } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive, Router, NavigationEnd } from '@angular/router';
import { CommonModule, NgTemplateOutlet } from '@angular/common';
import { filter } from 'rxjs/operators';
import { retry } from 'rxjs';
import { UserContextService, UserRole, MEDICAL_JWT_ROLES } from './core/services/user-context.service';
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
  userMenuOpen = signal(false);

  /** providerId of the currently authenticated user — used to detect a new login. */
  private lastAuthProviderId: string | null = null;

  readonly demoEnabled = signal(false);
  readonly demoSchema = signal<string | null>(null);
  readonly demoEmail = signal<string | null>(null);
  /**
   * Sessione demo = login con l'account demo, non semplicemente un utente del tenant
   * demo: la combo di impersonazione è un privilegio di quell'account. Filtrare solo
   * per schema la mostrava anche a medico@ e segreteria@, che devono restare sé stessi.
   */
  readonly isDemoUser = computed(() => {
    const u = this.authService.currentUser();
    const email = this.demoEmail();
    if (!u || !email || !this.demoSchema()) return false;
    return u.schemaName === this.demoSchema()
        && u.email.toLowerCase() === email.toLowerCase();
  });

  constructor() {
    // Al riavvio (docker compose up) il frontend risponde prima che il backend sia
    // pronto: un 502 transitorio lasciava demoSchema=null → il menu persona demo
    // spariva per tutta la sessione, in silenzio (#28). Ritenta durante il warm-up
    // e, se davvero irraggiungibile, logga invece di ingoiare l'errore.
    this.authService.getDemoConfig().pipe(
      retry({ count: 5, delay: 1500 })
    ).subscribe({
      next: res => {
        this.demoEnabled.set(res.enabled);
        this.demoSchema.set(res.schema ?? null);
        this.demoEmail.set(res.email ?? null);
      },
      error: err => console.warn('demo-config non raggiungibile: menu persona demo disattivato per questa sessione', err)
    });

    // Sync the displayed identity whenever the *logged-in* user changes (new login),
    // independent of the operator filter (which updates userContext but not currentUser).
    effect(() => {
      const u = this.authService.currentUser();
      if (u && u.providerId !== this.lastAuthProviderId) {
        this.lastAuthProviderId = u.providerId;
        this.userContext.initFromAuth(u);
        // Solo l'account demo parte da "Segreteria": è quello che impersona gli altri,
        // e una persona provider filtrerebbe le viste sui pazienti di quel provider,
        // lasciando le liste vuote (#30). Gli altri utenti del tenant demo conservano
        // la propria identità — initFromAuth ha già mappato ruolo e nome reali.
        const isClinicalLogin = (MEDICAL_JWT_ROLES as readonly string[]).includes(u.role);
        const demoEmail = this.demoEmail();
        const isDemoAccount = !!demoEmail
            && u.schemaName === this.demoSchema()
            && u.email.toLowerCase() === demoEmail.toLowerCase();
        if (isDemoAccount && !isClinicalLogin) {
          this.selectedKey.set('__secretary__');
          this.userContext.setRole('secretary');
        } else {
          this.selectedKey.set(u.providerId);
        }
        this.loadAppData();
      }
    }, { allowSignalWrites: true });
  }

  toggleUserMenu(event: Event): void {
    event.stopPropagation();
    this.userMenuOpen.update(v => !v);
  }

  closeUserMenu(): void {
    this.userMenuOpen.set(false);
  }

  /** Close the operator menu on any click outside it. */
  @HostListener('document:click')
  onDocumentClick(): void {
    if (this.userMenuOpen()) this.userMenuOpen.set(false);
  }

  logout(): void {
    this.closeUserMenu();
    this.authService.logout();
  }

  goHome(): void {
    const items = this.navItems();
    if (items.length) this.router.navigate([items[0].path]);
  }

  readonly showImpostazioni = computed(() => {
    return this.userContext.role() === 'admin';
  });

  readonly navItems = computed(() => {
    const r = this.userContext.role();
    if (this.userContext.authRole() === 'tenant_admin') return [];
    const allItems = [
      { path: '/dashboard',    icon: 'dashboard',            label: 'Dashboard' },
      ...(['secretary', 'doctor'].includes(r) ? [{ path: '/segretaria', icon: 'smart_toy', label: 'Copilot AI' }] : []),
      { path: '/agenda',       icon: 'event',                label: 'Agenda' },
      { path: '/pazienti',     icon: 'folder_shared',        label: 'Pazienti' },
      { path: '/preventivi',   icon: 'description',          label: 'Preventivi' },
      { path: '/fatturazione', icon: 'receipt_long',         label: 'Fatturazione' },
      { path: '/richiami',     icon: 'notifications_active', label: 'Richiami' },
      { path: '/magazzino',    icon: 'inventory_2',          label: 'Magazzino' },
      ...(['admin', 'doctor'].includes(r) ? [{ path: '/prestazioni', icon: 'medical_services', label: 'Prestazioni' }] : []),
    ];
    return allItems;
  });

  private isPublic(url: string): boolean {
    return url.startsWith('/landing') || url.startsWith('/registrati') || url.startsWith('/features/') || url.startsWith('/login') || url.startsWith('/admin-tenant');
  }

  ngOnInit(): void {
    // Identity sync is handled reactively by the effect in the constructor.
    this.isPublicRoute.set(this.isPublic(this.router.url));
    this.router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(e => {
      this.isPublicRoute.set(this.isPublic((e as NavigationEnd).urlAfterRedirects));
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
    if (r.includes('segret') || r.includes('secret')) return 'secretary';
    return 'doctor';
  }
}
