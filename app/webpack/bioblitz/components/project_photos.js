import _ from "lodash";
import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

class ProjectPhotos extends Component {

  componentDidMount( ) {
    NodeAPI.fetch( `observations/?page=3&per_page=15&project_id=${this.props.projectID}&photos=true&sounds=false` ).
      then( json => {
        this.props.setState( { photos: json } );
      } ).
      catch( e => console.log( e ) );
  }

  render( ) {
    let photos;
    if ( this.props.photos ) {
      photos = (
        <div>
          { _.map( this.props.photos.results, r => (
            <div key={ `photo${r.id}` } style={
              { backgroundImage: `url('${r.photos[0].url.replace( "square", "large" )}')` } }
            />
          ) ) }
        </div>
      );
    }
    return (
      <div className="slide" id="photos-slide">
        { photos }
      </div>
    );
  }
}

ProjectPhotos.propTypes = {
  projectID: PropTypes.number,
  placeID: PropTypes.number,
  photos: PropTypes.object,
  setState: PropTypes.func
};

export default ProjectPhotos;
