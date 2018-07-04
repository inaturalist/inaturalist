import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonPhoto from "../../../taxa/shared/components/taxon_photo";
import { urlForTaxon } from "../../../taxa/shared/util";
import ZoomableImageGallery from "./zoomable_image_gallery";
import PlaceChooserPopover from "../../../taxa/shared/components/place_chooser_popover";
import ObservationPhotoAttribution from "../../../shared/components/observation_photo_attribution";
import UserText from "../../../shared/components/user_text";
import TaxonChooserPopover from "./taxon_chooser_popover";
import ChooserPopover from "./chooser_popover";
import TaxonMap from "./taxon_map";

class Suggestions extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      scrollTopWas: null,
      detailTaxonChangedFor: null
    };
  }
  componentWillReceiveProps( nextProps ) {
    if (
      nextProps.detailTaxon &&
      this.props.detailTaxon &&
      this.props.detailTaxon.id !== nextProps.detailTaxon.id
    ) {
      if ( this.props.prevTaxon && this.props.prevTaxon.id === nextProps.detailTaxon.id ) {
        this.setState( { detailTaxonChangedFor: "prev" } );
      } else {
        this.setState( { detailTaxonChangedFor: "next" } );
      }
    } else {
      this.setState( { detailTaxonChangedFor: null } );
    }
  }
  componentDidUpdate( ) {
    if ( this.state.detailTaxonChangedFor ) {
      const domNode = ReactDOM.findDOMNode( this );
      $( ".detail-taxon", domNode ).removeClass( "changed" );
      $( ".detail-taxon", domNode ).addClass( `will-change-for-${this.state.detailTaxonChangedFor}` );
      setTimeout( ( ) => {
        $( ".detail-taxon", domNode ).addClass( "changed" );
        $( ".detail-taxon", domNode ).removeClass( "will-change-for-prev" );
        $( ".detail-taxon", domNode ).removeClass( "will-change-for-next" );
      }, 100 );
    }
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
  suggestionRowForTaxon( taxon, details = {} ) {
    const that = this;
    const taxonPhotos = _
      .uniq( taxon.taxonPhotos, tp => `${tp.photo.id}-${tp.taxon.id}` )
      .slice( 0, 5 );
    return (
      <div className="suggestion-row" key={`suggestion-row-${taxon.id}`}>
        <h3 className="clearfix">
          <SplitTaxon
            taxon={taxon}
            onClick={ e => {
              e.preventDefault( );
              this.scrollToTop( );
              this.props.setDetailTaxon( taxon );
              return false;
            } }
            user={ this.props.config.currentUser }
          />
          <div className="btn-group pull-right">
            { details && ( details.vision_score || details.frequency_score ) ? (
              <div className="quiet btn btn-label btn-xs">
                { details.vision_score ? I18n.t( "visually_similar" ) : null }
                { details.vision_score && details.frequency_score ? <span> / </span> : null }
                { details.frequency_score ? I18n.t( "seen_nearby" ) : null }
              </div>
            ) : null }
            <Button
              bsSize="xs"
              bsStyle="primary"
              onClick={ ( ) => {
                that.props.chooseTaxon( taxon, {
                  observation: that.props.observation,
                  vision: that.props.query.source === "visual"
                } );
              } }
            >
              { I18n.t( "select" ) }
            </Button>
          </div>
        </h3>
        <LazyLoad height={150} offsetVertical={1000}>
          <div className="photos">
            { taxonPhotos.length === 0 ? (
              <div className="noresults">
                { I18n.t( "no_photos" ) }
              </div>
            ) : taxonPhotos.map( tp => (
              <TaxonPhoto
                key={`suggestions-row-photo-${tp.taxon.id}-${tp.photo.id}`}
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
        </LazyLoad>
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
      chooseTaxon,
      prevTaxon,
      nextTaxon,
      config
    } = this.props;
    let detailTaxonImages;
    if ( detailTaxon && detailTaxon.taxonPhotos && detailTaxon.taxonPhotos.length > 0 ) {
      // Note key is critical here. See comment below on renderItem
      detailTaxonImages = detailTaxon.taxonPhotos.map( taxonPhoto => ( {
        key: `detail-taxon-${detailTaxon.id}-photo-${taxonPhoto.photo.id}`,
        original: taxonPhoto.photo.photoUrl( "medium" ),
        zoom: taxonPhoto.photo.photoUrl( "original" ) || taxonPhoto.photo.photoUrl( "large" ),
        thumbnail: taxonPhoto.photo.photoUrl( "square" ),
        description: (
          <div className="photo-meta">
            <OverlayTrigger
              container={ $( ".suggestions-detail" ).get( 0 ) }
              placement="top"
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
            </OverlayTrigger>
            <a href={`/photos/${taxonPhoto.photo.id}`} target="_blank">
              <i className="fa fa-info-circle" />
            </a>
          </div>
        )
      } ) );
    }
    let detailPhotos = <div className="noresults">{ I18n.t( "no_photos" ) }</div>;
    if ( detailTaxonImages && detailTaxonImages.length > 0 ) {
      // Using a custom renderItem method to ensure each slide has a unique key.
      // Without that the element won't get re-rendered with each new taxon and
      // the EasyZoom flyout can get stuck with the first taxon that gets
      // rendered.
      detailPhotos = (
        <ZoomableImageGallery
          items={detailTaxonImages}
          showThumbnails={detailTaxonImages && detailTaxonImages.length > 1}
          lazyLoad={false}
          server
          showNav={false}
          disableArrowKeys
          showFullscreenButton={ false }
          showPlayButton={ false }
          slideIndex={detailPhotoIndex}
          currentIndex={detailPhotoIndex}
          renderItem={ item => (
            <div className="image-gallery-image" key={ item.key }>
              <img
                src={item.original}
                alt={item.originalAlt}
                srcSet={item.srcSet}
                sizes={item.sizes}
                title={item.originalTitle}
              />
              {
                item.description &&
                  <span className="image-gallery-description">
                    {item.description}
                  </span>
              }
            </div>
          ) }
        />
      );
    }
    let comprehensiveList;
    if (
      query.source === "checklist" &&
      response &&
      response.results.length > 0 &&
      _.uniq( response.results.map( r => r.sourceKey ) ).length === 1 &&
      response.results[0].sourceDetails.listedTaxon.list.comprehensive
    ) {
      comprehensiveList = response.results[0].sourceDetails.listedTaxon.list;
    }
    let defaultPlaces = observation.places;
    if ( query.place && query.place.ancestors ) {
      defaultPlaces = query.place.ancestors;
    }
    let title = I18n.t( "no_suggestions_available" );
    if ( loading ) {
      title = I18n.t( "suggestions" );
    } else if ( response.results.length > 0 ) {
      title = I18n.t( "x_suggestions_filtered_by_colon", { count: response.results.length } );
    }
    return (
      <div className="Suggestions">
        <div className={`suggestions-wrapper ${detailTaxon ? "with-detail" : null}`}>
          <div className="suggestions-list">
            <div className="suggestions-inner">
              <ChooserPopover
                label={ I18n.t( "sort_by" ) }
                className="pull-right"
                container={ $( ".ObservationModal" ).get( 0 ) }
                chosen={ query.order_by }
                choices={["frequency", "taxonomy"]}
                defaultChoice="frequency"
                preIconClass={ false }
                postIconClass="fa fa-angle-down"
                hideClear
                setChoice={ orderBy => {
                  setQuery( Object.assign( { }, query, { order_by: orderBy } ) );
                } }
                clearChoice={ ( ) => {
                  setQuery( Object.assign( { }, query, { order_by: null } ) );
                } }
              />
              <div className="column-header">
                { title }
              </div>
              <div className="filters">
                <PlaceChooserPopover
                  container={ $( ".ObservationModal" ).get( 0 ) }
                  label={ I18n.t( "place" ) }
                  place={ query.place }
                  withBoundaries
                  defaultPlace={ query.defaultPlace }
                  defaultPlaces={ _.sortBy( defaultPlaces, p => p.bbox_area ) }
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
                  label={ I18n.t( "taxon" ) }
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
                  config={ config }
                />
                <ChooserPopover
                  label={ I18n.t( "source" ) }
                  container={ $( ".ObservationModal" ).get( 0 ) }
                  chosen={ query.source }
                  choices={["observations", "rg_observations", "checklist", "misidentifications", "visual"]}
                  choiceLabels={{ visual: "visually_similar" }}
                  defaultChoice="observations"
                  preIconClass={ false }
                  postIconClass="fa fa-angle-down"
                  hideClear
                  setChoice={ source => {
                    setQuery( Object.assign( { }, query, { source } ) );
                  } }
                  clearChoice={ ( ) => {
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
                  <i className="fa fa-list-ul"></i>
                  {I18n.t( "comprehensive_list" )}: <a target="_blank" href={`/lists/${comprehensiveList.id}`}>
                    { comprehensiveList.title } { comprehensiveList.source ? (
                      <span>({I18n.t( "source_" )} { comprehensiveList.source.in_text })</span>
                    ) : null }
                  </a>
                </div>
              ) : null }
              { response.results.map( r => this.suggestionRowForTaxon( r.taxon, r.sourceDetails ) ) }
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
                    <i className="fa fa-chevron-circle-left"></i> { I18n.t( "back_to_suggestions" ) }
                  </a>
                  <div className="prevnext pull-right">
                    <Button
                      disabled={ prevTaxon === null }
                      onClick={ ( ) => setDetailTaxon( prevTaxon ) }
                      className="prev"
                    >
                      <i className="fa fa-chevron-circle-left"></i> { I18n.t( "prev" ) }
                    </Button>
                    <Button
                      disabled={ nextTaxon === null }
                      onClick={ ( ) => setDetailTaxon( nextTaxon ) }
                      className="next"
                    >
                      { I18n.t( "next" ) } <i className="fa fa-chevron-circle-right"></i>
                    </Button>
                  </div>
                </div>
                { detailTaxon ? (
                  <div className={ `detail-taxon ${detailTaxonImages && detailTaxonImages.length > 1 ? "multiple-photos" : "single-photo"}` }>
                    { detailPhotos }
                    <div className="obs-modal-header">
                      <SplitTaxon
                        taxon={detailTaxon}
                        url={ urlForTaxon( detailTaxon ) }
                        target="_blank"
                        noParens
                        user={ config.currentUser }
                      />
                    </div>
                    { detailTaxon.wikipedia_summary ?
                      <UserText text={`${detailTaxon.wikipedia_summary} (${I18n.t( "source_wikipedia" )})`} /> : null
                    }
                    <h4>{ I18n.t( "observations_map" ) }</h4>
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
              onClick={ ( ) => chooseTaxon( detailTaxon, {
                observation,
                vision: query.source === "visual"
              } ) }
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
  chooseTaxon: PropTypes.func,
  prevTaxon: PropTypes.object,
  nextTaxon: PropTypes.object,
  config: PropTypes.object
};

Suggestions.defaultProps = {
  query: {},
  response: {
    results: []
  },
  detailPhotoIndex: 0,
  config: {}
};

export default Suggestions;
