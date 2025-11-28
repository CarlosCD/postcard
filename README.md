## Postcard
![GitHub top language](https://img.shields.io/github/languages/top/CarlosCD/postcard?color=red&style=plastic)
![GitHub](https://img.shields.io/github/license/CarlosCD/postcard?style=plastic)

Simple Ruby program to compose holiday cards, ready to print, given a digital image.

The intent is not to modify the original image file, but to create a `new` PDF file with the result.

### Installation and options

You need Ruby, which usually comes pre-installed in macOS and Linux. Better if you use one of the last
versions (tested up to version 3.4.7).

It requires ImageMagick, which in macOS it can be installed with [Homebrew](https://brew.sh):

    brew install imagemagick

The minimum is to download the files:

    postcard.rb
    Gemfile
    Gemfile.lock

The rest can be generated from running that program.

After downloading it, run this command once to install a couple of dependencies (Ruby gems):

    bundle

Also find the image file you want to use for your postcards.

Special commad-line options:

    -g  Generates a YAML configuration file (`postcard.yml`) and exits (no postcard images generated).
        The file can be used to set several options, like the text to be printed or the target page size

    -v  Verbose mode. It could be a bit technical. It gives some details for each of the operations performed.

### A few examples

At a Terminal window:

    ./postcard.rb -g

    ./postcard.rb

    ./postcard.rb "My Art Work.png"

    ./postcard.rb -v 0.artwork_large_sample.png

Some examples of output can be seen in the [doc/usage_examples.md](doc/usage_examples.md) file.

November 2025
