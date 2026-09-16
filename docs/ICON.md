# Paper pal

Scratchpad's Dock icon is a little stack of sticky notes: butter-yellow paper, a turned corner, and a hand-drawn smile, with a lilac sheet behind it. The indigo background and large simple shapes keep it legible at Dock size.

![Scratchpad icon](artwork/scratchpad-icon.png)

The editable source is `Scratchpad/Scratchpad.icon`, a native Icon Composer document with four original SVG layers. All artwork is vector paths; no fonts, stock art, or raster source images are needed. The icon mask, lighting, edge highlights, and shadows come from Icon Composer.

- **Paper pal:** the doodle, turned corner, and front sheet share a group so they move as one surface. Ink has glass effects disabled and a dark-appearance Fill override of None to preserve its original color.
- **Spare sheet:** a separate group provides depth behind the front note.
- Layers and groups in `icon.json` are ordered front to back. The artwork uses a shared 1024 × 1024 canvas.
- Default, dark, and monochrome/clear appearances are handled by the native renderer. The background becomes dark while the yellow note stays recognizable.

Open the `.icon` document in Icon Composer to edit materials or inspect appearances. The Xcode app icon build setting is `Scratchpad`, matching the document name. Xcode compiles it into the app's asset catalog and generates the macOS icon resources.

Run `./scripts/preview-icon.sh` to export the native appearance previews and a 64-pixel Dock-size preview into `build/IconPreviews`. This uses `ictool` bundled with the selected Xcode. Then run `./scripts/install.sh` to install the updated release.

Apple's [Icon Composer guide](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) describes the layered SVG workflow and Xcode integration.
