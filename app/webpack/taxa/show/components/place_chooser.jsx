import React, { PropTypes } from "react";
import _ from "lodash";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";

class PlaceChooser extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      editing: false
    };
  }

  toggle( ) {
    if ( this.state.editing ) {
      this.hide( );
      return;
    }
    this.show( );
  }

  show( ) {
    this.setState( { editing: true } );
  }

  hide( ) {
    this.setState( { editing: false } );
  }

  render( ) {
    let displayLink = <a onClick={ ( ) => this.toggle( ) }>{ I18n.t( "customize_location" ) }</a>;
    if ( this.props.place ) {
      displayLink = (
        <a
          className="display"
          onClick={ ( ) => this.toggle( ) }
        >
          { I18n.t( `places_name.${_.snakeCase( this.props.place.name )}` ) }
        </a>
      );
    }
    const that = this;
    return (
      <div className={`PlaceChooser ${this.props.className}`}>
        <span
          className={ this.state.editing ? "hidden" : "" }
        >
          <i
            className="fa fa-map-marker"
          /> { displayLink } <a
            onClick={ ( ) => this.toggle( ) }
          >
            <i className="fa fa-pencil" />
          </a>
        </span>
        <div className={this.state.editing ? "" : "hidden"}>
          <PlaceAutocomplete
            resetOnChange={false}
            initialPlaceID={ this.props.place ? this.props.place.id : null }
            bootstrapClear
            className="input-sm"
            afterSelect={ function ( result ) {
              that.props.setPlace( result.item );
              that.hide( );
            } }
            afterClear={ function ( ) {
              that.props.clearPlace( );
              that.hide( );
            } }
          />
        </div>
      </div>
    );
  }
}

PlaceChooser.propTypes = {
  place: PropTypes.object,
  className: PropTypes.string,
  setPlace: PropTypes.func,
  clearPlace: PropTypes.func
};

export default PlaceChooser;
