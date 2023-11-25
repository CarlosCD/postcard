## Postcard
![GitHub top language](https://img.shields.io/github/languages/top/CarlosCD/postcard?color=red&style=plastic)
![GitHub](https://img.shields.io/github/license/CarlosCD/postcard?style=plastic)

Simple Ruby program to compose holiday cards, ready to print, given a digital image.

It requires ImageMagick, which in macOS it can be installed with
[Homebrew](https://brew.sh):

    brew install imagemagick

Special options:

    -g  Generates a YAML configuration file and exits (no postcard generated).
        The file can be used to set the text to be printed or the page size.

    -v  Verbose mode

Usage examples:

    ./postcard.rb -g

    ./postcard.rb sample/artwork.png

    ./postcard.rb -v sample/artwork.png

November 2023
