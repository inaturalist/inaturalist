import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../taxa/shared/components/taxon_photo";
import ZoomableImageGallery from "./zoomable_image_gallery";

class Suggestions extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      scrollTopWas: null
    };
  }
  scrollToTop( ) {
    this.setState( { scrollTopWas: $( ".Suggestions" ).scrollTop( ) } );
    $( ".Suggestions" ).scrollTop( 0 );
  }
  resetScrollTop( ) {
    if ( this.state.scrollTopWas ) {
      const scrollTopWas = this.state.scrollTopWas;
      this.setState( { scrollTopWas: null } );
      setTimeout( ( ) => {
        $( ".Suggestions" ).scrollTop( scrollTopWas );
      }, 100 );
    }
  }
  render( ) {
    const {
      query,
      response,
      detailTaxon,
      setDetailTaxon
    } = this.props;
    let detailTaxonImages;
    if ( detailTaxon && detailTaxon.taxonPhotos.length > 0 ) {
      detailTaxonImages = detailTaxon.taxonPhotos.map( taxonPhoto => ( {
        original: taxonPhoto.photo.photoUrl( "large" ),
        zoom: taxonPhoto.photo.photoUrl( "original" ),
        thumbnail: taxonPhoto.photo.photoUrl( "square" )
      } ) );
    }
    return (
      <div className="Suggestions">
        <div className={`suggestions-wrapper ${detailTaxon ? "with-detail" : null}`}>
          <div className="suggestions-list">
            <div className="column-header">
              { response.results.length } Suggestions
            </div>
            { response.results.map( r => (
              <div key={`suggestion-row-${r.taxon.id}`}>
                <h3>
                  <SplitTaxon
                    taxon={r.taxon}
                    onClick={ e => {
                      e.preventDefault( );
                      this.scrollToTop( );
                      setDetailTaxon( r.taxon );
                      return false;
                    } }
                  />
                </h3>
                <div className="photos">
                  { r.taxon.taxonPhotos.length === 0 ? (
                    <div className="noresults">
                      { I18n.t( "no_photos" ) }
                    </div>
                  ) : r.taxon.taxonPhotos.slice( 0, 5 ).map( tp => (
                    <TaxonPhoto
                      key={`taxon-${r.taxon.id}-photo-${tp.photo.id}`}
                      photo={tp.photo}
                      taxon={r.taxon}
                      width={150}
                      height={150}
                      showTaxonPhotoModal={ ( p, t, o ) => {
                        console.log( "[DEBUG] foo" );
                      } }
                    />
                  ) ) }
                </div>
              </div>
            ) ) }
          </div>
          <div className="suggestions-detail">
            <div className="column-header">
              <a
                href="#"
                onClick={ e => {
                  e.preventDefault( );
                  setDetailTaxon( null );
                  this.resetScrollTop( );
                  return false;
                } }
              >
                &larr; Back to suggestions
              </a>
            </div>
            { detailTaxonImages && detailTaxonImages.length > 0 ? (
              <ZoomableImageGallery
                items={detailTaxonImages}
                showThumbnails={detailTaxonImages && detailTaxonImages.length > 1}
                lazyLoad={false}
                server
                showNav={false}
              />
            ) : <div className="noresults">No Taxon Chosen</div> }
            <p>
              i am the very model of a modern major general,
              i've information animal, mineral and vegetable,
              I know the kings of england and i quote the fights historical
              from marathon to waterloo in order categorical
            </p>
          </div>
        </div>
      </div>
    );
  }
}

Suggestions.propTypes = {
  query: PropTypes.object,
  response: PropTypes.object,
  detailTaxon: PropTypes.object,
  setDetailTaxon: PropTypes.func
};

Suggestions.defaultProps = {
  query: {},
  response: {
    results: []
  }
};

export default Suggestions;
