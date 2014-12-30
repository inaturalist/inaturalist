# Some monkey patches to georuby, mostly to accurately calculate bounding 
# boxes for multiring polygons.  IN the future, when I am a responsible human
# being, I will branch georuby on github, but not today.
module GeoRuby
  module SimpleFeatures
    class Point
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
    
    class MultiPolygon
      def num_points
        geometries.sum {|r| r.num_points}
      end

      def spans_dateline?
        return true if geometries.detect{|g| g.spans_dateline?}
        pts = geometries.map {|g| g.envelope.center}
        Point.points_span_dateline?(pts)
      end
    end
    
    class Polygon
      def num_points
        rings.sum {|r| r.size}
      end
      
      def bounding_box
        unless with_z
          bbox = @rings[0].bounding_box
          @rings[1..-1].each do |ring|
            ring_bbox = ring.bounding_box
            bbox[0].x = ring_bbox[0].x if ring_bbox[0].west_of?(bbox[0])
            bbox[0].y = ring_bbox[0].y if ring_bbox[0].south_of?(bbox[0])
            bbox[1].x = ring_bbox[1].x if ring_bbox[1].east_of?(bbox[1])
            bbox[1].y = ring_bbox[1].y if ring_bbox[1].north_of?(bbox[1])
          end
          bbox
        else
          result = @rings[0].bounding_box #valid for x and y
          max_z, min_z = result[1].z, result[0].z
          1.upto(size - 1) do |index|
            bbox = @rings[index].bounding_box
            sw = bbox[0]
            ne = bbox[1]
            max_z = ne.z if ne.z > max_z
            min_z = sw.z if sw.z < min_z 
          end
          result[1].z, result[0].z = max_z, min_z
          result
        end
      end

      def spans_dateline?
        rings.each do |ring|
          return true if Point.points_span_dateline?(ring.points)
        end
        false
      end
    end
  end
end
