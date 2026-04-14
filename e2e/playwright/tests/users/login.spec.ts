import { test, expect } from "@playwright/test";
import { LoginPage } from "../../page-objects/login.page";
import { envConfig } from "../../../shared/env.config";

test.describe( "Login page", () => {
  let loginPage: LoginPage;

  test.beforeEach( async ( { page } ) => {
    loginPage = new LoginPage( page );
    await loginPage.goto();
  } );

  test( "displays all form elements", async () => {
    await loginPage.assertFormElements();
  } );

  test( "shows email and password inputs", async () => {
    await expect( loginPage.emailInput ).toBeVisible();
    await expect( loginPage.passwordInput ).toBeVisible();
  } );

  test( "shows submit button", async () => {
    await expect( loginPage.submitButton ).toBeVisible();
  } );

  test( "shows signup link", async () => {
    await expect( loginPage.signupLink ).toBeVisible();
  } );

  test( "shows forgot password link", async () => {
    await expect( loginPage.forgotPasswordLink ).toBeVisible();
  } );

  test( "invalid credentials show error", async () => {
    await loginPage.login( "invalid@example.com", "wrongpassword" );
    await loginPage.assertLoginError();
  } );

  test( "valid credentials redirect and set CURRENT_USER", async ( { page } ) => {
    test.skip(
      !envConfig.testUser.email || !envConfig.testUser.password,
      "Test user credentials not configured"
    );

    await loginPage.login( envConfig.testUser.email, envConfig.testUser.password );
    await page.waitForURL( /\//, { timeout: 15_000 } );

    const isLoggedIn = await loginPage.isLoggedIn();
    expect( isLoggedIn ).toBe( true );
  } );
} );
