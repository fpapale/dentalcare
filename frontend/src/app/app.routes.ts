import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: 'landing', loadComponent: () => import('./features/public/landing/landing.component').then(m => m.LandingComponent) },
  { path: 'registrati', loadComponent: () => import('./features/public/registrazione/registrazione.component').then(m => m.RegistrazioneComponent) },
  { path: 'features/agenda', loadComponent: () => import('./features/public/agenda-page/agenda-page.component').then(m => m.AgendaPageComponent) },
  { path: 'features/cartella', loadComponent: () => import('./features/public/cartella-page/cartella-page.component').then(m => m.CartellaPageComponent) },
  { path: 'features/preventivi', loadComponent: () => import('./features/public/preventivi-page/preventivi-page.component').then(m => m.PreventiviPageComponent) },
  { path: 'features/magazzino', loadComponent: () => import('./features/public/magazzino-page/magazzino-page.component').then(m => m.MagazzinoPageComponent) },
  { path: 'features/richiami', loadComponent: () => import('./features/public/richiami-page/richiami-page.component').then(m => m.RichiamiPageComponent) },
  { path: '', redirectTo: 'landing', pathMatch: 'full' },
  {
    path: 'dashboard',
    loadComponent: () => import('./features/dashboard/dashboard.component').then(m => m.DashboardComponent)
  },
  {
    path: 'segretaria',
    loadComponent: () => import('./features/segretaria/segretaria.component').then(m => m.SegretariaComponent)
  },
  {
    path: 'agenda',
    loadComponent: () => import('./features/agenda/agenda.component').then(m => m.AgendaComponent)
  },
  {
    path: 'agenda/nuovo',
    loadComponent: () => import('./features/agenda/nuovo-appuntamento/nuovo-appuntamento.component').then(m => m.NuovoAppuntamentoComponent)
  },
  {
    path: 'pazienti',
    loadComponent: () => import('./features/pazienti/pazienti.component').then(m => m.PazientiComponent)
  },
  {
    path: 'pazienti/nuovo',
    loadComponent: () => import('./features/pazienti/nuovo-paziente/nuovo-paziente.component').then(m => m.NuovoPazienteComponent)
  },
  {
    path: 'pazienti/:id',
    loadComponent: () => import('./features/pazienti/paziente-detail/paziente-detail.component').then(m => m.PazienteDetailComponent)
  },
  {
    path: 'pazienti/:id/nuova-visita',
    loadComponent: () => import('./features/pazienti/nuova-visita/nuova-visita.component').then(m => m.NuovaVisitaComponent)
  },
  {
    path: 'pazienti/:id/diagnosi',
    loadComponent: () => import('./features/pazienti/diagnosi/diagnosi.component').then(m => m.DiagnosiComponent)
  },
  {
    path: 'pazienti/:id/prescrizioni',
    loadComponent: () => import('./features/pazienti/prescrizioni/prescrizioni.component').then(m => m.PrescrizioniComponent)
  },
  {
    path: 'pazienti/:id/piano-cura/:planId',
    loadComponent: () => import('./features/pazienti/piano-cura-detail/piano-cura-detail.component').then(m => m.PianoCuraDetailComponent)
  },
  {
    path: 'preventivi',
    loadComponent: () => import('./features/preventivi/preventivi.component').then(m => m.PreventiviComponent)
  },
  {
    path: 'preventivi/:estimateId',
    loadComponent: () => import('./features/preventivi/preventivo-detail/preventivo-detail.component').then(m => m.PreventivoDetailComponent)
  },
  {
    path: 'fatturazione',
    loadComponent: () => import('./features/fatturazione/fatturazione.component').then(m => m.FatturazioneComponent)
  },
  {
    path: 'fatturazione/:invoiceId',
    loadComponent: () => import('./features/fatturazione/fattura-detail/fattura-detail.component').then(m => m.FatturaDetailComponent)
  },
  {
    path: 'impostazioni',
    loadComponent: () => import('./features/impostazioni/impostazioni.component').then(m => m.ImpostazioniComponent)
  },
  {
    path: 'richiami',
    loadComponent: () => import('./features/richiami/richiami.component').then(m => m.RichiamiComponent)
  },
  {
    path: 'magazzino',
    loadComponent: () => import('./features/magazzino/magazzino.component').then(m => m.MagazzinoComponent)
  },
];
