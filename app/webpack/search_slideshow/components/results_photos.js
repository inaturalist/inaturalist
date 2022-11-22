import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
import Util from "../../project_slideshow/models/util";
import SplitTaxon from "../../shared/components/split_taxon";

class ResultsPhotos extends Component {

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
      `observations?per_page=15&${$.param( this.props.searchParams )}` +
      "&photos=true&sounds=false&order_by=votes&ttl=600" ).
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
              <a href={ `/observations/${r.id}` } key={ `photo${r.id}` }>
                <div className="cell" style={
                  { backgroundImage: `url('${photoUrl}')` } }
                >
                  <link rel="prefetch" href={ photoUrl } />
                  { prefetch }
                  <SplitTaxon taxon={ r.taxon } />
                  <div className="user-icon" style={ style }>{ placeholder }</div>
                </div>
              </a>
            );
          } ) }
        </div>
      );
    } else {
      photos = <h1 className="noresults">{ I18n.t( "no_photos" ) }</h1>;
    }
    return (
      <div className="slide photos-slide">
        { photos }
      </div>
    );
  }
}

ResultsPhotos.propTypes = {
  searchParams: PropTypes.object,
  photos: PropTypes.object,
  setState: PropTypes.func
};

export default ResultsPhotos;
