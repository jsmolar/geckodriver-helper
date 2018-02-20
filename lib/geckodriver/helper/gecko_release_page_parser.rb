require 'open-uri'
require 'json'

module Geckodriver
  class Helper
    class GeckoReleasePageParser
      GIT_API_URL = 'https://api.github.com/repos/mozilla/geckodriver/releases'.freeze

      attr_reader :platform

      def initialize(platform)
        @platform = platform
        @parsed_page = JSON.parse(open(GIT_API_URL).read)
      end

      def download(version)
        release = release_version(version)
        download_url = release_platform(release)
        download_url
      end

      def release_version(version)
        @parsed_page.each do |release|
          return release if release['tag_name'].include?(version)
        end
      end

      def latest_release_version
        @parsed_page[0]['tag_name']
      end

      def release_platform(release)
        release['assets'].each do |asset|
          link = asset['browser_download_url']
          return link if link.include? platform
        end
      end

      def latest_download_release
        download(latest_release_version)
      end

      def download_release(version)
        version.nil? ? latest_download_release : download(version)
      end
    end
  end
end
