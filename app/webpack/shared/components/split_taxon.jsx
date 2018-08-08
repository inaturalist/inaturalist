import React from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import { objectToComparable } from "../util";

const SplitTaxon = props => {
  const {
    taxon,
    url,
    target,
    noParens,
    placeholder,
    displayClassName,
    showIcon,
    truncate,
    onClick,
    noInactive,
    showMemberGroup,
    user
  } = props;
  const showScinameFirst = user && user.prefers_scientific_name_first;
  const LinkElement = ( url || onClick ) ? "a" : "span";
  const keyBase = objectToComparable( props );
  let title = "";
  if ( taxon ) {
    if ( taxon.rank && taxon.rank_level > 10 ) {
      title += _.capitalize(
        I18n.t( `ranks.${taxon.rank.toLowerCase( )}`, { defaultValue: taxon.rank } )
      );
    }
    title += ` ${taxon.name}`;
    if ( taxon.preferred_common_name ) {
      if ( user && user.prefers_scientific_name_first ) {
        title = `${title} (${_.trim( taxon.preferred_common_name )})`;
      } else {
        title = `${taxon.preferred_common_name} (${_.trim( title )})`;
      }
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
    return <LinkElement key={ `${keyBase}-icon` }href={ url } className={iconClass} />;
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
    cssClass += noParens ? " no-parens" : " parens";
    return cssClass;
  };
  const truncateText = text => (
    truncate ? _.truncate( text, { length: truncate } ) : text
  );
  const comName = ( ) => {
    let comNameClass = displayClassName || "";
    const key = `${keyBase}-comName`;
    if ( taxon && taxon.preferred_common_name ) {
      if ( showScinameFirst ) {
        comNameClass = `secondary-name ${comNameClass}`;
      } else {
        comNameClass = `display-name ${comNameClass}`;
      }
      const commonName = iNatModels.Taxon.titleCaseName( taxon.preferred_common_name );
      return (
        <LinkElement
          key={ key }
          className={`comname ${comNameClass}`}
          href={ url }
          target={ target }
          onClick={ onClick }
        >{
          truncateText( commonName )
        }</LinkElement>
      );
    } else if ( !taxon ) {
      comNameClass = `noname display-name ${comNameClass}`;
      if ( placeholder ) {
        return (
          <span>
            <LinkElement
              key={ key }
              className={ comNameClass }
              href={ url }
              onClick={ onClick }
              target={ target }
            >{
              I18n.t( "unknown" )
            }</LinkElement> <span className="altname">
              ({ I18n.t( "placeholder" ) }: { placeholder })
            </span>
          </span>
        );
      }
      return (
        <LinkElement
          key={ key }
          className={ comNameClass }
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
    const key = `${keyBase}-sciName`;
    let sciNameClass = `sciname ${taxon.rank}`;
    if ( !taxon.preferred_common_name || showScinameFirst ) {
      sciNameClass += ` display-name ${displayClassName || ""}`;
    } else {
      sciNameClass += " secondary-name";
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
    // Maybe we don't really need forceRank...
    // if ( ( forceRank || taxon.preferred_common_name ) && taxon.rank && taxon.rank_level > 10 ) {
    if ( taxon.rank && taxon.rank_level > 10 ) {
      return (
        <LinkElement
          key={ key }
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
        key={ key }
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
      <span key={ `${keyBase}-inactive` } className="inactive">
        <a
          href={`/taxon_changes?taxon_id=${taxon.id}`}
          target={ target }
        >
          <i className="fa fa-exclamation-circle"></i> { _.startCase( I18n.t( "inactive_taxon" ) ) }
        </a>
      </span>
    );
  };
  const extinct = ( ) => {
    if ( !taxon || !taxon.extinct ) {
      return null;
    }
    return (
      <span key={ `${keyBase}-extinct` } className="extinct">
        [
          { I18n.t( "extinct" ) }
        ]
      </span>
    );
  };
  let memberGroup;
  // show "is member of" if requested and there's no common name
  const isBetweenGenusAndSpecies = taxon && taxon.rank_level < 20 && taxon.rank_level > 10;
  if (
    showMemberGroup &&
    taxon &&
    (
      ( !taxon.preferred_common_name && !_.isEmpty( taxon.ancestors ) ) ||
      isBetweenGenusAndSpecies
    )
  ) {
    let groupAncestor;
    if ( isBetweenGenusAndSpecies ) {
      groupAncestor = _.find( taxon.ancestors, a => a.rank === "genus" );
    } else {
      groupAncestor = _.head( _.reverse( _.filter( taxon.ancestors, a => (
        a.preferred_common_name && a.rank_level > 20
      ) ) ) );
    }
    if ( groupAncestor ) {
      memberGroup = (
        <span key={ `${keyBase}-memberGroup` }className="member-group">
          { I18n.t( "a_member_of" ) } <SplitTaxon
            taxon={ groupAncestor }
            forceRank
            url={ `/taxa/${groupAncestor.id}` }
            user={ user }
          />
        </span>
      );
    }
  }
  let firstName;
  let secondName;
  if ( showScinameFirst ) {
    firstName = sciName( );
    secondName = comName( );
  } else {
    firstName = comName( );
    secondName = sciName( );
  }
  const nodes = _.compact( [
    icon( ),
    firstName,
    secondName,
    inactive( ),
    extinct( ),
    memberGroup
  ] );
  return (
    <span title={title} className={`SplitTaxon ${taxonClass( )}`}>
      { _.flatten( _.map( nodes, ( n, i ) => ( i === 0 ? n : [" ", n] ) ) ) }
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
  noInactive: PropTypes.bool,
  showMemberGroup: PropTypes.bool,
  user: PropTypes.object
};
SplitTaxon.defaultProps = {
  target: "_self"
};

export default SplitTaxon;
