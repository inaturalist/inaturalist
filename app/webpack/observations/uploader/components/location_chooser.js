import _ from "lodash";
import React, { PropTypes } from "react";
import { Modal, Button, Input, Glyphicon } from "react-bootstrap";
import { GoogleMapLoader, GoogleMap, Circle, SearchBox, Marker } from "react-google-maps";
import SelectionBasedComponent from "./selection_based_component";
import util from "../models/util";
var lastCenterChange = new Date().getTime();

class LocationChooser extends SelectionBasedComponent {

  static searchboxStyle( ) {
    return {
      border: "1px solid transparent",
      borderRadius: "2px",
      boxShadow: "0 2px 6px rgba(0, 0, 0, 0.3)",
      boxSizing: "border-box",
      MozBoxSizing: "border-box",
      fontSize: "14px",
      height: "36px",
      marginTop: "10px",
      outline: "none",
      padding: "0 12px",
      textOverflow: "ellipses",
      width: "250px"
    };
  }

  constructor( props, context ) {
    super( props, context );
    this.handleMapClick = this.handleMapClick.bind( this );
    this.close = this.close.bind( this );
    this.save = this.save.bind( this );
    this.handlePlacesChanged = this.handlePlacesChanged.bind( this );
    this.update = this.update.bind( this );
    this.fitCircles = this.fitCircles.bind( this );
    this.reverseGeocode = this.reverseGeocode.bind( this );
    this.radiusChanged = this.radiusChanged.bind( this );
    this.centerChanged = this.centerChanged.bind( this );
    this.moveCircle = this.moveCircle.bind( this );
    this.multiValued = this.multiValued.bind( this );
    this.placeholder = this.placeholder.bind( this );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.show && !prevProps.show && !this.props.center ) {
      setTimeout( this.fitCircles, 10 );
    }
  }

  fitCircles( ) {
    if ( !this.refs.map ) { return; }
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
      this.refs.map.fitBounds( bounds );
    }
  }

  handleMapClick( event ) {
    const latLng = event.latLng;
    const zoom = this.refs.map.getZoom( );
    const radius = Math.round( ( 1 / Math.pow( 2, zoom ) ) * 2000000 );
    this.moveCircle( latLng, radius, { geocode: true } );
  }

  moveCircle( center, radius, options = { } ) {
    this.props.updateState( { locationChooser: {
      lat: center.lat( ),
      lng: center.lng( ),
      center: this.refs.map.getCenter( ),
      bounds: this.refs.map.getBounds( ),
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

  close( ) {
    this.props.updateState( { locationChooser: { show: false } } );
  }

  save( ) {
    const attrs = {
      latitude: this.props.lat ? Number( this.props.lat ) : undefined,
      longitude: this.props.lat ? Number( this.props.lng ) : undefined,
      accuracy: this.props.radius ? Number( this.props.radius ) : undefined,
      center: this.refs.map.getCenter( ),
      bounds: this.refs.map.getBounds( ),
      zoom: this.refs.map.getZoom( ),
      locality_notes: this.props.notes
    };
    if ( !attrs.accuracy ) { attrs.accuracy = undefined; }
    if ( this.props.obsCard ) {
      this.props.updateObsCard( this.props.obsCard, attrs );
    } else {
      if ( !attrs.latitude && this.multiValued( "latitude" ) ) { delete attrs.latitude; }
      if ( !attrs.longitude && this.multiValued( "longitude" ) ) { delete attrs.longitude; }
      if ( !attrs.accuracy && this.multiValued( "accuracy" ) ) { delete attrs.accuracy; }
      if ( !attrs.locality_notes && this.multiValued( "locality_notes" ) ) {
        delete attrs.locality_notes;
      }
      this.props.updateSelectedObsCards( attrs );
    }
    this.close( );
  }

  reverseGeocode( lat, lng ) {
    util.reverseGeocode( lat, lng ).then( location => {
      if ( location ) {
        this.props.updateState( { locationChooser: { notes: location } } );
      }
    } );
  }

  handlePlacesChanged( ) {
    const places = this.refs.searchbox.getPlaces();
    if ( places.length > 0 ) {
      const geometry = places[0].geometry;
      if ( geometry.viewport ) {
        this.refs.map.fitBounds( geometry.viewport );
      } else {
        const lat = geometry.location.lat( );
        const lng = geometry.location.lng( );
        this.refs.map.fitBounds( new google.maps.LatLngBounds(
          new google.maps.LatLng( lat - 0.001, lng - 0.001 ),
          new google.maps.LatLng( lat + 0.001, lng + 0.001 ) ) );
      }
      const zoom = this.refs.map.getZoom( );
      this.props.updateState( { locationChooser: {
        lat: geometry.location.lat( ).toString( ),
        lng: geometry.location.lng( ).toString( ),
        center: this.refs.map.getCenter( ),
        bounds: this.refs.map.getBounds( ),
        radius: Math.round( ( 1 / Math.pow( 2, zoom ) ) * 10000000 ).toString( ),
        notes: places[0].formatted_address
      } } );
    }
  }

  update( field, e ) {
    const updates = { [field]: e.target.value };
    if ( field === "lat" || field === "lng" ) {
      updates.radius = this.props.radius || "1";
      let lat = updates.lat || this.props.lat;
      lat = lat ? Number( lat ) : undefined;
      let lng = updates.lng || this.props.lng;
      lng = lng ? Number( lng ) : undefined;
      this.reverseGeocode( lat, lng );
    }
    this.props.updateState( { locationChooser: updates } );
  }

  multiValued( prop ) {
    return this.props.obsCards &&
           this.valuesOf( prop, this.props.obsCards ).length > 1;
  }

  placeholder( prop ) {
    return this.multiValued( prop ) ? "multiple" : undefined;
  }

  render() {
    let center;
    let circles = [];
    let markers = [];
    let canSave = false;
    const latNum = Number( this.props.lat );
    const lngNum = Number( this.props.lng );
    if ( this.props.lat &&
         this.props.lng &&
         !_.isNaN( latNum ) &&
         !_.isNaN( lngNum ) &&
         _.inRange( latNum, -89.999, 90 ) &&
         _.inRange( lngNum, -179.999, 180 ) ) {
      center = { lat: latNum, lng: lngNum };
      canSave = true;
    } else if ( !this.props.lat && !this.props.lng ) {
      canSave = true;
    }
    _.each( this.props.obsCards, c => {
      if ( c.latitude && !( this.props.obsCard && this.props.obsCard.id === c.id ) ) {
        markers.push(
          <Marker key={`marker${c.id}`}
            position={{ lat: c.latitude, lng: c.longitude }}
            icon={{
              path: "M -4,-4 4,4 M 4,-4 -4,4",
              strokeColor: "#337ab7",
              strokeWeight: 4,
              scale: 1
            }}
          />
        );
        circles.push(
          <Circle key={`circle${c.id}`}
            center={{ lat: c.latitude, lng: c.longitude }}
            radius={c.accuracy || 0}
            onClick={ this.handleMapClick }
            options={{
              strokeColor: "#337ab7",
              strokeOpacity: 0.6,
              fillColor: "#337ab7",
              fillOpacity: 0.35
            }}
          />
        );
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
    }
    const glyph = this.props.notes && ( <Glyphicon glyph="map-marker" /> );
    return (
      <Modal show={ this.props.show } className="location" onHide={ this.close }>
        <Modal.Header closeButton>
          <Modal.Title>
            { glyph }
            { this.props.notes || I18n.t( "location" ) }
          </Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <GoogleMapLoader
            containerElement={
              <div
                { ...this.props }
                className="map"
              />
            }
            googleMapElement={
              <GoogleMap
                ref="map"
                defaultZoom={ this.props.zoom || 1 }
                defaultCenter={ this.props.center || center || { lat: 30, lng: 15 } }
                onClick={ this.handleMapClick }
                options={{ streetViewControl: false }}
              >
                <SearchBox
                  bounds={ this.props.bounds }
                  onPlacesChanged={ this.handlePlacesChanged }
                  controlPosition={ google.maps.ControlPosition.TOP_LEFT }
                  ref="searchbox"
                  placeholder={ I18n.t( "search_for_a_location" ) }
                  style={ LocationChooser.searchboxStyle( ) }
                />
                { markers }
                { circles }
              </GoogleMap>
            }
          />
          <div className="form">
            <Input
              key="lat"
              type="text"
              label={ I18n.t( "latitude" ) }
              value={ this.props.lat }
              placeholder={ this.placeholder( "latitude" ) }
              onChange={ e => this.update( "lat", e ) }
            />
            <Input
              key="lng"
              type="text"
              label={ I18n.t( "longitude" ) }
              value={ this.props.lng }
              placeholder={ this.placeholder( "longitude" ) }
              onChange={ e => this.update( "lng", e ) }
            />
            <Input
              key="radius"
              type="text"
              label={ I18n.t( "accuracy_meters" ) }
              value={ this.props.radius }
              placeholder={ this.placeholder( "accuracy" ) }
              onChange={ e => this.update( "radius", e ) }
            />
            <Input
              className="notes"
              key="notes"
              type="text"
              label={ I18n.t( "locality_notes" ) }
              value={ this.props.notes }
              placeholder={ this.placeholder( "locality_notes" ) }
              onChange={ e => this.update( "notes", e ) }
            />
          </div>
        </Modal.Body>
        <Modal.Footer>
          <Button onClick={ this.close }>{ I18n.t( "cancel" ) }</Button>
          <Button
            onClick={ this.save }
            bsStyle="primary"
            disabled={ !canSave }
          >
            { I18n.t( "save" ) }
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

LocationChooser.propTypes = {
  show: PropTypes.bool,
  default: PropTypes.object,
  obsCard: PropTypes.object,
  obsCards: PropTypes.object,
  setState: PropTypes.func,
  updateState: PropTypes.func,
  updateObsCard: PropTypes.func,
  updateSelectedObsCards: PropTypes.func,
  lat: PropTypes.any,
  lng: PropTypes.any,
  radius: PropTypes.any,
  zoom: PropTypes.number,
  center: PropTypes.object,
  bounds: PropTypes.object,
  notes: PropTypes.string
};

export default LocationChooser;
