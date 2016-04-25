import React, { PropTypes, Component } from "react";
import { Grid, Row, Col, Button, Glyphicon, DropdownButton, MenuItem } from "react-bootstrap";
import Dropzone from "react-dropzone";
import { DropTarget } from "react-dnd";
import { pipe } from "ramda";
import ObsCardComponent from "./obs_card_component";
import LocationChooser from "./location_chooser";
import StatusModal from "./status_modal";
import LeftMenu from "./left_menu";
import TopMenu from "./top_menu";
import ConfirmModal from "./confirm_modal";
import RemoveModal from "./remove_modal";
import PhotoViewer from "./photo_viewer";
import _ from "lodash";

const photoTarget = {
  drop( props, monitor, component ) {
    if ( monitor.didDrop( ) ) { return; }
    const item = monitor.getItem( );
    const dropResult = component.props;
    if ( dropResult ) {
      props.newCardFromPhoto( item, dropResult.obsCard );
    }
  }
};

class DragDropZone extends Component {

  static photoDrop( connect, monitor ) {
    return {
      connectDropTarget: connect.dropTarget( ),
      photoIsOver: monitor.isOver( ),
      canDrop: monitor.canDrop( )
    };
  }

  constructor( props, context ) {
    super( props, context );
    this.fileChooser = this.fileChooser.bind( this );
    this.selectObsCards = this.selectObsCards.bind( this );
    this.unselectAll = this.unselectAll.bind( this );
    this.selectCard = this.selectCard.bind( this );
  }

  componentDidUpdate( ) {
    if ( Object.keys( this.props.obsCards ).length > 0 ) {
      if ( this.props.saveStatus !== "saving" ) {
        window.onbeforeunload = ( ) =>
          "These observations have not been uploaded yet.";
      } else {
        window.onbeforeunload = undefined;
      }
      $( "body" ).unbind( "keydown keyup click" );
      $( "body" ).on( "keydown", e => {
        if ( e.which === 91 ) {
          this.props.setState( { commandKeyPressed: true } );
        } else if ( e.which === 16 ) {
          this.props.setState( { shiftKeyPressed: true } );
        }
      } );
      $( "body" ).on( "keyup", e => {
        if ( e.which === 91 ) {
          this.props.setState( { commandKeyPressed: false } );
        } else if ( e.which === 16 ) {
          this.props.setState( { shiftKeyPressed: false } );
        }
      } );
      $( "body" ).on( "click", this.unselectAll );
      $( ".uploader" ).selectable( { filter: ".card",
        cancel: ".card, .glyphicon, input, button, .input-group-addon, " +
          ".input-group-addon, #multiMenu, " +
          ".bootstrap-datetimepicker-widget, a, li, .rw-datetimepicker, textarea",
        selecting: this.selectObsCards,
        unselecting: this.selectObsCards,
        distance: 1
      } );
      $( ".uploader" ).selectable( "enable" );
    } else {
      $( ".uploader" ).selectable( "disable" );
      window.onbeforeunload = undefined;
    }
  }

  closeAutocompletes( e ) {
    const ignore = "input[name='taxon_name'], .ui-autocomplete";
    const target = e.target || e.nativeEvent.target;
    if ( $( ignore ).has( target ).length > 0 ||
         $( target ).is( ignore ) ) {
      return;
    }
    $( ".ui-autocomplete" ).hide( );
  }

  fileChooser( ) {
    this.refs.dropzone.open( );
  }

  selectObsCards( ) {
    const selectedIDs = { };
    $( ".card.ui-selecting, .card.ui-selected" ).each( function ( ) {
      selectedIDs[$( this ).data( "id" )] = true;
    } );
    this.props.selectObsCards( selectedIDs );
  }

  unselectAll( e ) {
    const ignore = "a, .card, #multiMenu, button, .modal, .bootstrap-datetimepicker-widget, " +
      ".ui-autocomplete";
    const target = e.target || e.nativeEvent.target;
    if ( $( ignore ).has( target ).length > 0 ||
         $( target ).is( ignore ) ) {
      return;
    }
    this.props.selectObsCards( {} );
  }

  selectCard( obsCard ) {
    let newSelected;
    const selectedIDs = _.keys( this.props.selectedObsCards );
    if ( this.props.commandKeyPressed ) {
      // command + click
      if ( this.props.selectedObsCards[obsCard.id] ) {
        // the card was already selected
        newSelected = Object.assign( { }, this.props.selectedObsCards );
        delete newSelected[obsCard.id];
      } else {
        newSelected = Object.assign( { }, this.props.selectedObsCards, { [obsCard.id]: true } );
      }
    } else if ( this.props.shiftKeyPressed && selectedIDs.length > 0 ) {
      // shift + click
      const firstSelected = _.min( selectedIDs );
      newSelected = Object.assign( { }, this.props.selectedObsCards );
      _.each( this.props.obsCards, ( card, id ) => {
        // select anything between the first selected and this selection
        if ( ( obsCard.id < firstSelected && _.inRange( id, obsCard.id, firstSelected ) ) ||
             ( obsCard.id > firstSelected && _.inRange( id, firstSelected, obsCard.id + 1 ) ) ) {
          newSelected[id] = true;
        }
      } );
    } else {
      // normal click
      newSelected = { [obsCard.id]: true };
    }
    this.props.selectObsCards( newSelected );
  }

  render( ) {
    const { onDrop, updateObsCard, confirmRemoveObsCard, onCardDrop, updateSelectedObsCards,
      obsCards, trySubmitObservations, createBlankObsCard, selectedObsCards, locationChooser,
      selectAll, removeSelected, mergeObsCards, saveStatus, saveCounts, setState,
      updateState, removeModal, confirmRemoveSelected, removeObsCard, movePhoto,
      selectObsCards, combineSelected, commandKeyPressed, shiftKeyPressed,
      draggingProps, confirmModal, confirmRemoveFile, photoViewer, photoIsOver } = this.props;
    let leftColumn;
    let intro;
    let mainColumnSpan = 12;
    let className = "uploader";
    if ( draggingProps && draggingProps.obsCard ) { className += " hover"; }
    if ( photoIsOver ) { className += " photoOver"; }
    const cardCount = Object.keys( obsCards ).length;
    if ( cardCount > 0 ) {
      mainColumnSpan = 9;
      className += " populated";
      const keys = _.keys( selectedObsCards );
      const countSelected = _.keys( selectedObsCards ).length;
      const first = keys[0];
      leftColumn = (
        <Col xs={ 3 } className="leftColumn">
          <LeftMenu
            key={ `leftmenu${countSelected}${first}` }
            count={cardCount}
            setState={this.props.setState}
            selectedObsCards={this.props.selectedObsCards}
            updateSelectedObsCards={this.props.updateSelectedObsCards}
          />
        </Col>
      );
    } else {
      intro = (
        <div className="intro">
          <div className="start">
            <div className="drag_or_choose">
              <p>Drag and drop some photos</p>
              <p>or</p>
              <Button bsStyle="primary" bsSize="large" onClick={ ( ) => this.fileChooser( ) }>
                Choose photos
                <Glyphicon glyph="upload" />
              </Button>
            </div>
            <DropdownButton bsStyle="default" title="More Import Options" id="more_imports">
              <MenuItem href="/observations/import#csv_import">CSV</MenuItem>
              <MenuItem href="/observations/import#photo_import">From Flickr</MenuItem>
              <MenuItem divider />
              <MenuItem header>Import Sounds</MenuItem>
              <MenuItem href="/observations/import#sound_import">From SoundCloud</MenuItem>
            </DropdownButton>
          </div>
          <div className="hover">
            <p>Drop it</p>
          </div>
        </div>
      );
    }
    return (
      <div onClick={ this.closeAutocompletes }>
        <Dropzone
          ref="dropzone"
          onDrop={ onDrop }
          className={ className }
          activeClassName="hover"
          disableClick
          disablePreview
          accept="image/*"
        >
          <Grid fluid>
            <TopMenu
              createBlankObsCard={ createBlankObsCard }
              confirmRemoveSelected={ confirmRemoveSelected }
              selectAll={ selectAll }
              selectedObsCards={ selectedObsCards }
              trySubmitObservations={ trySubmitObservations }
              combineSelected={ combineSelected }
              fileChooser={ this.fileChooser }
              countTotal={ cardCount }
              countSelected={ _.keys( selectedObsCards ).length }
            />
            <Row className="body">
              { leftColumn }
                <Col xs={ mainColumnSpan } id="imageGrid">
                  { this.props.connectDropTarget(
                    <div>
                      { _.map( obsCards, obsCard => (
                        <ObsCardComponent key={ obsCard.id }
                          obsCard={ obsCard }
                          onCardDrop={ onCardDrop }
                          updateObsCard={ updateObsCard }
                          mergeObsCards={ mergeObsCards }
                          selectCard={ this.selectCard }
                          selectObsCards={ selectObsCards }
                          selectedObsCards={ selectedObsCards }
                          movePhoto={ movePhoto }
                          confirmRemoveObsCard={ ( ) => confirmRemoveObsCard( obsCard ) }
                          commandKeyPressed={ commandKeyPressed }
                          shiftKeyPressed={ shiftKeyPressed }
                          setState={ setState }
                          draggingProps={ draggingProps }
                          confirmRemoveFile={ confirmRemoveFile }
                        />
                      ) ) }
                    </div>
                  ) }
                  { intro }
                </Col>
            </Row>
          </Grid>
        </Dropzone>
        <StatusModal
          show={ saveStatus === "saving" }
          saveCounts={ saveCounts }
          total={ cardCount } className="status"
        />
        <ConfirmModal
          updateState={ updateState }
          removeObsCard={ removeObsCard }
          removeSelected={ removeSelected }
          { ...confirmModal }
        />
        <RemoveModal
          updateState={ updateState }
          removeObsCard={ removeObsCard }
          removeSelected={ removeSelected }
          { ...removeModal }
        />
        <LocationChooser
          obsCards={ obsCards }
          setState={ setState }
          updateObsCard={ updateObsCard }
          updateState={ updateState }
          updateSelectedObsCards={ updateSelectedObsCards }
          { ...locationChooser }
        />
        <PhotoViewer
          updateState={ updateState }
          { ...photoViewer }
        />
      </div>
    );
  }
}

DragDropZone.propTypes = {
  onDrop: PropTypes.func.isRequired,
  updateObsCard: PropTypes.func,
  removeObsCard: PropTypes.func,
  confirmRemoveObsCard: PropTypes.func,
  obsCards: PropTypes.object,
  selectedObsCards: PropTypes.object,
  trySubmitObservations: PropTypes.func,
  createBlankObsCard: PropTypes.func,
  selectObsCards: PropTypes.func,
  updateSelectedObsCards: PropTypes.func,
  onCardDrop: PropTypes.func,
  selectAll: PropTypes.func,
  removeSelected: PropTypes.func,
  mergeObsCards: PropTypes.func,
  saveStatus: PropTypes.string,
  saveCounts: PropTypes.object,
  locationChooser: PropTypes.object,
  removeModal: PropTypes.object,
  confirmModal: PropTypes.object,
  setState: PropTypes.func,
  updateState: PropTypes.func,
  confirmRemoveSelected: PropTypes.func,
  connectDropTarget: PropTypes.func,
  movePhoto: PropTypes.func,
  newCardFromPhoto: PropTypes.func,
  draggingProps: PropTypes.object,
  combineSelected: PropTypes.func,
  commandKeyPressed: PropTypes.bool,
  shiftKeyPressed: PropTypes.bool,
  confirmRemoveFile: PropTypes.func,
  photoViewer: PropTypes.object,
  photoIsOver: PropTypes.bool
};

export default pipe(
  DropTarget( "Photo", photoTarget, DragDropZone.photoDrop )
)( DragDropZone );
