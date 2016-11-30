import React, { PropTypes } from "react";
import update from "react/lib/update";
import querystring from "querystring";
import {
  Modal,
  Button,
  Grid,
  Row,
  Col
} from "react-bootstrap";
import _ from "lodash";
import { fetch } from "../../shared/util";
import ExternalPhoto from "./external_photo";
import ChosenPhoto from "./chosen_photo";
import PhotoChooserDropArea from "./photo_chooser_drop_area";

class PhotoChooserModal extends React.Component {
  constructor( props ) {
    super( props );
    this.movePhoto = this.movePhoto.bind( this );
    this.state = {
      photos: [],
      loading: true,
      provider: "flickr",
      chosen: []
    };
  }
  componentWillMount( ) {
    if ( this.props.chosen ) {
      this.setState( { chosen: this.props.chosen } );
    }
  }
  componentWillReceiveProps( newProps ) {
    if ( !this.props.visible && newProps.visible ) {
      this.fetchPhotos( newProps );
    }
  }
  setProvider( provider ) {
    this.setState( { provider } );
    this.fetchPhotos( );
  }
  fetchPhotos( props ) {
    this.setState( { loading: true } );
    const params = {
      q: ( props || this.props ).initialQuery
    };
    const url = `/flickr/photo_fields.json?${querystring.stringify( params )}`;
    fetch( url, params ).then(
      response => {
        response.json( ).then( json => {
          this.setState( {
            photos: json.map( p =>
              Object.assign( {}, p, {
                id: `${this.state.provider}-${p.native_photo_id}`
              } )
            )
          } );
        } );
        this.setState( { loading: false } );
      },
      error => {
        this.setState( { loading: false } );
      }
    );
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
  choosePhoto( id ) {
    console.log( "[DEBUG] choosePhoto, id: ", id );
    const { photos, chosen } = this.state;
    // const existing = _.find( chosen, p => p.id === id );
    const existingIndex = chosen.findIndex( p => p.id === id );
    if ( existingIndex >= 0 ) {
      // chosen[existingIndex].candidate = false;
      console.log( "[DEBUG] existing photo, setting all chosen photo to be not candidates" );
      this.setState( {
        chosen: chosen.map( p => Object.assign( { }, p, { candidate: false } ) )
      } );
      return;
    }
    const photo = _.find( photos, p => p.id === id );
    if ( !photo ) {
      console.log( "[DEBUG] no photo to choose" );
      return;
    }
    photo.candidate = false;
    console.log( "[DEBUG] appending photo ", id );
    chosen.push( photo );
    this.setState( { chosen } );
  }
  newPhotoEnter( id, index ) {
    const { photos, chosen } = this.state;
    const hovering = _.find( photos, p => p.id === id );
    if ( !hovering ) {
      console.log( "[DEBUG] can't find hovering photo" );
      return;
    }
    const existing = _.find( chosen, p => p.id === id );
    if ( existing ) {
      console.log( "[DEBUG] hovering photo already added" );
      return;
    }
    const newPhoto = Object.assign( { }, hovering, { candidate: true } );
    console.log( "[DEBUG] inserting new photo" );
    chosen.splice( index, 0, newPhoto );
    this.setState( { chosen } );
  }
  newPhotoExit( ) {
    const { chosen } = this.state;
    this.setState( { chosen: chosen.filter( p => !p.candidate ) } );
  }
  removePhoto( id ) {
    const { chosen } = this.state;
    this.setState( { chosen: chosen.filter( p => p.id !== id ) } );
  }
  render( ) {
    console.log( "[DEBUG] rendering PhotoChooserModal" );
    const { visible, onSubmit } = this.props;
    return (
      <Modal
        show={visible}
        bsSize="large"
        className="PhotoChooserModal"
      >
        <Modal.Header>
          { I18n.t( "choose_photos_for_this_taxon" ) }
          <select
            onChange={ e => this.setProvider( e.target.value ) }
            className="pull-right"
          >
            <option value="flickr">Flickr</option>
            <option value="inat">iNat</option>
            <option value="eol">EOL</option>
            <option value="wikimedia">Wikimedia Commons</option>
          </select>
        </Modal.Header>
        <Modal.Body>
          <Grid fluid>
            <Row>
              <Col xs={6}>
                <h2>Photos</h2>
                { this.state.photos.map( photo => (
                  <ExternalPhoto
                    key={`${this.state.provider}-${photo.native_photo_id}`}
                    id={photo.id}
                    src={photo.thumb_url}
                    movePhoto={this.movePhoto}
                    didNotDropPhoto={ ( ) => this.newPhotoExit( ) }
                  />
                ) ) }
              </Col>
              <Col xs={6}>
                <h2>Chosen</h2>
                { _.map( this.state.chosen, ( photo, i ) => (
                  <ChosenPhoto
                    key={`${this.state.provider}-${photo.native_photo_id}`}
                    id={photo.id}
                    src={photo.thumb_url}
                    index={i}
                    movePhoto={this.movePhoto}
                    newPhotoEnter={ id => this.newPhotoEnter( id ) }
                    dropNewPhoto={ id => this.choosePhoto( id ) }
                    removePhoto={ id => this.removePhoto( id ) }
                    candidate={photo.candidate}
                  />
                ) ) }
                <PhotoChooserDropArea
                  photos={this.state.chosen}
                  droppedPhoto={ id => this.choosePhoto( id ) }
                />
              </Col>
            </Row>
          </Grid>
        </Modal.Body>
        <Modal.Footer>
          <Button bsStyle="primary" onClick={ ( ) => onSubmit( this.state.chosen ) } >
            { I18n.t( "submit" ) }
          </Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

PhotoChooserModal.propTypes = {
  initialQuery: PropTypes.string,
  photos: PropTypes.array,
  chosen: PropTypes.array,
  visible: PropTypes.bool,
  onSubmit: PropTypes.func
};

PhotoChooserModal.defaultProps = {
  chosen: []
};

export default PhotoChooserModal;
