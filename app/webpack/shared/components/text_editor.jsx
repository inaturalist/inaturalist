import React from "react";
import PropTypes from "prop-types";
import TextEditorFormatButton from "./text_editor_format_button";
import UserText from "./user_text";

class TextEditor extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.textarea = React.createRef();
    this.state = {
      textareaChars: 0,
      preview: false
    };
  }

  render( ) {
    const {
      content,
      maxLength,
      placeholder,
      className,
      textareaClassName,
      showCharsRemainingAt,
      onBlur
    } = this.props;
    const { textareaChars, preview } = this.state;
    let textareaOnChange;
    if ( maxLength ) {
      textareaOnChange = e => {
        if ( e.target.value.length > showCharsRemainingAt ) {
          this.setState( { textareaChars: e.target.value.length } );
        }
      };
    }
    return (
      <div className={`TextEditor ${className} ${preview && "with-preview"}`}>
        { this.textarea && this.textarea.current && (
          <div className="btn-toolbar" role="toolbar" aria-label={I18n.t( "text_editing_controls" )}>
            <div className="btn-group format-controls" role="group" aria-label={I18n.t( "text_formatting_controls" )}>
              <TextEditorFormatButton
                textarea={this.textarea.current}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-bold" />}
                template={text => `**${text}**`}
                placeholder={I18n.t( "bold_text", { defaultValue: "bold text" } )}
                newSelectionOffset={2}
                newSelectionOffsetLength={textLength => textLength}
                disabled={preview}
              />
              <TextEditorFormatButton
                textarea={this.textarea.current}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-italic" />}
                template={text => `*${text}*`}
                placeholder={I18n.t( "italic_text", { defaultValue: "italic text" } )}
                newSelectionOffset={1}
                newSelectionOffsetLength={textLength => textLength}
                disabled={preview}
              />
              <TextEditorFormatButton
                textarea={this.textarea.current}
                className="btn btn-default btn-xs"
                label={<i className="icon-link" />}
                template={text => `[${text}](url)`}
                placeholder={I18n.t( "linked_text", { defaultValue: "linked text" } )}
                newSelectionOffset={textLength => textLength + 3}
                newSelectionOffsetLength={3}
                disabled={preview}
              />
            </div>
            <div className="btn-group block-controls" role="group" aria-label={I18n.t( "text_block_controls" )}>
              <TextEditorFormatButton
                textarea={this.textarea.current}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-quote-right" />}
                template={( text, prevTxt ) => {
                  const newTxt = text.toString( ).split( "\n" ).map( line => `> ${line}` ).join( "\n" );
                  if ( prevTxt === "" || prevTxt.slice( prevTxt.length - 2 ) === "\n\n" ) {
                    return newTxt;
                  }
                  if ( prevTxt[prevTxt.length - 1] === "\n" ) {
                    return `\n${newTxt}`;
                  }
                  return `\n\n${newTxt}`;
                }}
                disabled={preview}
              />
              <TextEditorFormatButton
                textarea={this.textarea.current}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-list-ul" />}
                template={( text, prevTxt ) => {
                  const newTxt = text.toString( ).split( "\n" ).map( line => `* ${line}` ).join( "\n" );
                  if ( prevTxt === "" || prevTxt.slice( prevTxt.length - 2 ) === "\n\n" ) {
                    return newTxt;
                  }
                  if ( prevTxt[prevTxt.length - 1] === "\n" ) {
                    return `\n${newTxt}`;
                  }
                  return `\n\n${newTxt}`;
                }}
                disabled={preview}
              />
              <TextEditorFormatButton
                textarea={this.textarea.current}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-list-ol" />}
                template={( text, prevTxt ) => {
                  const newTxt = text.toString( ).split( "\n" ).map( line => `1. ${line}` ).join( "\n" );
                  if ( prevTxt === "" || prevTxt.slice( prevTxt.length - 2 ) === "\n\n" ) {
                    return newTxt;
                  }
                  if ( prevTxt[prevTxt.length - 1] === "\n" ) {
                    return `\n${newTxt}`;
                  }
                  return `\n\n${newTxt}`;
                }}
                disabled={preview}
              />
            </div>
            <div className="btn-group" role="group" aria-label={I18n.t( "preview" )}>
              { preview ? (
                <button
                  type="button"
                  className="btn btn-primary btn-xs btn-edit"
                  onClick={( ) => this.setState( { preview: false } )}
                >
                  { I18n.t( "edit" ) }
                </button>
              ) : (
                <button
                  type="button"
                  className="btn btn-default btn-xs btn-preview"
                  onClick={( ) => this.setState( { preview: true } )}
                >
                  { I18n.t( "preview" ) }
                </button>
              ) }
            </div>
          </div>
        ) }
        <textarea
          ref={this.textarea}
          className={textareaClassName}
          maxLength={maxLength}
          placeholder={placeholder}
          onChange={textareaOnChange}
          onBlur={onBlur}
        >
          { content }
        </textarea>
        { maxLength && textareaChars > showCharsRemainingAt && (
          <div className="text-muted small chars-remaining">
            { `${textareaChars} / ${maxLength}` }
          </div>
        ) }
        { preview && (
          <UserText
            className="preview"
            text={this.textarea.current.value}
            markdown
          />
        ) }
      </div>
    );
  }
}

TextEditor.propTypes = {
  maxLength: PropTypes.number,
  content: PropTypes.string,
  placeholder: PropTypes.string,
  className: PropTypes.string,
  textareaClassName: PropTypes.string,
  showCharsRemainingAt: PropTypes.number,
  onBlur: PropTypes.func
};

TextEditor.defaultProps = {
  showCharsRemainingAt: 0
};

export default TextEditor;
