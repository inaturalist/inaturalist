import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Modal, Button, Input } from "react-bootstrap";
import { GoogleMapLoader, GoogleMap, Circle, SearchBox } from "react-google-maps";


class LocationChooser extends Component {

  static searchboxStyle( ) {
    return {
      border: "1px solid transparent",
      borderRadius: "1px",
      boxShadow: "0 2px 6px rgba(0, 0, 0, 0.3)",
      boxSizing: "border-box",
      MozBoxSizing: "border-box",
      fontSize: "14px",
      height: "32px",
      marginTop: "12px",
      outline: "none",
      padding: "0 12px",
      textOverflow: "ellipses",
      width: "200px"
    };
  }

  constructor( props, context ) {
    super( props, context );
    this.handleMapClick = this.handleMapClick.bind( this );
    this.close = this.close.bind( this );
    this.save = this.save.bind( this );
    this.handlePlacesChanged = this.handlePlacesChanged.bind( this );
    this.updateLatitude = this.updateLatitude.bind( this );
    this.updateLongitude = this.updateLongitude.bind( this );
    this.updateRadius = this.updateRadius.bind( this );
  }

  handleMapClick( event ) {
    const latLng = event.latLng;
    const zoom = this._googleMapComponent.getZoom( );
    this.props.updateState( { locationChooser: {
      center: {
        lat: latLng.lat(),
        lng: latLng.lng()
      },
      bounds: this._googleMapComponent.getBounds( ),
      radius: Math.round( ( 1 / Math.pow( 2, zoom ) ) * 5000000 )
    } } );
  }

  close( ) {
    this.props.setState( { locationChooser: { open: false } } );
  }

  save( ) {
    const zoom = this._googleMapComponent.getZoom( );
    const attrs = {
      latitude: this.props.center.lat,
      longitude: this.props.center.lng,
      accuracy: this.props.radius,
      bounds: this.props.bounds,
      zoom
    };
    if ( this.props.obsCard ) {
      this.props.updateObsCard( this.props.obsCard, attrs );
    } else {
      this.props.updateSelectedObsCards( attrs );
    }
    this.close( );
  }

  handlePlacesChanged( ) {
    const places = this.refs.searchbox.getPlaces();
    if ( places.length > 0 ) {
      const geometry = places[0].geometry;
      if ( geometry.viewport ) {
        this._googleMapComponent.fitBounds( geometry.viewport );
      } else {
        const lat = geometry.location.lat( );
        const lng = geometry.location.lng( );
        this._googleMapComponent.fitBounds( new google.maps.LatLngBounds(
          new google.maps.LatLng( lat - 0.001, lng - 0.001 ),
          new google.maps.LatLng( lat + 0.001, lng + 0.001 ) ) );
      }
      const zoom = this._googleMapComponent.getZoom( );
      this.props.updateState( { locationChooser: {
        center: {
          lat: geometry.location.lat( ),
          lng: geometry.location.lng( )
        },
        bounds: this._googleMapComponent.getBounds( ),
        radius: Math.round( ( 1 / Math.pow( 2, zoom ) ) * 10000000 )
      } } );
    }
  }

  updateLatitude( e ) {
    if ( !e.target.value || _.isNaN( Number( e.target.value ) ) ) { return; }
    const zoom = this._googleMapComponent.getZoom( );
    this.props.updateState( { locationChooser: {
      center: {
        lat: Number( e.target.value ),
        lng: this.props.center ? this.props.center.lng : 0
      },
      radius: this.radius || Math.round( ( 1 / Math.pow( 2, zoom ) ) * 10000000 )
    } } );
  }

  updateLongitude( e ) {
    if ( !e.target.value || _.isNaN( Number( e.target.value ) ) ) { return; }
    const zoom = this._googleMapComponent.getZoom( );
    this.props.updateState( { locationChooser: {
      center: {
        lat: this.props.center ? this.props.center.lng : 0,
        lng: Number( e.target.value )
      },
      radius: this.radius || Math.round( ( 1 / Math.pow( 2, zoom ) ) * 10000000 )
    } } );
  }

  updateRadius( e ) {
    if ( !e.target.value || _.isNaN( Number( e.target.value ) ) ) { return; }
    this.props.updateState( { locationChooser: {
      radius: Number( e.target.value )
    } } );
  }

  render() {
    let circle;
    if ( this.props.center ) {
      circle = (
        <Circle ref="circle"
          center={this.props.center}
          radius={this.props.radius}
          editable
        />
      );
    }
    return (
      <Modal show={ this.props.open } className="location" onHide={ this.close }>
        <Modal.Header closeButton>
          <Modal.Title>Modal heading</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <GoogleMapLoader
            containerElement={
              <div
                {...this.props}
                style={{ height: "320px" }}
              />
            }
            googleMapElement={
              <GoogleMap
                ref={ map => { this._googleMapComponent = map; } }
                defaultZoom={ this.props.zoom || 2 }
                defaultCenter={this.props.center || { lat: 0, lng: 0 }}
                onClick={this.handleMapClick}
              >
                <SearchBox
                  bounds={this.props.bounds}
                  onPlacesChanged={ this.handlePlacesChanged }
                  controlPosition={google.maps.ControlPosition.TOP_LEFT}
                  ref="searchbox"
                  placeholder="Search for a location"
                  style={ LocationChooser.searchboxStyle( ) }
                />
                { circle }
              </GoogleMap>
            }
          />
          <Input type="text" label="Latitude" value={this.props.center && this.props.center.lat}
            onChange={this.updateLatitude}
          />
          <Input type="text" label="Longitude" value={this.props.center && this.props.center.lng}
            onChange={this.updateLongitude}
          />
          <Input type="text" label="Radius" value={this.props.center && this.props.radius}
            onChange={this.updateRadius}
          />
        </Modal.Body>
        <Modal.Footer>
          <Button onClick={ this.close }>Cancel</Button>
          <Button onClick={ this.save }>Save</Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

LocationChooser.propTypes = {
  open: PropTypes.bool,
  default: PropTypes.object,
  obsCard: PropTypes.object,
  setState: PropTypes.func,
  updateState: PropTypes.func,
  updateObsCard: PropTypes.func,
  updateSelectedObsCards: PropTypes.func,
  center: PropTypes.object,
  radius: PropTypes.number,
  zoom: PropTypes.number,
  bounds: PropTypes.object
};

export default LocationChooser;
