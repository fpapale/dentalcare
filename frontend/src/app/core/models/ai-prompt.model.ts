export interface AiPromptLocale {
  locale: string;
  value: string;
  globalValue: string;
  defaultValue: string;
  overridden: boolean;
}

export interface AiPrompt {
  key: string;
  description: string;
  locales: AiPromptLocale[];
}

export interface UpdateAiPromptRequest {
  value: string;
}
