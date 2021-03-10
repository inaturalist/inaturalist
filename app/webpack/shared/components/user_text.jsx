import React from "react";
import PropTypes from "prop-types";
import safeHtml from "safe-html";
import htmlTruncate from "html-truncate";
import linkifyHtml from "linkifyjs/html";
import sanitizeHtml from "sanitize-html";
import MarkdownIt from "markdown-it";

const ALLOWED_TAGS = ( `
  a
  abbr
  acronym
  b
  blockquote
  br
  cite
  code
  del
  div
  dl
  dt
  em
  h1
  h2
  h3
  h4
  h5
  h6
  hr
  i
  img
  ins
  li
  ol
  p
  pre
  s
  small
  strike
  strong
  sub
  sup
  table
  tbody
  td
  t
  th
  thead
  tr
  tt
  ul
` ).split( /\s+/m );

const ALLOWED_ATTRIBUTES_NAMES = (
  "href src width height alt cite title class name abbr value align target rel"
  // + "xml:lang style controls preload"
).split( " " );

const ALLOWED_ATTRIBUTES = {
  href: {
    allowedTags: ["a"],
    filter: value => {
      // Only let through http urls
      if ( /^https?:/i.exec( value ) ) {
        return value;
      }
      return false;
    }
  }
};
for ( let i = 0; i < ALLOWED_ATTRIBUTES_NAMES.length; i += 1 ) {
  ALLOWED_ATTRIBUTES[ALLOWED_ATTRIBUTES_NAMES[i]] = { allTags: true };
}

const CONFIG = {
  allowedTags: ALLOWED_TAGS,
  allowedAttributes: ALLOWED_ATTRIBUTES
};

class UserText extends React.Component {
  // Imperfect solution until we can get an API endpoint to check for the existence of these users
  static hyperlinkMentions( text ) {
    return text.replace( /(\B)@([A-z][\\\w\\\-_]*)/g, "$1<a href=\"/people/$2\">@$2</a>" );
  }

  constructor( ) {
    super( );
    this.state = {
      more: false
    };
  }

  toggle( ) {
    const { more } = this.state;
    this.setState( { more: !more } );
  }

  render( ) {
    const {
      text,
      truncate,
      config,
      moreToggle,
      stripTags,
      stripWhitespace,
      className,
      markdown
    } = this.props;
    const { more } = this.state;
    if ( !text || text.length === 0 ) {
      return <div className={`UserText ${className}`} />;
    }
    let html = text;
    // replace ampersands in URL params with entities so they don't get
    // interpretted by safeHtml
    html = html.replace( /&(\w+=)/g, "&amp;$1" );
    if ( markdown ) {
      const md = new MarkdownIt( {
        html: true,
        breaks: true
      } );
      md.renderer.rules.table_open = ( ) => "<table class=\"table\">\n";
      if ( truncate && !more ) {
        html = md.renderInline( html );
      } else {
        html = md.render( html );
      }
    } else {
      // use BRs for newlines
      html = text.trim( ).replace( /\n/gm, "<br />" );
    }
    html = safeHtml( UserText.hyperlinkMentions( html ), config || CONFIG );
    if ( stripTags ) {
      html = sanitizeHtml( html, { allowedTags: [], allowedAttributes: {} } );
    }
    let truncatedHtml;
    if ( truncate && truncate > 0 && !more ) {
      truncatedHtml = htmlTruncate( html, truncate );
    }
    let moreLink;
    if ( truncate && ( truncatedHtml !== html ) && moreToggle ) {
      moreLink = (
        <button
          type="button"
          onClick={( ) => {
            this.toggle( );
            return false;
          }}
          className={`btn btn-nostyle linky ${truncate && truncate > 0 ? "more" : "collapse"}`}
        >
          { more ? I18n.t( "less" ) : I18n.t( "more" ) }
        </button>
      );
    }
    let htmlToDisplay = truncatedHtml || html;
    if ( !stripTags ) {
      const sanitizedHtml = sanitizeHtml(
        truncatedHtml || html,
        {
          allowedTags: ALLOWED_TAGS,
          allowedAttributes: { "*": ALLOWED_ATTRIBUTES_NAMES },
          exclusiveFilter: stripWhitespace && ( frame => ( frame.tag === "a" && !frame.text.trim( ) ) )
        }
      );
      // Note: markdown-it has a linkifier option too, but it does not allow you
      // to specify attributes link nofollow, so we're using linkifyjs, but we are
      // ignoring URLs in the existing tags that might have them like a and code
      const linkifiedHtml = linkifyHtml( sanitizedHtml, {
        className: null,
        attributes: { rel: "nofollow" },
        ignoreTags: ["a", "code", "pre"]
      } );
      htmlToDisplay = linkifiedHtml;
    }
    if ( stripWhitespace ) {
      htmlToDisplay = htmlToDisplay.trim( ).replace( /^(<br *\/?>\s*)+/, "" );
    }
    return (
      <div className={`UserText ${className}`}>
        <span
          className="content"
          dangerouslySetInnerHTML={{ __html: htmlToDisplay }}
        />
        { " " }
        { moreLink }
      </div>
    );
  }
}

UserText.propTypes = {
  text: PropTypes.string,
  truncate: PropTypes.number,
  config: PropTypes.object,
  className: PropTypes.string,
  moreToggle: PropTypes.bool,
  stripTags: PropTypes.bool,
  stripWhitespace: PropTypes.bool,
  markdown: PropTypes.bool
};

UserText.defaultProps = {
  className: "",
  moreToggle: true,
  markdown: true
};

export default UserText;
