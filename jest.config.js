module.exports = {
  testEnvironment: "jsdom",
  roots: ["<rootDir>/app/webpack"],
  testMatch: ["<rootDir>/app/webpack/**/*.test.@(ts|tsx|js|jsx)"],
  moduleFileExtensions: ["tsx", "ts", "jsx", "js", "json"],
  moduleNameMapper: {
    "\\.module\\.css$": "identity-obj-proxy",
    "\\.(css|scss|less)$": "identity-obj-proxy"
  },
  transform: {
    "^.+\\.[jt]sx?$": "babel-jest"
  },
  // htmlparser2 v12 (a sanitize-html dependency) and its dependency chain are
  // ESM-only, so they must be transpiled for jest's CommonJS runtime
  transformIgnorePatterns: [
    "/node_modules/(?!(htmlparser2|domelementtype|domhandler|domutils|dom-serializer|entities)/)"
  ],
  clearMocks: true,
  setupFilesAfterEnv: ["<rootDir>/app/webpack/jest.setup.ts"]
};
