# Logs destruction events in Logstash along with an in-app stack trace
module LogsDestruction
  
  extend ActiveSupport::Concern

  included do
    after_destroy :log_destruction

    private
    def log_destruction
      foreign_keys = self.class.reflections.select{|k,r| r.macro == :belongs_to }.map{|k,r| r.foreign_key} & self.class.column_names
      msg = "#{self.class.name} #{id} destroyed. #{foreign_keys.map{|k| "#{k}: #{send(k)}"}}"
      Rails.logger.debug "[INFO #{Time.now}] #{msg}"
      Logstasher.write_hash(
        # last_error is a text field, while error_message is a keyword field, so
        # if we want to search on text in the message, we need to use last_error
        # (or arguments, or backtrace)
        last_error: msg,
        backtrace: caller( 0 ).select{|l| l.index( Rails.root.to_s )}.map{|l| l.sub( Rails.root.to_s, "" )}.join( "\n" ),
        subtype: "#{self.class.name}#destroy",
        model: self.class.name,
        model_method: "destroy",
        model_method_id: "#{self.class.name}::destroy::#{id}"
      )
      true
    rescue => e
      Rails.logger.error "[ERROR] Failed to log destruction of #{self.class.name} #{id}: #{e}"
      true
    end
  end    
end
