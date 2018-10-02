import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { fetch } from "../../../shared/util";
import mousetrap from "mousetrap";

class SavedLocationChooser extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      query: "",
      show: false,
      locations: [],
      current: -1
    };
    this.clickOffEventNamespace = "click.SavedLocationChooserClickOff";
    this.input = React.createRef( );
  }

  componentDidMount( ) {
    this.setLocationsFromProps( this.props );
  }

  componentWillReceiveProps( newProps ) {
    this.setLocationsFromProps( newProps );
  }

  setLocationsFromProps( props ) {
    if ( _.isEmpty( this.state.query ) && props.defaultLocations.length > 0 ) {
      this.setState( {
        current: -1,
        locations: props.defaultLocations
      } );
    }
  }

  show( ) {
    if ( !this.state.show ) {
      this.setState( { show: true } );
      this.bindArrowKeys( );
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
  }

  hide( ) {
    if ( this.state.show ) {
      this.setState( { show: false, current: -1 } );
      this.unbindArrowKeys( );
      $( "body" ).unbind( this.clickOffEventNamespace );
    }
  }

  searchLocations( text ) {
    fetch( `/saved_locations?q=${text}` )
      .then( response => response.json( ) )
      .then( json => this.setState( {
        current: -1,
        locations: json.results
      } ) );
  }

  bindArrowKeys( ) {
    const domNode = this.input.current;
    mousetrap( domNode ).bind( "up", ( ) => this.highlightPrev( ) );
    mousetrap( domNode ).bind( "down", ( ) => this.highlightNext( ) );
    mousetrap( domNode ).bind( "enter", ( ) => this.chooseCurrent( ) );
  }

  unbindArrowKeys( ) {
    const domNode = this.input.current;
    mousetrap( domNode ).unbind( "up" );
    mousetrap( domNode ).unbind( "down" );
    mousetrap( domNode ).unbind( "enter" );
  }

  highlightNext( ) {
    this.setState( {
      current: Math.min( this.state.locations.length - 1, this.state.current + 1 )
    } );
  }

  highlightPrev( ) {
    this.setState( {
      current: Math.max( 0, this.state.current - 1 )
    } );
  }

  chooseCurrent( ) {
    const currentPlace = this.state.locations[this.state.current];
    if ( currentPlace ) {
      this.props.onChoose( currentPlace );
    }
    this.hide( );
    this.setState( { query: "" } );
    if ( this.input.current ) {
      this.input.current.blur( );
    }
  }

  render( ) {
    const {
      onChoose,
      defaultLocations,
      removeLocation,
      locationsTotal
    } = this.props;
    const className = `SavedLocationChooser ${this.props.className || ""}`;
    return (
      <div className={ className }>
        <div className="accessory">
          <span className="badge">{ I18n.toNumber( locationsTotal, { precision: 0 } ) }</span>
        </div>
        <input
          ref={ this.input }
          value={ this.state.query }
          placeholder={ I18n.t( "your_pinned_locations", { defaultValue: "Your Pinned Locations" } ) }
          className="form-control"
          onFocus={ ( ) => {
            this.show( );
          } }
          onChange={ e => {
            const text = e.target.value || "";
            this.setState( { query: text } );
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
            { this.state.locations.map( ( sl, i ) => (
              <li
                key={ `saved-location-${sl.id}` }
                className={ i === this.state.current ? "current" : "" }
              >
                <a
                  href="#"
                  onClick={ e => {
                    e.preventDefault( );
                    onChoose( sl );
                    this.hide( );
                    return false;
                  }}
                  onMouseOver={ ( ) => this.setState( { current: i } ) }
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
  removeLocation: PropTypes.func,
  className: PropTypes.string,
  locationsTotal: PropTypes.number
};

export default SavedLocationChooser;
