import React from "react";
import PropTypes from "prop-types";
import TextEditor from "../../../shared/components/text_editor";

// The approach of getting the form values from the event object here is based
// on some feedback from DrMike in https://discord.gg/0ZcbPKXt5bZ6au5t. It's
// fine here, but it might be worth considering
// https://github.com/erikras/redux-form if this approach ends up getting
// complicated.

const CommentForm = ( {
  observation, onSubmitComment, className, content, key
} ) => (
  <form
    key={key}
    className={`CommentForm ${className}`}
    onSubmit={function ( e ) {
      e.preventDefault();
      onSubmitComment( {
        parent_type: "Observation",
        parent_id: observation.id,
        body: content
      } );
      content = null;
    }}
  >
    <h3>{ I18n.t( "add_a_comment" ) }</h3>
    <div className="form-group">
      <TextEditor
        content={content}
        key={`comment-editor-${observation.id}-${observation.comments.length}`}
        maxLength={5000}
        onBlur={e => { content = e.target.value; }}
        placeholder={I18n.t( "leave_a_comment" )}
        showCharsRemainingAt={4000}
        textareaClassName="form-control"
        mentions
      />
    </div>
    <button
      type="submit"
      className="btn btn-primary"
    >
      { I18n.t( "save" ) }
    </button>
  </form>
);

CommentForm.propTypes = {
  observation: PropTypes.object,
  onSubmitComment: PropTypes.func.isRequired,
  className: PropTypes.string,
  content: PropTypes.string,
  key: PropTypes.string
};

export default CommentForm;
