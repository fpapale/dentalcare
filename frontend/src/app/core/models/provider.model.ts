export interface Provider {
  providerId: string;
  firstName: string;
  lastName: string;
  fullName: string;
  role: string;
  phone: string | null;
  email: string | null;
  active: boolean;
}
