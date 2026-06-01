export interface Provider {
  providerId: string;
  firstName: string;
  lastName: string;
  fullName: string;
  role: string;
  phone: string | null;
  email: string | null;
  active: boolean;
  vatNumber: string | null;
  fiscalCode: string | null;
  professionalRegister: string | null;
  registerNumber: string | null;
  billingAddressStreet: string | null;
  billingAddressZip: string | null;
  billingAddressCity: string | null;
  billingAddressProvince: string | null;
  billingPec: string | null;
  billingIban: string | null;
  billingSdiCode: string | null;
  invoicePrefix: string | null;
  photoUrl?: string | null;
  assignedPatientCount: number;
}

export interface CreateProviderRequest {
  firstName: string;
  lastName: string;
  role: string;
  phone?: string;
  email?: string;
}

export interface UpdateProviderProfileRequest {
  firstName: string;
  lastName: string;
  role: string;
  phone?: string;
  email?: string;
  active: boolean;
}
