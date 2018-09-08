import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { fetch } from "../../../shared/util";

class SavedLocationChooser extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      query: "",
      show: false,
      locations: [],
      current: -1
    };
    // this.input = React.createRef( );
    this.clickOffEventNamespace = "click.SavedLocationChooserClickOff";
  }

  componentDidMount( ) {
    this.setLocationsFromProps( this.props );
  }

  componentWillReceiveProps( newProps ) {
    this.setLocationsFromProps( newProps );
  }

  setLocationsFromProps( props ) {
    if ( _.isEmpty( this.state.query ) && props.defaultLocations.length > 0 ) {
      this.setState( { locations: props.defaultLocations } );
    }
  }

  show( ) {
    this.setState( { show: true } );
    const that = this;
    $( "body" ).on( this.clickOffEventNamespace, e => {
      if ( !$( ".SavedLocationChooser" ).is( e.target ) &&
          $( ".SavedLocationChooser" ).has( e.target ).length === 0 &&
          $( e.target ).parents( ".SavedLocationChooser" ).length === 0
        ) {
        that.hide( );
      }
    } );
  }

  hide( ) {
    this.setState( { show: false } );
    $( "body" ).unbind( this.clickOffEventNamespace );
  }

  searchLocations( text ) {
    fetch( `/saved_locations?q=${text}` )
      .then( response => response.json( ) )
      .then( locations => this.setState( { locations } ) );
  }

  render( ) {
    const {
      onChoose,
      defaultLocations,
      removeLocation
    } = this.props;
    return (
      <div className="SavedLocationChooser">
        <input
          placeholder={ I18n.t( "your_saved_locations", { defaultValue: "Your Saved Locations" } ) }
          className="form-control"
          onFocus={ ( ) => this.show( ) }
          onChange={ e => {
            const text = e.target.value || "";
            if ( text.length === 0 ) {
              this.setState( { locations: defaultLocations } );
            } else {
              this.searchLocations( text );
            }
          } }
        />
        <div className={ `menu ${this.state.show > 0 ? "show" : "hidden"}`}>
          <ul>
            { this.state.locations.length === 0 ? (
              <li>
                { I18n.t( "no_results_found" ) }
              </li>
            ) : null }
            { this.state.locations.map( sl => (
              <li key={ `saved-location-${sl.id}` }>
                <a
                  href="#"
                  onClick={ e => {
                    e.preventDefault( );
                    onChoose( sl );
                    this.hide( );
                    return false;
                  }}
                >
                  { sl.title }
                  <dl className="small text-muted">
                    <dt>{ I18n.t( "lat" ) }</dt>
                    <dd>{ _.round( sl.latitude, 3 ) }</dd>
                    <dt>{ I18n.t( "long" ) }</dt>
                    <dd>{ _.round( sl.longitude, 3 ) }</dd>
                    <dt>{ I18n.t( "acc" ) }</dt>
                    <dd>{ sl.positional_accuracy }</dd>
                  </dl>
                </a>
                <button
                  onClick={ ( ) => {
                    if ( confirm( I18n.t( "are_you_sure?" ) ) ) {
                      removeLocation( sl );
                    }
                  } }
                >
                  <i className="fa fa-times" alt={ I18n.t( "remove" ) }></i>
                </button>
              </li>
            ) ) }
          </ul>
        </div>
      </div>
    );
  }
}

SavedLocationChooser.propTypes = {
  defaultLocations: PropTypes.array,
  onChoose: PropTypes.func,
  removeLocation: PropTypes.func
};

export default SavedLocationChooser;
