import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import {
  Button,
  Col,
  Grid,
  Overlay,
  Popover,
  Row
} from "react-bootstrap";
import _ from "lodash";
import PlaceAutocomplete from "./place_autocomplete";
import ProjectAutocomplete from "./project_autocomplete";
import UserAutocomplete from "./user_autocomplete";
import DateFilters from "./date_filters";
import FilterCheckbox from "./filter_checkbox";

class FiltersButton extends React.Component {
  constructor( props ) {
    super( props );
    const { params } = props;
    const diffs = _.difference( _.values( params ), _.values( props.defaultParams ) );
    this.state = {
      moreFiltersHidden: diffs.length === 0,
      show: false
    };
    this.clickOffEventNamespace = "click.FiltersButtonClickOff";
    this.target = React.createRef( );
  }

  toggle( ) {
    const { show } = this.state;
    if ( show ) {
      this.hide( );
      return;
    }
    this.show( );
  }

  show( ) {
    this.setState( { show: true } );
    const that = this;
    $( "body" ).on( this.clickOffEventNamespace, e => {
      if (
        !$( ".FiltersButtonWrapper" ).is( e.target )
        && $( ".FiltersButtonWrapper" ).has( e.target ).length === 0
        && $( ".in" ).has( e.target ).length === 0
        && $( e.target ).parents( ".ui-autocomplete " ).length === 0
        && $( e.target ).parents( ".ui-datepicker " ).length === 0
        && $( e.target ).parents( ".ui-datepicker-header " ).length === 0
        && $( e.target ).parents( ".ui-multiselect-menu " ).length === 0
        && $( e.target ).parents( ".observation-field " ).length === 0
      ) {
        that.hide( );
      }
    } );
  }

  hide( ) {
    this.setState( { show: false } );
    $( "body" ).unbind( this.clickOffEventNamespace );
  }

  render( ) {
    const {
      config,
      params,
      updateSearchParams,
      replaceSearchParams,
      defaultParams,
      terms
    } = this.props;
    const {
      moreFiltersHidden,
      show
    } = this.state;
    const paramsForUrl = ( ) => window.location.search.replace( /^\?/, "" );
    const closeFilters = ( ) => {
      // yes it's a horrible hack
      $( ".FiltersButton" ).click( );
    };
    const resetParams = ( ) => replaceSearchParams( defaultParams );
    const numFiltersSet = ( ) => {
      const diffs = _.difference( _.values( params ), _.values( defaultParams ) );
      return diffs.length > 0 ? diffs.length.toString() : "";
    };
    const viewerCuratesProject = config && config.currentUser
      && _.find(
        config.currentUser.curator_projects,
        p => [p.id, p.slug].includes( params.project_id )
      );
    const FilterCheckboxWrapper = checkbox => (
      <FilterCheckbox
        {...Object.assign( {}, checkbox, {
          defaultParams,
          params,
          updateSearchParams
        } )}
      />
    );
    const visibleRanks = [
      "kingdom",
      "phylum",
      "subphylum",
      "superclass",
      "class",
      "subclass",
      "infraclass",
      "subterclass",
      "superorder",
      "order",
      "suborder",
      "infraorder",
      "parvorder",
      "zoosection",
      "zoosubsection",
      "superfamily",
      "epifamily",
      "family",
      "subfamily",
      "supertribe",
      "tribe",
      "subtribe",
      "genus",
      "genushybrid",
      "subgenus",
      "section",
      "subsection",
      "complex",
      "species",
      "hybrid",
      "subspecies",
      "variety",
      "form",
      "infrahybrid"
    ];
    const orderByFields = [
      { value: "id", label: "date_added" },
      { value: "observed_on", label: "date_observed_" },
      { value: "updated_at", label: "date_updated" },
      { value: "votes", label: "faves" },
      { value: "random", label: "random" }
    ];
    const canShowObservationFields = ( ) => (
      params.observationFields && _.size( params.observationFields ) > 0
    );
    const iconicTaxonButton = ( t, i ) => {
      let cssClass = "iconic-taxon";
      if ( ( i + 1 ) % 6 === 0 ) {
        cssClass += " last";
      }
      if ( _.includes( params.iconic_taxa, t.name ) ) {
        cssClass += " filter-changed active";
      }
      return (
        <Button
          className={cssClass}
          title={I18n.t( `all_taxa.${t.label}`, { defaultValue: I18n.t( t.label ) } )}
          key={`btn-${t.name}`}
          onClick={( ) => {
            let newIconicTaxa;
            if ( _.includes( params.iconic_taxa, t.name ) ) {
              newIconicTaxa = _.without( params.iconic_taxa, t.name );
            } else {
              newIconicTaxa = params.iconic_taxa.map( n => n );
              newIconicTaxa.push( t.name );
            }
            updateSearchParams( {
              iconic_taxa: newIconicTaxa
            } );
          }}
        >
          <i className={`icon-iconic-${t.name.toLowerCase( )}`} />
        </Button>
      );
    };
    const licenses = [
      "CC0",
      "CC-BY",
      "CC-BY-NC",
      "CC-BY-SA",
      "CC-BY-ND",
      "CC-BY-NC-SA",
      "CC-BY-NC-ND"
    ];
    const mainLeftCol = (
      <Col xs="4">
        <Row>
          <Col xs="12">
            <label className="sectionlabel">
              { I18n.t( "quality_grade_" ) }
              { " " }
              <small className="text-muted">
                { `(${I18n.t( "select_at_least_one" )})` }
              </small>
            </label>
          </Col>
        </Row>
        <Row>
          <Col className="quality-filters" xs="12">
            <FilterCheckboxWrapper
              param="quality_grade"
              label={I18n.t( "casual_" )}
              checked="casual"
              noBlank
            />
            <FilterCheckboxWrapper
              param="quality_grade"
              label={I18n.t( "needs_id_" )}
              checked="needs_id"
              noBlank
            />
            <FilterCheckboxWrapper
              param="quality_grade"
              label={I18n.t( "research_grade" )}
              checked="research"
              noBlank
            />
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel">
              { I18n.t( "show" ) }
            </label>
          </Col>
        </Row>
        <Row className="show-filters">
          <Col className="filters-left-col" xs="6">
            { [
              { param: "captive", key: "show-filter-captive" },
              { param: "threatened", key: "show-filter-threatened" },
              { param: "introduced", key: "show-filter-introduced" },
              { param: "popular", key: "show-filter-popular" }
            ].map( FilterCheckboxWrapper ) }
          </Col>
          <Col className="filters-left-col" xs="6">
            { [
              { param: "sounds", key: "show-filter-sounds", label: I18n.t( "has_sounds" ) },
              { param: "photos", key: "show-filter-photos", label: I18n.t( "has_photos" ) },
              {
                param: "user_id",
                key: "show-filter-user_id",
                label: I18n.t( "your_observations" ),
                checked: CURRENT_USER.id
              }
            ].map( FilterCheckboxWrapper ) }
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <div className="form-group">
              <label className="sectionlabel" htmlFor="params-q">
                { I18n.t( "description_slash_tags" ) }
              </label>
              <input
                className="params-q form-control"
                placeholder={I18n.t( "blue_butterfly_etc" )}
                value={params.q}
                onChange={e => {
                  updateSearchParams( { q: e.target.value } );
                }}
              />
            </div>
          </Col>
        </Row>
      </Col>
    );
    const mainCenterCol = (
      <Col xs="4" className="filters-center-col">
        <Row className="form-group">
          <Col xs="12">
            <label className="sectionlabel">
              { I18n.t( "categories" ) }
            </label>
            <div className="filters-categories btn-group">
              { [
                { name: "Aves", label: "birds" },
                { name: "Amphibia", label: "amphibians" },
                { name: "Reptilia", label: "reptiles" },
                { name: "Mammalia", label: "mammals" },
                { name: "Actinopterygii", label: "ray_finned_fishes" },
                { name: "Mollusca", label: "mollusks" }
              ].map( iconicTaxonButton ) }
              { [
                { name: "Arachnida", label: "arachnids" },
                { name: "Insecta", label: "insects" },
                { name: "Plantae", label: "plants" },
                { name: "Fungi", label: "fungi" },
                { name: "Protozoa", label: "protozoans" },
                { name: "unknown", label: "unknown" }
              ].map( iconicTaxonButton ) }
            </div>
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel" htmlFor="params-hrank">
              { I18n.t( "rank" ) }
            </label>
          </Col>
        </Row>
        <Row className="filters-ranks form-group">
          <Col xs="6">
            <select
              className={`params-hrank form-control ${params.hrank ? "filter-changed" : ""}`}
              defaultValue={params.hrank}
              onChange={e => updateSearchParams( { hrank: e.target.value } )}
            >
              <option value="">
                { I18n.t( "high" ) }
              </option>
              { visibleRanks.map( rank => (
                <option key={`params-hrank-${rank}`} value={rank}>
                  { I18n.t( `ranks.${rank}` ) }
                </option>
              ) ) }
            </select>
          </Col>
          <Col xs="6">
            <select
              className={`params-lrank form-control ${params.lrank ? "filter-changed" : ""}`}
              defaultValue={params.lrank}
              onChange={e => updateSearchParams( { lrank: e.target.value } )}
            >
              <option value="">
                { I18n.t( "low" ) }
              </option>
              { visibleRanks.map( rank => (
                <option key={`params-lrank-${rank}`} value={rank}>
                  { I18n.t( `ranks.${rank}` ) }
                </option>
              ) ) }
            </select>
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel" htmlFor="params-order-by">
              { I18n.t( "sort_by" ) }
            </label>
          </Col>
        </Row>
        <Row className="form-group">
          <Col xs="6">
            <select
              className={
                "params-order-by form-control"
                + ` ${params.order_by !== defaultParams.order_by ? "filter-changed" : ""}`
              }
              onChange={e => updateSearchParams( { order_by: e.target.value } )}
              value={params.order_by}
            >
              { orderByFields.map( field => (
                <option value={field.value} key={`params-order-by-${field.value}`}>
                  { I18n.t( field.label ) }
                </option>
              ) ) }
            </select>
          </Col>
          <Col xs="6">
            <select
              defaultValue="desc"
              className={
                "params-order form-control"
                + ` ${params.order !== defaultParams.order ? "filter-changed" : ""}`
              }
              onChange={e => updateSearchParams( { order: e.target.value } )}
            >
              <option value="asc">
                { I18n.t( "ascending" ) }
              </option>
              <option value="desc">
                { I18n.t( "descending" ) }
              </option>
            </select>
          </Col>
        </Row>
      </Col>
    );
    const mainRightCol = (
      <Col xs="4" className="filters-right-col">
        <label className="sectionlabel">
          { I18n.t( "date_observed_" ) }
        </label>
        <DateFilters
          params={params}
          updateSearchParams={updateSearchParams}
        />
        <div
          className={canShowObservationFields( ) ? "filters-observation-fields" : "filters-observation-fields collapse"}
        >
          <label className="sectionlabel">
            { I18n.t( "observation_fields" ) }
          </label>
          { _.forEach( params.observationFields, ( v, k ) => (
            <span className="observation-field" key={`observation-field-${k}`}>
              { `${k}=${v}` }
              <button
                type="button"
                onClick={( ) => {
                  updateSearchParams( {
                    observationFields: _.omit( params.observationFields, [k] )
                  } );
                }}
              >
                &times;
              </button>
            </span>
          ) ) }
          <input type="hidden" name="taxon_ids[]" />
          <input type="hidden" name="taxon_ids" />
          <input type="hidden" name="has[]" />
          <input type="hidden" name="not_in_project" />
          <input type="hidden" name="lat" />
          <input type="hidden" name="lng" />
          <input type="hidden" name="viewer_id" />
          <input type="hidden" name="identified" />
          <input type="hidden" name="captive" />
          <input type="hidden" name="day" />
          <input type="hidden" name="year" />
          <input type="hidden" name="site_id" />
          <input type="hidden" name="projects[]" />
          <input type="hidden" name="apply_project_rules_for" />
          <input type="hidden" name="not_matching_project_rules_for" />
          <input type="hidden" name="list_id" />
        </div>
        <div className="form-group">
          <label className="sectionlabel">
            { I18n.t( "photo_licensing" ) }
          </label>
          <select
            className={`form-control ${params.photo_license ? "filter-changed" : ""}`}
            value={params.photo_license}
            onChange={e => updateSearchParams( { photo_license: e.target.value } )}
          >
            <option value="">{ I18n.t( "all" ) }</option>
            {licenses.map( code => (
              <option key={`photo-licenses-${code}`} value={code}>{ code.replace( "CC-", "CC " ) }</option>
            ) ) }
          </select>
        </div>
        <label className="sectionlabel">
          { I18n.t( "reviewed" ) }
        </label>
        <div className="form-group">
          <label
            className={
              `radio-inline ${params.reviewed === undefined || params.reviewed === null || params.reviewed === "any" ? "filter-changed" : ""}`
            }
          >
            <input
              type="radio"
              name="reviewed"
              checked={
                params.reviewed === undefined || params.reviewed === null || params.reviewed === "any"
              }
              onChange={( ) => updateSearchParams( { reviewed: "any" } )}
            />
            { I18n.t( "any_" ) }
          </label>
          <label className={`radio-inline ${params.reviewed === true ? "filter-changed" : ""}`}>
            <input
              type="radio"
              name="reviewed"
              value="true"
              checked={params.reviewed === true}
              onChange={( ) => updateSearchParams( { reviewed: true } )}
            />
            { I18n.t( "yes" ) }
          </label>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed"
              value="false"
              checked={params.reviewed === false}
              onChange={( ) => updateSearchParams( { reviewed: false } )}
            />
            { I18n.t( "no" ) }
          </label>
        </div>
      </Col>
    );
    const mainFilters = (
      <Row className="filters-row">
        { mainLeftCol }
        { mainCenterCol}
        { mainRightCol }
      </Row>
    );
    const moreLeftCol = (
      <Col xs="4">
        <div className="form-group">
          <label className="sectionlabel" htmlFor="params-user-id">
            { I18n.t( "person" ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon icon-person" />
            <UserAutocomplete
              resetOnChange={false}
              initialUserID={params.user_id}
              bootstrapClear
              className={params.user_id ? "filter-changed" : ""}
              afterSelect={result => {
                updateSearchParams( { user_id: result.item.id } );
              }}
              afterUnselect={( ) => {
                updateSearchParams( { user_id: null } );
              }}
            />
            <input value={params.user_id} type="hidden" name="user_id" />
          </div>
        </div>
        <div className="form-group">
          <label className="sectionlabel" htmlFor="params-project-id">
            { I18n.t( "project" ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon fa fa-briefcase" />
            <ProjectAutocomplete
              resetOnChange={false}
              initialProjectID={params.project_id}
              bootstrapClear
              className={params.project_id ? "filter-changed" : ""}
              afterSelect={result => {
                updateSearchParams( { project_id: result.item.id } );
              }}
              afterUnselect={( ) => {
                updateSearchParams( { project_id: null } );
              }}
            />
            <input value={params.project_id} type="hidden" name="project_id" />
          </div>
          { params.project_id && viewerCuratesProject && (
            <FilterCheckboxWrapper
              param="coords_viewable_for_proj"
              label={I18n.t( "coords_viewable_for_proj_label" )}
              tipText={I18n.t( "coords_viewable_for_proj_desc" )}
              checked="true"
            />
          ) }
        </div>
        <div className="form-group">
          <label className="sectionlabel">
            { I18n.t( "place" ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon fa fa-globe" />
            <PlaceAutocomplete
              resetOnChange={false}
              initialPlaceID={
                params.place_id && params.place_id !== "any" ? params.place_id : null
              }
              bootstrapClear
              className={params.place_id ? "filter-changed" : ""}
              afterSelect={result => {
                updateSearchParams( {
                  place_id: config.testingApiV2 ? result.item.uuid : result.item.id
                } );
              }}
              afterUnselect={( ) => {
                updateSearchParams( { place_id: null } );
              }}
            />
            <input type="hidden" name="place_id" />
          </div>
        </div>
      </Col>
    );
    const chosenTerm = terms.find( t => t.id === params.term_id );
    const rejectedTerm = terms.find( t => t.id === params.without_term_id );
    let defaultAccountAge = "";
    if ( params.user_after ) {
      defaultAccountAge = "recent";
    } else if ( params.user_before ) {
      defaultAccountAge = "established";
    }
    const moreCenterCol = (
      <Col xs="4" className="filters-center-col">
        <div className="form-group annotations-form-group">
          <label className="sectionlabel">{ I18n.t( "with_annotation" ) }</label>
          <select
            id="params-term-id"
            className={`form-control ${params.term_id ? "filter-changed" : ""}`}
            defaultValue={params.term_id}
            onChange={e => {
              if ( _.isEmpty( e.target.value ) ) {
                updateSearchParams( { term_id: "", term_value_id: "" } );
              } else {
                updateSearchParams( { term_id: e.target.value } );
              }
            }}
          >
            <option value="">
              { I18n.t( "none" ) }
            </option>
            { terms.map( t => (
              <option value={t.id} key={`with-term-id-${t.id}`}>
                { I18n.t( `controlled_term_labels.${_.snakeCase( t.label )}` ) }
              </option>
            ) ) }
          </select>
          { chosenTerm ? (
            <div className="term-value">
              <big>=</big>
              <select
                id="params-term-value-id"
                className={`form-control ${params.term_value_id ? "filter-changed" : ""}`}
                defaultValue={params.term_value_id}
                onChange={e => updateSearchParams( { term_value_id: e.target.value } )}
              >
                <option value="">
                  { I18n.t( "any_" ) }
                </option>
                { chosenTerm.values.map( t => (
                  <option value={t.id} key={`annotation-term-value-id-${t.id}`}>
                    { I18n.t( `controlled_term_labels.${_.snakeCase( t.label )}` ) }
                  </option>
                ) ) }
              </select>
            </div>
          ) : null }
        </div>
        <div className="form-group annotations-form-group">
          <label className="sectionlabel">{ I18n.t( "without_annotation" ) }</label>
          <select
            id="params-without-term-id"
            className={`form-control ${params.without_term_id ? "filter-changed" : ""}`}
            defaultValue={params.without_term_id || params.term_id}
            onChange={e => {
              if ( _.isEmpty( e.target.value ) ) {
                updateSearchParams( { without_term_id: "", without_term_value_id: "" } );
              } else {
                updateSearchParams( { without_term_id: e.target.value } );
              }
            }}
          >
            <option value="">
              { I18n.t( "none" ) }
            </option>
            { terms.map( t => (
              <option value={t.id} key={`without-term-id-${t.id}`}>
                { I18n.t( `controlled_term_labels.${_.snakeCase( t.label )}` ) }
              </option>
            ) ) }
          </select>
          { ( rejectedTerm || chosenTerm ) && (
            <div className="term-value">
              <big>=</big>
              <select
                id="params-term-value-id"
                className={`form-control ${params.without_term_value_id ? "filter-changed" : ""}`}
                defaultValue={params.without_term_value_id}
                onChange={e => updateSearchParams( { without_term_value_id: e.target.value } )}
              >
                <option value="">
                  { I18n.t( "any_" ) }
                </option>
                { ( rejectedTerm || chosenTerm ).values.map( t => (
                  <option value={t.id} key={`without-term-value-id-${t.id}`}>
                    { I18n.t( `controlled_term_labels.${_.snakeCase( t.label )}` ) }
                  </option>
                ) ) }
              </select>
            </div>
          ) }
        </div>
        <div className="form-group recent-users-form-group">
          <label htmlFor="account-creation" className="sectionlabel">{ I18n.t( "account_creation" ) }</label>
          <select
            id="account-creation"
            defaultValue={defaultAccountAge}
            className={`form-control ${params.user_before || params.user_after ? "filter-changed" : ""}`}
            onChange={e => {
              if ( _.isEmpty( e.target.value ) ) {
                updateSearchParams( { user_after: null, user_before: null } );
              } else if ( e.target.value === "recent" ) {
                updateSearchParams( { user_after: "1w", user_before: null } );
              } else if ( e.target.value === "established" ) {
                updateSearchParams( { user_before: "1w", user_after: null } );
              }
            }}
          >
            <option value="">
              { I18n.t( "any_" ) }
            </option>
            <option value="recent">
              { I18n.t( "in_the_past_week" ) }
            </option>
            <option value="established">
              { I18n.t( "more_than_a_week_ago" )}
            </option>
          </select>
        </div>
      </Col>
    );
    const moreRightCol = (
      <Col xs="4">
        <label className="sectionlabel">
          { I18n.t( "date_added" ) }
        </label>
        <DateFilters
          params={params}
          updateSearchParams={updateSearchParams}
          prefix="created"
        />
      </Col>
    );
    const moreFilters = (
      <div id="more-filters" className={moreFiltersHidden ? "hidden" : ""}>
        <Row className="filters-row">
          { moreLeftCol }
          { moreCenterCol }
          { moreRightCol }
        </Row>
      </div>
    );
    const popover = (
      <Grid className="FiltersButtonContainer">
        <div className="filters-body">
          { mainFilters }
          <Row>
            <Col xs="12">
              <Button
                bsStyle="link"
                className={`filters-more-btn ${moreFiltersHidden ? "collapsed" : ""}`}
                onClick={( ) => {
                  this.setState( { moreFiltersHidden: !moreFiltersHidden } );
                }}
              >
                { I18n.t( "more_filters" ) }
                &nbsp;
                <i className="fa fa-caret-down" />
                <i className="fa fa-caret-up" />
              </Button>
              { moreFilters }
            </Col>
          </Row>
        </div>
        <Row className="filters-footer FiltersButtonFooter">
          <Col xs="12">
            <Button bsStyle="primary" onClick={() => closeFilters( )}>
              { I18n.t( "update_search" ) }
            </Button>
            <Button onClick={( ) => resetParams( )}>
              { I18n.t( "reset_search_filters" ) }
            </Button>
            <div className="feeds pull-right">
              <a
                className="btn btn-link"
                href={`/observations.atom?${paramsForUrl( )}`}
                target="_self"
              >
                <i className="fa fa-rss" />
                <span>{ I18n.t( "atom" ) }</span>
              </a>
              <a
                className="btn btn-link"
                href={`/observations/export?${paramsForUrl( )}`}
                target="_self"
              >
                <i className="fa fa-download" />
                <span>{ I18n.t( "download" ) }</span>
              </a>
            </div>
          </Col>
        </Row>
      </Grid>
    );
    return (
      <span className="FiltersButtonWrapper">
        <Button
          bsRole="toggle"
          bsStyle="default"
          className="FiltersButton"
          ref={this.target}
          onClick={( ) => this.toggle( )}
        >
          <i className="fa fa-sliders" />
          { " " }
          { I18n.t( "filters" ) }
          &nbsp;
          <span className="badge">
            { numFiltersSet( ) }
          </span>
        </Button>
        <Overlay
          show={show}
          onHide={( ) => this.setState( { show: false } )}
          container={$( "#wrapper.bootstrap" ).get( 0 )}
          placement="bottom"
          target={( ) => ReactDOM.findDOMNode( this.target.current )}
        >
          <Popover
            id="FiltersButtonPopover"
            className="FiltersButtonPopover"
            placement="bottom"
          >
            {popover}
          </Popover>
        </Overlay>
      </span>
    );
  }
}

FiltersButton.propTypes = {
  config: PropTypes.object,
  params: PropTypes.object,
  defaultParams: PropTypes.object,
  updateSearchParams: PropTypes.func,
  replaceSearchParams: PropTypes.func,
  terms: PropTypes.array
};

FiltersButton.defaultProps = {
  terms: []
};

export default FiltersButton;
