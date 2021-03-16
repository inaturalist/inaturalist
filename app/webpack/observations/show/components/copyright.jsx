import React from "react";
import PropTypes from "prop-types";
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
    const { open } = this.state;
    if ( !observation || !observation.user ) { return ( <div /> ); }
    const loggedIn = config && config.currentUser;
    let application;
    if ( observation.application && observation.application.name ) {
      application = (
        <span className="app-info">
          { I18n.t( "this_observation_was_created_using" ) }
          <div className="application">
            <a href={observation.application.url}>
              <span className="icon">
                <img
                  src={observation.application.icon}
                  alt={observation.application.name}
                />
              </span>
              <span className="name">
                { observation.application.name }
              </span>
            </a>
          </div>
        </span>
      );
    }
    const panelTitle = application
      ? I18n.t( "copyright_info_and_more" )
      : I18n.t( "copyright_info" );
    return (
      <div className="Copyright collapsible-section">
        <h4
          className="collapsible"
        >
          <button
            type="button"
            className="btn btn-nostyle"
            onClick={( ) => {
              if ( loggedIn ) {
                this.props.updateSession( { prefers_hide_obs_show_copyright: open } );
              }
              this.setState( { open: !open } );
            }}
          >
            <i className={`fa fa-chevron-circle-${this.state.open ? "down" : "right"}`} />
            { panelTitle }
          </button>
        </h4>
        <Panel expanded={this.state.open} onToggle={() => {}}>
          <Panel.Collapse>
            <ObservationAttribution observation={observation} />
            { application }
          </Panel.Collapse>
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
