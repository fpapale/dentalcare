import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpErrorResponse } from '@angular/common/http';
import { AuthService } from '../../core/auth/auth.service';
import { ClinicOption, LoginPreflightResponse } from '../../core/auth/auth.model';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html'
})
export class LoginComponent implements OnInit {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly today = new Date().getFullYear();

  readonly step = signal<'form' | 'choose' | 'change-password' | 'forgot-password'>('form');
  readonly chooseOptions = signal<ClinicOption[]>([]);
  readonly pendingEmail = signal('');
  readonly pendingPassword = signal('');
  readonly confirmingClinicId = signal<string | null>(null);
  readonly showPassword = signal(false);

  readonly changePwdError = signal<string | null>(null);
  readonly changePwdSaving = signal(false);
  readonly newPassword = signal('');
  readonly confirmNewPassword = signal('');
  readonly infoMessage = signal<string | null>(null);

  readonly forgotEmail = signal('');
  readonly forgotSaving = signal(false);
  readonly forgotSent = signal(false);
  readonly forgotError = signal<string | null>(null);

  readonly form = this.fb.nonNullable.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]]
  });

  ngOnInit(): void {
    const pending = this.auth.getPendingChoose();
    if (pending) {
      this.chooseOptions.set(pending.options);
      this.pendingEmail.set(pending.email);
      this.pendingPassword.set(pending.password);
      this.step.set('choose');
      return;
    }

    this.auth.getDemoConfig().subscribe({
      next: (res) => {
        if (res.enabled && res.email && res.password) {
          this.form.patchValue({ email: res.email, password: res.password });
        }
      },
      error: () => {}
    });
  }

  onSubmit(): void {
    if (this.form.invalid || this.loading()) {
      this.form.markAllAsTouched();
      return;
    }
    this.error.set(null);
    this.infoMessage.set(null);
    this.loading.set(true);

    const { email, password } = this.form.getRawValue();
    this.pendingEmail.set(email);
    this.pendingPassword.set(password);

    this.auth.login({ email, password }).subscribe({
      next: (res) => {
        this.loading.set(false);
        this.handlePreflight(res);
      },
      error: (err: HttpErrorResponse) => {
        this.loading.set(false);
        this.handleError(err);
      }
    });
  }

  private handlePreflight(res: LoginPreflightResponse): void {
    if (res.type === 'direct') {
      this.auth.storeDirectLogin(res);
      if (res.mustChangePassword) {
        this.step.set('change-password');
        this.changePwdError.set(null);
        return;
      }
      const dest = res.role === 'tenant_admin' ? '/admin-tenant'
        : '/dashboard';
      this.router.navigate([dest]);
      return;
    }

    const options = res.options ?? [];
    if (options.length === 1) {
      this.onConfirm(options[0]);
      return;
    }

    this.auth.storePendingChoose(options, this.pendingEmail(), this.pendingPassword());
    this.chooseOptions.set(options);
    this.step.set('choose');
  }

  onConfirm(option: ClinicOption): void {
    if (this.confirmingClinicId() !== null) {
      return;
    }
    this.error.set(null);
    this.confirmingClinicId.set(option.clinicId);

    this.auth.confirmLogin({
      email: this.pendingEmail(),
      password: this.pendingPassword(),
      clinicId: option.clinicId,
      providerId: option.providerId
    }).subscribe({
      next: (res) => {
        this.confirmingClinicId.set(null);
        this.auth.clearPendingChoose();
        if (res.mustChangePassword) {
          this.step.set('change-password');
          this.changePwdError.set(null);
          return;
        }
        const role = option.role ?? '';
        const dest = (option.isTenantAdmin || role === 'tenant_admin') ? '/admin-tenant'
          : '/dashboard';
        this.router.navigate([dest]);
      },
      error: (err: HttpErrorResponse) => {
        this.confirmingClinicId.set(null);
        this.handleError(err);
      }
    });
  }

  submitChangePassword(): void {
    if (this.newPassword().length < 8) {
      this.changePwdError.set('La password deve avere almeno 8 caratteri.');
      return;
    }
    if (this.newPassword() !== this.confirmNewPassword()) {
      this.changePwdError.set('Le password non coincidono.');
      return;
    }
    this.changePwdSaving.set(true);
    this.changePwdError.set(null);

    this.auth.changePassword(this.pendingPassword(), this.newPassword()).subscribe({
      next: () => {
        this.changePwdSaving.set(false);
        // Cambio forzato completato: torna alla maschera di login per riautenticarsi.
        this.auth.clearSession();
        this.newPassword.set('');
        this.confirmNewPassword.set('');
        this.pendingPassword.set('');
        this.form.reset();
        this.step.set('form');
        this.infoMessage.set('Password aggiornata. Accedi con la nuova password.');
      },
      error: (err) => {
        this.changePwdSaving.set(false);
        this.changePwdError.set(err?.error?.message || 'Errore nel cambio password.');
      }
    });
  }

  submitForgotPassword(): void {
    if (!this.forgotEmail()) return;
    this.forgotSaving.set(true);
    this.forgotError.set(null);

    this.auth.forgotPassword(this.forgotEmail()).subscribe({
      next: () => { this.forgotSaving.set(false); this.forgotSent.set(true); },
      error: () => { this.forgotSaving.set(false); this.forgotError.set("Errore nell'invio. Riprova."); }
    });
  }

  backToForm(): void {
    this.auth.clearPendingChoose();
    this.step.set('form');
    this.chooseOptions.set([]);
    this.error.set(null);
  }

  backToLoginForm(): void {
    this.step.set('form');
    this.forgotSent.set(false);
    this.forgotError.set(null);
    this.forgotEmail.set('');
  }

  private handleError(err: HttpErrorResponse): void {
    if (err.status === 401) {
      this.error.set('Credenziali non valide');
    } else if (err.status === 404) {
      this.error.set('Studio non trovato');
    } else {
      this.error.set('Si è verificato un errore. Riprova più tardi.');
    }
  }
}
