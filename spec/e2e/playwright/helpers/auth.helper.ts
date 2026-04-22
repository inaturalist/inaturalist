import { Page, BrowserContext } from "@playwright/test";
import { envConfig } from "../../shared/env.config";
import * as path from "path";
import * as fs from "fs";

const STORAGE_STATE_PATH = path.resolve( __dirname, "..", ".auth", "storage-state.json" );

export async function login(
  page: Page,
  email?: string,
  password?: string
): Promise<void> {
  const user = email || envConfig.testUser.email;
  const pass = password || envConfig.testUser.password;

  if ( !user || !pass ) {
    throw new Error( "Test user credentials not configured. Set E2E_TEST_USER_EMAIL and E2E_TEST_USER_PASSWORD." );
  }

  await page.goto( "/login" );
  const form = page.locator( "form.log-in" );
  await form.locator( "input[type='email']" ).fill( user );
  await form.locator( "input[type='password']" ).fill( pass );
  await Promise.all( [
    page.waitForURL( url => !url.pathname.startsWith( "/login" )
      && !url.pathname.startsWith( "/session" ), { timeout: 15_000 } ),
    form.locator( "input[type='submit'][name='commit']" ).click()
  ] );
}

export async function saveStorageState( context: BrowserContext ): Promise<void> {
  const dir = path.dirname( STORAGE_STATE_PATH );
  if ( !fs.existsSync( dir ) ) {
    fs.mkdirSync( dir, { recursive: true } );
  }
  await context.storageState( { path: STORAGE_STATE_PATH } );
}

export function hasStorageState(): boolean {
  return fs.existsSync( STORAGE_STATE_PATH );
}

export function getStorageStatePath(): string {
  return STORAGE_STATE_PATH;
}
