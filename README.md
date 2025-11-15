# Trianglizer

Convert pixel art into **triangle-based vector graphics** as **SVG**, previewing the result directly inside **Aseprite** as you work.

This repository contains two tools:

1. **A single-page browser app** that converts static images or animated GIFs into animated triangle-based SVGs.
2. **An Aseprite script** that generates a live triangle-rendered preview of any sprite frame or animation.

## Demo

[![Watch a demo](https://img.youtube.com/vi/Qss9QoZXxWs/hqdefault.jpg)](https://www.youtube.com/watch?v=Qss9QoZXxWs)

## 1. SVG Converter (Browser App)

**[A standalone HTML file](./web)** that runs entirely in the browser - just open it locally.

### Features

- Upload **PNG**, **JPG**, or **GIF** (including animated GIFs).
- Converts each pixel into one or two **flat-colored triangles** depending on the chosen orientation.
- Outputs:
  - A single SVG file for static images.
  - A CSS-keyframed, multi-frame **animated SVG** for GIFs.

## 2. Aseprite Preview Script

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