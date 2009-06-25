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

  require 'yaml'
  def self.get_credentials
    #Dir.chdir do
      begin
        Dir.chdir('.rightscale') do 
          credentials = YAML::load(File.open("testcredentials.yml"))
          puts credentials.inspect
            self.aws_access_key_id = credentials["access_key"]
            self.aws_secret_access_key = credentials["secret_key"]
            puts 'akey=' + self.aws_access_key_id
        end
      rescue Exception => e
        puts "Couldn't chdir to ~/.rightscale: #{e.message}"
          raise e
      end
    #end
  end
end
