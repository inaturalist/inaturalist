import "@testing-library/jest-dom";

// The components reach for these as bare globals at runtime (injected by Rails
// in the app, by .storybook/preview.ts in Storybook). Stub them for unit tests.
type Globals = typeof globalThis & {
  I18n?: unknown;
  iNatModels?: unknown;
  ResizeObserver?: unknown;
};

const g = globalThis as Globals;

// Echo the key so assertions can match on translation keys.
g.I18n = {
  t: ( key: string ) => key
};

g.iNatModels = {
  Taxon: {
    titleCaseName: ( name: string ) => name
      ?.split( " " )
      .map( w => w.charAt( 0 ).toUpperCase( ) + w.slice( 1 ) )
      .join( " " ) ?? name
  }
};

// jsdom has no ResizeObserver; stub it so mounting carousel et al. doesn't throw.
g.ResizeObserver = class {
  observe( ) {}

  unobserve( ) {}

  disconnect( ) {}
};
