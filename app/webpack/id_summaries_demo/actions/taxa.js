// app/webpack/id_summaries_demo/actions/taxa.js
import inatjs from "inaturalistjs";

const photoUrlFromId = ( photoId, size = "square" ) => {
  const id = Number( photoId );
  if ( !Number.isFinite( id ) || id <= 0 ) return null;
  return `https://inaturalist-open-data.s3.amazonaws.com/photos/${id}/${size}.jpg`;
};

export const TAXA_FETCH_REQUEST = "id_summaries_demo/taxa/FETCH_REQUEST";
export const TAXA_FETCH_SUCCESS = "id_summaries_demo/taxa/FETCH_SUCCESS";
export const TAXA_FETCH_FAILURE = "id_summaries_demo/taxa/FETCH_FAILURE";

const TAXON_SUMMARY_FIELDS = [
  "uuid",
  "taxon_name",
  "taxon_common_name",
  "taxon_photo_id",
  "taxon_group",
  "run_generated_at",
  "id_summaries",
  "id_summaries.id",
  "id_summaries.summary",
  "id_summaries.score",
  "id_summaries.visual_key_group",
  "id_summaries.references.url",
  "id_summaries.references.comment_uuid",
  "id_summaries.references.user_id",
  "id_summaries.references.body",
  "id_summaries.references.reference_content",
  "id_summaries.references.reference_source",
  "id_summaries.references.reference_uuid",
  "id_summaries.references.reference_date",
  "id_summaries.references.created_at",
  "id_summaries.references.updated_at"
].join( "," );

export const fetchTaxa = ( { active = true, page = 1, per_page = 200 } = {} ) => async dispatch => {
  dispatch( { type: TAXA_FETCH_REQUEST } );
  try {
    const taxonIdSummariesAPI = inatjs?.taxon_id_summaries;
    if ( !taxonIdSummariesAPI || typeof taxonIdSummariesAPI.search !== "function" ) {
      throw new Error( "inatjs.taxon_id_summaries.search unavailable" );
    }
    const resp = await taxonIdSummariesAPI.search(
      {
        active, page, per_page, fields: TAXON_SUMMARY_FIELDS
      },
      { useAuth: true }
    );
    const {
      results = [], total_results, page: p, per_page: pp
    } = resp || {};

    const normalizeTip = ( tip = {} ) => ( {
      id: tip?.id,
      text: tip?.content || tip?.tip || tip?.summary || "",
      group: tip?.key_visual_trait_group || tip?.group || tip?.visual_key_group || null,
      score: Number.isFinite( tip?.score )
        ? tip.score
        : Number.isFinite( tip?.global_score )
          ? tip.global_score
          : null,
      sources: Array.isArray( tip?.sources )
        ? tip.sources.map( source => ( {
          url: source?.url,
          comment_uuid: source?.comment_uuid,
          user_id: source?.user_id,
          body: source?.body,
          created_at: source?.reference_date || source?.created_at || source?.updated_at || null,
          reference_source: source?.reference_source || source?.source || null,
          reference_uuid: source?.reference_uuid || source?.comment_uuid || null
        } ) )
        : Array.isArray( tip?.references )
          ? tip.references.map( ref => ( {
            url: ref?.url,
            comment_uuid: ref?.comment_uuid,
            user_id: ref?.user_id,
            body: ref?.body || ref?.reference_content,
            created_at: ref?.reference_date || ref?.created_at || ref?.reference_created_at || ref?.updated_at || null,
            reference_source: ref?.reference_source || ref?.source || null,
            reference_uuid: ref?.reference_uuid || ref?.comment_uuid || null
          } ) )
          : []
    } );

    const speciesList = results.map( r => ( {
      id: r?.taxon_id,
      uuid: r?.uuid,
      name: r?.taxon_name,
      commonName: r?.taxon_common_name?.name || r?.taxon_common_name || null,
      taxonGroup: r?.taxon_group || null,
      runGeneratedAt: r?.run_generated_at || null,
      taxonPhotoId: r?.taxon_photo_id,
      photoSquareUrl: photoUrlFromId( r?.taxon_photo_id, "square" ),
      photoMediumUrl: photoUrlFromId( r?.taxon_photo_id, "medium" ),
      tips: Array.isArray( r?.id_summaries ) ? r.id_summaries.map( normalizeTip ) : []
    } ) );

    dispatch( {
      type: TAXA_FETCH_SUCCESS,
      payload: {
        speciesList,
        page: p || page,
        perPage: pp || per_page,
        totalResults: Number.isFinite( total_results ) ? total_results : speciesList.length
      }
    } );
  } catch ( error ) {
    // eslint-disable-next-line no-console
    console.error( "inatjs.taxonIdSummaries.search failed", error );
    dispatch( { type: TAXA_FETCH_FAILURE, error: error?.message || "Request failed" } );
  }
};
