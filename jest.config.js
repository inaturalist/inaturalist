module.exports = {
  testEnvironment: "jsdom",
  roots: ["<rootDir>/app/webpack"],
  testMatch: ["<rootDir>/app/webpack/**/*.test.@(ts|tsx|js|jsx)"],
  moduleFileExtensions: ["tsx", "ts", "jsx", "js", "json"],
  setupFilesAfterEnv: ["<rootDir>/spec/jest/setup.ts"],
  moduleNameMapper: {
    "\\.module\\.css$": "identity-obj-proxy",
    "\\.(css|scss|less)$": "identity-obj-proxy"
  },
  transform: {
    "^.+\\.[jt]sx?$": "babel-jest"
  },
  transformIgnorePatterns: ["/node_modules/"],
  clearMocks: true
};
