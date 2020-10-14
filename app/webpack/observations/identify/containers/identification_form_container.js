import { connect } from "react-redux";
import _ from "lodash";
import IdentificationForm from "../components/identification_form";
import {
  postIdentification,
  fetchCurrentObservation,
  loadingDiscussionItem,
  fetchObservationsStats,
  stopLoadingDiscussionItem,
  showAlert,
  addIdentification
} from "../actions";
import { showDisagreementAlert } from "../../shared/ducks/disagreement_alert";
import { updateEditorContent } from "../../shared/ducks/text_editors";

// ownProps contains data passed in through the "tag", so in this case
// <IdentificationFormContainer observation={foo} />
function mapStateToProps( state, ownProps ) {
  return {
    observation: ownProps.observation,
    currentUser: state.config.currentUser,
    blind: state.config.blind,
    content: state.textEditor.obsIdentifyIdComment
  };
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitIdentification: ( identification, options = {} ) => {
      const ident = Object.assign( { }, identification, {
        observation: ownProps.observation
      } );
      dispatch( loadingDiscussionItem( ident ) );
      const boundPostIdentification = disagreement => {
        const params = Object.assign( { }, ident );
        if ( _.isNil( ident.disagreement ) ) {
          params.disagreement = disagreement || false;
        }
        dispatch( postIdentification( params ) )
          .catch( ( ) => {
            dispatch( stopLoadingDiscussionItem( ident ) );
          } )
          .then( ( ) => {
            dispatch( updateEditorContent( "obsIdentifyIdComment", "" ) );
            dispatch( fetchCurrentObservation( ownProps.observation ) ).then( ( ) => {
              $( ".ObservationModal:first" ).find( ".sidebar" ).scrollTop( $( window ).height( ) );
            } );
            dispatch( fetchObservationsStats( ) );
            // dispatch( fetchIdentifiers( ) );
          } );
      };
      if ( options.confirmationText ) {
        dispatch( showAlert( options.confirmationText, {
          title: I18n.t( "heads_up" ),
          onConfirm: boundPostIdentification,
          onCancel: ( ) => {
            dispatch( stopLoadingDiscussionItem( ident ) );
            dispatch( addIdentification( ) );
          }
        } ) );
      } else if ( options.potentialDisagreement ) {
        const o = options.observation;
        let observationTaxon = o.taxon;
        if (
          o.preferences.prefers_community_taxon === false
          || o.user.preferences.prefers_community_taxa === false
        ) {
          observationTaxon = o.community_taxon || o.taxon;
        }
        dispatch( showDisagreementAlert( {
          onDisagree: ( ) => {
            boundPostIdentification( true );
          },
          onBestGuess: boundPostIdentification,
          onCancel: ( ) => {
            dispatch( stopLoadingDiscussionItem( ident ) );
            dispatch( addIdentification( ) );
          },
          oldTaxon: observationTaxon,
          newTaxon: options.taxon
        } ) );
      } else {
        boundPostIdentification( );
      }
    },
    updateEditorContent: ( editor, content ) => {
      dispatch( updateEditorContent( editor, content ) );
    }
  };
}

const IdentificationFormContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( IdentificationForm );

export default IdentificationFormContainer;
