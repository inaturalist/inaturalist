import { request } from "@playwright/test";
import { envConfig } from "../../shared/env.config";

const contextPromise = request.newContext( {
  baseURL: envConfig.baseUrl
} );

type CommandOptions = Record<string, unknown> | string | unknown[];

// App commands run synchronously in the request; heavy ones (e.g. seed_dashboard,
// which reindexes taxa in Elasticsearch and runs notification jobs inline) can
// take well over Playwright's default 30s API timeout, so allow generous time.
const COMMAND_TIMEOUT_MS = 180_000;

const app = async ( name: string, options: CommandOptions = {} ): Promise<unknown> => {
  const context = await contextPromise;
  const response = await context.post( "/__e2e__/command", {
    data: { name, options },
    timeout: COMMAND_TIMEOUT_MS
  } );
  if ( !response.ok() ) {
    const body = await response.text();
    throw new Error( `/__e2e__/command failed (${response.status()}): ${body}` );
  }
  const results = await response.json() as unknown[];
  return results[0];
};

/**
 * Create a record using Machinist blueprints via SmartFactoryWrapper.
 *
 * @example
 *   const user = await appMake("create", "user", { login: "testuser" });
 *   const obs = await appMake("create", "observation", { description: "Test" });
 */
const appMake = async ( factoryMethod: string, ...factoryArgs: unknown[] ): Promise<Record<string, unknown>> => {
  // factory_bot.rb returns an array from .map; unwrap to get the first record
  const records = await app( "machinist", [[factoryMethod, ...factoryArgs]] ) as Record<string, unknown>[];
  return records[0];
};

export {
  app,
  appMake
};
