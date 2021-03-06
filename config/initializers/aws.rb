Aws.config.update({
    region: 'sa-east-1',
    credentials: Aws::Credentials.new(ENV['AWS_MEGA_ID'], ENV['AWS_MEGA_KEY']),
  })
  
  S3_BUCKET = Aws::S3::Resource.new.bucket(ENV['S3_BUCKET'])