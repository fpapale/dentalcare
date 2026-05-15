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

export interface EstimateLine {
  lineId: string;
  linePosition: number;
  serviceId: string;
  serviceName: string;
  treatmentPlanItemId: string | null;
  descriptionSnapshot: string;
  toothSnapshot: string | null;
  quantity: number;
  unitPrice: number;
  discountAmount: number;
  vatRate: number;
  lineSubtotal: number;
  lineTaxable: number;
  lineVatAmount: number;
  lineTotal: number;
}

export interface PlanItemCoverage {
  planItemId: string;
  estimateId: string;
  estimateNumber: string;
  estimateTitle: string;
  estimateStatus: string;
}

export interface EstimateDetail {
  estimateId: string;
  estimateNumber: string;
  version: number;
  status: string;
  title: string;
  notes: string | null;
  currency: string;
  subtotalAmount: number;
  discountAmount: number;
  taxableAmount: number;
  vatAmount: number;
  totalAmount: number;
  patientId: string;
  patientFullName: string;
  treatmentPlanId: string | null;
  treatmentPlanName: string | null;
  issuedAt: string | null;
  sentAt: string | null;
  validUntil: string | null;
  acceptedAt: string | null;
  rejectedAt: string | null;
  createdAt: string;
  lines: EstimateLine[];
}
