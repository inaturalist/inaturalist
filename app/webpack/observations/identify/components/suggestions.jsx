import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../taxa/shared/components/taxon_photo";
import ZoomableImageGallery from "./zoomable_image_gallery";

const Suggestions = ( { query, response, detailTaxon, setDetailTaxon } ) => {
  let detailTaxonImages;
  console.log( "[DEBUG] detailTaxon: ", detailTaxon );
  if ( detailTaxon ) {
    console.log( "[DEBUG] detailTaxon.taxonPhotos.length: ", detailTaxon.taxonPhotos.length );
  }
  if ( detailTaxon && detailTaxon.taxonPhotos.length > 0 ) {
    detailTaxonImages = detailTaxon.taxonPhotos.map( taxonPhoto => ( {
      original: taxonPhoto.photo.photoUrl( "large" ),
      zoom: taxonPhoto.photo.photoUrl( "original" ),
      thumbnail: taxonPhoto.photo.photoUrl( "square" )
    } ) );
    console.log( "[DEBUG] detailTaxonImages: ", detailTaxonImages );
  }
  return (
    <div className="Suggestions">
      <div className={`suggestions-wrapper ${detailTaxon ? "with-detail" : null}`}>
        <div className="suggestions-list">
          <h2>
            { response.results.length } Suggestions
          </h2>
          { response.results.map( r => (
            <div key={`suggestion-row-${r.taxon.id}`}>
              <h3>
                <SplitTaxon
                  taxon={r.taxon}
                  onClick={ e => {
                    e.preventDefault( );
                    $( ".Suggestions" ).scrollTop( 0 );
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
                ) : r.taxon.taxonPhotos.map( tp => (
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
          <h3>
            <a
              href="#"
              onClick={ e => {
                e.preventDefault( );
                setDetailTaxon( null );
                return false;
              } }
            >
              &larr; Back to suggestions
            </a>
          </h3>
          { detailTaxonImages && detailTaxonImages.length > 0 ? (
            <ZoomableImageGallery
              items={detailTaxonImages}
              showThumbnails={detailTaxonImages && detailTaxonImages.length > 1}
              lazyLoad={false}
              server
              showNav={false}
            />
          ) : <div className="noresults">No Taxon Chosen</div> }
        </div>
      </div>
    </div>
  );
};

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
