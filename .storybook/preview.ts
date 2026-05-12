import type { Preview } from "@storybook/react";

const translations: Record<string, string> = {
  view_all_caps: "VIEW ALL",
  previous_taxon_short: "‹",
  next_taxon_short: "›"
};

( window as Window & { I18n?: unknown } ).I18n = {
  t: ( key: string ) => translations[key] ?? key
};

const preview: Preview = {};

export default preview;
