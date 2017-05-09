import _ from "lodash";
import React, { Component, PropTypes } from "react";
import Util from "../../project_slideshow/models/util";

class ResultsPeople extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  componentDidMount( ) {
    this.reloadData( );
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.searchParams !== this.props.searchParams ) {
      this.reloadData( );
    }
  }

  reloadData( ) {
    /* eslint no-console: 0 */
    Util.nodeApiFetch(
      `observations/identifiers?per_page=6&${$.param( this.props.searchParams )}&ttl=600` ).
      then( json => {
        this.props.updateState( { peopleStats: { identifiers: json } } );
      } ).catch( e => console.log( e ) );
    Util.nodeApiFetch(
      `observations/observers?per_page=6&${$.param( this.props.searchParams )}&ttl=600` ).
      then( json => {
        this.props.updateState( { peopleStats: { observers: json } } );
      } ).catch( e => console.log( e ) );
  }

  render( ) {
    let observers;
    if ( this.props.peopleStats.observers ) {
      observers = (
        <div className="half">
          <div className="heading">Top Observers</div>
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
                <a href={ `/people/${r.user.login}`}>
                  <div className="image" style={ style }>{ placeholder }</div>
                </a>
                <div className="meta">
                  <span className="name">
                    <a href={ `/people/${r.user.login}`}>
                      { r.user.login }
                    </a>
                  </span>
                  <span className="count">
                    <a href={ `/observations?verifiable=any&${$.param( Object.assign( { }, this.props.searchParams, { user_id: r.user.login } ) )}`}>
                      { I18n.t( "x_observations_", { count: r.observation_count } ) }
                    </a>
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
          <div className="heading">Top Identifiers</div>
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
                <a href={ `/people/${r.user.login}`}>
                  <div className="image" style={ style }>{ placeholder }</div>
                </a>
                <div className="meta">
                  <span className="name">
                    <a href={ `/people/${r.user.login}`}>
                      { r.user.login }
                    </a>
                  </span>
                  <span className="count">
                    <a href={ `/observations?view=identifiers&verifiable=any&${$.param( Object.assign( { }, this.props.searchParams, { user_id: r.user.login } ) )}`}>
                      { I18n.t( "x_identifications_", { count: r.count } ) }
                    </a>
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

ResultsPeople.propTypes = {
  searchParams: PropTypes.object,
  peopleStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ResultsPeople;
