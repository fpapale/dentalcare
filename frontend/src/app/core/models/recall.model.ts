export interface Recall {
  recallId: string;
  patientId: string;
  patientFullName: string;
  patientPhone: string | null;
  recallType: string;
  dueDate: string;
  status: 'da_contattare' | 'contattato' | 'in_attesa' | 'confermato' | 'chiuso' | 'annullato';
  priority: 'alta' | 'media' | 'bassa';
  notes: string | null;
  contactCount: number;
  lastContactAt: string | null;
  sourceAppointmentDate: string | null;
  createdAt: string;
}

export interface RecallContact {
  contactId: string;
  recallId: string;
  contactType: 'telefono' | 'sms' | 'email' | 'whatsapp';
  contactAt: string;
  outcome: 'risposto' | 'non_risposto' | 'messaggio_lasciato' | 'confermato' | 'rifiutato';
  notes: string | null;
  createdAt: string;
}

export interface CreateRecallRequest {
  patientId: string;
  recallType: string;
  dueDate: string;
  priority?: string;
  notes?: string;
}

export interface CreateRecallContactRequest {
  contactType: string;
  outcome: string;
  notes?: string;
  createdByProviderId?: string;
}

export interface UpdateRecallRequest {
  status: string;
  priority?: string;
  recallType?: string;
  dueDate?: string;
  notes?: string;
}

export interface GenerateRecallsResponse {
  generated: number;
  skipped: number;
  message: string;
}
