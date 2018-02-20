require 'geckodriver/helper/version'
require 'geckodriver/helper/gecko_release_page_parser'
require 'fileutils'
require 'rbconfig'
require 'open-uri'
require 'archive/zip'
require 'zlib'
require 'rubygems/package'

module Geckodriver
  def self.install(version: nil, token: nil)
    Geckodriver::Helper.new.install_driver(version, token)
  end

  def self.update(version: nil, token: nil)
    Geckodriver::Helper.new.update_driver(version, token)
  end

  class Helper
    def initialize
      @gecko_release_parser = GeckoReleasePageParser.new(platform)
    end

    def run(*args)
      download
      exec binary_path, *args
    end

    def install_driver(version, token)
      @gecko_release_parser.authentication(token) unless token.nil?

      hit_network = current_version != version
      download(hit_network, version: version)
      exec binary_path unless File.exist?(binary_path)
    end

    def update_driver(version, token)
      @gecko_release_parser.authentication(token) unless token.nil?
      version ||= @gecko_release_parser.latest_release_version

      hit_network = current_version != version
      download(hit_network, version: version)
    end

    # rubocop:disable Metrics/AbcSize
    def download(hit_network = false, version: nil)
      return if File.exist?(binary_path) && !hit_network

      url = download_url(version)
      filename = File.basename url
      Dir.chdir platform_install_dir do
        FileUtils.rm_f filename
        File.open(filename, 'wb') do |saved_file|
          URI.parse(url).open('rb') do |read_file|
            saved_file.write(read_file.read)
          end
        end
        raise "Could not download #{url}" unless File.exist? filename
        unpack_archive(filename)
      end

      raise "Could not unarchive #{filename} to get #{binary_path}" unless File.exist? binary_path
      FileUtils.chmod 'ugo+rx', binary_path

      final_version = version || @gecko_release_parser.latest_release_version
      File.open(version_path, 'w') { |file| file.write(final_version) }
    end

    def download_url(version = nil)
      @gecko_release_parser.download_release(version)
    end

    def unpack_archive(file)
      if platform == 'win'
        unzip(file)
      else
        io = ungzip(file)
        untar(io)
      end
    end

    def binary_path
      if platform == 'win'
        File.join platform_install_dir, 'geckodriver.exe'
      else
        File.join platform_install_dir, 'geckodriver'
      end
    end

    def platform_install_dir
      dir = File.join install_dir, platform
      FileUtils.mkdir_p dir
      dir
    end

    def install_dir
      dir = File.expand_path File.join(ENV['HOME'], '.geckodriver-helper')
      FileUtils.mkdir_p dir
      dir
    end

    def platform
      cfg = RbConfig::CONFIG
      case cfg['host_os']
      when /linux/ then
        cfg['host_cpu'] =~ /x86_64|amd64/ ? 'linux64' : 'linux32'
      when /darwin/ then
        'mac'
      else
        'win'
      end
    end

    private

    def current_version
      File.read(version_path).strip if File.exist?(version_path)
    end

    def version_path
      File.join(install_dir, '.geckodriver-version')
    end

    def unzip(zipfile)
      Archive::Zip.extract(zipfile, '.', overwrite: :all)
    end

    def ungzip(tarfile)
      z = Zlib::GzipReader.open(tarfile)
      unzipped = StringIO.new(z.read)
      z.close
      unzipped
    end

    def untar(io)
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          destination_file = tarfile.full_name
          File.open destination_file, 'wb' do |f|
            f.print tarfile.read
          end
        end
      end
    end
  end
end
