export const LANGUAGE_OPTIONS = [
  { value: "en", label: "English" },
  { value: "es", label: "Spanish" },
  { value: "fr", label: "French" },
  { value: "de", label: "German" }
];

export const LANGUAGE_LABELS = LANGUAGE_OPTIONS.reduce( ( acc, option ) => {
  acc[option.value] = option.label;
  return acc;
}, {} );
