import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { environment } from '../../../environments/environment';
import { UserContextService } from '../../core/services/user-context.service';
import { AuthService } from '../../core/auth/auth.service';
import { AdminTenantService } from './admin-tenant.service';
import {
  CreateTenantClinicRequest,
  CreateTenantUserRequest,
  TenantClinicDto,
  TenantUserDto
} from './admin-tenant.model';

const AVAILABLE_ROLES = ['admin', 'secretary', 'doctor', 'hygienist', 'orthodontist', 'surgeon', 'assistant', 'other'] as const;

const emptyClinicForm = (): CreateTenantClinicRequest => ({ name: '', city: '', email: '' });
const emptyUserForm = (): CreateTenantUserRequest => ({
  firstName: '', lastName: '', email: '', role: 'doctor'
});

@Component({
  selector: 'app-admin-tenant',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './admin-tenant.component.html'
})
export class AdminTenantComponent implements OnInit {
  private readonly userContext = inject(UserContextService);
  private readonly auth = inject(AuthService);
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

  readonly deleteTargetClinic = signal<TenantClinicDto | null>(null);
  readonly deletingClinicId = signal<string | null>(null);
  readonly addingSelfToClinicId = signal<string | null>(null);
  readonly selfAdminClinicIds = signal<Set<string>>(new Set());

  ngOnInit(): void {
    this.loadClinics();
    this.loadSelfAdminClinics();
  }

  private loadSelfAdminClinics(): void {
    this.api.getSelfAdminClinicIds().subscribe({
      next: (ids) => this.selfAdminClinicIds.set(new Set(ids)),
      error: () => {}
    });
  }

  isSelfAdmin(clinicId: string): boolean {
    return this.selfAdminClinicIds().has(clinicId);
  }

  downloadExport(): void {
    const token = this.auth.getToken();
    window.location.href = `${environment.apiBaseUrl}/tenant-admin/export?token=${token}`;
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
        this.error.set(this.extractError(err, 'Errore nel caricamento degli studi.'));
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
      this.error.set('Il nome dello studio è obbligatorio.');
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
        this.error.set(this.extractError(err, 'Errore nella creazione dello studio.'));
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
    if (!form.firstName?.trim() || !form.lastName?.trim() || !form.email?.trim() || !form.role) {
      this.error.set('Tutti i campi sono obbligatori.');
      return;
    }
    this.creatingUser.set(true);
    this.error.set(null);
    const payload: CreateTenantUserRequest = {
      firstName: form.firstName.trim(),
      lastName: form.lastName.trim(),
      email: form.email.trim(),
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

  askDeleteClinic(clinic: TenantClinicDto): void {
    this.deleteTargetClinic.set(clinic);
  }

  cancelDeleteClinic(): void {
    this.deleteTargetClinic.set(null);
  }

  downloadClinicExport(clinicId: string): void {
    const token = this.auth.getToken();
    window.location.href = `${this.apiBase}/tenant-admin/clinics/${clinicId}/export?token=${token}`;
  }

  confirmDeleteClinic(): void {
    const clinic = this.deleteTargetClinic();
    if (!clinic) return;
    this.deletingClinicId.set(clinic.id);
    this.error.set(null);
    this.api.deleteClinic(clinic.id).subscribe({
      next: () => {
        this.clinics.update(list => list.filter(c => c.id !== clinic.id));
        this.clinicUsers.update(map => {
          const next = new Map(map);
          next.delete(clinic.id);
          return next;
        });
        if (this.expandedClinicId() === clinic.id) {
          this.expandedClinicId.set(null);
        }
        this.deleteTargetClinic.set(null);
        this.deletingClinicId.set(null);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Impossibile eliminare lo studio.'));
        this.deletingClinicId.set(null);
        this.deleteTargetClinic.set(null);
      }
    });
  }

  toggleSelfAdmin(clinicId: string): void {
    if (this.isSelfAdmin(clinicId)) {
      this.removeSelfAdmin(clinicId);
    } else {
      this.addSelfAdmin(clinicId);
    }
  }

  private addSelfAdmin(clinicId: string): void {
    this.addingSelfToClinicId.set(clinicId);
    this.error.set(null);
    this.api.addSelfAsAdmin(clinicId).subscribe({
      next: (created) => {
        this.selfAdminClinicIds.update(s => new Set([...s, clinicId]));
        this.clinicUsers.update(map => {
          const next = new Map(map);
          const current = next.get(clinicId) ?? [];
          if (!current.some(u => u.id === created.id)) {
            next.set(clinicId, [...current, created].sort((a, b) =>
              (a.lastName + a.firstName).localeCompare(b.lastName + b.firstName)
            ));
          }
          return next;
        });
        this.addingSelfToClinicId.set(null);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Errore durante l\'aggiunta come amministratore.'));
        this.addingSelfToClinicId.set(null);
      }
    });
  }

  private removeSelfAdmin(clinicId: string): void {
    this.addingSelfToClinicId.set(clinicId);
    this.error.set(null);
    this.api.removeSelfAsAdmin(clinicId).subscribe({
      next: () => {
        this.selfAdminClinicIds.update(s => {
          const next = new Set(s);
          next.delete(clinicId);
          return next;
        });
        this.clinicUsers.update(map => {
          const next = new Map(map);
          next.delete(clinicId);
          return next;
        });
        this.addingSelfToClinicId.set(null);
      },
      error: (err: HttpErrorResponse) => {
        this.error.set(this.extractError(err, 'Errore durante la rimozione come amministratore.'));
        this.addingSelfToClinicId.set(null);
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
