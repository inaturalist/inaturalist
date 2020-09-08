import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import SplitTaxon from "../../../shared/components/split_taxon";

class AncestryBreadcrumbs extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      open: true
    };
  }

  render( ) {
    const {
      config, taxon, keyPrefix, lifelist, setDetailsTaxon
    } = this.props;
    let nextMilestoneParentID = taxon.milestoneParentID;
    if ( !nextMilestoneParentID ) {
      return null;
    }
    let icon;
    let breadcrumbs;
    if ( !this.state.open ) {
      icon = ( <span className="fa fa-caret-left expander" onClick={( ) => this.setState( { open: true } )} /> );
    } else {
      breadcrumbs = [];
      icon = (
        <span
          className="fa fa-caret-right expander"
          onClick={( ) => this.setState( { open: false } )}
        />
      );
      while ( nextMilestoneParentID ) {
        const parentMilestoneTaxon = lifelist.taxa[nextMilestoneParentID];
        breadcrumbs.unshift( (
          <SplitTaxon
            taxon={parentMilestoneTaxon}
            key={`${keyPrefix}-${nextMilestoneParentID}`}
            user={config.currentUser}
            onClick={( ) => setDetailsTaxon( parentMilestoneTaxon, { updateSearch: true } )}
            noRank
          />
        ) );
        nextMilestoneParentID = parentMilestoneTaxon.milestoneParentID;
      }
    }
    return (
      <div className="ancestry">
        { breadcrumbs }
      </div>
    );
  }
}

AncestryBreadcrumbs.propTypes = {
  config: PropTypes.object,
  lifelist: PropTypes.object,
  taxon: PropTypes.object,
  setDetailsTaxon: PropTypes.func,
  keyPrefix: PropTypes.number
};

export default AncestryBreadcrumbs;
