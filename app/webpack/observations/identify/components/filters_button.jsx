import React, { PropTypes } from "react";
import { Button, OverlayTrigger, Popover, Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import { DEFAULT_PARAMS } from "../reducers/search_params_reducer";
import PlaceAutocomplete from "./place_autocomplete";
import ProjectAutocomplete from "./project_autocomplete";
import UserAutocomplete from "./user_autocomplete";

class FiltersButton extends React.Component {
  constructor( props ) {
    super( props );
    const params = props.params;
    const diffs = _.difference( _.values( params ), _.values( DEFAULT_PARAMS ) );
    this.state = {
      moreFiltersHidden: diffs.length === 0
    };
  }
  render() {
    const { params, updateSearchParams } = this.props;
    const paramsForUrl = ( ) => {
      // TODO filter out params that only apply to this component
      return window.location.search.replace( /^\?/, "" );
    };
    const closeFilters = ( ) => {
      // yes it's a horrible hack
      $( ".FiltersButton" ).click( );
    };
    const resetParams = ( ) => updateSearchParams( DEFAULT_PARAMS );
    const numFiltersSet = ( ) => {
      const diffs = _.difference( _.values( params ), _.values( DEFAULT_PARAMS ) );
      return diffs.length > 0 ? diffs.length.toString() : "";
    };
    const filterCheckbox = ( checkbox ) => {
      const checkedVal = ( checkbox.checked || true );
      return (
        <div className="checkbox" key={`filters-${checkbox.param}-${checkbox.label}`}>
          <label>
            <input
              type="checkbox"
              defaultChecked={ params[checkbox.param] === checkedVal }
              onChange={ ( e ) => {
                let newVal = checkbox.unchecked;
                if ( e.target.checked ) newVal = checkedVal;
                updateSearchParams( {
                  [checkbox.param]: newVal
                } );
              }}
            /> { _.capitalize( I18n.t( checkbox.label || checkbox.param ) ) }
          </label>
        </div>
      );
    };
    const visibleRanks = [
      "kingdom",
      "phylum",
      "subphylum",
      "superclass",
      "class",
      "subclass",
      "superorder",
      "order",
      "suborder",
      "infraorder",
      "superfamily",
      "epifamily",
      "family",
      "subfamily",
      "supertribe",
      "tribe",
      "subtribe",
      "genus",
      "genushybrid",
      "species",
      "hybrid",
      "subspecies",
      "variety",
      "form"
    ];
    const orderByFields = [
      { value: "observations.id", default: "date added", key: "date_added" },
      { value: "observed_on", default: "date observed", key: "date_observed" },
      { value: "votes", default: "faves", key: "faves" }
    ];
    const monthNames = ( "january february march april may june july august " +
      "september october november december" ).split( " " );
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
          title={ _.capitalize( I18n.t( t.label ) ) }
          key={`btn-${t.name}`}
          onClick={ ( ) => {
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
          } }
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
              { _.capitalize( I18n.t( "show" ) ) }
            </label>
          </Col>
        </Row>
        <Row id="show-filters">
          <Col id="filters-left-col" xs="6">
            { [
              { param: "wild" },
              { param: "verifiable", label: "verifiable", unchecked: "any" },
              { param: "quality_grade", label: "research_grade", checked: "research", unchecked: "any" },
              { param: "quality_grade", label: "needs_id", checked: "needs_id", unchecked: "any" },
              { param: "threatened" }
            ].map( filterCheckbox ) }
          </Col>
          <Col id="filters-left-col" xs="6">
            { [
              { param: "introduced" },
              { param: "popular" },
              { param: "sounds", label: "has_sounds" },
              { param: "photos", label: "has_photos" },
              { param: "user_id", label: "your_observations", checked: CURRENT_USER.id }
            ].map( filterCheckbox ) }
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <div className="form-group">
              <label className="sectionlabel" htmlFor="params-q">
                { I18n.t( "description_slash_tags" ) }
              </label>
              <input
                id="params-q"
                className="form-control"
                placeholder={ I18n.t( "blue_butterfly_etc" ) }
                value={ params.q }
                onChange={ ( e ) => {
                  updateSearchParams( { q: e.target.value } );
                } }
              />
            </div>
          </Col>
        </Row>
      </Col>
    );
    const mainCenterCol = (
      <Col xs="4" id="filters-center-col">
        <Row>
          <Col xs="12">
            <label className="sectionlabel">
              { _.capitalize( I18n.t( "categories" ) ) }
            </label>
            <div id="filters-categories" className="btn-group">
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
                { name: "Unknown", label: "unknown" }
              ].map( iconicTaxonButton ) }
            </div>
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel" htmlFor="params-hrank">
              { _.capitalize( I18n.t( "rank" ) ) }
            </label>
          </Col>
        </Row>
        <Row id="filters-ranks">
          <Col xs="6">
            <select
              id="params-hrank"
              className={`form-control ${params.hrank ? "filter-changed" : ""}`}
              defaultValue={params.hrank}
              onChange={ e => updateSearchParams( { hrank: e.target.value } ) }
            >
              <option value="">
                { _.capitalize( I18n.t( "high" ) ) }
              </option>
              { visibleRanks.map( rank => (
                <option key={`params-hrank-${rank}`} value={rank}>
                  { _.capitalize( I18n.t( `ranks.${rank}` ) ) }
                </option>
              ) ) }
            </select>
          </Col>
          <Col xs="6">
            <select
              id="params-lrank"
              className={`form-control ${params.lrank ? "filter-changed" : ""}`}
              defaultValue={params.lrank}
              onChange={ e => updateSearchParams( { lrank: e.target.value } ) }
            >
              <option value="">
                { _.capitalize( I18n.t( "low" ) ) }
              </option>
              { visibleRanks.map( rank => (
                <option key={`params-hrank-${rank}`} value={rank}>
                  { _.capitalize( I18n.t( `ranks.${rank}` ) ) }
                </option>
              ) ) }
            </select>
          </Col>
        </Row>
        <Row>
          <Col xs="12">
            <label className="sectionlabel" htmlFor="params-order-by">
              { _.capitalize( I18n.t( "sort_by" ) ) }
            </label>
          </Col>
        </Row>
        <Row>
          <Col xs="6">
            <select
              id="params-order-by"
              className={
                "form-control" +
                ` ${params.order_by !== DEFAULT_PARAMS.order_by ? "filter-changed" : ""}`
              }
              onChange={ e => updateSearchParams( { order_by: e.target.value } ) }
            >
              { orderByFields.map( field => (
                <option value={field.value} key={`params-order-by-${field.value}`}>
                  { _.capitalize( I18n.t( field.key, { defaultValue: field.default } ) ) }
                </option>
              ) ) }
            </select>
          </Col>
          <Col xs="6">
            <select
              id="params-order"
              defaultValue="desc"
              className={
                "form-control" +
                ` ${params.order !== DEFAULT_PARAMS.order ? "filter-changed" : ""}`
              }
              onChange={ e => updateSearchParams( { order: e.target.value } ) }
            >
              <option value="asc">
                { I18n.t( "asc" ) }
              </option>
              <option value="desc">
                { I18n.t( "desc" ) }
              </option>
            </select>
          </Col>
        </Row>
      </Col>
    );
    const mainRightCol = (
      <Col xs="4" id="filters-right-col">
        <label className="sectionlabel">
          { _.capitalize( I18n.t( "date_observed" ) ) }
        </label>
        <div className="filters-dates">
          <label className="radio">
            <input
              type="radio"
              name="date-type"
              value=""
              defaultChecked={ !params.dateType }
              onChange={ e => updateSearchParams( { dateType: e.target.value } ) }
            />
            { _.capitalize( I18n.t( "any" ) ) }
          </label>
          <label className="radio">
            <input
              type="radio"
              name="date-type"
              value="exact"
              defaultChecked={ params.dateType === "exact" }
              onChange={ e => updateSearchParams( { dateType: e.target.value } ) }
            />
            <span className="date-type date-type-exact">
              { I18n.t( "exact_date" ) }
              <input
                className={
                  `filters-dates-exact form-control input-sm date-picker ${params.on ? "filter-changed" : ""}`
                }
                type="text"
                placeholder="YYYY-MM-DD"
                onClick={ ( ) => updateSearchParams( { dateType: "exact" } ) }
                onChange={ e => updateSearchParams( { on: e.target.value } ) }
              />
            </span>
          </label>
          <label className="radio">
            <input
              type="radio"
              name="date-type"
              value="range"
              defaultChecked={ params.dateType === "range" }
            />
            <span className="date-type date-type-range">
              { I18n.t( "range" ) }
              <input
                className={
                  `form-control.input-sm.date-picker ${params.d1 ? "filter-changed" : ""}`
                }
                type="text"
                placeholder={ I18n.t( "start" ) }
                onClick={ ( ) => updateSearchParams( { dateType: "range" } ) }
                onChange={ e => updateSearchParams( { d1: e.target.value } ) }
              />
              <input
                className={
                  `form-control.input-sm.date-picker ${params.d2 ? "filter-changed" : ""}`
                }
                type="text"
                placeholder={ I18n.t( "end" ) }
                onClick={ ( ) => updateSearchParams( { dateType: "range" } ) }
                onChange={ e => updateSearchParams( { d2: e.target.value } ) }
              />
            </span>
          </label>
          <label className="radio">
            <input
              type="radio"
              name="date-type"
              value="month"
              defaultChecked={ params.dateType === "month" }
            />
            <span className="date-type date-type-month">
              { I18n.t( "months" ) }
              <select
                className={`form-control input-sm ${params.month ? "filter-changed" : ""}`}
                id="filters-dates-month"
                multiple="multiple"
              >
                { monthNames.map( month => {
                  const i = monthNames.indexOf( month );
                  return (
                    <option value={i} key={`filters-dates-month-${i}`}>
                      { I18n.t( `date_format.month.${month}` ) }
                    </option>
                  );
                } ) }
              </select>
            </span>
          </label>
        </div>
        <div
          id="filters-observation-fields"
          className={ canShowObservationFields( ) ? "" : "collapse" }
        >
          <label className="sectionlabel">
            { I18n.t( "observation_fields" ) }
          </label>
          { _.forEach( params.observationFields, ( v, k ) => (
            <span className="observation-field" key={`observation-field-${k}`}>
              { k }={ v }
              <button
                onClick={ ( ) => {
                  updateSearchParams( {
                    observationFields: _.omit( params.observationFields, [k] )
                  } );
                } }
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
          <input type="hidden" name="changed_fields" />
          <input type="hidden" name="changed_since" />
          <input type="hidden" name="change_project_id" />
        </div>
      </Col>
    );
    const mainFilters = (
      <Row>
        { mainLeftCol }
        { mainCenterCol}
        { mainRightCol }
      </Row>
    );
    const moreLeftCol = (
      <Col xs="4">
        <div className="form-group">
          <label className="sectionlabel" htmlFor="params-user-id">
            { _.capitalize( I18n.t( "person" ) ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon icon-person"></span>
            <UserAutocomplete
              resetOnChange={false}
              initialUserID={params.user_id}
              bootstrapClear
              className={params.user_id ? "filter-changed" : ""}
              afterSelect={ function ( result ) {
                updateSearchParams( { user_id: result.item.id } );
              } }
              afterUnselect={ function ( ) {
                updateSearchParams( { user_id: null } );
              } }
            />
            <input value={ params.user_id } type="hidden" name="user_id" />
          </div>
        </div>
        <div className="form-group">
          <label className="sectionlabel" htmlFor="params-project-id">
            { _.capitalize( I18n.t( "project" ) ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon fa fa-briefcase"></span>
            <ProjectAutocomplete
              resetOnChange={false}
              initialProjectID={params.project_id}
              bootstrapClear
              className={params.project_id ? "filter-changed" : ""}
              afterSelect={ function ( result ) {
                updateSearchParams( { project_id: result.item.id } );
              } }
              afterUnselect={ function ( ) {
                updateSearchParams( { project_id: null } );
              } }
            />
            <input value={ params.project_id } type="hidden" name="project_id" />
          </div>
        </div>
        <div className="form-group">
          <label className="sectionlabel" htmlForm="params-place-name">
            { _.capitalize( I18n.t( "place" ) ) }
          </label>
          <div className="input-group">
            <span className="input-group-addon fa fa-globe"></span>
            <PlaceAutocomplete
              resetOnChange={false}
              initialPlaceID={params.place_id}
              bootstrapClear
              className={params.place_id ? "filter-changed" : ""}
              afterSelect={ function ( result ) {
                updateSearchParams( { place_id: result.item.id } );
              } }
              afterUnselect={ function ( ) {
                updateSearchParams( { place_id: null } );
              } }
            />
            <input type="hidden" name="place_id" />
          </div>
        </div>
      </Col>
    );
    const moreCenterCol = (
      <Col xs="4">
        <div className="form-group">
          <label className="sectionlabel">
            { _.capitalize( I18n.t( "photo_licensing" ) ) }
          </label>
          <select
            className={`form-control ${params.photo_license ? "filter-changed" : ""}`}
            value={ params.photo_license }
          >
            <option value="">{ I18n.t( "all" ) }</option>
            {licenses.map( ( code ) => (
              <option key={`photo-licenses-${code}`} value={ code }>{ code }</option>
            ) ) }
          </select>
        </div>
        <label className="sectionlabel">
          { I18n.t( "reviewed" ) }
        </label>
        <div className={`form-group ${params.reviewed ? "filter-changed" : ""}`}>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed-any"
              defaultChecked={params.reviewed === undefined || params.reviewed === null}
            />
            { I18n.t( "any" ).toLowerCase( ) }
          </label>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed-yes"
              value="true"
              defaultChecked={params.reviewed === true}
            />
            { I18n.t( "yes" ).toLowerCase( ) }
          </label>
          <label className="radio-inline">
            <input
              type="radio"
              name="reviewed-no"
              value="false"
              defaultChecked={params.reviewed === false}
            />
            { I18n.t( "no" ).toLowerCase( ) }
          </label>
        </div>
      </Col>
    );
    const moreRightCol = (
      <Col xs="4">
        <label className="sectionlabel">
          { _.capitalize( I18n.t( "date_added" ) ) }
        </label>
        <div className="filters-dates">
          <label className="radio">
            <input type="radio" name="created-date-type" defaultChecked={ !params.createdDateType } />
            { _.capitalize( I18n.t( "any" ) ) }
          </label>
          <label className="radio">
            <input
              type="radio"
              name="created-date-type"
              value="exact"
              defaultChecked={ params.createdDateType === "exact" }
            />
            <span className="date-type date-type-exact">
              { I18n.t( "exact_date" ) }
              <input
                className={
                  `filters-dates-exact form-control input-sm date-picker ${params.created_on ? "filter-changed" : ""}`
                }
                type="text"
                placeholder="YYYY-MM-DD"
                value={ params.created_on }
                onClick={ ( ) => updateSearchParams( { createdDateType: "exact" } ) }
                onChange={ e => updateSearchParams( { created_on: e.target.value } ) }
              />
            </span>
          </label>
          <label className="radio">
            <input
              type="radio"
              name="created-date-type"
              value="range"
              defaultChecked={ params.createdDateType === "range" }
            />
            <span className="date-type date-type-range">
              { I18n.t( "range" ) }
              <input
                className={
                  `form-control input-sm.date-picker ${params.created_d1 ? "filter-changed" : ""}`
                }
                type="text"
                placeholder={ I18n.t( "start" ) }
                onClick={ ( ) => updateSearchParams( { createdDateType: "range" } ) }
                onChange={ e => updateSearchParams( { created_d1: e.target.value } ) }
              />
              <input
                className={
                  `form-control input-sm.date-picker ${params.created_d2 ? "filter-changed" : ""}`
                }
                type="text"
                placeholder={ I18n.t( "end" ) }
                onClick={ ( ) => updateSearchParams( { createdDateType: "range" } ) }
                onChange={ e => updateSearchParams( { created_d2: e.target.value } ) }
              />
            </span>
          </label>
        </div>
      </Col>
    );
    const moreFilters = (
      <div id="more-filters" className={this.state.moreFiltersHidden ? "hidden" : ""}>
        <Row>
          { moreLeftCol }
          { moreCenterCol }
          { moreRightCol }
        </Row>
      </div>
    );
    const popover = (
      <Popover id="FiltersButtonPopover" className="FiltersButtonPopover">
        <Grid className="FiltersButtonContainer">
          <div id="filters-body">
            { mainFilters }
            <Row>
              <Col xs="12">
                <Button
                  id="filters-more-btn"
                  bsStyle="link"
                  className={this.state.moreFiltersHidden ? "collapsed" : ""}
                  onClick={() => {
                    this.setState( { moreFiltersHidden: !this.state.moreFiltersHidden } );
                  }}
                >
                  { _.capitalize( I18n.t( "more_filters" ) ) }
                  &nbsp;
                  <i className="fa fa-caret-down"></i>
                  <i className="fa fa-caret-up"></i>
                </Button>
                { moreFilters }
              </Col>
            </Row>
          </div>
          <Row id="filters-footer" className="FiltersButtonFooter">
            <Col xs="12">
              <Button bsStyle="primary" onClick={ () => closeFilters( ) }>
                { _.capitalize( I18n.t( "update_search" ) ) }
              </Button>
              <Button onClick={ ( ) => resetParams( ) }>
                { _.capitalize( I18n.t( "reset_search_filters" ) ) }
              </Button>
              <div id="feeds" className="feeds pull-right">
                <a
                  className="btn btn-link" href={`/observations.atom?${paramsForUrl( )}`}
                  target="_self"
                >
                  <i className="fa fa-rss"></i>
                  <span>{ I18n.t( "atom" ) }</span>
                </a>
                <a
                  className="btn btn-link" href={`/observations.kml?${paramsForUrl( )}`}
                  target="_self"
                >
                  <i className="fa fa-globe"></i>
                  <span>{ I18n.t( "kml" ) }</span>
                </a>
                <a
                  className="btn btn-link" href={`/observations/export?${paramsForUrl( )}`}
                  target="_self"
                >
                  <i className="fa fa-download"></i>
                  <span>{ I18n.t( "download" ) }</span>
                </a>
              </div>
            </Col>
          </Row>
        </Grid>
      </Popover>
    );
    return (
      <OverlayTrigger
        trigger="click"
        rootClose
        placement="bottom"
        overlay={popover}
      >
        <Button bsRole="toggle" bsStyle="default" className="FiltersButton">
          <i className="fa fa-sliders"></i> { I18n.t( "filters" ) }
          &nbsp;
          <span className="badge">
            { numFiltersSet( ) }
          </span>
        </Button>
      </OverlayTrigger>
    );
  }
}

FiltersButton.propTypes = {
  params: PropTypes.object,
  updateSearchParams: PropTypes.func
};

export default FiltersButton;
