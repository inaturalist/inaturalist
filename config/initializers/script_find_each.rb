# frozen_string_literal: true

module ActiveRecord
  module Batches
    # Just like find_each except it writes useful output to STDOUT
    def script_find_each( options = {} )
      total = count
      current = 1
      recent_times = []
      flush = options.delete( :flush )
      max_count_width = Math.log( total ) + 2
      find_each do | record |
        eta = "??????????????????"
        avg = 0
        unless recent_times.blank?
          avg = recent_times.sum.to_f / recent_times.size
          eta = ApplicationController.helpers.time_ago_in_words( (
            avg * ( total - current )
          ).seconds.from_now )
        end
        pieces = [
          "#{record.class.name} #{record.id}".ljust( max_count_width + record.class.name.size + 5 ),
          "#{current.to_s.rjust( max_count_width )} / #{total}",
          "#{( current.to_f / total * 100 ).round( 2 )}%",
          "Avg: #{"#{avg.to_f.round( 4 )}s".ljust( 10 )}",
          "ETA #{eta}"
        ]
        col_size = pieces.sort.last.size + 4
        msg = pieces.map {| p | p.ljust( col_size ) }.join
        if flush
          print "#{msg}\r"
          $stdout.flush
        else
          puts msg
        end
        current += 1
        start = Time.now
        yield record
        recent_times << ( Time.now - start )
        recent_times.unshift if recent_times.size > 10
      end
    end
  end

  module Querying
    delegate :script_find_each, to: :all
  end
end
