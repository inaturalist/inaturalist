import React from "react";
import PropTypes from "prop-types";
import TextEditor from "../../../shared/components/text_editor";

// The approach of getting the form values from the event object here is based
// on some feedback from DrMike in https://discord.gg/0ZcbPKXt5bZ6au5t. It's
// fine here, but it might be worth considering
// https://github.com/erikras/redux-form if this approach ends up getting
// complicated.

class CommentForm extends React.Component {
  shouldComponentUpdate( nextProps ) {
    const {
      observation, content, key, className
    } = this.props;
    if ( observation.id === nextProps.observation.id
      && className === nextProps.className
      && key === nextProps.key
      && content === nextProps.content ) {
      return false;
    }
    return true;
  }

  render( ) {
    const {
      config,
      observation,
      onSubmitComment,
      className,
      content,
      key,
      updateEditorContent
    } = this.props;
    return (
      <form
        key={key}
        className={`CommentForm ${className}`}
        onSubmit={function ( e ) {
          e.preventDefault();
          onSubmitComment( {
            parent_type: "Observation",
            parent_id: config.testingApiV2 ? observation.uuid : observation.id,
            body: content
          } );
        }}
      >
        <h3>{ I18n.t( "add_a_comment" ) }</h3>
        <div className="form-group">
          <TextEditor
            content={content}
            key={`comment-editor-${observation.id}`}
            maxLength={5000}
            onBlur={e => { updateEditorContent( "obsIdentifyIdComment", e.target.value ); }}
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
  }
}

CommentForm.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  onSubmitComment: PropTypes.func.isRequired,
  className: PropTypes.string,
  content: PropTypes.string,
  key: PropTypes.string,
  updateEditorContent: PropTypes.func
};

export default CommentForm;
