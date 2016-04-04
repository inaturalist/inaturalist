// import { bindActionCreators } from "redux";
// import { connect } from "react-redux";
// import HTML5Backend from "react-dnd-html5-backend";
// import { DragDropContext } from "react-dnd";
// import SortableTable from "../components/sortable_table";
// import * as DragActions from "../actions/actions";

// function mapStateToProps( state ) {
//   return Object.assign( { }, state.table );
// }

// function mapDispatchToProps( dispatch ) {
//   return {
//     actions: bindActionCreators( DragActions, dispatch ),
//     moveCard: ( dragIndex, hoverIndex, dragCard ) => {
//       dispatch( DragActions.moveCard( dragIndex, hoverIndex, dragCard ) );
//     }
//   };
// }

// export default connect(
//   mapStateToProps,
//   mapDispatchToProps
// )( DragDropContext( HTML5Backend )( SortableTable ) );
