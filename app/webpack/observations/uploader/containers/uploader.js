import { connect } from "react-redux";
import HTML5Backend from "react-dnd-html5-backend";
import { DragDropContext } from "react-dnd";
import _ from "lodash";
import DragDropZone from "../components/drag_drop_zone";
import actions from "../actions/actions";
import { createSavedLocation, removeSavedLocation } from "../ducks/saved_locations";
import { updateCurrentUser } from "../../../shared/ducks/config";
import { trackFormatFromFileName } from "../../../shared/geotrack";

const mapStateToProps = state => {
  return Object.assign(
    {},
    state.dragDropZone,
    { savedLocations: state.savedLocations },
    { config: state.config }
  );
};

const mapDispatchToProps = dispatch => ( {
  onDrop: ( droppedFiles, rejectedFiles ) => {
    // Track files fail the dropzone's media type filter, so pick them out
    const [trackFiles, otherRejectedFiles] = _.partition(
      rejectedFiles,
      f => trackFormatFromFileName( f.name )
    );
    if ( otherRejectedFiles.length > 0 ) {
      dispatch( actions.onRejectedFiles( otherRejectedFiles ) );
    }
    if ( trackFiles.length > 0 ) {
      dispatch( actions.onTrackFileDrop( trackFiles[0] ) );
    }
    dispatch( actions.onFileDrop( droppedFiles ) );
  },
  onCardDrop: ( droppedFiles, obsCard ) => {
    dispatch( actions.onFileDropOnCard( droppedFiles, obsCard ) );
  },
  updateObsCard: ( obsCard, updates ) => {
    dispatch( actions.updateObsCard( obsCard, updates ) );
  },
  updateSelectedObsCards: updates => {
    dispatch( actions.updateSelectedObsCards( updates ) );
  },
  removeObsCard: obsCard => {
    dispatch( actions.removeObsCard( obsCard ) );
  },
  removeSelected: ( ) => {
    dispatch( actions.removeSelected( ) );
  },
  selectAll: ( ) => {
    dispatch( actions.selectAll( ) );
  },
  trySubmitObservations: ( ) => {
    dispatch( actions.trySubmitObservations( ) );
  },
  createBlankObsCard: ( ) => {
    dispatch( actions.createBlankObsCard( ) );
  },
  selectObsCards: ids => {
    dispatch( actions.selectObsCards( ids ) );
  },
  mergeObsCards: ( obsCards, targetCard ) => {
    dispatch( actions.mergeObsCards( obsCards, targetCard ) );
  },
  setState: attrs => {
    dispatch( actions.setState( attrs ) );
  },
  updateState: attrs => {
    dispatch( actions.updateState( attrs ) );
  },
  confirmRemoveSelected: ( ) => {
    dispatch( actions.confirmRemoveSelected( ) );
  },
  confirmRemoveObsCard: obsCard => {
    dispatch( actions.confirmRemoveObsCard( obsCard ) );
  },
  movePhoto: ( photo, toObsCard ) => {
    dispatch( actions.movePhoto( photo, toObsCard ) );
  },
  newCardFromMedia: ( media, options = {} ) => {
    dispatch( actions.newCardFromMedia( media, options ) );
  },
  combineSelected: ( ) => {
    dispatch( actions.combineSelected( ) );
  },
  confirmRemoveFile: file => {
    dispatch( actions.confirmRemoveFile( file ) );
  },
  appendToSelectedObsCards: updates => {
    dispatch( actions.appendToSelectedObsCards( updates ) );
  },
  removeFromSelectedObsCards: updates => {
    dispatch( actions.removeFromSelectedObsCards( updates ) );
  },
  saveLocation: params => {
    dispatch( createSavedLocation( params ) );
  },
  removeSavedLocation: savedLocation => dispatch( removeSavedLocation( savedLocation ) ),
  updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
  insertCardsBefore: ( cardIds, beforeCardId ) => {
    dispatch( actions.insertCardsBefore( cardIds, beforeCardId ) );
  },
  // Here items are Photo or File components, which have files and obs cards
  insertExistingFilesBefore: ( items, beforeCardId ) => {
    _.each( items, item => {
      dispatch( actions.newCardFromMedia( item, { beforeCardId } ) );
    } );
  },
  insertDroppedFilesBefore: ( files, beforeCardId ) => {
    dispatch( actions.onFileDrop( files, { beforeCardId } ) );
  },
  duplicateSelected: ( ) => {
    dispatch( actions.duplicateSelected( ) );
  },
  onTrackFileDrop: file => {
    dispatch( actions.onTrackFileDrop( file ) );
  },
  applyTrackLocations: options => {
    dispatch( actions.applyTrackLocations( options ) );
  },
  setTrackClockOffset: clockOffsetMs => {
    dispatch( actions.setTrackClockOffset( clockOffsetMs ) );
  },
  revertTrackLocation: obsCard => {
    dispatch( actions.revertTrackLocation( obsCard ) );
  },
  removeGpsTrack: ( ) => {
    dispatch( actions.setState( { gpsTrack: null } ) );
  },
  openGarminImport: ( ) => dispatch( actions.openGarminImport( ) ),
  closeGarminImport: ( ) => dispatch( actions.closeGarminImport( ) ),
  connectGarmin: apiKey => dispatch( actions.connectGarmin( apiKey ) ),
  disconnectGarmin: ( ) => dispatch( actions.disconnectGarmin( ) ),
  loadGarminActivities: options => dispatch( actions.loadGarminActivities( options ) ),
  importGarminActivity: activity => dispatch( actions.importGarminActivity( activity ) )
} );

/* eslint new-cap: [2, { capIsNewExceptions: ["DragDropContext"] }] */
const Uploader = connect(
  mapStateToProps,
  mapDispatchToProps
)( DragDropContext( HTML5Backend )( DragDropZone ) );

export default Uploader;
