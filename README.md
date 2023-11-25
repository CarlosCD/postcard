## Postcard
![GitHub top language](https://img.shields.io/github/languages/top/CarlosCD/postcard?color=red&style=plastic)
![GitHub](https://img.shields.io/github/license/CarlosCD/postcard?style=plastic)

Simple Ruby program to compose holiday cards, ready to print, given a digital image.

It requires ImageMagick, which in macOS it can be installed with
[Homebrew](https://brew.sh):

    brew install imagemagick

Simple example of usage (with a sample image file):

    ./postcard.rb sample/artwork.png

Special options:

    -v  Verbose mode

Example:

    ./postcard.rb -v sample/artwork.png

November 2023
