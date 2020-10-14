const UPDATE_EDITOR_CONTENT = "update_editor_content";

const textEditorReducer = ( state = {}, action ) => {
  if ( action.type === UPDATE_EDITOR_CONTENT ) {
    return Object.assign( {}, state, { [action.editor]: action.content } );
  }
  return state;
};

const updateEditorContent = ( editor, content ) => (
  { type: UPDATE_EDITOR_CONTENT, editor, content }
);

export default textEditorReducer;
export {
  UPDATE_EDITOR_CONTENT,
  updateEditorContent
};
