#!/usr/bin/env ruby
# frozen_string_literal: true

class Postcard
  def self.do_it!(args, verbose: true)
    postcard = self.new(args, verbose: verbose)
    postcard.do_it!(verbose: verbose)
  end

  def initialize(args = nil, verbose: true)
    install_gems_and_require 'mini_magick'
    # Read and verify arguments:
    args = [] unless args.is_a?(Array)
    args = args.first(3).compact.collect(&:to_s)
    if args.size < 2
      puts "Please pass at least two arguments (#{args.size} were received):\n"\
           "  1. The file name of a large image where the postcard will be added to "\
           "(white page)\n"\
           "  2. The file name of smaller image to be inserted in the first file "\
           "(postcard)\n\n"\
           "  3. Optionally, the resulting file (if none passed a new file will be "\
           "created)\n\n"\
           "If the file names include spaces, include them in quotes.\n\n"
      exit(1)
    end
    # Source files exist:
    page_filename, card_filename, result_filename = args
    [ page_filename, card_filename ].each do |file|
      unless File.file?(file)
        puts "'#{file}' is not an existing file."
        exit(1)
      end
    end
    # Resulting image filename:
    if result_filename.is_a?(String)
      if File.file?(result_filename)
        puts 'The result file needs to be non-existing (just in case, to avoid '\
             'overwriting existing files)'
        exit(1)
      end
    else
      result_filename = ''
    end
    result_filename = new_filename_from(card_filename) if result_filename.empty?
    # Image dimensions check:
    if verbose
      puts "Result file: '#{result_filename}'"
      puts
      puts "Page large file:     '#{page_filename}'"
      puts "Postcard image file: '#{card_filename}'"
      puts
      puts 'Calculating the dimension of the images...'
    end
    page_image = MiniMagick::Image.open(page_filename)
    card_image = MiniMagick::Image.open(card_filename)
    page_dimensions = page_image.dimensions
    half_page = page_dimensions.last / 2
    card_dimensions = card_image.dimensions
    if verbose
      puts 'Dimensions'
      puts "  Page:      #{page_dimensions.join(' x ')} pixels"
      half_page_dimensions = [ page_dimensions.first, half_page ]
      puts "  Half page: #{half_page_dimensions.join(' x ')} pixels"
      puts "  Postcard:  #{card_dimensions.join(' x ')} pixels"
    end
    if (card_dimensions <=> [ page_dimensions.first, half_page ]) != -1
      puts 'The postcard needs to fit within the page'
      exit(1)
    else
      puts('  The postcard fits') if verbose
    end
    # Images opacity check:
    { page_filename => page_image , card_filename => card_image }.each do |filename, img|
      if img['%[opaque]'] != 'True'
        puts "The source images '#{filename}' should be opaque."
        exit(1)
      end
    end
    # One image over another:
    left_margin  = (page_dimensions.first - card_dimensions.first) / 2
    upper_margin = (half_page - card_dimensions.last) / 2
    if verbose
      puts "The card will be copied into the page, starting at the point "\
           "(#{left_margin}, #{upper_margin}) from the upper left corner"
      puts
      puts 'Composing the result image in memory...'
    end
    result_image = page_image.composite(card_image) do |c|
      c.compose 'Over'                              # OverCompositeOp
      c.geometry "+#{left_margin}+#{upper_margin}"  # Copy from this point
    end
    puts('Writing into the new file...') if verbose
    result_image.write result_filename
  end

  def do_it!(verbose: true)
  end

  private

  def install_gems_and_require(gem_name, verbose: true)
    begin
      Gem::Specification.find_by_name(gem_name)
    rescue Gem::MissingSpecError
      puts("Installing the '#{gem_name}' Ruby gem...") if verbose
      system "gem install #{gem_name}"
    end
    require gem_name
  end

  # -- Utility methods (functions):

  def new_filename_from(filename)
    if filename.nil? || filename.empty?
      puts 'No file name given, making up one'
      prefix = 'new_result_file'
      extension = ''
    else
      prefix = filename
      extension = File.extname (prefix)
      unless extension.empty?
        extension = ".#{extension}" if !extension.start_with?('.')  # Windooze?
        prefix = prefix.delete_suffix extension
      end
    end
    result_filename = "#{prefix}#{extension}"
    num = 0
    while File.file?(result_filename)
      num += 1
      result_filename = "#{prefix}_#{num}#{extension}"
    end
    result_filename
  end
end

Postcard.do_it!(ARGV)

puts 'Bye!'
puts
