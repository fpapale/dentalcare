export interface Estimate {
  estimateId: string;
  estimateNumber: string;
  version: number;
  estimateStatus: string;
  estimateTitle: string;
  currency: string;
  subtotalAmount: number;
  discountAmount: number;
  taxableAmount: number;
  vatAmount: number;
  totalAmount: number;
  patientId: string;
  patientFullName: string;
  patientFiscalCode: string | null;
  patientPhone: string | null;
  issuedAt: string | null;
  sentAt: string | null;
  validUntil: string | null;
  acceptedAt: string | null;
  rejectedAt: string | null;
  estimateCreatedAt: string;
}
