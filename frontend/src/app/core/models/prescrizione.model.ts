export interface Prescrizione {
  id: string;
  drugName: string;
  dosage: string | null;
  frequency: string | null;
  duration: string | null;
  notes: string | null;
  providerName: string;
  prescribedAt: string;
  expiresAt: string | null;
  active: boolean;
  createdAt: string;
}

export interface CreatePrescrizioneRequest {
  providerId: string;
  drugName: string;
  dosage?: string;
  frequency?: string;
  duration?: string;
  notes?: string;
  prescribedAt?: string;
  expiresAt?: string;
}
