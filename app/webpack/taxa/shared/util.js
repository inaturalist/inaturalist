import isomorphicFetch from "isomorphic-fetch";
import _ from "lodash";
import React from "react";

const urlForTaxon = ( t ) => `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}`;
const urlForTaxonPhotos = ( t, params ) => {
  let url = `/taxa/${t.id}-${t.name.split( " " ).join( "-" )}/browse_photos`;
  if ( params ) {
    url += `?${_.map( params, ( v, k ) => `${k}=${v}` ).join( "&" )}`;
  }
  return url;
};
const urlForUser = ( u ) => `/people/${u.login}`;

// Light wrapper around isomorphic fetch to ensure credentials are always passed through
const fetch = ( url, options ) =>
  isomorphicFetch( url, Object.assign( {}, options, { credentials: "same-origin" } ) );

const defaultObservationParams = ( state ) => ( {
  verifiable: true,
  taxon_id: state.taxon.taxon ? state.taxon.taxon.id : null,
  place_id: state.config.chosenPlace ? state.config.chosenPlace.id : null
} );

const localizedPhotoAttribution = ( photo, options = { } ) => {
  const separator = options.separator || "";
  let userName = options.name || "";
  if ( userName.length === 0 ) userName = photo.native_realname || userName;
  if ( userName.length === 0 ) userName = photo.native_username || userName;
  const user = photo.user || options.user || ( options.observation ? options.observation.user : null );
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
    s = _.capitalize( I18n.t( "by_user", { user: userName } ) );
  } else {
    s = `(c) ${userName}`;
  }
  let url;
  let rights = I18n.t( "all_rights_reserved" );
  if ( photo.license_code ) {
    s += separator;
    if ( photo.license_code === "cc0" ) {
      url = "http://creativecommons.org/publicdomain/zero/1.0/";
      rights = `${I18n.t( "copyright.no_rights_reserved" )} (CC0)`;
    } else {
      url = `http://creativecommons.org/licenses/${photo.license_code.replace( /cc\-?/, "" )}/4.0`;
      rights = `${I18n.t( "some_rights_reserved" )}
        (${photo.license_code.replace( /cc\-?/, "CC " ).toUpperCase( )})`;
    }
  }
  return (
    <span>
      { s }, { url ? <a href={url} title={photo.license_code}>{ rights }</a> : rights }
    </span>
  );
};

const commasAnd = ( items ) => {
  if ( items.length <= 2 ) {
    return items.join( ` ${I18n.t( "and" )} ` );
  }
  const last = items.pop( );
  return `${items.join( ", " )}, ${I18n.t( "and" )} ${last}`;
};

export {
  urlForTaxon,
  urlForTaxonPhotos,
  urlForUser,
  fetch,
  defaultObservationParams,
  localizedPhotoAttribution,
  commasAnd
};
