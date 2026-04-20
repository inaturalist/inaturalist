import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown, MenuItem, Panel } from "react-bootstrap";
import UserWithIcon from "./user_with_icon";
import util from "../util";

class Identifiers extends React.Component {
  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_identifiers : false,
      placeId: null
    };
  }

  componentDidMount( ) {
    this.loadIdentifiers( this.state.placeId );
  }

  componentDidUpdate( prevProps ) {
    const { observation, observationPlaces } = this.props;
    if ( !observation || !observation.taxon || observation.taxon.rank_level > 50 || observation.geoprivacy === "private" ) {
      return;
    }
    /* In the constructor, observationPlaces is not defined yet (can be an empty array).
      We wait to set an initial value for placeId when props.observationPlaces is properly init'd.
      This react hook activates when that happens, and should execute this if-block only once */
    if ( ( !prevProps.observationPlaces || prevProps.observationPlaces.length === 0 )
        && !!observationPlaces && observationPlaces.length > 0 ) {
      const placeId = _.filter( observationPlaces, p => p.admin_level !== null )
        .find( p => p.admin_level === -10 )?.id; // -10 = Place::CONTINENT_LEVEL
      this.setState( { placeId } );
      this.loadIdentifiers( placeId );
    } else if ( prevProps.observationPlaces !== observationPlaces
      && observationPlaces.length === 0 ) {
      // if somehow observationPlaces is being updated TO an empty array, reset placeId
      this.setState( { placeId: null } );
      this.loadIdentifiers( null );
    }
  }

  loadIdentifiers( placeId ) {
    const { identifiers, fetchTaxonIdentifiers } = this.props;
    if ( identifiers === null && this.state.open ) {
      fetchTaxonIdentifiers( placeId );
    }
  }

  renderPlaceSelector( ) {
    const { observation, observationPlaces, fetchTaxonIdentifiers } = this.props;
    if ( !observation || !observation.taxon || observation.taxon.rank_level > 50 || observation.geoprivacy === "private" ) {
      return ( <span /> );
    }
    const standardPlaces = !observationPlaces ? []
      : _.filter( observationPlaces, p => p.admin_level !== null )
        .sort( ( p1, p2 ) => p1.admin_level > p2.admin_level );
    if ( standardPlaces.length !== 0 ) {
      const globalText = (
        <>
          <i className="fa fa-globe" />
          { " " }
          { I18n.t( "global" ) }
        </>
      );
      return (
        <>
          <Dropdown
            id="identifiers-place-dropdown"
            onSelect={index => {
              const placeId = index === 0 ? null : standardPlaces[index - 1].id;
              this.setState( { placeId } );
              fetchTaxonIdentifiers( placeId );
            }}
          >
            <Dropdown.Toggle>
              <span className="toggle">
                { !this.state.placeId
                  ? globalText
                  : util.placeToPlaceNameString(
                    standardPlaces.find( p => p.id === this.state.placeId )
                  ) }
              </span>
            </Dropdown.Toggle>
            <Dropdown.Menu className="dropdown-menu-right">
              <MenuItem
                key="place-0"
                eventKey={0}
                title={I18n.t( "global" )}
              >
                { globalText }
              </MenuItem>
              {
                standardPlaces.map( ( p, index ) => (
                  <MenuItem
                    key={`place-${index + 1}`}
                    eventKey={index + 1}
                    title={`${util.placeToPlaceNameString( p )} ${_.upperFirst( util.placeToPlaceTypeString( p ) )}`}
                  >
                    {util.placeToPlaceNameString( p )}
                    { " " }
                    <span className="place-type">
                      { _.upperFirst( util.placeToPlaceTypeString( p ) ) }
                    </span>
                  </MenuItem>
                ) )
              }
            </Dropdown.Menu>
          </Dropdown>
          <br />
        </>
      );
    }
    return null;
  }

  render( ) {
    const { observation, identifiers, config } = this.props;
    if ( !observation || !observation.taxon || observation.taxon.rank_level > 50 ) {
      return ( <span /> );
    }
    const loggedIn = config && config.currentUser;
    const { taxon } = observation;
    const { open } = this.state;
    let singleName = iNatModels.Taxon.titleCaseName( taxon.preferred_common_name ) || taxon.name;
    if ( config && config.currentUser && config.currentUser.prefers_scientific_name_first ) {
      singleName = taxon.name;
    }
    let panelContents;
    if ( identifiers === null ) {
      panelContents = ( <div className="loading_spinner" /> );
    } else if ( _.isEmpty( identifiers ) ) {
      panelContents = ( I18n.t( "none_found" ) );
    } else {
      panelContents = identifiers.map( i => (
        <div className="identifier" key={`identifier-${i.user.id}`}>
          <UserWithIcon
            config={config}
            user={i.user}
            subtitle={i.count}
            subtitleIconClass="icon-identification"
            subtitleLinkOverwrite={`/identifications?user_id=${i.user.login}&taxon_id=${taxon.id}`}
          />
        </div>
      ) );
    }
    return (
      <div className="Identifiers collapsible-section">
        <h4 className="collapsible">
          <button
            type="button"
            className="btn btn-nostyle"
            onClick={( ) => {
              if ( loggedIn ) {
                this.props.updateSession( { prefers_hide_obs_show_identifiers: open } );
              }
              this.setState( { open: !open } );
            }}
          >
            <i className={`fa fa-chevron-circle-${open ? "down" : "right"}`} />
            { I18n.t( "top_identifiers_of_taxon", { taxon: singleName } ) }
          </button>
        </h4>
        <Panel expanded={open} onToggle={() => {}}>
          <Panel.Collapse>
            { this.renderPlaceSelector() }
            { panelContents }
          </Panel.Collapse>
        </Panel>
      </div>
    );
  }
}

Identifiers.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  observationPlaces: PropTypes.array,
  identifiers: PropTypes.array,
  updateSession: PropTypes.func,
  fetchTaxonIdentifiers: PropTypes.func
};

export default Identifiers;
