# ![icon30](https://github.com/user-attachments/assets/ea370d0a-bd76-4ab5-91bb-e9ea5da83b87) ARay Viewer
Simple image viewer application built on Flutter

Usage example:

https://github.com/user-attachments/assets/14ed2f36-bdcf-4a85-b2b1-871d87fdc730

https://github.com/user-attachments/assets/d4dbc438-3800-4b5e-a63e-607f8b25b746

Comparison with the standard Windows Photo Viewer application:

PROS:
- Shows the current and total number of images at the top when scrolling through
- Ability to jump 5/10 images with Ctrl/Shift modifier keys + arrow keys
- Ability to jump from the last image to the first
- Don't lose fit mode when scrolling through images in both directions (they remain stretched)
- Ability to move to the next image without zooming out with the **anchor** feature.
- Smoother arrow keys scrolling

CONS:
- A lot fewer features, no slide show, no rotation, no share, no copilot, etc...
- Worse performance, due to heavy caching
- Sometimes, when opening multiple instances of the application, old instances start to use lots of memory. (Not sure what is going on there)
- Don't handle images being removed or renamed.

Possible improvements: 
- Create settings menu for: scroll speed (arrows), zoom speed, cache size, etc...
- Add Slideshow feature
- Add image info (resolution, file size) display
- Add image strip feature
- Fix memory usage issue if opening multiple windows
- Fix scroll wheel not working while hovering over top/bottom bars
