import React from "react";
import PropTypes from "prop-types";
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
    const { initialPlaceID } = this.props;
    if ( initialPlaceID !== prevProps.initialPlaceID ) {
      this.fetchPlace( );
    }
  }

  fetchPlace( ) {
    const { initialPlaceID } = this.props;
    if ( initialPlaceID ) {
      inaturalistjs.places.fetch( initialPlaceID ).then( r => {
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
      $( "input[name='place_name']", domNode )
        .trigger( "assignSelection", Object.assign(
          {},
          options.place,
          { title: options.place.display_name }
        ) );
    } else {
      $( "input[name='place_name']", domNode )
        .trigger( "resetAll" );
    }
  }

  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='place_name']", domNode );
  }

  render( ) {
    const { className, placeholder } = this.props;
    return (
      <span className="PlaceAutocomplete">
        <div className="form-group">
          <input
            type="search"
            name="place_name"
            className={`form-control ${className}`}
            placeholder={placeholder || I18n.t( "place" )}
          />
        </div>
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
