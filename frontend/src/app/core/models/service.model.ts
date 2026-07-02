export interface ServiceItem {
  serviceId: string;
  code: string;
  name: string;
  category: string | null;
  defaultPrice: number;
  durationMinutes: number | null;
}

export interface ServiceAdmin {
  serviceId: string;
  code: string;
  name: string;
  category: string | null;
  description: string | null;
  defaultPrice: number;
  defaultVatRate: number | null;
  durationMinutes: number | null;
  minToothDigit: number | null;
  maxToothDigit: number | null;
  applicableToDeciduous: boolean;
  active: boolean;
}

export interface ConditionDefault {
  id: string;
  conditionName: string;
  serviceId: string;
  serviceName: string;
  sortOrder: number;
}

export interface CreateServiceRequest {
  code: string;
  name: string;
  category?: string;
  description?: string;
  defaultPrice: number;
  defaultVatRate?: number;
  durationMinutes?: number;
  minToothDigit?: number;
  maxToothDigit?: number;
  applicableToDeciduous?: boolean;
}

export interface UpdateServiceRequest {
  name: string;
  category?: string;
  description?: string;
  defaultPrice: number;
  defaultVatRate?: number;
  durationMinutes?: number;
  minToothDigit?: number;
  maxToothDigit?: number;
  applicableToDeciduous?: boolean;
  active: boolean;
}

export interface CreateConditionDefaultRequest {
  conditionName: string;
  serviceId: string;
  sortOrder?: number;
}

export interface AddBundleItemRequest {
  childServiceId: string;
  sortOrder?: number;
}

export interface ServiceCategory {
  id: string;
  name: string;
  sortOrder: number;
  active: boolean;
  usageCount: number;
}

export interface CreateServiceCategoryRequest {
  name: string;
  sortOrder?: number;
}

export interface UpdateServiceCategoryRequest {
  name: string;
  sortOrder?: number;
  active: boolean;
}
