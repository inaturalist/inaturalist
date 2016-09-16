import _ from "lodash";
import fetch from "isomorphic-fetch";
import moment from "moment-timezone";

const util = class util {

  static isOnline( callback ) {
    // temporary until we have a ping API
    fetch( "/pages/about", {
      method: "head",
      mode: "no-cors",
      cache: "no-store" } ).
    then( ( ) => callback( true ) ).
    catch( ( ) => callback( false ) );
  }

  // returns a Promise
  static reverseGeocode( lat, lng ) {
    /* global google */
    const geocoder = new google.maps.Geocoder;
    return new Promise( ( resolve ) => {
      geocoder.geocode( { location: { lat, lng } }, ( results, status ) => {
        let locationName;
        if ( status === google.maps.GeocoderStatus.OK ) {
          if ( results[0] ) {
            results.reverse( );
            const neighborhood = _.find( results, r => _.includes( r.types, "neighborhood" ) );
            const locality = _.find( results, r => _.includes( r.types, "locality" ) );
            const sublocality = _.find( results, r => _.includes( r.types, "sublocality" ) );
            const level2 = _.find( results, r =>
              _.includes( r.types, "administrative_area_level_2" ) );
            const level1 = _.find( results, r =>
              _.includes( r.types, "administrative_area_level_1" ) );
            if ( neighborhood ) {
              locationName = neighborhood.formatted_address;
            } else if ( sublocality ) {
              locationName = sublocality.formatted_address;
            } else if ( locality ) {
              locationName = locality.formatted_address;
            } else if ( level2 ) {
              locationName = level2.formatted_address;
            } else if ( level1 ) {
              locationName = level1.formatted_address;
            }
          }
        }
        resolve( locationName );
      } );
    } );
  }

  static gpsCoordConvert( c ) {
    return ( c[0][0] / c[0][1] ) +
           ( ( c[1][0] / c[1][1] ) / 60 ) +
           ( ( c[2][0] / c[2][1] ) / 3600 );
  }

  static countPending( files ) {
    return _.size( _.pickBy( files, f =>
      f.uploadState === "pending" || f.uploadState === "uploading"
    ) );
  }

  static dateInvalid( dateString ) {
    let invalidDate = false;
    if ( dateString ) {
      const m = moment( dateString );
      const now = moment( );
      // valid dates must at least have year/month/day
      if ( !moment( dateString.split( " " )[0], "YYYY/MM/DD", true ).isValid( ) ) {
        invalidDate = true;
      } else if ( !m.isValid( ) || ( m.isAfter( now ) && !m.isSame( now, "day" ) ) ) {
        // dates in the future are also invalid
        invalidDate = true;
      }
    }
    return invalidDate;
  }

};

export default util;
