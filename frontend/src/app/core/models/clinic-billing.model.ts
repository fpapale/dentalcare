export interface ClinicBilling {
  id: string;
  name: string;
  legalName: string;
  vatNumber: string | null;
  fiscalCode: string | null;
  phone: string | null;
  email: string | null;
  addressLine1: string | null;
  addressLine2: string | null;
  city: string | null;
  province: string | null;
  postalCode: string | null;
  country: string | null;
}
