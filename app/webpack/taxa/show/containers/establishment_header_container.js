import { connect } from "react-redux";
import _ from "lodash";
import EstablishmentHeader from "../components/establishment_header";

function mapStateToProps( state ) {
  const taxon = state.taxon.taxon;
  const establishment = taxon.establishment_means;
  if ( !establishment ) {
    return { };
  }
  const listedTaxon = _.find( taxon.listed_taxa, lt =>
    lt.place.id === establishment.place.id &&
    lt.establishment_means === establishment.establishment_means
  );
  return {
    establishmentMeans: establishment,
    url: listedTaxon ? `/listed_taxa/${listedTaxon.id}` : null
  };
}

function mapDispatchToProps( ) {
  return { };
}

const EstablishmentHeaderContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( EstablishmentHeader );

export default EstablishmentHeaderContainer;
