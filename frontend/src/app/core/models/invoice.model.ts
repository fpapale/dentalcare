export interface Invoice {
  id: string;
  invoiceNumber: string;
  documentType: string;
  invoiceDate: string;
  dueDate: string | null;
  status: string;
  issuerType: string;
  providerFullName: string | null;
  patientFullName: string;
  estimateId: string | null;
  estimateNumber: string | null;
  totalAmount: number;
  currency: string;
  createdAt: string;
}

export interface InvoiceDetail extends Invoice {
  subtotalAmount: number;
  discountAmount: number;
  taxableAmount: number;
  vatAmount: number;
  issuerName: string;
  issuerVatNumber: string | null;
  issuerFiscalCode: string | null;
  issuerAddress: string | null;
  issuerEmail: string | null;
  issuerPec: string | null;
  issuerSdiCode: string | null;
  issuerIban: string | null;
  patientFiscalCode: string | null;
  patientAddress: string | null;
  patientEmail: string | null;
  notes: string | null;
  paymentMethod: string | null;
  paidAt: string | null;
  issuedAt: string | null;
  lines: InvoiceLine[];
}

export interface InvoiceLine {
  id: string;
  linePosition: number;
  description: string;
  toothInfo: string | null;
  quantity: number;
  unitPrice: number;
  discountAmount: number;
  vatRate: number;
  lineSubtotal: number;
  lineTaxable: number;
  lineVatAmount: number;
  lineTotal: number;
}
