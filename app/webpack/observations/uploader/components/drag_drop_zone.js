import _ from "lodash";
import React, { PropTypes, Component } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import Dropzone from "react-dropzone";
import { DropTarget } from "react-dnd";
import { pipe } from "ramda";
import ConfirmModal from "./confirm_modal";
import LeftMenu from "./left_menu";
import LocationChooser from "./location_chooser";
import ObsCardComponent from "./obs_card_component";
import OpeningActionMenu from "./opening_action_menu";
import PhotoViewer from "./photo_viewer";
import RemoveModal from "./remove_modal";
import StatusModal from "./status_modal";
import TopMenu from "./top_menu";
import HeaderUserMenu from "./header_user_menu";

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
    this.resize = this.resize.bind( this );
    this.selectNone = this.selectNone.bind( this );
  }

  componentDidMount( ) {
    this.resize( );
    $( window ).on( "resize", this.resize );
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
        ".input-group-addon, " +
        ".bootstrap-datetimepicker-widget, a, li, .rw-datetimepicker, textarea",
      selected: this.selectObsCards,
      unselected: this.selectObsCards,
      start: () => $( "body" ).off( "click" ),
      stop: () => setTimeout( () => $( "body" ).on( "click", this.unselectAll ), 100 ),
      distance: 1
    } );
  }

  componentDidUpdate( ) {
    this.resize( );
    const count = Object.keys( this.props.obsCards ).length;
    $( ".uploader" ).selectable( count > 0 ? "enable" : "disable" );
    if ( count > 0 && this.props.saveStatus !== "saving" ) {
      window.onbeforeunload = ( ) =>
        "These observations have not been uploaded yet.";
    } else {
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

  resize( ) {
    this.resizeElement( $( ".uploader" ) );
    this.resizeElement( $( "#imageGrid" ) );
  }

  resizeElement( el ) {
    const topOffset = el.offset( ).top;
    const height = $( window ).height( );
    const difference = height - topOffset;
    if ( difference > 450 ) {
      el.css( "min-height", difference );
    }
  }

  selectObsCards( e ) {
    e.preventDefault( );
    e.stopPropagation( );
    const selectedIDs = { };
    $( ".card.ui-selecting, .card.ui-selected" ).each( function ( ) {
      selectedIDs[$( this ).data( "id" )] = true;
    } );
    this.props.selectObsCards( selectedIDs );
  }

  unselectAll( e ) {
    const ignore = "a, .card, button, .modal, " +
      ".bootstrap-datetimepicker-widget, .ui-autocomplete, #react-images-container, " +
      ".navbar .select, input, .form-group";
    const target = e.target || e.nativeEvent.target;
    if ( $( ignore ).has( target ).length > 0 ||
         $( target ).is( ignore ) ) {
      return;
    }
    this.selectNone( );
  }

  selectNone( ) {
    this.props.selectObsCards( { } );
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
    let className = "uploader";
    if ( draggingProps && draggingProps.obsCard ) { className += " hover"; }
    if ( photoIsOver ) { className += " photoOver"; }
    const cardCount = Object.keys( obsCards ).length;
    if ( cardCount > 0 ) {
      className += " populated";
      const keys = _.keys( selectedObsCards );
      const countSelected = _.keys( selectedObsCards ).length;
      const first = keys[0];
      leftColumn = (
        <Col className="col-fixed-240 leftColumn">
          <LeftMenu
            key={ `leftmenu${countSelected}${first}` }
            count={ cardCount }
            setState={ this.props.setState }
            selectedObsCards={ this.props.selectedObsCards }
            updateSelectedObsCards={ this.props.updateSelectedObsCards }
          />
        </Col>
      );
    } else {
      intro = ( <OpeningActionMenu fileChooser={ this.fileChooser } /> );
    }
    const countSelected = _.keys( selectedObsCards ).length;
    const countSelectedPending =
      _.sum( _.map( selectedObsCards, c => c.nonUploadedFiles().length ) );
    const countPending = _.sum( _.map( obsCards, c => c.nonUploadedFiles().length ) );
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
          <nav className="navbar navbar-default">
            <div className="container-fluid">
              <div className="navbar-header">
                <button
                  type="button"
                  className="navbar-toggle collapsed"
                  data-toggle="collapse"
                  data-target="#header-user-menu"
                  aria-expanded="false"
                >
                  <span className="sr-only">Toggle navigation</span>
                  <span className="icon-bar"></span>
                  <span className="icon-bar"></span>
                  <span className="icon-bar"></span>
                </button>
                <a href="/" className="navbar-brand" alt="iNaturalist.org">
                  <img src="http://static.inaturalist.org/sites/1-logo.png?1433365372" />
                </a>
              </div>
              <HeaderUserMenu user={ CURRENT_USER } />
            </div>
          </nav>
          <TopMenu
            key={ `topMenu${cardCount}${countSelected}` }
            createBlankObsCard={ createBlankObsCard }
            confirmRemoveSelected={ confirmRemoveSelected }
            selectAll={ selectAll }
            selectNone={ this.selectNone }
            selectedObsCards={ selectedObsCards }
            trySubmitObservations={ trySubmitObservations }
            combineSelected={ combineSelected }
            fileChooser={ this.fileChooser }
            countTotal={ cardCount }
            countSelected={ countSelected }
            countSelectedPending={ countSelectedPending }
            countPending={ countPending }
          />
          <Grid fluid>
            <div className="row-fluid">
              <Col md={ 12 }>
                <Row>
                  { intro }
                </Row>
              </Col>
            </div>
          </Grid>
          <Grid fluid>
            <div className="row-fluid">
              { leftColumn }
              { this.props.connectDropTarget(
                <div id="imageGrid" className="col-offset-290 col-md-12">
                  <Row>
                    <ul className="obs">
                      { _.map( obsCards, obsCard => (
                        <ObsCardComponent
                          key={ obsCard.id }
                          ref={ `obsCard${obsCard.id}` }
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
                    </ul>
                  </Row>
                </div>
              ) }
            </div>
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
  combineSelected: PropTypes.func,
  commandKeyPressed: PropTypes.bool,
  confirmModal: PropTypes.object,
  confirmRemoveFile: PropTypes.func,
  confirmRemoveObsCard: PropTypes.func,
  confirmRemoveSelected: PropTypes.func,
  connectDropTarget: PropTypes.func,
  createBlankObsCard: PropTypes.func,
  draggingProps: PropTypes.object,
  locationChooser: PropTypes.object,
  mergeObsCards: PropTypes.func,
  movePhoto: PropTypes.func,
  newCardFromPhoto: PropTypes.func,
  obsCards: PropTypes.object,
  onCardDrop: PropTypes.func,
  onDrop: PropTypes.func.isRequired,
  photoIsOver: PropTypes.bool,
  photoViewer: PropTypes.object,
  removeModal: PropTypes.object,
  removeObsCard: PropTypes.func,
  removeSelected: PropTypes.func,
  saveCounts: PropTypes.object,
  saveStatus: PropTypes.string,
  selectAll: PropTypes.func,
  selectedObsCards: PropTypes.object,
  selectObsCards: PropTypes.func,
  setState: PropTypes.func,
  shiftKeyPressed: PropTypes.bool,
  trySubmitObservations: PropTypes.func,
  updateObsCard: PropTypes.func,
  updateSelectedObsCards: PropTypes.func,
  updateState: PropTypes.func
};

export default pipe(
  DropTarget( "Photo", photoTarget, DragDropZone.photoDrop )
)( DragDropZone );
