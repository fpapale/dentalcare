import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { environment } from '../../../environments/environment';
import { UserContextService } from '../../core/services/user-context.service';
import { AdminTenantService } from './admin-tenant.service';
import {
  CreateTenantClinicRequest,
  CreateTenantUserRequest,
  TenantClinicDto,
  TenantUserDto
} from './admin-tenant.model';

const AVAILABLE_ROLES = ['admin', 'doctor', 'hygienist', 'orthodontist', 'surgeon', 'assistant', 'other'] as const;

const emptyClinicForm = (): CreateTenantClinicRequest => ({ name: '', city: '', email: '' });
const emptyUserForm = (): CreateTenantUserRequest => ({
  firstName: '', lastName: '', email: '', password: '', role: 'doctor'
});

@Component({
  selector: 'app-admin-tenant',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin-tenant.component.html'
})
export class AdminTenantComponent implements OnInit {
  private readonly userContext = inject(UserContextService);
  private readonly api = inject(AdminTenantService);

  readonly tenantName = this.userContext.tenantName;
  readonly userName = this.userContext.userName;
  readonly userInitials = this.userContext.userInitials;

  readonly availableRoles = AVAILABLE_ROLES;
  readonly apiBase = environment.apiBaseUrl;

  readonly clinics = signal<TenantClinicDto[]>([]);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);

  readonly showCreateClinic = signal(false);
  readonly creatingClinic = signal(false);
  readonly clinicForm = signal<CreateTenantClinicRequest>(emptyClinicForm());

  readonly expandedClinicId = signal<string | null>(null);
  readonly clinicUsers = signal<Map<string, TenantUserDto[]>>(new Map());
  readonly usersLoading = signal<string | null>(null);

  readonly showCreateUser = signal<string | null>(null);
  readonly creatingUser = signal(false);
  readonly userForm = signal<CreateTenantUserRequest>(emptyUserForm());

  readonly confirmDeleteClinicId = signal<string | null>(null);
  readonly deletingClinicId = signal<string | null>(null);

  ngOnInit(): void {
    this.loadClinics();
  }

  downloadExport(): void {
    window.location.href = `${environment.apiBaseUrl}/tenant-admin/export`;
  }

  loadClinics(): void {
    this.loading.set(true);
    this.error.set(null);
    this.api.getClinics().subscribe({
      next: (list) => {
        this.clinics.set(list);
        this.loading.set(false);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Errore nel caricamento delle cliniche.'));
        this.loading.set(false);
      }
    });
  }

  toggleCreateClinic(): void {
    this.showCreateClinic.update(v => !v);
    if (this.showCreateClinic()) {
      this.clinicForm.set(emptyClinicForm());
      this.error.set(null);
    }
  }

  submitCreateClinic(): void {
    const form = this.clinicForm();
    if (!form.name?.trim()) {
      this.error.set('Il nome della clinica è obbligatorio.');
      return;
    }
    this.creatingClinic.set(true);
    this.error.set(null);
    const payload: CreateTenantClinicRequest = {
      name: form.name.trim(),
      city: form.city?.trim() || undefined,
      email: form.email?.trim() || undefined
    };
    this.api.createClinic(payload).subscribe({
      next: (created) => {
        this.clinics.update(list => [...list, created].sort((a, b) => a.name.localeCompare(b.name)));
        this.showCreateClinic.set(false);
        this.clinicForm.set(emptyClinicForm());
        this.creatingClinic.set(false);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Errore nella creazione della clinica.'));
        this.creatingClinic.set(false);
      }
    });
  }

  toggleClinicUsers(clinicId: string): void {
    if (this.expandedClinicId() === clinicId) {
      this.expandedClinicId.set(null);
      this.showCreateUser.set(null);
      return;
    }
    this.expandedClinicId.set(clinicId);
    this.showCreateUser.set(null);
    if (!this.clinicUsers().has(clinicId)) {
      this.loadUsers(clinicId);
    }
  }

  private loadUsers(clinicId: string): void {
    this.usersLoading.set(clinicId);
    this.api.getUsers(clinicId).subscribe({
      next: (users) => {
        this.clinicUsers.update(map => {
          const next = new Map(map);
          next.set(clinicId, users);
          return next;
        });
        this.usersLoading.set(null);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Errore nel caricamento degli utenti.'));
        this.usersLoading.set(null);
      }
    });
  }

  usersFor(clinicId: string): TenantUserDto[] {
    return this.clinicUsers().get(clinicId) ?? [];
  }

  toggleCreateUser(clinicId: string): void {
    if (this.showCreateUser() === clinicId) {
      this.showCreateUser.set(null);
    } else {
      this.userForm.set(emptyUserForm());
      this.showCreateUser.set(clinicId);
      this.error.set(null);
    }
  }

  submitCreateUser(clinicId: string): void {
    const form = this.userForm();
    if (!form.firstName?.trim() || !form.lastName?.trim() || !form.email?.trim() || !form.password || !form.role) {
      this.error.set('Tutti i campi sono obbligatori.');
      return;
    }
    if (form.password.length < 8) {
      this.error.set('La password deve avere almeno 8 caratteri.');
      return;
    }
    this.creatingUser.set(true);
    this.error.set(null);
    const payload: CreateTenantUserRequest = {
      firstName: form.firstName.trim(),
      lastName: form.lastName.trim(),
      email: form.email.trim(),
      password: form.password,
      role: form.role
    };
    this.api.createUser(clinicId, payload).subscribe({
      next: (created) => {
        this.clinicUsers.update(map => {
          const next = new Map(map);
          const current = next.get(clinicId) ?? [];
          next.set(clinicId, [...current, created].sort((a, b) =>
            (a.lastName + a.firstName).localeCompare(b.lastName + b.firstName)
          ));
          return next;
        });
        this.showCreateUser.set(null);
        this.userForm.set(emptyUserForm());
        this.creatingUser.set(false);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Errore nella creazione dell\'utente.'));
        this.creatingUser.set(false);
      }
    });
  }

  askDeleteClinic(clinicId: string): void {
    this.confirmDeleteClinicId.set(clinicId);
  }

  cancelDeleteClinic(): void {
    this.confirmDeleteClinicId.set(null);
  }

  confirmDeleteClinic(clinicId: string): void {
    this.deletingClinicId.set(clinicId);
    this.error.set(null);
    this.api.deleteClinic(clinicId).subscribe({
      next: () => {
        this.clinics.update(list => list.filter(c => c.id !== clinicId));
        this.clinicUsers.update(map => {
          const next = new Map(map);
          next.delete(clinicId);
          return next;
        });
        if (this.expandedClinicId() === clinicId) {
          this.expandedClinicId.set(null);
        }
        this.confirmDeleteClinicId.set(null);
        this.deletingClinicId.set(null);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Impossibile eliminare la clinica.'));
        this.deletingClinicId.set(null);
        this.confirmDeleteClinicId.set(null);
      }
    });
  }

  updateClinicField<K extends keyof CreateTenantClinicRequest>(key: K, value: CreateTenantClinicRequest[K]): void {
    this.clinicForm.update(f => ({ ...f, [key]: value }));
  }

  updateUserField<K extends keyof CreateTenantUserRequest>(key: K, value: CreateTenantUserRequest[K]): void {
    this.userForm.update(f => ({ ...f, [key]: value }));
  }

  private extractError(err: HttpErrorResponse, fallback: string): string {
    if (err.status === 409) {
      return err.error?.message || 'Operazione non consentita: conflitto sullo stato dei dati.';
    }
    if (err.status === 400) {
      return err.error?.message || 'Richiesta non valida.';
    }
    if (err.status === 403) {
      return 'Accesso non autorizzato.';
    }
    return err.error?.message || fallback;
  }
}
