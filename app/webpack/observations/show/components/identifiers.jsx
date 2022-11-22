import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Panel } from "react-bootstrap";
import UserWithIcon from "./user_with_icon";

class Identifiers extends React.Component {
  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_identifiers : false
    };
  }

  componentDidMount( ) {
    this.loadIdentifiers( );
  }

  componentDidUpdate( ) {
    this.loadIdentifiers( );
  }

  loadIdentifiers( ) {
    const { identifiers, fetchTaxonIdentifiers } = this.props;
    if ( identifiers === null && this.state.open ) {
      fetchTaxonIdentifiers( );
    }
  }

  render( ) {
    const { observation, identifiers, config } = this.props;
    if ( !observation || !observation.taxon ) { return ( <span /> ); }
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
          <UserWithIcon user={i.user} subtitle={i.count} subtitleIconClass="icon-identification" />
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
  identifiers: PropTypes.array,
  updateSession: PropTypes.func,
  fetchTaxonIdentifiers: PropTypes.func
};

export default Identifiers;
