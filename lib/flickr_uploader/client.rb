require 'flickraw'

module FlickrUploader
  class Client
    attr_accessor :flickr

    def initialize
      @auth_info = ConfigFile.new(Conf::AUTH_FILE, :token, :secret)
      @api_info = ConfigFile.new(Conf::API_FILE, :api_key, :shared_secret)
      config_api
      authenticate
      LOG.debug "Flickr account set up"
    end

    def config_api
      create_api_file unless @api_info.valid?
      LOG.debug "API_KEY: #{@api_info[:api_key]} | SECRET: #{@api_info[:shared_secret]}"
      FlickRaw.api_key = @api_info[:api_key]
      FlickRaw.shared_secret = @api_info[:shared_secret]
      self.flickr = FlickRaw::Flickr.new
    end

    def create_api_file
      STDOUT.print "Enter your API key: "
      api_key = STDIN.gets.chomp
      STDOUT.print "Enter your API shared secret: "
      secret = STDIN.gets.chomp
      @api_info.write(api_key: api_key, shared_secret: secret)
    end

    def authenticate
      create_auth_file unless @auth_info.valid?
      flickr.access_token = @auth_info[:token]
      flickr.access_secret = @auth_info[:secret]
      authenticate unless valid_token?
    end

    def create_auth_file
      LOG.debug "Authenticating"
      info = flickr.get_request_token
      req_token, req_secret = info['oauth_token'], info['oauth_token_secret']
      verification_code = get_verification_code(req_token, req_secret)
      info = get_auth_info(req_token, req_secret, verification_code)
      @auth_info.write(info)
    end

    def valid_token?
      begin
        true if flickr.test.login
      rescue
        LOG.debug "Stale token. Removing auth file."
        @auth_info.remove
        false
      end
    end

    def get_verification_code(request_token, request_secret, perms = 'write')
      LOG.debug "Get URL for verification token"
      auth_url = flickr.get_authorize_url(request_token, :perms => perms)
      STDOUT.puts "Visit this URL to get your verification code: #{auth_url}"
      STDOUT.print "Verification code: "
      STDIN.gets.strip
    end

    def get_auth_info(req_token, req_secret, verification_code)
      flickr.get_access_token(req_token, req_secret, verification_code)
      {token: flickr.access_token, secret: flickr.access_secret}
    end
  end
end
