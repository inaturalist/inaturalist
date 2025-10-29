import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import TextEditor from "../../../shared/components/text_editor";
import { isDisagreement } from "../../../shared/util";

class IdentificationForm extends React.Component {
  shouldComponentUpdate( nextProps ) {
    const {
      observation,
      content,
      key,
      className,
      nominate
    } = this.props;
    if ( observation.id === nextProps.observation.id
      && className === nextProps.className
      && key === nextProps.key
      && content === nextProps.content
      && nominate === nextProps.nominate ) {
      return false;
    }
    return true;
  }

  render( ) {
    const {
      config,
      observation: o,
      onSubmitIdentification,
      className,
      content,
      nominate,
      blind,
      key,
      updateEditorContent
    } = this.props;
    return (
      <form
        key={key}
        className={`IdentificationForm ${className}`}
        onSubmit={function ( e ) {
          e.preventDefault();
          // Note that data( "uiAutocomplete" ).selectedItem seems to disappear when
          // you re-focus on the taxon field, which can lead to some confusion b/c
          // it still looks like the taxon is selected in that state
          const idTaxon = $( ".IdentificationForm:visible:first input[name='taxon_name']" ).data( "autocomplete-item" );
          if ( !idTaxon ) {
            return;
          }
          const params = {
            observation_id: config.testingApiV2 ? o.uuid : o.id,
            taxon_id: idTaxon.id,
            body: content,
            blind,
            nominate
          };
          if ( blind && isDisagreement( o, idTaxon ) && e.target.elements.disagreement ) {
            params.disagreement = e.target.elements.disagreement.value === "1";
          }
          onSubmitIdentification( params, {
            observation: o,
            taxon: idTaxon,
            potentialDisagreement: !blind && isDisagreement( o, idTaxon )
          } );
          // this doesn't feel right... somehow submitting an ID should alter
          // the app state and this stuff should flow three here as props
          $( "input[name='taxon_name']", e.target ).trigger( "resetAll" );
          $( "input[name='taxon_name']", e.target ).blur( );
          updateEditorContent( "nominate", false );
        }}
      >
        <h3>{ I18n.t( "add_an_identification" ) }</h3>
        <TaxonAutocomplete bootstrapClear />
        <div className="form-group">
          <TextEditor
            className="upstacked"
            content={content}
            key={`comment-editor-${o.id}`}
            onBlur={e => { updateEditorContent( "obsIdentifyIdComment", e.target.value ); }}
            onChange={e => {
              const textLength = _.size( e.target.value );
              if ( textLength === 0 ) {
                // TODO: fingure out a better way to avoid the React controlled input error
                $( ".nomination input[type='checkbox']" ).prop( "checked", false );
                updateEditorContent( "nominate", false );
              }
              $( ".nomination input[type='checkbox']" ).prop( "disabled", textLength === 0 );
            }}
            placeholder={I18n.t( "tell_us_why" )}
            textareaClassName="form-control"
            mentions
          />
          <div className="nomination">
            <input
              type="checkbox"
              id="nominate-id"
              defaultChecked={nominate}
              disabled={_.size( content ) === 0}
              onChange={e => {
                updateEditorContent( "nominate", e.target.checked );
              }}
            />
            <label
              className="identificationNomination"
              htmlFor="nominate-id"
            >
              Nominate as an ID Tip (diagnostic characteristics that teach others to identify this organism)
            </label>
          </div>
        </div>
        { blind ? (
          <div className="form-group disagreement-group">
            <label>
              <input
                type="radio"
                name="disagreement"
                value="0"
                defaultChecked
              />
              { " " }
              Others could potentially refine this ID
            </label>
            <label>
              <input type="radio" name="disagreement" value="1" />
              { " " }
              This is the most specific ID the evidence justifies
            </label>
          </div>
        ) : null }
        <button
          type="submit"
          className="btn btn-primary"
        >
          { I18n.t( "save" ) }
        </button>
      </form>
    );
  }
}

IdentificationForm.propTypes = {
  config: PropTypes.object,
  observation: PropTypes.object,
  onSubmitIdentification: PropTypes.func.isRequired,
  className: PropTypes.string,
  content: PropTypes.string,
  nominate: PropTypes.bool,
  blind: PropTypes.bool,
  key: PropTypes.string,
  updateEditorContent: PropTypes.func
};

export default IdentificationForm;
