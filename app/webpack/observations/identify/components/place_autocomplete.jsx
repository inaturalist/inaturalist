import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import inaturalistjs from "inaturalistjs";

class PlaceAutocomplete extends React.Component {
  componentDidMount( ) {
    const { config } = this.props;
    const domNode = ReactDOM.findDOMNode( this );
    const opts = {
      ...this.props,
      idEl: $( "input[name='place_id']", domNode ),
      react: true,
      useAPIv2: config?.testingApiV2,
      fields: config?.testingApiV2 ? {
        place: {
          id: true,
          uuid: true,
          slug: true,
          display_name: true,
          place_type: true,
          admin_level: true
        }
      } : null
    };
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
    const { initialPlaceID, config } = this.props;
    if ( initialPlaceID ) {
      const params = { };
      if ( config && config.testingApiV2 ) {
        params.fields = {
          id: true,
          display_name: true
        };
      }
      inaturalistjs.places.fetch( initialPlaceID, params ).then( r => {
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
        .trigger( "assignSelection", {
          ...options.place,
          title: options.place.display_name
        } );
    } else {
      $( "input[name='place_name']", domNode )
        .trigger( "resetAll" );
    }
  }

  // this is currently referenced in the project place selector
  // eslint-disable-next-line react/no-unused-class-component-methods
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
  // eslint-disable-next-line react/no-unused-prop-types
  resetOnChange: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  bootstrapClear: PropTypes.bool,
  // eslint-disable-next-line react/no-unused-prop-types
  afterSelect: PropTypes.func,
  // eslint-disable-next-line react/no-unused-prop-types
  afterUnselect: PropTypes.func,
  // eslint-disable-next-line react/no-unused-prop-types
  afterClear: PropTypes.func,
  // eslint-disable-next-line react/no-unused-prop-types
  initialSelection: PropTypes.object,
  initialPlaceID: PropTypes.any,
  className: PropTypes.string,
  placeholder: PropTypes.string,
  config: PropTypes.object
};

export default PlaceAutocomplete;
