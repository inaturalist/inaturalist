import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import _ from "lodash";
import {
  Button,
  OverlayTrigger,
  Tooltip
} from "react-bootstrap";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonomicBranch from "../../../shared/components/taxonomic_branch";
import { urlForTaxon, taxonLayerForTaxon } from "../../../taxa/shared/util";
import ZoomableImageGallery from "./zoomable_image_gallery";
import PlaceChooserPopover from "../../../taxa/shared/components/place_chooser_popover";
import ObservationPhotoAttribution from "../../../shared/components/observation_photo_attribution";
import UserText from "../../../shared/components/user_text";
import TaxonChooserPopover from "./taxon_chooser_popover";
import ChooserPopover from "./chooser_popover";
import TaxonMap from "./taxon_map";
import SuggestionRow from "./suggestion_row";

class Suggestions extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      scrollTopWas: null,
      detailTaxonChangedFor: null
    };
  }

  componentWillReceiveProps( nextProps ) {
    const { detailTaxon, prevTaxon } = this.props;
    if (
      nextProps.detailTaxon
      && detailTaxon
      && detailTaxon.id !== nextProps.detailTaxon.id
    ) {
      if ( prevTaxon && prevTaxon.id === nextProps.detailTaxon.id ) {
        this.setState( { detailTaxonChangedFor: "prev" } );
      } else {
        this.setState( { detailTaxonChangedFor: "next" } );
      }
    } else {
      this.setState( { detailTaxonChangedFor: null } );
    }
  }

  componentDidUpdate( ) {
    const { detailTaxonChangedFor } = this.state;
    if ( detailTaxonChangedFor ) {
      const domNode = ReactDOM.findDOMNode( this );
      $( ".detail-taxon", domNode ).removeClass( "changed" );
      $( ".detail-taxon", domNode ).addClass(
        `will-change-for-${detailTaxonChangedFor}`
      );
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
    const { scrollTopWas: stateScrollTopWas } = this.state;
    if ( stateScrollTopWas ) {
      const scrollTopWas = stateScrollTopWas;
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
      detailPhotoIndex,
      observation,
      chooseTaxon,
      prevTaxon,
      nextTaxon,
      config,
      updateCurrentUser
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
              container={$( ".suggestions-detail" ).get( 0 )}
              placement="top"
              delayShow={500}
              trigger="click"
              rootClose
              overlay={(
                <Tooltip id="add-tip">
                  <ObservationPhotoAttribution photo={taxonPhoto.photo} />
                </Tooltip>
              )}
              key={`photo-${taxonPhoto.photo.id}-license`}
            >
              {
                taxonPhoto.photo.license_code
                  ? <i className="fa fa-creative-commons license" />
                  : <i className="fa fa-copyright license" />
              }
            </OverlayTrigger>
            <a
              href={`/photos/${taxonPhoto.photo.id}`}
              target="_blank"
              rel="noopener noreferrer"
            >
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
          showFullscreenButton={false}
          showPlayButton={false}
          slideIndex={detailPhotoIndex}
          currentIndex={detailPhotoIndex}
          renderItem={item => (
            <div className="image-gallery-image" key={item.key}>
              <img
                src={item.original}
                alt={item.originalAlt}
                srcSet={item.srcSet}
                sizes={item.sizes}
                title={item.originalTitle}
              />
              {
                item.description
                && (
                  <span className="image-gallery-description">
                    {item.description}
                  </span>
                )
              }
            </div>
          )}
        />
      );
    }
    let comprehensiveList;
    if (
      query.source === "checklist"
      && response
      && response.results.length > 0
      && response.comprehensiveness
      && response.comprehensiveness.list
    ) {
      comprehensiveList = response.comprehensiveness.list;
    }
    let defaultPlaces = observation.places;
    if ( query.place && query.place.ancestors ) {
      defaultPlaces = query.place.ancestors;
    }
    defaultPlaces = _.filter( defaultPlaces, p => parseInt( p.admin_level, 10 ) >= 0 );
    let title = I18n.t( "no_suggestions_available" );
    if ( loading ) {
      title = I18n.t( "suggestions" );
    } else if ( response.results.length > 0 ) {
      title = I18n.t( "x_suggestions_filtered_by_colon", { count: response.results.length } );
    }
    const sources = [
      "observations",
      "rg_observations",
      "captive_observations",
      "checklist"
    ];
    if ( query && query.taxon && query.taxon.rank_level <= 20 ) {
      sources.push( "misidentifications" );
    }
    if (
      observation
      && observation.observation_photos
      && observation.observation_photos.length > 0
    ) {
      sources.push( "visual" );
    }
    return (
      <div className="Suggestions">
        <div className={`suggestions-wrapper ${detailTaxon ? "with-detail" : ""}`}>
          <div className="suggestions-list" tabIndex="-1">
            <div className="suggestions-inner">
              <ChooserPopover
                id="suggestions-sort-chooser"
                label={I18n.t( "sort_by" )}
                className="pull-left"
                container={$( ".ObservationModal" ).get( 0 )}
                chosen={query.order_by}
                choices={["default", "taxonomy", "sciname"]}
                choiceLabels={{ default: "default_", sciname: "scientific_name" }}
                defaultChoice="default"
                preIconClass={false}
                postIconClass="fa fa-angle-down"
                hideClear
                setChoice={orderBy => {
                  setQuery( { ...query, order_by: orderBy } );
                }}
                clearChoice={( ) => {
                  setQuery( { ...query, order_by: null } );
                }}
              />
              <div className="column-header">
                { title }
              </div>
              <div className="filters">
                <ChooserPopover
                  id="suggestions-source-chooser"
                  label={I18n.t( "source" )}
                  container={$( ".ObservationModal" ).get( 0 )}
                  chosen={query.source}
                  choices={sources}
                  choiceLabels={{ visual: "visually_similar" }}
                  defaultChoice="observations"
                  preIconClass={false}
                  postIconClass="fa fa-angle-down"
                  hideClear
                  setChoice={source => {
                    setQuery( Object.assign( { }, query, { source } ) );
                  }}
                  clearChoice={( ) => {
                    setQuery( Object.assign( { }, query, { source: null } ) );
                  }}
                />
                <TaxonChooserPopover
                  id="suggestions-taxon-chooser"
                  container={$( ".ObservationModal" ).get( 0 )}
                  label={I18n.t( "taxon" )}
                  taxon={query.taxon}
                  defaultTaxon={query.defaultTaxon}
                  preIconClass={false}
                  postIconClass="fa fa-angle-down"
                  setTaxon={taxon => {
                    setQuery( Object.assign( { }, query, { taxon, taxon_id: taxon.id } ) );
                  }}
                  clearTaxon={( ) => {
                    setQuery( Object.assign( { }, query, { taxon: null, taxon_id: null } ) );
                  }}
                  config={config}
                />
                { query.source === "visual" ? null : (
                  <PlaceChooserPopover
                    container={$( ".ObservationModal" ).get( 0 )}
                    config={config}
                    label={I18n.t( "place" )}
                    place={query.place}
                    withBoundaries
                    defaultPlace={query.defaultPlace}
                    defaultPlaces={_.sortBy( defaultPlaces, p => p.bbox_area )}
                    preIconClass={false}
                    postIconClass="fa fa-angle-down"
                    setPlace={place => {
                      setQuery( Object.assign( { }, query, { place, place_id: place.id } ) );
                    }}
                    clearPlace={( ) => {
                      setQuery( Object.assign( { }, query, { place: null, place_id: null } ) );
                    }}
                  />
                ) }
              </div>
              { loading ? (
                <div className="text-center">
                  <div className="big loading_spinner" />
                </div>
              ) : null }
              { comprehensiveList ? (
                <div className="comprehensive-list">
                  <i className="fa fa-list-ul" />
                  { I18n.t( "label_colon", { label: I18n.t( "comprehensive_list" ) } )}
                  { " " }
                  <a
                    target="_blank"
                    rel="noopener noreferrer"
                    href={`/lists/${comprehensiveList.id}`}
                  >
                    { comprehensiveList.title }
                    { " " }
                    { comprehensiveList.source && comprehensiveList.source.in_text && (
                      <span
                        dangerouslySetInnerHTML={{
                          __html: `(${
                            I18n.t( "bold_label_colon_value_html", {
                              label: I18n.t( "source" ),
                              value: comprehensiveList.source.in_text
                            } )
                          })`
                        }}
                      />
                    ) }
                  </a>
                </div>
              ) : null }
              { response.results.map( r => (
                <SuggestionRow
                  key={`suggestion-row-${r.taxon.id}`}
                  taxon={r.taxon}
                  observation={observation}
                  details={r.source_details}
                  chooseTaxon={chooseTaxon}
                  source={query.source}
                  config={config}
                  updateCurrentUser={updateCurrentUser}
                  setDetailTaxon={( taxon, options = {} ) => {
                    this.scrollToTop( );
                    setDetailTaxon( taxon, options );
                  }}
                />
              ) ) }
            </div>
          </div>
          <div className="suggestions-detail">
            <div className="suggestions-inner">
              <div className="column-header">
                <button
                  type="button"
                  className="btn btn-nostyle header-text"
                  onClick={e => {
                    e.preventDefault( );
                    setDetailTaxon( null );
                    this.resetScrollTop( );
                    return false;
                  }}
                >
                  <i className="fa fa-chevron-circle-left" />
                  { " " }
                  { I18n.t( "back_to_suggestions" ) }
                </button>
                <div className="prevnext pull-right">
                  <Button
                    disabled={prevTaxon === null}
                    onClick={( ) => setDetailTaxon( prevTaxon )}
                    className="prev"
                  >
                    <i className="fa fa-chevron-circle-left" />
                    { " " }
                    { I18n.t( "previous_taxon_short" ) }
                  </Button>
                  <Button
                    disabled={nextTaxon === null}
                    onClick={( ) => setDetailTaxon( nextTaxon )}
                    className="next"
                  >
                    { I18n.t( "next_taxon_short" ) }
                    { " " }
                    <i className="fa fa-chevron-circle-right" />
                  </Button>
                </div>
              </div>
              { detailTaxon ? (
                <div
                  className={
                    `detail-taxon ${detailTaxonImages && detailTaxonImages.length > 1 ? "multiple-photos" : "single-photo"}`
                  }
                >
                  { detailPhotos }
                  <div className="obs-modal-header">
                    <SplitTaxon
                      taxon={detailTaxon}
                      url={urlForTaxon( detailTaxon )}
                      target="_blank"
                      noParens
                      user={config.currentUser}
                      iconLink
                    />
                  </div>
                  { detailTaxon.wikipedia_summary
                    && <UserText text={`${detailTaxon.wikipedia_summary} (${I18n.t( "source_wikipedia" )})`} />
                  }
                  <h4>{ I18n.t( "observations_map" ) }</h4>
                  <TaxonMap
                    placement="suggestion-detail"
                    showAllLayer={false}
                    minZoom={2}
                    gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
                    observations={[observation]}
                    gestureHandling="auto"
                    reloadKey={`taxondetail-${detailTaxon.id}`}
                    taxonLayers={[
                      taxonLayerForTaxon( detailTaxon, {
                        currentUser: config.currentUser,
                        updateCurrentUser
                      } )
                    ]}
                    currentUser={config.currentUser}
                    updateCurrentUser={updateCurrentUser}
                  />
                  <h4>{ I18n.t( "taxonomy" ) }</h4>
                  <TaxonomicBranch
                    taxon={detailTaxon}
                    chooseTaxon={t => setDetailTaxon( t )}
                    noHideable
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
              onClick={( ) => setDetailTaxon( null )}
            >
              { I18n.t( "cancel" ) }
            </Button>
            <Button
              bsStyle="primary"
              onClick={( ) => chooseTaxon( detailTaxon, {
                observation,
                vision: query.source === "visual"
              } )}
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
  config: PropTypes.object,
  updateCurrentUser: PropTypes.func
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
