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
  const groupedTaxa = useMemo( () => {
    if ( !Array.isArray( list ) || list.length === 0 ) return [];
    const byGroup = list.reduce( ( acc, species ) => {
      const label = species?.taxonGroup && species.taxonGroup.trim().length > 0
        ? species.taxonGroup
        : fallbackGroupLabel;
      if ( !acc[label] ) acc[label] = [];
      acc[label].push( species );
      return acc;
    }, {} );
    const labels = Object.keys( byGroup ).sort( ( a, b ) => {
      if ( a === fallbackGroupLabel ) return 1;
      if ( b === fallbackGroupLabel ) return -1;
      return a.localeCompare( b );
    } );
    return labels.map( label => ( {
      label,
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
