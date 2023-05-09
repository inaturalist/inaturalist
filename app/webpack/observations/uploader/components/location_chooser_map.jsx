import React from "react";
import ReactDOM from "react-dom";
import PropTypes from "prop-types";
import _ from "lodash";
import util from "../models/util";
import { objectToComparable } from "../../../shared/util";
import PhotoMarkerOverlayView from "./photo_marker_overlay_view";
import GooglePlacesSearchBox from "./google_places_search_box";

let lastCenterChange = new Date().getTime();

const markerSVG = {
  path: "M648 1169q117 0 216 -60t156.5 -161t57.5 -218q0 -115 -70 -258q-69 -109 -158 -225.5t-143 "
  + "-179.5l-54 -62q-9 8 -25.5 24.5t-63.5 67.5t-91 103t-98.5 128t-95.5 148q-60 132 -60 249q0 88 "
  + "34 169.5t91.5 142t137 96.5t166.5 36zM652.5 974q-91.5 0 -156.5 -65 t-65 -157t65 -156.5t156.5 "
  + "-64.5t156.5 64.5t65 156.5t-65 157t-156.5 65z",
  fillOpacity: 1,
  strokeWeight: 0,
  scale: 0.02,
  rotation: 180,
  origin: typeof ( google ) !== "undefined" && new google.maps.Point( 0, 0 ),
  anchor: typeof ( google ) !== "undefined" && new google.maps.Point( 625, 0 )
};

class LocationChooserMap extends React.Component {
  // Haversine distance calc, adapted from http://www.movable-type.co.uk/scripts/latlong.html
  static distanceInMeters( lat1, lon1, lat2, lon2 ) {
    const earthRadius = 6370997; // m
    const degreesPerRadian = 57.2958;
    const dLat = ( lat2 - lat1 ) / degreesPerRadian;
    const dLon = ( lon2 - lon1 ) / degreesPerRadian;
    const lat1Mod = lat1 / degreesPerRadian;
    const lat2Mod = lat2 / degreesPerRadian;
    const a = Math.sin( dLat / 2 ) * Math.sin( dLat / 2 )
      + Math.sin( dLon / 2 ) * Math.sin( dLon / 2 ) * Math.cos( lat1Mod ) * Math.cos( lat2Mod );
    const c = 2 * Math.atan2( Math.sqrt( a ), Math.sqrt( 1 - a ) );
    const d = earthRadius * c;
    return d;
  }

  constructor( props, context ) {
    super( props, context );
    this.handleMapClick = this.handleMapClick.bind( this );
    this.handlePlacesChanged = this.handlePlacesChanged.bind( this );
    this.fitCircles = this.fitCircles.bind( this );
    this.fitCurrentCircle = this.fitCurrentCircle.bind( this );
    this.reverseGeocode = this.reverseGeocode.bind( this );
    this.radiusChanged = this.radiusChanged.bind( this );
    this.centerChanged = this.centerChanged.bind( this );
    this.moveCircle = this.moveCircle.bind( this );
    // This holds references to all the overlays on the map that need to get
    // removed when props change
    this.overlays = [];
  }

  componentDidMount( ) {
    const {
      center,
      config,
      center: existingCenter,
      fitCurrentCircle,
      show,
      updateCurrentUser,
      updateState,
      zoom
    } = this.props;
    const domNode = ReactDOM.findDOMNode( this );
    const map = new google.maps.Map( $( ".map-inner", domNode ).get( 0 ), {
      ...iNaturalist.Map.DEFAULT_GOOGLE_MAP_OPTIONS,
      zoom: zoom || 1,
      center: existingCenter || { lat: 30, lng: 15 },
      fullscreenControl: true,
      mapTypeId: iNaturalist.Map.preferredMapTypeId( config.currentUser )
    } );
    this.map = map;
    google.maps.event.addListener( map, "click", this.handleMapClick );
    google.maps.event.addListener( map, "maptypeid_changed", ( ) => {
      updateCurrentUser( { preferred_observations_search_map_type: this.map.getMapTypeId( ) } );
    } );
    google.maps.event.addListener( map, "bounds_changed", ( ) => {
      const c = map.getCenter( );
      updateState( {
        locationChooser: {
          center: { lat: c.lat(), lng: c.lng() },
          bounds: map.getBounds( ),
          zoom: map.getZoom( )
        }
      } );
    } );
    this.overlaysFromProps( );
    if ( map && !center ) {
      if ( !center ) {
        setTimeout( this.fitCircles, 10 );
      } else if ( show && fitCurrentCircle ) {
        setTimeout( this.fitCurrentCircle, 10 );
      }
    }
  }

  shouldComponentUpdate( nextProps ) {
    const comparableKeys = [
      "show",
      "lat",
      "lng",
      "radius",
      "zoom",
      "center",
      "bounds"
    ];
    const { obsCards } = this.props;
    const comparable = objectToComparable( {
      ..._.filter( this.props, ( v, k ) => comparableKeys.indexOf( k ) >= 0 ),
      obsCards: _.keys( obsCards )
    } );
    const nextComparable = objectToComparable( {
      ..._.filter( nextProps, ( v, k ) => comparableKeys.indexOf( k ) >= 0 ),
      obsCards: _.keys( nextProps.obsCards )
    } );
    return comparable !== nextComparable;
  }

  componentDidUpdate( prevProps ) {
    const { fitCurrentCircle } = this.props;
    this.overlaysFromProps( prevProps );
    if ( fitCurrentCircle ) {
      setTimeout( this.fitCurrentCircle, 10 );
    }
  }

  handleMapClick( event ) {
    const { latLng } = event;
    const zoom = this.map.getZoom( );
    const radius = Math.round( ( 1 / ( 2 ** zoom ) ) * 2000000 );
    this.moveCircle( latLng, radius, { geocode: true } );
  }

  handlePlacesChanged( input, places ) {
    const { updateState } = this.props;
    let searchQuery;
    let lat;
    let lng;
    let searchedForCoord = false;
    if ( input ) {
      searchQuery = input.value;
      const searchCoord = searchQuery.split( "," ).map( piece => parseFloat( piece, 16 ) );
      if (
        searchCoord[0] !== 0
        && searchCoord[0] > -90
        && searchCoord[0] < 90
        && searchCoord[1] !== 0
        && searchCoord[1] > -180
        && searchCoord[1] < 180
      ) {
        lat = searchCoord[0];
        lng = searchCoord[1];
        searchedForCoord = true;
      }
    }
    let notes;
    let radius;
    let viewport;
    if ( places.length > 0 ) {
      const { geometry } = places[0];
      ( { viewport } = geometry );
      lat = lat || geometry.location.lat( );
      lng = lng || geometry.location.lng( );
      // Set the locality notes using political entity names and omitting
      // street-level information
      const storeStreetAddress = false; // disabling until we figure out what we really want
      if (
        storeStreetAddress
        && places[0].address_components
        && places[0].address_components.length > 0
      ) {
        const goodTypes = ["political", "neighborhood"];
        const goodComponents = _.filter(
          places[0].address_components,
          p => _.intersection( p.types, goodTypes ).length > 0
        );
        notes = goodComponents
          .map( p => ( p.short_name || p.long_name ) )
          .join( ", " );
        if ( places[0].name && !places[0].name.match( /^\d+/ ) ) {
          notes = `${places[0].name}, ${notes}`;
        }
      } else {
        notes = places[0].formatted_address;
      }
    }
    if ( typeof ( google ) !== "undefined" ) {
      if ( viewport && !searchedForCoord ) {
        // radius is the largest distance from geom center to one of the bounds corners
        radius = _.max( [
          LocationChooserMap.distanceInMeters(
            lat,
            lng,
            viewport.getCenter().lat(),
            viewport.getCenter().lng()
          ),
          LocationChooserMap.distanceInMeters(
            lat,
            lng,
            viewport.getNorthEast().lat(),
            viewport.getNorthEast().lng()
          )
        ] );
        this.map.fitBounds( viewport );
      } else {
        if ( !searchedForCoord ) {
          notes = searchQuery || notes;
        }
        this.map.fitBounds(
          new google.maps.LatLngBounds(
            new google.maps.LatLng( lat - 0.001, lng - 0.001 ),
            new google.maps.LatLng( lat + 0.001, lng + 0.001 )
          )
        );
      }
    }
    let { manualPlaceGuess, notes: existingNotes } = this.props;
    if ( manualPlaceGuess && notes ) {
      notes = existingNotes;
    } else {
      manualPlaceGuess = false;
    }
    updateState( {
      locationChooser: {
        lat: lat ? lat.toString( ) : undefined,
        lng: lng ? lng.toString( ) : undefined,
        center: this.map.getCenter( ),
        bounds: this.map.getBounds( ),
        radius,
        notes,
        manualPlaceGuess
      }
    } );
  }

  // Remove existing overlays and repopulate them based on the props
  overlaysFromProps( prevProps = {} ) {
    const {
      lat,
      lng,
      obsCard: currentCard,
      obsCards,
      radius,
      show,
      center,
      fitCurrentCircle
    } = this.props;

    // Determine if we should re-render the overlays
    const comparableKeys = [
      "show",
      "lat",
      "lng",
      "radius"
    ];
    const comparable = objectToComparable( {
      ..._.filter( this.props, ( v, k ) => comparableKeys.indexOf( k ) >= 0 ),
      obsCards: _.keys( obsCards )
    } );
    const prevComparable = objectToComparable( {
      ..._.filter( prevProps, ( v, k ) => comparableKeys.indexOf( k ) >= 0 ),
      obsCards: _.keys( prevProps.obsCards )
    } );
    if ( comparable === prevComparable ) {
      return;
    }

    let newCenter;
    const latNum = Number( lat );
    const lngNum = Number( lng );
    if (
      lat
      && lng
      && !_.isNaN( latNum )
      && !_.isNaN( lngNum )
      && _.inRange( latNum, -89.999, 90 )
      && _.inRange( lngNum, -179.999, 180 )
    ) {
      newCenter = { lat: latNum, lng: lngNum };
    }

    // Delete existing overlays
    while ( this.overlays.length > 0 ) {
      const overlay = this.overlays.pop( );
      overlay.setMap( null );
    }

    // Add new circles
    if ( this.map && newCenter ) {
      this.circle = new google.maps.Circle( {
        map: this.map,
        center: newCenter,
        radius: Number( radius ),
        strokeColor: "#DF0101",
        strokeOpacity: 0.8,
        fillColor: "#DF0101",
        fillOpacity: 0.35,
        editable: true,
        draggable: true
      } );
      google.maps.event.addListener( this.circle, "click", this.handleMapClick );
      google.maps.event.addListener( this.circle, "radius_changed", this.radiusChanged );
      google.maps.event.addListener( this.circle, "center_changed", this.centerChanged );
      this.overlays.push( this.circle );
    }

    // Add new markers for obs cards
    _.each( obsCards, card => {
      if ( card.latitude && !( currentCard && currentCard.id === card.id ) ) {
        const cardImage = $( `[data-id=${card.id}] .carousel-inner img:first` );
        if ( cardImage.length > 0 ) {
          const overlay = new PhotoMarkerOverlayView(
            cardImage[0].src,
            { lat: card.latitude, lng: card.longitude }
          );
          overlay.setMap( this.map );
          this.overlays.push( overlay );
        } else {
          const marker = new google.maps.Marker( {
            map: this.map,
            position: { lat: card.latitude, lng: card.longitude },
            icon: { ...markerSVG, fillColor: "#333" }
          } );
          this.overlays.push( marker );
        }
      }
    } );

    // Add a new marker for the current obs
    if ( this.map && newCenter && !radius ) {
      const marker = new google.maps.Marker( {
        map: this.map,
        position: newCenter,
        icon: { ...markerSVG, fillColor: "#DF0101", scale: 0.03 }
      } );
      this.overlays.push( marker );
    }
  }

  radiusChanged( ) {
    if ( this.circle ) {
      this.moveCircle( this.circle.getCenter( ), this.circle.getRadius( ) );
    }
  }

  centerChanged( ) {
    const time = new Date().getTime();
    if ( time - lastCenterChange > 900 ) {
      const goTime = time;
      lastCenterChange = goTime;
      setTimeout( () => {
        if ( goTime === lastCenterChange && this.circle ) {
          this.moveCircle( this.circle.getCenter( ), this.circle.getRadius( ), { geocode: true } );
        }
      }, 1000 );
    }
  }

  reverseGeocode( lat, lng ) {
    const {
      manualPlaceGuess,
      notes,
      updateState
    } = this.props;
    if ( manualPlaceGuess && notes ) { return; }
    util.reverseGeocode( lat, lng ).then( location => {
      if ( location ) {
        updateState( {
          locationChooser: {
            notes: location,
            manualPlaceGuess: false
          }
        } );
      }
    } );
  }

  moveCircle( center, radius, options = { } ) {
    const { updateState } = this.props;
    updateState( {
      locationChooser: {
        lat: center.lat( ),
        lng: center.lng( ),
        center: this.map.getCenter( ),
        bounds: this.map.getBounds( ),
        radius
      }
    } );
    if ( options.geocode ) {
      this.reverseGeocode( center.lat( ), center.lng( ) );
    }
  }

  fitCircles( ) {
    if ( !this.map ) { return; }
    if ( typeof ( google ) === "undefined" ) return;
    const circles = [];
    const { obsCards } = this.props;
    _.each( obsCards, c => {
      if ( c.latitude ) {
        circles.push( new google.maps.Circle( {
          center: {
            lat: c.latitude,
            lng: c.longitude
          },
          radius: c.accuracy || 0
        } ) );
      }
    } );
    if ( circles.length > 0 ) {
      const bounds = new google.maps.LatLngBounds( );
      _.each( circles, c => {
        bounds.union( c.getBounds( ) );
      } );
      this.map.fitBounds( bounds );
    }
  }

  fitCurrentCircle( ) {
    const {
      center,
      radius,
      updateState
    } = this.props;
    if ( !this.map ) { return; }
    if ( !center ) { return; }
    if ( !radius ) {
      this.map.panTo( center );
    } else {
      const bounds = (
        new google.maps.Circle( {
          center,
          radius: radius || 0
        } )
      ).getBounds( );
      this.map.fitBounds( bounds );
    }
    updateState( { locationChooser: { fitCurrentCircle: false } } );
  }

  render( ) {
    const { bounds } = this.props;
    return (
      <div className="LocationChooserMap map">
        <div className="map-inner" />
        <GooglePlacesSearchBox
          bounds={bounds}
          onPlacesChanged={this.handlePlacesChanged}
        />
      </div>
    );
  }
}

LocationChooserMap.propTypes = {
  show: PropTypes.bool,
  obsCard: PropTypes.object,
  obsCards: PropTypes.object,
  updateState: PropTypes.func,
  lat: PropTypes.any,
  lng: PropTypes.any,
  radius: PropTypes.any,
  zoom: PropTypes.number,
  center: PropTypes.object,
  bounds: PropTypes.object,
  notes: PropTypes.string,
  manualPlaceGuess: PropTypes.bool,
  fitCurrentCircle: PropTypes.bool,
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
};

LocationChooserMap.defaultProps = {
  obsCards: {},
  config: {}
};

export default LocationChooserMap;
