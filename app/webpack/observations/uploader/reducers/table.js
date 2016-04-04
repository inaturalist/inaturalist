// import * as types from "../constants/constants";

// const initialState = {
//   cards: [{
//     id: 1,
//     text: "Write a cool JS library"
//   }, {
//     id: 2,
//     text: "Make it generic enough"
//   }, {
//     id: 3,
//     text: "Write README"
//   }, {
//     id: 4,
//     text: "Create some examples"
//   }, {
//     id: 5,
//     text: "Spam in Twitter and IRC to promote it (note that this element is taller than the others)"
//   }, {
//     id: 6,
//     text: "???"
//   }, {
//     id: 7,
//     text: "PROFIT"
//   }]
// };

// const table = ( state = initialState, action ) => {
//   switch ( action.type ) {
//     case types.MOVE_CARD: {
//       const cards = state.cards.concat( [] );
//       const dragCard = cards[action.dragIndex];
//       cards.splice( action.dragIndex, 1 );
//       cards.splice( action.hoverIndex, 0, dragCard );
//       return Object.assign( { }, state, { cards } );
//     }
//     default:
//       return state;
//   }
// };

// export default table;
