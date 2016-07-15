import React, { PropTypes } from "react";
import _ from "lodash";

const SplitTaxon = ( { taxon, url, noParens, placeholder, displayClassName } ) => {
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
        <a
          className={`comname display-name ${displayClassName || ""}`}
          href={ url }
          target="_self"
        >
          { taxon.preferred_common_name }
        </a>
      );
    } else if ( !taxon ) {
      if ( placeholder ) {
        return (
          <span>
            <a
              className={`noname display-name ${displayClassName || ""}`}
              href={ url }
              target="_self"
            >
              { I18n.t( "unknown" ) }
            </a> <span className="altname">
              ({ I18n.t( "placeholder" ) }: { placeholder })
            </span>
          </span>
        );
      }
      return (
        <a
          className={`noname display-name ${displayClassName || ""}`}
          href={ url }
          target="_self"
        >
          { I18n.t( "unknown" ) }
        </a>
      );
    }
    return "";
  };
  const sciName = ( ) => {
    if ( !taxon ) {
      return "";
    }
    const taxonRank = ( ) => {
      if ( taxon.preferred_common_name && taxon.rank_level > 10 ) {
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
      <a
        className={sciNameClass}
        href={ url }
        target="_self"
      >
        { taxonRank( ) }
        { taxon.name }
      </a>
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
            target="_blank"
          >
            { I18n.t( "inactive_taxon" ) }
          </a>
        ]
      </span>
    );
  };
  return (
    <div className="SplitTaxon">
      <span className={taxonClass( )}>
        <a
          href={ url }
          className={iconClass( )}
        >
        </a>
        { displayName( ) } { sciName( ) } { inactive( ) }
      </span>
    </div>
  );
};

SplitTaxon.propTypes = {
  taxon: PropTypes.object,
  url: PropTypes.string,
  noParens: PropTypes.bool,
  placeholder: PropTypes.string,
  displayClassName: PropTypes.string
};

export default SplitTaxon;
