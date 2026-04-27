import React, { useEffect, useRef } from "react";
import PropTypes from "prop-types";
import {
  Grid,
  Row,
  Col,
  Dropdown,
  MenuItem
} from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import _ from "lodash";
import TaxonPageMapContainer from "../containers/taxon_page_map_container";
import StatusTab from "./status_tab";
import TaxonomyTabContainer from "../containers/taxonomy_tab_container";
import ArticlesTabContainer from "../containers/articles_tab_container";
import InteractionsTabContainer from "../containers/interactions_tab_container";
import HighlightsTabContainer from "../containers/highlights_tab_container";
import SimilarTabContainer from "../containers/similar_tab_container";
import IdentificationsTabContainer from "../containers/identifications_tab_container";
import RecentObservationsContainer from "../containers/recent_observations_container";

const TaxonPageTabs = ({
  taxon,
  chosenTab,
  currentUser,
  showPhotoChooserModal,
  choseTab,
  loadDataForTab
}) => {
  const containerRef = useRef( null );
  const prevTaxonIdRef = useRef( taxon?.id );
  const prevChosenTabRef = useRef( chosenTab );

  useEffect( ( ) => {
    const tabs = $( "a[data-toggle=tab]", containerRef.current );
    const handleTabShown = e => {
      choseTab( e.target.hash.match( /#(.+)-tab/ )[1] );
    };
    tabs.on( "shown.bs.tab", handleTabShown );
    return ( ) => tabs.off( "shown.bs.tab", handleTabShown );
  }, [] );

  useEffect( ( ) => {
    if ( prevTaxonIdRef.current !== taxon?.id ) {
      loadDataForTab( chosenTab );
    }
    // very lame hack to make sure the map resizes correctly if it rendered when
    // not visible
    if ( chosenTab === "map" && prevChosenTabRef.current !== "map" ) {
      const taxonMap = $( ".TaxonMap", containerRef.current );
      // If google wasn't initialized for some reason, doing any of this will
      // crash, and we can't use an ErrorBoundary in a callback like this
      if ( typeof ( google ) !== "undefined" ) {
        google.maps.event.trigger( taxonMap.data( "taxonMap" ), "resize" );
        taxonMap.taxonMap( taxonMap.data( "taxonMapOptions" ) );
      }
    }
    prevTaxonIdRef.current = taxon?.id;
    prevChosenTabRef.current = chosenTab;
  }, [taxon?.id, chosenTab] );

  const { test } = $.deparam.querystring( );
  const speciesOrLower = taxon && taxon.rank_level <= 10;
  const genusOrSpecies = taxon && ( taxon.rank_level === 20 || taxon.rank_level === 10 );
  let curationTab;
  const flagsCount = taxon.flag_counts
    ? parseInt( taxon.flag_counts.resolved, 10 ) + parseInt( taxon.flag_counts.unresolved, 10 )
    : 0;
  const isCurator = currentUser?.roles.indexOf( "curator" ) >= 0 || currentUser?.roles.indexOf( "admin" ) >= 0;
  const isAdmin = currentUser?.roles.indexOf( "admin" ) >= 0;
  if ( currentUser?.privilegedWith( "interaction" ) ) {
    let atlasItem;
    if ( isCurator && taxon.rank_level <= 10 ) {
      atlasItem = taxon.atlas_id ? (
        <MenuItem eventKey="edit-atlas" href={`/atlases/${taxon.atlas_id}`}>
          <i className="fa fa-globe" />
          { " " }
          { I18n.t( "edit_atlas" ) }
        </MenuItem>
      ) : (
        <MenuItem eventKey="new-atlas" href={`/atlases/new?taxon_id=${taxon.id}`}>
          <i className="fa fa-globe" />
          { " " }
          { I18n.t( "create_an_atlas" ) }
        </MenuItem>
      );
    }

    let taxonPhotosItem;
    if ( taxon.photos_locked && !isAdmin ) {
      taxonPhotosItem = (
        <MenuItem
          className="disabled"
          title={I18n.t( "photos_locked_desc" )}
          eventKey="edit-photos-locked"
        >
          <i className="fa fa-picture-o" />
          { " " }
          { I18n.t( "photos_locked" ) }
        </MenuItem>
      );
    } else if ( !currentUser.content_creation_restrictions ) {
      taxonPhotosItem = (
        <MenuItem
          eventKey="edit-photos"
        >
          <i className="fa fa-picture-o" />
          { " " }
          { I18n.t( "edit_photos" ) }
        </MenuItem>
      );
    }

    curationTab = (
      <li className="curation-tab">
        <Dropdown
          id="curation-dropdown"
          pullRight
          onSelect={eventKey => {
            switch ( eventKey ) {
              case "add-flag":
                window.location = `/taxa/${taxon.id}/flags/new`;
                break;
              case "view-flags":
                window.location = `/taxa/${taxon.id}/flags`;
                break;
              case "edit-photos":
                showPhotoChooserModal( );
                break;
              case "edit-photos-locked":
                // If photos are locked, do nothing
                break;
              case "edit-atlas":
                window.location = `/atlases/${taxon.atlas_id}`;
                break;
              case "new-atlas":
                window.location = `/atlases/new?taxon_id=${taxon.id}`;
                break;
              case "history":
                window.location = `/taxa/${taxon.id}/history`;
                break;
              default:
                window.location = `/taxa/${taxon.id}/edit`;
            }
          }}
        >
          <Dropdown.Toggle>
            <i className="fa fa-cog" />
            { " " }
            { I18n.t( "curation" ) }
          </Dropdown.Toggle>
          <Dropdown.Menu>
            <MenuItem
              eventKey="add-flag"
              href={`/taxa/${taxon.id}/flags/new`}
            >
              <i className="fa fa-flag" />
              { " " }
              { I18n.t( "flag_for_curation" ) }
            </MenuItem>
            <MenuItem
              className={flagsCount > 0 ? "" : "hidden"}
              eventKey="view-flags"
              href={`/taxa/${taxon.id}/flags`}
            >
              <i className="fa fa-flag-checkered" />
              { " " }
              { I18n.t( "view_flags" ) }
              { " " }
              <span className="text-muted">{ `(${flagsCount})` }</span>
            </MenuItem>
            { taxonPhotosItem }
            { atlasItem }
            <MenuItem
              className={isCurator ? "" : "hidden"}
              eventKey="edit-taxon"
              href={`/taxa/${taxon.id}/edit`}
            >
              <i className="fa fa-pencil" />
              { " " }
              { I18n.t( "edit_taxon" ) }
            </MenuItem>
            <MenuItem
              eventKey="history"
              href={`/taxa/${taxon.id}/history`}
            >
              <i className="fa fa-history" />
              { " " }
              { I18n.t( "history" ) }
            </MenuItem>
          </Dropdown.Menu>
        </Dropdown>
      </li>
    );
  }
  return (
    <div className="TaxonPageTabs" ref={containerRef}>
      <Grid>
        <Row>
          <Col xs={12}>
            <ul id="main-tabs" className="nav nav-tabs" role="tablist">
              <li role="presentation" className={chosenTab === "map" ? "active" : ""}>
                <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
              </li>
              <li role="presentation" className={chosenTab === "articles" ? "active" : ""}>
                <a href="#articles-tab" role="tab" data-toggle="tab">{ I18n.t( "about" ) }</a>
              </li>
              <li
                role="presentation"
                className={`${speciesOrLower ? "hidden" : ""} ${chosenTab === "highlights" ? "active" : ""}`}
              >
                <a
                  href="#highlights-tab"
                  role="tab"
                  data-toggle="tab"
                >
                  { I18n.t( "trends" ) }
                </a>
              </li>
              { test === "interactions" && (
                <li
                  role="presentation"
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
              <li role="presentation" className={chosenTab === "taxonomy" ? "active" : ""}>
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
                className={`${genusOrSpecies ? "" : "hidden"} ${chosenTab === "similar" ? "active" : ""}`}
              >
                <a href="#similar-tab" role="tab" data-toggle="tab">
                  { speciesOrLower ? I18n.t( "similar_species" ) : I18n.t( "similar_taxa" ) }
                </a>
              </li>
              { currentUser?.canViewHelpfulIDTips( ) && (
                <li
                  role="presentation"
                  className={`${speciesOrLower ? "" : "hidden"} ${chosenTab === "identifications" ? "active" : ""}`}
                >
                  <a href="#identifications-tab" role="tab" data-toggle="tab">{ I18n.t( "identifications" ) }</a>
                </li>
              ) }
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
          <LazyLoad
            debounce={false}
            offset={100}
          >
            <TaxonPageMapContainer />
          </LazyLoad>
          <LazyLoad
            debounce={false}
            minHeight={120}
            offset={100}
          >
            <RecentObservationsContainer />
          </LazyLoad>
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
          id="taxonomy-tab"
        >
          <TaxonomyTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "status" ? "active" : ""}`}
          id="status-tab"
        >
          <StatusTab
            currentUser={currentUser}
            taxon={taxon}
            statuses={taxon.conservationStatuses}
            listedTaxaCount={taxon.listed_taxa_count}
            listedTaxa={_.filter( taxon.listed_taxa, lt => lt.establishment_means )}
          />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${genusOrSpecies ? "" : "hidden"} ${chosenTab === "similar" ? "active" : ""}`}
          id="similar-tab"
        >
          <SimilarTabContainer />
        </div>
        <div
          role="tabpanel"
          className={`tab-pane ${speciesOrLower ? "" : "hidden"} ${chosenTab === "identifications" ? "active" : ""}`}
          id="identifications-tab"
        >
          <IdentificationsTabContainer />
        </div>
      </div>
    </div>
  );
};

TaxonPageTabs.propTypes = {
  taxon: PropTypes.object,
  currentUser: PropTypes.object,
  showPhotoChooserModal: PropTypes.func,
  choseTab: PropTypes.func,
  chosenTab: PropTypes.string,
  loadDataForTab: PropTypes.func
};

TaxonPageTabs.defaultProps = {
  chosenTab: "articles"
};

export default TaxonPageTabs;
