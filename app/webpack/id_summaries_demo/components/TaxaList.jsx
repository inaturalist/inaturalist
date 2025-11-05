/* global I18n */

import React, { useMemo } from "react";
import PropTypes from "prop-types";

const photoUrlFromId = ( photoId, size = "square" ) => {
  const id = Number( photoId );
  if ( !Number.isFinite( id ) || id <= 0 ) return null;
  return `https://inaturalist-open-data.s3.amazonaws.com/photos/${id}/${size}.jpg`;
};

const TaxaList = ( {
  list = [],
  images = {},
  selectedId,
  loading,
  error,
  onTileClick
} ) => {
  const fallbackGroupLabel = I18n.t( "id_summaries.demo.taxa_list.other_group" );
  const OTHER_GROUP_KEY = "__other__";
  const normalizeGroupKey = value => {
    if ( !value ) return "";
    return value
      .trim()
      .toLowerCase()
      .replace( /[^a-z0-9]+/g, "_" )
      .replace( /^_+|_+$/g, "" );
  };
  const groupLabels = useMemo( () => {
    const raw =
      ( typeof window !== "undefined" && window.ID_SUMMARY_GROUP_LABELS )
        || (
          I18n?.translations
          && I18n.locale
          && I18n.translations[I18n.locale]
          && I18n.translations[I18n.locale]?.id_summaries
          && I18n.translations[I18n.locale].id_summaries?.demo
          && I18n.translations[I18n.locale].id_summaries.demo?.taxa_list
          && I18n.translations[I18n.locale].id_summaries.demo.taxa_list?.group_labels
        )
        || {};
    if ( raw && typeof raw === "object" ) {
      return { ...raw };
    }
    return {};
  }, [] );
  const translateGroupName = groupName => {
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
  const groupedTaxa = useMemo( () => {
    if ( !Array.isArray( list ) || list.length === 0 ) return [];
    const byGroup = list.reduce( ( acc, species ) => {
      const key = species?.taxonGroup && species.taxonGroup.trim().length > 0
        ? species.taxonGroup.trim()
        : OTHER_GROUP_KEY;
      if ( !acc[key] ) acc[key] = [];
      acc[key].push( species );
      return acc;
    }, {} );
    const labels = Object.keys( byGroup ).sort( ( a, b ) => {
      if ( a === OTHER_GROUP_KEY ) return 1;
      if ( b === OTHER_GROUP_KEY ) return -1;
      const labelA = translateGroupName( a );
      const labelB = translateGroupName( b );
      return labelA.localeCompare( labelB );
    } );
    return labels.map( label => ( {
      label: label === OTHER_GROUP_KEY ? fallbackGroupLabel : translateGroupName( label ),
      taxa: byGroup[label]
        .slice()
        .sort( ( a, b ) => {
          const nameA = ( a?.name || "" ).trim().toLocaleLowerCase();
          const nameB = ( b?.name || "" ).trim().toLocaleLowerCase();
          if ( nameA === nameB ) return 0;
          return nameA.localeCompare( nameB );
        } )
    } ) );
  }, [list, fallbackGroupLabel] );

  const renderGroup = group => (
    <section key={group.label} className="fg-thumb-group">
      <h3 className="fg-thumb-group-heading">{group.label}</h3>
      <div className="fg-thumb-grid">
        {group.taxa.map( species => {
          const isSelected = selectedId === species.id;
          const tileClass = `fg-thumb-tile${isSelected ? " is-selected" : ""}`;
          const thumb = images[species.id]
            || species?.photoSquareUrl
            || photoUrlFromId( species?.taxonPhotoId, "square" );
          const fallback = species?.name && species.name.trim().length > 0
            ? species.name.trim().charAt( 0 ).toUpperCase()
            : "?";
          return (
            <div key={species.id} className="fg-thumb-col">
              <button
                type="button"
                className="fg-thumb-button"
                title={species.name}
                aria-pressed={isSelected}
                onClick={() => onTileClick?.( species )}
                onKeyDown={event => {
                  if ( event.key === "Enter" || event.key === " " ) {
                    event.preventDefault();
                    onTileClick?.( species );
                  }
                }}
              >
                <span className={tileClass}>
                  {thumb ? (
                    <img src={thumb} alt={species.name} className="fg-img-fill" />
                  ) : (
                    <span className="fg-thumb-fallback" aria-hidden="true">
                      <span>{fallback}</span>
                    </span>
                  )}
                </span>
              </button>
            </div>
          );
        } )}
      </div>
    </section>
  );

  const renderSkeleton = () => (
    <div className="fg-thumb-grid fg-thumb-grid-placeholder">
      {Array.from( { length: 12 } ).map( ( _, index ) => (
        <div key={`placeholder-${index}`} className="fg-thumb-col">
          <div className="fg-thumb-tile is-loading">
            <div className="fg-thumb-fallback" aria-hidden="true">
              <span>•</span>
            </div>
          </div>
        </div>
      ) )}
    </div>
  );

  return (
    <div className="fg-sidebar-panel">
      {error ? <div style={{ color: "#ef4444", marginBottom: 12 }}>{error}</div> : null}
      {loading && list.length === 0 ? (
        renderSkeleton()
      ) : groupedTaxa.length > 0 ? (
        groupedTaxa.map( renderGroup )
      ) : (
        <div className="fg-muted">
          {I18n.t( "id_summaries.demo.taxa_list.empty" )}
        </div>
      )}
    </div>
  );
};

export default TaxaList;

TaxaList.propTypes = {
  list: PropTypes.arrayOf( PropTypes.shape( {
    id: PropTypes.number,
    name: PropTypes.string,
    taxonGroup: PropTypes.string,
    photoSquareUrl: PropTypes.string,
    taxonPhotoId: PropTypes.oneOfType( [PropTypes.number, PropTypes.string] )
  } ) ),
  images: PropTypes.objectOf( PropTypes.string ),
  selectedId: PropTypes.number,
  loading: PropTypes.bool,
  error: PropTypes.string,
  onTileClick: PropTypes.func
};
