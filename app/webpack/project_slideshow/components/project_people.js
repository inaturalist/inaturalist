import _ from "lodash";
import React, { Component, PropTypes } from "react";
import Util from "../models/util";

class ProjectPeople extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  componentDidMount( ) {
    this.reloadData( );
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.project.id !== this.props.project.id ) {
      this.reloadData( );
    }
  }

  reloadData( ) {
    /* eslint no-console: 0 */
    Util.nodeApiFetch(
      `observations/identifiers?per_page=6&project_id=${this.props.project.id}&ttl=600` ).
      then( json => {
        this.props.updateState( { peopleStats: { identifiers: json } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch(
      `observations/observers?per_page=6&project_id=${this.props.project.id}&ttl=600` ).
      then( json => {
        this.props.updateState( { peopleStats: { observers: json } } );
      } ).catch( e => console.log( e ) );
  }

  render( ) {
    let observers;
    if ( this.props.peopleStats.observers ) {
      observers = (
        <div className="half">
          <div className="heading">{ I18n.t("top_observers") }</div>
          { _.map( this.props.peopleStats.observers.results, r => {
            let style;
            let placeholder;
            let prefetch;
            if ( r.user.icon_url ) {
              const icon = r.user.icon_url;
              style = { backgroundImage: `url('${icon}')` };
              prefetch = ( <link rel="prefetch" href={ icon } /> );
            } else {
              placeholder = ( <i className="icon-person" /> );
            }
            return (
              <div key={ `observer${r.user.id}` } className="person">
                { prefetch }
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <span className="name">{ r.user.login }</span>
                  <span className="count">
                  { I18n.t( "x_observations_", { count: r.observation_count } ) }
                  </span>
                </div>
              </div>
            );
          } ) }
        </div>
      );
    }
    let identifiers;
    if ( this.props.peopleStats.identifiers ) {
      identifiers = (
        <div className="half">
          <div className="heading">{ I18n.t( "top_identifiers" ) }</div>
          { _.map( this.props.peopleStats.identifiers.results, r => {
            let style;
            let placeholder;
            let prefetch;
            if ( r.user.icon_url ) {
              const icon = r.user.icon_url;
              style = { backgroundImage: `url('${icon}')` };
              prefetch = ( <link rel="prefetch" href={ icon } /> );
            } else {
              placeholder = ( <i className="icon-person" /> );
            }
            return (
              <div key={ `observer${r.user.id}` } className="person">
                { prefetch }
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <span className="name">{ r.user.login }</span>
                  <span className="count">
                    { I18n.t( "x_identifications_", { count: r.count } ) }
                  </span>
                </div>
              </div>
            );
          } ) }
        </div>
      );
    }
    return (
      <div className="slide row-fluid people-slide">
        <div className="col-md-6">
          { observers }
        </div>
        <div className="col-md-6">
          { identifiers }
        </div>
      </div>
    );
  }
}

ProjectPeople.propTypes = {
  project: PropTypes.object,
  peopleStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ProjectPeople;
