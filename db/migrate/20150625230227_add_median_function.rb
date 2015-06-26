class AddMedianFunction < ActiveRecord::Migration
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION _final_median(anyarray) RETURNS float8 AS $$ 
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
      $$ LANGUAGE SQL IMMUTABLE;
      
      DROP AGGREGATE IF EXISTS median(anyelement);
      CREATE AGGREGATE median(anyelement) (
        SFUNC=array_append,
        STYPE=anyarray,
        FINALFUNC=_final_median,
        INITCOND='{}'
      );
    SQL
  end

  def down
    execute <<-SQL
      DROP AGGREGATE IF EXISTS median(anyelement);
      DROP FUNCTION IF EXISTS _final_median(anyarray);
    SQL
  end
end
