import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';
import { tenantAdminGuard } from './core/guards/tenant-admin.guard';
import { roleGuard } from './core/guards/role.guard';

export const routes: Routes = [
  { path: 'login', loadComponent: () => import('./features/login/login.component').then(m => m.LoginComponent) },
  { path: 'landing', loadComponent: () => import('./features/public/landing/landing.component').then(m => m.LandingComponent) },
  { path: 'registrati', loadComponent: () => import('./features/public/registrazione/registrazione.component').then(m => m.RegistrazioneComponent) },
  { path: 'features/agenda', loadComponent: () => import('./features/public/agenda-page/agenda-page.component').then(m => m.AgendaPageComponent) },
  { path: 'features/cartella', loadComponent: () => import('./features/public/cartella-page/cartella-page.component').then(m => m.CartellaPageComponent) },
  { path: 'features/preventivi', loadComponent: () => import('./features/public/preventivi-page/preventivi-page.component').then(m => m.PreventiviPageComponent) },
  { path: 'features/magazzino', loadComponent: () => import('./features/public/magazzino-page/magazzino-page.component').then(m => m.MagazzinoPageComponent) },
  { path: 'features/richiami', loadComponent: () => import('./features/public/richiami-page/richiami-page.component').then(m => m.RichiamiPageComponent) },
  { path: '', redirectTo: 'landing', pathMatch: 'full' },

  // dashboard: admin + secretary + medical
  {
    path: 'dashboard',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent)
  },
  // SegretarIA AI: secretary only
  {
    path: 'segretaria',
    canActivate: [authGuard, roleGuard('secretary')],
    loadComponent: () => import('./features/segretaria/segretaria.component').then(m => m.SegretariaComponent)
  },

  // AGENDA: admin + secretary + medical
  {
    path: 'agenda',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/agenda/agenda.component').then(m => m.AgendaComponent)
  },
  {
    path: 'agenda/nuovo',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/agenda/nuovo-appuntamento/nuovo-appuntamento.component').then(m => m.NuovoAppuntamentoComponent)
  },

  // PAZIENTI lista: admin + secretary + medical
  {
    path: 'pazienti',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/pazienti/pazienti.component').then(m => m.PazientiComponent)
  },
  // Nuovo paziente: admin + secretary
  {
    path: 'pazienti/nuovo',
    canActivate: [authGuard, roleGuard('admin', 'secretary')],
    loadComponent: () => import('./features/pazienti/nuovo-paziente/nuovo-paziente.component').then(m => m.NuovoPazienteComponent)
  },
  // Scheda paziente (panoramica, richiami, preventivi da scheda): secretary + medical
  {
    path: 'pazienti/:id',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/pazienti/paziente-detail/paziente-detail.component').then(m => m.PazienteDetailComponent)
  },
  // Cartella clinica: admin + medical
  {
    path: 'pazienti/:id/nuova-visita',
    canActivate: [authGuard, roleGuard('admin', 'medical')],
    loadComponent: () => import('./features/pazienti/nuova-visita/nuova-visita.component').then(m => m.NuovaVisitaComponent)
  },
  {
    path: 'pazienti/:id/diagnosi',
    canActivate: [authGuard, roleGuard('admin', 'medical')],
    loadComponent: () => import('./features/pazienti/diagnosi/diagnosi.component').then(m => m.DiagnosiComponent)
  },
  {
    path: 'pazienti/:id/prescrizioni',
    canActivate: [authGuard, roleGuard('admin', 'medical')],
    loadComponent: () => import('./features/pazienti/prescrizioni/prescrizioni.component').then(m => m.PrescrizioniComponent)
  },
  {
    path: 'pazienti/:id/visita/:entryId',
    canActivate: [authGuard, roleGuard('admin', 'medical')],
    loadComponent: () => import('./features/pazienti/visita-detail/visita-detail.component').then(m => m.VisitaDetailComponent)
  },
  {
    path: 'pazienti/:id/piano-cura/:planId',
    canActivate: [authGuard, roleGuard('admin', 'medical')],
    loadComponent: () => import('./features/pazienti/piano-cura-detail/piano-cura-detail.component').then(m => m.PianoCuraDetailComponent)
  },

  // PREVENTIVI: admin + secretary + medical (backend non filtra per admin)
  {
    path: 'preventivi',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/preventivi/preventivi.component').then(m => m.PreventiviComponent)
  },
  {
    path: 'preventivi/:estimateId',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/preventivi/preventivo-detail/preventivo-detail.component').then(m => m.PreventivoDetailComponent)
  },

  // FATTURAZIONE: admin + secretary + medical (backend non filtra per admin)
  {
    path: 'fatturazione',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/fatturazione/fatturazione.component').then(m => m.FatturazioneComponent)
  },
  {
    path: 'fatturazione/:invoiceId',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/fatturazione/fattura-detail/fattura-detail.component').then(m => m.FatturaDetailComponent)
  },

  // IMPOSTAZIONI: admin
  {
    path: 'impostazioni',
    canActivate: [authGuard, roleGuard('admin')],
    loadComponent: () => import('./features/impostazioni/impostazioni.component').then(m => m.ImpostazioniComponent)
  },

  // RICHIAMI: admin + secretary + medical (backend non filtra per admin)
  {
    path: 'richiami',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/richiami/richiami.component').then(m => m.RichiamiComponent)
  },
  // MAGAZZINO: admin + secretary + medical
  {
    path: 'magazzino',
    canActivate: [authGuard, roleGuard('admin', 'secretary', 'medical')],
    loadComponent: () => import('./features/magazzino/magazzino.component').then(m => m.MagazzinoComponent)
  },

  // ADMIN TENANT: solo tenant_admin
  {
    path: 'admin-tenant',
    canActivate: [tenantAdminGuard],
    loadComponent: () => import('./features/admin-tenant/admin-tenant.component').then(m => m.AdminTenantComponent)
  },
];
