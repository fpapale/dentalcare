import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
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
    path: 'preventivi',
    loadComponent: () => import('./features/preventivi/preventivi.component').then(m => m.PreventiviComponent)
  },
  {
    path: 'fatturazione',
    loadComponent: () => import('./features/fatturazione/fatturazione.component').then(m => m.FatturazioneComponent)
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
