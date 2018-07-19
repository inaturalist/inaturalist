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

let lastCenterChange = new Date().getTime();

const markerSVG = {
  path: "M648 1169q117 0 216 -60t156.5 -161t57.5 -218q0 -115 -70 -258q-69 -109 -158 -225.5t-143 " +
    "-179.5l-54 -62q-9 8 -25.5 24.5t-63.5 67.5t-91 103t-98.5 128t-95.5 148q-60 132 -60 249q0 88 " +
    "34 169.5t91.5 142t137 96.5t166.5 36zM652.5 974q-91.5 0 -156.5 -65 t-65 -157t65 -156.5t156.5 " +
    "-64.5t156.5 64.5t65 156.5t-65 157t-156.5 65z",
  fillOpacity: 1,
  strokeWeight: 0,
  scale: 0.02,
  rotation: 180,
  origin: new google.maps.Point( 0, 0 ),
  anchor: new google.maps.Point( 625, 0 )
};

// https://github.com/tomchentw/react-google-maps/issues/220#issuecomment-319269122
class LocationChooserMap extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.handleMapClick = this.handleMapClick.bind( this );
    // this.close = this.close.bind( this );
    // this.save = this.save.bind( this );
    this.handlePlacesChanged = this.handlePlacesChanged.bind( this );
    // this.update = this.update.bind( this );
    this.fitCircles = this.fitCircles.bind( this );
    this.reverseGeocode = this.reverseGeocode.bind( this );
    this.radiusChanged = this.radiusChanged.bind( this );
    this.centerChanged = this.centerChanged.bind( this );
    this.moveCircle = this.moveCircle.bind( this );
    // this.multiValued = this.multiValued.bind( this );
    // this.placeholder = this.placeholder.bind( this );
  }

  componentDidMount( ) {
    if ( this.map && !this.props.center ) {
      setTimeout( this.fitCircles, 10 );
    }
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.show && !prevProps.show ) {
      if ( !this.props.center ) {
        setTimeout( this.fitCircles, 10 );
      }
    }
  }
  fitCircles( ) {
    if ( !this.map ) { return; }
    const circles = [];
    _.each( this.props.obsCards, c => {
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

  handleMapClick( event ) {
    const latLng = event.latLng;
    const zoom = this.map.getZoom( );
    const radius = Math.round( ( 1 / Math.pow( 2, zoom ) ) * 2000000 );
    this.moveCircle( latLng, radius, { geocode: true } );
  }

  moveCircle( center, radius, options = { } ) {
    this.props.updateState( { locationChooser: {
      lat: center.lat( ),
      lng: center.lng( ),
      center: this.map.getCenter( ),
      bounds: this.map.getBounds( ),
      radius
    } } );
    if ( options.geocode ) {
      this.reverseGeocode( center.lat( ), center.lng( ) );
    }
  }

  radiusChanged( ) {
    if ( this.refs.circle ) {
      const circleState = this.refs.circle.state.circle;
      this.moveCircle( circleState.center, circleState.radius );
    }
  }

  centerChanged( ) {
    const time = new Date().getTime();
    if ( time - lastCenterChange > 900 ) {
      const goTime = time;
      lastCenterChange = goTime;
      setTimeout( () => {
        if ( goTime === lastCenterChange ) {
          const circleState = this.refs.circle.state.circle;
          this.moveCircle( circleState.center, circleState.radius, { geocode: true } );
        }
      }, 1000 );
    }
  }

  reverseGeocode( lat, lng ) {
    if ( this.props.manualPlaceGuess && this.props.notes ) { return; }
    util.reverseGeocode( lat, lng ).then( location => {
      if ( location ) {
        this.props.updateState( { locationChooser: {
          notes: location,
          manualPlaceGuess: false
        } } );
      }
    } );
  }

  handlePlacesChanged( ) {
    const places = this.searchbox.getPlaces();
    if ( places.length > 0 ) {
      const geometry = places[0].geometry;
      const lat = geometry.location.lat( );
      const lng = geometry.location.lng( );
      let notes = places[0].formatted_address;
      let radius;
      const viewport = geometry.viewport;
      if ( viewport ) {
        // radius is the largest distance from geom center to one of the bounds corners
        radius = _.max( [
          this.distanceInMeters( lat, lng,
            viewport.getCenter().lat(), viewport.getCenter().lng() ),
          this.distanceInMeters( lat, lng,
            viewport.getNorthEast().lat(), viewport.getNorthEast().lng() )
        ] );
        this.map.fitBounds( viewport );
      } else {
        notes = this.searchbox.state.inputElement.value || notes;
        this.map.fitBounds( new google.maps.LatLngBounds(
          new google.maps.LatLng( lat - 0.001, lng - 0.001 ),
          new google.maps.LatLng( lat + 0.001, lng + 0.001 ) ) );
      }
      let manualPlaceGuess = this.props.manualPlaceGuess;
      if ( manualPlaceGuess && this.props.notes ) {
        notes = this.props.notes;
      } else {
        manualPlaceGuess = false;
      }
      this.props.updateState( { locationChooser: {
        lat: lat ? lat.toString( ) : undefined,
        lng: lng ? lng.toString( ) : undefined,
        center: this.map.getCenter( ),
        bounds: this.map.getBounds( ),
        radius,
        notes,
        manualPlaceGuess
      } } );
    }
  }

  // Haversine distance calc, adapted from http://www.movable-type.co.uk/scripts/latlong.html
  distanceInMeters( lat1, lon1, lat2, lon2 ) {
    const earthRadius = 6370997; // m
    const degreesPerRadian = 57.2958;
    const dLat = ( lat2 - lat1 ) / degreesPerRadian;
    const dLon = ( lon2 - lon1 ) / degreesPerRadian;
    const lat1Mod = lat1 / degreesPerRadian;
    const lat2Mod = lat2 / degreesPerRadian;

    const a = Math.sin( dLat / 2 ) * Math.sin( dLat / 2 ) +
            Math.sin( dLon / 2 ) * Math.sin( dLon / 2 ) * Math.cos( lat1Mod ) * Math.cos( lat2Mod );
    const c = 2 * Math.atan2( Math.sqrt( a ), Math.sqrt( 1 - a ) );
    const d = earthRadius * c;
    return d;
  }

  render( ) {
    const props = this.props;
    let center;
    let circles = [];
    let markers = [];
    let overlays = [];
    // let canSave = false;
    const latNum = Number( this.props.lat );
    const lngNum = Number( this.props.lng );
    if ( this.props.lat &&
         this.props.lng &&
         !_.isNaN( latNum ) &&
         !_.isNaN( lngNum ) &&
         _.inRange( latNum, -89.999, 90 ) &&
         _.inRange( lngNum, -179.999, 180 ) ) {
      center = { lat: latNum, lng: lngNum };
      // canSave = true;
    } else if ( !this.props.lat && !this.props.lng ) {
      // canSave = true;
    }
    _.each( this.props.obsCards, c => {
      if ( c.latitude && !( this.props.obsCard && this.props.obsCard.id === c.id ) ) {
        const cardImage = $( `[data-id=${c.id}] .carousel-inner img:first` );
        if ( cardImage.length > 0 ) {
          overlays.push(
            <OverlayView key={ `overlay${c.id}` }
              position={ { lat: c.latitude, lng: c.longitude } }
              mapPaneName={ OverlayView.OVERLAY_LAYER }
            >
              <div className="photo-marker">
                <img src={ cardImage[0].src } />
              </div>
            </OverlayView>
          );
        } else {
          markers.push(
            <Marker key={`marker${c.id}`}
              position={{ lat: c.latitude, lng: c.longitude }}
              icon={ Object.assign( { }, markerSVG, {
                fillColor: "#333"
              } ) }
            />
          );
        }
      }
    } );
    if ( center ) {
      circles.push(
        <Circle key="circle" ref="circle"
          center={ center }
          radius={ Number( this.props.radius ) }
          onClick={ this.handleMapClick }
          onRadiusChanged={ this.radiusChanged }
          onCenterChanged={ this.centerChanged }
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
      if ( !this.props.radius ) {
        markers.push(
          <Marker key="marker"
            position={{ lat: center.lat, lng: center.lng }}
            icon={ Object.assign( { }, markerSVG, {
              fillColor: "#DF0101",
              scale: 0.03
            } ) }
          />
        );
      }
    }
    return (
      <GoogleMap
        ref={ ref => {
          this.map = ref;
        } }
        defaultZoom={ props.zoom || 1 }
        defaultCenter={ props.center || { lat: 30, lng: 15 } }
        onClick={ this.handleMapClick }
        onBoundsChanged={ ( ) => {
          this.props.updateState( { locationChooser: {
            center: this.map.getCenter( ),
            bounds: this.map.getBounds( ),
            zoom: this.map.getZoom( )
          } } );
        }}
        options={{
          streetViewControl: false,
          fullscreenControl: true,
          gestureHandling: "auto"
        }}
      >
        {/*
        */}
        <SearchBox
          ref={ ref => {
            this.searchbox = ref;
          } }
          bounds={ props.bounds }
          onPlacesChanged={ this.handlePlacesChanged }
          controlPosition={ google.maps.ControlPosition.TOP_LEFT }
        >
          <input
            type="text"
            placeholder={ I18n.t( "search_for_a_location" ) }
            style={ {
              border: "1px solid transparent",
              borderRadius: "2px",
              boxShadow: "0 0px 5px rgba(0, 0, 0, 0.3)",
              boxSizing: "border-box",
              MozBoxSizing: "border-box",
              fontSize: "13px",
              height: "28.5px",
              marginTop: "10px",
              outline: "none",
              padding: "0 12px",
              textOverflow: "ellipses",
              width: "250px"
            } }
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
  setState: PropTypes.func,
  selectedObsCards: PropTypes.object,
  updateState: PropTypes.func,
  // updateObsCard: PropTypes.func,
  // updateSelectedObsCards: PropTypes.func,
  // updateSingleObsCard: PropTypes.bool,
  lat: PropTypes.any,
  lng: PropTypes.any,
  radius: PropTypes.any,
  zoom: PropTypes.number,
  center: PropTypes.object,
  bounds: PropTypes.object,
  notes: PropTypes.string,
  manualPlaceGuess: PropTypes.bool
};

// withGoogleMap is a HOC from react-google-maps. It requires that this
// component have the props containerElement and mapElement
export default withGoogleMap( LocationChooserMap );
