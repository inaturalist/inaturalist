import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import inaturalistjs from "inaturalistjs";

class PlaceAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = Object.assign( {}, this.props, {
      idEl: $( "input[name='place_id']", domNode )
    } );
    $( "input[name='place_name']", domNode ).placeAutocomplete( opts );
    this.fetchPlace( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialPlaceID &&
         this.props.initialPlaceID !== prevProps.initialPlaceID ) {
      this.fetchPlace( );
    }
  }

  fetchPlace( ) {
    if ( this.props.initialPlaceID ) {
      inaturalistjs.places.fetch( this.props.initialPlaceID ).then( r => {
        if ( r.results.length > 0 ) {
          this.updatePlace( { place: r.results[0] } );
        }
      } );
    }
  }

  updatePlace( options = { } ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( options.place ) {
      $( "input[name='place_name']", domNode ).
        trigger( "assignSelection", Object.assign(
          {},
          options.place,
          { title: options.place.display_name }
        ) );
    }
  }

  render( ) {
    return (
      <span className="PlaceAutocomplete form-group">
        <input
          type="search"
          name="place_name"
          className="form-control"
          placeholder={ I18n.t( "place" ) }
        />
        <input type="hidden" name="place_id" />
      </span>
    );
  }
}


PlaceAutocomplete.propTypes = {
  resetOnChange: PropTypes.bool,
  bootstrapClear: PropTypes.bool,
  afterSelect: PropTypes.func,
  afterUnselect: PropTypes.func,
  initialSelection: PropTypes.object,
  initialPlaceID: PropTypes.number
};

export default PlaceAutocomplete;
