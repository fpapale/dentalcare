import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ClinicSettingsService } from '../../core/services/clinic-settings.service';
import { ProviderService } from '../../core/services/provider.service';
import { ClinicBilling } from '../../core/models/clinic-billing.model';
import { Provider } from '../../core/models/provider.model';

@Component({
  selector: 'app-impostazioni',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './impostazioni.component.html'
})
export class ImpostazioniComponent implements OnInit {
  activeTab = signal<'studio' | 'professionisti'>('studio');

  clinic = signal<ClinicBilling | null>(null);
  clinicForm: Partial<ClinicBilling> = {};
  loadingClinic = signal(true);
  savingClinic = signal(false);
  clinicSaved = signal(false);

  providers = signal<Provider[]>([]);
  selectedProvider = signal<Provider | null>(null);
  billingForm: Partial<Provider> = {};
  loadingProviders = signal(true);
  savingProvider = signal(false);
  providerSaved = signal(false);

  constructor(
    private clinicService: ClinicSettingsService,
    private providerService: ProviderService
  ) {}

  ngOnInit(): void {
    this.clinicService.get().subscribe({
      next: c => { this.clinic.set(c); this.clinicForm = { ...c }; this.loadingClinic.set(false); },
      error: () => this.loadingClinic.set(false)
    });
    this.providerService.findAll(false).subscribe({
      next: list => { this.providers.set(list); this.loadingProviders.set(false); },
      error: () => this.loadingProviders.set(false)
    });
  }

  saveClinic(): void {
    this.savingClinic.set(true);
    this.clinicService.update(this.clinicForm).subscribe({
      next: () => { this.savingClinic.set(false); this.clinicSaved.set(true); setTimeout(() => this.clinicSaved.set(false), 2500); },
      error: () => this.savingClinic.set(false)
    });
  }

  selectProvider(p: Provider): void {
    this.selectedProvider.set(p);
    this.billingForm = {
      vatNumber: p.vatNumber, fiscalCode: p.fiscalCode,
      professionalRegister: p.professionalRegister, registerNumber: p.registerNumber,
      billingAddressStreet: p.billingAddressStreet, billingAddressZip: p.billingAddressZip,
      billingAddressCity: p.billingAddressCity, billingAddressProvince: p.billingAddressProvince,
      billingPec: p.billingPec, billingIban: p.billingIban,
      billingSdiCode: p.billingSdiCode, invoicePrefix: p.invoicePrefix
    };
    this.providerSaved.set(false);
  }

  saveProviderBilling(): void {
    const p = this.selectedProvider();
    if (!p) return;
    this.savingProvider.set(true);
    this.providerService.updateBilling(p.providerId, this.billingForm).subscribe({
      next: () => {
        this.savingProvider.set(false);
        this.providerSaved.set(true);
        setTimeout(() => this.providerSaved.set(false), 2500);
        const updated = { ...p, ...this.billingForm } as Provider;
        this.selectedProvider.set(updated);
        this.providers.update(list => list.map(x => x.providerId === p.providerId ? updated : x));
      },
      error: () => this.savingProvider.set(false)
    });
  }

  roleLabel(role: string): string {
    const r = role.toLowerCase();
    if (r.includes('igien') || r.includes('hygien')) return 'Igienista';
    if (r.includes('admin')) return 'Amministratore';
    return 'Dentista';
  }
}
