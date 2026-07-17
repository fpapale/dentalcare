import { Injectable, computed, signal } from '@angular/core';
import { AuthUser } from '../auth/auth.model';

export type UserRole = 'secretary' | 'doctor' | 'hygienist' | 'admin';

/** Ruoli JWT clinici. Allineato a DentalCareAiTools.MEDICAL_ROLES lato backend. */
export const MEDICAL_JWT_ROLES = ['dentist', 'doctor', 'hygienist', 'orthodontist', 'surgeon'] as const;

@Injectable({ providedIn: 'root' })
export class UserContextService {
  readonly role = signal<UserRole>('doctor');
  /** JWT role — set once on login, never changed by context switch */
  readonly authRole = signal<string>('');
  readonly userName = signal('Dr. Verdi');
  readonly userInitials = signal('GV');
  /** Identità del provider corrente. Usare per l'autore di un record, non come filtro di vista. */
  readonly providerId = signal<string | null>(null);
  readonly clinicName = signal<string | null>(null);
  readonly tenantName = signal<string | null>(null);

  /**
   * providerId da passare alle API come filtro di vista.
   *
   * Solo i ruoli clinici filtrano sui propri pazienti; segreteria e amministrazione
   * vedono l'intero studio e devono passare `null` (il backend interpreta il parametro
   * assente come "nessun filtro" — vedi PatientService.findAll).
   *
   * Passare qui l'identità di una segretaria svuota agenda e lista pazienti: non è mai
   * il provider di un paziente, quindi il filtro non trova nulla.
   */
  readonly filterProviderId = computed(() =>
    this.role() === 'doctor' || this.role() === 'hygienist' ? this.providerId() : null
  );

  private readonly roleMap: Record<UserRole, { name: string; initials: string }> = {
    secretary: { name: 'Maria Rossi', initials: 'MR' },
    doctor:    { name: 'Dr. Verdi',   initials: 'GV' },
    hygienist: { name: 'Lucia Bianchi', initials: 'LB' },
    admin:     { name: 'Admin',       initials: 'AD' },
  };

  setRole(role: UserRole): void {
    const info = this.roleMap[role];
    this.role.set(role);
    this.userName.set(info.name);
    this.userInitials.set(info.initials);
    this.providerId.set(null);
  }

  setProvider(providerId: string, name: string, initials: string, role: UserRole): void {
    this.providerId.set(providerId);
    this.role.set(role);
    this.userName.set(name);
    this.userInitials.set(initials);
  }

  setClinicName(name: string): void {
    this.clinicName.set(name);
  }

  initFromAuth(user: AuthUser): void {
    this.authRole.set(user.role);

    const mappedRole: UserRole =
      user.role === 'admin' || user.role === 'tenant_admin' ? 'admin'
      : user.role === 'secretary' ? 'secretary'
      : user.role === 'hygienist' ? 'hygienist'
      : 'doctor';

    const fullName = `${user.firstName} ${user.lastName}`;
    const name = mappedRole === 'doctor' || mappedRole === 'hygienist'
      ? `Dr. ${fullName}`
      : fullName;

    const initials = `${user.firstName[0] ?? ''}${user.lastName[0] ?? ''}`.toUpperCase();

    this.role.set(mappedRole);
    this.userName.set(name);
    this.userInitials.set(initials);
    this.providerId.set(user.providerId);
    this.tenantName.set(user.tenantName ?? null);
  }
}
