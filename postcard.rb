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
    args = args.first(2).compact.collect(&:to_s)
    if args.size != 2
      puts "Please pass at least two arguments (#{args.size} were received):\n"\
           "  1. The file name of a large image where the postcard will be added to "\
           "(white page)\n"\
           "  2. The file name of smaller image to be inserted in the first file "\
           "(postcard)\n\n"\
           "If the file names include spaces, include them in quotes.\n\n"
      exit(1)
    end
    # Source files exist:
    page_filename, card_filename = args
    [ page_filename, card_filename ].each do |file|
      unless File.file?(file)
        puts "'#{file}' is not an existing file."
        exit(1)
      end
    end
    # Image dimensions check:
    if verbose
      puts
      puts "Page large file:     '#{page_filename}'"
      puts "Postcard image file: '#{card_filename}'"
      puts
      puts 'Calculating the dimension of the images...'
    end
    @page_image = MiniMagick::Image.open(page_filename)
    @card_image = MiniMagick::Image.open(card_filename)
    @page_dimensions = @page_image.dimensions
    @half_page = @page_dimensions.last / 2
    @card_dimensions = @card_image.dimensions
    if verbose
      puts 'Dimensions'
      puts "  Page:      #{@page_dimensions.join(' x ')} pixels"
      half_page_dimensions = [ @page_dimensions.first, @half_page ]
      puts "  Half page: #{half_page_dimensions.join(' x ')} pixels"
      puts "  Postcard:  #{@card_dimensions.join(' x ')} pixels"
    end
    if (@card_dimensions <=> [ @page_dimensions.first, @half_page ]) != -1
      puts 'The postcard needs to fit within the page'
      exit(1)
    else
      puts('  The postcard fits') if verbose
    end
    # Images opacity check:
    { page_filename => @page_image , card_filename => @card_image }.each do |filename, img|
      if img['%[opaque]'] != 'True'
        puts "The source images '#{filename}' should be opaque."
        exit(1)
      end
    end
  end

  def do_it!(verbose: true)
    # 1. One image over another:
    result_filename1 = new_filename_from('result_file.png')
    result_image = images_merge(@page_image, @card_image, @card_dimensions,
                                @page_dimensions.first, @half_page,
                                result_filename1, verbose: verbose)
    # 2. Rotate the image sideways (landscape):
    result_filename2 = new_filename_from(result_filename1,suffix: '-Rotated')
    rotate_image(result_image, result_filename2)
    # 3. Copy of the file as PDF:
    result_filename3 = new_filename_from(result_filename2, new_extension: '.pdf', suffix: '-Final')
    transform_to_pdf(result_image, result_filename3)
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

  # -- Image manipulations:

  def images_merge(large_image, small_image, small_dimensions, page_width,
                   half_page_size, result_filename, verbose: true)
    left_margin  = (page_width - small_dimensions.first) / 2
    upper_margin = (half_page_size - small_dimensions.last) / 2
    if verbose
      puts "The card will be copied into the page, starting at the point "\
           "(#{left_margin}, #{upper_margin}) from the upper left corner"
      puts
      puts 'Composing the result image in memory...'
    end
    result_image = large_image.composite(small_image) do |c|
      c.compose 'Over'                              # OverCompositeOp
      c.geometry "+#{left_margin}+#{upper_margin}"  # Copy from this point
    end
    puts('Writing into the new file...') if verbose
    result_image.write result_filename
    result_image
  end

  # Some images, in particular PDFs with text get the text distorted when rotating.
  #   It seems to work better with a PNGs.
  def rotate_image(image, new_filename, verbose: true)
    puts('Rotating the image -90 degrees...') if verbose
    image.combine_options{ |opt| opt.rotate '-90' }
    puts("Saving the image as '#{new_filename}'...") if verbose
    image.write new_filename
  end

  def transform_to_pdf(image, pdf_filename, verbose: true)
    puts('Changing the image format to PDF...') if verbose
    image.format 'pdf'
    puts("Saving the image as '#{pdf_filename}'...") if verbose
    image.write pdf_filename
  end

  # -- Utility methods (functions):

  def new_filename_from(filename, new_extension: nil, suffix: nil)
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
    if suffix.is_a?(String) && !suffix.empty?
      prefix += suffix
    end
    if new_extension.is_a?(String) && !new_extension.empty?
      extension = new_extension
      extension = ".#{extension}" if !new_extension.start_with?('.') 
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
