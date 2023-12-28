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

    ---
    dpi: 1200
    units: inches
    page_width: 11
    page_height: 8.5
    text: "(untitled)               Pencil on newspaper                https://my_art_site.example.com/untitled_artwork.html"
    result_file: 5.postcard-final.pdf

Postcard generation, non verbose, using the `postcard.yml` above:

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