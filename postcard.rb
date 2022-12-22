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
    card_filename = args.first.to_s if args.is_a?(Array)
    if !card_filename.is_a?(String) || card_filename.empty?
      puts "Please pass one argument (#{args.size} were received):\n"\
           "The file name of the smaller image to be inserted in the postcard\n\n"\
           "If the file name include spaces, include them in quotes.\n\n"
      exit(1)
    elsif !File.file?(card_filename)
      # The file exists:
      puts "The given file '#{card_filename}' does not exist."
      exit(1)
    end
    # This could be an argument or config data, in a YAML file, or a
    #   set of global constants:
    # ---
    @dpi = 1_200
    #   Maybe from the size of the page (inches), for a given resolution (DPI):
    @page_dimensions = [ 10_200, 13_200 ]
    @half_page = 13_200 / 2                # Calculated from the page's dimensions
    @text = '(untitled)               Pencil on newspaper                '\
            'https://my_art_site.example.com/untitled_artwork.html'
    # ---
    # Image dimensions check:
    if verbose
      puts "Source artwork file: '#{card_filename}'"
      puts
      puts 'Calculating the dimension of the image...'
    end
    @card_image = MiniMagick::Image.open(card_filename)
    @card_dimensions = @card_image.dimensions
    if verbose
      puts '  Dimensions:'
      puts "    Postcard:  #{@card_dimensions.join(' x ')} pixels"
      puts "    Page:      #{@page_dimensions.join(' x ')} pixels"
      half_page_dimensions = [ @page_dimensions.first, @half_page ]
      puts "    Half page: #{half_page_dimensions.join(' x ')} pixels"
    end
    if (@card_dimensions <=> [ @page_dimensions.first, @half_page ]) != -1
      puts 'The postcard needs to fit within the page'
      exit(1)
    else
      puts('  The postcard fits') if verbose
    end
    # Image opacity check:
    if @card_image['%[opaque]'] != 'True'
      puts "The source image '#{card_filename}' should be opaque."
      exit(1)
    end
  end

  def do_it!(verbose: true)
    # 1. Rotate the artwork upside down:
    result_filename1 = new_filename_from('1.artwork_upsidedown.png')
    rotate_image @card_image, angle: '180', new_filename: result_filename1
    # 2. White image with text:
    result_filename2 = new_filename_from('2.white_page.png', new_extension: '.png')
    new_image = new_white_image_with_text(new_filename: result_filename2,
                                          dimensions: @page_dimensions, dpi: @dpi,\
                                          text: @text, verbose: verbose)
    if new_image.nil?
      puts 'Unable to create the white image page where to add the card to'
      exit(1)
    end
    # 3. One image over another:
    result_filename3 = new_filename_from('3.images_merged.png')
    #   The dimensions for the card should not have been changed:
    new_image = images_merge(new_image, @card_image, @card_dimensions,
                             @page_dimensions.first, @half_page,
                             new_filename: result_filename3, verbose: verbose)
    # 4. Rotate the image sideways (landscape):
    result_filename4 = new_filename_from('4.rotated_landscape.png')
    rotate_image new_image, angle: '-90', new_filename: result_filename4
    # 5. Copy of the file as PDF:
    result_filename5 = new_filename_from('5.final_pdf_result.pdf')
    transform_to_pdf(new_image, new_filename: result_filename5)
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

  # Returns either nil, if something goes wrong, or an Image
  def new_white_image_with_text(dimensions: [ 10_200, 13_200 ], dpi: 1_200, text: nil, new_filename: nil, verbose: true)
    puts if verbose
    # Sanity checks:
    unless (dimensions.is_a?(Array) && (dimensions.size == 2) &&
            (dimensions == dimensions.collect{|d| d.to_s.to_i}))
      puts('Page dimensions not valid.') if verbose
      return
    end
    if (dpi != dpi.to_s.to_i) || (dpi <= 0)
      puts ('dpi should be a positive integer.') if verbose
      return
    end
    unless new_filename
      puts ('A new file name should be provided') if verbose
      return
    end
    # Create image:
    if verbose
      puts 'Creating a new white image with text.'
      puts "  Dimensions: #{dimensions.join('x')}"
      puts "  Resolution: #{dpi} Pixels/inch"
      puts '  Text:       Arial 6pt.'
      puts "  New filename: '#{new_filename}'"
      puts '  ...'
    end
    # Magimagick convert command:
    MiniMagick::Tool::Convert.new do |command|
      command.size("#{dimensions.join('x')}")
      command << 'canvas:white'
      command.units 'pixelsperinch'
      command.density(dpi)
      if text.is_a?(String) && !text.empty?
        command.font('Arial')
        command.pointsize(6)
        command.gravity('SouthEast')
        command.annotate('+800+600')  # Bottom and right margins
        command << "#{text}"
      end
      # ColorSpace sRGB, instead of Gray:
      command << "PNG24:#{new_filename}"
    end
    MiniMagick::Image.open(new_filename)
  end

  def images_merge(large_image, small_image, small_dimensions, page_width,
                   half_page_size, new_filename: nil, verbose: true)
    left_margin  = (page_width - small_dimensions.first) / 2
    upper_margin = (half_page_size - small_dimensions.last) / 2
    if verbose
      puts
      puts "The card will be copied into the page, starting at the point "\
           "[#{left_margin}, #{upper_margin}] from the upper left corner"
      puts '  Composing the result image in memory...'
    end
    result_image = large_image.composite(small_image) do |c|
      c.compose 'Over'                              # OverCompositeOp
      c.geometry "+#{left_margin}+#{upper_margin}"  # Copy from this point
    end
    if new_filename
      puts("  Saving the image as '#{new_filename}'...") if verbose
      result_image.write new_filename
    end
    result_image
  end

  # Some images, in particular PDFs with text get the text distorted when rotating.
  #   It seems to work better with a PNGs.
  def rotate_image(image, angle: '0', new_filename: nil, verbose: true)
    if verbose
      puts
      puts "Rotating the image #{angle} degrees..."
    end
    image.combine_options{ |opt| opt.rotate angle }
    if new_filename
      puts("  Saving the image as '#{new_filename}'...") if verbose
      image.write new_filename
    end
  end

  def transform_to_pdf(image, new_filename: nil, verbose: true)
    if verbose
      puts
      puts 'Changing the image format to PDF...'
    end
    unless new_filename
      puts ('A new PDF file name should be provided') if verbose
      return
    end
    image.format 'pdf'
    puts("  Saving the image as '#{new_filename}'...") if verbose
    image.write new_filename
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

puts
puts 'Bye!'
puts
