import React from "react";
import PropTypes from "prop-types";
import {
  OverlayTrigger,
  Popover
} from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import mousetrap from "mousetrap";

const PLACE_TYPES = {
  0: "Undefined",
  1: "Building",
  2: "Street Segment",
  3: "Nearby Building",
  5: "Intersection",
  6: "Street",
  7: "Town",
  8: "State",
  9: "County",
  10: "Local Administrative Area",
  11: "Postal Code",
  12: "Country",
  13: "Island",
  14: "Airport",
  15: "Drainage",
  16: "Land Feature",
  17: "Miscellaneous",
  18: "Nationality",
  19: "Supername",
  20: "Point of Interest",
  21: "Region",
  22: "Suburb",
  23: "Sports Team",
  24: "Colloquial",
  25: "Zone",
  26: "Historical State",
  27: "Historical County",
  29: "Continent",
  31: "Time Zone",
  32: "Nearby Intersection",
  33: "Estate",
  35: "Historical Town",
  36: "Aggregate",
  100: "Open Space",
  101: "Territory",
  102: "District",
  103: "Province",
  1000: "Municipality",
  1001: "Parish",
  1002: "Department Segment",
  1003: "City Building",
  1004: "Commune",
  1005: "Governorate",
  1006: "Prefecture",
  1007: "Canton",
  1008: "Republic",
  1009: "Division",
  1010: "Subdivision",
  1011: "Village block",
  1012: "Sum",
  1013: "Unknown",
  1014: "Shire",
  1015: "Prefecture City",
  1016: "Regency",
  1017: "Constituency",
  1018: "Local Authority",
  1019: "Poblacion",
  1020: "Delegation"
};

const PLACE_SEARCH_FIELDS = {
  id: true,
  uuid: true,
  name: true,
  display_name: true,
  place_type: true
};

class PlaceChooserPopover extends React.Component {
  constructor( props ) {
    super( props );
    this.state = {
      places: [],
      current: -1
    };
    this.input = React.createRef( );
  }

  componentDidMount( ) {
    this.setPlacesFromProps( this.props );
  }

  componentWillReceiveProps( newProps ) {
    this.setPlacesFromProps( newProps );
  }

  handlePlacesResponse( response ) {
    let newPlaces = response.results;
    if (
      this.props.defaultPlace
      && this.props.place
      && this.props.place.id !== this.props.defaultPlace.id
    ) {
      newPlaces = _.filter( newPlaces, p => p.id !== this.props.defaultPlace.id );
      newPlaces.splice( 0, 0, this.props.defaultPlace );
    }
    this.setState( { places: newPlaces } );
  }

  setPlacesFromProps( props ) {
    const usableProps = { ...props, ...this.props };
    const { places } = this.state;
    if ( usableProps.defaultPlace ) {
      let newPlaces = places;
      newPlaces = _.filter( newPlaces, p => p.id !== usableProps.defaultPlace.id );
      newPlaces.splice( 0, 0, usableProps.defaultPlace );
      this.setState( { places: newPlaces } );
    }
    if ( usableProps.defaultPlaces ) {
      let newPlaces = usableProps.defaultPlaces;
      if ( usableProps.defaultPlace ) {
        newPlaces = _.filter( newPlaces, p => p.id !== usableProps.defaultPlace.id );
        newPlaces.splice( 0, 0, usableProps.defaultPlace );
        this.setState( { places: newPlaces } );
      }
      this.setState( { places: newPlaces } );
    } else if (
      usableProps.place
      && usableProps.place.ancestor_place_ids && usableProps.place.ancestor_place_ids.length > 0
    ) {
      this.fetchPlaces( usableProps.place.ancestor_place_ids );
    }
  }

  searchPlaces( text ) {
    const { config } = this.props;
    const { testingApiV2 } = config;
    const searchEndpoint = testingApiV2 ? inatjs.places.search : inatjs.places.autocomplete;
    const params = { q: text };
    if ( this.props.withBoundaries ) {
      params.geo = true;
    }
    if ( testingApiV2 ) {
      params.fields = PLACE_SEARCH_FIELDS;
    }
    searchEndpoint( params )
      .then( response => this.handlePlacesResponse( response ) );
  }

  fetchPlaces( ids ) {
    const { config } = this.props;
    const params = { };
    if ( config.testingApiV2 ) {
      params.fields = PLACE_SEARCH_FIELDS;
    }
    inatjs.places.fetch( ids, params ).then( response => this.handlePlacesResponse( response ) );
  }

  highlightNext( ) {
    const { places, current } = this.state;
    this.setState( {
      current: Math.min( places.length, current + 1 )
    } );
  }

  highlightPrev( ) {
    const { current } = this.state;
    this.setState( {
      current: Math.max( -1, current - 1 )
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

  render( ) {
    const {
      className,
      clearButton,
      clearPlace,
      container,
      label,
      place,
      postIconClass,
      preIconClass
    } = this.props;
    return (
      <OverlayTrigger
        trigger="click"
        placement="bottom"
        rootClose
        container={container}
        onEntered={( ) => {
          this.bindArrowKeys( );
          $( this.input.current ).focus( );
        }}
        onExit={( ) => {
          this.unbindArrowKeys( );
        }}
        overlay={(
          <Popover id="place-chooser" className="PlaceChooserPopover RecordChooserPopover">
            <div className="form-group">
              <input
                type="text"
                ref={this.input}
                placeholder={I18n.t( "search" )}
                className="form-control"
                onChange={e => {
                  const text = e.target.value || "";
                  if ( text.length === 0 ) {
                    this.setState( { places: [] } );
                  } else {
                    this.searchPlaces( text );
                  }
                }}
              />
            </div>
            <ul className="list-unstyled">
              <li
                className={this.state.current === -1 ? "current pinned" : "pinned"}
                onMouseOver={( ) => this.setState( { current: -1 } )}
                onFocus={( ) => this.setState( { current: -1 } )}
                style={{ display: this.props.place ? "block" : "none" }}
              >
                <button
                  type="button"
                  className="btn btn-nostyle"
                  onClick={( ) => this.chooseCurrent( )}
                >
                  <i className="fa fa-times" />
                  { I18n.t( "clear" ) }
                </button>
              </li>
              { _.map( this.state.places, ( p, i ) => {
                let placeType;
                if ( p && PLACE_TYPES[p.place_type] ) {
                  const placeTypeKey = _.snakeCase( PLACE_TYPES[p.place_type] );
                  placeType = I18n.t( `place_geo.geo_planet_place_types.${_.capitalize( placeTypeKey )}`, {
                    defaultValue: I18n.t( `place_geo.geo_planet_place_types.${placeTypeKey}` )
                  } );
                }
                return (
                  <li
                    key={`place-chooser-place-${p.id}`}
                    className={
                      `media ${this.state.current === i ? "current" : ""}
                      ${this.props.defaultPlace && p.id === this.props.defaultPlace.id ? "pinned" : ""}`
                    }
                    onMouseOver={( ) => this.setState( { current: i } )}
                    onFocus={( ) => this.setState( { current: i } )}
                  >
                    <button
                      type="button"
                      className="btn btn-nostyle"
                      onClick={( ) => this.chooseCurrent( )}
                    >
                      <div className="media-left">
                        <i className="media-object fa fa-map-marker" />
                      </div>
                      <div className="media-body">
                        {
                          I18n.t( `places_name.${_.snakeCase( p.name )}`, { defaultValue: p.display_name } )
                        }
                        { " " }
                        {placeType && <span className="text-muted place-type">{`(${placeType})`}</span>}
                      </div>
                    </button>
                  </li>
                );
              } ) }
            </ul>
          </Popover>
        )}
      >
        <div
          className={`PlaceChooserPopoverTrigger RecordChooserPopoverTrigger ${place ? "chosen" : ""} ${className}`}
        >
          { preIconClass && <i className={`${preIconClass} pre-icon`} /> }
          { label ? ( <label>{ label }</label> ) : null }
          {
            place
              ? I18n.t( `places_name.${_.snakeCase( place.name )}`, { defaultValue: place.display_name } )
              : I18n.t( "filter_by_place" )
          }
          { place && clearButton && (
            <button
              type="button"
              className="btn btn-nostyle clear-button"
              onClick={clearPlace}
            >
              <i className="fa fa-times" />
            </button>
          ) }
          { postIconClass && <i className={`${postIconClass} post-icon`} /> }
        </div>
      </OverlayTrigger>
    );
  }
}

PlaceChooserPopover.propTypes = {
  clearButton: PropTypes.bool,
  place: PropTypes.object,
  defaultPlace: PropTypes.object,
  // eslint-disable-next-line react/no-unused-prop-types
  defaultPlaces: PropTypes.array,
  className: PropTypes.string,
  setPlace: PropTypes.func,
  clearPlace: PropTypes.func,
  container: PropTypes.object,
  preIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  postIconClass: PropTypes.oneOfType( [PropTypes.string, PropTypes.bool] ),
  label: PropTypes.string,
  withBoundaries: PropTypes.bool,
  config: PropTypes.object
};

PlaceChooserPopover.defaultProps = {
  preIconClass: "fa fa-map-marker"
};

export default PlaceChooserPopover;
