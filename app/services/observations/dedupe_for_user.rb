module Observations
  class DedupeForUser
    def initialize(user, options = {})
      if user.is_a?(User)
        @user = user
      else
        @user = User.find_by_id(user) || User.find_by_login(user)
      end
      @options = options
    end

    def call
      return unless user
      sql = <<-SQL
        SELECT
          array_agg(id) AS observation_ids
        FROM
          observations
        WHERE
          user_id = #{user.id}
          AND taxon_id IS NOT NULL
          AND observed_on_string IS NOT NULL AND observed_on_string != ''
          AND private_geom IS NOT NULL
        GROUP BY
          user_id,
          taxon_id,
          observed_on_string,
          private_geom
        HAVING count(*) > 1;
      SQL
      deleted = 0
      start = Time.now
      Observation.connection.execute(sql).each do |row|
        ids = row['observation_ids'].gsub(/[\{\}]/, '').split(',').map(&:to_i).sort
        puts "Found duplicates: #{ids.join(',')}" if options[:debug]
        keeper_id = ids.shift
        puts "\tKeeping #{keeper_id}" if options[:debug]
        unless options[:test]
          Observation.find(ids).each do |o|
            puts "\tDeleting #{o.id}" if options[:debug]
            o.destroy
          end
        end
        deleted += ids.size
      end
      puts "Deleted #{deleted} observations in #{Time.now - start}s" if options[:debug]
    end

    private

    attr_reader :user, :options
  end
end
