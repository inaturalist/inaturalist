const UPDATE_EDITOR_CONTENT = "update_editor_content";

const textEditorReducer = ( state = { content: "" }, action ) => {
  if ( action.type === UPDATE_EDITOR_CONTENT ) {
    return Object.assign( {}, state, { content: action.content } );
  }
  return state;
};

const updateEditorContent = content => ( { type: UPDATE_EDITOR_CONTENT, content } );

export default textEditorReducer;
export {
  UPDATE_EDITOR_CONTENT,
  updateEditorContent
};
