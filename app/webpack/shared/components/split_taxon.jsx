import React, { PropTypes } from "react";
import _ from "lodash";

const SplitTaxon = ( {
  taxon,
  url,
  target,
  noParens,
  placeholder,
  displayClassName,
  forceRank,
  showIcon,
  truncate,
  onClick,
  noInactive
} ) => {
  const LinkElement = url ? "a" : "span";
  let title = "";
  if ( taxon ) {
    if ( taxon.rank && taxon.rank_level > 10 ) {
      title += _.capitalize(
        I18n.t( `ranks.${taxon.rank.toLowerCase( )}`, { defaultValue: taxon.rank } )
      );
    }
    title += ` ${taxon.name}`;
    if ( taxon.preferred_common_name ) {
      title = `${taxon.preferred_common_name} (${_.trim( title )})`;
    }
  }
  const icon = ( ) => {
    if ( !showIcon ) {
      return null;
    }
    let iconClass = "icon icon-iconic-";
    if ( taxon && taxon.iconic_taxon_name ) {
      iconClass += taxon.iconic_taxon_name.toString( ).toLowerCase( );
    } else {
      iconClass += "unknown";
    }
    return <LinkElement href={ url } className={iconClass} />;
  };
  const taxonClass = ( ) => {
    let cssClass = "taxon";
    if ( taxon ) {
      cssClass += ` ${taxon.rank} ${taxon.iconic_taxon_name}`;
      if ( taxon.preferred_common_name ) {
        cssClass += " has-com-name";
      }
    } else {
      cssClass += " Unknown";
    }
    if ( noParens ) {
      cssClass += " no-parens";
    }
    return cssClass;
  };
  const truncateText = text => (
    truncate ? _.truncate( text, { length: truncate } ) : text
  );
  const displayName = ( ) => {
    if ( taxon && taxon.preferred_common_name ) {
      return (
        <LinkElement
          className={`comname display-name ${displayClassName || ""}`}
          href={ url }
          target={ target }
          onClick={ onClick }
        >
          { truncateText( taxon.preferred_common_name ) }
        </LinkElement>
      );
    } else if ( !taxon ) {
      if ( placeholder ) {
        return (
          <span>
            <LinkElement
              className={`noname display-name ${displayClassName || ""}`}
              href={ url }
              onClick={ onClick }
              target={ target }
            >
              { I18n.t( "unknown" ) }
            </LinkElement> <span className="altname">
              ({ I18n.t( "placeholder" ) }: { placeholder })
            </span>
          </span>
        );
      }
      return (
        <LinkElement
          className={`noname display-name ${displayClassName || ""}`}
          href={ url }
          onClick={ onClick }
          target={ target }
        >
          { I18n.t( "unknown" ) }
        </LinkElement>
      );
    }
    return null;
  };
  const sciName = ( ) => {
    if ( !taxon ) {
      return null;
    }
    let sciNameClass = `sciname ${taxon.rank}`;
    if ( !taxon.preferred_common_name ) {
      sciNameClass += ` display-name ${displayClassName || ""}`;
    }
    let name = taxon.name;
    if ( taxon.rank_level < 10 ) {
      const namePieces = name.split( " " );
      let rankPiece;
      if ( taxon.rank === "variety" ) {
        rankPiece = "var.";
      } else if ( taxon.rank === "subspecies" ) {
        rankPiece = "ssp.";
      } else if ( taxon.rank === "form" ) {
        rankPiece = "f.";
      }
      if ( rankPiece ) {
        name = (
          <span>
            {
              namePieces.slice( 0, namePieces.length - 1 ).join( " " )
            } <span className="rank">
              { rankPiece }
            </span> {
              namePieces[namePieces.length - 1]
            }
          </span>
        );
      }
    }
    if ( ( forceRank || taxon.preferred_common_name ) && taxon.rank && taxon.rank_level > 10 ) {
      return (
        <LinkElement
          className={sciNameClass}
          href={ url }
          onClick={ onClick }
          target={ target }
        >
          <span className="rank">
            { _.capitalize( I18n.t( `ranks.${taxon.rank.toLowerCase( )}`, { defaultValue: taxon.rank } ) ) }
          </span> { truncateText( name ) }
        </LinkElement>
      );
    }
    return (
      <LinkElement
        className={sciNameClass}
        href={ url }
        onClick={ onClick }
        target={ target }
      >
        { truncateText( name ) }
      </LinkElement>
    );
  };
  const inactive = ( ) => {
    if ( !taxon || taxon.is_active || noInactive ) {
      return null;
    }
    return (
      <span className="inactive">
        [
          <a
            href={`/taxon_changes?taxon_id=${taxon.id}`}
            target={ target }
          >
            { I18n.t( "inactive_taxon" ) }
          </a>
        ]
      </span>
    );
  };
  return (
    <span title={title} className={`SplitTaxon ${taxonClass( )}`}>
      { icon( ) } { displayName( ) } { sciName( ) } { inactive( ) }
    </span>
  );
};

SplitTaxon.propTypes = {
  taxon: PropTypes.object,
  url: PropTypes.string,
  target: PropTypes.string,
  noParens: PropTypes.bool,
  placeholder: PropTypes.string,
  displayClassName: PropTypes.string,
  forceRank: PropTypes.bool,
  showIcon: PropTypes.bool,
  truncate: PropTypes.number,
  onClick: PropTypes.func,
  noInactive: PropTypes.bool
};
SplitTaxon.defaultProps = {
  target: "_self"
};

export default SplitTaxon;
