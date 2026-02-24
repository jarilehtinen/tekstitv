# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'openssl'

require_relative 'parser'

module TekstiTV
  # HTTP client and caching for teletext JSON pages.
  module Client
    API_BASE = 'https://external.api.yle.fi/v1/teletext/pages'.freeze
    CACHE_DIR = 'cache'.freeze
    ROOT_DIR = File.expand_path('../..', __dir__)

    def self.fetch_page(page_number, cache:, allow_api:)
      return cache[page_number] if cache.key?(page_number)

      cached = read_cached_page(page_number)
      if cached
        parsed = Parser.parse_content(cached)
        cache[page_number] = parsed
        return parsed
      end

      return nil unless allow_api

      uri = URI("#{API_BASE}/#{page_number}.json")
      params = { 'app_id' => ENV['YLE_APP_ID'], 'app_key' => ENV['YLE_APP_KEY'] }
      uri.query = URI.encode_www_form(params)

      response = http_get(uri)
      return "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

      cache_page(page_number, response.body)
      parsed = Parser.parse_content(response.body)
      cache[page_number] = parsed
      parsed
    rescue StandardError => e
      "Error: #{e.class}: #{e.message}"
    end

    # Force refresh from API and update cache + file.
    def self.refresh_page(page_number, cache:)
      cache.delete(page_number)
      delete_cached_page(page_number)
      fetch_page(page_number, cache: cache, allow_api: true)
    end

    def self.read_cached_page(page_number)
      path = File.join(ROOT_DIR, CACHE_DIR, "#{page_number}.json")
      return nil unless File.exist?(path)

      File.read(path)
    end

    def self.cache_page(page_number, body)
      cache_dir = File.join(ROOT_DIR, CACHE_DIR)
      Dir.mkdir(cache_dir) unless Dir.exist?(cache_dir)
      path = File.join(cache_dir, "#{page_number}.json")
      File.write(path, body)
    end

    def self.delete_cached_page(page_number)
      path = File.join(ROOT_DIR, CACHE_DIR, "#{page_number}.json")
      File.delete(path) if File.exist?(path)
    end

    def self.http_get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      ca_file = ssl_ca_file
      http.ca_file = ca_file if ca_file

      http.get(uri.request_uri)
    end

    def self.ssl_ca_file
      env_path = ENV['SSL_CERT_FILE'].to_s.strip
      return env_path unless env_path.empty?

      candidates = [
        '/etc/ssl/cert.pem', # macOS
        '/etc/ssl/certs/ca-certificates.crt', # Debian/Ubuntu
        '/etc/pki/tls/certs/ca-bundle.crt', # RHEL/CentOS/Fedora
        '/usr/local/etc/openssl@3/cert.pem', # Homebrew Intel
        '/usr/local/etc/openssl@1.1/cert.pem',
        '/opt/homebrew/etc/openssl@3/cert.pem', # Homebrew Apple Silicon
        '/opt/homebrew/etc/openssl@1.1/cert.pem'
      ]

      candidates.find { |path| File.exist?(path) }
    end
  end
end
