import React, { PropTypes } from "react";
import { Button } from "react-bootstrap";

// The approach of getting the form values from the event object here is based
// on some feedback from DrMike in https://discord.gg/0ZcbPKXt5bZ6au5t. It's
// fine here, but it might be worth considering
// https://github.com/erikras/redux-form if this approach ends up getting
// complicated.

const CommentForm = ( { observation, onSubmitComment } ) => (
  <form
    onSubmit={function ( e ) {
      e.preventDefault();
      onSubmitComment( {
        parent_type: "Observation",
        parent_id: observation.id,
        body: e.target.elements.body.value
      } );
    }}
  >
    <h2>Add a Comment</h2>
    <textarea name="body" className="form-control"></textarea>
    <Button type="submit">Save</Button>
  </form>
);

CommentForm.propTypes = {
  observation: PropTypes.object,
  onSubmitComment: PropTypes.func.isRequired
};

export default CommentForm;
