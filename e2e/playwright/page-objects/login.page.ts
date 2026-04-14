import { Page, Locator, expect } from "@playwright/test";
import { BasePage } from "./base.page";

export class LoginPage extends BasePage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly signupLink: Locator;
  readonly rememberCheckbox: Locator;
  readonly forgotPasswordLink: Locator;
  readonly loginForm: Locator;

  constructor( page: Page ) {
    super( page );
    this.loginForm = page.locator( "form.log-in" );
    this.emailInput = page.locator( "input[type='email']" );
    this.passwordInput = page.locator( "input[type='password']" );
    this.submitButton = page.locator( "button.btn-inat.btn-primary" );
    this.signupLink = page.locator( "a.btn.btn-link" );
    this.rememberCheckbox = page.locator( "input[type='checkbox']" );
    this.forgotPasswordLink = page.locator( "a.forgot-password-link" );
  }

  async goto(): Promise<void> {
    await super.goto( "/login" );
  }

  async login( email: string, password: string ): Promise<void> {
    await this.emailInput.fill( email );
    await this.passwordInput.fill( password );
    await this.submitButton.click();
  }

  async assertLoginError(): Promise<void> {
    const errorMessage = this.page.locator( ".alert, .error, .flash" ).first();
    await expect( errorMessage ).toBeVisible( { timeout: 10_000 } );
  }

  async assertFormElements(): Promise<void> {
    await expect( this.loginForm ).toBeVisible();
    await expect( this.emailInput ).toBeVisible();
    await expect( this.passwordInput ).toBeVisible();
    await expect( this.submitButton ).toBeVisible();
  }
}
