namespace :inaturalist do
  desc "Copy example config files."
  task :setup do
    Dir.glob("#{Rails.root}/config/*.example").each do |file|
      example = File.basename(file)
      file = File.basename(example, '.example')
      if File.exists?(Rails.root.join('config', file))
        puts "#{file} already exists."
      else
        cp Rails.root.join('config', example), Rails.root.join('config', file)
      end
    end
    exit 0
  end

  desc "Set the public_positional_accuracy and mappable fields on observations."
  task :update_public_accuracy => :environment do
    batch = 0
    batch_size = 10000
    total_observations = Observation.count
    total_batches = (total_observations / batch_size).ceil
    start_time = Time.now
    Observation.includes(:quality_metrics).find_in_batches(batch_size: batch_size) do |observations|
      puts "Starting batch #{ batch += 1 } of #{ total_batches } at #{ (Time.now - start_time).round(2) } seconds"
      Observation.connection.transaction do
        observations.each do |o|
          o.update_public_positional_accuracy
          o.update_mappable
        end
      end
    end
  end

  desc "Delete content from spmmer accounts."
  task :delete_spam_content => :environment do
    spammer_ids = User.where(spammer: true).
      where("suspended_at < ?", User::DELETE_SPAM_AFTER.ago).
      collect(&:id)
    Comment.where(user_id: spammer_ids).destroy_all
    Guide.where(user_id: spammer_ids).destroy_all
    Identification.where(user_id: spammer_ids).destroy_all
    List.where(user_id: spammer_ids).where("lists.type != 'LifeList'").destroy_all
    Observation.where(user_id: spammer_ids).destroy_all
    Post.where(user_id: spammer_ids).destroy_all
    Project.where(user_id: spammer_ids).destroy_all
    User.where(id: spammer_ids).update_all(description: nil)
  end
end

