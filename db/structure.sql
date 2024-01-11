SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: _final_median(numeric[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._final_median(numeric[]) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
   SELECT AVG(val)
   FROM (
     SELECT val
     FROM unnest($1) val
     ORDER BY 1
     LIMIT  2 - MOD(array_upper($1, 1), 2)
     OFFSET CEIL(array_upper($1, 1) / 2.0) - 1
   ) sub;
$_$;


--
-- Name: _final_median(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._final_median(anyarray) RETURNS double precision
    LANGUAGE sql IMMUTABLE
    AS $_$ 
        WITH q AS
        (
           SELECT val
           FROM unnest($1) val
           WHERE VAL IS NOT NULL
           ORDER BY 1
        ),
        cnt AS
        (
          SELECT COUNT(*) AS c FROM q
        )
        SELECT AVG(val)::float8
        FROM 
        (
          SELECT val FROM q
          LIMIT  2 - MOD((SELECT c FROM cnt), 2)
          OFFSET GREATEST(CEIL((SELECT c FROM cnt) / 2.0) - 1,0)  
        ) q2;
      $_$;


--
-- Name: cleangeometry(public.geometry); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleangeometry(geom public.geometry) RETURNS public.geometry
    LANGUAGE plpgsql
    AS $_$
          DECLARE
          inGeom ALIAS for $1;
          outGeom geometry;
          tmpLinestring geometry;
          sqlString text;

      BEGIN

          outGeom := NULL;

          -- Clean Polygons --
          IF (ST_GeometryType(inGeom) = 'ST_Polygon' OR ST_GeometryType(inGeom) = 'ST_MultiPolygon') THEN

              -- Check if it needs fixing
              IF NOT ST_IsValid(inGeom) THEN

                  sqlString := '
                      -- separate multipolygon into 1 polygon per row
                      WITH split_multi (geom, poly) AS (
                          SELECT
                              (ST_Dump($1)).geom,
                              (ST_Dump($1)).path[1] -- polygon number
                      ),
                      -- break each polygon into linestrings
                      split_line (geom, poly, line) AS (
                          SELECT
                              ST_Boundary((ST_DumpRings(geom)).geom),
                              poly,
                              (ST_DumpRings(geom)).path[1] -- line number
                          FROM split_multi
                      ),
                      -- get the linestrings that make up the exterior of each polygon
                      line_exterior (geom, poly) AS (
                          SELECT
                              geom,
                              poly
                          FROM split_line
                          WHERE line = 0
                      ),
                      -- get an array of all the linestrings that make up the interior of each polygon
                      line_interior (geom, poly) AS (
                          SELECT
                              array_agg(geom ORDER BY line),
                              poly
                          FROM split_line
                          WHERE line > 0
                          GROUP BY poly
                      ),
                      -- use MakePolygon to rebuild the polygons
                      poly_geom (geom, poly) AS (
                          SELECT
                              CASE WHEN line_interior.geom IS NULL
                                  THEN ST_Buffer(ST_MakePolygon(line_exterior.geom), 0)
                                  ELSE ST_Buffer(ST_MakePolygon(line_exterior.geom, line_interior.geom), 0)
                              END,
                              line_exterior.poly
                          FROM line_exterior
                          LEFT JOIN line_interior USING (poly)
                      )
                  ';

                  IF (ST_GeometryType(inGeom) = 'ST_Polygon') THEN
                      sqlString := sqlString || '
                          SELECT geom
                          FROM poly_geom
                      ';
                  ELSE
                      sqlString := sqlString || '
                          , -- if its a multipolygon combine the polygons back together
                          multi_geom (geom) AS (
                              SELECT
                                  ST_Multi(ST_Collect(geom ORDER BY poly))
                              FROM poly_geom
                          )
                          SELECT geom
                          FROM multi_geom
                      ';
                  END IF;

                  EXECUTE sqlString INTO outGeom USING inGeom;

                  RETURN outGeom;
              ELSE
                  RETURN inGeom;
              END IF;

          -- Clean Lines --
          ELSIF (ST_GeometryType(inGeom) = 'ST_Linestring') THEN

              outGeom := ST_Union(ST_Multi(inGeom), ST_PointN(inGeom, 1));
              RETURN outGeom;
          ELSIF (ST_GeometryType(inGeom) = 'ST_MultiLinestring') THEN
              outGeom := ST_Multi(ST_Union(ST_Multi(inGeom), ST_PointN(inGeom, 1)));
              RETURN outGeom;
          ELSE
              RAISE NOTICE 'The input type % is not supported',ST_GeometryType(inGeom);
              RETURN inGeom;
          END IF;
      END;
      $_$;


--
-- Name: crc32(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crc32(word text) RETURNS bigint
    LANGUAGE plpgsql IMMUTABLE
    AS $$
          DECLARE tmp bigint;
          DECLARE i int;
          DECLARE j int;
          DECLARE byte_length int;
          DECLARE word_array bytea;
          BEGIN
            IF COALESCE(word, '') = '' THEN
              return 0;
            END IF;

            i = 0;
            tmp = 4294967295;
            byte_length = bit_length(word) / 8;
            word_array = decode(replace(word, E'\\', E'\\\\'), 'escape');
            LOOP
              tmp = (tmp # get_byte(word_array, i))::bigint;
              i = i + 1;
              j = 0;
              LOOP
                tmp = ((tmp >> 1) # (3988292384 * (tmp & 1)))::bigint;
                j = j + 1;
                IF j >= 8 THEN
                  EXIT;
                END IF;
              END LOOP;
              IF i >= byte_length THEN
                EXIT;
              END IF;
            END LOOP;
            return (tmp # 4294967295);
          END
        $$;


--
-- Name: st_aslatlontext(public.geometry); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.st_aslatlontext(public.geometry) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$ SELECT ST_AsLatLonText($1, '') $_$;


--
-- Name: median(anyelement); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.median(anyelement) (
    SFUNC = array_append,
    STYPE = anyarray,
    INITCOND = '{}',
    FINALFUNC = public._final_median
);


--
-- Name: median(numeric); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.median(numeric) (
    SFUNC = array_append,
    STYPE = numeric[],
    INITCOND = '{}',
    FINALFUNC = public._final_median
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: annotations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.annotations (
    id integer NOT NULL,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    resource_id integer,
    resource_type character varying,
    controlled_attribute_id integer,
    controlled_value_id integer,
    user_id integer,
    observation_field_value_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: annotations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.annotations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: annotations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.annotations_id_seq OWNED BY public.annotations.id;


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id integer NOT NULL,
    placement character varying(255),
    start timestamp without time zone,
    "end" timestamp without time zone,
    body text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    locales text[] DEFAULT '{}'::text[],
    dismiss_user_ids integer[] DEFAULT '{}'::integer[],
    dismissible boolean DEFAULT false,
    clients text[] DEFAULT '{}'::text[]
);


--
-- Name: announcements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcements_id_seq OWNED BY public.announcements.id;


--
-- Name: announcements_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements_sites (
    announcement_id integer,
    site_id integer
);


--
-- Name: api_endpoint_caches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_endpoint_caches (
    id integer NOT NULL,
    api_endpoint_id integer,
    request_url character varying,
    request_began_at timestamp without time zone,
    request_completed_at timestamp without time zone,
    success boolean,
    response text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: api_endpoint_caches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_endpoint_caches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_endpoint_caches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_endpoint_caches_id_seq OWNED BY public.api_endpoint_caches.id;


--
-- Name: api_endpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_endpoints (
    id integer NOT NULL,
    title character varying NOT NULL,
    description text,
    documentation_url character varying,
    base_url character varying,
    cache_hours integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: api_endpoints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_endpoints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_endpoints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_endpoints_id_seq OWNED BY public.api_endpoints.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: assessment_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assessment_sections (
    id integer NOT NULL,
    assessment_id integer,
    user_id integer,
    title character varying(255),
    body text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    display_order integer
);


--
-- Name: assessment_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.assessment_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: assessment_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.assessment_sections_id_seq OWNED BY public.assessment_sections.id;


--
-- Name: assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assessments (
    id integer NOT NULL,
    taxon_id integer,
    project_id integer,
    user_id integer,
    description text,
    completed_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: assessments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.assessments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: assessments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.assessments_id_seq OWNED BY public.assessments.id;


--
-- Name: atlas_alterations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atlas_alterations (
    id integer NOT NULL,
    atlas_id integer,
    user_id integer,
    place_id integer,
    action character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: atlas_alterations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.atlas_alterations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: atlas_alterations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.atlas_alterations_id_seq OWNED BY public.atlas_alterations.id;


--
-- Name: atlases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.atlases (
    id integer NOT NULL,
    user_id integer,
    taxon_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_active boolean DEFAULT false,
    is_marked boolean DEFAULT false,
    account_id integer
);


--
-- Name: atlases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.atlases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: atlases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.atlases_id_seq OWNED BY public.atlases.id;


--
-- Name: audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audits (
    id bigint NOT NULL,
    auditable_id integer,
    auditable_type character varying,
    associated_id integer,
    associated_type character varying,
    user_id integer,
    user_type character varying,
    username character varying,
    action character varying,
    audited_changes jsonb,
    version integer DEFAULT 0,
    comment character varying,
    remote_address character varying,
    request_uuid character varying,
    created_at timestamp without time zone
);


--
-- Name: audits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audits_id_seq OWNED BY public.audits.id;


--
-- Name: colors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.colors (
    id integer NOT NULL,
    value character varying(255)
);


--
-- Name: colors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.colors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: colors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.colors_id_seq OWNED BY public.colors.id;


--
-- Name: colors_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.colors_taxa (
    color_id integer,
    taxon_id integer
);


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    user_id integer,
    parent_id integer,
    parent_type character varying(255),
    body text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: complete_sets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.complete_sets (
    id integer NOT NULL,
    user_id integer,
    taxon_id integer,
    place_id integer,
    description text,
    source_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    is_active boolean DEFAULT false
);


--
-- Name: complete_sets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.complete_sets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: complete_sets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.complete_sets_id_seq OWNED BY public.complete_sets.id;


--
-- Name: computer_vision_demo_uploads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.computer_vision_demo_uploads (
    id integer NOT NULL,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    photo_file_name character varying,
    photo_content_type character varying,
    photo_file_size character varying,
    photo_updated_at character varying,
    original_url character varying,
    thumbnail_url character varying,
    mobile boolean,
    user_agent character varying,
    metadata text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: computer_vision_demo_uploads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.computer_vision_demo_uploads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: computer_vision_demo_uploads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.computer_vision_demo_uploads_id_seq OWNED BY public.computer_vision_demo_uploads.id;


--
-- Name: conservation_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conservation_statuses (
    id integer NOT NULL,
    taxon_id integer,
    user_id integer,
    place_id integer,
    source_id integer,
    authority character varying(255),
    status character varying(255),
    url character varying(512),
    description text,
    geoprivacy character varying(255) DEFAULT 'obscured'::character varying,
    iucn integer DEFAULT 20,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    updater_id integer
);


--
-- Name: conservation_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conservation_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conservation_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conservation_statuses_id_seq OWNED BY public.conservation_statuses.id;


--
-- Name: controlled_term_labels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.controlled_term_labels (
    id integer NOT NULL,
    controlled_term_id integer,
    locale character varying,
    valid_within_clade integer,
    label character varying,
    definition character varying,
    icon_file_name character varying,
    icon_content_type character varying,
    icon_file_size character varying,
    icon_updated_at character varying,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: controlled_term_labels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.controlled_term_labels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: controlled_term_labels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.controlled_term_labels_id_seq OWNED BY public.controlled_term_labels.id;


--
-- Name: controlled_term_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.controlled_term_taxa (
    id integer NOT NULL,
    controlled_term_id integer,
    taxon_id integer,
    exception boolean DEFAULT false
);


--
-- Name: controlled_term_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.controlled_term_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: controlled_term_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.controlled_term_taxa_id_seq OWNED BY public.controlled_term_taxa.id;


--
-- Name: controlled_term_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.controlled_term_values (
    id integer NOT NULL,
    controlled_attribute_id integer,
    controlled_value_id integer
);


--
-- Name: controlled_term_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.controlled_term_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: controlled_term_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.controlled_term_values_id_seq OWNED BY public.controlled_term_values.id;


--
-- Name: controlled_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.controlled_terms (
    id integer NOT NULL,
    ontology_uri text,
    uri text,
    is_value boolean DEFAULT false,
    active boolean DEFAULT false,
    multivalued boolean DEFAULT false,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    blocking boolean DEFAULT false,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: controlled_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.controlled_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: controlled_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.controlled_terms_id_seq OWNED BY public.controlled_terms.id;


--
-- Name: counties_simplified_01; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.counties_simplified_01 (
    id integer NOT NULL,
    place_geometry_id integer,
    place_id integer,
    geom public.geometry(MultiPolygon) NOT NULL
);


--
-- Name: counties_simplified_01_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.counties_simplified_01_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: counties_simplified_01_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.counties_simplified_01_id_seq OWNED BY public.counties_simplified_01.id;


--
-- Name: countries_simplified_1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries_simplified_1 (
    id integer NOT NULL,
    place_geometry_id integer,
    place_id integer,
    geom public.geometry(MultiPolygon) NOT NULL
);


--
-- Name: countries_simplified_1_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.countries_simplified_1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: countries_simplified_1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.countries_simplified_1_id_seq OWNED BY public.countries_simplified_1.id;


--
-- Name: custom_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_projects (
    id integer NOT NULL,
    head text,
    side text,
    css text,
    project_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: custom_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.custom_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: custom_projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.custom_projects_id_seq OWNED BY public.custom_projects.id;


--
-- Name: data_partners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_partners (
    id integer NOT NULL,
    name character varying,
    url character varying,
    partnership_url character varying,
    frequency character varying,
    dwca_params json,
    dwca_last_export_at timestamp without time zone,
    api_request_url character varying,
    description text,
    requirements text,
    last_sync_observation_links_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    logo_file_name character varying,
    logo_content_type character varying,
    logo_file_size bigint,
    logo_updated_at timestamp without time zone
);


--
-- Name: data_partners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.data_partners_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: data_partners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.data_partners_id_seq OWNED BY public.data_partners.id;


--
-- Name: delayed_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delayed_jobs (
    id integer NOT NULL,
    priority integer DEFAULT 0,
    attempts integer DEFAULT 0,
    handler text,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    queue character varying(255),
    unique_hash character varying
);


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: delayed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;


--
-- Name: deleted_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deleted_observations (
    id integer NOT NULL,
    user_id integer,
    observation_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    observation_created_at timestamp without time zone
);


--
-- Name: deleted_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deleted_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deleted_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deleted_observations_id_seq OWNED BY public.deleted_observations.id;


--
-- Name: deleted_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deleted_photos (
    id integer NOT NULL,
    user_id integer,
    photo_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    removed_from_s3 boolean DEFAULT false NOT NULL,
    orphan boolean DEFAULT false NOT NULL
);


--
-- Name: deleted_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deleted_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deleted_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deleted_photos_id_seq OWNED BY public.deleted_photos.id;


--
-- Name: deleted_sounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deleted_sounds (
    id integer NOT NULL,
    user_id integer,
    sound_id integer,
    removed_from_s3 boolean DEFAULT false,
    orphan boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: deleted_sounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deleted_sounds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deleted_sounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deleted_sounds_id_seq OWNED BY public.deleted_sounds.id;


--
-- Name: deleted_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deleted_users (
    id integer NOT NULL,
    user_id integer,
    login character varying(255),
    email character varying(255),
    user_created_at timestamp without time zone,
    user_updated_at timestamp without time zone,
    observations_count integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: deleted_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deleted_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deleted_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deleted_users_id_seq OWNED BY public.deleted_users.id;


--
-- Name: email_suppressions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_suppressions (
    id bigint NOT NULL,
    email text,
    suppression_type text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer
);


--
-- Name: email_suppressions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.email_suppressions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: email_suppressions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.email_suppressions_id_seq OWNED BY public.email_suppressions.id;


--
-- Name: exploded_atlas_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exploded_atlas_places (
    id integer NOT NULL,
    atlas_id integer,
    place_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: exploded_atlas_places_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.exploded_atlas_places_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: exploded_atlas_places_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.exploded_atlas_places_id_seq OWNED BY public.exploded_atlas_places.id;


--
-- Name: external_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.external_taxa (
    id integer NOT NULL,
    name character varying,
    rank character varying,
    parent_name character varying,
    parent_rank character varying,
    url character varying,
    taxon_framework_relationship_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: external_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.external_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: external_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.external_taxa_id_seq OWNED BY public.external_taxa.id;


--
-- Name: file_extensions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_extensions (
    id integer NOT NULL,
    extension character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: file_extensions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.file_extensions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: file_extensions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.file_extensions_id_seq OWNED BY public.file_extensions.id;


--
-- Name: file_prefixes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_prefixes (
    id integer NOT NULL,
    prefix character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: file_prefixes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.file_prefixes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: file_prefixes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.file_prefixes_id_seq OWNED BY public.file_prefixes.id;


--
-- Name: flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flags (
    id integer NOT NULL,
    flag character varying(255),
    comment character varying(255),
    created_at timestamp without time zone NOT NULL,
    flaggable_id integer DEFAULT 0 NOT NULL,
    flaggable_type character varying(15) NOT NULL,
    user_id integer DEFAULT 0 NOT NULL,
    resolver_id integer,
    resolved boolean DEFAULT false,
    updated_at timestamp without time zone,
    resolved_at timestamp without time zone,
    flaggable_user_id integer,
    flaggable_content text,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    flaggable_parent_type character varying,
    flaggable_parent_id bigint
);


--
-- Name: flags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flags_id_seq OWNED BY public.flags.id;


--
-- Name: flickr_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flickr_identities (
    id integer NOT NULL,
    flickr_username character varying(255),
    frob character varying(255),
    token character varying(255),
    token_created_at timestamp without time zone,
    auto_import integer DEFAULT 0,
    auto_imported_at timestamp without time zone,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    flickr_user_id character varying(255),
    secret character varying(255)
);


--
-- Name: flickr_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flickr_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flickr_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flickr_identities_id_seq OWNED BY public.flickr_identities.id;


--
-- Name: flow_task_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flow_task_resources (
    id integer NOT NULL,
    flow_task_id integer,
    resource_type character varying(255),
    resource_id integer,
    type character varying(255),
    file_file_name character varying(255),
    file_content_type character varying(255),
    file_file_size integer,
    file_updated_at timestamp without time zone,
    extra text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: flow_task_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flow_task_resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flow_task_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flow_task_resources_id_seq OWNED BY public.flow_task_resources.id;


--
-- Name: flow_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flow_tasks (
    id integer NOT NULL,
    type character varying(255),
    options text,
    command character varying(255),
    error character varying(255),
    started_at timestamp without time zone,
    finished_at timestamp without time zone,
    user_id integer,
    redirect_url character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    exception text,
    unique_hash character varying
);


--
-- Name: flow_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flow_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flow_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flow_tasks_id_seq OWNED BY public.flow_tasks.id;


--
-- Name: frequency_cell_month_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frequency_cell_month_taxa (
    frequency_cell_id integer,
    month integer,
    taxon_id integer,
    count integer
);


--
-- Name: frequency_cells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.frequency_cells (
    id integer NOT NULL,
    swlat integer,
    swlng integer
);


--
-- Name: frequency_cells_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.frequency_cells_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: frequency_cells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.frequency_cells_id_seq OWNED BY public.frequency_cells.id;


--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendly_id_slugs (
    id integer NOT NULL,
    slug character varying(255),
    sluggable_id integer,
    sequence integer DEFAULT 1 NOT NULL,
    sluggable_type character varying(40),
    scope character varying(255),
    created_at timestamp without time zone
);


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendly_id_slugs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendly_id_slugs_id_seq OWNED BY public.friendly_id_slugs.id;


--
-- Name: friendships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendships (
    id integer NOT NULL,
    user_id integer,
    friend_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    following boolean DEFAULT true,
    trust boolean DEFAULT false
);


--
-- Name: friendships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendships_id_seq OWNED BY public.friendships.id;


--
-- Name: geo_model_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.geo_model_taxa (
    id bigint NOT NULL,
    taxon_id integer,
    prauc double precision,
    "precision" double precision,
    recall double precision,
    f1 double precision,
    threshold double precision,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: geo_model_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.geo_model_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: geo_model_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.geo_model_taxa_id_seq OWNED BY public.geo_model_taxa.id;


--
-- Name: goal_contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goal_contributions (
    id integer NOT NULL,
    contribution_id integer,
    contribution_type character varying(255),
    goal_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    goal_participant_id integer
);


--
-- Name: goal_contributions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goal_contributions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goal_contributions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goal_contributions_id_seq OWNED BY public.goal_contributions.id;


--
-- Name: goal_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goal_participants (
    id integer NOT NULL,
    goal_id integer,
    user_id integer,
    goal_completed integer DEFAULT 0,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: goal_participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goal_participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goal_participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goal_participants_id_seq OWNED BY public.goal_participants.id;


--
-- Name: goal_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goal_rules (
    id integer NOT NULL,
    goal_id integer,
    operator character varying(255),
    operator_class character varying(255),
    arguments character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: goal_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goal_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goal_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goal_rules_id_seq OWNED BY public.goal_rules.id;


--
-- Name: goals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goals (
    id integer NOT NULL,
    description text,
    number_of_contributions_required integer,
    goal_type character varying(255),
    ends_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    completed boolean DEFAULT false
);


--
-- Name: goals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: goals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goals_id_seq OWNED BY public.goals.id;


--
-- Name: guide_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guide_photos (
    id integer NOT NULL,
    guide_taxon_id integer,
    title character varying(255),
    description character varying(255),
    photo_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer DEFAULT 0
);


--
-- Name: guide_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guide_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guide_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guide_photos_id_seq OWNED BY public.guide_photos.id;


--
-- Name: guide_ranges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guide_ranges (
    id integer NOT NULL,
    guide_taxon_id integer,
    medium_url character varying(512),
    thumb_url character varying(512),
    original_url character varying(512),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    license character varying(255),
    source_url character varying(512),
    rights_holder character varying(255),
    source_id integer,
    file_file_name character varying(255),
    file_content_type character varying(255),
    file_file_size integer,
    file_updated_at timestamp without time zone,
    "position" integer DEFAULT 0
);


--
-- Name: guide_ranges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guide_ranges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guide_ranges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guide_ranges_id_seq OWNED BY public.guide_ranges.id;


--
-- Name: guide_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guide_sections (
    id integer NOT NULL,
    guide_taxon_id integer,
    title character varying(255),
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer DEFAULT 0,
    license character varying(255),
    source_url character varying(255),
    rights_holder character varying(255),
    source_id integer,
    creator_id integer,
    updater_id integer
);


--
-- Name: guide_sections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guide_sections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guide_sections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guide_sections_id_seq OWNED BY public.guide_sections.id;


--
-- Name: guide_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guide_taxa (
    id integer NOT NULL,
    guide_id integer,
    taxon_id integer,
    name character varying(255),
    display_name character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer DEFAULT 0,
    source_identifier character varying(255)
);


--
-- Name: guide_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guide_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guide_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guide_taxa_id_seq OWNED BY public.guide_taxa.id;


--
-- Name: guide_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guide_users (
    id integer NOT NULL,
    guide_id integer,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: guide_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guide_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guide_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guide_users_id_seq OWNED BY public.guide_users.id;


--
-- Name: guides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.guides (
    id integer NOT NULL,
    title character varying(255),
    description text,
    published_at timestamp without time zone,
    latitude numeric,
    longitude numeric,
    user_id integer,
    place_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    license character varying(255) DEFAULT 'CC-BY-SA'::character varying,
    icon_file_name character varying(255),
    icon_content_type character varying(255),
    icon_file_size integer,
    icon_updated_at timestamp without time zone,
    map_type character varying(255) DEFAULT 'terrain'::character varying,
    zoom_level integer,
    taxon_id integer,
    source_url character varying(255),
    downloadable boolean DEFAULT false,
    ngz_file_name character varying(255),
    ngz_content_type character varying(255),
    ngz_file_size integer,
    ngz_updated_at timestamp without time zone
);


--
-- Name: guides_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.guides_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: guides_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.guides_id_seq OWNED BY public.guides.id;


--
-- Name: identifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.identifications (
    id integer NOT NULL,
    observation_id integer,
    taxon_id integer,
    user_id integer,
    type character varying(255),
    body text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    current boolean DEFAULT true,
    taxon_change_id integer,
    category character varying,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    blind boolean,
    previous_observation_taxon_id integer,
    disagreement boolean
);


--
-- Name: identifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.identifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: identifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.identifications_id_seq OWNED BY public.identifications.id;


--
-- Name: list_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.list_rules (
    id integer NOT NULL,
    list_id integer,
    operator character varying(255),
    operand_id integer,
    operand_type character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: list_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.list_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: list_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.list_rules_id_seq OWNED BY public.list_rules.id;


--
-- Name: listed_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listed_taxa (
    id integer NOT NULL,
    taxon_id integer,
    list_id integer,
    last_observation_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    place_id integer,
    description text,
    comments_count integer DEFAULT 0,
    user_id integer,
    updater_id integer,
    occurrence_status_level integer,
    establishment_means character varying(32),
    first_observation_id integer,
    observations_count integer DEFAULT 0,
    taxon_range_id integer,
    source_id integer,
    manually_added boolean DEFAULT false,
    primary_listing boolean DEFAULT true
);


--
-- Name: listed_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listed_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listed_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.listed_taxa_id_seq OWNED BY public.listed_taxa.id;


--
-- Name: listed_taxon_alterations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.listed_taxon_alterations (
    id integer NOT NULL,
    taxon_id integer,
    user_id integer,
    place_id integer,
    action character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: listed_taxon_alterations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.listed_taxon_alterations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: listed_taxon_alterations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.listed_taxon_alterations_id_seq OWNED BY public.listed_taxon_alterations.id;


--
-- Name: lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lists (
    id integer NOT NULL,
    title character varying(255),
    description text,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    type character varying(255),
    comprehensive boolean DEFAULT false,
    taxon_id integer,
    last_synced_at timestamp without time zone,
    place_id integer,
    project_id integer,
    source_id integer,
    show_obs_photos boolean DEFAULT true
);


--
-- Name: lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.lists_id_seq OWNED BY public.lists.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    user_id integer,
    from_user_id integer,
    to_user_id integer,
    thread_id integer,
    subject character varying(255),
    body text,
    read_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: model_attribute_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.model_attribute_changes (
    id integer NOT NULL,
    model_type character varying,
    model_id integer,
    field_name character varying,
    changed_at timestamp without time zone
);


--
-- Name: model_attribute_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.model_attribute_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: model_attribute_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.model_attribute_changes_id_seq OWNED BY public.model_attribute_changes.id;


--
-- Name: moderator_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.moderator_actions (
    id integer NOT NULL,
    resource_type character varying,
    resource_id integer,
    user_id integer,
    action character varying,
    reason character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: moderator_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.moderator_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: moderator_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.moderator_actions_id_seq OWNED BY public.moderator_actions.id;


--
-- Name: moderator_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.moderator_notes (
    id integer NOT NULL,
    user_id integer,
    body text,
    subject_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: moderator_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.moderator_notes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: moderator_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.moderator_notes_id_seq OWNED BY public.moderator_notes.id;


--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_access_grants (
    id integer NOT NULL,
    resource_owner_id integer NOT NULL,
    application_id integer NOT NULL,
    token character varying(255) NOT NULL,
    expires_in integer NOT NULL,
    redirect_uri character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    scopes character varying(255),
    code_challenge character varying,
    code_challenge_method character varying
);


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_access_grants_id_seq OWNED BY public.oauth_access_grants.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_access_tokens (
    id integer NOT NULL,
    resource_owner_id integer,
    application_id integer NOT NULL,
    token character varying(255) NOT NULL,
    refresh_token character varying(255),
    expires_in integer,
    revoked_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    scopes character varying(255)
);


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_access_tokens_id_seq OWNED BY public.oauth_access_tokens.id;


--
-- Name: oauth_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_applications (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    uid character varying(255) NOT NULL,
    secret character varying(255) NOT NULL,
    redirect_uri character varying(255) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    owner_id integer,
    owner_type character varying(255),
    trusted boolean DEFAULT false,
    image_file_name character varying(255),
    image_content_type character varying(255),
    image_file_size integer,
    image_updated_at timestamp without time zone,
    url character varying(255),
    description text,
    scopes character varying DEFAULT ''::character varying NOT NULL,
    confidential boolean DEFAULT true NOT NULL,
    official boolean DEFAULT false
);


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_applications_id_seq OWNED BY public.oauth_applications.id;


--
-- Name: observation_accuracy_experiments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_accuracy_experiments (
    id bigint NOT NULL,
    sample_size integer,
    taxon_id integer,
    validator_redundancy_factor integer,
    sample_generation_date timestamp without time zone,
    validator_contact_date timestamp without time zone,
    validator_deadline_date timestamp without time zone,
    assessment_date timestamp without time zone,
    responding_validators integer,
    validated_observations integer,
    low_acuracy_mean double precision,
    low_acuracy_variance double precision,
    high_accuracy_mean double precision,
    high_accuracy_variance double precision,
    precision_mean double precision,
    precision_variance double precision,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: observation_accuracy_experiments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_accuracy_experiments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_accuracy_experiments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_accuracy_experiments_id_seq OWNED BY public.observation_accuracy_experiments.id;


--
-- Name: observation_accuracy_samples; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_accuracy_samples (
    id bigint NOT NULL,
    observation_accuracy_experiment_id integer,
    observation_id integer,
    taxon_id integer,
    quality_grade character varying,
    year integer,
    iconic_taxon_name character varying,
    continent character varying,
    taxon_observations_count integer,
    taxon_rank_level integer,
    descendant_count integer,
    correct integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: observation_accuracy_samples_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_accuracy_samples_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_accuracy_samples_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_accuracy_samples_id_seq OWNED BY public.observation_accuracy_samples.id;


--
-- Name: observation_accuracy_samples_validators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_accuracy_samples_validators (
    observation_accuracy_sample_id bigint NOT NULL,
    observation_accuracy_validator_id bigint NOT NULL
);


--
-- Name: observation_accuracy_validators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_accuracy_validators (
    id bigint NOT NULL,
    user_id integer,
    email_date timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: observation_accuracy_validators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_accuracy_validators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_accuracy_validators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_accuracy_validators_id_seq OWNED BY public.observation_accuracy_validators.id;


--
-- Name: observation_field_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_field_values (
    id integer NOT NULL,
    observation_id integer,
    observation_field_id integer,
    value character varying(2048),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    user_id integer,
    updater_id integer,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: observation_field_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_field_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_field_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_field_values_id_seq OWNED BY public.observation_field_values.id;


--
-- Name: observation_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_fields (
    id integer NOT NULL,
    name character varying(255),
    datatype character varying(255),
    user_id integer,
    description character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    allowed_values text,
    values_count integer,
    users_count integer,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: observation_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_fields_id_seq OWNED BY public.observation_fields.id;


--
-- Name: observation_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_links (
    id integer NOT NULL,
    observation_id integer,
    rel character varying(255),
    href character varying(255),
    href_name character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: observation_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_links_id_seq OWNED BY public.observation_links.id;


--
-- Name: observation_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_photos (
    id integer NOT NULL,
    observation_id integer NOT NULL,
    photo_id integer NOT NULL,
    "position" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    uuid character varying(255)
);


--
-- Name: observation_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_photos_id_seq OWNED BY public.observation_photos.id;


--
-- Name: observation_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_reviews (
    id integer NOT NULL,
    user_id integer,
    observation_id integer,
    reviewed boolean DEFAULT true,
    user_added boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: observation_reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_reviews_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_reviews_id_seq OWNED BY public.observation_reviews.id;


--
-- Name: observation_sounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_sounds (
    id integer NOT NULL,
    observation_id integer,
    sound_id integer,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: observation_sounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observation_sounds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_sounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observation_sounds_id_seq OWNED BY public.observation_sounds.id;


--
-- Name: observation_zooms_10; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_10 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_11; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_11 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_12; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_12 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_125; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_125 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_2; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_2 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_2000; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_2000 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_250; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_250 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_3; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_3 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_4; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_4 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_4000; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_4000 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_5; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_5 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_500; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_500 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_6; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_6 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_63; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_63 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_7; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_7 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_8; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_8 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_9; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_9 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observation_zooms_990; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observation_zooms_990 (
    taxon_id integer,
    geom public.geometry,
    count integer NOT NULL
);


--
-- Name: observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observations (
    id integer NOT NULL,
    observed_on date,
    description text,
    latitude numeric(15,10),
    longitude numeric(15,10),
    map_scale integer,
    timeframe text,
    species_guess character varying(255),
    user_id integer,
    taxon_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    place_guess character varying(255),
    id_please boolean DEFAULT false,
    observed_on_string character varying(255),
    iconic_taxon_id integer,
    num_identification_agreements integer DEFAULT 0,
    num_identification_disagreements integer DEFAULT 0,
    time_observed_at timestamp without time zone,
    time_zone character varying(255),
    location_is_exact boolean DEFAULT false,
    delta boolean DEFAULT false,
    positional_accuracy integer,
    private_latitude numeric(15,10),
    private_longitude numeric(15,10),
    geoprivacy character varying(255),
    quality_grade character varying DEFAULT 'casual'::character varying,
    user_agent character varying(255),
    positioning_method character varying(255),
    positioning_device character varying(255),
    out_of_range boolean,
    license character varying(255),
    uri character varying(255),
    observation_photos_count integer DEFAULT 0,
    comments_count integer DEFAULT 0,
    geom public.geometry(Point),
    cached_tag_list character varying(768),
    zic_time_zone character varying(255),
    oauth_application_id integer,
    observation_sounds_count integer DEFAULT 0,
    identifications_count integer DEFAULT 0,
    private_geom public.geometry(Point),
    community_taxon_id integer,
    captive boolean DEFAULT false,
    site_id integer,
    uuid character varying(255),
    public_positional_accuracy integer,
    mappable boolean DEFAULT false,
    cached_votes_total integer DEFAULT 0,
    last_indexed_at timestamp without time zone,
    private_place_guess character varying,
    taxon_geoprivacy character varying
);


--
-- Name: observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.observations_id_seq OWNED BY public.observations.id;


--
-- Name: observations_places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observations_places (
    observation_id integer NOT NULL,
    place_id integer NOT NULL
);


--
-- Name: observations_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.observations_posts (
    observation_id integer NOT NULL,
    post_id integer NOT NULL
);


--
-- Name: passwords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.passwords (
    id integer NOT NULL,
    user_id integer,
    reset_code character varying(255),
    expiration_date timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: passwords_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.passwords_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: passwords_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.passwords_id_seq OWNED BY public.passwords.id;


--
-- Name: photo_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photo_metadata (
    photo_id integer NOT NULL,
    metadata bytea
);


--
-- Name: photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.photos (
    id integer NOT NULL,
    user_id integer,
    native_photo_id character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    native_page_url character varying(512),
    native_username character varying(255),
    native_realname character varying(255),
    license integer,
    type character varying(255),
    file_content_type character varying(255),
    file_file_name character varying(255),
    file_file_size integer,
    file_processing boolean,
    mobile boolean DEFAULT false,
    file_updated_at timestamp without time zone,
    subtype character varying(255),
    native_original_image_url character varying(512),
    uuid uuid DEFAULT public.uuid_generate_v4(),
    file_extension_id smallint,
    file_prefix_id smallint,
    width smallint,
    height smallint
);


--
-- Name: photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.photos_id_seq OWNED BY public.photos.id;


--
-- Name: picasa_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.picasa_identities (
    id integer NOT NULL,
    user_id integer,
    token character varying(255),
    token_created_at timestamp without time zone,
    picasa_user_id character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: picasa_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.picasa_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: picasa_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.picasa_identities_id_seq OWNED BY public.picasa_identities.id;


--
-- Name: place_geometries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.place_geometries (
    id integer NOT NULL,
    place_id integer,
    source_name character varying(255),
    source_identifier character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    source_filename character varying(255),
    geom public.geometry(MultiPolygon) NOT NULL,
    source_id integer
);


--
-- Name: place_geometries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.place_geometries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: place_geometries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.place_geometries_id_seq OWNED BY public.place_geometries.id;


--
-- Name: place_taxon_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.place_taxon_names (
    id integer NOT NULL,
    place_id integer,
    taxon_name_id integer,
    "position" integer DEFAULT 0
);


--
-- Name: place_taxon_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.place_taxon_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: place_taxon_names_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.place_taxon_names_id_seq OWNED BY public.place_taxon_names.id;


--
-- Name: places; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.places (
    id integer NOT NULL,
    name character varying(255),
    display_name character varying(255),
    code character varying(255),
    latitude numeric(15,10),
    longitude numeric(15,10),
    swlat numeric(15,10),
    swlng numeric(15,10),
    nelat numeric(15,10),
    nelng numeric(15,10),
    woeid integer,
    parent_id integer,
    check_list_id integer,
    place_type integer,
    bbox_area double precision,
    source_name character varying(255),
    source_identifier character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    delta boolean DEFAULT false,
    user_id integer,
    source_filename character varying(255),
    ancestry character varying(255),
    slug character varying(255),
    source_id integer,
    admin_level integer,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: places_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.places_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: places_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.places_id_seq OWNED BY public.places.id;


--
-- Name: places_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.places_sites (
    id bigint NOT NULL,
    site_id integer NOT NULL,
    place_id integer NOT NULL,
    scope character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: places_sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.places_sites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: places_sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.places_sites_id_seq OWNED BY public.places_sites.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    parent_id integer NOT NULL,
    parent_type character varying(255) NOT NULL,
    user_id integer NOT NULL,
    published_at timestamp without time zone,
    title character varying(255) NOT NULL,
    body text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    type character varying(255),
    start_time timestamp without time zone,
    stop_time timestamp without time zone,
    place_id integer,
    latitude numeric(15,10),
    longitude numeric(15,10),
    radius integer,
    distance double precision,
    number integer,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.preferences (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    owner_id integer NOT NULL,
    owner_type character varying(255) NOT NULL,
    group_id integer,
    group_type character varying(255),
    value text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.preferences_id_seq OWNED BY public.preferences.id;


--
-- Name: project_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_assets (
    id integer NOT NULL,
    project_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    asset_file_name character varying(255),
    asset_content_type character varying(255),
    asset_file_size integer,
    asset_updated_at timestamp without time zone
);


--
-- Name: project_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_assets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_assets_id_seq OWNED BY public.project_assets.id;


--
-- Name: project_observation_fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_observation_fields (
    id integer NOT NULL,
    project_id integer,
    observation_field_id integer,
    required boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    "position" integer
);


--
-- Name: project_observation_fields_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_observation_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_observation_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_observation_fields_id_seq OWNED BY public.project_observation_fields.id;


--
-- Name: project_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_observations (
    id integer NOT NULL,
    project_id integer,
    observation_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    curator_identification_id integer,
    tracking_code character varying(255),
    user_id integer,
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: project_observations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_observations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_observations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_observations_id_seq OWNED BY public.project_observations.id;


--
-- Name: project_user_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_user_invitations (
    id integer NOT NULL,
    user_id integer,
    invited_user_id integer,
    project_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: project_user_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_user_invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_user_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_user_invitations_id_seq OWNED BY public.project_user_invitations.id;


--
-- Name: project_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project_users (
    id integer NOT NULL,
    project_id integer,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    role character varying(255),
    observations_count integer DEFAULT 0,
    taxa_count integer DEFAULT 0
);


--
-- Name: project_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.project_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: project_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.project_users_id_seq OWNED BY public.project_users.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id integer NOT NULL,
    user_id integer,
    title character varying(255),
    description text,
    terms text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    icon_file_name character varying(255),
    icon_content_type character varying(255),
    icon_file_size integer,
    icon_updated_at timestamp without time zone,
    project_type character varying(255),
    slug character varying(255),
    observed_taxa_count integer DEFAULT 0,
    source_url character varying(255),
    tracking_codes character varying(255),
    delta boolean DEFAULT false,
    place_id integer,
    map_type character varying(255) DEFAULT 'terrain'::character varying,
    latitude numeric(15,10),
    longitude numeric(15,10),
    zoom_level integer,
    cover_file_name character varying(255),
    cover_content_type character varying(255),
    cover_file_size integer,
    cover_updated_at timestamp without time zone,
    event_url character varying(255),
    start_time timestamp without time zone,
    end_time timestamp without time zone,
    trusted boolean DEFAULT false,
    "group" character varying(255),
    last_aggregated_at timestamp without time zone,
    observation_requirements_updated_at timestamp without time zone
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: provider_authorizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.provider_authorizations (
    id integer NOT NULL,
    provider_name character varying(255) NOT NULL,
    provider_uid text,
    token text,
    user_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    scope character varying(255),
    secret character varying(255),
    refresh_token character varying
);


--
-- Name: provider_authorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.provider_authorizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: provider_authorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.provider_authorizations_id_seq OWNED BY public.provider_authorizations.id;


--
-- Name: quality_metrics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quality_metrics (
    id integer NOT NULL,
    user_id integer,
    observation_id integer,
    metric character varying(255),
    agree boolean DEFAULT true,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: quality_metrics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.quality_metrics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: quality_metrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.quality_metrics_id_seq OWNED BY public.quality_metrics.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying(255)
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: roles_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles_users (
    role_id integer,
    user_id integer
);


--
-- Name: rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rules (
    id integer NOT NULL,
    type character varying(255),
    ruler_type character varying(255),
    ruler_id integer,
    operand_type character varying(255),
    operand_id integer,
    operator character varying(255),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rules_id_seq OWNED BY public.rules.id;


--
-- Name: saved_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_locations (
    id integer NOT NULL,
    user_id integer,
    latitude numeric(15,10),
    longitude numeric(15,10),
    title character varying,
    positional_accuracy integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    geoprivacy text DEFAULT 'open'::text
);


--
-- Name: saved_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.saved_locations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: saved_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.saved_locations_id_seq OWNED BY public.saved_locations.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    session_id character varying NOT NULL,
    data text,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: simplified_tree_milestone_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.simplified_tree_milestone_taxa (
    id integer NOT NULL,
    taxon_id integer
);


--
-- Name: simplified_tree_milestone_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.simplified_tree_milestone_taxa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: simplified_tree_milestone_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.simplified_tree_milestone_taxa_id_seq OWNED BY public.simplified_tree_milestone_taxa.id;


--
-- Name: site_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_admins (
    id integer NOT NULL,
    user_id integer,
    site_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: site_admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_admins_id_seq OWNED BY public.site_admins.id;


--
-- Name: site_featured_projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_featured_projects (
    id integer NOT NULL,
    site_id integer,
    project_id integer,
    user_id integer,
    noteworthy boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: site_featured_projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_featured_projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_featured_projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_featured_projects_id_seq OWNED BY public.site_featured_projects.id;


--
-- Name: site_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_statistics (
    id integer NOT NULL,
    created_at timestamp without time zone,
    data json
);


--
-- Name: site_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_statistics_id_seq OWNED BY public.site_statistics.id;


--
-- Name: sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sites (
    id integer NOT NULL,
    name character varying(255),
    url character varying(255),
    place_id integer,
    source_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    logo_file_name character varying(255),
    logo_content_type character varying(255),
    logo_file_size integer,
    logo_updated_at timestamp without time zone,
    logo_square_file_name character varying(255),
    logo_square_content_type character varying(255),
    logo_square_file_size integer,
    logo_square_updated_at timestamp without time zone,
    stylesheet_file_name character varying(255),
    stylesheet_content_type character varying(255),
    stylesheet_file_size integer,
    stylesheet_updated_at timestamp without time zone,
    draft boolean DEFAULT false,
    homepage_data text,
    logo_email_banner_file_name character varying,
    logo_email_banner_content_type character varying,
    logo_email_banner_file_size integer,
    logo_email_banner_updated_at timestamp without time zone,
    domain character varying,
    coordinate_systems_json text,
    favicon_file_name character varying,
    favicon_content_type character varying,
    favicon_file_size bigint,
    favicon_updated_at timestamp without time zone,
    shareable_image_file_name character varying,
    shareable_image_content_type character varying,
    shareable_image_file_size bigint,
    shareable_image_updated_at timestamp without time zone,
    logo_blog_file_name character varying,
    logo_blog_content_type character varying,
    logo_blog_file_size bigint,
    logo_blog_updated_at timestamp without time zone
);


--
-- Name: sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sites_id_seq OWNED BY public.sites.id;


--
-- Name: soundcloud_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.soundcloud_identities (
    id integer NOT NULL,
    native_username character varying(255),
    native_realname character varying(255),
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: soundcloud_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.soundcloud_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: soundcloud_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.soundcloud_identities_id_seq OWNED BY public.soundcloud_identities.id;


--
-- Name: sounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sounds (
    id integer NOT NULL,
    user_id integer,
    native_username character varying(255),
    native_realname character varying(255),
    native_sound_id character varying(255),
    native_page_url character varying(255),
    license integer,
    type character varying(255),
    sound_url character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    native_response text,
    file_file_name character varying,
    file_content_type character varying,
    file_file_size integer,
    file_updated_at timestamp without time zone,
    subtype character varying(255),
    uuid uuid DEFAULT public.uuid_generate_v4()
);


--
-- Name: sounds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sounds_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sounds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sounds_id_seq OWNED BY public.sounds.id;


--
-- Name: sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sources (
    id integer NOT NULL,
    in_text character varying(255),
    citation character varying(512),
    url character varying(512),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    title character varying(255),
    user_id integer
);


--
-- Name: sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sources_id_seq OWNED BY public.sources.id;


--
-- Name: states_simplified_1; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.states_simplified_1 (
    id integer NOT NULL,
    place_geometry_id integer,
    place_id integer,
    geom public.geometry(MultiPolygon) NOT NULL
);


--
-- Name: states_simplified_1_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.states_simplified_1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: states_simplified_1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.states_simplified_1_id_seq OWNED BY public.states_simplified_1.id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id integer NOT NULL,
    user_id integer,
    resource_type character varying(255),
    resource_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    taxon_id integer
);


--
-- Name: subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subscriptions_id_seq OWNED BY public.subscriptions.id;


--
-- Name: taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taggings (
    id integer NOT NULL,
    tag_id integer,
    taggable_id integer,
    taggable_type character varying(255),
    created_at timestamp without time zone,
    tagger_id integer,
    tagger_type character varying,
    context character varying(128)
);


--
-- Name: taggings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taggings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taggings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taggings_id_seq OWNED BY public.taggings.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying(255),
    taggings_count integer DEFAULT 0
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxa (
    id integer NOT NULL,
    name character varying(255),
    rank character varying(255),
    source_identifier character varying(255),
    source_url character varying(255),
    source_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    iconic_taxon_id integer,
    is_iconic boolean DEFAULT false,
    auto_photos boolean DEFAULT true,
    auto_description boolean DEFAULT true,
    version integer,
    name_provider character varying(255),
    delta boolean DEFAULT false,
    creator_id integer,
    updater_id integer,
    observations_count integer DEFAULT 0,
    listed_taxa_count integer DEFAULT 0,
    rank_level double precision,
    wikipedia_summary text,
    wikipedia_title character varying(255),
    featured_at timestamp without time zone,
    ancestry character varying(255),
    locked boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    taxon_framework_relationship_id integer,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    photos_locked boolean DEFAULT false
);


--
-- Name: taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxa_id_seq OWNED BY public.taxa.id;


--
-- Name: taxon_change_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_change_taxa (
    id integer NOT NULL,
    taxon_change_id integer,
    taxon_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: taxon_change_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_change_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_change_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_change_taxa_id_seq OWNED BY public.taxon_change_taxa.id;


--
-- Name: taxon_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_changes (
    id integer NOT NULL,
    description text,
    taxon_id integer,
    source_id integer,
    user_id integer,
    type character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    committed_on date,
    change_group character varying(255),
    committer_id integer,
    move_children boolean DEFAULT false
);


--
-- Name: taxon_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_changes_id_seq OWNED BY public.taxon_changes.id;


--
-- Name: taxon_curators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_curators (
    id integer NOT NULL,
    user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    taxon_id integer,
    taxon_framework_id integer
);


--
-- Name: taxon_curators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_curators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_curators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_curators_id_seq OWNED BY public.taxon_curators.id;


--
-- Name: taxon_descriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_descriptions (
    id integer NOT NULL,
    taxon_id integer,
    locale character varying(255),
    body text,
    provider character varying,
    provider_taxon_id character varying,
    url character varying,
    title character varying
);


--
-- Name: taxon_descriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_descriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_descriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_descriptions_id_seq OWNED BY public.taxon_descriptions.id;


--
-- Name: taxon_framework_relationships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_framework_relationships (
    id integer NOT NULL,
    description text,
    relationship text DEFAULT 'unknown'::text,
    user_id integer,
    updater_id integer,
    taxon_framework_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: taxon_framework_relationships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_framework_relationships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_framework_relationships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_framework_relationships_id_seq OWNED BY public.taxon_framework_relationships.id;


--
-- Name: taxon_frameworks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_frameworks (
    id integer NOT NULL,
    taxon_id integer,
    description text,
    rank_level integer,
    complete boolean DEFAULT false,
    source_id integer,
    user_id integer,
    updater_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: taxon_frameworks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_frameworks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_frameworks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_frameworks_id_seq OWNED BY public.taxon_frameworks.id;


--
-- Name: taxon_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_links (
    id integer NOT NULL,
    url character varying(255) NOT NULL,
    site_title character varying(255),
    taxon_id integer NOT NULL,
    show_for_descendent_taxa boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    user_id integer,
    place_id integer,
    species_only boolean DEFAULT false,
    short_title character varying(10)
);


--
-- Name: taxon_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_links_id_seq OWNED BY public.taxon_links.id;


--
-- Name: taxon_name_priorities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_name_priorities (
    id integer NOT NULL,
    "position" smallint,
    user_id integer NOT NULL,
    place_id integer,
    lexicon character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: taxon_name_priorities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_name_priorities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_name_priorities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_name_priorities_id_seq OWNED BY public.taxon_name_priorities.id;


--
-- Name: taxon_names; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_names (
    id integer NOT NULL,
    name character varying(255),
    is_valid boolean,
    lexicon character varying(255),
    source_identifier character varying(255),
    source_url character varying(255),
    taxon_id integer,
    source_id integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    name_provider character varying(255),
    creator_id integer,
    updater_id integer,
    "position" integer DEFAULT 0,
    parameterized_lexicon character varying
);


--
-- Name: taxon_names_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_names_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_names_id_seq OWNED BY public.taxon_names.id;


--
-- Name: taxon_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_photos (
    id integer NOT NULL,
    taxon_id integer NOT NULL,
    photo_id integer NOT NULL,
    "position" integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: taxon_photos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_photos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_photos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_photos_id_seq OWNED BY public.taxon_photos.id;


--
-- Name: taxon_ranges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_ranges (
    id integer NOT NULL,
    taxon_id integer,
    source character varying(255),
    start_month integer,
    end_month integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    range_type character varying(255),
    range_content_type character varying(255),
    range_file_name character varying(255),
    range_file_size integer,
    description text,
    source_id integer,
    source_identifier integer,
    range_updated_at timestamp without time zone,
    geom public.geometry(MultiPolygon),
    url character varying(255),
    user_id integer,
    updater_id integer,
    iucn_relationship integer
);


--
-- Name: taxon_ranges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_ranges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_ranges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_ranges_id_seq OWNED BY public.taxon_ranges.id;


--
-- Name: taxon_scheme_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_scheme_taxa (
    id integer NOT NULL,
    taxon_scheme_id integer,
    taxon_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    source_identifier character varying(255),
    taxon_name_id integer
);


--
-- Name: taxon_scheme_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_scheme_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_scheme_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_scheme_taxa_id_seq OWNED BY public.taxon_scheme_taxa.id;


--
-- Name: taxon_schemes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.taxon_schemes (
    id integer NOT NULL,
    title character varying(255),
    description text,
    source_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: taxon_schemes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.taxon_schemes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: taxon_schemes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.taxon_schemes_id_seq OWNED BY public.taxon_schemes.id;


--
-- Name: time_zone_geometries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.time_zone_geometries (
    ogc_fid integer NOT NULL,
    tzid character varying(80),
    geom public.geometry(MultiPolygon)
);


--
-- Name: time_zone_geometries_ogc_fid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.time_zone_geometries_ogc_fid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: time_zone_geometries_ogc_fid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.time_zone_geometries_ogc_fid_seq OWNED BY public.time_zone_geometries.ogc_fid;


--
-- Name: trip_purposes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_purposes (
    id integer NOT NULL,
    trip_id integer,
    purpose character varying(255),
    resource_type character varying(255),
    resource_id integer,
    success boolean,
    complete boolean DEFAULT false,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: trip_purposes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_purposes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_purposes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_purposes_id_seq OWNED BY public.trip_purposes.id;


--
-- Name: trip_taxa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trip_taxa (
    id integer NOT NULL,
    taxon_id integer,
    trip_id integer,
    observed boolean,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: trip_taxa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trip_taxa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trip_taxa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trip_taxa_id_seq OWNED BY public.trip_taxa.id;


--
-- Name: update_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.update_actions (
    id integer NOT NULL,
    resource_id integer,
    resource_type character varying,
    notifier_type character varying,
    notifier_id integer,
    notification character varying,
    resource_owner_id integer,
    created_at timestamp without time zone
);


--
-- Name: update_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.update_actions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: update_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.update_actions_id_seq OWNED BY public.update_actions.id;


--
-- Name: user_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_blocks (
    id integer NOT NULL,
    user_id integer,
    blocked_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    override_user_id integer
);


--
-- Name: user_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_blocks_id_seq OWNED BY public.user_blocks.id;


--
-- Name: user_mutes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_mutes (
    id integer NOT NULL,
    user_id integer,
    muted_user_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_mutes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_mutes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_mutes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_mutes_id_seq OWNED BY public.user_mutes.id;


--
-- Name: user_parents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_parents (
    id integer NOT NULL,
    user_id integer,
    parent_user_id integer,
    name character varying,
    email character varying,
    child_name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    donorbox_donor_id integer
);


--
-- Name: user_parents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_parents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_parents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_parents_id_seq OWNED BY public.user_parents.id;


--
-- Name: user_privileges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_privileges (
    id integer NOT NULL,
    user_id integer,
    privilege character varying,
    revoked_at timestamp without time zone,
    revoke_user_id integer,
    revoke_reason character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: user_privileges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_privileges_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_privileges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_privileges_id_seq OWNED BY public.user_privileges.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    login character varying(40),
    name character varying(100),
    email character varying(100),
    encrypted_password character varying(128) DEFAULT ''::character varying NOT NULL,
    password_salt character varying(255) DEFAULT ''::character varying NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    remember_token character varying(40),
    remember_token_expires_at timestamp without time zone,
    confirmation_token character varying(255),
    confirmed_at timestamp without time zone,
    state character varying(255) DEFAULT 'passive'::character varying,
    deleted_at timestamp without time zone,
    time_zone character varying(255),
    description text,
    life_list_id integer,
    observations_count integer DEFAULT 0,
    identifications_count integer DEFAULT 0,
    journal_posts_count integer DEFAULT 0,
    life_list_taxa_count integer DEFAULT 0,
    old_preferences text,
    icon_url character varying(255),
    last_ip character varying(255),
    confirmation_sent_at timestamp without time zone,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    suspended_at timestamp without time zone,
    suspension_reason character varying(255),
    uri character varying(255),
    locale character varying(255),
    site_id integer,
    place_id integer,
    spammer boolean,
    spam_count integer DEFAULT 0,
    last_active date,
    subscriptions_suspended_at timestamp without time zone,
    test_groups character varying,
    latitude double precision,
    longitude double precision,
    lat_lon_acc_admin_level integer,
    icon_file_name character varying,
    icon_content_type character varying,
    icon_file_size integer,
    icon_updated_at timestamp without time zone,
    search_place_id integer,
    curator_sponsor_id integer,
    suspended_by_user_id integer,
    birthday date,
    pi_consent_at timestamp without time zone,
    donorbox_donor_id integer,
    donorbox_plan_type character varying,
    donorbox_plan_status character varying,
    donorbox_plan_started_at date,
    uuid uuid DEFAULT public.uuid_generate_v4(),
    species_count integer DEFAULT 0,
    locked_at timestamp without time zone,
    failed_attempts integer DEFAULT 0,
    unlock_token character varying,
    oauth_application_id integer,
    data_transfer_consent_at timestamp without time zone,
    unconfirmed_email character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.votes (
    id integer NOT NULL,
    votable_id integer,
    votable_type character varying,
    voter_id integer,
    voter_type character varying,
    vote_flag boolean,
    vote_scope character varying,
    vote_weight integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.votes_id_seq OWNED BY public.votes.id;


--
-- Name: wiki_page_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_page_attachments (
    id integer NOT NULL,
    page_id integer NOT NULL,
    wiki_page_attachment_file_name character varying(255),
    wiki_page_attachment_content_type character varying(255),
    wiki_page_attachment_file_size integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: wiki_page_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wiki_page_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_page_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wiki_page_attachments_id_seq OWNED BY public.wiki_page_attachments.id;


--
-- Name: wiki_page_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_page_versions (
    id integer NOT NULL,
    page_id integer NOT NULL,
    updator_id integer,
    number integer,
    comment character varying(255),
    path character varying(255),
    title character varying(255),
    content text,
    updated_at timestamp without time zone
);


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wiki_page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_page_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wiki_page_versions_id_seq OWNED BY public.wiki_page_versions.id;


--
-- Name: wiki_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wiki_pages (
    id integer NOT NULL,
    creator_id integer,
    updator_id integer,
    path character varying(255),
    title character varying(255),
    content text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    admin_only boolean DEFAULT false
);


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.wiki_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: wiki_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.wiki_pages_id_seq OWNED BY public.wiki_pages.id;


--
-- Name: year_statistic_localized_shareable_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.year_statistic_localized_shareable_images (
    id bigint NOT NULL,
    year_statistic_id integer NOT NULL,
    locale character varying NOT NULL,
    shareable_image_file_name character varying,
    shareable_image_content_type character varying,
    shareable_image_file_size bigint,
    shareable_image_updated_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: year_statistic_localized_shareable_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.year_statistic_localized_shareable_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: year_statistic_localized_shareable_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.year_statistic_localized_shareable_images_id_seq OWNED BY public.year_statistic_localized_shareable_images.id;


--
-- Name: year_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.year_statistics (
    id integer NOT NULL,
    user_id integer,
    year integer,
    data json,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    site_id integer,
    shareable_image_file_name character varying,
    shareable_image_content_type character varying,
    shareable_image_file_size integer,
    shareable_image_updated_at timestamp without time zone
);


--
-- Name: year_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.year_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: year_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.year_statistics_id_seq OWNED BY public.year_statistics.id;


--
-- Name: annotations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotations ALTER COLUMN id SET DEFAULT nextval('public.annotations_id_seq'::regclass);


--
-- Name: announcements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements ALTER COLUMN id SET DEFAULT nextval('public.announcements_id_seq'::regclass);


--
-- Name: api_endpoint_caches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_endpoint_caches ALTER COLUMN id SET DEFAULT nextval('public.api_endpoint_caches_id_seq'::regclass);


--
-- Name: api_endpoints id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_endpoints ALTER COLUMN id SET DEFAULT nextval('public.api_endpoints_id_seq'::regclass);


--
-- Name: assessment_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessment_sections ALTER COLUMN id SET DEFAULT nextval('public.assessment_sections_id_seq'::regclass);


--
-- Name: assessments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessments ALTER COLUMN id SET DEFAULT nextval('public.assessments_id_seq'::regclass);


--
-- Name: atlas_alterations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atlas_alterations ALTER COLUMN id SET DEFAULT nextval('public.atlas_alterations_id_seq'::regclass);


--
-- Name: atlases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atlases ALTER COLUMN id SET DEFAULT nextval('public.atlases_id_seq'::regclass);


--
-- Name: audits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audits ALTER COLUMN id SET DEFAULT nextval('public.audits_id_seq'::regclass);


--
-- Name: colors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colors ALTER COLUMN id SET DEFAULT nextval('public.colors_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: complete_sets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complete_sets ALTER COLUMN id SET DEFAULT nextval('public.complete_sets_id_seq'::regclass);


--
-- Name: computer_vision_demo_uploads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.computer_vision_demo_uploads ALTER COLUMN id SET DEFAULT nextval('public.computer_vision_demo_uploads_id_seq'::regclass);


--
-- Name: conservation_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conservation_statuses ALTER COLUMN id SET DEFAULT nextval('public.conservation_statuses_id_seq'::regclass);


--
-- Name: controlled_term_labels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_term_labels ALTER COLUMN id SET DEFAULT nextval('public.controlled_term_labels_id_seq'::regclass);


--
-- Name: controlled_term_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_term_taxa ALTER COLUMN id SET DEFAULT nextval('public.controlled_term_taxa_id_seq'::regclass);


--
-- Name: controlled_term_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_term_values ALTER COLUMN id SET DEFAULT nextval('public.controlled_term_values_id_seq'::regclass);


--
-- Name: controlled_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_terms ALTER COLUMN id SET DEFAULT nextval('public.controlled_terms_id_seq'::regclass);


--
-- Name: counties_simplified_01 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counties_simplified_01 ALTER COLUMN id SET DEFAULT nextval('public.counties_simplified_01_id_seq'::regclass);


--
-- Name: countries_simplified_1 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries_simplified_1 ALTER COLUMN id SET DEFAULT nextval('public.countries_simplified_1_id_seq'::regclass);


--
-- Name: custom_projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_projects ALTER COLUMN id SET DEFAULT nextval('public.custom_projects_id_seq'::regclass);


--
-- Name: data_partners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_partners ALTER COLUMN id SET DEFAULT nextval('public.data_partners_id_seq'::regclass);


--
-- Name: delayed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);


--
-- Name: deleted_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_observations ALTER COLUMN id SET DEFAULT nextval('public.deleted_observations_id_seq'::regclass);


--
-- Name: deleted_photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_photos ALTER COLUMN id SET DEFAULT nextval('public.deleted_photos_id_seq'::regclass);


--
-- Name: deleted_sounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_sounds ALTER COLUMN id SET DEFAULT nextval('public.deleted_sounds_id_seq'::regclass);


--
-- Name: deleted_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_users ALTER COLUMN id SET DEFAULT nextval('public.deleted_users_id_seq'::regclass);


--
-- Name: email_suppressions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_suppressions ALTER COLUMN id SET DEFAULT nextval('public.email_suppressions_id_seq'::regclass);


--
-- Name: exploded_atlas_places id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exploded_atlas_places ALTER COLUMN id SET DEFAULT nextval('public.exploded_atlas_places_id_seq'::regclass);


--
-- Name: external_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_taxa ALTER COLUMN id SET DEFAULT nextval('public.external_taxa_id_seq'::regclass);


--
-- Name: file_extensions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_extensions ALTER COLUMN id SET DEFAULT nextval('public.file_extensions_id_seq'::regclass);


--
-- Name: file_prefixes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_prefixes ALTER COLUMN id SET DEFAULT nextval('public.file_prefixes_id_seq'::regclass);


--
-- Name: flags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags ALTER COLUMN id SET DEFAULT nextval('public.flags_id_seq'::regclass);


--
-- Name: flickr_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flickr_identities ALTER COLUMN id SET DEFAULT nextval('public.flickr_identities_id_seq'::regclass);


--
-- Name: flow_task_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_task_resources ALTER COLUMN id SET DEFAULT nextval('public.flow_task_resources_id_seq'::regclass);


--
-- Name: flow_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_tasks ALTER COLUMN id SET DEFAULT nextval('public.flow_tasks_id_seq'::regclass);


--
-- Name: frequency_cells id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frequency_cells ALTER COLUMN id SET DEFAULT nextval('public.frequency_cells_id_seq'::regclass);


--
-- Name: friendly_id_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs ALTER COLUMN id SET DEFAULT nextval('public.friendly_id_slugs_id_seq'::regclass);


--
-- Name: friendships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships ALTER COLUMN id SET DEFAULT nextval('public.friendships_id_seq'::regclass);


--
-- Name: geo_model_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.geo_model_taxa ALTER COLUMN id SET DEFAULT nextval('public.geo_model_taxa_id_seq'::regclass);


--
-- Name: goal_contributions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_contributions ALTER COLUMN id SET DEFAULT nextval('public.goal_contributions_id_seq'::regclass);


--
-- Name: goal_participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_participants ALTER COLUMN id SET DEFAULT nextval('public.goal_participants_id_seq'::regclass);


--
-- Name: goal_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_rules ALTER COLUMN id SET DEFAULT nextval('public.goal_rules_id_seq'::regclass);


--
-- Name: goals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals ALTER COLUMN id SET DEFAULT nextval('public.goals_id_seq'::regclass);


--
-- Name: guide_photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_photos ALTER COLUMN id SET DEFAULT nextval('public.guide_photos_id_seq'::regclass);


--
-- Name: guide_ranges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_ranges ALTER COLUMN id SET DEFAULT nextval('public.guide_ranges_id_seq'::regclass);


--
-- Name: guide_sections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_sections ALTER COLUMN id SET DEFAULT nextval('public.guide_sections_id_seq'::regclass);


--
-- Name: guide_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_taxa ALTER COLUMN id SET DEFAULT nextval('public.guide_taxa_id_seq'::regclass);


--
-- Name: guide_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_users ALTER COLUMN id SET DEFAULT nextval('public.guide_users_id_seq'::regclass);


--
-- Name: guides id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guides ALTER COLUMN id SET DEFAULT nextval('public.guides_id_seq'::regclass);


--
-- Name: identifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifications ALTER COLUMN id SET DEFAULT nextval('public.identifications_id_seq'::regclass);


--
-- Name: list_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_rules ALTER COLUMN id SET DEFAULT nextval('public.list_rules_id_seq'::regclass);


--
-- Name: listed_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listed_taxa ALTER COLUMN id SET DEFAULT nextval('public.listed_taxa_id_seq'::regclass);


--
-- Name: listed_taxon_alterations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listed_taxon_alterations ALTER COLUMN id SET DEFAULT nextval('public.listed_taxon_alterations_id_seq'::regclass);


--
-- Name: lists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lists ALTER COLUMN id SET DEFAULT nextval('public.lists_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: model_attribute_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_attribute_changes ALTER COLUMN id SET DEFAULT nextval('public.model_attribute_changes_id_seq'::regclass);


--
-- Name: moderator_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderator_actions ALTER COLUMN id SET DEFAULT nextval('public.moderator_actions_id_seq'::regclass);


--
-- Name: moderator_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderator_notes ALTER COLUMN id SET DEFAULT nextval('public.moderator_notes_id_seq'::regclass);


--
-- Name: oauth_access_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_grants_id_seq'::regclass);


--
-- Name: oauth_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_tokens_id_seq'::regclass);


--
-- Name: oauth_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_applications ALTER COLUMN id SET DEFAULT nextval('public.oauth_applications_id_seq'::regclass);


--
-- Name: observation_accuracy_experiments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_accuracy_experiments ALTER COLUMN id SET DEFAULT nextval('public.observation_accuracy_experiments_id_seq'::regclass);


--
-- Name: observation_accuracy_samples id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_accuracy_samples ALTER COLUMN id SET DEFAULT nextval('public.observation_accuracy_samples_id_seq'::regclass);


--
-- Name: observation_accuracy_validators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_accuracy_validators ALTER COLUMN id SET DEFAULT nextval('public.observation_accuracy_validators_id_seq'::regclass);


--
-- Name: observation_field_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_field_values ALTER COLUMN id SET DEFAULT nextval('public.observation_field_values_id_seq'::regclass);


--
-- Name: observation_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_fields ALTER COLUMN id SET DEFAULT nextval('public.observation_fields_id_seq'::regclass);


--
-- Name: observation_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_links ALTER COLUMN id SET DEFAULT nextval('public.observation_links_id_seq'::regclass);


--
-- Name: observation_photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_photos ALTER COLUMN id SET DEFAULT nextval('public.observation_photos_id_seq'::regclass);


--
-- Name: observation_reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_reviews ALTER COLUMN id SET DEFAULT nextval('public.observation_reviews_id_seq'::regclass);


--
-- Name: observation_sounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_sounds ALTER COLUMN id SET DEFAULT nextval('public.observation_sounds_id_seq'::regclass);


--
-- Name: observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observations ALTER COLUMN id SET DEFAULT nextval('public.observations_id_seq'::regclass);


--
-- Name: passwords id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.passwords ALTER COLUMN id SET DEFAULT nextval('public.passwords_id_seq'::regclass);


--
-- Name: photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos ALTER COLUMN id SET DEFAULT nextval('public.photos_id_seq'::regclass);


--
-- Name: picasa_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picasa_identities ALTER COLUMN id SET DEFAULT nextval('public.picasa_identities_id_seq'::regclass);


--
-- Name: place_geometries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_geometries ALTER COLUMN id SET DEFAULT nextval('public.place_geometries_id_seq'::regclass);


--
-- Name: place_taxon_names id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_taxon_names ALTER COLUMN id SET DEFAULT nextval('public.place_taxon_names_id_seq'::regclass);


--
-- Name: places id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places ALTER COLUMN id SET DEFAULT nextval('public.places_id_seq'::regclass);


--
-- Name: places_sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places_sites ALTER COLUMN id SET DEFAULT nextval('public.places_sites_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preferences ALTER COLUMN id SET DEFAULT nextval('public.preferences_id_seq'::regclass);


--
-- Name: project_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_assets ALTER COLUMN id SET DEFAULT nextval('public.project_assets_id_seq'::regclass);


--
-- Name: project_observation_fields id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_observation_fields ALTER COLUMN id SET DEFAULT nextval('public.project_observation_fields_id_seq'::regclass);


--
-- Name: project_observations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_observations ALTER COLUMN id SET DEFAULT nextval('public.project_observations_id_seq'::regclass);


--
-- Name: project_user_invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_user_invitations ALTER COLUMN id SET DEFAULT nextval('public.project_user_invitations_id_seq'::regclass);


--
-- Name: project_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_users ALTER COLUMN id SET DEFAULT nextval('public.project_users_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: provider_authorizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provider_authorizations ALTER COLUMN id SET DEFAULT nextval('public.provider_authorizations_id_seq'::regclass);


--
-- Name: quality_metrics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_metrics ALTER COLUMN id SET DEFAULT nextval('public.quality_metrics_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules ALTER COLUMN id SET DEFAULT nextval('public.rules_id_seq'::regclass);


--
-- Name: saved_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_locations ALTER COLUMN id SET DEFAULT nextval('public.saved_locations_id_seq'::regclass);


--
-- Name: simplified_tree_milestone_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simplified_tree_milestone_taxa ALTER COLUMN id SET DEFAULT nextval('public.simplified_tree_milestone_taxa_id_seq'::regclass);


--
-- Name: site_admins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_admins ALTER COLUMN id SET DEFAULT nextval('public.site_admins_id_seq'::regclass);


--
-- Name: site_featured_projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_featured_projects ALTER COLUMN id SET DEFAULT nextval('public.site_featured_projects_id_seq'::regclass);


--
-- Name: site_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_statistics ALTER COLUMN id SET DEFAULT nextval('public.site_statistics_id_seq'::regclass);


--
-- Name: sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites ALTER COLUMN id SET DEFAULT nextval('public.sites_id_seq'::regclass);


--
-- Name: soundcloud_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.soundcloud_identities ALTER COLUMN id SET DEFAULT nextval('public.soundcloud_identities_id_seq'::regclass);


--
-- Name: sounds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sounds ALTER COLUMN id SET DEFAULT nextval('public.sounds_id_seq'::regclass);


--
-- Name: sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sources ALTER COLUMN id SET DEFAULT nextval('public.sources_id_seq'::regclass);


--
-- Name: states_simplified_1 id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states_simplified_1 ALTER COLUMN id SET DEFAULT nextval('public.states_simplified_1_id_seq'::regclass);


--
-- Name: subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions ALTER COLUMN id SET DEFAULT nextval('public.subscriptions_id_seq'::regclass);


--
-- Name: taggings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings ALTER COLUMN id SET DEFAULT nextval('public.taggings_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxa ALTER COLUMN id SET DEFAULT nextval('public.taxa_id_seq'::regclass);


--
-- Name: taxon_change_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_change_taxa ALTER COLUMN id SET DEFAULT nextval('public.taxon_change_taxa_id_seq'::regclass);


--
-- Name: taxon_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_changes ALTER COLUMN id SET DEFAULT nextval('public.taxon_changes_id_seq'::regclass);


--
-- Name: taxon_curators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_curators ALTER COLUMN id SET DEFAULT nextval('public.taxon_curators_id_seq'::regclass);


--
-- Name: taxon_descriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_descriptions ALTER COLUMN id SET DEFAULT nextval('public.taxon_descriptions_id_seq'::regclass);


--
-- Name: taxon_framework_relationships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_framework_relationships ALTER COLUMN id SET DEFAULT nextval('public.taxon_framework_relationships_id_seq'::regclass);


--
-- Name: taxon_frameworks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_frameworks ALTER COLUMN id SET DEFAULT nextval('public.taxon_frameworks_id_seq'::regclass);


--
-- Name: taxon_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_links ALTER COLUMN id SET DEFAULT nextval('public.taxon_links_id_seq'::regclass);


--
-- Name: taxon_name_priorities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_name_priorities ALTER COLUMN id SET DEFAULT nextval('public.taxon_name_priorities_id_seq'::regclass);


--
-- Name: taxon_names id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_names ALTER COLUMN id SET DEFAULT nextval('public.taxon_names_id_seq'::regclass);


--
-- Name: taxon_photos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_photos ALTER COLUMN id SET DEFAULT nextval('public.taxon_photos_id_seq'::regclass);


--
-- Name: taxon_ranges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_ranges ALTER COLUMN id SET DEFAULT nextval('public.taxon_ranges_id_seq'::regclass);


--
-- Name: taxon_scheme_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_scheme_taxa ALTER COLUMN id SET DEFAULT nextval('public.taxon_scheme_taxa_id_seq'::regclass);


--
-- Name: taxon_schemes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_schemes ALTER COLUMN id SET DEFAULT nextval('public.taxon_schemes_id_seq'::regclass);


--
-- Name: time_zone_geometries ogc_fid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_zone_geometries ALTER COLUMN ogc_fid SET DEFAULT nextval('public.time_zone_geometries_ogc_fid_seq'::regclass);


--
-- Name: trip_purposes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_purposes ALTER COLUMN id SET DEFAULT nextval('public.trip_purposes_id_seq'::regclass);


--
-- Name: trip_taxa id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_taxa ALTER COLUMN id SET DEFAULT nextval('public.trip_taxa_id_seq'::regclass);


--
-- Name: update_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.update_actions ALTER COLUMN id SET DEFAULT nextval('public.update_actions_id_seq'::regclass);


--
-- Name: user_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks ALTER COLUMN id SET DEFAULT nextval('public.user_blocks_id_seq'::regclass);


--
-- Name: user_mutes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_mutes ALTER COLUMN id SET DEFAULT nextval('public.user_mutes_id_seq'::regclass);


--
-- Name: user_parents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_parents ALTER COLUMN id SET DEFAULT nextval('public.user_parents_id_seq'::regclass);


--
-- Name: user_privileges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_privileges ALTER COLUMN id SET DEFAULT nextval('public.user_privileges_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes ALTER COLUMN id SET DEFAULT nextval('public.votes_id_seq'::regclass);


--
-- Name: wiki_page_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_attachments ALTER COLUMN id SET DEFAULT nextval('public.wiki_page_attachments_id_seq'::regclass);


--
-- Name: wiki_page_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions ALTER COLUMN id SET DEFAULT nextval('public.wiki_page_versions_id_seq'::regclass);


--
-- Name: wiki_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages ALTER COLUMN id SET DEFAULT nextval('public.wiki_pages_id_seq'::regclass);


--
-- Name: year_statistic_localized_shareable_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.year_statistic_localized_shareable_images ALTER COLUMN id SET DEFAULT nextval('public.year_statistic_localized_shareable_images_id_seq'::regclass);


--
-- Name: year_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.year_statistics ALTER COLUMN id SET DEFAULT nextval('public.year_statistics_id_seq'::regclass);


--
-- Name: annotations annotations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.annotations
    ADD CONSTRAINT annotations_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: api_endpoint_caches api_endpoint_caches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_endpoint_caches
    ADD CONSTRAINT api_endpoint_caches_pkey PRIMARY KEY (id);


--
-- Name: api_endpoints api_endpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_endpoints
    ADD CONSTRAINT api_endpoints_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: assessment_sections assessment_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessment_sections
    ADD CONSTRAINT assessment_sections_pkey PRIMARY KEY (id);


--
-- Name: assessments assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assessments
    ADD CONSTRAINT assessments_pkey PRIMARY KEY (id);


--
-- Name: atlas_alterations atlas_alterations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atlas_alterations
    ADD CONSTRAINT atlas_alterations_pkey PRIMARY KEY (id);


--
-- Name: atlases atlases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.atlases
    ADD CONSTRAINT atlases_pkey PRIMARY KEY (id);


--
-- Name: audits audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audits
    ADD CONSTRAINT audits_pkey PRIMARY KEY (id);


--
-- Name: colors colors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.colors
    ADD CONSTRAINT colors_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: complete_sets complete_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.complete_sets
    ADD CONSTRAINT complete_sets_pkey PRIMARY KEY (id);


--
-- Name: computer_vision_demo_uploads computer_vision_demo_uploads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.computer_vision_demo_uploads
    ADD CONSTRAINT computer_vision_demo_uploads_pkey PRIMARY KEY (id);


--
-- Name: conservation_statuses conservation_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conservation_statuses
    ADD CONSTRAINT conservation_statuses_pkey PRIMARY KEY (id);


--
-- Name: controlled_term_labels controlled_term_labels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_term_labels
    ADD CONSTRAINT controlled_term_labels_pkey PRIMARY KEY (id);


--
-- Name: controlled_term_taxa controlled_term_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_term_taxa
    ADD CONSTRAINT controlled_term_taxa_pkey PRIMARY KEY (id);


--
-- Name: controlled_term_values controlled_term_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_term_values
    ADD CONSTRAINT controlled_term_values_pkey PRIMARY KEY (id);


--
-- Name: controlled_terms controlled_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.controlled_terms
    ADD CONSTRAINT controlled_terms_pkey PRIMARY KEY (id);


--
-- Name: counties_simplified_01 counties_simplified_01_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.counties_simplified_01
    ADD CONSTRAINT counties_simplified_01_pkey PRIMARY KEY (id);


--
-- Name: countries_simplified_1 countries_simplified_1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries_simplified_1
    ADD CONSTRAINT countries_simplified_1_pkey PRIMARY KEY (id);


--
-- Name: custom_projects custom_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_projects
    ADD CONSTRAINT custom_projects_pkey PRIMARY KEY (id);


--
-- Name: data_partners data_partners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_partners
    ADD CONSTRAINT data_partners_pkey PRIMARY KEY (id);


--
-- Name: delayed_jobs delayed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);


--
-- Name: deleted_observations deleted_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_observations
    ADD CONSTRAINT deleted_observations_pkey PRIMARY KEY (id);


--
-- Name: deleted_photos deleted_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_photos
    ADD CONSTRAINT deleted_photos_pkey PRIMARY KEY (id);


--
-- Name: deleted_sounds deleted_sounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_sounds
    ADD CONSTRAINT deleted_sounds_pkey PRIMARY KEY (id);


--
-- Name: deleted_users deleted_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deleted_users
    ADD CONSTRAINT deleted_users_pkey PRIMARY KEY (id);


--
-- Name: email_suppressions email_suppressions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_suppressions
    ADD CONSTRAINT email_suppressions_pkey PRIMARY KEY (id);


--
-- Name: exploded_atlas_places exploded_atlas_places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exploded_atlas_places
    ADD CONSTRAINT exploded_atlas_places_pkey PRIMARY KEY (id);


--
-- Name: external_taxa external_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.external_taxa
    ADD CONSTRAINT external_taxa_pkey PRIMARY KEY (id);


--
-- Name: file_extensions file_extensions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_extensions
    ADD CONSTRAINT file_extensions_pkey PRIMARY KEY (id);


--
-- Name: file_prefixes file_prefixes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_prefixes
    ADD CONSTRAINT file_prefixes_pkey PRIMARY KEY (id);


--
-- Name: flags flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flags
    ADD CONSTRAINT flags_pkey PRIMARY KEY (id);


--
-- Name: flickr_identities flickr_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flickr_identities
    ADD CONSTRAINT flickr_identities_pkey PRIMARY KEY (id);


--
-- Name: flow_task_resources flow_task_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_task_resources
    ADD CONSTRAINT flow_task_resources_pkey PRIMARY KEY (id);


--
-- Name: flow_tasks flow_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_tasks
    ADD CONSTRAINT flow_tasks_pkey PRIMARY KEY (id);


--
-- Name: frequency_cells frequency_cells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.frequency_cells
    ADD CONSTRAINT frequency_cells_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: friendships friendships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_pkey PRIMARY KEY (id);


--
-- Name: geo_model_taxa geo_model_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.geo_model_taxa
    ADD CONSTRAINT geo_model_taxa_pkey PRIMARY KEY (id);


--
-- Name: goal_contributions goal_contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_contributions
    ADD CONSTRAINT goal_contributions_pkey PRIMARY KEY (id);


--
-- Name: goal_participants goal_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_participants
    ADD CONSTRAINT goal_participants_pkey PRIMARY KEY (id);


--
-- Name: goal_rules goal_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goal_rules
    ADD CONSTRAINT goal_rules_pkey PRIMARY KEY (id);


--
-- Name: goals goals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goals
    ADD CONSTRAINT goals_pkey PRIMARY KEY (id);


--
-- Name: guide_photos guide_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_photos
    ADD CONSTRAINT guide_photos_pkey PRIMARY KEY (id);


--
-- Name: guide_ranges guide_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_ranges
    ADD CONSTRAINT guide_ranges_pkey PRIMARY KEY (id);


--
-- Name: guide_sections guide_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_sections
    ADD CONSTRAINT guide_sections_pkey PRIMARY KEY (id);


--
-- Name: guide_taxa guide_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_taxa
    ADD CONSTRAINT guide_taxa_pkey PRIMARY KEY (id);


--
-- Name: guide_users guide_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guide_users
    ADD CONSTRAINT guide_users_pkey PRIMARY KEY (id);


--
-- Name: guides guides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.guides
    ADD CONSTRAINT guides_pkey PRIMARY KEY (id);


--
-- Name: identifications identifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.identifications
    ADD CONSTRAINT identifications_pkey PRIMARY KEY (id);


--
-- Name: list_rules list_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.list_rules
    ADD CONSTRAINT list_rules_pkey PRIMARY KEY (id);


--
-- Name: listed_taxa listed_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listed_taxa
    ADD CONSTRAINT listed_taxa_pkey PRIMARY KEY (id);


--
-- Name: listed_taxon_alterations listed_taxon_alterations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.listed_taxon_alterations
    ADD CONSTRAINT listed_taxon_alterations_pkey PRIMARY KEY (id);


--
-- Name: lists lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lists
    ADD CONSTRAINT lists_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: model_attribute_changes model_attribute_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_attribute_changes
    ADD CONSTRAINT model_attribute_changes_pkey PRIMARY KEY (id);


--
-- Name: moderator_actions moderator_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderator_actions
    ADD CONSTRAINT moderator_actions_pkey PRIMARY KEY (id);


--
-- Name: moderator_notes moderator_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moderator_notes
    ADD CONSTRAINT moderator_notes_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_grants oauth_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens oauth_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_applications oauth_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);


--
-- Name: observation_accuracy_experiments observation_accuracy_experiments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_accuracy_experiments
    ADD CONSTRAINT observation_accuracy_experiments_pkey PRIMARY KEY (id);


--
-- Name: observation_accuracy_samples observation_accuracy_samples_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_accuracy_samples
    ADD CONSTRAINT observation_accuracy_samples_pkey PRIMARY KEY (id);


--
-- Name: observation_accuracy_validators observation_accuracy_validators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_accuracy_validators
    ADD CONSTRAINT observation_accuracy_validators_pkey PRIMARY KEY (id);


--
-- Name: observation_field_values observation_field_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_field_values
    ADD CONSTRAINT observation_field_values_pkey PRIMARY KEY (id);


--
-- Name: observation_fields observation_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_fields
    ADD CONSTRAINT observation_fields_pkey PRIMARY KEY (id);


--
-- Name: observation_links observation_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_links
    ADD CONSTRAINT observation_links_pkey PRIMARY KEY (id);


--
-- Name: observation_photos observation_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_photos
    ADD CONSTRAINT observation_photos_pkey PRIMARY KEY (id);


--
-- Name: observation_reviews observation_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_reviews
    ADD CONSTRAINT observation_reviews_pkey PRIMARY KEY (id);


--
-- Name: observations observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observations
    ADD CONSTRAINT observations_pkey PRIMARY KEY (id);


--
-- Name: observation_sounds observations_sounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.observation_sounds
    ADD CONSTRAINT observations_sounds_pkey PRIMARY KEY (id);


--
-- Name: passwords passwords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.passwords
    ADD CONSTRAINT passwords_pkey PRIMARY KEY (id);


--
-- Name: photos photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.photos
    ADD CONSTRAINT photos_pkey PRIMARY KEY (id);


--
-- Name: picasa_identities picasa_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picasa_identities
    ADD CONSTRAINT picasa_identities_pkey PRIMARY KEY (id);


--
-- Name: place_geometries place_geometries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_geometries
    ADD CONSTRAINT place_geometries_pkey PRIMARY KEY (id);


--
-- Name: place_taxon_names place_taxon_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.place_taxon_names
    ADD CONSTRAINT place_taxon_names_pkey PRIMARY KEY (id);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_pkey PRIMARY KEY (id);


--
-- Name: places_sites places_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.places_sites
    ADD CONSTRAINT places_sites_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: preferences preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.preferences
    ADD CONSTRAINT preferences_pkey PRIMARY KEY (id);


--
-- Name: project_assets project_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_assets
    ADD CONSTRAINT project_assets_pkey PRIMARY KEY (id);


--
-- Name: project_observation_fields project_observation_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_observation_fields
    ADD CONSTRAINT project_observation_fields_pkey PRIMARY KEY (id);


--
-- Name: project_observations project_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_observations
    ADD CONSTRAINT project_observations_pkey PRIMARY KEY (id);


--
-- Name: project_user_invitations project_user_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_user_invitations
    ADD CONSTRAINT project_user_invitations_pkey PRIMARY KEY (id);


--
-- Name: project_users project_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project_users
    ADD CONSTRAINT project_users_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: provider_authorizations provider_authorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provider_authorizations
    ADD CONSTRAINT provider_authorizations_pkey PRIMARY KEY (id);


--
-- Name: quality_metrics quality_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quality_metrics
    ADD CONSTRAINT quality_metrics_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: rules rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rules
    ADD CONSTRAINT rules_pkey PRIMARY KEY (id);


--
-- Name: saved_locations saved_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_locations
    ADD CONSTRAINT saved_locations_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (session_id);


--
-- Name: simplified_tree_milestone_taxa simplified_tree_milestone_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simplified_tree_milestone_taxa
    ADD CONSTRAINT simplified_tree_milestone_taxa_pkey PRIMARY KEY (id);


--
-- Name: site_admins site_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_admins
    ADD CONSTRAINT site_admins_pkey PRIMARY KEY (id);


--
-- Name: site_featured_projects site_featured_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_featured_projects
    ADD CONSTRAINT site_featured_projects_pkey PRIMARY KEY (id);


--
-- Name: site_statistics site_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_statistics
    ADD CONSTRAINT site_statistics_pkey PRIMARY KEY (id);


--
-- Name: sites sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_pkey PRIMARY KEY (id);


--
-- Name: soundcloud_identities soundcloud_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.soundcloud_identities
    ADD CONSTRAINT soundcloud_identities_pkey PRIMARY KEY (id);


--
-- Name: sounds sounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sounds
    ADD CONSTRAINT sounds_pkey PRIMARY KEY (id);


--
-- Name: sources sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sources
    ADD CONSTRAINT sources_pkey PRIMARY KEY (id);


--
-- Name: states_simplified_1 states_simplified_1_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states_simplified_1
    ADD CONSTRAINT states_simplified_1_pkey PRIMARY KEY (id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: taggings taggings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taggings
    ADD CONSTRAINT taggings_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: taxa taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxa
    ADD CONSTRAINT taxa_pkey PRIMARY KEY (id);


--
-- Name: taxon_change_taxa taxon_change_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_change_taxa
    ADD CONSTRAINT taxon_change_taxa_pkey PRIMARY KEY (id);


--
-- Name: taxon_changes taxon_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_changes
    ADD CONSTRAINT taxon_changes_pkey PRIMARY KEY (id);


--
-- Name: taxon_curators taxon_curators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_curators
    ADD CONSTRAINT taxon_curators_pkey PRIMARY KEY (id);


--
-- Name: taxon_descriptions taxon_descriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_descriptions
    ADD CONSTRAINT taxon_descriptions_pkey PRIMARY KEY (id);


--
-- Name: taxon_framework_relationships taxon_framework_relationships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_framework_relationships
    ADD CONSTRAINT taxon_framework_relationships_pkey PRIMARY KEY (id);


--
-- Name: taxon_frameworks taxon_frameworks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_frameworks
    ADD CONSTRAINT taxon_frameworks_pkey PRIMARY KEY (id);


--
-- Name: taxon_links taxon_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_links
    ADD CONSTRAINT taxon_links_pkey PRIMARY KEY (id);


--
-- Name: taxon_name_priorities taxon_name_priorities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_name_priorities
    ADD CONSTRAINT taxon_name_priorities_pkey PRIMARY KEY (id);


--
-- Name: taxon_names taxon_names_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_names
    ADD CONSTRAINT taxon_names_pkey PRIMARY KEY (id);


--
-- Name: taxon_photos taxon_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_photos
    ADD CONSTRAINT taxon_photos_pkey PRIMARY KEY (id);


--
-- Name: taxon_ranges taxon_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_ranges
    ADD CONSTRAINT taxon_ranges_pkey PRIMARY KEY (id);


--
-- Name: taxon_scheme_taxa taxon_scheme_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_scheme_taxa
    ADD CONSTRAINT taxon_scheme_taxa_pkey PRIMARY KEY (id);


--
-- Name: taxon_schemes taxon_schemes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.taxon_schemes
    ADD CONSTRAINT taxon_schemes_pkey PRIMARY KEY (id);


--
-- Name: time_zone_geometries time_zone_geometries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.time_zone_geometries
    ADD CONSTRAINT time_zone_geometries_pkey PRIMARY KEY (ogc_fid);


--
-- Name: trip_purposes trip_purposes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_purposes
    ADD CONSTRAINT trip_purposes_pkey PRIMARY KEY (id);


--
-- Name: trip_taxa trip_taxa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trip_taxa
    ADD CONSTRAINT trip_taxa_pkey PRIMARY KEY (id);


--
-- Name: update_actions update_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.update_actions
    ADD CONSTRAINT update_actions_pkey PRIMARY KEY (id);


--
-- Name: user_blocks user_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_blocks
    ADD CONSTRAINT user_blocks_pkey PRIMARY KEY (id);


--
-- Name: user_mutes user_mutes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_mutes
    ADD CONSTRAINT user_mutes_pkey PRIMARY KEY (id);


--
-- Name: user_parents user_parents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_parents
    ADD CONSTRAINT user_parents_pkey PRIMARY KEY (id);


--
-- Name: user_privileges user_privileges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_privileges
    ADD CONSTRAINT user_privileges_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: wiki_page_attachments wiki_page_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_attachments
    ADD CONSTRAINT wiki_page_attachments_pkey PRIMARY KEY (id);


--
-- Name: wiki_page_versions wiki_page_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_page_versions
    ADD CONSTRAINT wiki_page_versions_pkey PRIMARY KEY (id);


--
-- Name: wiki_pages wiki_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wiki_pages
    ADD CONSTRAINT wiki_pages_pkey PRIMARY KEY (id);


--
-- Name: year_statistic_localized_shareable_images year_statistic_localized_shareable_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.year_statistic_localized_shareable_images
    ADD CONSTRAINT year_statistic_localized_shareable_images_pkey PRIMARY KEY (id);


--
-- Name: year_statistics year_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.year_statistics
    ADD CONSTRAINT year_statistics_pkey PRIMARY KEY (id);


--
-- Name: associated_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX associated_index ON public.audits USING btree (associated_type, associated_id);


--
-- Name: auditable_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auditable_index ON public.audits USING btree (auditable_type, auditable_id, version);


--
-- Name: fk_flags_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fk_flags_user ON public.flags USING btree (user_id);


--
-- Name: index_annotations_on_controlled_attribute_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_controlled_attribute_id ON public.annotations USING btree (controlled_attribute_id);


--
-- Name: index_annotations_on_controlled_value_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_controlled_value_id ON public.annotations USING btree (controlled_value_id);


--
-- Name: index_annotations_on_observation_field_value_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_observation_field_value_id ON public.annotations USING btree (observation_field_value_id);


--
-- Name: index_annotations_on_resource_id_and_resource_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_resource_id_and_resource_type ON public.annotations USING btree (resource_id, resource_type);


--
-- Name: index_annotations_on_unique_resource_and_attribute; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_annotations_on_unique_resource_and_attribute ON public.annotations USING btree (resource_type, resource_id, controlled_attribute_id, controlled_value_id);


--
-- Name: index_annotations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_annotations_on_user_id ON public.annotations USING btree (user_id);


--
-- Name: index_annotations_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_annotations_on_uuid ON public.annotations USING btree (uuid);


--
-- Name: index_announcements_on_start_and_end; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_start_and_end ON public.announcements USING btree (start, "end");


--
-- Name: index_announcements_sites_on_announcement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_sites_on_announcement_id ON public.announcements_sites USING btree (announcement_id);


--
-- Name: index_announcements_sites_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_sites_on_site_id ON public.announcements_sites USING btree (site_id);


--
-- Name: index_api_endpoint_caches_on_api_endpoint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_endpoint_caches_on_api_endpoint_id ON public.api_endpoint_caches USING btree (api_endpoint_id);


--
-- Name: index_api_endpoint_caches_on_request_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_endpoint_caches_on_request_url ON public.api_endpoint_caches USING btree (request_url);


--
-- Name: index_api_endpoints_on_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_endpoints_on_title ON public.api_endpoints USING btree (title);


--
-- Name: index_assessment_sections_on_assessment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessment_sections_on_assessment_id ON public.assessment_sections USING btree (assessment_id);


--
-- Name: index_assessment_sections_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessment_sections_on_user_id ON public.assessment_sections USING btree (user_id);


--
-- Name: index_assessments_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_project_id ON public.assessments USING btree (project_id);


--
-- Name: index_assessments_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_taxon_id ON public.assessments USING btree (taxon_id);


--
-- Name: index_assessments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assessments_on_user_id ON public.assessments USING btree (user_id);


--
-- Name: index_atlas_alterations_on_atlas_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_atlas_alterations_on_atlas_id ON public.atlas_alterations USING btree (atlas_id);


--
-- Name: index_atlas_alterations_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_atlas_alterations_on_place_id ON public.atlas_alterations USING btree (place_id);


--
-- Name: index_atlas_alterations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_atlas_alterations_on_user_id ON public.atlas_alterations USING btree (user_id);


--
-- Name: index_atlases_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_atlases_on_taxon_id ON public.atlases USING btree (taxon_id);


--
-- Name: index_atlases_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_atlases_on_user_id ON public.atlases USING btree (user_id);


--
-- Name: index_audits_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audits_on_created_at ON public.audits USING btree (created_at);


--
-- Name: index_audits_on_request_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audits_on_request_uuid ON public.audits USING btree (request_uuid);


--
-- Name: index_colors_taxa_on_taxon_id_and_color_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_colors_taxa_on_taxon_id_and_color_id ON public.colors_taxa USING btree (taxon_id, color_id);


--
-- Name: index_comments_on_parent_id_and_parent_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_parent_id_and_parent_type ON public.comments USING btree (parent_id, parent_type);


--
-- Name: index_comments_on_parent_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_parent_type ON public.comments USING btree (parent_type);


--
-- Name: index_comments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_user_id ON public.comments USING btree (user_id);


--
-- Name: index_comments_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_comments_on_uuid ON public.comments USING btree (uuid);


--
-- Name: index_complete_sets_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_complete_sets_on_place_id ON public.complete_sets USING btree (place_id);


--
-- Name: index_complete_sets_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_complete_sets_on_taxon_id ON public.complete_sets USING btree (taxon_id);


--
-- Name: index_complete_sets_on_taxon_id_and_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_complete_sets_on_taxon_id_and_place_id ON public.complete_sets USING btree (taxon_id, place_id);


--
-- Name: index_complete_sets_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_complete_sets_on_user_id ON public.complete_sets USING btree (user_id);


--
-- Name: index_computer_vision_demo_uploads_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_computer_vision_demo_uploads_on_uuid ON public.computer_vision_demo_uploads USING btree (uuid);


--
-- Name: index_conservation_statuses_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conservation_statuses_on_place_id ON public.conservation_statuses USING btree (place_id);


--
-- Name: index_conservation_statuses_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conservation_statuses_on_source_id ON public.conservation_statuses USING btree (source_id);


--
-- Name: index_conservation_statuses_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conservation_statuses_on_taxon_id ON public.conservation_statuses USING btree (taxon_id);


--
-- Name: index_conservation_statuses_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conservation_statuses_on_updater_id ON public.conservation_statuses USING btree (updater_id);


--
-- Name: index_conservation_statuses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conservation_statuses_on_user_id ON public.conservation_statuses USING btree (user_id);


--
-- Name: index_controlled_term_taxa_on_controlled_term_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_controlled_term_taxa_on_controlled_term_id ON public.controlled_term_taxa USING btree (controlled_term_id);


--
-- Name: index_controlled_term_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_controlled_term_taxa_on_taxon_id ON public.controlled_term_taxa USING btree (taxon_id);


--
-- Name: index_controlled_terms_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_controlled_terms_on_uuid ON public.controlled_terms USING btree (uuid);


--
-- Name: index_counties_simplified_01_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_counties_simplified_01_on_geom ON public.counties_simplified_01 USING gist (geom);


--
-- Name: index_counties_simplified_01_on_place_geometry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_counties_simplified_01_on_place_geometry_id ON public.counties_simplified_01 USING btree (place_geometry_id);


--
-- Name: index_counties_simplified_01_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_counties_simplified_01_on_place_id ON public.counties_simplified_01 USING btree (place_id);


--
-- Name: index_countries_simplified_1_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_countries_simplified_1_on_geom ON public.countries_simplified_1 USING gist (geom);


--
-- Name: index_countries_simplified_1_on_place_geometry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_countries_simplified_1_on_place_geometry_id ON public.countries_simplified_1 USING btree (place_geometry_id);


--
-- Name: index_countries_simplified_1_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_countries_simplified_1_on_place_id ON public.countries_simplified_1 USING btree (place_id);


--
-- Name: index_custom_projects_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_custom_projects_on_project_id ON public.custom_projects USING btree (project_id);


--
-- Name: index_delayed_jobs_on_unique_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_delayed_jobs_on_unique_hash ON public.delayed_jobs USING btree (unique_hash);


--
-- Name: index_deleted_observations_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deleted_observations_on_user_id_and_created_at ON public.deleted_observations USING btree (user_id, created_at);


--
-- Name: index_deleted_photos_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deleted_photos_on_created_at ON public.deleted_photos USING btree (created_at);


--
-- Name: index_deleted_sounds_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deleted_sounds_on_created_at ON public.deleted_sounds USING btree (created_at);


--
-- Name: index_deleted_users_on_login; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deleted_users_on_login ON public.deleted_users USING btree (login);


--
-- Name: index_deleted_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_deleted_users_on_user_id ON public.deleted_users USING btree (user_id);


--
-- Name: index_email_suppressions_on_email_and_suppression_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_suppressions_on_email_and_suppression_type ON public.email_suppressions USING btree (email, suppression_type);


--
-- Name: index_email_suppressions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_email_suppressions_on_user_id ON public.email_suppressions USING btree (user_id);


--
-- Name: index_exploded_atlas_places_on_atlas_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exploded_atlas_places_on_atlas_id ON public.exploded_atlas_places USING btree (atlas_id);


--
-- Name: index_exploded_atlas_places_on_atlas_id_and_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exploded_atlas_places_on_atlas_id_and_place_id ON public.exploded_atlas_places USING btree (atlas_id, place_id);


--
-- Name: index_exploded_atlas_places_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_exploded_atlas_places_on_place_id ON public.exploded_atlas_places USING btree (place_id);


--
-- Name: index_file_extensions_on_extension; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_file_extensions_on_extension ON public.file_extensions USING btree (extension);


--
-- Name: index_file_prefixes_on_prefix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_file_prefixes_on_prefix ON public.file_prefixes USING btree (prefix);


--
-- Name: index_flags_on_flaggable_id_and_flaggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flags_on_flaggable_id_and_flaggable_type ON public.flags USING btree (flaggable_id, flaggable_type);


--
-- Name: index_flags_on_flaggable_parent_type_and_flaggable_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flags_on_flaggable_parent_type_and_flaggable_parent_id ON public.flags USING btree (flaggable_parent_type, flaggable_parent_id);


--
-- Name: index_flags_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flags_on_uuid ON public.flags USING btree (uuid);


--
-- Name: index_flickr_photos_on_flickr_native_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flickr_photos_on_flickr_native_photo_id ON public.photos USING btree (native_photo_id);


--
-- Name: index_flow_task_resources_on_flow_task_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flow_task_resources_on_flow_task_id_and_type ON public.flow_task_resources USING btree (flow_task_id, type);


--
-- Name: index_flow_task_resources_on_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flow_task_resources_on_resource_type_and_resource_id ON public.flow_task_resources USING btree (resource_type, resource_id);


--
-- Name: index_flow_tasks_on_unique_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flow_tasks_on_unique_hash ON public.flow_tasks USING btree (unique_hash);


--
-- Name: index_flow_tasks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flow_tasks_on_user_id ON public.flow_tasks USING btree (user_id);


--
-- Name: index_frequency_cell_month_taxa_on_frequency_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_frequency_cell_month_taxa_on_frequency_cell_id ON public.frequency_cell_month_taxa USING btree (frequency_cell_id);


--
-- Name: index_frequency_cell_month_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_frequency_cell_month_taxa_on_taxon_id ON public.frequency_cell_month_taxa USING btree (taxon_id);


--
-- Name: index_frequency_cells_on_swlat_and_swlng; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_frequency_cells_on_swlat_and_swlng ON public.frequency_cells USING btree (swlat, swlng);


--
-- Name: index_friendships_on_following; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendships_on_following ON public.friendships USING btree (following);


--
-- Name: index_friendships_on_trust; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendships_on_trust ON public.friendships USING btree (trust);


--
-- Name: index_friendships_on_user_id_and_friend_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_friendships_on_user_id_and_friend_id ON public.friendships USING btree (user_id, friend_id);


--
-- Name: index_geo_model_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_geo_model_taxa_on_taxon_id ON public.geo_model_taxa USING btree (taxon_id);


--
-- Name: index_guide_photos_on_guide_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_photos_on_guide_taxon_id ON public.guide_photos USING btree (guide_taxon_id);


--
-- Name: index_guide_photos_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_photos_on_photo_id ON public.guide_photos USING btree (photo_id);


--
-- Name: index_guide_ranges_on_guide_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_ranges_on_guide_taxon_id ON public.guide_ranges USING btree (guide_taxon_id);


--
-- Name: index_guide_ranges_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_ranges_on_source_id ON public.guide_ranges USING btree (source_id);


--
-- Name: index_guide_sections_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_sections_on_creator_id ON public.guide_sections USING btree (creator_id);


--
-- Name: index_guide_sections_on_guide_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_sections_on_guide_taxon_id ON public.guide_sections USING btree (guide_taxon_id);


--
-- Name: index_guide_sections_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_sections_on_source_id ON public.guide_sections USING btree (source_id);


--
-- Name: index_guide_sections_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_sections_on_updater_id ON public.guide_sections USING btree (updater_id);


--
-- Name: index_guide_taxa_on_guide_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_taxa_on_guide_id ON public.guide_taxa USING btree (guide_id);


--
-- Name: index_guide_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_taxa_on_taxon_id ON public.guide_taxa USING btree (taxon_id);


--
-- Name: index_guide_users_on_guide_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_users_on_guide_id ON public.guide_users USING btree (guide_id);


--
-- Name: index_guide_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guide_users_on_user_id ON public.guide_users USING btree (user_id);


--
-- Name: index_guides_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guides_on_place_id ON public.guides USING btree (place_id);


--
-- Name: index_guides_on_source_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guides_on_source_url ON public.guides USING btree (source_url);


--
-- Name: index_guides_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guides_on_taxon_id ON public.guides USING btree (taxon_id);


--
-- Name: index_guides_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_guides_on_user_id ON public.guides USING btree (user_id);


--
-- Name: index_identifications_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_category ON public.identifications USING btree (category);


--
-- Name: index_identifications_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_created_at ON public.identifications USING btree (created_at);


--
-- Name: index_identifications_on_observation_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_observation_id_and_created_at ON public.identifications USING btree (observation_id, created_at);


--
-- Name: index_identifications_on_previous_observation_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_previous_observation_taxon_id ON public.identifications USING btree (previous_observation_taxon_id);


--
-- Name: index_identifications_on_taxon_change_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_taxon_change_id ON public.identifications USING btree (taxon_change_id);


--
-- Name: index_identifications_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_taxon_id ON public.identifications USING btree (taxon_id);


--
-- Name: index_identifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_user_id_and_created_at ON public.identifications USING btree (user_id, created_at);


--
-- Name: index_identifications_on_user_id_and_current; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_identifications_on_user_id_and_current ON public.identifications USING btree (user_id, current);


--
-- Name: index_identifications_on_user_id_and_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identifications_on_user_id_and_observation_id ON public.identifications USING btree (user_id, observation_id) WHERE current;


--
-- Name: index_identifications_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_identifications_on_uuid ON public.identifications USING btree (uuid);


--
-- Name: index_list_rules_on_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_list_rules_on_list_id ON public.list_rules USING btree (list_id);


--
-- Name: index_list_rules_on_operand_type_and_operand_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_list_rules_on_operand_type_and_operand_id ON public.list_rules USING btree (operand_type, operand_id);


--
-- Name: index_listed_taxa_on_first_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_first_observation_id ON public.listed_taxa USING btree (first_observation_id);


--
-- Name: index_listed_taxa_on_last_observation_id_and_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_last_observation_id_and_list_id ON public.listed_taxa USING btree (last_observation_id, list_id);


--
-- Name: index_listed_taxa_on_list_id_and_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_list_id_and_taxon_id ON public.listed_taxa USING btree (list_id, taxon_id);


--
-- Name: index_listed_taxa_on_place_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_place_id_and_created_at ON public.listed_taxa USING btree (place_id, created_at);


--
-- Name: index_listed_taxa_on_place_id_and_observations_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_place_id_and_observations_count ON public.listed_taxa USING btree (place_id, observations_count);


--
-- Name: index_listed_taxa_on_place_id_and_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_place_id_and_taxon_id ON public.listed_taxa USING btree (place_id, taxon_id);


--
-- Name: index_listed_taxa_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_source_id ON public.listed_taxa USING btree (source_id);


--
-- Name: index_listed_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_taxon_id ON public.listed_taxa USING btree (taxon_id);


--
-- Name: index_listed_taxa_on_taxon_range_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_taxon_range_id ON public.listed_taxa USING btree (taxon_range_id);


--
-- Name: index_listed_taxa_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxa_on_user_id ON public.listed_taxa USING btree (user_id);


--
-- Name: index_listed_taxon_alterations_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxon_alterations_on_place_id ON public.listed_taxon_alterations USING btree (place_id);


--
-- Name: index_listed_taxon_alterations_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxon_alterations_on_taxon_id ON public.listed_taxon_alterations USING btree (taxon_id);


--
-- Name: index_listed_taxon_alterations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_listed_taxon_alterations_on_user_id ON public.listed_taxon_alterations USING btree (user_id);


--
-- Name: index_lists_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lists_on_place_id ON public.lists USING btree (place_id);


--
-- Name: index_lists_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lists_on_project_id ON public.lists USING btree (project_id);


--
-- Name: index_lists_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lists_on_source_id ON public.lists USING btree (source_id);


--
-- Name: index_lists_on_type_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lists_on_type_and_id ON public.lists USING btree (type, id);


--
-- Name: index_lists_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_lists_on_user_id ON public.lists USING btree (user_id);


--
-- Name: index_messages_on_user_id_and_from_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_user_id_and_from_user_id ON public.messages USING btree (user_id, from_user_id);


--
-- Name: index_messages_on_user_id_and_thread_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_user_id_and_thread_id ON public.messages USING btree (user_id, thread_id);


--
-- Name: index_messages_on_user_id_and_to_user_id_and_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_user_id_and_to_user_id_and_read_at ON public.messages USING btree (user_id, to_user_id, read_at);


--
-- Name: index_model_attribute_changes_on_changed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_model_attribute_changes_on_changed_at ON public.model_attribute_changes USING btree (changed_at);


--
-- Name: index_model_attribute_changes_on_model_id_and_field_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_model_attribute_changes_on_model_id_and_field_name ON public.model_attribute_changes USING btree (model_id, field_name);


--
-- Name: index_moderator_actions_on_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moderator_actions_on_resource_type_and_resource_id ON public.moderator_actions USING btree (resource_type, resource_id);


--
-- Name: index_moderator_actions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moderator_actions_on_user_id ON public.moderator_actions USING btree (user_id);


--
-- Name: index_moderator_notes_on_subject_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moderator_notes_on_subject_user_id ON public.moderator_notes USING btree (subject_user_id);


--
-- Name: index_moderator_notes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_moderator_notes_on_user_id ON public.moderator_notes USING btree (user_id);


--
-- Name: index_oa_samples_oa_validators; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oa_samples_oa_validators ON public.observation_accuracy_samples_validators USING btree (observation_accuracy_sample_id, observation_accuracy_validator_id);


--
-- Name: index_oa_validators_oa_samples; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oa_validators_oa_samples ON public.observation_accuracy_samples_validators USING btree (observation_accuracy_validator_id, observation_accuracy_sample_id);


--
-- Name: index_oas_on_oae_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oas_on_oae_id ON public.observation_accuracy_samples USING btree (observation_accuracy_experiment_id);


--
-- Name: index_oauth_access_grants_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON public.oauth_access_grants USING btree (token);


--
-- Name: index_oauth_access_tokens_on_refresh_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON public.oauth_access_tokens USING btree (refresh_token);


--
-- Name: index_oauth_access_tokens_on_resource_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON public.oauth_access_tokens USING btree (resource_owner_id);


--
-- Name: index_oauth_access_tokens_on_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON public.oauth_access_tokens USING btree (token);


--
-- Name: index_oauth_applications_on_owner_id_and_owner_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_applications_on_owner_id_and_owner_type ON public.oauth_applications USING btree (owner_id, owner_type);


--
-- Name: index_oauth_applications_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_applications_on_uid ON public.oauth_applications USING btree (uid);


--
-- Name: index_observation_accuracy_samples_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_accuracy_samples_on_observation_id ON public.observation_accuracy_samples USING btree (observation_id);


--
-- Name: index_observation_accuracy_validators_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_accuracy_validators_on_user_id ON public.observation_accuracy_validators USING btree (user_id);


--
-- Name: index_observation_field_values_on_observation_field_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_field_values_on_observation_field_id ON public.observation_field_values USING btree (observation_field_id);


--
-- Name: index_observation_field_values_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_field_values_on_observation_id ON public.observation_field_values USING btree (observation_id);


--
-- Name: index_observation_field_values_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_field_values_on_updater_id ON public.observation_field_values USING btree (updater_id);


--
-- Name: index_observation_field_values_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_field_values_on_user_id ON public.observation_field_values USING btree (user_id);


--
-- Name: index_observation_field_values_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observation_field_values_on_uuid ON public.observation_field_values USING btree (uuid);


--
-- Name: index_observation_field_values_on_value_and_field; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_field_values_on_value_and_field ON public.observation_field_values USING btree (value, observation_field_id);


--
-- Name: index_observation_fields_on_datatype; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_fields_on_datatype ON public.observation_fields USING btree (datatype);


--
-- Name: index_observation_fields_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_fields_on_name ON public.observation_fields USING btree (name);


--
-- Name: index_observation_fields_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observation_fields_on_uuid ON public.observation_fields USING btree (uuid);


--
-- Name: index_observation_links_on_observation_id_and_href; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_links_on_observation_id_and_href ON public.observation_links USING btree (observation_id, href);


--
-- Name: index_observation_photos_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_photos_on_observation_id ON public.observation_photos USING btree (observation_id);


--
-- Name: index_observation_photos_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_photos_on_photo_id ON public.observation_photos USING btree (photo_id);


--
-- Name: index_observation_photos_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observation_photos_on_uuid ON public.observation_photos USING btree (uuid);


--
-- Name: index_observation_reviews_on_observation_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observation_reviews_on_observation_id_and_user_id ON public.observation_reviews USING btree (observation_id, user_id);


--
-- Name: index_observation_reviews_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_reviews_on_user_id ON public.observation_reviews USING btree (user_id);


--
-- Name: index_observation_sounds_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observation_sounds_on_uuid ON public.observation_sounds USING btree (uuid);


--
-- Name: index_observation_zooms_10_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_10_on_taxon_id ON public.observation_zooms_10 USING btree (taxon_id);


--
-- Name: index_observation_zooms_11_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_11_on_taxon_id ON public.observation_zooms_11 USING btree (taxon_id);


--
-- Name: index_observation_zooms_125_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_125_on_taxon_id ON public.observation_zooms_125 USING btree (taxon_id);


--
-- Name: index_observation_zooms_12_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_12_on_taxon_id ON public.observation_zooms_12 USING btree (taxon_id);


--
-- Name: index_observation_zooms_2000_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_2000_on_taxon_id ON public.observation_zooms_2000 USING btree (taxon_id);


--
-- Name: index_observation_zooms_250_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_250_on_taxon_id ON public.observation_zooms_250 USING btree (taxon_id);


--
-- Name: index_observation_zooms_2_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_2_on_taxon_id ON public.observation_zooms_2 USING btree (taxon_id);


--
-- Name: index_observation_zooms_3_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_3_on_taxon_id ON public.observation_zooms_3 USING btree (taxon_id);


--
-- Name: index_observation_zooms_4000_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_4000_on_taxon_id ON public.observation_zooms_4000 USING btree (taxon_id);


--
-- Name: index_observation_zooms_4_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_4_on_taxon_id ON public.observation_zooms_4 USING btree (taxon_id);


--
-- Name: index_observation_zooms_500_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_500_on_taxon_id ON public.observation_zooms_500 USING btree (taxon_id);


--
-- Name: index_observation_zooms_5_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_5_on_taxon_id ON public.observation_zooms_5 USING btree (taxon_id);


--
-- Name: index_observation_zooms_63_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_63_on_taxon_id ON public.observation_zooms_63 USING btree (taxon_id);


--
-- Name: index_observation_zooms_6_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_6_on_taxon_id ON public.observation_zooms_6 USING btree (taxon_id);


--
-- Name: index_observation_zooms_7_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_7_on_taxon_id ON public.observation_zooms_7 USING btree (taxon_id);


--
-- Name: index_observation_zooms_8_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_8_on_taxon_id ON public.observation_zooms_8 USING btree (taxon_id);


--
-- Name: index_observation_zooms_990_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_990_on_taxon_id ON public.observation_zooms_990 USING btree (taxon_id);


--
-- Name: index_observation_zooms_9_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observation_zooms_9_on_taxon_id ON public.observation_zooms_9 USING btree (taxon_id);


--
-- Name: index_observations_on_cached_votes_total; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_cached_votes_total ON public.observations USING btree (cached_votes_total);


--
-- Name: index_observations_on_captive; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_captive ON public.observations USING btree (captive);


--
-- Name: index_observations_on_comments_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_comments_count ON public.observations USING btree (comments_count);


--
-- Name: index_observations_on_community_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_community_taxon_id ON public.observations USING btree (community_taxon_id);


--
-- Name: index_observations_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_created_at ON public.observations USING btree (created_at);


--
-- Name: index_observations_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_geom ON public.observations USING gist (geom);


--
-- Name: index_observations_on_last_indexed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_last_indexed_at ON public.observations USING btree (last_indexed_at);


--
-- Name: index_observations_on_mappable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_mappable ON public.observations USING btree (mappable);


--
-- Name: index_observations_on_oauth_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_oauth_application_id ON public.observations USING btree (oauth_application_id);


--
-- Name: index_observations_on_observed_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_observed_on ON public.observations USING btree (observed_on);


--
-- Name: index_observations_on_observed_on_and_time_observed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_observed_on_and_time_observed_at ON public.observations USING btree (observed_on, time_observed_at);


--
-- Name: index_observations_on_out_of_range; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_out_of_range ON public.observations USING btree (out_of_range);


--
-- Name: index_observations_on_photos_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_photos_count ON public.observations USING btree (observation_photos_count);


--
-- Name: index_observations_on_private_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_private_geom ON public.observations USING gist (private_geom);


--
-- Name: index_observations_on_quality_grade; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_quality_grade ON public.observations USING btree (quality_grade);


--
-- Name: index_observations_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_site_id ON public.observations USING btree (site_id);


--
-- Name: index_observations_on_taxon_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_taxon_id_and_user_id ON public.observations USING btree (taxon_id, user_id);


--
-- Name: index_observations_on_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_uri ON public.observations USING btree (uri);


--
-- Name: index_observations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_on_user_id ON public.observations USING btree (user_id);


--
-- Name: index_observations_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observations_on_uuid ON public.observations USING btree (uuid);


--
-- Name: index_observations_places_on_observation_id_and_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_observations_places_on_observation_id_and_place_id ON public.observations_places USING btree (observation_id, place_id);


--
-- Name: index_observations_places_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_places_on_place_id ON public.observations_places USING btree (place_id);


--
-- Name: index_observations_posts_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_posts_on_observation_id ON public.observations_posts USING btree (observation_id);


--
-- Name: index_observations_posts_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_posts_on_post_id ON public.observations_posts USING btree (post_id);


--
-- Name: index_observations_sounds_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_sounds_on_observation_id ON public.observation_sounds USING btree (observation_id);


--
-- Name: index_observations_sounds_on_sound_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_sounds_on_sound_id ON public.observation_sounds USING btree (sound_id);


--
-- Name: index_observations_user_datetime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_observations_user_datetime ON public.observations USING btree (user_id, observed_on, time_observed_at);


--
-- Name: index_photo_metadata_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_photo_metadata_on_photo_id ON public.photo_metadata USING btree (photo_id);


--
-- Name: index_photos_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_photos_on_user_id ON public.photos USING btree (user_id);


--
-- Name: index_photos_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_photos_on_uuid ON public.photos USING btree (uuid);


--
-- Name: index_picasa_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_picasa_identities_on_user_id ON public.picasa_identities USING btree (user_id);


--
-- Name: index_place_geometries_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_geometries_on_geom ON public.place_geometries USING gist (geom);


--
-- Name: index_place_geometries_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_geometries_on_place_id ON public.place_geometries USING btree (place_id);


--
-- Name: index_place_geometries_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_geometries_on_source_id ON public.place_geometries USING btree (source_id);


--
-- Name: index_place_taxon_names_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_taxon_names_on_place_id ON public.place_taxon_names USING btree (place_id);


--
-- Name: index_place_taxon_names_on_taxon_name_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_place_taxon_names_on_taxon_name_id ON public.place_taxon_names USING btree (taxon_name_id);


--
-- Name: index_places_on_admin_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_admin_level ON public.places USING btree (admin_level);


--
-- Name: index_places_on_ancestry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_ancestry ON public.places USING btree (ancestry text_pattern_ops);


--
-- Name: index_places_on_bbox_area; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_bbox_area ON public.places USING btree (bbox_area);


--
-- Name: index_places_on_check_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_check_list_id ON public.places USING btree (check_list_id);


--
-- Name: index_places_on_latitude_and_longitude; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_latitude_and_longitude ON public.places USING btree (latitude, longitude);


--
-- Name: index_places_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_parent_id ON public.places USING btree (parent_id);


--
-- Name: index_places_on_place_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_place_type ON public.places USING btree (place_type);


--
-- Name: index_places_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_places_on_slug ON public.places USING btree (slug);


--
-- Name: index_places_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_source_id ON public.places USING btree (source_id);


--
-- Name: index_places_on_swlat_and_swlng_and_nelat_and_nelng; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_swlat_and_swlng_and_nelat_and_nelng ON public.places USING btree (swlat, swlng, nelat, nelng);


--
-- Name: index_places_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_on_user_id ON public.places USING btree (user_id);


--
-- Name: index_places_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_places_on_uuid ON public.places USING btree (uuid);


--
-- Name: index_places_sites_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_places_sites_on_site_id ON public.places_sites USING btree (site_id);


--
-- Name: index_posts_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_place_id ON public.posts USING btree (place_id);


--
-- Name: index_posts_on_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_published_at ON public.posts USING btree (published_at);


--
-- Name: index_posts_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_posts_on_uuid ON public.posts USING btree (uuid);


--
-- Name: index_preferences_on_owner_and_name_and_preference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_preferences_on_owner_and_name_and_preference ON public.preferences USING btree (owner_id, owner_type, name, group_id, group_type);


--
-- Name: index_preferences_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_preferences_on_updated_at ON public.preferences USING btree (updated_at);


--
-- Name: index_project_assets_on_asset_content_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_assets_on_asset_content_type ON public.project_assets USING btree (asset_content_type);


--
-- Name: index_project_assets_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_assets_on_project_id ON public.project_assets USING btree (project_id);


--
-- Name: index_project_observation_fields_on_observation_field_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_observation_fields_on_observation_field_id ON public.project_observation_fields USING btree (observation_field_id);


--
-- Name: index_project_observations_on_curator_identification_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_observations_on_curator_identification_id ON public.project_observations USING btree (curator_identification_id);


--
-- Name: index_project_observations_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_observations_on_observation_id ON public.project_observations USING btree (observation_id);


--
-- Name: index_project_observations_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_observations_on_project_id ON public.project_observations USING btree (project_id);


--
-- Name: index_project_observations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_observations_on_user_id ON public.project_observations USING btree (user_id);


--
-- Name: index_project_observations_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_observations_on_uuid ON public.project_observations USING btree (uuid);


--
-- Name: index_project_user_invitations_on_invited_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_user_invitations_on_invited_user_id ON public.project_user_invitations USING btree (invited_user_id);


--
-- Name: index_project_user_invitations_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_user_invitations_on_project_id ON public.project_user_invitations USING btree (project_id);


--
-- Name: index_project_user_invitations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_user_invitations_on_user_id ON public.project_user_invitations USING btree (user_id);


--
-- Name: index_project_users_on_project_id_and_taxa_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_users_on_project_id_and_taxa_count ON public.project_users USING btree (project_id, taxa_count);


--
-- Name: index_project_users_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_users_on_updated_at ON public.project_users USING btree (updated_at);


--
-- Name: index_project_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_project_users_on_user_id ON public.project_users USING btree (user_id);


--
-- Name: index_project_users_on_user_id_and_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_project_users_on_user_id_and_project_id ON public.project_users USING btree (user_id, project_id);


--
-- Name: index_projects_on_cached_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_cached_slug ON public.projects USING btree (slug);


--
-- Name: index_projects_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_place_id ON public.projects USING btree (place_id);


--
-- Name: index_projects_on_source_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_source_url ON public.projects USING btree (source_url);


--
-- Name: index_projects_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_user_id ON public.projects USING btree (user_id);


--
-- Name: index_provider_authorizations_on_provider_name_and_provider_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_authorizations_on_provider_name_and_provider_uid ON public.provider_authorizations USING btree (provider_name, provider_uid);


--
-- Name: index_provider_authorizations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_authorizations_on_user_id ON public.provider_authorizations USING btree (user_id);


--
-- Name: index_quality_metrics_on_observation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quality_metrics_on_observation_id ON public.quality_metrics USING btree (observation_id);


--
-- Name: index_quality_metrics_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_quality_metrics_on_user_id ON public.quality_metrics USING btree (user_id);


--
-- Name: index_roles_users_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_users_on_role_id ON public.roles_users USING btree (role_id);


--
-- Name: index_roles_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_users_on_user_id ON public.roles_users USING btree (user_id);


--
-- Name: index_rules_on_ruler_id_and_ruler_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rules_on_ruler_id_and_ruler_type ON public.rules USING btree (ruler_id, ruler_type);


--
-- Name: index_saved_locations_on_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_locations_on_title ON public.saved_locations USING btree (title);


--
-- Name: index_saved_locations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_locations_on_user_id ON public.saved_locations USING btree (user_id);


--
-- Name: index_sessions_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_updated_at ON public.sessions USING btree (updated_at);


--
-- Name: index_site_admins_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_site_admins_on_site_id ON public.site_admins USING btree (site_id);


--
-- Name: index_site_admins_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_site_admins_on_user_id ON public.site_admins USING btree (user_id);


--
-- Name: index_site_featured_projects_on_site_id_and_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_site_featured_projects_on_site_id_and_project_id ON public.site_featured_projects USING btree (site_id, project_id);


--
-- Name: index_sites_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_place_id ON public.sites USING btree (place_id);


--
-- Name: index_sites_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_source_id ON public.sites USING btree (source_id);


--
-- Name: index_slugs_on_n_s_s_and_s; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_slugs_on_n_s_s_and_s ON public.friendly_id_slugs USING btree (slug, sluggable_type, sequence, scope);


--
-- Name: index_slugs_on_sluggable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_slugs_on_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_id);


--
-- Name: index_sounds_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sounds_on_type ON public.sounds USING btree (type);


--
-- Name: index_sounds_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sounds_on_user_id ON public.sounds USING btree (user_id);


--
-- Name: index_sounds_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sounds_on_uuid ON public.sounds USING btree (uuid);


--
-- Name: index_sources_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sources_on_user_id ON public.sources USING btree (user_id);


--
-- Name: index_states_simplified_1_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_states_simplified_1_on_geom ON public.states_simplified_1 USING gist (geom);


--
-- Name: index_states_simplified_1_on_place_geometry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_states_simplified_1_on_place_geometry_id ON public.states_simplified_1 USING btree (place_geometry_id);


--
-- Name: index_states_simplified_1_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_states_simplified_1_on_place_id ON public.states_simplified_1 USING btree (place_id);


--
-- Name: index_subscriptions_on_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_resource_type_and_resource_id ON public.subscriptions USING btree (resource_type, resource_id);


--
-- Name: index_subscriptions_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_taxon_id ON public.subscriptions USING btree (taxon_id);


--
-- Name: index_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_user_id ON public.subscriptions USING btree (user_id);


--
-- Name: index_subscriptions_on_user_id_and_resource_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subscriptions_on_user_id_and_resource_type ON public.subscriptions USING btree (user_id, resource_type);


--
-- Name: index_taggings_on_taggable_id_and_taggable_type_and_context; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taggings_on_taggable_id_and_taggable_type_and_context ON public.taggings USING btree (taggable_id, taggable_type, context);


--
-- Name: index_tags_on_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_lower_name ON public.tags USING btree (lower((name)::text));


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_name ON public.tags USING btree (name);


--
-- Name: index_taxa_on_ancestry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_ancestry ON public.taxa USING btree (ancestry text_pattern_ops);


--
-- Name: index_taxa_on_featured_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_featured_at ON public.taxa USING btree (featured_at);


--
-- Name: index_taxa_on_is_iconic; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_is_iconic ON public.taxa USING btree (is_iconic);


--
-- Name: index_taxa_on_listed_taxa_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_listed_taxa_count ON public.taxa USING btree (listed_taxa_count);


--
-- Name: index_taxa_on_locked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_locked ON public.taxa USING btree (locked);


--
-- Name: index_taxa_on_lower_name_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_lower_name_and_id ON public.taxa USING btree (lower((name)::text), id);


--
-- Name: index_taxa_on_observations_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_observations_count ON public.taxa USING btree (observations_count);


--
-- Name: index_taxa_on_rank_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_rank_level ON public.taxa USING btree (rank_level);


--
-- Name: index_taxa_on_taxon_framework_relationship_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxa_on_taxon_framework_relationship_id ON public.taxa USING btree (taxon_framework_relationship_id);


--
-- Name: index_taxa_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_taxa_on_uuid ON public.taxa USING btree (uuid);


--
-- Name: index_taxon_change_taxa_on_taxon_change_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_change_taxa_on_taxon_change_id ON public.taxon_change_taxa USING btree (taxon_change_id);


--
-- Name: index_taxon_change_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_change_taxa_on_taxon_id ON public.taxon_change_taxa USING btree (taxon_id);


--
-- Name: index_taxon_changes_on_committer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_changes_on_committer_id ON public.taxon_changes USING btree (committer_id);


--
-- Name: index_taxon_changes_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_changes_on_source_id ON public.taxon_changes USING btree (source_id);


--
-- Name: index_taxon_changes_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_changes_on_taxon_id ON public.taxon_changes USING btree (taxon_id);


--
-- Name: index_taxon_changes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_changes_on_user_id ON public.taxon_changes USING btree (user_id);


--
-- Name: index_taxon_curators_on_taxon_framework_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_curators_on_taxon_framework_id ON public.taxon_curators USING btree (taxon_framework_id);


--
-- Name: index_taxon_descriptions_on_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_descriptions_on_provider ON public.taxon_descriptions USING btree (provider);


--
-- Name: index_taxon_descriptions_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_descriptions_on_taxon_id ON public.taxon_descriptions USING btree (taxon_id);


--
-- Name: index_taxon_links_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_links_on_place_id ON public.taxon_links USING btree (place_id);


--
-- Name: index_taxon_links_on_taxon_id_and_show_for_descendent_taxa; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_links_on_taxon_id_and_show_for_descendent_taxa ON public.taxon_links USING btree (taxon_id, show_for_descendent_taxa);


--
-- Name: index_taxon_links_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_links_on_user_id ON public.taxon_links USING btree (user_id);


--
-- Name: index_taxon_name_priorities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_name_priorities_on_user_id ON public.taxon_name_priorities USING btree (user_id);


--
-- Name: index_taxon_names_on_lexicon; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_names_on_lexicon ON public.taxon_names USING btree (lexicon);


--
-- Name: index_taxon_names_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_names_on_taxon_id ON public.taxon_names USING btree (taxon_id);


--
-- Name: index_taxon_photos_on_photo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_photos_on_photo_id ON public.taxon_photos USING btree (photo_id);


--
-- Name: index_taxon_photos_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_photos_on_taxon_id ON public.taxon_photos USING btree (taxon_id);


--
-- Name: index_taxon_ranges_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_ranges_on_geom ON public.taxon_ranges USING gist (geom);


--
-- Name: index_taxon_ranges_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_ranges_on_taxon_id ON public.taxon_ranges USING btree (taxon_id);


--
-- Name: index_taxon_ranges_on_updater_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_ranges_on_updater_id ON public.taxon_ranges USING btree (updater_id);


--
-- Name: index_taxon_ranges_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_ranges_on_user_id ON public.taxon_ranges USING btree (user_id);


--
-- Name: index_taxon_scheme_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_scheme_taxa_on_taxon_id ON public.taxon_scheme_taxa USING btree (taxon_id);


--
-- Name: index_taxon_scheme_taxa_on_taxon_name_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_scheme_taxa_on_taxon_name_id ON public.taxon_scheme_taxa USING btree (taxon_name_id);


--
-- Name: index_taxon_scheme_taxa_on_taxon_scheme_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_scheme_taxa_on_taxon_scheme_id ON public.taxon_scheme_taxa USING btree (taxon_scheme_id);


--
-- Name: index_taxon_schemes_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxon_schemes_on_source_id ON public.taxon_schemes USING btree (source_id);


--
-- Name: index_trip_purposes_on_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trip_purposes_on_resource_type_and_resource_id ON public.trip_purposes USING btree (resource_type, resource_id);


--
-- Name: index_trip_purposes_on_trip_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trip_purposes_on_trip_id ON public.trip_purposes USING btree (trip_id);


--
-- Name: index_trip_taxa_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trip_taxa_on_taxon_id ON public.trip_taxa USING btree (taxon_id);


--
-- Name: index_trip_taxa_on_trip_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trip_taxa_on_trip_id ON public.trip_taxa USING btree (trip_id);


--
-- Name: index_update_actions_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_update_actions_unique ON public.update_actions USING btree (resource_id, notifier_id, resource_type, notifier_type, notification, resource_owner_id);


--
-- Name: index_user_blocks_on_blocked_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_blocks_on_blocked_user_id ON public.user_blocks USING btree (blocked_user_id);


--
-- Name: index_user_blocks_on_override_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_blocks_on_override_user_id ON public.user_blocks USING btree (override_user_id);


--
-- Name: index_user_blocks_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_blocks_on_user_id ON public.user_blocks USING btree (user_id);


--
-- Name: index_user_mutes_on_muted_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_mutes_on_muted_user_id ON public.user_mutes USING btree (muted_user_id);


--
-- Name: index_user_mutes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_mutes_on_user_id ON public.user_mutes USING btree (user_id);


--
-- Name: index_user_parents_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_parents_on_email ON public.user_parents USING btree (email);


--
-- Name: index_user_parents_on_parent_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_parents_on_parent_user_id ON public.user_parents USING btree (parent_user_id);


--
-- Name: index_user_parents_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_parents_on_user_id ON public.user_parents USING btree (user_id);


--
-- Name: index_user_privileges_on_revoke_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_privileges_on_revoke_user_id ON public.user_privileges USING btree (revoke_user_id);


--
-- Name: index_user_privileges_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_privileges_on_user_id ON public.user_privileges USING btree (user_id);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_curator_sponsor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_curator_sponsor_id ON public.users USING btree (curator_sponsor_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_identifications_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_identifications_count ON public.users USING btree (identifications_count);


--
-- Name: index_users_on_journal_posts_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_journal_posts_count ON public.users USING btree (journal_posts_count);


--
-- Name: index_users_on_last_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_last_ip ON public.users USING btree (last_ip);


--
-- Name: index_users_on_life_list_taxa_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_life_list_taxa_count ON public.users USING btree (life_list_taxa_count);


--
-- Name: index_users_on_login; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_login ON public.users USING btree (login);


--
-- Name: index_users_on_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_lower_email ON public.users USING btree (lower((email)::text));


--
-- Name: index_users_on_lower_login; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_lower_login ON public.users USING btree (lower((login)::text));


--
-- Name: index_users_on_oauth_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_oauth_application_id ON public.users USING btree (oauth_application_id);


--
-- Name: index_users_on_observations_count; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_observations_count ON public.users USING btree (observations_count);


--
-- Name: index_users_on_place_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_place_id ON public.users USING btree (place_id);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_site_id ON public.users USING btree (site_id);


--
-- Name: index_users_on_spammer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_spammer ON public.users USING btree (spammer);


--
-- Name: index_users_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_state ON public.users USING btree (state);


--
-- Name: index_users_on_unconfirmed_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_unconfirmed_email ON public.users USING btree (unconfirmed_email);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: index_users_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_updated_at ON public.users USING btree (updated_at);


--
-- Name: index_users_on_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_uri ON public.users USING btree (uri);


--
-- Name: index_users_on_uuid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_uuid ON public.users USING btree (uuid);


--
-- Name: index_votes_on_unique_obs_fave; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_votes_on_unique_obs_fave ON public.votes USING btree (votable_type, votable_id, voter_type, voter_id) WHERE (((votable_type)::text = 'Observation'::text) AND ((voter_type)::text = 'User'::text) AND (vote_scope IS NULL) AND (vote_flag = true));


--
-- Name: index_votes_on_votable_id_and_votable_type_and_vote_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_votes_on_votable_id_and_votable_type_and_vote_scope ON public.votes USING btree (votable_id, votable_type, vote_scope);


--
-- Name: index_votes_on_voter_id_and_voter_type_and_vote_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_votes_on_voter_id_and_voter_type_and_vote_scope ON public.votes USING btree (voter_id, voter_type, vote_scope);


--
-- Name: index_wiki_page_attachments_on_page_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_attachments_on_page_id ON public.wiki_page_attachments USING btree (page_id);


--
-- Name: index_wiki_page_versions_on_page_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_versions_on_page_id ON public.wiki_page_versions USING btree (page_id);


--
-- Name: index_wiki_page_versions_on_updator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_page_versions_on_updator_id ON public.wiki_page_versions USING btree (updator_id);


--
-- Name: index_wiki_pages_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_wiki_pages_on_creator_id ON public.wiki_pages USING btree (creator_id);


--
-- Name: index_wiki_pages_on_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_wiki_pages_on_path ON public.wiki_pages USING btree (path);


--
-- Name: index_year_statistic_localized_shareable_images_on_ys_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_year_statistic_localized_shareable_images_on_ys_id ON public.year_statistic_localized_shareable_images USING btree (year_statistic_id);


--
-- Name: index_year_statistics_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_year_statistics_on_site_id ON public.year_statistics USING btree (site_id);


--
-- Name: index_year_statistics_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_year_statistics_on_user_id ON public.year_statistics USING btree (user_id);


--
-- Name: pof_projid_ofid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pof_projid_ofid ON public.project_observation_fields USING btree (project_id, observation_field_id);


--
-- Name: pof_projid_pos; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX pof_projid_pos ON public.project_observation_fields USING btree (project_id, "position");


--
-- Name: taggings_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX taggings_idx ON public.taggings USING btree (tag_id, taggable_id, taggable_type, context, tagger_id, tagger_type);


--
-- Name: taxon_names_lower_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX taxon_names_lower_name_index ON public.taxon_names USING btree (lower((name)::text));


--
-- Name: time_zone_geometries_geom_geom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX time_zone_geometries_geom_geom_idx ON public.time_zone_geometries USING gist (geom);


--
-- Name: unique_schema_migrations; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_schema_migrations ON public.schema_migrations USING btree (version);


--
-- Name: user_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_index ON public.audits USING btree (user_id, user_type);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20090820033338'),
('20090920043428'),
('20091005055004'),
('20091023222943'),
('20091024022010'),
('20091123044434'),
('20091216052325'),
('20091221195909'),
('20091223030137'),
('20100119024356'),
('20100610052004'),
('20100709225557'),
('20100807184336'),
('20100807184524'),
('20100807184540'),
('20100815222147'),
('20101002052112'),
('20101010224648'),
('20101017010641'),
('20101120231112'),
('20101128052201'),
('20101203223538'),
('20101218044932'),
('20101226171854'),
('20110107064406'),
('20110112061527'),
('20110202063613'),
('20110228043741'),
('20110316040303'),
('20110326195224'),
('20110330050657'),
('20110331173629'),
('20110331174611'),
('20110401221815'),
('20110402222428'),
('20110405041648'),
('20110405041654'),
('20110405041659'),
('20110408005124'),
('20110409064704'),
('20110414202308'),
('20110415221429'),
('20110415225622'),
('20110415230149'),
('20110428074115'),
('20110429004856'),
('20110429075345'),
('20110502182056'),
('20110502221926'),
('20110505040504'),
('20110513230256'),
('20110514221925'),
('20110526205447'),
('20110529052159'),
('20110531065431'),
('20110610193807'),
('20110709200352'),
('20110714185244'),
('20110731201217'),
('20110801001844'),
('20110805044702'),
('20110807035642'),
('20110809064402'),
('20110809064437'),
('20110811040139'),
('20110905185019'),
('20110913060143'),
('20111003210305'),
('20111014181723'),
('20111014182046'),
('20111027041911'),
('20111027211849'),
('20111028190803'),
('20111102210429'),
('20111108184751'),
('20111202065742'),
('20111209033826'),
('20111212052205'),
('20111226210945'),
('20120102213824'),
('20120105232343'),
('20120106222437'),
('20120109221839'),
('20120109221956'),
('20120119183954'),
('20120119184143'),
('20120120232035'),
('20120123001206'),
('20120123190202'),
('20120214200727'),
('20120413012920'),
('20120413013521'),
('20120416221933'),
('20120425042326'),
('20120427014202'),
('20120504214431'),
('20120521225005'),
('20120524173746'),
('20120525190526'),
('20120529181631'),
('20120609003704'),
('20120628014940'),
('20120628014948'),
('20120628015126'),
('20120629011843'),
('20120702194230'),
('20120702224519'),
('20120704055118'),
('20120711053525'),
('20120711053620'),
('20120712040410'),
('20120713074557'),
('20120717184355'),
('20120719171324'),
('20120725194234'),
('20120801204921'),
('20120808224842'),
('20120810053551'),
('20120821195023'),
('20120830020828'),
('20120902210558'),
('20120904064231'),
('20120906014934'),
('20120919201617'),
('20120926220539'),
('20120929003044'),
('20121011181051'),
('20121031200130'),
('20121101180101'),
('20121115043256'),
('20121116214553'),
('20121119073505'),
('20121128022641'),
('20121224231303'),
('20121227214513'),
('20121230023106'),
('20121230210148'),
('20130102225500'),
('20130103065755'),
('20130108182219'),
('20130108182802'),
('20130116165914'),
('20130116225224'),
('20130131001533'),
('20130131061500'),
('20130201224839'),
('20130205052838'),
('20130206192217'),
('20130208003925'),
('20130208222855'),
('20130226064319'),
('20130227211137'),
('20130301222959'),
('20130304024311'),
('20130306020925'),
('20130311061913'),
('20130312070047'),
('20130313192420'),
('20130403235431'),
('20130409225631'),
('20130411225629'),
('20130418190210'),
('20130429215442'),
('20130501005855'),
('20130502190619'),
('20130514012017'),
('20130514012037'),
('20130514012051'),
('20130514012105'),
('20130514012120'),
('20130516200016'),
('20130521001431'),
('20130523203022'),
('20130603221737'),
('20130603234330'),
('20130604012213'),
('20130607221500'),
('20130611025612'),
('20130613223707'),
('20130624022309'),
('20130628035929'),
('20130701224024'),
('20130704010119'),
('20130708233246'),
('20130708235548'),
('20130709005451'),
('20130709212550'),
('20130711181857'),
('20130721235136'),
('20130730200246'),
('20130814211257'),
('20130903235202'),
('20130910053330'),
('20130917071826'),
('20130926224132'),
('20130926233023'),
('20130929024857'),
('20131008061545'),
('20131011234030'),
('20131023224910'),
('20131024045916'),
('20131031160647'),
('20131031171349'),
('20131119214722'),
('20131123022658'),
('20131128214012'),
('20131128234236'),
('20131204211450'),
('20131220044313'),
('20140101210916'),
('20140104202529'),
('20140113145150'),
('20140114210551'),
('20140124190652'),
('20140205200914'),
('20140220201532'),
('20140225074921'),
('20140307003642'),
('20140313030123'),
('20140416193430'),
('20140604055610'),
('20140611180054'),
('20140620021223'),
('20140701212522'),
('20140704062909'),
('20140731201815'),
('20140820152353'),
('20140904004901'),
('20140912201349'),
('20141003193707'),
('20141015212020'),
('20141015213053'),
('20141112011137'),
('20141201211037'),
('20141203024242'),
('20141204224856'),
('20141213001622'),
('20141213195804'),
('20141229185357'),
('20141231210447'),
('20150104021132'),
('20150104033219'),
('20150126194129'),
('20150128225554'),
('20150203174741'),
('20150226010539'),
('20150304201738'),
('20150313171312'),
('20150319205049'),
('20150324004401'),
('20150404012836'),
('20150406181841'),
('20150409021334'),
('20150409031504'),
('20150412200608'),
('20150413222254'),
('20150421155510'),
('20150504184529'),
('20150509225733'),
('20150512222753'),
('20150524000620'),
('20150611215738'),
('20150614212053'),
('20150619231829'),
('20150622201252'),
('20150625230227'),
('20150701222736'),
('20150902052821'),
('20150916164339'),
('20150922154000'),
('20150922215548'),
('20151006230511'),
('20151014213826'),
('20151026184104'),
('20151030205931'),
('20151104175231'),
('20151117005737'),
('20151117221028'),
('20151228144302'),
('20160104200015'),
('20160317211729'),
('20160323182801'),
('20160324184344'),
('20160325152944'),
('20160406233849'),
('20160531181652'),
('20160531215755'),
('20160611140606'),
('20160613200151'),
('20160613202854'),
('20160624205645'),
('20160627194031'),
('20160629221454'),
('20160630024035'),
('20160701031842'),
('20160701042751'),
('20160726191620'),
('20160808154245'),
('20160809221731'),
('20160809221754'),
('20160815154039'),
('20160818234437'),
('20160913224325'),
('20160920151846'),
('20160929155608'),
('20161012202458'),
('20161012202803'),
('20161012204604'),
('20161020190217'),
('20161110221032'),
('20161210081605'),
('20161216041939'),
('20161220213126'),
('20170110025430'),
('20170110025450'),
('20170110185648'),
('20170113211950'),
('20170309003500'),
('20170317183900'),
('20170327224712'),
('20170413131753'),
('20170414011849'),
('20170418202820'),
('20170605234102'),
('20170630200341'),
('20170703152556'),
('20170706180531'),
('20170710150124'),
('20170710211319'),
('20170727000020'),
('20170727000602'),
('20170727193500'),
('20170801022454'),
('20170804212822'),
('20170808184245'),
('20170811032109'),
('20170811232802'),
('20170907221848'),
('20170920185103'),
('20170923232400'),
('20171107200722'),
('20171108223540'),
('20171218191934'),
('20171221220649'),
('20171222172131'),
('20180103194449'),
('20180109232530'),
('20180124192906'),
('20180126155509'),
('20180209020229'),
('20180320224314'),
('20180329144359'),
('20180410171703'),
('20180425181719'),
('20180501172628'),
('20180504213719'),
('20180518192353'),
('20180518231918'),
('20180613193352'),
('20180704195638'),
('20180719001655'),
('20180803162216'),
('20180821031507'),
('20180822173011'),
('20180905191330'),
('20180906232956'),
('20180911144001'),
('20180911233322'),
('20180914231617'),
('20181016064445'),
('20181016064507'),
('20181016064523'),
('20181028002405'),
('20181102233037'),
('20181110004422'),
('20181120235404'),
('20181203171209'),
('20190104024910'),
('20190215195613'),
('20190301012813'),
('20190308020554'),
('20190404042229'),
('20190514191221'),
('20190514192302'),
('20190516011313'),
('20190516181748'),
('20190528222836'),
('20190604231553'),
('20190702063435'),
('20190820224224'),
('20190918161513'),
('20191101004413'),
('20191104233418'),
('20191115201008'),
('20191203201511'),
('20191210173400'),
('20200116234248'),
('20200117011717'),
('20200122231601'),
('20200127213714'),
('20200130191142'),
('20200220211829'),
('20200226211718'),
('20200318193130'),
('20200604181750'),
('20200706035032'),
('20200708223315'),
('20200710004607'),
('20200710004608'),
('20200822002822'),
('20200824210059'),
('20200826001446'),
('20200910001039'),
('20200918185507'),
('20200918230545'),
('20200925210606'),
('20201023174221'),
('20201118012108'),
('20201204005354'),
('20210125233250'),
('20210127005238'),
('20210128211322'),
('20210213020914'),
('20210220195556'),
('20210305235042'),
('20210408221535'),
('20210625223935'),
('20210630004545'),
('20210819164339'),
('20210819214533'),
('20210908061217'),
('20210908070001'),
('20210921160302'),
('20210921160446'),
('20210921160504'),
('20210930182050'),
('20211001151300'),
('20211109220615'),
('20211216171216'),
('20220105014844'),
('20220127195113'),
('20220209191328'),
('20220217224804'),
('20220224012321'),
('20220225054243'),
('20220305012626'),
('20220308015748'),
('20220310001916'),
('20220317205240'),
('20220317210522'),
('20220407173712'),
('20221129175508'),
('20221214192739'),
('20221219015021'),
('20230224230316'),
('20230407150700'),
('20230504154134'),
('20230504154207'),
('20230504154224'),
('20230504154236'),
('20230504154248'),
('20230504154302'),
('20230907210748'),
('20231017190352'),
('20231025144604'),
('20240109034635'),
('20240109035846'),
('20240109035854'),
('20240110183622');


