import _ from "lodash";
import React, { PropTypes } from "react";
import { Panel } from "react-bootstrap";
import UserImage from "../../../shared/components/user_image";

class Identifiers extends React.Component {
  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_identifiers : true
    };
  }

  render( ) {
    const { observation, identifiers, config } = this.props;
    if ( !observation || !observation.taxon || _.isEmpty( identifiers ) ) { return ( <span /> ); }
    const loggedIn = config && config.currentUser;
    const taxon = observation.taxon;
    return (
      <div className="Identifiers collapsible-section">
        <h4
          className="collapsible"
          onClick={ ( ) => {
            if ( loggedIn ) {
              this.props.updateSession( { prefers_hide_obs_show_identifiers: this.state.open } );
            }
            this.setState( { open: !this.state.open } );
          } }
        >
          <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
          { I18n.t( "top_identifiers_of_taxon", {
            taxon: taxon.preferred_common_name || taxon.name } ) }
        </h4>
        <Panel collapsible expanded={ this.state.open }>
          { identifiers.map( i => (
            <div className="identifier" key={ `identifier-${i.user.id}` }>
              <div className="UserWithIcon">
                <div className="icon">
                  <UserImage user={ i.user } />
                </div>
                <div className="title">
                  <a href={ `/people/${i.user.login}` }>{ i.user.login }</a>
                </div>
                <div className="subtitle">
                  <i className="icon-identification" />
                  { i.count }
                </div>
              </div>
            </div>
          ) ) }
        </Panel>
      </div>
    );
  }
}

Identifiers.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  identifiers: PropTypes.array,
  updateSession: PropTypes.func
};

export default Identifiers;
