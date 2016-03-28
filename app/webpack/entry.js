console.log("[DEBUG] entry loaded");
import React from 'react';
import ReactDOM from 'react-dom';
import App from './test';
console.log("[DEBUG] document.getElementById('app'): ", document.getElementById('app'))
ReactDOM.render(<App />, document.getElementById('app'));

var CommentBox = React.createClass({
  render: function() {
    return (
      <div className="commentBox">
        Hello, world! I am a CommentBox.
      </div>
    );
  }
});
ReactDOM.render(
  <CommentBox />,
  document.getElementById('content')
);
