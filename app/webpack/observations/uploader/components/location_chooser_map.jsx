import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import {
  withGoogleMap,
  GoogleMap,
  Circle,
  Marker,
  OverlayView
} from "react-google-maps";
import { SearchBox } from "react-google-maps/lib/components/places/SearchBox";
import util from "../models/util";
import { objectToComparable } from "../../../shared/util";

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
  origin: new google.maps.Point( 0, 0 ),
  anchor: new google.maps.Point( 625, 0 )
};

// https://github.com/tomchentw/react-google-maps/issues/220#issuecomment-319269122
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
  }

  componentDidMount( ) {
    const { center } = this.props;
    if ( this.map && !center ) {
      setTimeout( this.fitCircles, 10 );
    }
    if ( this.map ) {
      iNaturalist.log( { "map-placement": "observations-upload-location-chooser" } );
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
    const comparable = objectToComparable(
      Object.assign( {}, _.filter( this.props, ( v, k ) => comparableKeys.indexOf( k ) >= 0 ), {
        obsCards: _.keys( obsCards )
      } )
    );
    const nextComparable = objectToComparable(
      Object.assign( {}, _.filter( nextProps, ( v, k ) => comparableKeys.indexOf( k ) >= 0 ), {
        obsCards: _.keys( obsCards )
      } )
    );
    return comparable !== nextComparable;
  }

  componentDidUpdate( prevProps ) {
    const {
      show,
      center,
      fitCurrentCircle
    } = this.props;
    if ( show && !prevProps.show ) {
      if ( !center ) {
        setTimeout( this.fitCircles, 10 );
      }
    } else if (
      show
      && fitCurrentCircle
      && objectToComparable( center ) !== objectToComparable( prevProps.center )
    ) {
      setTimeout( this.fitCurrentCircle, 10 );
    }
  }

  fitCircles( ) {
    if ( !this.map ) { return; }
    const circles = [];
    const { obsCards } = this.props;
    _.each( obsCards, c => {
      if ( c.latitude ) {
        /* global google */
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

  handleMapClick( event ) {
    const { latLng } = event;
    const zoom = this.map.getZoom( );
    const radius = Math.round( ( 1 / ( 2 ** zoom ) ) * 2000000 );
    this.moveCircle( latLng, radius, { geocode: true } );
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
        if ( goTime === lastCenterChange ) {
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

  handlePlacesChanged( ) {
    const places = this.searchbox.getPlaces();
    const { updateState } = this.props;
    let searchQuery;
    let lat;
    let lng;
    let searchedForCoord = false;
    if ( this.searchboxInput ) {
      searchQuery = this.searchboxInput.value;
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
        const goodComponents = _.filter( places[0].address_components,
          p => _.intersection( p.types, goodTypes ).length > 0 );
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
    if ( viewport && !searchedForCoord ) {
      // radius is the largest distance from geom center to one of the bounds corners
      radius = _.max( [
        LocationChooserMap.distanceInMeters( lat, lng,
          viewport.getCenter().lat(), viewport.getCenter().lng() ),
        LocationChooserMap.distanceInMeters( lat, lng,
          viewport.getNorthEast().lat(), viewport.getNorthEast().lng() )
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

  render( ) {
    // const props = this.props;
    const {
      lat,
      lng,
      radius,
      obsCard,
      obsCards,
      zoom,
      bounds,
      center: existingCenter,
      updateState,
      config,
      updateCurrentUser
    } = this.props;
    let center;
    const circles = [];
    const markers = [];
    const overlays = [];
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
      center = { lat: latNum, lng: lngNum };
    }
    _.each( obsCards, c => {
      if ( c.latitude && !( obsCard && obsCard.id === c.id ) ) {
        const cardImage = $( `[data-id=${c.id}] .carousel-inner img:first` );
        if ( cardImage.length > 0 ) {
          overlays.push(
            <OverlayView
              key={`overlay${c.id}`}
              position={{ lat: c.latitude, lng: c.longitude }}
              mapPaneName={OverlayView.OVERLAY_LAYER}
            >
              <div className="photo-marker">
                <img src={cardImage[0].src} alt="" />
              </div>
            </OverlayView>
          );
        } else {
          markers.push(
            <Marker
              key={`marker${c.id}`}
              position={{ lat: c.latitude, lng: c.longitude }}
              icon={Object.assign( { }, markerSVG, {
                fillColor: "#333"
              } )}
            />
          );
        }
      }
    } );
    if ( center ) {
      circles.push(
        <Circle
          key="circle"
          ref={ref => { this.circle = ref; }}
          center={center}
          radius={Number( radius )}
          onClick={this.handleMapClick}
          onRadiusChanged={this.radiusChanged}
          onCenterChanged={this.centerChanged}
          options={{
            strokeColor: "#DF0101",
            strokeOpacity: 0.8,
            fillColor: "#DF0101",
            fillOpacity: 0.35
          }}
          editable
          draggable
        />
      );
      if ( !radius ) {
        markers.push(
          <Marker
            key="marker"
            position={{ lat: center.lat, lng: center.lng }}
            icon={Object.assign( { }, markerSVG, {
              fillColor: "#DF0101",
              scale: 0.03
            } )}
          />
        );
      }
    }
    return (
      <GoogleMap
        ref={ref => { this.map = ref; }}
        defaultZoom={zoom || 1}
        defaultCenter={existingCenter || { lat: 30, lng: 15 }}
        defaultTilt={0}
        defaultMapTypeId={iNaturalist.Map.preferredMapTypeId( config.currentUser )}
        onClick={this.handleMapClick}
        onMapTypeIdChanged={( ) => {
          updateCurrentUser( { preferred_observations_search_map_type: this.map.getMapTypeId( ) } );
        }}
        onBoundsChanged={( ) => {
          const c = this.map.getCenter( );
          updateState( {
            locationChooser: {
              center: { lat: c.lat(), lng: c.lng() },
              bounds: this.map.getBounds( ),
              zoom: this.map.getZoom( )
            }
          } );
        }}
        options={{
          streetViewControl: false,
          fullscreenControl: true,
          rotateControl: false,
          gestureHandling: "greedy",
          controlSize: 26
        }}
      >
        {/*
        */}
        <SearchBox
          ref={ref => { this.searchbox = ref; }}
          bounds={bounds}
          onPlacesChanged={this.handlePlacesChanged}
          controlPosition={google.maps.ControlPosition.TOP_LEFT}
        >
          <input
            ref={ref => { this.searchboxInput = ref; }}
            type="text"
            placeholder={I18n.t( "search_for_a_location" )}
            style={{
              border: "1px solid transparent",
              borderRadius: "2px",
              boxShadow: "0 0px 5px rgba(0, 0, 0, 0.3)",
              boxSizing: "border-box",
              MozBoxSizing: "border-box",
              fontSize: "14px",
              lineHeight: "14px",
              height: "26px",
              marginTop: "6px",
              outline: "none",
              padding: "0 12px",
              textOverflow: "ellipses",
              width: "250px"
            }}
          />
        </SearchBox>
        { markers }
        { circles }
        { overlays }
      </GoogleMap>
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

// withGoogleMap is a HOC from react-google-maps. It requires that this
// component have the props containerElement and mapElement
export default withGoogleMap( LocationChooserMap );
