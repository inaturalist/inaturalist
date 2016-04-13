import React, { PropTypes, Component } from "react";
import { DragSource, DropTarget } from "react-dnd";
import { Badge, Glyphicon, Input, Button } from "react-bootstrap";
import ImageGallery from "react-image-gallery";
import { pipe } from "ramda";
import TaxonAutocomplete from "../../identify/components/taxon_autocomplete";
import Dropzone from "react-dropzone";
import { DateTimePicker } from "react-widgets";
import Moment from "moment";
import momentLocalizer from "react-widgets/lib/localizers/moment";
import _ from "lodash";

momentLocalizer( Moment );

const cardSource = {
  beginDrag( props ) {
    // hiding the image gallery side slides so the moved card looks clean
    const card = $( `.card[data-id=${props.obsCard.id}]` );
    card.css( "cursor", "no-drag" );
    card.find( ".image-gallery-slide.left" ).hide( );
    card.find( ".image-gallery-slide.right" ).hide( );
    return props;
  },
  endDrag( props ) {
    // hiding the image gallery side slides again
    const card = $( `.card[data-id=${props.obsCard.id}]` );
    card.find( ".image-gallery-slide.left" ).show( );
    card.find( ".image-gallery-slide.right" ).show( );
    return props;
  }
};

const cardTarget = {
  canDrop( props, monitor ) {
    const item = monitor.getItem( );
    return item.obsCard.id !== props.obsCard.id;
  },
  drop( props, monitor, component ) {
    const item = monitor.getItem( );
    const dropResult = component.props;
    if ( dropResult ) {
      props.mergeObsCards( item.obsCard, dropResult.obsCard );
    }
  }
};

class ObsCardComponent extends Component {

  static collect( connect, monitor ) {
    return {
      connectDragSource: connect.dragSource( ),
      isDragging: monitor.isDragging( ),
      connectDragPreview: connect.dragPreview( )
    };
  }

  static collectDrop( connect, monitor ) {
    return {
      connectDropTarget: connect.dropTarget( ),
      isOver: monitor.isOver( ),
      canDrop: monitor.canDrop( )
    };
  }

  constructor( props, context ) {
    super( props, context );
    this.openLocationChooser = this.openLocationChooser.bind( this );
    this.selectCard = this.selectCard.bind( this );
  }

  shouldComponentUpdate( nextProps ) {
    return this.props.isDragging !== nextProps.isDragging ||
      !_.isMatch( this.props.obsCard, nextProps.obsCard );
  }

  openLocationChooser( ) {
    this.props.setState( { locationChooser: {
      open: true,
      lat: this.props.obsCard.latitude,
      lng: this.props.obsCard.longitude,
      radius: this.props.obsCard.accuracy,
      obsCard: this.props.obsCard,
      zoom: this.props.obsCard.zoom,
      center: this.props.obsCard.center,
      bounds: this.props.obsCard.bounds,
      geoprivacy: this.props.obsCard.geoprivacy,
      notes: this.props.obsCard.locality_notes
    } } );
  }

  selectCard( ) {
    this.props.selectObsCards( { [this.props.obsCard.id]: true } );
  }

  render( ) {
    const { obsCard, connectDropTarget, onCardDrop, connectDragPreview, isDragging,
      connectDragSource, isOver, confirmRemoveObsCard, updateObsCard } = this.props;
    let className = "card ui-selectee";
    if ( isDragging ) { className += " dragging"; }
    if ( isOver ) { className += " dragOver"; }
    if ( obsCard.selected ) { className += " selected ui-selecting"; }
    if ( obsCard.blank( ) ) { className += " blank"; }
    let img;
    let badge;
    const filesArray = _.values( obsCard.files );
    const galleryImages = _.compact( _.map( filesArray, f => (
      f.photo && { original: f.photo.small_url }
    ) ) );
    const photo = filesArray.length > 0 ? filesArray[0] : undefined;
    if ( photo && photo.upload_state === "pending" ) {
      badge = ( <Badge><Glyphicon glyph="hourglass" /></Badge> );
      img = ( <div className="placeholder" /> );
    } else if ( photo && photo.upload_state === "uploading" ) {
      badge = ( <Badge><Glyphicon glyph="hourglass" className="fa-spin" /></Badge> );
      img = ( <div className="placeholder" /> );
    } else if ( photo && photo.upload_state === "uploaded" && photo.photo ) {
      badge = ( <Badge>{ filesArray.length }</Badge> );
      // img = ( <img src={ photo.photo.small_url } /> );
      img = (
        <ImageGallery
          showThumbnails={ false }
          showBullets={ galleryImages.length > 1 }
          items={ galleryImages }
        />
      );
    } else {
      img = ( <div className="placeholder" /> );
    }
    let globe = (
      <Button onClick={ this.openLocationChooser }>
        <Glyphicon glyph="globe" />
      </Button>
    );
    return (
      <Dropzone className="cellDropzone" disableClick disablePreview onDrop={
        ( f, e ) => onCardDrop( f, e, obsCard ) } activeClassName="hover"
        key={ obsCard.id }
      >
        <div className="cell">
        {
          connectDropTarget( connectDragPreview(
            <div className={ className } data-id={ obsCard.id }>
              { connectDragSource(
                <div className="move">
                  <span className="glyphicon glyphicon-record" aria-hidden="true"></span>
                </div>
              ) }
              <div className="close" onClick={ confirmRemoveObsCard }>
                <span className="glyphicon glyphicon-remove-sign" aria-hidden="true"></span>
              </div>
              <div className="image">
                { badge }
                { img }
              </div>
              <TaxonAutocomplete key={ obsCard.selected_taxon && obsCard.selected_taxon.id }
                bootstrapClear
                searchExternal={false}
                initialSelection={ obsCard.selected_taxon }
                afterSelect={ function ( result ) {
                  updateObsCard( obsCard,
                    { taxon_id: result.item.id, selected_taxon: result.item } );
                } }
                afterUnselect={ function ( ) {
                  if ( obsCard.taxon_id ) {
                    updateObsCard( obsCard,
                      { taxon_id: undefined, selected_taxon: undefined } );
                  }
                } }
              />
              <DateTimePicker key={ obsCard.date } defaultValue={ obsCard.date } onChange={ e =>
                updateObsCard( obsCard, { date: e } ) }
              />
              <Input type="text" buttonAfter={globe} onClick={ this.selectCard } readOnly
                value={ obsCard.latitude &&
                  `${_.round( obsCard.latitude, 4 )},${_.round( obsCard.longitude, 4 )}` }
              />
              <Input type="textarea" placeholder="Add a description" onClick={ this.selectCard }
                value={ obsCard.description } onChange={ e =>
                  updateObsCard( obsCard, { description: e.target.value } ) }
              />
            </div>
          ) )
        }
        </div>
      </Dropzone>
    );
  }
}

ObsCardComponent.propTypes = {
  obsCard: PropTypes.object,
  confirmRemoveObsCard: PropTypes.func,
  connectDropTarget: PropTypes.func,
  connectDragSource: PropTypes.func,
  connectDragPreview: PropTypes.func,
  isOver: PropTypes.bool,
  isDragging: PropTypes.bool,
  updateObsCard: PropTypes.func,
  onCardDrop: PropTypes.func,
  mergeObsCards: PropTypes.func,
  setState: PropTypes.func,
  selectObsCards: PropTypes.func
};

export default pipe(
  DragSource( "ObsCard", cardSource, ObsCardComponent.collect ),
  DropTarget( "ObsCard", cardTarget, ObsCardComponent.collectDrop )
)( ObsCardComponent );
