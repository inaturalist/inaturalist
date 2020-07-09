import React from "react";
import PropTypes from "prop-types";

class TextEditorFormatButton extends React.Component {
  constructor(props, context) {
    super(props, context);
    this.button = React.createRef();
  };

  render( ) {
    const {
      textarea,
      label,
      template,
      className,
      newSelectionOffset,
      newSelectionOffsetLength,
      disabled,
      placeholder,
      tip
    } = this.props;
    return (
      <button
        type="button"
        tabIndex="-1"
        className={className}
        disabled={disabled}
        title={tip}
        aria-label={tip}
        ref={this.button}
        onClick={() => {
          const {selectionStart} = textarea;
          if (textarea.selectionStart !== undefined && textarea.selectionEnd !== undefined) {
            let selection = textarea.value.substring(
              textarea.selectionStart,
              textarea.selectionEnd
            );
            if (selection.length === 0 && placeholder) {
              selection = placeholder;
            }
            const selectionWithMarkup = template(
              selection,
              textarea.value.substring(0, textarea.selectionStart)
            );
            const newSelectionOffsetVal = typeof (newSelectionOffset) === "function"
              ? newSelectionOffset(selection.length)
              : newSelectionOffset;
            const newSelectionOffsetLengthVal = typeof (newSelectionOffsetLength) === "function"
              ? newSelectionOffsetLength(selection.length)
              : newSelectionOffsetLength;
            textarea.value = textarea.value.substring(0, textarea.selectionStart)
              + selectionWithMarkup
              + textarea.value.substring(textarea.selectionEnd, textarea.value.length);
            const rangeStart = selectionStart + newSelectionOffsetVal;
            const rangeEnd = selectionStart
              + newSelectionOffsetVal
              + (
                newSelectionOffsetLengthVal === undefined
                  ? selectionWithMarkup.length
                  : newSelectionOffsetLengthVal
              );
            textarea.setSelectionRange(rangeStart, rangeEnd);
          }
          textarea.focus();
        }}
      >
        {label}
      </button>
    );
  };
}

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

  disabled: PropTypes.bool,

  // Text inserted into the textarea when the button is clicked but no text was
  // selected
  placeholder: PropTypes.string,

  // title and aria-label attributes for the button. Should tell the user what
  // clicking this button does
  tip: PropTypes.string
};

TextEditorFormatButton.defaultProps = {
  newSelectionOffset: 0
};

export default TextEditorFormatButton;
