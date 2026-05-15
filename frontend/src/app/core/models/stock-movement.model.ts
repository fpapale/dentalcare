export interface StockMovement {
  movementId: string;
  productId: string;
  productName: string;
  movementType: 'carico' | 'scarico' | 'rettifica' | 'rientro';
  quantity: number;
  unitCost: number | null;
  notes: string | null;
  referenceDoc: string | null;
  createdAt: string;
}

export interface CreateStockMovementRequest {
  productId: string;
  movementType: string;
  quantity: number;
  unitCost?: number;
  notes?: string;
  referenceDoc?: string;
}
