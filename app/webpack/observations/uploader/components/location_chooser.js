import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Modal, Button, Input } from "react-bootstrap";
import { GoogleMapLoader, GoogleMap, Circle, SearchBox, Marker } from "react-google-maps";


class LocationChooser extends Component {

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
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.open && !prevProps.open && !this.props.center ) {
      setTimeout( this.fitCircles, 10 );
    }
  }

  fitCircles( ) {
    if ( !this.refs.map ) { return; }
    const circles = [];
    _.each( this.props.obsCards, c => {
      if ( c.latitude ) {
        circles.push( new google.maps.Circle( {
          center: {
            lat: c.latitude,
            lng: c.longitude
          },
          radius: c.accuracy
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
    this.reverseGeocode( latLng.lat( ), latLng.lng( ) );
    this.props.updateState( { locationChooser: {
      lat: latLng.lat( ),
      lng: latLng.lng( ),
      center: this.refs.map.getCenter( ),
      bounds: this.refs.map.getBounds( ),
      radius: Math.round( ( 1 / Math.pow( 2, zoom ) ) * 5000000 )
    } } );
  }

  close( ) {
    this.props.setState( { locationChooser: { open: false } } );
  }

  save( ) {
    const attrs = {
      latitude: this.props.lat ? Number( this.props.lat ) : undefined,
      longitude: this.props.lat ? Number( this.props.lng ) : undefined,
      accuracy: this.props.lat ? Number( this.props.radius ) : undefined,
      center: this.refs.map.getCenter( ),
      bounds: this.refs.map.getBounds( ),
      zoom: this.refs.map.getZoom( ),
      locality_notes: this.props.notes,
      geoprivacy: this.props.geoprivacy
    };
    if ( this.props.obsCard ) {
      this.props.updateObsCard( this.props.obsCard, attrs );
    } else {
      this.props.updateSelectedObsCards( attrs );
    }
    this.close( );
  }

  reverseGeocode( lat, lng ) {
    const geocoder = new google.maps.Geocoder;
    geocoder.geocode( { location: { lat, lng } }, ( results, status ) => {
      if ( status === google.maps.GeocoderStatus.OK ) {
        if ( results[1] ) {
          results.reverse( );
          const neighborhood = _.find( results, r => _.includes( r.types, "neighborhood" ) );
          const locality = _.find( results, r => _.includes( r.types, "locality" ) );
          const sublocality = _.find( results, r => _.includes( r.types, "sublocality" ) );
          const level2 = _.find( results, r => _.includes( r.types, "administrative_area_level_2" ) );
          const level1 = _.find( results, r => _.includes( r.types, "administrative_area_level_1" ) );
          let locationName;
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
          if ( locationName ) {
            this.props.updateState( { locationChooser: { notes: locationName } } );
          }
        } else {
          // no results
        }
      } else {
        // fail
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
          />
        );
        circles.push(
          <Circle key={`circle${c.id}`}
            center={{ lat: c.latitude, lng: c.longitude }}
            radius={c.accuracy}
            onClick={ this.handleMapClick }
            options={{
              strokeColor: "#000000",
              strokeOpacity: 0.5,
              fillColor: "#ffffff",
              fillOpacity: 0.2
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
    return (
      <Modal show={ this.props.open } className="location" onHide={ this.close }>
        <Modal.Header closeButton>
          <Modal.Title>Modal heading</Modal.Title>
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
                  placeholder="Search for a location"
                  style={ LocationChooser.searchboxStyle( ) }
                />
                { markers }
                { circles }
              </GoogleMap>
            }
          />
          <div className="form">
            <Input key="lat" type="text" label="Latitude:" value={ this.props.lat }
              onChange={ e => this.update( "lat", e ) }
            />
            <Input key="lng" type="text" label="Longitude:" value={ this.props.lng }
              onChange={ e => this.update( "lng", e ) }
            />
            <Input key="radius" type="text" label="Accuracy (m):" value={ this.props.radius }
              onChange={ e => this.update( "radius", e ) }
            />
            <Input key="geoprivacy" type="select" label="Geoprivacy:" value={ this.props.geoprivacy }
              onChange={ e => this.update( "geoprivacy", e ) }
            >
              <option value="open">open</option>
              <option value="obscured">obscured</option>
              <option value="private">private</option>
            </Input>
            <Input className="notes" key="notes" type="text"
              label="Locality Notes:" value={ this.props.notes }
              onChange={ e => this.update( "notes", e ) }
            />
          </div>
        </Modal.Body>
        <Modal.Footer>
          <Button onClick={ this.close }>Cancel</Button>
          <Button onClick={ this.save } bsStyle="primary" disabled={ !canSave }>Save</Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

LocationChooser.propTypes = {
  open: PropTypes.bool,
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
  geoprivacy: PropTypes.string,
  notes: PropTypes.string
};

export default LocationChooser;
