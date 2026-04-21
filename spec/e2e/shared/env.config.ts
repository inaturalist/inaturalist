import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.resolve( __dirname, "..", ".env.local" ) });

export const envConfig = {
  baseUrl: process.env.E2E_BASE_URL || "http://localhost:3000",
  testUser: {
    email: process.env.E2E_TEST_USER_EMAIL || "",
    password: process.env.E2E_TEST_USER_PASSWORD || ""
  },
  headless: process.env.E2E_HEADLESS !== "false",
  slowMo: parseInt( process.env.E2E_SLOW_MO || "0", 10 )
};
