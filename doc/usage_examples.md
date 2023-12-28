## Postcard

### Examples of output

`Please note that if the program has changed since the date at the bottom of this document,
there could be some differences in the output shown here.`

Creating a default `postcard.yml` file, if it is not there:

    ./postcard.rb -g
      Generating a new configuration file 'postcard.yml'...
      Done.

      All done. Bye!

The file generated has this text (edit it to set your preferences):

    # Configuration options:
    #   dpi:          Image resolution, for printing, in pixels (dots) per unit given (dots per inch, for example).  Default: 1200
    #   units:        Either "centimeters", or "inches" (case-insensitive).     c                                    Default: inches
    #   page_width:   Final page width, in the units used (11 for the US Letter format, 8.5x11 inches, landscape).   Default: 11
    #   page_height:  Final page height in the units used.                                                           Default: 8.5
    #   text:         Text to be used in the back of the postcard (one line, describing the image).                  No default (no text)
    #   result_file:  Name of the result file, PDF format. If it exists it will use a different name.                Default: postcard.pdf
    #
    ---
    dpi: 1200
    units: inches
    page_width: 11
    page_height: 8.5
    text: "(untitled)               Pencil on newspaper                https://my_art_site.example.com/untitled_artwork.html"
    result_file: postcard.pdf

Postcard generation, non verbose, using the provided sample `postcard.yml` configuration, not the one above:

    ./postcard.rb 0.artwork_large_sample.png
      A configuration YAML file ('postcard.yml') exists, using it...
      Source artwork file:        '0.artwork_large_sample.png'

      => Image resized, as        '0.artwork_resized.png'
      => Image rotated as         '1.artwork_upsidedown.png'
      => White image with text as '2.white_page.png'
      => Image files merged as    '3.images_merged.png'
      => Landcape image as        '4.rotated_landscape.png'
      => Final PDF file, as       '5.postcard-final.pdf'

      All done. Bye!

December 2023
