export interface Appointment {
  appointmentId: string;
  startsAt: string;
  endsAt: string;
  chairLabel: string;
  appointmentStatus: string;
  notes: string | null;
  patientId: string;
  patientFullName: string;
  patientPhone: string | null;
  providerId: string;
  providerName: string;
  providerRole: string;
  serviceName: string | null;
  serviceCategory: string | null;
  toothNumber: string | null;
  hasAllergyAlert: boolean;
  hasMedicationAlert: boolean;
}
