# Zixel

A simple sixel library and CLI application for zig.

## Overview

`Zixel` enables the display of images directly in terminals that support the `sixel` format. It takes an input image, converts it to the `sixel` format, and displays the result.

## Limitations

* Not all image formats are supported.
* Image data is imported using the `zigimg` library, so only formats supported by `zigimg` can be processed. If conversion fails, consider converting the image to `PNG` format before using `Zixel`.

## Usage: CLI

```
Usage: ./zixel [options]
Generate sixel from input image

Options:
  -i, --image IMAGE     Set input image to IMAGE
  -x, --width WIDTH     Set output sixel image width to WIDTH (default: 200)
  -y, --height HEIGHT   Set output sixel image height to HEIGHT (default: 200)
  -c, --colors NUM      Set the number of colors to NUM (default: 256)
  -h, --help            Show this help and exit
```

## Restoring dependency

`Zixel` relies on the `zigimg` library. The compatible version is preconfigured in the `build.zig.zon` file. In case you need to fetch the dependency again, run the following command:

```
zig fetch --save https://github.com/zigimg/zigimg/archive/cbb0c64caffd5b02863aadd62bab48cef7f86ceb.tar.gz
```
