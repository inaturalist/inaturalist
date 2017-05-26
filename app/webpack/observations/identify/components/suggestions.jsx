import React, { PropTypes } from "react";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../taxa/shared/components/taxon_photo";
import { urlForTaxon } from "../../../taxa/shared/util";
import ZoomableImageGallery from "./zoomable_image_gallery";
import PlaceChooserPopover from "../../../taxa/shared/components/place_chooser_popover";
import ObservationPhotoAttribution from "../../../shared/components/observation_photo_attribution";
import TaxonChooserPopover from "./taxon_chooser_popover";
import SourceChooserPopover from "./source_chooser_popover";
import TaxonMap from "./taxon_map";

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
  suggestionRowForTaxon( taxon ) {
    const that = this;
    const taxonPhotos = _
      .uniq( taxon.taxonPhotos, tp => `${tp.photo.id}-${tp.taxon.id}` )
      .slice( 0, 5 );
    return (
      <div className="suggestion-row" key={`suggestion-row-${taxon.id}`}>
        <h3>
          <SplitTaxon
            taxon={taxon}
            onClick={ e => {
              e.preventDefault( );
              this.scrollToTop( );
              this.props.setDetailTaxon( taxon );
              return false;
            } }
          />
          <Button
            bsSize="xs"
            bsStyle="primary"
            className="pull-right"
            onClick={ ( ) => {
              that.props.chooseTaxon( taxon, { observation: that.props.observation } );
            } }
          >
            { I18n.t( "select_this_taxon" ) }
          </Button>
        </h3>
        <div className="photos">
          { taxonPhotos.length === 0 ? (
            <div className="noresults">
              { I18n.t( "no_photos" ) }
            </div>
          ) : taxonPhotos.map( tp => (
            <TaxonPhoto
              photo={tp.photo}
              taxon={taxon}
              width={150}
              height={150}
              showTaxonPhotoModal={ p => {
                const index = _.findIndex( taxon.taxonPhotos,
                  taxonPhoto => taxonPhoto.photo.id === p.id );
                this.props.setDetailTaxon( taxon, { detailPhotoIndex: index } );
              } }
            />
          ) ) }
        </div>
      </div>
    );
  }
  render( ) {
    const {
      query,
      response,
      detailTaxon,
      setDetailTaxon,
      setQuery,
      loading,
      detailPhotoIndex,
      observation,
      chooseTaxon
    } = this.props;
    let detailTaxonImages;
    if ( detailTaxon && detailTaxon.taxonPhotos.length > 0 ) {
      detailTaxonImages = detailTaxon.taxonPhotos.map( taxonPhoto => ( {
        original: taxonPhoto.photo.photoUrl( "large" ),
        zoom: taxonPhoto.photo.photoUrl( "original" ),
        thumbnail: taxonPhoto.photo.photoUrl( "square" ),
        description: (
          <div className="photo-meta">
            <OverlayTrigger
              container={ $( ".suggestions-detail" ).get( 0 ) }
              placement="left"
              delayShow={ 500 }
              trigger="click"
              rootClose
              overlay={ (
                <Tooltip id="add-tip">
                  <ObservationPhotoAttribution photo={ taxonPhoto.photo } />
                </Tooltip> ) }
              key={ `photo-${taxonPhoto.photo.id}-license` }
            >
              { taxonPhoto.photo.license_code ? ( <i className="fa fa-creative-commons license" /> ) :
                ( <i className="fa fa-copyright license" /> ) }
            </OverlayTrigger> <a href={`/photos/${taxonPhoto.photo.id}`} target="_blank">
              <i className="fa fa-info-circle" />
            </a>
          </div>
        )
      } ) );
    }
    let detailPhotos = <div className="noresults">{ I18n.t( "no_photos" ) }</div>;
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
    let comprehensiveList;
    if (
      query.source === "checklist" &&
      response &&
      response.results.length > 0 &&
      _.uniq( response.results.map( r => r.sourceKey ) ).length === 1
    ) {
      comprehensiveList = response.results[0].sourceDetails.listedTaxon.list;
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
                  defaultPlace={ query.defaultPlace }
                  defaultPlaces={ observation.places }
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
                  defaultTaxon={ query.defaultTaxon }
                  preIconClass={false}
                  postIconClass="fa fa-angle-down"
                  setTaxon={ taxon => {
                    setQuery( Object.assign( { }, query, { taxon, taxon_id: taxon.id } ) );
                  } }
                  clearTaxon={ ( ) => {
                    setQuery( Object.assign( { }, query, { taxon: null, taxon_id: null } ) );
                  } }
                />
                <SourceChooserPopover
                  container={ $( ".ObservationModal" ).get( 0 ) }
                  source={ query.source }
                  defaultSource={ "checklist" }
                  preIconClass={ false }
                  postIconClass="fa fa-angle-down"
                  setSource={ source => {
                    setQuery( Object.assign( { }, query, { source } ) );
                  } }
                  clearSource={ ( ) => {
                    setQuery( Object.assign( { }, query, { source: null } ) );
                  } }
                />
              </div>
              { loading ? (
                <div className="text-center">
                  <div className="big loading_spinner" />
                </div>
              ) : null }
              { comprehensiveList ? (
                <div className="comprehensive-list">
                  Comprehensive List: <a target="_blank" href={`/lists/${comprehensiveList.id}`}>
                    { comprehensiveList.title } { comprehensiveList.source ? (
                      <span>(Source: { comprehensiveList.source.in_text })</span>
                    ) : null }
                  </a>
                </div>
              ) : null }
              { response.results.length === 0 && !loading ? (
                <div className="noresults">
                  { I18n.t( "no_results_found" ) }
                </div>
              ) : null }
              { response.results.map( r => this.suggestionRowForTaxon( r.taxon ) ) }
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
                    <i className="fa fa-arrow-circle-left"></i> Back to suggestions
                  </a>
                </div>
                { detailTaxon ? (
                  <div>
                    { detailPhotos }
                    <div className="obs-modal-header">
                      <SplitTaxon
                        taxon={detailTaxon}
                        url={ urlForTaxon( detailTaxon ) }
                        noParens
                      />
                    </div>
                    <TaxonMap
                      showAllLayer={false}
                      minZoom={2}
                      gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
                      observations={[observation]}
                      scrollwheel={false}
                      taxonLayers={[{
                        taxon: detailTaxon,
                        observations: true,
                        gbif: { disabled: true },
                        places: true,
                        ranges: true
                      }]}
                    />
                  </div>
                ) : null }
              </div>
            </div>
        </div>
        { detailTaxon ? (
          <div className="suggestions-tools tools">
            <Button
              bsStyle="link"
              onClick={ ( ) => setDetailTaxon( null ) }
            >
              { I18n.t( "cancel" ) }
            </Button>
            <Button
              bsStyle="primary"
              onClick={ ( ) => chooseTaxon( detailTaxon, { observation } ) }
            >
              { I18n.t( "select_this_taxon" ) }
            </Button>
          </div>
        ) : null }
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
  detailPhotoIndex: PropTypes.number,
  observation: PropTypes.object,
  chooseTaxon: PropTypes.func
};

Suggestions.defaultProps = {
  query: {},
  response: {
    results: []
  },
  detailPhotoIndex: 0
};

export default Suggestions;
