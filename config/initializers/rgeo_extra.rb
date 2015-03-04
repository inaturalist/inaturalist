module RGeo
  module Geos

    class CAPIMultiPolygonImpl
      def num_points
        sum(&:num_points)
      end

      def points
        map(&:points).flatten
      end

      def spans_dateline?
        return true if detect{|g| g.spans_dateline?}
        pts = map {|g| g.envelope.centroid}
        CAPIPointImpl.points_span_dateline?(pts)
      end
    end

    class CAPIPolygonImpl
      def num_points
        exterior_ring.num_points + interior_rings.sum {|r| r.num_points}
      end

      def lower_corner
        e = exterior_ring.num_points == 5 ? exterior_ring : envelope.exterior_ring
        e.points[0]
      end

      def upper_corner
        e = exterior_ring.num_points == 5 ? exterior_ring : envelope.exterior_ring
        e.points[2]
      end

      def points
        rings.map(&:points).flatten
      end

      def rings
        [exterior_ring, interior_rings].flatten
      end

      def spans_dateline?
        rings.each do |ring|
          return true if CAPIPointImpl.points_span_dateline?(ring.points)
        end
        false
      end
    end

    class CAPIPointImpl
      def east_of?(point)
        !west_of?(point)
      end

      def west_of?(point)
        (x > 0 && point.x < 0) ? x - 180 > point.x : x < point.x
      end

      def north_of?(point)
        !south_of?(point)
      end

      def south_of?(point)
        y < point.y
      end

      def across_dateline_from?(point)
        return true if point.x > 180 # apparently this is how it handles stuff near the edge sometimes
        (x < 0 && point.x > 0 || x > 0 && point.x < 0) && (x.abs > 90 || point.x.abs > 90)
      end

      def self.points_span_dateline?(pts)
        pts.each_with_index do |pt,i|
          next_pt = pts[i+1] || pts[0]
          return true if pt.across_dateline_from?(next_pt)
        end
        false
      end
    end

  end
end
