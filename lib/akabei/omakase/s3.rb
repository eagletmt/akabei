module Akabei
  module Omakase
    class S3
      def initialize(aws_config, shell)
        if aws_config
          require 'aws-sdk-core'
          @s3 = Aws::S3::Client.new(
            access_key_id: aws_config['access_key_id'],
            secret_access_key: aws_config['secret_access_key'],
            region: aws_config['region'],
          )
          @bucket_name = aws_config['bucket']
          @write_options = aws_config['write_options']
          @shell = shell
        end
      end

      def before!(config, arch)
        download_repository(config, arch) if @s3
      end

      def after!(config, arch, packages)
        upload_repository(config, arch, packages) if @s3
      end

      def download_repository(config, arch)
        get(config.db_path(arch))
        if config.repo_signer
          get(Pathname.new("#{config.db_path(arch)}.sig"))
        end
        get(config.files_path(arch))
        get(config.abs_path(arch))
      end

      def get(path)
        @shell.say("Download #{path}", :blue)
        @s3.get_object(
          bucket: @bucket_name,
          key: path.to_s,
          response_target: path,
        )
      rescue Aws::S3::Errors::NoSuchKey
        @shell.say("S3: #{path} not found", :red)
        FileUtils.rm_f(path)
      end

      SIG_MIME_TYPE = 'application/pgp-signature'
      GZIP_MIME_TYPE = 'application/gzip'
      XZ_MIME_TYPE = 'application/x-xz'

      def upload_repository(config, arch, packages)
        packages.each do |package|
          put(package.path, XZ_MIME_TYPE)
          if config.package_signer
            put(Pathname.new("#{package.path}.sig"), SIG_MIME_TYPE)
          end
        end
        put(config.abs_path(arch), GZIP_MIME_TYPE)
        put(config.files_path(arch), GZIP_MIME_TYPE)
        put(config.db_path(arch), GZIP_MIME_TYPE)
        if config.repo_signer
          put(Pathname.new("#{config.db_path(arch)}.sig"), SIG_MIME_TYPE)
        end
      end

      def put(path, mime_type)
        @shell.say("Upload #{path}", :green)
        path.open do |f|
          @s3.put_object(
            @write_options.merge(
              bucket: @bucket_name,
              key: path.to_s,
              body: f,
              content_type: mime_type,
            )
          )
        end
      end
    end
  end
end
