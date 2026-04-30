import React, { useEffect, useRef } from "react";
import PropTypes from "prop-types";
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
import TabDrawer from "../../../shared/components/tab_drawer";

const TaxonPageTabs = ( {
  taxon,
  chosenTab,
  currentUser,
  showPhotoChooserModal,
  choseTab,
  loadDataForTab
} ) => {
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
  const tabLabels = {
    map: I18n.t( "map" ),
    articles: I18n.t( "about" ),
    highlights: I18n.t( "trends" ),
    interactions: I18n.t( "interactions" ),
    taxonomy: I18n.t( "taxonomy" ),
    status: I18n.t( "status" ),
    similar: speciesOrLower ? I18n.t( "similar_species" ) : I18n.t( "similar_taxa" ),
    identifications: I18n.t( "identifications" )
  };
  const drawerItems = [
    { value: "map", label: tabLabels.map },
    { value: "articles", label: tabLabels.articles },
    ...( !speciesOrLower ? [{ value: "highlights", label: tabLabels.highlights }] : [] ),
    ...( speciesOrLower && test === "interactions" ? [{ value: "interactions", label: tabLabels.interactions }] : [] ),
    { value: "taxonomy", label: tabLabels.taxonomy },
    ...( speciesOrLower ? [{ value: "status", label: tabLabels.status }] : [] ),
    ...( genusOrSpecies ? [{ value: "similar", label: tabLabels.similar }] : [] ),
    ...( currentUser?.canViewHelpfulIDTips( ) && speciesOrLower ? [{ value: "identifications", label: tabLabels.identifications }] : [] )
  ];
  console.log( "currentUser", currentUser );
  if ( currentUser?.privilegedWith( "interaction" ) ) {
    console.log( "is privilegedWith interaction" );
    drawerItems.push( { separator: true } );
    drawerItems.push( { href: `/taxa/${taxon.id}/flags/new`, label: I18n.t( "flag_for_curation" ), icon: "fa-cog" } );
    if ( flagsCount > 0 ) {
      drawerItems.push( { href: `/taxa/${taxon.id}/flags`, label: I18n.t( "view_flags" ), icon: "fa-cog" } );
    }
    if ( !taxon.photos_locked || isAdmin ) {
      if ( !currentUser.content_creation_restrictions ) {
        drawerItems.push( { onClick: ( ) => showPhotoChooserModal( ), label: I18n.t( "edit_photos" ), icon: "fa-cog" } );
      }
    }
    if ( isCurator && taxon.rank_level <= 10 ) {
      if ( taxon.atlas_id ) {
        drawerItems.push( { href: `/atlases/${taxon.atlas_id}`, label: I18n.t( "edit_atlas" ), icon: "fa-cog" } );
      } else {
        drawerItems.push( { href: `/atlases/new?taxon_id=${taxon.id}`, label: I18n.t( "create_an_atlas" ), icon: "fa-cog" } );
      }
    }
    if ( isCurator ) {
      drawerItems.push( { href: `/taxa/${taxon.id}/edit`, label: I18n.t( "edit_taxon" ), icon: "fa-cog" } );
    }
    drawerItems.push( { href: `/taxa/${taxon.id}/history`, label: I18n.t( "history" ), icon: "fa-cog" } );
  }
  if ( currentUser?.privilegedWith( "interaction" ) ) {
    let atlasItem;
    if ( isCurator && taxon.rank_level <= 10 ) {
      atlasItem = taxon.atlas_id ? (
        <li>
          <a href={`/atlases/${taxon.atlas_id}`}>
            <i className="fa fa-globe" />
            { " " }
            { I18n.t( "edit_atlas" ) }
          </a>
        </li>
      ) : (
        <li>
          <a href={`/atlases/new?taxon_id=${taxon.id}`}>
            <i className="fa fa-globe" />
            { " " }
            { I18n.t( "create_an_atlas" ) }
          </a>
        </li>
      );
    }

    let taxonPhotosItem;
    if ( taxon.photos_locked && !isAdmin ) {
      taxonPhotosItem = (
        <li className="disabled" title={I18n.t( "photos_locked_desc" )}>
          <span>
            <i className="fa fa-picture-o" />
            { " " }
            { I18n.t( "photos_locked" ) }
          </span>
        </li>
      );
    } else if ( !currentUser.content_creation_restrictions ) {
      taxonPhotosItem = (
        <li>
          { /* eslint-disable-next-line jsx-a11y/anchor-is-valid */ }
          <a
            href="#"
            onClick={e => {
              e.preventDefault( );
              showPhotoChooserModal( );
            }}
          >
            <i className="fa fa-picture-o" />
            { " " }
            { I18n.t( "edit_photos" ) }
          </a>
        </li>
      );
    }

    curationTab = (
      <li className="curation-tab">
        <div className="dropdown" id="curation-dropdown">
          <button
            className="btn btn-default dropdown-toggle"
            type="button"
            data-toggle="dropdown"
          >
            <i className="fa fa-cog" />
            { " " }
            { I18n.t( "curation" ) }
            { " " }
            <span className="caret" />
          </button>
          <ul className="dropdown-menu dropdown-menu-right">
            <li>
              <a href={`/taxa/${taxon.id}/flags/new`}>
                <i className="fa fa-flag" />
                { " " }
                { I18n.t( "flag_for_curation" ) }
              </a>
            </li>
            <li className={flagsCount > 0 ? "" : "hidden"}>
              <a href={`/taxa/${taxon.id}/flags`}>
                <i className="fa fa-flag-checkered" />
                { " " }
                { I18n.t( "view_flags" ) }
                { " " }
                <span className="text-muted">{ `(${flagsCount})` }</span>
              </a>
            </li>
            { taxonPhotosItem }
            { atlasItem }
            <li className={isCurator ? "" : "hidden"}>
              <a href={`/taxa/${taxon.id}/edit`}>
                <i className="fa fa-pencil" />
                { " " }
                { I18n.t( "edit_taxon" ) }
              </a>
            </li>
            <li>
              <a href={`/taxa/${taxon.id}/history`}>
                <i className="fa fa-history" />
                { " " }
                { I18n.t( "history" ) }
              </a>
            </li>
          </ul>
        </div>
      </li>
    );
  }
  return (
    <div className="TaxonPageTabs" ref={containerRef}>
      <TabDrawer
        selectedValue={chosenTab}
        selectedLabel={tabLabels[chosenTab]}
        items={drawerItems}
        onChange={choseTab}
      />
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
