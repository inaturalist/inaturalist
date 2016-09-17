import React, { PropTypes } from "react";
import _ from "lodash";

const SplitTaxon = ( {
  taxon,
  url,
  target,
  noParens,
  placeholder,
  displayClassName,
  forceRank
} ) => {
  const LinkElement = url ? "a" : "span";
  let title = "";
  if ( taxon ) {
    if ( taxon.rank_level > 10 ) {
      title += _.capitalize( taxon.rank );
    }
    title += ` ${taxon.name}`;
    if ( taxon.preferred_common_name ) {
      title = `${taxon.preferred_common_name} (${title})`;
    }
  }
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
  const iconClass = ( ) => {
    let cssClass = "icon icon-iconic-";
    if ( taxon ) {
      cssClass += taxon.iconic_taxon_name;
    } else {
      cssClass += "unknown";
    }
  };
  const displayName = ( ) => {
    if ( taxon && taxon.preferred_common_name ) {
      return (
        <LinkElement
          className={`comname display-name ${displayClassName || ""}`}
          href={ url }
          target={ target }
        >
          { taxon.preferred_common_name }
        </LinkElement>
      );
    } else if ( !taxon ) {
      if ( placeholder ) {
        return (
          <span>
            <LinkElement
              className={`noname display-name ${displayClassName || ""}`}
              href={ url }
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
          target={ target }
        >
          { I18n.t( "unknown" ) }
        </LinkElement>
      );
    }
    return "";
  };
  const sciName = ( ) => {
    if ( !taxon ) {
      return "";
    }
    const taxonRank = ( ) => {
      if ( ( forceRank || taxon.preferred_common_name ) && taxon.rank_level > 10 ) {
        return (
          <span className="rank">
            { _.capitalize( taxon.rank ) }
          </span>
        );
      }
      return "";
    };
    let sciNameClass = `sciname ${taxon.rank}`;
    if ( !taxon.preferred_common_name ) {
      sciNameClass += ` display-name ${displayClassName || ""}`;
    }
    return (
      <LinkElement
        className={sciNameClass}
        href={ url }
        target={ target }
      >
        { taxonRank( ) }
        { taxon.name }
      </LinkElement>
    );
  };
  const inactive = ( ) => {
    if ( !taxon || taxon.is_active ) {
      return "";
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
    <div className="SplitTaxon" title={title}>
      <span className={taxonClass( )}>
        <LinkElement
          href={ url }
          className={iconClass( )}
        />
        { displayName( ) } { sciName( ) } { inactive( ) }
      </span>
    </div>
  );
};

SplitTaxon.propTypes = {
  taxon: PropTypes.object,
  url: PropTypes.string,
  target: PropTypes.string,
  noParens: PropTypes.bool,
  placeholder: PropTypes.string,
  displayClassName: PropTypes.string,
  forceRank: PropTypes.bool
};
SplitTaxon.defaultProps = {
  target: "_self"
};

export default SplitTaxon;
