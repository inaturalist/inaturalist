import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import ErrorBoundary from "../../../shared/components/error_boundary";
import SplitTaxon from "../../../shared/components/split_taxon";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import PhotoPreviewContainer from "../containers/photo_preview_container";
import ChartsContainer from "../containers/charts_container";
import Leaders from "./leaders";
import TaxonPageTabsContainer from "../containers/taxon_page_tabs_container";
import PhotoModalContainer from "../containers/photo_modal_container";
import PhotoChooserModalContainer from "../containers/photo_chooser_modal_container";
import PlaceChooserContainer from "../containers/place_chooser_container";
import TaxonChangeAlertContainer from "../containers/taxon_change_alert_container";
import TaxonCrumbsContainer from "../containers/taxon_crumbs_container";
import AkaNamesContainer from "../containers/aka_names_container";
import StatusRow from "./status_row";
import FlashMessage from "../../../observations/show/components/flash_message";
import TestGroupToggle from "../../../shared/components/test_group_toggle";

const App = ( { taxon, showNewTaxon, config } ) => (
  <div id="TaxonDetail">
    { config && config.testingApiV2 && (
      <FlashMessage
        key="testing_apiv2"
        title="Testing API V2"
        message="This page is using V2 of the API. Please report any differences from using the page w/ API v1 at https://forum.inaturalist.org/t/api-v2-feedback/21215"
        type="warning"
        html
      />
    ) }
    <Grid>
      <TaxonChangeAlertContainer />
      <Row className="preheader">
        <Col xs={8}>
          <TaxonCrumbsContainer />
          <a className="permalink" href={`/taxa/${taxon.id}-${taxon.name.split( " " ).join( "-" )}`}>
            <i className="icon-link" />
          </a>
        </Col>
        <Col xs={4}>
          <div className="pull-right">
            <TaxonAutocomplete
              inputClassName="input-sm"
              bootstrapClear
              placeholder={I18n.t( "search_species_" )}
              searchExternal={false}
              afterSelect={result => showNewTaxon( result.item )}
              position={{ my: "right top", at: "right bottom", collision: "none" }}
              config={config}
            />
          </div>
        </Col>
      </Row>
      <Row id="TaxonHeader">
        <Col xs={12}>
          <div className="inner">
            <h1>
              <SplitTaxon
                taxon={taxon}
                user={config.currentUser}
              />
              {
                config.currentUser
                && config.currentUser.roles
                && (
                  config.currentUser.roles.indexOf( "curator" ) >= 0
                  || config.currentUser.roles.indexOf( "admin" ) >= 0
                )
                && taxon.flag_counts
                && taxon.flag_counts.unresolved
                && taxon.flag_counts.unresolved > 0
                  ? (
                    <a href={`/taxa/${taxon.id}/flags`} className="btn btn-default btn-flags">
                      <i className="fa fa-flag" />
                      { " " }
                      { I18n.t( "flags_with_count", { count: taxon.flag_counts.unresolved } ) }
                    </a>
                  )
                  : null
              }
            </h1>
            <div id="place-chooser-container">
              <PlaceChooserContainer container={$( "#app" ).get( 0 )} clearButton />
            </div>
          </div>
        </Col>
        <Col xs={12}>
          <AkaNamesContainer />
        </Col>
      </Row>
    </Grid>
    <Grid fluid>
      <Row id="hero">
        <Col xs={12}>
          <Grid>
            <StatusRow
              conservationStatus={taxon.conservationStatus}
              establishmentMeans={taxon.establishment_means}
            />
            <Row>
              <Col xs={6}>
                <PhotoPreviewContainer />
              </Col>
              <Col xs={6}>
                <Leaders taxon={taxon} />
                <Row>
                  <Col xs={12}>
                    <ErrorBoundary>
                      <ChartsContainer />
                    </ErrorBoundary>
                  </Col>
                </Row>
              </Col>
            </Row>
          </Grid>
        </Col>
      </Row>
    </Grid>
    <TaxonPageTabsContainer />
    <PhotoModalContainer />
    <PhotoChooserModalContainer />
    {
      config
      && config.currentUser
      && config.currentUser.roles
      && (
        config.currentUser.roles.indexOf( "curator" ) >= 0
        || config.currentUser.roles.indexOf( "admin" ) >= 0
        || ( config.currentUser.sites_admined && config.currentUser.sites_admined.length > 0 )
      )
      && (
        <div className="container upstacked">
          <div className="row">
            <div className="cols-xs-12">
              <TestGroupToggle
                group="apiv2"
                joinPrompt="Test API V2? You can also use the test=apiv2 URL param"
                joinedStatus="Joined API V2 test"
                user={config.currentUser}
              />
            </div>
          </div>
        </div>
      )
    }
  </div>
);

App.propTypes = {
  taxon: PropTypes.object,
  showNewTaxon: PropTypes.func,
  config: PropTypes.object
};

App.defaultProps = {
  config: {}
};

export default App;
