import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import TaxonPageMap from "./taxon_page_map";
import StatusTab from "./status_tab";
import TaxonomyTabContainer from "../containers/taxonomy_tab_container";
import NamesTabContainer from "../containers/names_tab_container";
import ArticlesTabContainer from "../containers/articles_tab_container";
import InteractionsTabContainer from "../containers/interactions_tab_container";
import HighlightsTabContainer from "../containers/highlights_tab_container";

class TaxonPageTabs extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "a[data-toggle=tab]", domNode ).on( "shown.bs.tab", e => {
      switch ( e.target.hash ) {
        case "#articles-tab":
          this.props.fetchArticlesContent( );
          break;
        case "#names-tab":
          this.props.fetchNames( );
          break;
        case "#interactions-tab":
          this.props.fetchInteractions( );
          break;
        case "#highlights-tab":
          this.props.fetchTrendingTaxa( );
          this.props.fetchRareTaxa( );
          break;
        default:
          // it's cool, you probably have what you need
      }
    } );
  }
  render( ) {
    return (
      <div className="TaxonPageTabs">
        <Grid>
          <Row>
            <Col xs={12}>
              <ul className="nav nav-tabs" role="tablist">
                <li role="presentation" className="active">
                  <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
                </li>
                <li role="presentation">
                  <a href="#articles-tab" role="tab" data-toggle="tab">{ I18n.t( "articles" ) }</a>
                </li>
                <li role="presentation">
                  <a
                    href="#highlights-tab"
                    role="tab"
                    data-toggle="tab"
                  >
                    { I18n.t( "highlights" ) }
                  </a>
                </li>
                <li role="presentation">
                  <a
                    href="#interactions-tab"
                    role="tab"
                    data-toggle="tab"
                  >
                    { I18n.t( "interactions" ) }
                  </a>
                </li>
                <li role="presentation">
                  <a href="#taxonomy-tab" role="tab" data-toggle="tab">{ I18n.t( "taxonomy" ) }</a>
                </li>
                <li role="presentation">
                  <a href="#names-tab" role="tab" data-toggle="tab">{ I18n.t( "names" ) }</a>
                </li>
                <li role="presentation">
                  <a href="#status-tab" role="tab" data-toggle="tab">{ I18n.t( "status" ) }</a>
                </li>
                <li role="presentation">
                  <a href="#related-tab" role="tab" data-toggle="tab">{ I18n.t( "related_species" ) }</a>
                </li>
              </ul>
            </Col>
          </Row>
        </Grid>
        <div className="tab-content">
          <div role="tabpanel" className="tab-pane active" id="map-tab">
            <TaxonPageMap taxon={this.props.taxon} />
          </div>
          <div role="tabpanel" className="tab-pane" id="articles-tab">
            <ArticlesTabContainer />
          </div>
          <div role="tabpanel" className="tab-pane" id="highlights-tab">
            <HighlightsTabContainer />
          </div>
          <div role="tabpanel" className="tab-pane" id="interactions-tab">
            <InteractionsTabContainer />
          </div>
          <div role="tabpanel" className="tab-pane" id="taxonomy-tab">
            <TaxonomyTabContainer />
          </div>
          <div role="tabpanel" className="tab-pane" id="names-tab">
            <NamesTabContainer />
          </div>
          <div role="tabpanel" className="tab-pane" id="status-tab">
            <StatusTab
              statuses={this.props.taxon.conservationStatuses}
              listedTaxa={_.filter( this.props.taxon.listed_taxa, lt => lt.establishment_means )}
            />
          </div>
          <div role="tabpanel" className="tab-pane" id="related-tab">
            related species
          </div>
        </div>
      </div>
    );
  }
}

TaxonPageTabs.propTypes = {
  taxon: PropTypes.object,
  fetchArticlesContent: PropTypes.func,
  fetchNames: PropTypes.func,
  fetchInteractions: PropTypes.func,
  fetchRareTaxa: PropTypes.func,
  fetchTrendingTaxa: PropTypes.func
};

export default TaxonPageTabs;
