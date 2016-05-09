import _ from "lodash";
import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

class ProjectPeople extends Component {

  componentDidMount( ) {
    NodeAPI.fetch( `observations/identifiers?per_page=6&project_id=${this.props.projectID}` ).
      then( json => {
        this.props.updateState( { peopleStats: { identifiers: json } } );
      } ).
      catch( e => console.log( e ) );
    NodeAPI.fetch( `observations/observers?per_page=6&project_id=${this.props.projectID}` ).
      then( json => {
        this.props.updateState( { peopleStats: { observers: json } } );
      } ).
      catch( e => console.log( e ) );
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
            if ( r.user.icon_url ) {
              style = { backgroundImage: `url('${r.user.icon_url.replace( "medium", "original" )}')` };
            } else {
              placeholder = ( <i className="icon-person" /> );
            }
            return (
              <div key={ `observer${r.user.id}` } className="person">
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <span className="name">{ r.user.login }</span>
                  <span className="count">
                    { Number( r.observation_count ).toLocaleString( ) } Observations
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
            if ( r.user.icon_url ) {
              style = { backgroundImage: `url('${r.user.icon_url.replace( "medium", "original" )}')` };
            } else {
              placeholder = ( <i className="icon-person" /> );
            }
            return (
              <div key={ `observer${r.user.id}` } className="person">
                <div className="image" style={ style }>{ placeholder }</div>
                <div className="meta">
                  <span className="name">{ r.user.login }</span>
                  <span className="count">
                    { Number( r.count ).toLocaleString( ) } Identifications
                  </span>
                </div>
              </div>
            );
          } ) }
        </div>
      );
    }
    return (
      <div className="slide row-fluid" id="people-slide">
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
  projectID: PropTypes.number,
  placeID: PropTypes.number,
  peopleStats: PropTypes.object,
  updateState: PropTypes.func
};

export default ProjectPeople;
