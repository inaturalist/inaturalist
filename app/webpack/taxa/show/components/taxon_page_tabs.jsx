import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Grid, Row, Col, Dropdown, MenuItem } from "react-bootstrap";
import _ from "lodash";
import TaxonPageMap from "./taxon_page_map";
import StatusTab from "./status_tab";
import TaxonomyTabContainer from "../containers/taxonomy_tab_container";
import ArticlesTabContainer from "../containers/articles_tab_container";
import InteractionsTabContainer from "../containers/interactions_tab_container";
import HighlightsTabContainer from "../containers/highlights_tab_container";
import SimilarTabContainer from "../containers/similar_tab_container";
import RecentObservationsContainer from "../containers/recent_observations_container";

class TaxonPageTabs extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "a[data-toggle=tab]", domNode ).on( "shown.bs.tab", e => {
      this.props.choseTab( e.target.hash.match( /\#(.+)\-tab/ )[1] );
    } );
    this.props.loadDataForTab( this.props.chosenTab );
  }
  render( ) {
    const speciesOrLower = this.props.taxon && this.props.taxon.rank_level <= 10;
    const chosenTab = this.props.chosenTab;
    let curationTab;
    const currentUser = this.props.currentUser;
    if ( currentUser && currentUser.id ) {
      const isCurator =
        currentUser.roles.indexOf( "curator" ) >= 0 ||
        currentUser.roles.indexOf( "admin" ) >= 0;
      curationTab = (
        <li className="curation-tab">
          <Dropdown
            id="curation-dropdown"
            pullRight
            onSelect={ ( e, eventKey ) => {
              switch ( eventKey ) {
                case "add-flag":
                  window.location = `/taxa/${this.props.taxon.id}/flags/new`;
                  break;
                case "view-flags":
                  window.location = `/taxa/${this.props.taxon.id}/flags`;
                  break;
                case "edit-photos":
                  this.props.showPhotoChooserModal( );
                  break;
                default:
                  window.location = `/taxa/${this.props.taxon.id}/edit`;
              }
            }}
          >
            <Dropdown.Toggle>
              <i className="fa fa-cog"></i> { I18n.t( "curation" ) }
            </Dropdown.Toggle>
            <Dropdown.Menu>
              <MenuItem
                className={isCurator ? "" : "hidden"}
                eventKey="add-flag"
              >
                <i className="fa fa-flag"></i> { I18n.t( "flag_for_curation" ) }
              </MenuItem>
              <MenuItem
                className={isCurator ? "" : "hidden"}
                eventKey="view-flags"
              >
                <i className="fa fa-flag-checkered"></i> { I18n.t( "view_flags" ) }
              </MenuItem>
              <MenuItem
                eventKey="edit-photos"
              >
                <i className="fa fa-picture-o"></i> { I18n.t( "edit_photos" ) }
              </MenuItem>
              <MenuItem
                className={isCurator ? "" : "hidden"}
                eventKey="edit-taxon"
              >
                <i className="fa fa-pencil"></i> { I18n.t( "edit_taxon" ) }
              </MenuItem>
            </Dropdown.Menu>
          </Dropdown>
        </li>
      );
    }
    return (
      <div className="TaxonPageTabs">
        <Grid>
          <Row>
            <Col xs={12}>
              <ul id="main-tabs" className="nav nav-tabs" role="tablist">
                <li role="presentation" className={ chosenTab === "map" ? "active" : "" }>
                  <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
                </li>
                <li role="presentation" className={ chosenTab === "articles" ? "active" : "" }>
                  <a href="#articles-tab" role="tab" data-toggle="tab">{ I18n.t( "about" ) }</a>
                </li>
                <li
                  role="presentation"
                  className={ `${speciesOrLower ? "hidden" : ""} ${chosenTab === "highlights" ? "active" : ""}`}
                >
                  <a
                    href="#highlights-tab"
                    role="tab"
                    data-toggle="tab"
                  >
                    { I18n.t( "trends" ) }
                  </a>
                </li>
                { true ? null : (
                  <li role="presentation"
                    className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "interactions" ? "active" : ""}`}
                  >
                    <a
                      href="#interactions-tab"
                      role="tab"
                      data-toggle="tab"
                    >
                      { I18n.t( "interactions" ) }
                    </a>
                  </li>
                ) }
                <li role="presentation" className={ chosenTab === "taxonomy" ? "active" : "" }>
                  <a href="#taxonomy-tab" role="tab" data-toggle="tab">{ I18n.t( "taxonomy" ) }</a>
                </li>
                <li
                  role="presentation"
                  className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "status" ? "active" : ""}`}
                >
                  <a href="#status-tab" role="tab" data-toggle="tab">{ I18n.t( "status" ) }</a>
                </li>
                <li
                  role="presentation"
                  className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "similar" ? "active" : ""}`}
                >
                  <a href="#similar-tab" role="tab" data-toggle="tab">{ I18n.t( "similar_species" ) }</a>
                </li>
                { curationTab }
              </ul>
            </Col>
          </Row>
        </Grid>
        <div id="main-tabs-content" className="tab-content">
          <div
            role="tabpanel"
            className={`tab-pane ${chosenTab === "map" ? "active" : ""}`}
            id="map-tab"
          >
            <TaxonPageMap taxon={this.props.taxon} />
            <RecentObservationsContainer />
          </div>
          <div
            role="tabpanel"
            className={`tab-pane ${chosenTab === "articles" ? "active" : ""}`}
            id="articles-tab"
          >
            <ArticlesTabContainer />
          </div>
          <div
            role="tabpanel"
            className={`tab-pane ${speciesOrLower ? "hidden" : ""} ${chosenTab === "highlights" ? "active" : ""}`}
            id="highlights-tab"
          >
            <HighlightsTabContainer />
          </div>
          <div
            role="tabpanel"
            className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "interactions" ? "active" : ""}`}
            id="interactions-tab"
          >
            <InteractionsTabContainer />
          </div>
          <div
            role="tabpanel"
            className={`tab-pane ${chosenTab === "taxonomy" ? "active" : ""}`}
            id="taxonomy-tab">
            <TaxonomyTabContainer />
          </div>
          <div
            role="tabpanel"
            className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "status" ? "active" : ""}`}
            id="status-tab"
          >
            <StatusTab
              statuses={this.props.taxon.conservationStatuses}
              listedTaxa={_.filter( this.props.taxon.listed_taxa, lt => lt.establishment_means )}
            />
          </div>
          <div
            role="tabpanel"
            className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "similar" ? "active" : ""}`}
            id="similar-tab"
          >
            <SimilarTabContainer />
          </div>
        </div>
      </div>
    );
  }
}

TaxonPageTabs.propTypes = {
  taxon: PropTypes.object,
  currentUser: PropTypes.object,
  showPhotoChooserModal: PropTypes.func,
  choseTab: PropTypes.func,
  chosenTab: PropTypes.string,
  loadDataForTab: PropTypes.func
};

TaxonPageTabs.defaultProps = {
  chosenTab: "map"
};

export default TaxonPageTabs;
