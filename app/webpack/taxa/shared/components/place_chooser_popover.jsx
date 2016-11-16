import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import {
  OverlayTrigger,
  Popover,
  Input
} from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import mousetrap from "mousetrap";

class PlaceChooserPopover extends React.Component {

  constructor( ) {
    super( );
    this.state = {
      places: [],
      current: -1
    };
  }

  componentWillReceiveProps( newProps ) {
    if ( newProps.defaultPlace ) {
      let newPlaces = this.state.places;
      newPlaces = _.filter( newPlaces, p => p.id !== newProps.defaultPlace.id );
      newPlaces.splice( 0, 0, newProps.defaultPlace );
      this.setState( { places: newPlaces } );
    }
  }

  fetchPlaces( text ) {
    inatjs.places.autocomplete( { q: text } ).then( response => {
      let newPlaces = response.results;
      if (
        this.props.defaultPlace &&
        this.props.place &&
        this.props.place.id !== this.props.defaultPlace.id
      ) {
        newPlaces = _.filter( newPlaces, p => p.id !== this.props.defaultPlace.id );
        newPlaces.splice( 0, 0, this.props.defaultPlace );
      }
      this.setState( { places: newPlaces } );
    } );
  }

  highlightNext( ) {
    this.setState( {
      current: Math.min( this.state.places.length, this.state.current + 1 )
    } );
  }

  highlightPrev( ) {
    // TODO
    this.setState( {
      current: Math.max( -1, this.state.current - 1 )
    } );
  }

  chooseCurrent( ) {
    const currentPlace = this.state.places[this.state.current];
    // Dumb, but I don't see a better way to explicity close the popover
    $( "body" ).click( );
    if ( currentPlace ) {
      this.props.setPlace( currentPlace );
    } else {
      this.props.clearPlace( );
    }
  }

  bindArrowKeys( ) {
    const domNode = ReactDOM.findDOMNode( this.refs.input );
    mousetrap( domNode ).bind( "up", ( ) => this.highlightPrev( ) );
    mousetrap( domNode ).bind( "down", ( ) => this.highlightNext( ) );
    mousetrap( domNode ).bind( "enter", ( ) => this.chooseCurrent( ) );
  }

  unbindArrowKeys( ) {
    const domNode = ReactDOM.findDOMNode( this.refs.input );
    mousetrap( domNode ).unbind( "up" );
    mousetrap( domNode ).unbind( "down" );
    mousetrap( domNode ).unbind( "enter" );
  }

  render( ) {
    const { place, className } = this.props;
    return (
      <OverlayTrigger
        trigger="click"
        placement="bottom"
        rootClose
        onEntered={( ) => {
          this.bindArrowKeys( );
          $( "input", ReactDOM.findDOMNode( this.refs.input ) ).focus( );
        }}
        onExit={( ) => {
          this.unbindArrowKeys( );
        }}
        overlay={
          <Popover id="place-chooser" className="PlaceChooserPopover">
            <Input
              type="text"
              placeholder={I18n.t( "search" )}
              ref="input"
              onChange={ ( ) => {
                const text = $( "input", ReactDOM.findDOMNode( this.refs.input ) ).val( );
                if ( text.length === 0 ) {
                  this.setState( { places: [] } );
                } else {
                  this.fetchPlaces( text );
                }
              }}
            />
            <ul className="list-unstyled">
              <li
                className={this.state.current === -1 ? "current" : ""}
                onMouseOver={( ) => {
                  this.setState( { current: -1 } );
                }}
                onClick={( ) => this.chooseCurrent( )}
                className="pinned"
                style={{ display: this.props.place ? "block" : "none" }}
              >
                <i className="fa fa-times"></i>
                { _.capitalize( I18n.t( "clear" ) ) }
              </li>
              { _.map( this.state.places, ( p, i ) => (
                <li
                  key={`place-chooser-place-${p.id}`}
                  className={
                    `${this.state.current === i ? "current" : ""}
                    ${this.props.defaultPlace && p.id === this.props.defaultPlace.id ? "pinned" : ""}`
                  }
                  onClick={( ) => this.chooseCurrent( )}
                  onMouseOver={( ) => {
                    this.setState( { current: i } );
                  }}
                >
                  <i className="fa fa-map-marker"></i>
                  { p.display_name }
                </li>
              ) ) }
            </ul>
          </Popover>
        }
      >
        <div
          className={`PlaceChooserPopoverTrigger ${place ? "chosen" : ""} ${className}`}
        >
          <i className="fa fa-map-marker"></i>
          { place ? place.display_name : _.startCase( I18n.t( "filter_by_place" ) ) }
        </div>
      </OverlayTrigger>
    );
  }
}

PlaceChooserPopover.propTypes = {
  place: PropTypes.object,
  defaultPlace: PropTypes.object,
  className: PropTypes.string,
  setPlace: PropTypes.func,
  clearPlace: PropTypes.func
};

export default PlaceChooserPopover;
