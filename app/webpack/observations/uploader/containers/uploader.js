import { connect } from "react-redux";
import DragDropZone from "../components/drag_drop_zone";
import actions from "../actions/actions";
import HTML5Backend from "react-dnd-html5-backend";
import { DragDropContext } from "react-dnd";
import ObsCard from "../models/obs_card";
import DroppedFile from "../models/dropped_file";

const mapStateToProps = ( state ) => state.dragDropZone;

const mapDispatchToProps = ( dispatch ) => ( {
  onDrop: ( droppedFiles, e ) => {
    if ( droppedFiles.length === 0 ) { return; }
    // skip drops onto cards
    if ( $( ".card" ).has( e.nativeEvent.target ).length > 0 ) { return; }
    const obsCards = { };
    let i = 0;
    const startTime = new Date( ).getTime( );
    droppedFiles.forEach( f => {
      const id = ( startTime + i );
      const obsCard = new ObsCard( { id } );
      obsCard.files[id] = DroppedFile.fromFile( f, id );
      obsCard.date = obsCard.files[id].lastModifiedDate;
      obsCards[obsCard.id] = obsCard;
      i += 1;
    } );
    dispatch( actions.appendObsCards( obsCards ) );
    dispatch( actions.uploadImages( ) );
  },
  onCardDrop: ( droppedFiles, e, obsCard ) => {
    if ( droppedFiles.length === 0 ) { return; }
    const files = Object.assign( { }, obsCard.files );
    let i = 0;
    const startTime = new Date( ).getTime( );
    droppedFiles.forEach( f => {
      const id = ( startTime + i );
      files[id] = DroppedFile.fromFile( f, id );
      i += 1;
    } );
    dispatch( actions.updateObsCard( obsCard, {
      files,
      dispatch
    } ) );
    dispatch( actions.uploadImages( ) );
  },
  updateObsCard: ( obsCard, updates ) => {
    dispatch( actions.updateObsCard( obsCard, updates ) );
  },
  updateSelectedObsCards: ( updates ) => {
    dispatch( actions.updateSelectedObsCards( updates ) );
  },
  removeObsCard: ( obsCard ) => {
    dispatch( actions.removeObsCard( obsCard ) );
  },
  removeSelected: ( ) => {
    dispatch( actions.removeSelected( ) );
  },
  selectAll: ( ) => {
    dispatch( actions.selectAll( ) );
  },
  submitObservations: ( ) => {
    dispatch( actions.submitObservations( ) );
  },
  createBlankObsCard: ( ) => {
    dispatch( actions.createBlankObsCard( ) );
  },
  selectObsCards: ( ids ) => {
    dispatch( actions.selectObsCards( ids ) );
  },
  mergeObsCards: ( fromObsCard, toObsCard ) => {
    dispatch( actions.mergeObsCards( fromObsCard, toObsCard ) );
  },
  setState: ( attrs ) => {
    dispatch( actions.setState( attrs ) );
  },
  updateState: ( attrs ) => {
    dispatch( actions.updateState( attrs ) );
  },
  confirmRemoveSelected: ( ) => {
    dispatch( actions.confirmRemoveSelected( ) );
  },
  confirmRemoveObsCard: ( obsCard ) => {
    dispatch( actions.confirmRemoveObsCard( obsCard ) );
  }
} );

const Uploader = connect(
  mapStateToProps,
  mapDispatchToProps
)( DragDropContext( HTML5Backend )( DragDropZone ) );

export default Uploader;
