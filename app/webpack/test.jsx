'use strict';
// require('react');
// // let square = x => x * x;
// // console.log(square(5));

// // class TestClass {
// //   constructor() {
// //     console.log("[DEBUG] new TestClass instantiated")
// //   }
// // }
// // module.exports = TestClass;
// var CommentBox = React.createClass({
//   render: function() {
//     return (
//       <div className="commentBox">
//         Hello, world! I am a CommentBox.
//       </div>
//     );
//   }
// });
// ReactDOM.render(
//   <CommentBox />,
//   document.getElementById('content')
// );
import React from 'react';
// import Note from './Note.jsx';

// export default class App extends React.Component {
//   render() {
//     // return <Note />;
//     console.log("[DEBUG] rendering app");
//     return '<strong>App loaded</strong>';
//   }
// }
export default() => <strong>App loaded</strong>;