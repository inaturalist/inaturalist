import React, { PropTypes } from "react";
import _ from "lodash";

const SplitTaxon = ( { taxon, url, noParens } ) => {
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
  const commonName = ( ) => {
    if ( taxon && taxon.preferred_common_name ) {
      return (
        <a
          className="comname display-name"
          href={ url }
          target="_self"
        >
          { taxon.preferred_common_name }
        </a>
      );
    } else if ( !taxon ) {
      return (
        <a
          className="noname display-name"
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
    return (
      <a
        className={`sciname ${taxon.rank} ${taxon.preferred_common_name ? "" : "display-name"}`}
        href={ url }
        target="_self"
      >
        { taxonRank( ) }
        { taxon.name }
      </a>
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
        { commonName( ) } { sciName( ) }
      </span>
    </div>
  );
};

SplitTaxon.propTypes = {
  taxon: PropTypes.object,
  url: PropTypes.string,
  noParens: PropTypes.bool
};

export default SplitTaxon;
