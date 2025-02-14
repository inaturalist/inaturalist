import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import TaxonAutocomplete from "../../../shared/components/taxon_autocomplete";
import TextEditor from "../../../shared/components/text_editor";
import { isDisagreement } from "../../../shared/util";

class IdentificationForm extends React.Component {
  shouldComponentUpdate( nextProps ) {
    const {
      observation, content, key, className
    } = this.props;
    if ( observation.id === nextProps.observation.id
      && className === nextProps.className
      && key === nextProps.key
      && content === nextProps.content ) {
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
            blind
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
            placeholder={I18n.t( "tell_us_why" )}
            textareaClassName="form-control"
            mentions
          />
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
  blind: PropTypes.bool,
  key: PropTypes.string,
  updateEditorContent: PropTypes.func
};

export default IdentificationForm;
