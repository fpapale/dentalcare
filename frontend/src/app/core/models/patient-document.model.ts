export interface PatientDocumentSummary {
  id: string;
  documentType: string;
  title: string;
  fileName: string;
  mimeType: string;
  fileSizeBytes: number | null;
  notes: string | null;
  takenAt: string | null;
  createdAt: string;
}

export interface UpdatePatientDocumentRequest {
  title: string;
  documentType?: string;
  notes?: string;
  takenAt?: string;
}

export const DOCUMENT_TYPE_LABELS: Record<string, string> = {
  rx_panoramica: 'Ortopanoramica',
  rx_endorale: 'RX Endorale',
  cbct: 'TAC / CBCT',
  foto_clinica: 'Foto clinica',
  foto_extraorale: 'Foto extraorale',
  consenso_informato: 'Consenso informato',
  referto: 'Referto / Lettera',
  documento_amministrativo: 'Documento amministrativo',
  altro: 'Altro',
};
