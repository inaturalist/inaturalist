import { envConfig } from "../shared/env.config";

export const puppeteerConfig = {
  baseUrl: envConfig.baseUrl,
  headless: envConfig.headless,
  slowMo: envConfig.slowMo,
  defaultViewport: {
    width: 1280,
    height: 720
  },
  screenshotDir: "./screenshots",
  reportDir: "./reports",
  pages: [
    { name: "home", path: "/" },
    { name: "observations", path: "/observations" },
    { name: "taxa-mammals", path: "/taxa/48460-Mammalia" },
    { name: "login", path: "/login" }
  ]
};
