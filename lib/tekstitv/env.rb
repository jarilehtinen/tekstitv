# frozen_string_literal: true

module TekstiTV
  # Environment helpers for local secrets and validation.
  module Env
    ROOT_DIR = File.expand_path('../..', __dir__)

    def self.load!
      env_path = File.join(ROOT_DIR, '.env')
      return unless File.exist?(env_path)

      File.readlines(env_path, chomp: true).each do |line|
        next if line.strip.empty? || line.strip.start_with?('#')
        key, value = line.split('=', 2)
        next unless key && value

        ENV[key.strip] ||= value.strip
      end
    end

    def self.ensure_credentials!
      missing = []
      missing << 'YLE_APP_ID' if ENV['YLE_APP_ID'].to_s.strip.empty?
      missing << 'YLE_APP_KEY' if ENV['YLE_APP_KEY'].to_s.strip.empty?

      return if missing.empty?

      warn "Missing env: #{missing.join(', ')}"
      warn 'Create a .env file with YLE_APP_ID and YLE_APP_KEY.'
      exit 1
    end
  end
end
