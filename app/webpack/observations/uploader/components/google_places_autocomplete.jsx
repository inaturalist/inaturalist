import React from "react";
import PropTypes from "prop-types";
import { objectToComparable } from "../../../shared/util";

class GooglePlacesAutocomplete extends React.Component {
  constructor( props ) {
    super( props );
    this.input = React.createRef( );
  }

  componentDidMount( ) {
    this.placesAutocomplete = new google.maps.places.Autocomplete(
      this.input.current,
      {
        fields: ["place_id"]
      }
    );
    this.placesAutocompleteService = new google.maps.places.AutocompleteService( );
    this.googleGeocoder = new google.maps.Geocoder( );
  }

  componentDidUpdate( prevProps ) {
    if ( !this.placesAutocomplete ) return;
    // Change the bias bounds of the placesAutocomplete
    const { bounds } = this.props;
    if ( bounds && objectToComparable( bounds ) !== objectToComparable( prevProps.bounds ) ) {
      this.placesAutocomplete.setBounds( bounds );
    }
    // Remove any existing event listener for places_changes
    if ( this.placesChangedListener ) {
      google.maps.event.removeListener( this.placesChangedListener );
    }
    // Add a listener for places_changed
    this.placesChangedListener = this.placesAutocomplete.addListener( "place_changed", ( ) => {
      const place = this.placesAutocomplete.getPlace( );
      if ( place && place.place_id ) {
        this.geocodePlaceID( place.place_id );
        return;
      }
      this.processAutocompletePrediction( );
    } );
  }

  processAutocompletePrediction( ) {
    // the user hit enter in the place autocomplete input field without picking a result. Run
    // the text in the input field through the placesAutocompleteService and process the top
    // result as if it were selected by the user
    const q = $( this.input.current ).val( );
    this.placesAutocompleteService.getQueryPredictions(
      { input: q },
      ( predictions, status ) => {
        if ( status !== google.maps.places.PlacesServiceStatus.OK
         || predictions.length === 0 || !predictions[0].place_id ) {
          return;
        }
        this.geocodePlaceID( predictions[0].place_id );
      }
    );
  }

  geocodePlaceID( placeID ) {
    const { onPlacesChanged } = this.props;
    // fetch additional information for the placeID from the geocoder service to get details
    // such as address_components, viewport, center lat/lng, etc.
    this.googleGeocoder.geocode( { placeId: placeID }, ( results, status ) => {
      if ( status !== google.maps.GeocoderStatus.OK ) {
        return;
      }
      onPlacesChanged( this.input.curent, results[0] );
    } );
  }

  render( ) {
    return (
      <div className="GooglePlacesAutocomplete">
        <input
          ref={this.input}
          type="text"
          placeholder={I18n.t( "search_for_a_location" )}
        />
      </div>
    );
  }
}

GooglePlacesAutocomplete.propTypes = {
  bounds: PropTypes.object,
  onPlacesChanged: PropTypes.func.isRequired
};

export default GooglePlacesAutocomplete;
