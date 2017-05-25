import React, { PropTypes } from "react";
import _ from "lodash";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../taxa/shared/components/taxon_photo";
import ZoomableImageGallery from "./zoomable_image_gallery";
import PlaceChooserPopover from "../../../taxa/shared/components/place_chooser_popover";
import TaxonChooserPopover from "./taxon_chooser_popover";

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
      setDetailTaxon,
      setQuery,
      loading,
      detailPhotoIndex
    } = this.props;
    let detailTaxonImages;
    if ( detailTaxon && detailTaxon.taxonPhotos.length > 0 ) {
      detailTaxonImages = detailTaxon.taxonPhotos.map( taxonPhoto => ( {
        original: taxonPhoto.photo.photoUrl( "large" ),
        zoom: taxonPhoto.photo.photoUrl( "original" ),
        thumbnail: taxonPhoto.photo.photoUrl( "square" )
      } ) );
    }
    let detailPhotos = <div className="noresults">No Taxon Chosen</div>;
    if ( detailTaxonImages && detailTaxonImages.length > 0 ) {
      detailPhotos = (
        <ZoomableImageGallery
          items={detailTaxonImages}
          showThumbnails={detailTaxonImages && detailTaxonImages.length > 1}
          lazyLoad={false}
          server
          showNav={false}
          slideIndex={detailPhotoIndex}
          currentIndex={detailPhotoIndex}
        />
      );
    }
    return (
      <div className="Suggestions">
        <div className={`suggestions-wrapper ${detailTaxon ? "with-detail" : null}`}>
          <div className="suggestions-list">
            <div className="suggestions-inner">
              <div className="column-header">
                { I18n.t( "x_suggestions", { count: response.results.length } ) }
              </div>
              <div className="filters">
                <label>{ I18n.t( "filters" ) }</label>
                <PlaceChooserPopover
                  container={ $( ".ObservationModal" ).get( 0 ) }
                  place={ query.place }
                  preIconClass={false}
                  postIconClass="fa fa-angle-down"
                  setPlace={ place => {
                    setQuery( Object.assign( { }, query, { place, place_id: place.id } ) );
                  } }
                  clearPlace={ ( ) => {
                    setQuery( Object.assign( { }, query, { place: null, place_id: null } ) );
                  } }
                />
                <TaxonChooserPopover
                  container={ $( ".ObservationModal" ).get( 0 ) }
                  taxon={ query.taxon }
                  preIconClass={false}
                  postIconClass="fa fa-angle-down"
                  setTaxon={ taxon => {
                    setQuery( Object.assign( { }, query, { taxon, taxon_id: taxon.id } ) );
                  } }
                  clearTaxon={ ( ) => {
                    setQuery( Object.assign( { }, query, { taxon: null, taxon_id: null } ) );
                  } }
                />
              </div>
              { loading ? (
                <div className="text-center">
                  <div className="big loading_spinner" />
                </div>
              ) : null }
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
                        showTaxonPhotoModal={ p => {
                          const index = _.findIndex( r.taxon.taxonPhotos,
                            taxonPhoto => taxonPhoto.photo.id === p.id );
                          setDetailTaxon( r.taxon, { detailPhotoIndex: index } );
                        } }
                      />
                    ) ) }
                  </div>
                </div>
              ) ) }
            </div>
          </div>
          <div className="suggestions-detail">
            <div className="suggestions-inner">
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
                { detailPhotos }
                <p>
                  i am the very model of a modern major general,
                  i've information animal, mineral and vegetable,
                  I know the kings of england and i quote the fights historical
                  from marathon to waterloo in order categorical
                </p>
              </div>
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
  setDetailTaxon: PropTypes.func,
  setQuery: PropTypes.func,
  loading: PropTypes.bool,
  detailPhotoIndex: PropTypes.number
};

Suggestions.defaultProps = {
  query: {},
  response: {
    results: []
  },
  detailPhotoIndex: 0
};

export default Suggestions;
