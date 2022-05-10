import React from "react";
import PropTypes from "prop-types";
import { objectToComparable } from "../../../shared/util";

class GooglePlacesSearchBox extends React.Component {
  constructor( props ) {
    super( props );
    this.input = React.createRef( );
  }

  componentDidMount( ) {
    this.searchBox = new google.maps.places.SearchBox( this.input.current );
  }

  componentDidUpdate( prevProps ) {
    if ( !this.searchBox ) return;
    // Change the bias bounds of the searchbox
    const { bounds, onPlacesChanged } = this.props;
    if ( bounds && objectToComparable( bounds ) !== objectToComparable( prevProps.bounds ) ) {
      this.searchBox.setBounds( bounds );
    }
    // Remove any existing event listener for places_changes
    if ( this.placesChangedListener ) {
      google.maps.event.removeListener( this.placesChangedListener );
    }
    if ( onPlacesChanged ) {
      // Add a listener for places_changed
      const input = this.input.current;
      this.placesChangedListener = this.searchBox.addListener( "places_changed", ( ) => {
        onPlacesChanged( input, this.searchBox.getPlaces( ) );
      } );
    }
  }

  render( ) {
    return (
      <div className="GooglePlacesSearchBox">
        <input
          ref={this.input}
          type="text"
          placeholder={I18n.t( "search_for_a_location" )}
        />
      </div>
    );
  }
}

GooglePlacesSearchBox.propTypes = {
  bounds: PropTypes.object,
  onPlacesChanged: PropTypes.func.isRequired
};

export default GooglePlacesSearchBox;
