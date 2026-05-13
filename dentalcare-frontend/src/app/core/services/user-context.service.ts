import { Injectable, signal } from '@angular/core';

export type UserRole = 'secretary' | 'doctor' | 'hygienist' | 'admin';

@Injectable({ providedIn: 'root' })
export class UserContextService {
  readonly role = signal<UserRole>('doctor');
  readonly userName = signal('Dr. Verdi');
  readonly userInitials = signal('GV');
  readonly providerId = signal<string | null>(null);

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
}
