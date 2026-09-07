module.exports = {
  testEnvironment: "jsdom",
  roots: ["<rootDir>/app/webpack"],
  testMatch: ["<rootDir>/app/webpack/**/*.test.@(ts|tsx|js|jsx)"],
  moduleFileExtensions: ["tsx", "ts", "jsx", "js", "json"],
  moduleNameMapper: {
    "\\.module\\.css$": "identity-obj-proxy",
    "\\.(css|scss|less)$": "identity-obj-proxy",
    // Force resolution to billboard.js's ESM build (dist-esm), matching what webpack
    // resolves in the browser build. Its CJS/"require" build (dist/billboard.pkgd.js)
    // doesn't re-export shape/interaction helpers (areaSpline, spline, zoom) at the
    // top level, which would make jest fail in a way the browser bundle never does.
    "^billboard\\.js$": "<rootDir>/node_modules/billboard.js/dist-esm/billboard.js"
  },
  transform: {
    "^.+\\.[jt]sx?$": "babel-jest"
  },
  // ESM-only packages (d3 and its sub-packages, billboard.js's ESM build,
  // htmlparser2 v12 and its dependency chain via sanitize-html, etc.) need to be
  // transpiled for jest's CommonJS runtime. Allow-listing each one doesn't scale
  // as this dependency tree grows — transform all of node_modules instead.
  transformIgnorePatterns: [],
  clearMocks: true,
  setupFilesAfterEnv: ["<rootDir>/app/webpack/jest.setup.ts"]
};
