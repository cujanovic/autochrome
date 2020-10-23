#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'tmpdir'
require 'optparse'
require 'open3'
require 'digest'

DATA_DIR = File.expand_path("../data", __FILE__)

THEME_COLORS = {
  Cyan: 0.5,
  Blue: 0.61,
  Green: 0.28,
  Orange: 0.08,
  Purple: 0.79,
  Red: 1.0,
  Yellow: 0.164,
  White: 0.0,
}

THEME_IMAGE = 'caution.png'
THEME_IMAGE2 = 'refresh.png'
THEME_IMAGE3 = 'tab.png'
THEME_IMAGE_PATH = File.join(DATA_DIR,'theme_source',THEME_IMAGE)
THEME_IMAGE_PATH2 = File.join(DATA_DIR,'theme_source',THEME_IMAGE2)
THEME_IMAGE_PATH3 = File.join(DATA_DIR,'theme_source',THEME_IMAGE3)
THEME_OUTPUT_PATH = File.join(DATA_DIR, 'themes')

EXT_SOURCE_DIR = File.join(DATA_DIR, 'extension_source')
EXT_OUTPUT_DIR = File.join(DATA_DIR, 'extensions')


def parse_options(arg_list)
  options = { path: "~/Applications/Chromium.app/Contents/MacOS/Chromium-orig" }

  OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options]"
    opts.separator ""

    opts.on("-p", "--path Chromium Path", "Path to chromium-orig") do |t|
      options[:path] = t
    end
    opts.on("-h", "--help", "Show this message") do
      puts opts
      exit 1
    end
  end.order(arg_list)

  options
end


options = parse_options(ARGV)

if !File.exists?(File.expand_path(options[:path]))
  puts "Chromium at #{options[:path]} does not exist. Specify location with --path"
  exit 1
end

def build_extension(options, path, target)
  system("#{options[:path]} --no-sandbox -no-message-box --pack-extension=#{path}")
  pubkey, _, _ = Open3.capture3('openssl', 'rsa', '-in', "#{path}.pem", '-pubout', '-outform', 'DER')
  File.write("#{File.dirname(target)}/#{File.basename(target, ".crx")}.pub", pubkey)
  FileUtils.mv("#{path}.crx", target)
  FileUtils.rm("#{path}.pem")
end

# Build themes

THEME_COLORS.each do |color_name,hue|
  Dir.mktmpdir do |temp_dir|
    manifest_path = File.join(temp_dir,'manifest.json')
    File.write(manifest_path, JSON.generate({
      "name": "Caution #{color_name}",
      "version": "1.1",
      "manifest_version": 2,
      "theme": {
        "images": {
          "theme_frame": "#{THEME_IMAGE}",
          "theme_frame_inactive": "#{THEME_IMAGE}",
          "theme_toolbar": "#{THEME_IMAGE2}",
          "theme_ntp_background": "#{THEME_IMAGE2}",
          "theme_tab_background": "#{THEME_IMAGE3}",
          "theme_tab_background_incognito": "#{THEME_IMAGE3}"
        },
        "colors": {
          "frame": [32, 33, 36],
          "frame_inactive": [60, 64, 67],
          "frame_incognito": [32, 33, 36],
          "frame_incognito_inactive": [60, 64, 67],
          "toolbar": [50, 54, 57],
          "tab_text": [241, 243, 244],
          "tab_background_text": [189, 193, 198],
          "tab_background_text_incognito": [189, 193, 198],
          "tab_background_text_inactive": [168, 171, 175],
          "tab_background_text_incognito_inactive": [168, 171, 175],
          "bookmark_text": [241, 243, 244],
          "ntp_background": [50, 54, 57],
          "ntp_text": [255, 255, 255],
          "omnibox_background": [32, 33, 36],
          "omnibox_text": [255, 255, 255]
		    },
        "tints": {
          "frame":                    [hue, hue == 0 ? 0 : -1.0, -1.0],
          "frame_inactive":           [hue, hue == 0 ? 0 : -1.0, 0.7],
          "frame_incognito":          [hue, hue == 0 ? 0 : -1.0, -1.0],
          "frame_incognito_inactive": [hue, hue == 0 ? 0 : -1.0, 0.7],
          "buttons": [-1, -1, 0.96]
        },
        "properties": {
			    "ntp_logo_alternate": 1,
			    "ntp_background_repeat": "repeat"
		    }
      }
    }))

    FileUtils.cp(THEME_IMAGE_PATH, temp_dir)
    FileUtils.cp(THEME_IMAGE_PATH2, temp_dir)
    FileUtils.cp(THEME_IMAGE_PATH3, temp_dir)
    build_extension(options, temp_dir, "#{THEME_OUTPUT_PATH}/#{color_name}.crx")
  end
end

# Build extensions
exts = ['autochrome_junk_drawer', 'settingsreset']
exts.each do |ext|
  build_extension(options, "#{EXT_SOURCE_DIR}/#{ext}", "#{EXT_OUTPUT_DIR}/#{ext}.crx")
end

