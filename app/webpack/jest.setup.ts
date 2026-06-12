import "@testing-library/jest-dom";

type Globals = {
  I18n: { t: (key: string) => string };
  ResizeObserver: unknown;
};
const g = global as unknown as Globals;

// Stub the I18n global used by components; return the key as-is so tests can
// assert on the raw translation key without needing a full locale fixture.
g.I18n = { t: (key: string) => key };

// jsdom doesn't implement ResizeObserver; stub it so layout-aware components mount.
g.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
};
