import React from "react";
import PropTypes from "prop-types";
import update from "immutability-helper";
import querystring from "querystring";
import {
  Modal,
  Button,
  ButtonGroup
} from "react-bootstrap";
import _ from "lodash";
import inatjs from "inaturalistjs";
import { validate as uuidValidate } from "uuid";
import { fetch } from "../../../shared/util";
import { MAX_TAXON_PHOTOS } from "../../shared/util";
import ExternalPhoto from "./external_photo";
import ChosenPhoto from "./chosen_photo";
import PhotoChooserDropArea from "./photo_chooser_drop_area";

class PhotoChooserModal extends React.Component {
  static keyForPhoto( photo ) {
    return `${photo.type || "Photo"}-${photo.id || photo.native_photo_id}`;
  }

  static infoURL( photo ) {
    return photo.id ? `/photos/${photo.id}` : photo.native_page_url;
  }

  constructor( props ) {
    super( props );
    this.movePhoto = this.movePhoto.bind( this );
    this.state = {
      photos: [],
      loading: true,
      submitting: false,
      provider: "inat-rg",
      chosen: [],
      page: 1
    };
  }

  componentWillMount( ) {
    const { chosen } = this.props;
    if ( chosen ) {
      this.setState( { chosen } );
    }
  }

  componentWillReceiveProps( newProps ) {
    const { visible } = this.props;
    if ( !visible && newProps.visible ) {
      this.setState( { submitting: false } );
      this.fetchPhotos( newProps );
    }
    if ( newProps.chosen ) {
      this.setState( {
        chosen: newProps.chosen.map(
          p => ( { ...p, chooserID: PhotoChooserModal.keyForPhoto( p ) } )
        )
      } );
    }
    if ( newProps.initialTaxon ) {
      this.setState( { queryTaxon: newProps.initialTaxon } );
    }
    if ( newProps.initialQuery ) {
      this.setState( { query: newProps.initialQuery } );
    }
  }

  setProvider( provider ) {
    this.setState( { provider } );
    this.fetchPhotos( this.props, { provider } );
  }

  fetchPhotos( props, options = {} ) {
    const { provider } = this.state;
    this.setState( { loading: true, isLastPage: false } );
    const chosenProvider = options.provider || provider || "inat-rg";
    this.setState( { page: options.page || 1, photos: [] } );
    switch ( chosenProvider ) {
      case "inat":
        this.fetchObservationPhotos( { quality_grade: "any" }, options );
        break;
      case "inat-rg": {
        this.fetchObservationPhotos( { quality_grade: "research" }, options );
        break;
      }
      default:
        this.fetchProviderPhotos( chosenProvider, options );
    }
  }

  fetchObservationPhotos( params, options ) {
    const { config } = this.props;
    const { query, queryTaxon } = this.state;
    const queryParams = {
      page: options.page || 1,
      per_page: 24,
      photos: true,
      order_by: "votes",
      ...params
    };
    if ( queryTaxon ) {
      queryParams.taxon_id = queryTaxon.id;
    } else if (
      query
      && Number( query ).toString( ) === query
      && Number.isInteger( Number( query ) )
    ) {
      // query is an Integer, so assume its an observation ID
      queryParams.id = query;
    } else if ( query && uuidValidate( query ) ) {
      // query is a UUID, assume it specifies an observation
      queryParams.uuid = query;
    } else {
      queryParams.q = query;
      queryParams.search_on = "taxon_page_obs_photos";
    }
    if ( config.testingApiV2 ) {
      queryParams.fields = {
        photos: {
          id: true,
          url: true
        }
      };
    }
    inatjs.observations.search( queryParams ).then( response => {
      const isLastPage = ( response.page * response.per_page ) >= response.total_results;
      const obsPhotos = _.filter(
        _.compact( _.flatten( _.map( response.results, "photos" ) ) ),
        p => p.url
      );
      const photos = _.map( obsPhotos, p => ( {
        ...p,
        small_url: p.url.replace( "square", "small" ),
        chooserID: PhotoChooserModal.keyForPhoto( p )
      } ) );
      this.setState( {
        loading: false,
        isLastPage,
        photos: _.uniqBy( photos, photo => photo.chooserID )
      } );
    } ).catch( ( ) => {
      this.setState( { loading: false } );
    } );
  }

  fetchProviderPhotos( provider, options ) {
    const { query } = this.state;
    const params = {
      ...options,
      q: query,
      limit: 24,
      page: options.page || 1
    };
    const url = `/${provider}/photo_fields.json?${querystring.stringify( params )}`;
    fetch( url, params )
      .then(
        response => response.json( ),
        error => {
          // TODO handle error better
          this.setState( { loading: false } );
          // console.log( "[DEBUG] error: ", error );
        }
      )
      .then( json => {
        const photos = json.map( p => ( { ...p, chooserID: PhotoChooserModal.keyForPhoto( p ) } ) );
        this.setState( {
          loading: false,
          photos: _.uniqBy( photos, photo => photo.chooserID )
        } );
      } );
  }

  fetchNextPhotos( ) {
    const { page } = this.state;
    this.fetchPhotos( this.props, { page: page + 1 } );
  }

  fetchPrevPhotos( ) {
    const { page } = this.state;
    this.fetchPhotos( this.props, {
      page: Math.max( page - 1, 1 )
    } );
  }

  movePhoto( dragIndex, hoverIndex ) {
    const { chosen } = this.state;
    const dragPhoto = chosen[dragIndex];
    if ( !dragPhoto ) {
      return;
    }
    if ( dragIndex === hoverIndex ) {
      return;
    }
    this.setState( update( this.state, {
      chosen: {
        $splice: [
          [dragIndex, 1],
          [hoverIndex, 0, dragPhoto]
        ]
      }
    } ) );
  }

  choosePhoto( chooserID ) {
    const { photos, chosen } = this.state;
    const existingIndex = chosen.findIndex( p => p.chooserID === chooserID );
    if ( existingIndex >= 0 ) {
      this.setState( {
        chosen: chosen.map( p => ( { ...p, candidate: false } ) )
      } );
      return;
    }
    const photo = _.find( photos, p => p.chooserID === chooserID );
    if ( !photo ) {
      return;
    }
    photo.candidate = false;
    chosen.push( photo );
    this.setState( { chosen } );
  }

  newPhotoEnter( chooserID, index ) {
    const { photos, chosen } = this.state;
    const hovering = _.find( photos, p => p.chooserID === chooserID );
    if ( !hovering ) {
      return;
    }
    const existing = _.find( chosen, p => p.chooserID === chooserID );
    if ( existing ) {
      return;
    }
    const newPhoto = { ...hovering, candidate: true };
    chosen.splice( index, 0, newPhoto );
    this.setState( { chosen } );
  }

  newPhotoExit( ) {
    const { chosen } = this.state;
    this.setState( { chosen: chosen.filter( p => !p.candidate ) } );
  }

  removePhoto( chooserID ) {
    const { chosen } = this.state;
    this.setState( { chosen: chosen.filter( p => p.chooserID !== chooserID ) } );
  }

  submit( ) {
    this.setState( { submitting: true } );
    const { onSubmit } = this.props;
    const { chosen } = this.state;
    onSubmit( chosen );
  }

  render( ) {
    const { visible, onClose } = this.props;
    const {
      provider,
      query,
      page,
      photos,
      loading,
      chosen,
      submitting,
      isLastPage
    } = this.state;
    let searchPlaceholder = I18n.t( "type_species_name" );
    if ( provider === "inat" || provider === "inat-rg" ) {
      searchPlaceholder = I18n.t( "search_by_taxon_name_or_observation_id" );
    } else if ( provider === "flickr" ) {
      searchPlaceholder = I18n.t( "search_by_taxon_name_or_flickr_photo_id" );
    }
    const photosToDisplay = _.filter(
      photos,
      p => p.small_url && p.small_url.match( /\.(jpe?g|gif|png)/i )
    );
    const prevNextButtons = (
      <ButtonGroup className="pull-right">
        <Button
          disabled={page === 1}
          onClick={( ) => this.fetchPrevPhotos( )}
          title={I18n.t( "previous_page" )}
        >
          { I18n.t( "previous_page_short" ) }
        </Button>
        <Button
          disabled={photos.length < 24 || isLastPage}
          onClick={( ) => this.fetchNextPhotos( )}
          title={I18n.t( "next_page" )}
        >
          { I18n.t( "next_page_short" ) }
        </Button>
      </ButtonGroup>
    );
    const totalChosenPhotos = _.filter( chosen, p => !p.candidate ).length;
    return (
      <Modal
        show={visible}
        bsSize="large"
        className="PhotoChooserModal FullScreenModal"
        onHide={onClose}
      >
        <div className="inner">
          <Modal.Header closeButton>
            <Modal.Title>{ I18n.t( "choose_photos_for_this_taxon" ) }</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <div className="photocols">
              <div className="choosercol">
                <form
                  onSubmit={e => {
                    e.preventDefault( );
                    this.fetchPhotos( );
                    return false;
                  }}
                >
                  <div className="input-group search-control">
                    <input
                      type="text"
                      className="form-control"
                      placeholder={searchPlaceholder}
                      value={query}
                      onChange={e => this.setState( { query: e.target.value, queryTaxon: null } )}
                    />
                    <span className="input-group-btn">
                      <button
                        className="btn btn-default"
                        type="submit"
                      >
                        { I18n.t( "search" ) }
                      </button>
                    </span>
                  </div>
                </form>
                <form className="form-inline controls nav-buttons stacked">
                  <div className="form-group">
                    <label>
                      { I18n.t( "photos_from" ) }
                    </label>
                    { " " }
                    <select
                      className="form-control"
                      onChange={e => this.setProvider( e.target.value )}
                    >
                      <option value="inat-rg">{ I18n.t( "rg_observations" ) }</option>
                      <option value="inat">{ I18n.t( "observations" ) }</option>
                      <option value="flickr">Flickr</option>
                      <option value="eol">EOL</option>
                      <option value="wikimedia_commons">Wikimedia Commons</option>
                    </select>
                  </div>
                  { ( photos.length > 0 || page > 1 ) && prevNextButtons }
                </form>
                <div className="photos">
                  { photosToDisplay.map( photo => (
                    <ExternalPhoto
                      key={PhotoChooserModal.keyForPhoto( photo )}
                      chooserID={PhotoChooserModal.keyForPhoto( photo )}
                      src={photo.small_url}
                      movePhoto={this.movePhoto}
                      didNotDropPhoto={( ) => this.newPhotoExit( )}
                      infoURL={PhotoChooserModal.infoURL( photo )}
                    />
                  ) ) }
                  { loading ? (
                    <div className="loading text-center">
                      <i className="fa fa-spin fa-refresh fa-2x text-muted" />
                    </div>
                  ) : null }
                  { !loading && photos.length === 0 && page === 1 ? (
                    <div className="text-muted text-center">{ I18n.t( "no_results_found" ) }</div>
                  ) : null }
                  { !loading && photos.length === 0 && page > 1 ? (
                    <div className="text-muted text-center">{ I18n.t( "no_more_results_found" ) }</div>
                  ) : null }
                  { !loading && provider.indexOf( "inat" ) >= 0 && (
                    <div className="alert alert-info upstacked">
                      { I18n.t( "taxa_show_obs_photo_search_tip" ) }
                    </div>
                  ) }
                </div>
                { photos.length > 0 && <form>{ prevNextButtons }</form> }
              </div>
              <PhotoChooserDropArea
                photos={chosen}
                droppedPhoto={chooserID => this.choosePhoto( chooserID )}
              >
                <h4>{ I18n.t( "photos_chosen_for_this_taxon" ) }</h4>
                <p>
                  { I18n.t( "views.taxa.show.photo_chooser_modal_desc" ) }
                </p>
                { totalChosenPhotos >= MAX_TAXON_PHOTOS && (
                  <p className="alert alert-warning">
                    { I18n.t( "views.taxa.show.max_photos_desc", { max: MAX_TAXON_PHOTOS } ) }
                  </p>
                ) }
                <div className="stacked photos">
                  { _.map( chosen, ( photo, i ) => (
                    <ChosenPhoto
                      key={PhotoChooserModal.keyForPhoto( photo )}
                      chooserID={PhotoChooserModal.keyForPhoto( photo )}
                      src={photo.small_url}
                      index={i}
                      movePhoto={this.movePhoto}
                      newPhotoEnter={chooserID => this.newPhotoEnter( chooserID )}
                      dropNewPhoto={chooserID => this.choosePhoto( chooserID )}
                      removePhoto={chooserID => this.removePhoto( chooserID )}
                      candidate={photo.candidate}
                      infoURL={PhotoChooserModal.infoURL( photo )}
                      isDefault={i === 0}
                      totalChosenPhotos={totalChosenPhotos}
                    />
                  ) ) }
                </div>
                <p className="text-muted">
                  <small>
                    { I18n.t( "views.taxa.show.photo_chooser_modal_explanation" ) }
                  </small>
                </p>
              </PhotoChooserDropArea>
            </div>
          </Modal.Body>
          <Modal.Footer>
            <Button
              bsStyle="primary"
              onClick={( ) => this.submit( )}
              disabled={submitting}
            >
              { submitting ? I18n.t( "saving" ) : I18n.t( "save_photos" ) }
            </Button>
          </Modal.Footer>
        </div>
      </Modal>
    );
  }
}

PhotoChooserModal.propTypes = {
  // Both of these props *are* used in lifecycle methods
  initialQuery: PropTypes.string, // eslint-disable-line
  initialTaxon: PropTypes.object, // eslint-disable-line
  chosen: PropTypes.array,
  visible: PropTypes.bool,
  onSubmit: PropTypes.func,
  onClose: PropTypes.func,
  config: PropTypes.object
};

PhotoChooserModal.defaultProps = {
  chosen: []
};

export default PhotoChooserModal;
