require "rubygems"
require "optimist"

OPTS = Optimist::options do
    banner <<-EOS
Import Sendgrid email suppressions and store locally.

Usage:

  rails runner tools/sync_suppressions.rb

where [options] are:
EOS
  opt :debug, "Print debug statements", :type => :boolean, :short => "-d"
end

start = Time.now

def get_response( url )
  response = RestClient.get( url, {
    "Authorization" => "Bearer #{ CONFIG.sendgrid_api_key }"
  } )		
end

def get_records( url_base )
  json = [1]
  records = []
  i=0
  while json.count > 0
    puts "\t...reading page #{i}"
  	offset=500*i
	  url = "#{url_base}?limit=500&offset=#{ offset }"
  	begin
  	  response = get_response( url )
  	rescue
  	  response = get_response( url )
  	end
  	json = JSON.parse( response )
 	 records << json
  	i += 1
  end
  records = records.flatten
end

def get_supressions( suppression_type )
  puts "getting suppressions of type #{ suppression_type }"
  url_base = "https://api.sendgrid.com/v3/suppression/#{ suppression_type }"
  records = get_records( url_base )
  emails = records.map{ |a| a["email"] }.uniq
  return emails
end

def get_supression_group
  puts "getting group suppressions"
  url_base = "https://api.sendgrid.com/v3/asm/suppressions"
  records = get_records( url_base )

  emails = Hash.new
  records.map{ |a| a["group_name"] }.uniq.each do |group_name|
  	group = records.select{ |a| a["group_name"] == group_name }.map{ |a| a["email"] }
  	emails[group_name.downcase.gsub( " ", "_" )] = group
  end
  return emails
end

def save_emails( emails, suppression_type )
  emails.each do |email|
    unless es = EmailSuppression.where( email: email, suppression_type: suppression_type ).first
      es = EmailSuppression.new( email: email, suppression_type: suppression_type )
    end
    es.save
  end
end

suppression_type = "bounces"
emails = get_supressions( suppression_type )
save_emails( emails, suppression_type )

suppression_type = "blocks"
emails = get_supressions( suppression_type )
save_emails( emails, suppression_type )

suppression_type = "invalid_emails"
emails = get_supressions( suppression_type )
save_emails( emails, suppression_type )

suppression_type = "spam_reports"
emails = get_supressions( suppression_type )
save_emails( emails, suppression_type )

suppression_type = "unsubscribes"
emails = get_supressions( suppression_type )
save_emails( emails, suppression_type )

emails = get_supression_group
emails.each do |suppression_type, emails|
  save_emails( emails, suppression_type )
end

created_count = EmailSuppression.where("updated_at >= ? OR created_at >= ?", start, start).count

to_destroy = EmailSuppression.where("updated_at < ? OR created_at < ?", start, start)
destroy_count = to_destroy.count
to_destroy.destroy_all 

puts
puts "Imported #{created_count} emails and removed #{destroy_count} emails in #{Time.now - start}s"
puts


