class TestCredentials

  @@aws_access_key_id = nil 
  @@aws_secret_access_key = nil 
  @@account_number = nil

  def self.aws_access_key_id
    @@aws_access_key_id
  end
  def self.aws_access_key_id=(newval)
    @@aws_access_key_id = newval
  end
  def self.account_number
    @@account_number
  end
  def self.account_number=(newval)
    @@account_number = newval
  end
  def self.aws_secret_access_key
    @@aws_secret_access_key
  end
  def self.aws_secret_access_key=(newval)
    @@aws_secret_access_key = newval
  end

  def self.get_credentials
    Dir.chdir do
      begin
        Dir.chdir('./.rightscale') do 
          require 'testcredentials'
        end
      rescue Exception => e
        puts "Couldn't chdir to ~/.rightscale: #{e.message}"
      end
    end
  end
end
