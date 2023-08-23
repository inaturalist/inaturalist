import React from "react";
import ReactDOMServer from "react-dom/server";
import PropTypes from "prop-types";
import _ from "lodash";
import { objectToComparable } from "../util";

class SplitTaxon extends React.Component {
  constructor( ) {
    super( );
    this.keyBase = objectToComparable( this.props );
  }

  LinkElement( ) {
    const { url, onClick } = this.props;
    return ( url || onClick ) ? "a" : "span";
  }

  truncateText( text ) {
    const { truncate } = this.props;
    return truncate ? _.truncate( text, { length: truncate } ) : text;
  }

  showScinameFirst( ) {
    const { sciFirst, user } = this.props;
    return sciFirst || ( user && user.prefers_scientific_name_first );
  }

  icon( ) {
    const { taxon, showIcon, url } = this.props;
    if ( !showIcon ) {
      return null;
    }
    let iconClass = "icon icon-iconic-";
    if ( taxon && taxon.iconic_taxon_name ) {
      iconClass += taxon.iconic_taxon_name.toString( ).toLowerCase( );
    } else {
      iconClass += "unknown";
    }
    const LinkElement = this.LinkElement( );
    return <LinkElement key={`${this.keyBase}-icon`} href={url} className={iconClass} />;
  }

  taxonClass( ) {
    const { taxon, noParens } = this.props;
    let cssClass = "taxon";
    if ( taxon ) {
      cssClass += ` ${taxon.rank} ${taxon.iconic_taxon_name}`;
      if ( !_.isEmpty( taxon.preferred_common_names ) || taxon.preferred_common_name ) {
        cssClass += " has-com-name";
      }
    } else {
      cssClass += " Unknown";
    }
    cssClass += noParens ? " no-parens" : " parens";
    return cssClass;
  }

  title( ) {
    const { taxon, user } = this.props;
    let title = "";
    if ( taxon ) {
      title = taxon.name;
      if ( taxon.rank && taxon.rank_level > 10 ) {
        title = I18n.t( "rank_sciname", {
          rank: I18n.t( `ranks.${taxon.rank.toLowerCase( )}` ),
          name: taxon.name
        } );
      }
      if ( !_.isEmpty( taxon.preferred_common_names ) ) {
        const commonNames = _.map( taxon.preferred_common_names, preferredCommonName => (
          _.trim( iNatModels.Taxon.titleCaseName( preferredCommonName.name ) ) ) );
        if ( user && user.prefers_scientific_name_first ) {
          return `${title} (${commonNames.join( " · " )})`;
        }
        return `${commonNames.join( " · " )} (${_.trim( title )})`;
      }
      if ( taxon.preferred_common_name ) {
        const comName = iNatModels.Taxon.titleCaseName( taxon.preferred_common_name );
        if ( user && user.prefers_scientific_name_first ) {
          return `${title} (${_.trim( comName )})`;
        }
        return `${comName} (${_.trim( title )})`;
      }
    }
    return title;
  }

  placeholderName( ) {
    const {
      displayClassName,
      placeholder,
      url,
      onClick,
      target
    } = this.props;
    const key = `${this.keyBase}-comName`;
    const LinkElement = this.LinkElement( );
    let nameClass = displayClassName || "";
    nameClass = `noname display-name ${nameClass}`;
    return (
      <span key={key}>
        <LinkElement
          className={nameClass}
          href={url}
          onClick={onClick}
          target={target}
        >
          { I18n.t( "unknown" ) }
        </LinkElement>
        { " " }
        <span className="altname">
          { "(" }
          { I18n.t( "label_colon", { label: I18n.t( "placeholder" ) } ) }
          { " " }
          { placeholder }
          { ")" }
        </span>
      </span>
    );
  }

  unknownName( ) {
    const {
      displayClassName,
      url,
      onClick,
      target
    } = this.props;
    const key = `${this.keyBase}-comName`;
    const LinkElement = this.LinkElement( );
    let nameClass = displayClassName || "";
    nameClass = `noname display-name ${nameClass}`;
    return (
      <LinkElement
        key={key}
        className={nameClass}
        href={url}
        onClick={onClick}
        target={target}
      >
        { I18n.t( "unknown" ) }
      </LinkElement>
    );
  }

  comNames( ) {
    const { taxon, placeholder } = this.props;
    if ( !taxon ) {
      if ( placeholder ) {
        return this.placeholderName( );
      }
      return this.unknownName( );
    }
    if ( !_.isEmpty( taxon.preferred_common_names ) ) {
      const comNamesClass = this.showScinameFirst( ) ? "secondary-names" : "display-names";
      let comNames = _.map( taxon.preferred_common_names, ( preferredCommonName, index ) => (
        this.comName( preferredCommonName.name, index )
      ) );
      comNames = comNames.reduce( ( prev, curr ) => [prev, " · ", curr] );
      return (
        <span key="comnames" className={`comname ${comNamesClass}`}>
          {comNames}
        </span>
      );
    }
    if ( taxon.preferred_common_name ) {
      return this.comName( taxon.preferred_common_name );
    }
    return null;
  }

  comName( displayCommonName, index = 0 ) {
    const {
      displayClassName,
      url,
      target,
      onClick
    } = this.props;
    let comNameClass = displayClassName || "";
    const LinkElement = this.LinkElement( );
    const key = `${this.keyBase}-comName-${index}`;
    if ( this.showScinameFirst( ) ) {
      comNameClass = `secondary-name ${comNameClass}`;
    } else {
      comNameClass = `display-name ${comNameClass}`;
    }
    const commonName = iNatModels.Taxon.titleCaseName( displayCommonName );
    return (
      <LinkElement
        key={key}
        className={`comname ${comNameClass}`}
        href={url}
        target={target}
        onClick={onClick}
      >
        { this.truncateText( commonName ) }
      </LinkElement>
    );
  }

  sciName( ) {
    const {
      taxon,
      displayClassName,
      url,
      onClick,
      target,
      noRank
    } = this.props;
    if ( !taxon ) {
      return null;
    }
    const key = `${this.keyBase}-sciName`;
    const LinkElement = this.LinkElement( );
    let sciNameClass = `sciname ${taxon.rank}`;
    if ( ( !taxon.preferred_common_name && _.isEmpty( taxon.preferred_common_names ) )
      || this.showScinameFirst( ) ) {
      sciNameClass += ` display-name ${displayClassName || ""}`;
    } else {
      sciNameClass += " secondary-name";
    }
    let { name } = taxon;
    if ( taxon.rank === "stateofmatter" ) {
      name = I18n.t( "all_taxa.life" );
    }
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
            { namePieces.slice( 0, namePieces.length - 1 ).join( " " ) }
            { " " }
            <span className="rank">
              { rankPiece }
            </span>
            &nbsp;
            { namePieces[namePieces.length - 1] }
          </span>
        );
      }
    }
    if ( taxon.rank && taxon.rank_level > 10 ) {
      return (
        <LinkElement
          key={key}
          className={sciNameClass}
          href={url}
          onClick={onClick}
          target={target}
        >
          { !noRank && (
            <span className="rank">
              { I18n.t( `ranks.${taxon.rank.toLowerCase( )}` ) }
            </span>
          ) }
          { !noRank && "\u00A0" }
          { this.truncateText( name ) }
        </LinkElement>
      );
    }
    return (
      <LinkElement
        key={key}
        className={sciNameClass}
        href={url}
        onClick={onClick}
        target={target}
      >
        { this.truncateText( name ) }
      </LinkElement>
    );
  }

  inactive( ) {
    const { taxon, noInactive, target } = this.props;
    if ( !taxon || taxon.is_active || noInactive ) {
      return null;
    }
    return (
      <span key={`${this.keyBase}-inactive`} className="inactive">
        <a
          href={`/taxon_changes?taxon_id=${taxon.id}`}
          target={target}
        >
          <i className="fa fa-exclamation-circle" />
          { " " }
          { I18n.t( "inactive_taxon" ) }
        </a>
      </span>
    );
  }

  extinct( ) {
    const { taxon } = this.props;
    if ( !taxon || !taxon.extinct ) {
      return null;
    }
    return (
      <span key={`${this.keyBase}-extinct`} className="extinct">
        [
        { I18n.t( "extinct" ) }
        ]
      </span>
    );
  }

  memberGroup( ) {
    const { taxon, showMemberGroup, user } = this.props;
    let memberGroup;
    // show "is member of" if requested and there's no common name
    const isBetweenGenusAndSpecies = taxon && taxon.rank_level < 20 && taxon.rank_level > 10;
    if (
      showMemberGroup
      && taxon
      && (
        ( !taxon.preferred_common_name && !_.isEmpty( taxon.ancestors ) )
        || isBetweenGenusAndSpecies
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
          <span
            key={`${this.keyBase}-memberGroup`}
            className="member-group"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={{
              __html: I18n.t( "a_member_of_taxon_html", {
                taxon: ReactDOMServer.renderToString(
                  <SplitTaxon
                    taxon={groupAncestor}
                    url={`/taxa/${groupAncestor.id}`}
                    user={user}
                  />
                )
              } )
            }}
          />
        );
      }
    }
    return memberGroup;
  }

  linkIcon( ) {
    const { iconLink, target, url } = this.props;
    let linkIcon = null;
    if ( iconLink ) {
      linkIcon = (
        <a
          target={target}
          href={url}
          className="direct-link"
          key={`${this.keyBase}-linkIcon`}
        >
          <i className="icon-link" />
        </a>
      );
    }
    return linkIcon;
  }

  render( ) {
    const { taxon, componentClassName } = this.props;

    let firstName;
    let secondName;
    if ( this.showScinameFirst( ) ) {
      firstName = this.sciName( );
      secondName = this.comNames( taxon );
    } else {
      firstName = this.comNames( taxon );
      secondName = this.sciName( );
    }
    const nodes = _.compact( [
      this.icon( ),
      firstName,
      secondName,
      this.inactive( ),
      this.extinct( ),
      this.memberGroup( ),
      this.linkIcon( )
    ] );
    const className = _.compact( ["SplitTaxon", this.taxonClass( )] ).join( " " );
    return (
      <span title={this.title( )} className={className}>
        { _.flatten( _.map( nodes, ( n, i ) => ( i === 0 ? n : [" ", n] ) ) ) }
      </span>
    );
  }
}

SplitTaxon.propTypes = {
  taxon: PropTypes.object,
  url: PropTypes.string,
  target: PropTypes.string,
  noParens: PropTypes.bool,
  noRank: PropTypes.bool,
  placeholder: PropTypes.string,
  displayClassName: PropTypes.string,
  showIcon: PropTypes.bool,
  truncate: PropTypes.number,
  onClick: PropTypes.func,
  noInactive: PropTypes.bool,
  showMemberGroup: PropTypes.bool,
  user: PropTypes.object,
  iconLink: PropTypes.bool,
  sciFirst: PropTypes.bool
};

SplitTaxon.defaultProps = {
  target: "_self"
};

export default SplitTaxon;
