import _ from "lodash";
import React from "react";
import { COLORS } from "../../shared/util";

const urlForTaxon = t => (
  t ? `/taxa/${t.id}-${t.name.replace( /\W/g, "-" )}` : null
);
const urlForTaxonPhotos = ( t, params ) => {
  let url = `/taxa/${t.id}-${t.name.replace( /\W/g, "-" )}/browse_photos`;
  if ( params ) {
    url += `?${_.map( params, ( v, k ) => `${k}=${v}` ).join( "&" )}`;
  }
  return url;
};
const urlForUser = u => `/people/${u.login}`;
const urlForPlace = p => `/places/${p.slug || p.id}`;

const defaultObservationParams = ( state, options = { } ) => {
  const { config } = state;
  const params = {
    verifiable: true,
    taxon_id: state.taxon.taxon ? state.taxon.taxon.id : null,
    place_id: state.config.chosenPlace ? state.config.chosenPlace.id : null,
    preferred_place_id: state.config.preferredPlace ? state.config.preferredPlace.id : null
  };
  if ( state.config.chosenPlace ) {
    // TODO: explore should use integer IDs until the explore-apiv2 branch is merged
    params.place_id = ( config.testingApiV2 && !options.forExplore )
      ? state.config.chosenPlace.uuid
      : state.config.chosenPlace.id;
  }
  return _.pickBy( params, v => !_.isNil( v ) );
};

const localizedPhotoAttribution = ( photo, options = { } ) => {
  const separator = options.separator || "";
  let userName = options.name || "";
  if ( userName.length === 0 ) userName = photo.native_realname || userName;
  if ( userName.length === 0 ) userName = photo.native_username || userName;
  const user = photo.user || options.user || (
    options.observation ? options.observation.user : null
  );
  if ( user && userName.length === 0 ) {
    userName = user.name || user.login || userName;
  }
  if ( userName.length === 0 && photo.attribution ) {
    const matches = photo.attribution.match( /\(.+\) (.+?),/ );
    if ( matches ) {
      userName = matches[1];
    }
  }
  userName = userName.length === 0 ? I18n.t( "unknown" ) : userName;
  let s;
  if ( photo.license_code === "pd" ) {
    s = I18n.t( "copyright.no_known_copyright_restrictions", {
      name: userName,
      license_name: I18n.t( "public_domain" )
    } );
  } else if ( photo.license_code === "cc0" ) {
    if ( userName === I18n.t( "unknown" ) ) {
      s = "";
    } else {
      s = I18n.t( "by_user", { user: userName } );
    }
  } else {
    s = `(c) ${userName}`;
  }
  let url;
  let rights = I18n.t( "all_rights_reserved" );
  if ( photo.license_code ) {
    if ( s.length > 0 ) {
      s += separator;
    }
    if ( photo.license_code === "cc0" ) {
      url = "http://creativecommons.org/publicdomain/zero/1.0/";
      rights = `${I18n.t( "copyright.no_rights_reserved" )} (CC0)`;
    } else {
      url = photo.license_code === "pd"
        ? "https://en.wikipedia.org/wiki/Public_domain"
        : `http://creativecommons.org/licenses/${photo.license_code.replace( /cc-?/, "" )}/4.0`;
      rights = `${I18n.t( "some_rights_reserved" )}
        (${photo.license_code.replace( /cc-?/, "CC " ).toUpperCase( )})`;
    }
  }
  let final = s && s.length > 0 ? `${s} – ` : "";
  if ( url ) {
    final += `<a href=${url} title=${photo.license_code}>${rights}</a>`;
  } else {
    final += rights;
  }
  return final;
};

const commasAnd = items => {
  const listWithNItems = I18n.t( "list_with_n_items", { one: "-ONE-", two: "-TWO-", three: "-THREE-" } );
  const listWithTwoItems = I18n.t( "list_with_two_items", { one: "-ONE-", two: "-TWO-" } );
  const separator = listWithNItems.match( /-ONE-(.*)-TWO-/ )[1];
  const finalSeparator = listWithNItems.match( /-TWO-(.*)-THREE-/ )[1];
  const twoItemSeparator = listWithTwoItems.match( /-ONE-(.*)-TWO-/ )[1];
  if ( items.length <= 2 ) {
    return items.join( twoItemSeparator );
  }
  const last = items.pop( );
  return `${items.join( separator )}${finalSeparator}${last}`;
};

const windowStateForTaxon = taxon => {
  let scinameWithRank = taxon.name;
  if ( taxon.rank_level > 10 ) {
    scinameWithRank = `${I18n.t( `ranks.${taxon.rank.toString().toLowerCase()}` )} ${taxon.name}`;
  } else if ( taxon.rank_level < 10 ) {
    let rankPiece;
    if ( taxon.rank === "variety" ) {
      rankPiece = "var.";
    } else if ( taxon.rank === "subspecies" ) {
      rankPiece = "ssp.";
    } else if ( taxon.rank === "form" ) {
      rankPiece = "f.";
    }
    if ( rankPiece ) {
      const namePieces = taxon.name.split( " " );
      scinameWithRank = [
        namePieces.slice( 0, namePieces.length - 1 ).join( " " ),
        rankPiece,
        namePieces[namePieces.length - 1]
      ].join( " " );
    }
  }
  let title = scinameWithRank;
  if ( taxon.preferred_common_name ) {
    title = `${iNatModels.Taxon.titleCaseName( taxon.preferred_common_name )} (${scinameWithRank})`;
  }
  const state = {
    taxon: {
      id: taxon.id,
      name: taxon.name,
      preferred_common_name: taxon.preferred_common_name,
      iconic_taxon_name: taxon.iconic_taxon_name,
      rank_level: taxon.rank_level,
      rank: taxon.rank,
      is_active: taxon.is_active,
      ancestor_ids: taxon.ancestor_ids
    }
  };
  return {
    state,
    title,
    url: `${urlForTaxon( taxon )}${window.location.search}`
  };
};

const taxonLayerForTaxon = ( taxon, options = {} ) => {
  const {
    currentUser,
    updateCurrentUser,
    observation
  } = options;
  const {
    prefers_captive_obs_maps: currentUserPrefersCaptiveObs,
    prefers_gbif_layer_maps: currentUserPrefersGbifLayer,
    prefers_medialess_obs_maps: currentUserPrefersMedialessObs
  } = currentUser || {
    prefers_captive_obs_maps: false,
    prefers_gbif_layer_maps: false,
    prefers_medialess_obs_maps: false
  };
  return {
    taxon,
    observationLayers: [
      {
        label: I18n.t( "verifiable_observations" ),
        verifiable: true
      },
      {
        label: I18n.t( "observations_without_media" ),
        verifiable: false,
        captive: false,
        photos: false,
        sounds: false,
        color: COLORS.maroon,
        disabled: !currentUserPrefersMedialessObs,
        observation_id: observation
          && observation.obscured
          && observation.private_geojson
          && observation.id,
        onChange: currentUser
          && ( e => updateCurrentUser( { prefers_medialess_obs_maps: e.target.checked } ) )
      },
      {
        label: I18n.t( "captive_cultivated" ),
        verifiable: false,
        captive: true,
        color: COLORS.blue,
        observation_id: observation
          && observation.obscured
          && observation.private_geojson
          && observation.id,
        disabled: !currentUserPrefersCaptiveObs,
        onChange: currentUser
          && ( e => updateCurrentUser( { prefers_captive_obs_maps: e.target.checked } ) )
      }
    ],
    gbif: {
      disabled: !currentUserPrefersGbifLayer,
      legendColor: "#F7005A",
      onChange: currentUser && ( e => updateCurrentUser( {
        prefers_gbif_layer_maps: e.target.checked
      } ) )
    },
    places: true,
    ranges: true
  };
};

const RANK_LEVELS = {
  root: 100,
  kingdom: 70,
  subkingdom: 67,
  phylum: 60,
  subphylum: 57,
  superclass: 53,
  class: 50,
  subclass: 47,
  infraclass: 45,
  superorder: 43,
  order: 40,
  suborder: 37,
  infraorder: 35,
  parvorder: 34.5,
  zoosection: 34,
  zoosubsection: 33.5,
  superfamily: 33,
  epifamily: 32,
  family: 30,
  subfamily: 27,
  supertribe: 26,
  tribe: 25,
  subtribe: 24,
  genus: 20,
  genushybrid: 20,
  subgenus: 15,
  section: 13,
  subsection: 12,
  species: 10,
  hybrid: 10,
  subspecies: 5,
  variety: 5,
  form: 5,
  infrahybrid: 5
};

const MAX_TAXON_PHOTOS = 12;

export {
  urlForTaxon,
  urlForTaxonPhotos,
  urlForUser,
  urlForPlace,
  defaultObservationParams,
  localizedPhotoAttribution,
  commasAnd,
  windowStateForTaxon,
  taxonLayerForTaxon,
  RANK_LEVELS,
  MAX_TAXON_PHOTOS
};
