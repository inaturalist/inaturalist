import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonPageMap from "./taxon_page_map";
import TaxonomyTabContainer from "../containers/taxonomy_tab_container";
import ArticlesTabContainer from "../containers/articles_tab_container";

class TaxonPageTabs extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "a[data-toggle=tab]", domNode ).on( "shown.bs.tab", e => {
      if ( !this.props.description && e.target.hash === "#articles-tab" ) {
        this.props.fetchArticlesContent( );
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
            <Grid>
              <Row>
                <Col xs={12}>
                  highlights go here
                </Col>
              </Row>
            </Grid>
          </div>
          <div role="tabpanel" className="tab-pane" id="interactions-tab">
            <Grid>
              <Row>
                <Col xs={12}>
                  interactions go here
                </Col>
              </Row>
            </Grid>
          </div>
          <div role="tabpanel" className="tab-pane" id="taxonomy-tab">
            <Grid>
              <Row>
                <Col xs={12}>
                  <TaxonomyTabContainer />
                </Col>
              </Row>
            </Grid>
          </div>
          <div role="tabpanel" className="tab-pane" id="names-tab">
            <Grid>
              <Row>
                <Col xs={12}>
                  names go here
                </Col>
              </Row>
            </Grid>
          </div>
          <div role="tabpanel" className="tab-pane" id="status-tab">
            <Grid>
              <Row>
                <Col xs={12}>
                  status goes here
                </Col>
              </Row>
            </Grid>
          </div>
        </div>
      </div>
    );
  }
}

TaxonPageTabs.propTypes = {
  taxon: PropTypes.object,
  description: PropTypes.string,
  fetchArticlesContent: PropTypes.func
};

export default TaxonPageTabs;
