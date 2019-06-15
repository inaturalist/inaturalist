import { connect } from "react-redux";
import _ from "lodash";
import EstablishmentHeader from "../components/establishment_header";

function mapStateToProps( state ) {
  const { taxon } = state.taxon;
  const establishment = taxon.establishment_means;
  if ( !establishment ) {
    return { };
  }
  const listedTaxon = _.find( taxon.listed_taxa, lt => (
    lt.place.id === establishment.place.id
    && lt.establishment_means === establishment.establishment_means
  ) );
  let url;
  if ( listedTaxon ) {
    url = `/listed_taxa/${listedTaxon.id}`;
  } else if ( establishment.id ) {
    url = `/listed_taxa/${establishment.id}`;
  }
  return {
    establishmentMeans: establishment,
    url,
    source: listedTaxon ? listedTaxon.list.title : null
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
