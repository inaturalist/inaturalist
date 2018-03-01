import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import inaturalistjs from "inaturalistjs";

class PlaceAutocomplete extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const opts = Object.assign( {}, this.props, {
      idEl: $( "input[name='place_id']", domNode ),
      react: true
    } );
    $( "input[name='place_name']", domNode ).placeAutocomplete( opts );
    this.fetchPlace( );
  }

  componentDidUpdate( prevProps ) {
    if ( this.props.initialPlaceID !== prevProps.initialPlaceID ) {
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
    } else {
      this.updatePlace( { place: null } );
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
    } else {
      $( "input[name='place_name']", domNode ).
        trigger( "resetAll" );
    }
  }

  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='place_name']", domNode );
  }

  render( ) {
    return (
      <span className="PlaceAutocomplete">
        <input
          type="search"
          name="place_name"
          className={`form-control ${this.props.className}`}
          placeholder={ this.props.placeholder || I18n.t( "place" ) }
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
  afterClear: PropTypes.func,
  initialSelection: PropTypes.object,
  initialPlaceID: PropTypes.number,
  className: PropTypes.string,
  placeholder: PropTypes.string
};

export default PlaceAutocomplete;
