
import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import LazyLoad from "react-lazy-load";
import { Button } from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../taxa/shared/components/taxon_photo";
import { urlForTaxon } from "../../../taxa/shared/util";
import { COLORS } from "../../../shared/util";
import TaxonMap from "./taxon_map";

const SuggestionRow = ( {
  taxon,
  observation,
  details,
  chooseTaxon,
  setDetailTaxon,
  source,
  config,
  updateCurrentUser
} ) => {
  const taxonPhotos = _
    .uniq( taxon.taxonPhotos, tp => `${tp.photo.id}-${tp.taxon.id}` )
    .slice( 0, 2 );
  let backgroundSize = "cover";
  if (
    taxonPhotos.length === 1
    && taxonPhotos[0].photo.original_dimensions
    && (
      taxonPhotos[0].photo.original_dimensions.width
      <= taxonPhotos[0].photo.original_dimensions.height
    )
  ) {
    backgroundSize = "contain";
  }
  const currentUserPrefersMedialessObs = config.currentUser
    && config.currentUser.prefers_medialess_obs_maps;
  const taxonLayer = {
    taxon,
    gbif: { disabled: true, legendColor: "#F7005A" },
    places: true,
    ranges: true
  };
  if ( source === "rg_observations" ) {
    taxonLayer.observationLayers = [
      { label: I18n.t( "rg_observations" ), quality_grade: "research" }
    ];
  } else if ( source === "captive_observations" ) {
    taxonLayer.observationLayers = [
      {
        label: I18n.t( "captive_observations" ),
        captive: "true",
        color: COLORS.blue
      }
    ];
  } else {
    taxonLayer.observationLayers = [
      { label: I18n.t( "verifiable_observations" ), verifiable: true },
      {
        label: I18n.t( "observations_without_media" ),
        color: COLORS.maroon,
        verifiable: false,
        captive: false,
        photos: false,
        sounds: false,
        disabled: !currentUserPrefersMedialessObs,
        onChange: e => updateCurrentUser( {
          prefers_medialess_obs_maps: e.target.checked
        } )
      }
    ];
  }
  const obsForMap = _.pick( observation, [
    "geoprivacy",
    "id",
    "latitude",
    "longitude",
    "map_scale",
    "positional_accuracy",
    "public_positional_accuracy",
    "species_guess",
    "taxon",
    "user"
  ] );
  obsForMap.coordinates_obscured = observation.obscured && !observation.private_geojson;
  return (
    <div className="suggestion-row" key={`suggestion-row-${taxon.id}`}>
      <h3 className="d-flex justify-content-between">
        <SplitTaxon
          taxon={taxon}
          target="_blank"
          url={urlForTaxon( taxon )}
          onClick={e => {
            e.preventDefault( );
            setDetailTaxon( taxon );
            return false;
          }}
          user={config.currentUser}
          iconLink
        />
        <div className="btn-group pull-right">
          { details && ( details.vision_score || details.frequency_score ) ? (
            <div className="quiet btn btn-label btn-xs">
              { details.vision_score ? I18n.t( "visually_similar" ) : null }
              { details.vision_score && details.frequency_score ? <span> / </span> : null }
              { details.frequency_score ? I18n.t( "expected_nearby" ) : null }
            </div>
          ) : null }
          <Button
            bsSize="xs"
            bsStyle="primary"
            onClick={( ) => {
              chooseTaxon( taxon, {
                observation,
                vision: source === "visual"
              } );
            }}
          >
            { I18n.t( "select" ) }
          </Button>
        </div>
      </h3>
      <LazyLoad height={200} offsetVertical={1000}>
        <div className="suggestion-row-content">
          <div className="photos">
            { taxonPhotos.length === 0 ? (
              <div className="noresults">
                { I18n.t( "no_photos" ) }
              </div>
            ) : taxonPhotos.map( tp => (
              <TaxonPhoto
                key={`suggestions-row-photo-${tp.taxon.id}-${tp.photo.id}`}
                photo={tp.photo}
                taxon={taxon}
                height={200}
                backgroundSize={backgroundSize}
                showTaxonPhotoModal={p => {
                  const index = _.findIndex( taxon.taxonPhotos,
                    taxonPhoto => taxonPhoto.photo.id === p.id );
                  setDetailTaxon( taxon, { detailPhotoIndex: index } );
                }}
              />
            ) ) }
          </div>
          <TaxonMap
            placement="suggestion-row"
            showAllLayer={false}
            minZoom={2}
            zoomLevel={6}
            preserveViewport
            latitude={observation.latitude}
            longitude={observation.longitude}
            gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
            observations={[obsForMap]}
            gestureHandling="auto"
            reloadKey={`map-for-${observation.id}-${taxon.id}`}
            taxonLayers={[taxonLayer]}
            zoomControl={false}
            mapTypeControl={false}
            disableFullscreen
            currentUser={config.currentUser}
            updateCurrentUser={updateCurrentUser}
            showAccuracy
          />
        </div>
      </LazyLoad>
    </div>
  );
};

SuggestionRow.propTypes = {
  taxon: PropTypes.object.isRequired,
  observation: PropTypes.object.isRequired,
  details: PropTypes.object,
  chooseTaxon: PropTypes.func.isRequired,
  setDetailTaxon: PropTypes.func.isRequired,
  source: PropTypes.string,
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
};

SuggestionRow.defaultProps = {
  config: {}
};

export default SuggestionRow;
