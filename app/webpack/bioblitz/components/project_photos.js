import _ from "lodash";
import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

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
    NodeAPI.fetch(
      `observations/?per_page=15&project_id=${this.props.project.id}&photos=true&sounds=false&ttl=600` ).
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
            return (
              <div className="cell" key={ `photo${r.id}` } style={
                { backgroundImage: `url('${r.photos[0].url.replace( "square", "large" )}')` } }
              >
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
