# Trianglizer

Convert pixel art into **triangle-based vector graphics** as **SVG**, previewing the result directly inside **Aseprite** as you work.

This repository contains three tools:

1. **An Aseprite script** that generates a live triangle-rendered preview of any sprite frame or animation.
2. **A single-page browser app** that converts static images or animated GIFs into animated triangle-based SVGs (with embedded JSON for rendering in Godot).
3. **A Godot game script** that renders the generated SVG's with various controls for rendering.

> Disclaimer: These files are heavily vibe-coded, and have had very little code review other than "does it work". Use at your own risk.

## Demo

[![Watch a demo](https://img.youtube.com/vi/ECTalxaMlKA/hqdefault.jpg)](https://www.youtube.com/watch?v=ECTalxaMlKA)

## 1. Aseprite Preview Script

**[A script](./aseprite_scripts)** that adds a **live vector-style triangle preview window** to Aseprite. To use it, in Aseprite:

- Navigate to `File > Scripts > Open Scripts Folder`
- Copy `aseprite_scripts/triangle_preview.lua` to that folder
- Run to `File > Scripts > Rescan Scripts Folder`
- Then, open a preview panel with `File > Scripts > triangle_preview`

### **Features**

- Works on the **entire sprite**, merging all visible layers.
- Updates automatically when you draw, change frames, or play the animation.
- Iterate visually in Aseprite without leaving the editor before converting.

## **Pipeline Overview**

These tools form a simple but flexible pipeline:

1. Design pixel art in Aseprite.
2. Preview triangle conversion live using the Aseprite script.
3. Export via the SVG converter app.

## 2. SVG Converter (Browser App)

**[A standalone HTML file](./web)** that runs entirely in the browser - just open it locally.

### Features

- Upload **PNG**, **JPG**, or **GIF** (including animated GIFs).
- Converts each pixel into one or two **flat-colored triangles** depending on the chosen orientation.
- Outputs:
  - A single SVG file for static images.
  - A CSS-keyframed, multi-frame **animated SVG** for GIFs.
  - The SVG file contained embedded rendering config for the below Godot script.

## 3. Godot 2D Node Renderer

**[A GD Script](./godot/)** that can render the generated `.svg` files (that have the embedded rendering configurations).

- Create a 2D Node
- Attach the included script
- Choose a generated SVG as the data source (check the logs for any errors)
- It offers some rendering parameters out of the box:
  - Color Tinting
  - Animation speed
  - Opacity
- It also plays nicely with the default Transformations (like scaling and rotation)