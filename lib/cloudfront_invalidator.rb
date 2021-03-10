module CloudfrontInvalidator

  extend ActiveSupport::Concern

  def invalidate_cloudfront_cache_for(attachment_name, path_pattern)
    attr_to_check = "#{attachment_name}_updated_at"
    # the attachment has been modified, and was an attachment before
    return if try(:skip_cloudfront_invalidation)
    if respond_to?( :in_public_s3_bucket? ) && in_public_s3_bucket?
      # the public bucket does not use cloudfront
      return
    end
    if changes[attr_to_check] && !changes[attr_to_check][0].nil?
      begin
        INatAWS.cloudfront_invalidate(path_pattern.sub(":id", id.to_s))
      rescue Exception => e
        Rails.logger.error "[ERROR #{Time.now}] Failed CloudFront invalidation: #{e}"
      end
    end
  end

  class_methods do
    # it's important to place this after `has_attached_file`
    def invalidate_cloudfront_caches(attachment_name, path_pattern)
      after_save ->(obj) { invalidate_cloudfront_cache_for(attachment_name, path_pattern) }
    end
  end
end

ActiveRecord::Base.send(:include, CloudfrontInvalidator)
