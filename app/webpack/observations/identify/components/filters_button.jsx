import React, { PropTypes } from "react";
import { Button, Dropdown, Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import { DEFAULT_PARAMS } from "../reducers/search_params_reducer";

const FiltersButton = ( {
  params,
  updateSearchParams
} ) => {
  const filterCheckbox = ( checkbox ) => {
    const checkedVal = ( checkbox.checked || true );
    return (
      <div className="checkbox" key={`filters-${checkbox.param}-${checkbox.label}`}>
        <label>
          <input
            type="checkbox"
            checked={ params[checkbox.param] === checkedVal }
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
  return (
    <Dropdown id="filter-container" className="FiltersButton">
      <Button bsRole="toggle" bsStyle="default">
        <i className="fa fa-sliders"></i>
        { I18n.t( "filters" ) }
        <span className="badge">3</span>
      </Button>
      <div bsRole="menu" className="dropdown-menu ">
        <Grid id="filter-dropdown">
          <div id="filters-body">
            <Row>
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
                      { param: "quality_grade", label: "research_grade", checked: "research" },
                      { param: "quality_grade", label: "needs_id", checked: "needs_id" },
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
                        { name: "Mollusca", label: "mollusks" },
                        { name: "Arachnida", label: "arachnids" },
                        { name: "Insecta", label: "insects" },
                        { name: "Plantae", label: "plants" },
                        { name: "Fungi", label: "fungi" },
                        { name: "Protozoa", label: "protozoans" },
                        { name: "Unknown", label: "unknown" }
                      ].map( t => {
                        let cssClass = "iconic-taxon";
                        // if ( ( i + 1 ) % 6 === 0 ) {
                        //   cssClass += " last";
                        // }
                        if ( _.includes( params.iconic_taxa, t.name ) ) {
                          cssClass += " filter-changed active";
                        }
                        return (
                          <Button
                            className={cssClass}
                            title={ I18n.t( t.label ) }
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
                      } ) }
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
                      checked={ !params.dateType }
                      onChange={ e => updateSearchParams( { dateType: e.target.value } ) }
                    />
                    { _.capitalize( I18n.t( "any" ) ) }
                  </label>
                  <label className="radio">
                    <input
                      type="radio"
                      name="date-type"
                      value="exact"
                      checked={ params.dateType === "exact" }
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
                      checked={ params.dateType === "range" }
                      onChange={ e => updateSearchParams( { dateType: e.target.value } ) }
                    />
                    <span className="date-type date-type-range">
                      { I18n.t( "range" ) }
                      <input
                        className={
                          `form-control.input-sm.date-picker ${params.d1 ? "filter-changed" : ""}`
                        }
                        type="text"
                        placeholder={ I18n.t( "start" ) }
                        onClick={ ( ) => updateSearchParams( { dateType: "exact" } ) }
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
                      checked={ params.dateType === "month" }
                      onChange={ e => updateSearchParams( { dateType: e.target.value } ) }
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
                <div id="filters-observation-fields" className={ canShowObservationFields( ) ? "" : "collapse" }>
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
            </Row>
          </div>
        </Grid>
      </div>
    </Dropdown>
  );
};

FiltersButton.propTypes = {
  params: PropTypes.object,
  updateSearchParams: PropTypes.func
};

export default FiltersButton;
