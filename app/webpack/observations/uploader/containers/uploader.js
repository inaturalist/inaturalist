import { connect } from "react-redux";
import DragDropZone from "../components/drag_drop_zone";
import * as actions from "../actions/actions";
import HTML5Backend from "react-dnd-html5-backend";
import { DragDropContext } from "react-dnd";
import ObsCard from "../components/obs_card";


const mapStateToProps = ( state ) => state.dragDropZone;

const mapDispatchToProps = ( dispatch ) => ( {
  onDrop: ( files ) => {
    const cards = _.object( files.map( f => {
      const card = new ObsCard( {
        id: f.size,
        name: f.name,
        preview: f.preview,
        lastModified: f.lastModified,
        lastModifiedDate: f.lastModifiedDate,
        size: f.size,
        type: f.type,
        file: f,
        dispatch
      } );
      return [f.size, card];
    } ) );
    console.log(cards);

    dispatch( actions.uploadFiles( cards ) );
    for ( const k in cards ) {
      if ( cards.hasOwnProperty( k ) ) {
        cards[k].upload();
      }
    }
  },
  nameChange: ( file, e ) => {
    dispatch( actions.updateFile( file, { name: e.target.value } ) );
  },
  descriptionChange: ( file, e ) => {
    dispatch( actions.updateFile( file, { description: e.target.value } ) );
  }
} );

const Uploader = connect(
  mapStateToProps,
  mapDispatchToProps
)( DragDropContext( HTML5Backend )( DragDropZone ) );

export default Uploader;
