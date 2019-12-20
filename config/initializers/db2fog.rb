require_relative 'spree'

# Use a config file provided by ofn-install if available.
if File.exists?(Rails.root.join("config", "db2fog.yml"))
  DB2Fog.config = YAML.load_file(Rails.root.join("config", "db2fog.yml"))
else
  # See: https://github.com/yob/db2fog
  DB2Fog.config = {
      :aws_access_key_id     => Spree::Config[:s3_access_key],
      :aws_secret_access_key => Spree::Config[:s3_secret],
      :directory             => ENV['S3_BACKUPS_BUCKET'],
      :provider              => 'AWS'
  }

  DB2Fog.config[:region] = ENV['S3_REGION'] if ENV['S3_REGION']
end
