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
    let breadcrumbs;
    if ( this.state.open ) {
      breadcrumbs = [];
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
