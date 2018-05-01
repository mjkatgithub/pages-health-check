# frozen_string_literal: true

require "dnsruby"
require "public_suffix"

module GitHubPages
  module HealthCheck
    class CAA
      attr_reader :host
      attr_reader :error

      def initialize(host)
        raise ArgumentError, "host cannot be nil" if host.nil?

        @host = host
      end

      def errored?
        records # load the records first
        !error.nil?
      end

      def lets_encrypt_allowed?
        return false if errored?
        return true unless records_present?
        records.any? { |r| r.property_value == "letsencrypt.org" }
      end

      def records_present?
        return false if errored?
        records && !records.empty?
      end

      def records
        @records ||= (get_caa_records(host) | get_caa_records(PublicSuffix.domain(host)))
      end

      private

      def get_caa_records(domain)
        return [] if domain.nil?
        query(domain).select { |r| r.type == Dnsruby::Types::CAA && r.property_tag == "issue" }
      end

      def query(domain)
        resolver = Dnsruby::Resolver.new
        resolver.retry_times = 2
        resolver.query_timeout = 2
        begin
          resolver.query(domain, Dnsruby::Types::CAA).answer
        rescue Dnsruby::ResolvError => e
          @error = e
          []
        end
      end
    end
  end
end
