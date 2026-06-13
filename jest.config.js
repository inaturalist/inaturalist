module.exports = {
  testEnvironment: "jsdom",
  setupFilesAfterEnv: ["<rootDir>/app/webpack/jest.setup.ts"],
  roots: ["<rootDir>/app/webpack"],
  testMatch: ["<rootDir>/app/webpack/**/*.test.@(ts|tsx|js|jsx)"],
  moduleFileExtensions: ["tsx", "ts", "jsx", "js", "json"],
  moduleNameMapper: {
    "\\.module\\.css$": "identity-obj-proxy",
    "\\.(css|scss|less)$": "identity-obj-proxy",
    "^heic-to$": "<rootDir>/app/webpack/__mocks__/heic-to.js"
  },
  transform: {
    "^.+\\.[jt]sx?$": "babel-jest"
  },
  transformIgnorePatterns: ["/node_modules/"],
  clearMocks: true
};
