import React, { PropTypes } from "react";
import safeHtml from "safe-html";
import htmlTruncate from "html-truncate";

const ALLOWED_TAGS = (
  "div a abbr acronym b blockquote br cite code dl dt em h1 h2 h3 h4 h5 h6 hr i"
  + " img li ol p pre s small strike strong sub sup tt ul"
  // + "table tr td th"
  // + "audio source embed iframe object param"
).split( " " );

const ALLOWED_ATTRIBUTES_NAMES = (
  "href src width height alt cite title class name abbr value align"
  // + "xml:lang style controls preload"
).split( " " );

const ALLOWED_ATTRIBUTES = {
  href: {
    allowedTags: ["a"],
    filter: ( value ) => {
      // Only let through http urls
      if ( /^https?:/i.exec( value ) ) {
        return value;
      }
      return false;
    }
  }
};
for ( let i = 0; i < ALLOWED_ATTRIBUTES_NAMES.length; i++ ) {
  ALLOWED_ATTRIBUTES[ALLOWED_ATTRIBUTES_NAMES[i]] = { allTags: true };
}

const CONFIG = {
  allowedTags: ALLOWED_TAGS,
  allowedAttributes: ALLOWED_ATTRIBUTES
};

class UserText extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      more: false
    };
  }

  toggle( ) {
    this.setState( { more: !this.state.more } );
  }

  // Imperfect solution until we can get an API endpoint to check for the existence of these users
  hyperlinkMentions( text ) {
    return text.replace( /(\B)@([\\\w][\\\w\\\-_]*)/g, "$1<a href=\"/people/$2\">@$2</a>" );
  }

  render( ) {
    const { text, truncate, config } = this.props;
    let { className } = Object.assign( { }, this.props );
    if ( !text || text.length === 0 ) {
      return <div className={`UserText ${className}`}></div>;
    }
    const html = safeHtml( this.hyperlinkMentions( text ), config || CONFIG );
    let truncatedHtml;
    const style = {
      transition: "height 2s",
      overflow: "hidden"
    };
    if ( truncate && truncate > 0 && !this.state.more ) {
      truncatedHtml = htmlTruncate( html, truncate );
      if ( truncatedHtml !== html ) {
        className += " truncated";
      }
    }
    let moreLink;
    if ( truncate && ( truncatedHtml !== html ) ) {
      moreLink = (
        <a
          onClick={ ( ) => {
            this.toggle( );
            return false;
          } }
          className={truncate && truncate > 0 ? "" : "collapse"}
        >
          { this.state.more ? I18n.t( "less" ) : I18n.t( "more" ) }
        </a>
      );
    }
    return (
      <div className={`UserText ${className}`}>
        <div
          className="content"
          dangerouslySetInnerHTML={ { __html: ( truncatedHtml || html ) } }
          style={style}
        ></div>
        { moreLink }
      </div>
    );
  }
}

UserText.propTypes = {
  text: PropTypes.string,
  truncate: PropTypes.number,
  config: PropTypes.object,
  className: PropTypes.string
};

export default UserText;
