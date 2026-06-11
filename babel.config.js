// Shared Babel config for webpack, Storybook, and Jest.
// Browser tooling (webpack/Storybook) uses preset-env's default targets — identical
// to the presets these tools previously declared inline. Jest (NODE_ENV=test) gets
// node targets so tests transpile to the running Node.
module.exports = api => {
  const isTest = api.env( "test" );
  return {
    presets: [
      "@babel/preset-typescript",
      ["@babel/preset-env", isTest ? { targets: { node: "current" } } : {}],
      "@babel/preset-react"
    ]
  };
};
