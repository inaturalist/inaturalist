import React from "react";
import PropTypes from "prop-types";

const TextEditorFormatButton = ( {
  textarea,
  label,
  template,
  className,
  newSelectionOffset,
  newSelectionOffsetLength,
  disabled
} ) => (
  <button
    type="button"
    className={className}
    disabled={disabled}
    onClick={( ) => {
      const { selectionStart } = textarea;
      if ( textarea.selectionStart !== undefined && textarea.selectionEnd !== undefined ) {
        const selection = textarea.value.substring(
          textarea.selectionStart,
          textarea.selectionEnd
        );
        const selectionWithMarkup = template(
          selection,
          textarea.value.substring( 0, textarea.selectionStart )
        );
        const newSelectionOffsetVal = typeof ( newSelectionOffset ) === "function"
          ? newSelectionOffset( selection.length )
          : newSelectionOffset;
        const newSelectionOffsetLengthVal = typeof ( newSelectionOffsetLength ) === "function"
          ? newSelectionOffsetLength( selection.length )
          : newSelectionOffsetLength;
        textarea.value = textarea.value.substring( 0, textarea.selectionStart )
          + selectionWithMarkup
          + textarea.value.substring( textarea.selectionEnd, textarea.value.length );
        const rangeStart = selectionStart + newSelectionOffsetVal;
        console.log( "[DEBUG] rangeStart: ", rangeStart );
        const rangeEnd = selectionStart
          + newSelectionOffsetVal
          + ( newSelectionOffsetLengthVal === undefined ? selectionWithMarkup.length : newSelectionOffsetLengthVal );
        console.log( "[DEBUG] newSelectionOffsetLengthVal: ", newSelectionOffsetLengthVal );
        console.log( "[DEBUG] selectionWithMarkup.length: ", selectionWithMarkup.length );
        console.log( "[DEBUG] rangeEnd: ", rangeEnd );
        textarea.setSelectionRange( rangeStart, rangeEnd );
      }
      textarea.focus( );
    }}
  >
    { label }
  </button>
);

TextEditorFormatButton.propTypes = {
  textarea: PropTypes.object.isRequired,
  label: PropTypes.oneOfType( [PropTypes.string, PropTypes.element] ).isRequired,
  template: PropTypes.func.isRequired,
  className: PropTypes.string,

  // Start position of the newly selected text relative to the start of the
  // originally selected text
  newSelectionOffset: PropTypes.oneOfType( [PropTypes.number, PropTypes.func] ),

  // Function that accepts the length of the selected text and returns the
  // length of the new selection
  newSelectionOffsetLength: PropTypes.oneOfType( [PropTypes.number, PropTypes.func] ),

  disabled: PropTypes.bool
};

TextEditorFormatButton.defaultProps = {
  newSelectionOffset: 0
};

export default TextEditorFormatButton;
