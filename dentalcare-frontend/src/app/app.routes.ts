import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
  {
    path: 'dashboard',
    loadComponent: () => import('./pages/dashboard/dashboard.component').then(m => m.DashboardComponent)
  },
  {
    path: 'segretaria',
    loadComponent: () => import('./pages/segretaria/segretaria.component').then(m => m.SegretariaComponent)
  },
  {
    path: 'agenda',
    loadComponent: () => import('./pages/agenda/agenda.component').then(m => m.AgendaComponent)
  },
  {
    path: 'agenda/nuovo',
    loadComponent: () => import('./pages/agenda/nuovo-appuntamento/nuovo-appuntamento.component').then(m => m.NuovoAppuntamentoComponent)
  },
  {
    path: 'pazienti',
    loadComponent: () => import('./pages/pazienti/pazienti.component').then(m => m.PazientiComponent)
  },
  {
    path: 'pazienti/nuovo',
    loadComponent: () => import('./pages/pazienti/nuovo-paziente/nuovo-paziente.component').then(m => m.NuovoPazienteComponent)
  },
  {
    path: 'pazienti/:id',
    loadComponent: () => import('./pages/pazienti/paziente-detail/paziente-detail.component').then(m => m.PazienteDetailComponent)
  },
  {
    path: 'pazienti/:id/cartella',
    loadComponent: () => import('./pages/pazienti/cartella-clinica/cartella-clinica.component').then(m => m.CartellaClinciComponent)
  },
  {
    path: 'preventivi',
    loadComponent: () => import('./pages/preventivi/preventivi.component').then(m => m.PreventiviComponent)
  },
  {
    path: 'fatturazione',
    loadComponent: () => import('./pages/fatturazione/fatturazione.component').then(m => m.FatturazioneComponent)
  },
  {
    path: 'richiami',
    loadComponent: () => import('./pages/richiami/richiami.component').then(m => m.RichiamiComponent)
  },
  {
    path: 'magazzino',
    loadComponent: () => import('./pages/magazzino/magazzino.component').then(m => m.MagazzinoComponent)
  },
];
