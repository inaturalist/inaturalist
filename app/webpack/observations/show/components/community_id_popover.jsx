import React from "react";
import PropTypes from "prop-types";
import { Popover, OverlayTrigger } from "react-bootstrap";
import UserImage from "../../../shared/components/user_image";
import SplitTaxon from "../../../shared/components/split_taxon";

class CommunityIDPopover extends React.Component {

  constructor( ) {
    super( );
    this.renderTaxonomy = this.renderTaxonomy.bind( this );
  }

  renderTaxonomy( taxa, root ) {
    const taxon = taxa.shift( );
    if ( !taxon ) { return ( <div /> ); }
    const lastTaxon = ( taxa.length === 0 );
    const bold = ( this.props.communityIDTaxon && taxon.id === this.props.communityIDTaxon.id );
    return (
      <ul className={ `plain taxonomy ${lastTaxon ? "last" : null}` }>
        <li className={ `${!root && "child"} ${bold && "boldTaxon"}` }>
          <SplitTaxon
            taxon={taxon}
            url={ `/taxa/${taxon.id}` }
            forceRank
            user={ this.props.config.currentUser }
          />
          { !lastTaxon && this.renderTaxonomy( taxa, false ) }
        </li>
      </ul>
    );
  }

  render( ) {
    const identification = this.props.identification;
    const contents = this.props.contents;
    const agreement = this.props.agreement;
    const taxa = ( identification.taxon.ancestors || [] ).concat( identification.taxon );
    const popover = (
      <Popover
        className={ `CommunityIDPopoverOverlay PopoverWithHeader ${agreement ? "agree" : "disagree"}` }
        id={ `popover-${identification.id}` }
      >
        <div className="header">
          <UserImage user={ identification.user } />
          <a href={ `/people/${identification.user.login}` }>{ identification.user.login }</a>'s ID:
        </div>
        <div className="contents">
          { this.renderTaxonomy( taxa, true ) }
        </div>
      </Popover>
    );
    return (
      <OverlayTrigger
        trigger="click"
        rootClose
        placement="top"
        animation={false}
        overlay={popover}
        containerPadding={ 20 }
      >
        <span className={ `CommunityIDPopover ${this.props.className}`} style={ this.props.style }>
          { contents }
        </span>
      </OverlayTrigger>
    );
  }
}

CommunityIDPopover.propTypes = {
  agreement: PropTypes.bool,
  keyPrefix: PropTypes.string,
  contents: PropTypes.object,
  identification: PropTypes.object,
  communityIDTaxon: PropTypes.object,
  style: PropTypes.object,
  className: PropTypes.string,
  config: PropTypes.object
};

CommunityIDPopover.defaultProps = {
  config: {}
};

export default CommunityIDPopover;
