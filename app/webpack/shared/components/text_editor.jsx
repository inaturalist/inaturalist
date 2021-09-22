import React from "react";
import PropTypes from "prop-types";
import mousetrap from "mousetrap";
import ReactDOM from "react-dom";
import TextEditorFormatButton from "./text_editor_format_button";
import UserText from "./user_text";

class TextEditor extends React.Component {
  constructor( props, context ) {
    super( props, context );
    this.textarea = React.createRef();
    this.boldButton = React.createRef();
    this.italicButton = React.createRef();
    this.linkButton = React.createRef();
    this.state = {
      textareaChars: 0,
      preview: false,
      content: props.content
    };
  }

  componentDidMount( ) {
    const { mentions } = this.props;

    mousetrap( this.textarea.current ).bind( "mod+b", e => {
      e.preventDefault();
      this.boldButton.button.current.click( );
    } );
    mousetrap( this.textarea.current ).bind( "mod+i", e => {
      e.preventDefault();
      this.italicButton.button.current.click( );
    } );
    mousetrap( this.textarea.current ).bind( "mod+k", e => {
      e.preventDefault();
      this.linkButton.button.current.click( );
    } );

    if ( mentions ) {
      const domNode = ReactDOM.findDOMNode( this );
      $( this.textarea.current, domNode ).textcompleteUsers( );
    }
  }

  componentWillReceiveProps( props ) {
    this.setState( { content: props.content } );
  }

  componentDidUpdate( prevProps, prevState ) {
    const { changeHandler } = this.props;
    const { content } = this.state;
    if ( changeHandler && prevState.content !== content ) { changeHandler( content ); }
  }

  render( ) {
    const {
      maxLength,
      placeholder,
      className,
      textareaClassName,
      showCharsRemainingAt,
      onBlur
    } = this.props;
    const { preview, content } = this.state;
    const textareaChars = content ? content.length : 0;
    const textareaOnChange = e => {
      this.setState( { content: e.target.value } );
    };
    return (
      <div className={`TextEditor ${className} ${preview && "with-preview"}`}>
        { this.textarea && (
          <div className="btn-toolbar" role="toolbar" aria-label={I18n.t( "text_editing_controls" )}>
            <div className="btn-group format-controls" role="group" aria-label={I18n.t( "text_formatting_controls" )}>
              <TextEditorFormatButton
                textarea={this.textarea}
                textareaOnChange={val => { this.setState( { content: val } ); }}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-bold" />}
                template={text => `**${text}**`}
                placeholder={I18n.t( "bold_text" )}
                ref={button => { this.boldButton = button; }}
                newSelectionOffset={2}
                newSelectionOffsetLength={textLength => textLength}
                disabled={preview}
                tip={I18n.t( "add_bold_text" )}
              />
              <TextEditorFormatButton
                textarea={this.textarea}
                textareaOnChange={val => { this.setState( { content: val } ); }}
                className="btn btn-default btn-xs"
                label={<i className="fa fa-italic" />}
                template={text => `*${text}*`}
                placeholder={I18n.t( "italic_text" )}
                ref={button => { this.italicButton = button; }}
                newSelectionOffset={1}
                newSelectionOffsetLength={textLength => textLength}
                disabled={preview}
                tip={I18n.t( "add_italic_text" )}
              />
              <TextEditorFormatButton
                textarea={this.textarea}
                textareaOnChange={val => { this.setState( { content: val } ); }}
                className="btn btn-default btn-xs"
                label={<i className="icon-link" />}
                template={text => `[${text}](url)`}
                placeholder={I18n.t( "linked_text" )}
                ref={button => { this.linkButton = button; }}
                newSelectionOffset={textLength => textLength + 3}
                newSelectionOffsetLength={3}
                disabled={preview}
                tip={I18n.t( "add_a_link" )}
              />
            </div>
            <div className="btn-group block-controls" role="group" aria-label={I18n.t( "text_block_controls" )}>
              <TextEditorFormatButton
                textarea={this.textarea}
                textareaOnChange={val => { this.setState( { content: val } ); }}
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
                tip={I18n.t( "insert_a_quote" )}
              />
              <TextEditorFormatButton
                textarea={this.textarea}
                textareaOnChange={val => { this.setState( { content: val } ); }}
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
                tip={I18n.t( "add_a_bulleted_list" )}
              />
              <TextEditorFormatButton
                textarea={this.textarea}
                textareaOnChange={val => { this.setState( { content: val } ); }}
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
                tip={I18n.t( "add_a_numbered_list" )}
              />
            </div>
            <div className="btn-group pull-right" role="group" aria-label={I18n.t( "preview" )}>
              { preview ? (
                <button
                  type="button"
                  tabIndex="-1"
                  className="btn btn-primary btn-xs btn-edit"
                  onClick={( ) => this.setState( { preview: false } )}
                >
                  { I18n.t( "edit" ) }
                </button>
              ) : (
                <button
                  type="button"
                  tabIndex="-1"
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
          value={content || ""}
        />
        { maxLength && textareaChars > showCharsRemainingAt && (
          <div className="text-muted small chars-remaining">
            { I18n.t( "x_of_y_short", { x: textareaChars, y: maxLength } )}
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
  changeHandler: PropTypes.func,
  mentions: PropTypes.bool,
  className: PropTypes.string,
  textareaClassName: PropTypes.string,
  showCharsRemainingAt: PropTypes.number,
  onBlur: PropTypes.func
};

TextEditor.defaultProps = {
  showCharsRemainingAt: 0,
  mentions: false
};

export default TextEditor;
