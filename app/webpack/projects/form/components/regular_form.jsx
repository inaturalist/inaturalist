import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonAutocomplete from "../../../observations/uploader/components/taxon_autocomplete";
import PlaceAutocomplete from "../../../observations/identify/components/place_autocomplete";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";
import util from "../../../observations/show/util";
import SplitTaxon from "../../../shared/components/split_taxon";
import DateTimeFieldWrapper from
  "../../../observations/uploader/components/date_time_field_wrapper";
import JQueryUIMultiselect from "../../../observations/identify/components/jquery_ui_multiselect";

class RegularForm extends React.Component {

  qualityGradeValues( ) {
    const checkedInputs = $( "input[name=quality_grade]:checked", ReactDOM.findDOMNode( this ) );
    return _.map( checkedInputs, a => a.value ).join( "," ) || null;
  }

  render( ) {
    const {
      config,
      project,
      addProjectRule,
      removeProjectRule,
      setRulePreference,
      updateProject
    } = this.props;
    const monthNames = ( "january february march april may june july august " +
      "september october november december" ).split( " " );
    return (
      <div id="RegularForm" className="Form">
        <Grid>
          <Row className="text">
            <Col xs={12}>
              <h2>{ I18n.t( "observation_requirements" ) }</h2>
              <div className="help-text">
                { I18n.t( "views.projects.new.please_specify_the_requirements" ) }
              </div>
            </Col>
          </Row>
          <Row>
            <Col xs={4}>
              <label>{ I18n.t( "taxa" ) }</label>
              <TaxonAutocomplete
                ref="ta"
                bootstrap
                perPage={ 6 }
                searchExternal={ false }
                onSelectReturn={ e => {
                  addProjectRule( "in_taxon?", "Taxon", e.item );
                  this.refs.ta.inputElement( ).val( "" );
                } }
                config={ config }
                placeholder={ I18n.t( "taxon_autocomplete_placeholder" ) }
              />
              { !_.isEmpty( project.taxonRules ) && (
                <div className="icon-previews">
                  { _.map( project.taxonRules, taxonRule => (
                    <div className="icon-preview" key={ `taxon_rule_${taxonRule.taxon.id}` }>
                      { util.taxonImage( taxonRule.taxon ) }
                      <SplitTaxon
                        taxon={ taxonRule.taxon }
                        user={ config.currentUser }
                      />
                      <i
                        className="fa fa-times-circle"
                        onClick={ ( ) => removeProjectRule( taxonRule ) }
                      />
                    </div>
                  ) ) }
                </div>
              ) }
            </Col>
            <Col xs={4}>
              <label>{ I18n.t( "places" ) }</label>
              <div className="input-group">
                <span className="input-group-addon fa fa-globe"></span>
                <PlaceAutocomplete
                  ref="pa"
                  afterSelect={ e => {
                    addProjectRule( "observed_in_place?", "Place", e.item );
                    this.refs.pa.inputElement( ).val( "" );
                  } }
                  bootstrapClear
                  config={ config }
                  placeholder={ I18n.t( "place_autocomplete_placeholder" ) }
                />
              </div>
              { !_.isEmpty( project.placeRules ) && (
                <div className="icon-previews">
                  { _.map( project.placeRules, placeRule => (
                    <div className="badge-div" key={ `place_rule_${placeRule.place.id}` }>
                      <span className="badge">
                        { placeRule.place.display_name }
                        <i
                          className="fa fa-times-circle-o"
                          onClick={ ( ) => removeProjectRule( placeRule ) }
                        />
                      </span>
                    </div>
                  ) ) }
                </div>
              ) }
            </Col>
            <Col xs={4}>
              <label>{ I18n.t( "users" ) }</label>
              <div className="input-group">
                <span className="input-group-addon fa fa-briefcase"></span>
                <UserAutocomplete
                  ref="ua"
                  afterSelect={ e => {
                    e.item.id = e.item.user_id;
                    addProjectRule( "observed_by_user?", "User", e.item );
                    this.refs.ua.inputElement( ).val( "" );
                  } }
                  bootstrapClear
                  config={ config }
                  placeholder={ I18n.t( "user_autocomplete_placeholder" ) }
                />
              </div>
              { !_.isEmpty( project.userRules ) && (
                <div className="icon-previews">
                  { _.map( project.userRules, userRule => (
                    <div className="badge-div" key={ `user_rule_${userRule.user.id}` }>
                      <span className="badge">
                        { userRule.user.login }
                        <i
                          className="fa fa-times-circle-o"
                          onClick={ ( ) => removeProjectRule( userRule ) }
                        />
                      </span>
                    </div>
                  ) ) }
                </div>
              ) }
            </Col>
          </Row>
          <Row>
            <Col xs={4}>
              <label>Data Quality</label>
              <input
                type="checkbox"
                id="project-quality-research"
                name="quality_grade"
                value="research"
                defaultChecked={ project.rule_quality_grade.research }
                onChange={ ( ) => setRulePreference( "quality_grade", this.qualityGradeValues( ) ) }
              />
              <label className="inline" htmlFor="project-quality-research">
                { I18n.t( "research_" ) }
              </label>
              <input
                type="checkbox"
                id="project-quality-needs-id"
                name="quality_grade"
                value="needs_id"
                defaultChecked={ project.rule_quality_grade.needs_id }
                onChange={ ( ) => setRulePreference( "quality_grade", this.qualityGradeValues( ) ) }
              />
              <label className="inline" htmlFor="project-quality-needs-id">
                { I18n.t( "needs_id_" ) }
              </label>
              <input
                type="checkbox"
                id="project-quality-casual"
                name="quality_grade"
                value="casual"
                defaultChecked={ project.rule_quality_grade.casual }
                onChange={ ( ) => setRulePreference( "quality_grade", this.qualityGradeValues( ) ) }
              />
              <label className="inline" htmlFor="project-quality-casual">
                { I18n.t( "casual_" ) }
              </label>
            </Col>
            <Col xs={8}>
              <label>{ I18n.t( "media_type" ) }</label>
              <input
                type="radio"
                name="project-media"
                id="project-media-any"
                defaultChecked={ !project.rule_photos && !project.rule_sounds }
                onChange={ ( ) => {
                  setRulePreference( "photos", null );
                  setRulePreference( "sounds", null );
                } }
              />
              <label className="inline" htmlFor="project-media-any">
                { I18n.t( "any_" ) }
              </label>
              <input
                type="radio"
                name="project-media"
                id="project-media-sounds"
                defaultChecked={ project.rule_sounds && !project.rule_photos }
                onChange={ ( ) => {
                  setRulePreference( "sounds", "true" );
                  setRulePreference( "photos", null );
                } }
              />
              <label className="inline" htmlFor="project-media-sounds">
                { I18n.t( "has_sound" ) }
              </label>
              <input
                type="radio"
                name="project-media"
                id="project-media-photos"
                defaultChecked={ project.rule_photos && !project.rule_sounds }
                onChange={ ( ) => {
                  setRulePreference( "photos", "true" );
                  setRulePreference( "sounds", null );
                } }
              />
              <label className="inline" htmlFor="project-media-photos">
                { I18n.t( "has_photo" ) }
              </label>
              <input
                type="radio"
                name="project-media"
                id="project-media-both"
                defaultChecked={ project.rule_photos && project.rule_sounds }
                onChange={ ( ) => {
                  setRulePreference( "photos", "true" );
                  setRulePreference( "sounds", "true" );
                } }
              />
              <label className="inline" htmlFor="project-media-both">
                { I18n.t( "has_photo_and_sound" ) }
              </label>
            </Col>
          </Row>
          <Row className="date-row">
            <Col xs={12}>
              <label>{ I18n.t( "date_observed_" ) }</label>
              <input
                type="radio"
                id="project-date-type-any"
                checked={ project.date_type === "any" }
                onChange={ ( ) => updateProject( { date_type: "any" } ) }
              />
              <label className="inline" htmlFor="project-date-type-any">
                { I18n.t( "any_" ) }
              </label>
              <input
                type="radio"
                id="project-date-type-exact"
                checked={ project.date_type === "exact" }
                onChange={ ( ) => updateProject( { date_type: "exact" } ) }
              />
              <label className="inline" htmlFor="project-date-type-exact">
                { I18n.t( "exact" ) }
              </label>
              <DateTimeFieldWrapper
                mode="date"
                ref="exactDate"
                inputFormat="YYYY-MM-DD"
                defaultText={ project.rule_observed_on }
                onChange={ date => setRulePreference( "observed_on", date ) }
                allowFutureDates
                inputProps={ {
                  className: "form-control",
                  placeholder: "YYYY-MM-DD",
                  onClick: ( ) => this.refs.exactDate.onClick( )
                } }
              />
            </Col>
          </Row>
          <Row className="date-row">
            <Col xs={12} className="date-range-col">
              <input
                type="radio"
                id="project-date-type-range"
                checked={ project.date_type === "range" }
                onChange={ ( ) => updateProject( { date_type: "range" } ) }
              />
              <label className="inline" htmlFor="project-date-type-range">
                { I18n.t( "date_picker.range" ) }
              </label>
              <DateTimeFieldWrapper
                mode="datetime"
                ref="dateRangeD1"
                inputFormat="YYYY-MM-DD HH:mm Z"
                defaultText={ project.rule_d1 }
                onChange={ date => setRulePreference( "d1", date ) }
                allowFutureDates
                inputProps={ {
                  className: "form-control",
                  placeholder: I18n.t( "start_date_time" ),
                  onClick: ( ) => this.refs.dateRangeD1.onClick( )
                } }
              />
              <DateTimeFieldWrapper
                mode="datetime"
                ref="dateRangeD2"
                inputFormat="YYYY-MM-DD HH:mm Z"
                defaultText={ project.rule_d2 }
                onChange={ date => setRulePreference( "d2", date ) }
                allowFutureDates
                inputProps={ {
                  className: "form-control",
                  placeholder: I18n.t( "end_date_time" ),
                  onClick: ( ) => this.refs.dateRangeD2.onClick( )
                } }
              />
              <div className="help-text">
                { I18n.t( "views.projects.new.note_you_can_delete_the_time" ) }
              </div>
            </Col>
          </Row>
          <Row className="date-row">
            <Col xs={12}>
              <input
                type="radio"
                id="project-date-type-months"
                checked={ project.date_type === "months" }
                onChange={ ( ) => updateProject( { date_type: "months" } ) }
              />
              <label className="inline" htmlFor="project-date-type-months">
                { I18n.t( "months" ) }
              </label>
              <div
                style={ { position: "relative" } }
              >
                <JQueryUIMultiselect
                  className="form-control input-sm"
                  id="filters-dates-month"
                  onChange={ values =>
                    setRulePreference( "month", values ? values.join( "," ) : null )
                  }
                  defaultValue={ project.rule_month ? project.rule_month.split( "," ) : null }
                  data={
                    _.map( monthNames, ( month, i ) => (
                      {
                        value: i + 1,
                        label: I18n.t( `date_format.month.${month}` )
                      }
                    ) )
                  }
                />
              </div>
            </Col>
          </Row>
        </Grid>
      </div>
    );
  }
}

RegularForm.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  addProjectRule: PropTypes.func,
  removeProjectRule: PropTypes.func,
  setRulePreference: PropTypes.func,
  updateProject: PropTypes.func
};

export default RegularForm;
