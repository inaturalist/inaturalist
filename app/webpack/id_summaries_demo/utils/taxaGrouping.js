/* global I18n */

export const OTHER_GROUP_KEY = "__other__";

export const loadGroupLabels = () => {
  const raw =
    ( typeof window !== "undefined" && window.ID_SUMMARY_GROUP_LABELS )
    || (
      I18n?.translations?.[I18n.locale]
      ?.id_summaries?.demo?.taxa_list?.group_labels
    )
    || {};
  if ( raw && typeof raw === "object" ) {
    return { ...raw };
  }
  return {};
};

export const getFallbackGroupLabel = () => I18n.t( "id_summaries.demo.taxa_list.other_group" );

export const normalizeGroupKey = value => {
  if ( !value ) return "";
  return value
    .trim()
    .toLowerCase()
    .replace( /[^a-z0-9]+/g, "_" )
    .replace( /^_+|_+$/g, "" );
};

const resolveGroupingOptions = ( options = {} ) => ( {
  groupLabels: options.groupLabels || loadGroupLabels(),
  fallbackGroupLabel: options.fallbackGroupLabel || getFallbackGroupLabel()
} );

export const translateGroupName = ( groupName, options = {} ) => {
  const { groupLabels, fallbackGroupLabel } = resolveGroupingOptions( options );
  if ( !groupName || groupName.trim().length === 0 ) return fallbackGroupLabel;
  const trimmed = groupName.trim();
  const normalized = normalizeGroupKey( trimmed );
  if ( normalized && Object.prototype.hasOwnProperty.call( groupLabels, normalized ) ) {
    return groupLabels[normalized];
  }
  if ( Object.prototype.hasOwnProperty.call( groupLabels, trimmed ) ) {
    return groupLabels[trimmed];
  }
  const translationBase = "id_summaries.demo.taxa_list.group_labels";
  return I18n.t( `${translationBase}.${normalized || trimmed}`, { defaultValue: trimmed } );
};

const sortSpeciesByName = ( a, b ) => {
  const nameA = ( a?.name || "" ).trim().toLocaleLowerCase();
  const nameB = ( b?.name || "" ).trim().toLocaleLowerCase();
  if ( nameA === nameB ) return 0;
  return nameA.localeCompare( nameB );
};

const groupSpecies = list => list.reduce( ( acc, species ) => {
  const key = typeof species?.taxonGroup === "string" && species.taxonGroup.trim().length > 0
    ? species.taxonGroup.trim()
    : OTHER_GROUP_KEY;
  if ( !acc[key] ) acc[key] = [];
  acc[key].push( species );
  return acc;
}, {} );

const sortGroupKeys = ( keys, grouped, options ) => keys.sort( ( a, b ) => {
  if ( a === OTHER_GROUP_KEY ) return 1;
  if ( b === OTHER_GROUP_KEY ) return -1;
  const countDiff = ( grouped[b]?.length || 0 ) - ( grouped[a]?.length || 0 );
  if ( countDiff !== 0 ) return countDiff;
  const labelA = translateGroupName( a, options );
  const labelB = translateGroupName( b, options );
  return labelA.localeCompare( labelB );
} );

export const groupTaxaForDisplay = ( list = [], options = {} ) => {
  if ( !Array.isArray( list ) || list.length === 0 ) return [];
  const resolvedOptions = resolveGroupingOptions( options );
  const grouped = groupSpecies( list );
  const labels = sortGroupKeys( Object.keys( grouped ), grouped, resolvedOptions );
  return labels.map( label => ( {
    label: label === OTHER_GROUP_KEY
      ? resolvedOptions.fallbackGroupLabel
      : translateGroupName( label, resolvedOptions ),
    taxa: grouped[label].slice().sort( sortSpeciesByName )
  } ) );
};

export const determineDefaultSpecies = ( list = [], options = {} ) => {
  if ( !Array.isArray( list ) || list.length === 0 ) return null;
  const resolvedOptions = resolveGroupingOptions( options );
  const grouped = groupSpecies( list );
  const labels = sortGroupKeys( Object.keys( grouped ), grouped, resolvedOptions );
  const bestGroup = labels[0];
  if ( !bestGroup ) return null;
  const sortedTaxa = grouped[bestGroup].slice().sort( sortSpeciesByName );
  return sortedTaxa[0] || null;
};
