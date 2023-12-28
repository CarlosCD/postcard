#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

class Postcard
  class << self
    def do_it!(args)
      verbose = !args.delete('-v').nil?
      if args.delete('-g').nil?
        config_hash = read_configuration(verbose: verbose)
        card_filename = args.first.to_s if args.is_a?(Array)
        postcard = new(card_filename, config: config_hash, verbose: verbose)
        postcard.do_it!(verbose: verbose)
      else
        if File.file?(CONFIG_FILENAME)
          puts "A file called '#{CONFIG_FILENAME}' already exists, "\
               "please rename it if you want to generate a new one."
        else
          generate_config_yaml
        end
      end
    end

    private

    CONFIG_FILENAME = 'postcard.yml'
    DEFAULT_CONFIG = { 'dpi'          => 1_200,
                       'units'        => 'inches',
                       'page_width'   => 11,
                       'page_height'  => 8.5,
                       'text'         => '',
                       'result_file'  => 'postcard.pdf' }

    def generate_config_yaml
      puts "Generating a new configuration file '#{CONFIG_FILENAME}'..."
      help_prefix = <<~NOTES
      # Configuration options:
      #   dpi:          Image resolution, for printing, in pixels (dots) per unit given (dots per inch, for example).  Default: 1200
      #   units:        Either "centimeters", or "inches" (case-insensitive).     c                                    Default: inches
      #   page_width:   Final page width, in the units used (11 for the US Letter format, 8.5x11 inches, landscape).   Default: 11
      #   page_height:  Final page height in the units used.                                                           Default: 8.5
      #   text:         Text to be used in the back of the postcard (one line, describing the image).                  No default (no text)
      #   result_file:  Name of the result file, PDF format. If it exists it will use a different name.                Default: postcard.pdf
      #
      NOTES
      helping_config = DEFAULT_CONFIG
      # Only to generate the file, but the default text is empty...
      helping_config['text'] = '(untitled)               Pencil on newspaper                '\
                              'https://my_art_site.example.com/untitled_artwork.html'
      full_file_content = help_prefix + helping_config.to_yaml
      File.open(CONFIG_FILENAME, 'w') {|f| f.write full_file_content }
      puts 'Done.'
    end

    def read_configuration(verbose: false)
      config_hash = {}
      if File.file?(CONFIG_FILENAME)
        puts "A configuration YAML file ('#{CONFIG_FILENAME}') exists, using it..."
        yaml_content = File.read(CONFIG_FILENAME)
        yaml_hash = YAML.safe_load(yaml_content, symbolize_names: true)
        if yaml_hash.is_a?(Hash)
          yaml_hash.each do |k,v|
            if %i(dpi page_width page_height).include?(k)
              if v.is_a?(Numeric)
                config_hash[k] = v
              else
                puts "The value for #{k} should be Numeric. We will ignore it and use a default."
              end
            elsif %i(result_file units text).include?(k)
              if v.is_a?(String) && (v.size > 0) && (k != :units || %w(centimeters inches).include?(v))
                config_hash[k] = v
              else
                puts "The value for #{k} is not a valid String. We will ignore it and use a default."
              end
            else
              puts "YAML element '#{k}' is not valid. We will ignore it and use a default."
            end
          end
        end
        (DEFAULT_CONFIG.keys.collect(&:to_sym) - config_hash.keys).each do |k|
          v = DEFAULT_CONFIG[k.to_s]
          config_hash[k] = v
          puts "'#{k}' was missing in the configuration YAML file. It will be set as '#{v}'"
        end
      end
      keys_with_values_keys = config_hash.keys.collect(&:to_s)
      (DEFAULT_CONFIG.keys - keys_with_values_keys).each do |k|
        config_hash[k.to_sym] ||= DEFAULT_CONFIG[k]
      end
      if verbose
        puts 'Configuration to be used:'
        config_hash.each do |k,v|
          val = v.is_a?(String) ? "'#{v}'" : v
          puts "#{k}:".ljust(14) + "#{val}"
        end
        puts
      end
      config_hash
    end
  end

  def initialize(card_filename = nil, config: {}, verbose: false)
    # Read and verify card_filename:
    if !card_filename.is_a?(String) || card_filename.empty?
      puts "Please pass as an argument the file name of the image to be inserted in the postcard.\n\n"\
           "If the file name include spaces, put the name in quotation marks.\n\n"
      exit(1)
    elsif !File.file?(card_filename)
      # The file exists:
      puts "The file '#{card_filename}' does not exist."
      exit(1)
    end
    puts 'Source artwork file:'.ljust(28) + "'#{card_filename}'"
    puts
    # Configuration:
    # ---
    @dpi = config[:dpi] || 1_200
    page_width  = config[:page_width] || 11
    page_height = config[:page_height] || 8.5
    page_units = config[:units] || 'inches'
    @text = config[:text] || ''  # Defaults to no text
    @postcard_result_file = config[:result_file] || 'postcard.pdf'
    # ---
    # Derived configuration calculations:
    # ---
    # Transforms into inches (as we use DPI):
    units_scale = (page_units.to_s.downcase == 'centimeters') ? 2.54 : 1
    page_width_inches  = page_width  / units_scale
    page_height_inches = page_height / units_scale
    # Portrait orientation, 8.5x11 inches => [10_200, 13_200] pixels
    @page_dimensions = [ (page_height_inches*@dpi).to_i, (page_width_inches*@dpi).to_i ]
    @half_page = @page_dimensions.last / 2  # 13_200 / 2
    # ---
    # Dependencies:
    install_gems_and_require 'mini_magick'
    # Image dimensions check:
    puts('Calculating the dimension of the image...') if verbose
    @card_image = MiniMagick::Image.open(card_filename)
    card_dimensions = @card_image.dimensions
    @half_page_dimensions = [ @page_dimensions.first, @half_page ]
    if verbose
      puts '  Dimensions:'
      puts "    Full page:      #{@page_dimensions.join(' x ')} pixels"
      puts "    Half page:      #{@half_page_dimensions.join(' x ')} pixels"
      puts "    Postcard image: #{card_dimensions.join(' x ')} pixels, "\
           "#{@card_image.resolution.uniq.join('x')} dpi"
    end
    if (card_dimensions.first <= 0) || (card_dimensions.last <= 0) ||
       (@half_page_dimensions.first <= 0) || (@half_page_dimensions.last <= 0)
      puts 'Error: the postcard needs to fit within the page'
      exit(1)
    end
    # Image opacity check:
    if @card_image['%[opaque]'] != 'True'
      puts "The source image '#{card_filename}' should be opaque (no transparencies/alpha channel)."
      exit(1)
    end
  end

  def do_it!(verbose: false)
    # 0. Resize only if too large, and adjust dpi:
    result_filename0 = new_filename_from('0.artwork_resized.png')
    margin_pixels = (0.5*@dpi).to_i  # 0.5 inches => 600 pixels at 1,200 dpi
    dimension_with_margins = @half_page_dimensions.collect{|s| s - margin_pixels}
    resize_and_dpi_if_larger(@card_image, new_filename: result_filename0,
                             dimensions: dimension_with_margins, dpi: @dpi, verbose: verbose)
    # 1. Rotate the artwork upside down:
    result_filename1 = new_filename_from('1.artwork_upsidedown.png')
    rotate_image @card_image, angle: '180', new_filename: result_filename1, message_detail: 'Image rotated', verbose: verbose
    # 2. White image with the text:
    result_filename2 = new_filename_from('2.white_page.png', new_extension: '.png')
    new_image = new_white_image_with_text(new_filename: result_filename2,
                                          dimensions: @page_dimensions, dpi: @dpi,
                                          text: @text, verbose: verbose)
    if new_image.nil?
      puts 'Unable to create the white image page where to add the card to'
      exit(1)
    end
    puts '=> White image with text as'.ljust(28) + "'#{result_filename2}'"
    # 3. Merge one image over the other:
    result_filename3 = new_filename_from('3.images_merged.png')
    new_image = images_merge(new_image, @card_image, @card_image.dimensions,
                             @page_dimensions.first, @half_page,
                             new_filename: result_filename3, verbose: verbose)
    # 4. Rotate the image sideways (landscape orientation):
    result_filename4 = new_filename_from('4.rotated_landscape.png')
    rotate_image new_image, angle: '-90', new_filename: result_filename4, message_detail: 'Landcape image', verbose: verbose
    # 5. Copy of the file as PDF:
    result_filename5 = new_filename_from(@postcard_result_file, new_extension: '.pdf')
    transform_to_pdf(new_image, new_filename: result_filename5, verbose: verbose)
    puts '=> Final PDF file, as'.ljust(28) + "'#{result_filename5}'"
  end

  private

  def install_gems_and_require(gem_name)
    begin
      Gem::Specification.find_by_name(gem_name)
    rescue Gem::MissingSpecError
      puts "Installing the '#{gem_name}' Ruby gem..."
      system "gem install #{gem_name}"
    end
    require gem_name
  end

  # -- Image manipulations:

  def resize_and_dpi_if_larger(image, new_filename: nil, dimensions: [ 9_600, 6_000 ], dpi: 1_200,
                               verbose: false)
    # Sanity checks:
    unless (dimensions.is_a?(Array) && (dimensions.size == 2) &&
            (dimensions == dimensions.collect{|d| d.to_s.to_i}))
      puts('Image dimensions not valid.') if verbose
      return
    end
    if (dpi != dpi.to_s.to_i) || (dpi <= 0)
      puts ('dpi should be a positive integer.') if verbose
      return
    end
    # Has to be adjusted?
    image_resolution = image.resolution.uniq
    resolution_needs_changes = (image_resolution.size > 1) || (image_resolution.first != dpi)
    resize_needed = (image.dimensions.first > dimensions.first) ||
                    (image.dimensions.last > dimensions.last)
    if resolution_needs_changes || resize_needed
      image.resize(dimensions.join('x')) if resize_needed
      image.density(dpi) if resolution_needs_changes
      puts("  Original image changed to #{image.dimensions.join('x')} pixels and #{dpi} dpi") if verbose
      if new_filename
        puts("  Saving the image...\n\n") if verbose
        image.write new_filename
        puts '=> Image resized, as'.ljust(28) + "'#{new_filename}'"
      end
    end
  end

  # Some images, in particular PDFs with text get the text distorted when rotating.
  #   It seems to work better with a PNGs.
  def rotate_image(image, angle: '0', new_filename: nil, message_detail: nil, verbose: false)
    if verbose
      puts
      puts "  Rotating the image #{angle} degrees..."
    end
    image.combine_options{ |opt| opt.rotate angle }
    if new_filename
      puts("  Saving the image...\n\n") if verbose
      image.write new_filename
      puts "=> #{message_detail} as".ljust(28) + "'#{new_filename}'"
    end
  end

  # Returns either nil, if something goes wrong, or an Image
  def new_white_image_with_text(dimensions: [ 10_200, 13_200 ], dpi: 1_200, text: nil, new_filename: nil,
                                verbose: false)
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
      puts '  Creating a new white image with text.'
      puts "  Dimensions: #{dimensions.join('x')}"
      puts "  Resolution: #{dpi} Pixels/inch"
      puts "  Text: '#{text}'"
      puts '  Text font: Arial 6pt.'
      puts '  ...'
      puts
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
                   half_page_size, new_filename: nil, verbose: false)
    left_margin  = (page_width - small_dimensions.first) / 2
    upper_margin = (half_page_size - small_dimensions.last) / 2
    if verbose
      puts
      puts "  The card will be copied into the page, starting at the point "\
           "[#{left_margin}, #{upper_margin}] from the upper left corner"
      puts '  Composing the result image in memory...'
    end
    result_image = large_image.composite(small_image) do |c|
      c.compose 'Over'                              # OverCompositeOp
      c.geometry "+#{left_margin}+#{upper_margin}"  # Copy from this point
    end
    if new_filename
      puts("  Saving the image...\n\n") if verbose
      result_image.write new_filename
      puts '=> Image files merged as'.ljust(28) + "'#{new_filename}'"
    end
    result_image
  end

  def transform_to_pdf(image, new_filename: nil, verbose: false)
    if verbose
      puts
      puts '  Changing the image format to PDF...'
    end
    unless new_filename
      puts ('A new PDF file name should be provided') if verbose
      return
    end
    image.format 'pdf'
    puts("  Saving the image...\n\n") if verbose
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
puts 'All done. Bye!'
puts
