# LiveCam

Live(-ish) streaming app for use with RTMP streaming servers like NGINX's rtmp-module or Periscope. Completely based on [LFLiveKit](https://github.com/LaiFengiOS/LFLiveKit) but modernized to XCode 10 and without GPUImage, instead using CIFilter and the Metal-Framework. Features muting, front/back camera, and a filter to pixelate faces in the stream (but not in the preview).

[![Build Status](https://travis-ci.org/mdelete/LiveCam.svg?branch=master)](https://travis-ci.org/mdelete/LiveCam)

***Disclaimer: Pixelation is not perfect. It may or may not work. If streaming could violate rights and/or the privacy of people, don't!***

Configuration
-------------
Edit property **LCServerURL** in **Info.plist** to set a default stream *or* long-press the record button for a configuration dialog.

TODOs
-----

 * Better error handling
 * Maybe replace [pili-librtmp](https://github.com/pili-engineering/pili-librtmp) with [srs-librtmp](https://github.com/ossrs/srs-librtmp/tree/master/src/srs)

Links
-----

 * https://developer.apple.com/documentation/coreimage/cifilter/filter_parameter_keys?language=objc
 * https://github.com/arut/nginx-rtmp-module

License
-------
The code in this repository is published under the terms of the **MIT** License. See the **LICENSE** file for the complete license text.