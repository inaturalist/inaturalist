import React from "react";
import PropTypes from "prop-types";
import { DropdownButton, MenuItem } from "react-bootstrap";
import TaxaTreeContainer from "../containers/taxa_tree_container";
import TaxaListContainer from "../containers/taxa_list_container";

class TreeView extends React.Component {
  rankOptions( ) {
    const {
      lifelist, setTreeMode
    } = this.props;
    let label = lifelist.treeMode === "simplified"
      ? I18n.t( "views.lifelists.dropdowns.simplified_tree" )
      : I18n.t( "views.lifelists.dropdowns.full_taxonomy" );
    label = `${I18n.t( "view" )}: ${label}`;
    return (
      <DropdownButton
        title={label}
        id="treeModeDropdown"
        onSelect={key => setTreeMode( key )}
      >
        <MenuItem
          eventKey="simplified"
          className={lifelist.treeMode === "simplified" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.simplified_tree" ) }
        </MenuItem>
        <MenuItem
          eventKey="full_taxonomy"
          className={lifelist.treeMode === "simplified" ? null : "selected"}
        >
          { I18n.t( "views.lifelists.dropdowns.full_taxonomy" ) }
        </MenuItem>
      </DropdownButton>
    );
  }

  sortOptions( ) {
    const { lifelist, setTreeSort } = this.props;
    let label = I18n.t( "views.lifelists.dropdowns.most_observed" );
    if ( lifelist.treeSort === "name" ) {
      label = I18n.t( "views.lifelists.dropdowns.name" );
    } else if ( lifelist.treeSort === "taxonomic" ) {
      label = I18n.t( "views.lifelists.dropdowns.taxonomic" );
    } else if ( lifelist.treeSort === "obsAsc" ) {
      label = I18n.t( "views.lifelists.dropdowns.least_observed" );
    }
    label = `${I18n.t( "views.lifelists.dropdowns.sort" )}: ${label}`;
    return (
      <DropdownButton
        title={label}
        id="sortDropdown"
        onSelect={key => setTreeSort( key )}
      >
        <MenuItem
          eventKey="obsDesc"
          className={lifelist.treeSort === "obsDesc" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.most_observed" ) }
        </MenuItem>
        <MenuItem
          eventKey="obsAsc"
          className={lifelist.treeSort === "obsAsc" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.least_observed" ) }
        </MenuItem>
        <MenuItem
          eventKey="name"
          className={lifelist.treeSort === "name" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.name" ) }
        </MenuItem>
        <MenuItem
          eventKey="taxonomic"
          className={lifelist.treeSort === "taxonomic" ? "selected" : null}
        >
          { I18n.t( "views.lifelists.dropdowns.taxonomic" ) }
        </MenuItem>
      </DropdownButton>
    );
  }

  ancestryOptions( ) {
    const { lifelist, setListShowAncestry } = this.props;
    let label = I18n.t( "hide" );
    if ( lifelist.listShowAncestry ) {
      label = I18n.t( "show" );
    }
    label = `${I18n.t( "views.lifelists.dropdowns.ancestry" )}: ${label}`;
    return (
      <DropdownButton
        title={label}
        id="ancestryDropdown"
        onSelect={key => setListShowAncestry( key === "show" )}
      >
        <MenuItem
          eventKey="show"
          className={lifelist.listShowAncestry ? "selected" : null}
        >
          { I18n.t( "show" ) }
        </MenuItem>
        <MenuItem
          eventKey="hide"
          className={lifelist.listShowAncestry ? null : "selected"}
        >
          { I18n.t( "hide" ) }
        </MenuItem>
      </DropdownButton>
    );
  }

  render( ) {
    const { lifelist } = this.props;
    let treeComponent;
    if ( lifelist.navView === "tree" ) {
      treeComponent = ( <TaxaTreeContainer /> );
    } else if ( lifelist.navView === "list" ) {
      treeComponent = ( <TaxaListContainer /> );
    }
    return (
      <div className="Details">
        <div className="search-options">
          { this.sortOptions( ) }
          { lifelist.navView === "tree" && this.rankOptions( ) }
        </div>
        { treeComponent }
      </div>
    );
  }
}

TreeView.propTypes = {
  lifelist: PropTypes.object,
  setTreeSort: PropTypes.func,
  setTreeMode: PropTypes.func,
  setListShowAncestry: PropTypes.func
};

export default TreeView;
