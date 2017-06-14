import React, { PropTypes } from "react";
import { Panel } from "react-bootstrap";
import ObservationAttribution from "../../../shared/components/observation_attribution";

class Copyright extends React.Component {
  constructor( props ) {
    super( props );
    const currentUser = props.config && props.config.currentUser;
    this.state = {
      open: currentUser ? !currentUser.prefers_hide_obs_show_copyright : true
    };
  }

  render( ) {
    const { observation, config } = this.props;
    if ( !observation ) { return ( <span /> ); }
    const loggedIn = config && config.currentUser;
    return (
      <div className="Copyright">
        <h4
          className="collapsable"
          onClick={ ( ) => {
            if ( loggedIn ) {
              this.props.updateSession( { prefers_hide_obs_show_copyright: this.state.open } );
            }
            this.setState( { open: !this.state.open } );
          } }
        >
          <i className={ `fa fa-chevron-circle-${this.state.open ? "down" : "right"}` } />
          Copyright Info
        </h4>
        <Panel collapsible expanded={ this.state.open }>
          <ObservationAttribution observation={ observation } />
        </Panel>
      </div>
    );
  }
}

Copyright.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  updateSession: PropTypes.func
};

export default Copyright;
