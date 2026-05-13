import type { StorybookConfig } from "@storybook/react-webpack5";
import type { RuleSetRule } from "webpack";

const config: StorybookConfig = {
  stories: ["../app/webpack/**/*.stories.@(tsx|ts|jsx|js)"],
  addons: ["@storybook/addon-essentials"],
  staticDirs: [{ from: "../app/assets/fonts", to: "/fonts" }],
  framework: {
    name: "@storybook/react-webpack5",
    options: {}
  },
  webpackFinal: async ( baseConfig ) => {
    baseConfig.module?.rules?.push( {
      test: /\.[jt]sx?$/,
      exclude: /node_modules/,
      use: {
        loader: "babel-loader",
        options: {
          presets: [
            "@babel/preset-typescript",
            "@babel/preset-env",
            "@babel/preset-react"
          ]
        }
      }
    } as RuleSetRule );
    return baseConfig;
  }
};

export default config;
