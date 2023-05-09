module CloudfrontInvalidator

  extend ActiveSupport::Concern

  included do
    def invalidate_cloudfront_cache_for( attachment_name, path_pattern )
      begin
        INatAWS.cloudfront_invalidate( path_pattern.sub( ":id", id.to_s ) )
      rescue Exception => e
        Rails.logger.error "[ERROR #{Time.now}] Failed CloudFront invalidation: #{e}"
      end
    end


    class << self
      def invalidate_cloudfront_caches( attachment_name, path_pattern )
        after_save ->( obj ) do
          return if try( :skip_cloudfront_invalidation )
          if respond_to?( :in_public_s3_bucket? ) && in_public_s3_bucket?
            # the public bucket does not use cloudfront
            return
          end
          attr_to_check = "#{attachment_name}_updated_at"
          if saved_changes[attr_to_check] && !saved_changes[attr_to_check][0].nil?
            self.class.delay(
              priority: INTEGRITY_PRIORITY,
              unique_hash: { "#{self.class.name}::invalidate_cloudfront_cache_for": id }
            ).invalidate_cloudfront_cache_for( id, attachment_name, path_pattern )
          end
        end
      end

      def invalidate_cloudfront_cache_for( id, attachment_name, path_pattern )
        return unless instance = find_by_id( id )
        instance.invalidate_cloudfront_cache_for( attachment_name, path_pattern )
      end
    end
  end
end

ActiveRecord::Base.send(:include, CloudfrontInvalidator)
