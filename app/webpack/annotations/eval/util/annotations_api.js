import _ from "lodash";
import { ATTRIBUTES } from "../constants/attributes";

const normalizeAnnotations = annotations => {
  const attributes = ( annotations && annotations.attributes ) || { };
  return ATTRIBUTES.map( attribute => {
    const result = attributes[attribute.name];
    if ( !result || result.applicable === false ) {
      return { ...attribute, applicable: false, values: [] };
    }
    const type = _.isArray( result.predictions ) ? "bce" : "ce";
    const predicted = type === "bce"
      ? result.predictions
      : _.compact( [result.prediction] );
    const values = _.map( result.scores || { }, ( score, label ) => ( {
      label,
      score,
      predicted: _.includes( predicted, label )
    } ) );
    return {
      ...attribute,
      type,
      applicable: true,
      values: _.orderBy( values, "score", "desc" )
    };
  } );
};

export { normalizeAnnotations };
export default normalizeAnnotations;
