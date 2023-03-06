import _ from "lodash";
import React, { Component } from "react";
import PropTypes from "prop-types";
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
import InsertionDropTarget from "./insertion_drop_target";
import { ACCEPTED_FILE_TYPES, MAX_FILE_SIZE } from "../models/util";

const fileTarget = {
  drop( props, monitor ) {
    if ( monitor.didDrop( ) ) { return; }
    const item = monitor.getItem( );
    props.newCardFromMedia( item );
  }
};

class DragDropZone extends Component {
  static fileDrop( connect, monitor ) {
    return {
      connectDropTarget: connect.dropTarget( ),
      fileIsOver: monitor.isOver( ),
      canDrop: monitor.canDrop( )
    };
  }

  static closeAutocompletes( e ) {
    const ignore = "input[name='taxon_name'], .ui-autocomplete";
    const target = e.target || e.nativeEvent.target;
    if (
      $( ignore ).has( target ).length > 0
      || $( target ).is( ignore )
    ) {
      return;
    }
    $( ".ui-autocomplete" ).hide( );
  }

  static resize( ) {
    DragDropZone.resizeElement( $( ".uploader" ) );
    DragDropZone.resizeElement( $( "#imageGrid" ) );
    DragDropZone.resizeElement( $( ".leftColumn" ) );
  }

  static resizeElement( el ) {
    if ( el.length === 0 ) { return; }
    const topOffset = el.offset( ).top;
    const height = $( window ).height( );
    const difference = height - topOffset;
    if ( difference > 450 ) {
      el.css( "min-height", difference );
    }
  }

  constructor( props, context ) {
    super( props, context );
    this.fileChooser = this.fileChooser.bind( this );
    this.selectObsCards = this.selectObsCards.bind( this );
    this.unselectAll = this.unselectAll.bind( this );
    this.selectCard = this.selectCard.bind( this );
    this.resize = DragDropZone.resize.bind( this );
    this.selectNone = this.selectNone.bind( this );
  }

  componentDidMount( ) {
    const { setState: propsSetState } = this.props;
    this.resize( );
    $( window ).on( "resize", this.resize );
    $( "body" ).unbind( "keydown keyup click" );
    const commandKeys = [17, 91, 93, 224];
    const shiftKeys = [16];
    $( "body" ).on( "keydown", e => {
      if ( _.includes( commandKeys, e.which ) ) {
        propsSetState( { commandKeyPressed: true } );
      } else if ( _.includes( shiftKeys, e.which ) ) {
        propsSetState( { shiftKeyPressed: true } );
      }
    } );
    $( "body" ).on( "keyup", e => {
      if ( _.includes( commandKeys, e.which ) ) {
        propsSetState( { commandKeyPressed: false } );
      } else if ( _.includes( shiftKeys, e.which ) ) {
        propsSetState( { shiftKeyPressed: false } );
      }
    } );
    $( "body" ).on( "click", this.unselectAll );
    $( ".uploader" ).selectable( {
      filter: ".card",
      cancel: ".card, .glyphicon, input, button, .input-group-addon, .input-group-addon, .intro, select, .leftColumn, .bootstrap-datetimepicker-widget, a, li, .rw-datetimepicker, textarea",
      selected: this.selectObsCards,
      unselected: this.selectObsCards,
      start: () => $( "body" ).off( "click" ),
      stop: () => setTimeout( () => $( "body" ).on( "click", this.unselectAll ), 100 ),
      distance: 1
    } );
    // prevent these keys from being stuck in the "pressed" state
    $( window ).blur( () => {
      propsSetState( { shiftKeyPressed: false } );
      propsSetState( { commandKeyPressed: false } );
    } );
  }

  componentDidUpdate( ) {
    const { obsCards, saveStatus } = this.props;
    this.resize( );
    const count = Object.keys( obsCards ).length;
    $( ".uploader" ).selectable( count > 0 ? "enable" : "disable" );
    if ( count > 0 && saveStatus !== "saving" ) {
      window.onbeforeunload = ( ) => I18n.t( "these_observations_have_not_been_uploaded_yet" );
    } else {
      window.onbeforeunload = undefined;
    }
  }

  fileChooser( ) {
    this.refs.dropzone.open( );
  }

  selectObsCards( e ) {
    const { selectObsCards } = this.props;
    e.preventDefault( );
    e.stopPropagation( );
    const selectedIDs = { };
    $( ".card.ui-selecting, .card.ui-selected" ).each( function ( ) {
      selectedIDs[$( this ).data( "id" )] = true;
    } );
    selectObsCards( selectedIDs );
  }

  unselectAll( e ) {
    const ignore = "a, .card, button, .modal, span.title, .leftColumn, .bootstrap-datetimepicker-widget, .ui-autocomplete, #lightboxBackdrop, .navbar .select, input, .form-group, select";
    const target = e.target || e.nativeEvent.target;
    if (
      $( ignore ).has( target ).length > 0
      || $( target ).is( ignore )
    ) {
      return;
    }
    // some targets will be gone by this point, like taxon autocomplete results
    // don't count those as unselecting
    if ( $( "body" ).has( target ).length === 0 ) {
      return;
    }
    this.selectNone( );
  }

  selectNone( ) {
    $( "input, textarea" ).blur( );
    const { selectObsCards } = this.props;
    selectObsCards( { } );
  }

  selectCard( obsCard ) {
    const {
      selectedObsCards,
      commandKeyPressed,
      shiftKeyPressed,
      obsCards,
      selectObsCards
    } = this.props;
    let newSelected;
    const selectedIDs = _.keys( selectedObsCards );
    if ( commandKeyPressed ) {
      // command + click
      if ( selectedObsCards[obsCard.id] ) {
        // the card was already selected
        newSelected = Object.assign( { }, selectedObsCards );
        delete newSelected[obsCard.id];
      } else {
        newSelected = Object.assign( { }, selectedObsCards, { [obsCard.id]: true } );
      }
    } else if ( shiftKeyPressed && selectedIDs.length > 0 ) {
      // shift + click
      const firstSelected = _.min( selectedIDs );
      newSelected = Object.assign( { }, selectedObsCards );
      _.each( obsCards, ( card, id ) => {
        // select anything between the first selected and this selection
        if (
          ( obsCard.id < firstSelected && _.inRange( id, obsCard.id, firstSelected ) )
          || ( obsCard.id > firstSelected && _.inRange( id, firstSelected, obsCard.id + 1 ) )
        ) {
          newSelected[id] = true;
        }
      } );
    } else {
      // normal click
      newSelected = { [obsCard.id]: true };
    }
    selectObsCards( newSelected );
  }

  render( ) {
    const {
      confirmModal,
      confirmRemoveObsCard,
      connectDropTarget,
      draggingProps,
      fileIsOver,
      locationChooser,
      obsCards,
      observationField,
      observationFieldSelectedDate,
      observationFieldValue,
      onDrop,
      photoViewer,
      obsPositions,
      removeModal,
      saveStatus,
      selectedObsCards,
      insertCardsBefore,
      insertExistingFilesBefore,
      insertDroppedFilesBefore
    } = this.props;
    let leftColumn;
    let intro;
    let className = "uploader";
    if ( draggingProps && draggingProps.obsCard ) { className += " hover"; }
    if ( fileIsOver ) { className += " fileOver"; }
    const cardCount = Object.keys( obsCards ).length;
    if ( cardCount > 0 ) {
      const keys = _.keys( selectedObsCards );
      const countSelected = _.keys( selectedObsCards ).length;
      const lastUpdate = _.max( _.map( selectedObsCards, c => c.updatedAt ) );
      const first = keys[0];
      let leftMenuKey = `leftmenu${countSelected}${first}${lastUpdate}`;
      if ( observationField ) {
        leftMenuKey += `field${observationField.id}`;
      }
      if ( observationFieldValue ) {
        leftMenuKey += observationFieldValue;
      }
      if ( observationFieldSelectedDate ) {
        leftMenuKey += observationFieldSelectedDate;
      }
      leftColumn = (
        <Col className="col-fixed-250 leftColumn">
          <LeftMenu
            reactKey={leftMenuKey}
            count={cardCount}
            {...this.props}
          />
        </Col>
      );
    } else {
      intro = ( <OpeningActionMenu fileChooser={this.fileChooser} /> );
    }
    const countSelected = _.keys( selectedObsCards ).length;
    const countSelectedPending = _.sum(
      _.map( selectedObsCards, c => c.nonUploadedFiles().length )
    );
    const countPending = _.sum( _.map( obsCards, c => c.nonUploadedFiles().length ) );
    return (
      <div onClick={DragDropZone.closeAutocompletes}>
        <Dropzone
          ref="dropzone"
          onDrop={( acceptedFiles, rejectedFiles, dropEvent ) => {
            // Skip drops on components that handle drops themselves. Dropping a
            // file on a Dropzone component will propagate drop events to *all*
            // Dropzone components that contain it. Since our DragDropZone
            // components contains the ObsCardComponent, for example, we need to
            // ensure that drops onto obs cards that do *not* behave like
            // dropping a file on the DragDropZone. So here ensuring that if the
            // element that was the target of the drop event matches selectors
            // for components we know will handle file drops themselves, just
            // ignore this event
            // Also trying to protect against treating images dragged from the
            // same page from being treated as new files. Images dragged from
            // the same page will appear as multiple dataTransferItems, the
            // first being a "string" kind and not a "file" kind
            if ( dropEvent.nativeEvent.dataTransfer
              && dropEvent.nativeEvent.dataTransfer.items
              && dropEvent.nativeEvent.dataTransfer.items.length > 0
              && dropEvent.nativeEvent.dataTransfer.items[0].kind === "string" ) {
              return;
            }
            if ( $( ".ObsCardComponent, .InsertionDropTarget" ).has( dropEvent.nativeEvent.target ).length === 0 ) {
              _.each( acceptedFiles, file => {
                try {
                  file.preview = file.preview || window.URL.createObjectURL( file );
                } catch ( err ) {
                  // eslint-disable-next-line no-console
                  console.error( "Failed to generate preview for file", file, err );
                }
              } );
              onDrop( acceptedFiles, rejectedFiles );
            }
          }}
          className={className}
          activeClassName="hover"
          disableClick
          disablePreview
          accept={ACCEPTED_FILE_TYPES}
          maxSize={MAX_FILE_SIZE}
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
                  <span className="icon-bar" />
                  <span className="icon-bar" />
                  <span className="icon-bar" />
                </button>
                <a href="/" className="navbar-brand" title={SITE.name} alt={SITE.name}>
                  <img src={SITE.logo} alt={SITE.name} />
                </a>
              </div>
              <HeaderUserMenu user={CURRENT_USER} />
            </div>
          </nav>
          <TopMenu
            key={`topMenu${cardCount}${countSelected}`}
            reactKey={`topMenu${cardCount}${countSelected}`}
            selectNone={this.selectNone}
            fileChooser={this.fileChooser}
            countTotal={cardCount}
            countSelected={countSelected}
            countSelectedPending={countSelectedPending}
            countPending={countPending}
            {...this.props}
          />
          <Grid fluid>
            <div className="row-fluid">
              <Col md={12}>
                <Row>
                  { intro }
                </Row>
              </Col>
            </div>
          </Grid>
          <Grid fluid>
            <div className="row-fluid">
              { leftColumn }
              { connectDropTarget(
                <div id="imageGrid" className="col-offset-290 col-md-12">
                  <div id="imageGridObs" className="obs">
                    { _.map( obsPositions, ( cardID, position ) => {
                      const obsCard = obsCards[cardID];
                      return (
                        <div className="card-and-inserts" key={`card-and-inserts-${obsCard.id}`}>
                          <InsertionDropTarget
                            className="before"
                            beforeCardId={cardID}
                            insertCardsBefore={insertCardsBefore}
                            insertExistingFilesBefore={insertExistingFilesBefore}
                            insertDroppedFilesBefore={insertDroppedFilesBefore}
                          />
                          <ObsCardComponent
                            {...this.props}
                            key={obsCard.id}
                            ref={`obsCard${obsCard.id}`}
                            obsCard={obsCard}
                            selectCard={this.selectCard}
                            confirmRemoveObsCard={( ) => confirmRemoveObsCard( obsCard )}
                          />
                          { position >= obsPositions.length - 1 ? (
                            <InsertionDropTarget
                              className="after"
                              insertCardsBefore={insertCardsBefore}
                              insertExistingFilesBefore={insertExistingFilesBefore}
                              insertDroppedFilesBefore={insertDroppedFilesBefore}
                            />
                          ) : (
                            <InsertionDropTarget
                              className="after"
                              beforeCardId={obsPositions[position + 1]}
                              insertCardsBefore={insertCardsBefore}
                              insertExistingFilesBefore={insertExistingFilesBefore}
                              insertDroppedFilesBefore={insertDroppedFilesBefore}
                            />
                          ) }
                        </div>
                      );
                    } ) }
                  </div>
                </div>
              ) }
            </div>
          </Grid>
        </Dropzone>
        <StatusModal
          {...this.props}
          className="status"
          show={saveStatus === "saving" && !confirmModal.show}
          total={cardCount}
        />
        <ConfirmModal
          {...this.props}
          {...confirmModal}
        />
        <RemoveModal
          {...this.props}
          {...removeModal}
        />
        <LocationChooser
          {...this.props}
          {...locationChooser}
        />
        <PhotoViewer
          {...this.props}
          {...photoViewer}
        />
      </div>
    );
  }
}

DragDropZone.propTypes = {
  commandKeyPressed: PropTypes.bool,
  config: PropTypes.object,
  confirmModal: PropTypes.object,
  confirmRemoveObsCard: PropTypes.func,
  connectDropTarget: PropTypes.func,
  draggingProps: PropTypes.object,
  fileIsOver: PropTypes.bool,
  files: PropTypes.object,
  locationChooser: PropTypes.object,
  newCardFromMedia: PropTypes.func,
  obsCards: PropTypes.object,
  observationField: PropTypes.object,
  observationFieldSelectedDate: PropTypes.string,
  observationFieldValue: PropTypes.any,
  onDrop: PropTypes.func.isRequired,
  photoViewer: PropTypes.object,
  removeModal: PropTypes.object,
  removeObsCard: PropTypes.func,
  saveStatus: PropTypes.string,
  selectedObsCards: PropTypes.object,
  selectObsCards: PropTypes.func,
  setState: PropTypes.func,
  shiftKeyPressed: PropTypes.bool,
  updateCurrentUser: PropTypes.func,
  obsPositions: PropTypes.array,
  insertCardsBefore: PropTypes.func,
  insertExistingFilesBefore: PropTypes.func,
  insertDroppedFilesBefore: PropTypes.func
};

export default pipe(
  DropTarget( ["Photo", "Sound"], fileTarget, DragDropZone.fileDrop )
)( DragDropZone );
