import _ from "lodash";
import React, { Component, PropTypes } from "react";
import Util from "../models/util";

class ProjectPhotos extends Component {

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
      `observations/?per_page=15&project_id=${this.props.project.id}` +
      "&photos=true&sounds=false&order_by=votes&ttl=600&locale=" + I18n.locale ).
      then( json => {
        this.props.setState( { photos: json } );
      } ).catch( e => console.log( e ) );
  }

  render( ) {
    let photos;
    if ( this.props.photos ) {
      photos = (
        <div>
          { _.map( this.props.photos.results, r => {
            let style;
            let placeholder;
            let prefetch;
            if ( r.user.icon_url ) {
              const icon = r.user.icon_url.replace( "medium", "original" );
              style = { backgroundImage: `url('${icon}')` };
              prefetch = ( <link rel="prefetch" href={ icon } /> );
            } else {
              placeholder = ( <i className="icon-person" /> );
            }
            let photoUrl = r.photos[0].url.replace( "square", "large" );
            return (
              <div className="cell" key={ `photo${r.id}` } style={
                { backgroundImage: `url('${photoUrl}')` } }
              >
                <link rel="prefetch" href={ photoUrl } />
                { prefetch }
                <div className="caption">
                  { r.taxon ? ( r.taxon.preferred_common_name || r.taxon.name ) : "Unknown" }
                </div>
                <div className="user-icon" style={ style }>{ placeholder }</div>
              </div>
            );
          } ) }
        </div>
      );
    } else {
      photos = <h1 className="noresults">No Photos Yet</h1>;
    }
    return (
      <div className="slide photos-slide">
        { photos }
      </div>
    );
  }
}

ProjectPhotos.propTypes = {
  project: PropTypes.object,
  photos: PropTypes.object,
  setState: PropTypes.func
};

export default ProjectPhotos;
