-- triangle_preview.lua
-- Triangle raster preview + animation bake for the active sprite in Aseprite
-- Flow:
--   1) Ask for parameters in a small settings dialog.
--   2) On OK, open a preview dialog using those params.
--   3) Preview auto-updates on paint / frame changes and can bake all frames.

do
  local spr = app.sprite
  if not spr then
    app.alert("Open a sprite first.")
    return
  end

  -- Parameters chosen in the settings dialog
  local params = {
    side   = 16,
    orient = "cols",
    nx     = 0,
    ny     = 0,
  }

  local dlg       = nil  -- preview dialog
  local previewImg = nil -- Image containing current frame's triangulated render

  ----------------------------------------------------------------------
  -- helpers
  ----------------------------------------------------------------------

  local function drawSpan(img, y, x1, x2, color)
    local w, h = img.width, img.height
    if y < 0 or y >= h then return end
    if x1 > x2 then x1, x2 = x2, x1 end
    x1 = math.max(0, math.floor(x1))
    x2 = math.min(w - 1, math.ceil(x2))
    for x = x1, x2 do
      img:putPixel(x, y, color)
    end
  end

  local function fillTriangle(img, x1, y1, x2, y2, x3, y3, color)
    -- Bounding box of the triangle
    local minX = math.floor(math.min(x1, x2, x3))
    local maxX = math.ceil (math.max(x1, x2, x3))
    local minY = math.floor(math.min(y1, y2, y3))
    local maxY = math.ceil (math.max(y1, y2, y3))

    local w, h = img.width, img.height
    if minX >= w or maxX < 0 or minY >= h or maxY < 0 then
      return
    end

    -- Clamp bbox to image bounds
    if minX < 0 then minX = 0 end
    if minY < 0 then minY = 0 end
    if maxX > w then maxX = w end
    if maxY > h then maxY = h end

    local function edge(ax, ay, bx, by, px, py)
      return (px - ax) * (by - ay) - (py - ay) * (bx - ax)
    end

    -- Signed area to know triangle orientation
    local area = edge(x1, y1, x2, y2, x3, y3)
    if area == 0 then
      return
    end

    local areaSign = area > 0

    -- Sample at pixel centers (x + 0.5, y + 0.5)
    for y = minY, maxY - 1 do
      local py = y + 0.5
      for x = minX, maxX - 1 do
        local px = x + 0.5

        local w0 = edge(x2, y2, x3, y3, px, py)
        local w1 = edge(x3, y3, x1, y1, px, py)
        local w2 = edge(x1, y1, x2, y2, px, py)

        if areaSign then
          if w0 >= 0 and w1 >= 0 and w2 >= 0 then
            img:putPixel(x, y, color)
          end
        else
          if w0 <= 0 and w1 <= 0 and w2 <= 0 then
            img:putPixel(x, y, color)
          end
        end
      end
    end
  end

  ----------------------------------------------------------------------
  -- core triangulation: given a flattened src Image, returns new Image
  ----------------------------------------------------------------------

  local function triangulateImage(srcImg, side, orient, nudgeX, nudgeY)
    local srcW, srcH = srcImg.width, srcImg.height
    local outW, outH = srcW, srcH -- 1:1 pixels

    local hTri = side * math.sqrt(3) / 2

    local canvasW, canvasH
    if orient == "rows" then
      canvasW = math.floor((outW-1)*(side/2) + side + 0.5)
      canvasH = math.floor(outH * hTri + 0.5)
    else -- "cols"
      canvasW = outW * side
      canvasH = math.floor((outH-1)*(hTri/2) + hTri + 0.5)
    end

    local outImg = Image(canvasW, canvasH, srcImg.colorMode)
    outImg:clear(app.pixelColor.rgba(0,0,0,0))

    local transparent = app.pixelColor.rgba(0,0,0,0)

    if orient == "rows" then
      for y = 0, outH-1 do
        local sy = y + nudgeY
        if sy < 0 then sy = 0 end
        if sy >= srcH then sy = srcH - 1 end

        local Y = y * hTri
        for x = 0, outW-1 do
          local sx = x + nudgeX
          if sx < 0 then sx = 0 end
          if sx >= srcW then sx = srcW - 1 end

          local X = x * (side / 2)
          local c = srcImg:getPixel(sx, sy)
          if c ~= transparent then
            local a = app.pixelColor.rgbaA(c)
            if a > 0 then
              local r = app.pixelColor.rgbaR(c)
              local g = app.pixelColor.rgbaG(c)
              local b = app.pixelColor.rgbaB(c)
              local col = app.pixelColor.rgba(r,g,b,a)
              local parity = (x + y) % 2
              if parity == 0 then
                -- up
                fillTriangle(outImg,
                  X,          Y + hTri,
                  X+side/2,   Y,
                  X+side,     Y + hTri,
                  col)
              else
                -- down
                fillTriangle(outImg,
                  X,          Y,
                  X+side/2,   Y + hTri,
                  X+side,     Y,
                  col)
              end
            end
          end
        end
      end
    else
      -- "cols": triangles pointing left/right
      for y = 0, outH-1 do
        local sy = y + nudgeY
        if sy < 0 then sy = 0 end
        if sy >= srcH then sy = srcH - 1 end

        local Y = y * (hTri / 2)
        for x = 0, outW-1 do
          local sx = x + nudgeX
          if sx < 0 then sx = 0 end
          if sx >= srcW then sx = srcW - 1 end

          local X = x * side
          local c = srcImg:getPixel(sx, sy)
          if c ~= transparent then
            local a = app.pixelColor.rgbaA(c)
            if a > 0 then
              local r = app.pixelColor.rgbaR(c)
              local g = app.pixelColor.rgbaG(c)
              local b = app.pixelColor.rgbaB(c)
              local col = app.pixelColor.rgba(r,g,b,a)
              local parity = (x + y) % 2
              if parity == 0 then
                -- right
                fillTriangle(outImg,
                  X,        Y,
                  X,        Y + hTri,
                  X+side,   Y + hTri/2,
                  col)
              else
                -- left
                fillTriangle(outImg,
                  X+side,   Y,
                  X+side,   Y + hTri,
                  X,        Y + hTri/2,
                  col)
              end
            end
          end
        end
      end
    end

    return outImg
  end

  ----------------------------------------------------------------------
  -- rebuild preview from current sprite state (current frame, all layers)
  ----------------------------------------------------------------------

  local function rebuildPreview()
    if not spr then return end
    if not dlg then return end
    if not app.sprite then return end
    if app.sprite ~= spr then return end

    local side   = params.side
    local orient = params.orient
    local nudgeX = params.nx
    local nudgeY = params.ny

    -- Flatten all visible layers of the current frame
    local frame = app.activeFrame.frameNumber
    local srcImg = Image(spr.spec)  -- same size / colorMode as sprite
    srcImg:clear()
    srcImg:drawSprite(spr, frame)

    previewImg = triangulateImage(srcImg, side, orient, nudgeX, nudgeY)
    dlg:repaint()
  end

  ----------------------------------------------------------------------
  -- preview dialog creation
  ----------------------------------------------------------------------

  local function openPreviewDialog()
    dlg = Dialog{ title = "Triangle Preview" }

    dlg:button{
      text = "Refresh from sprite",
      onclick = function() rebuildPreview() end
    }

    dlg:canvas{
      id = "preview",
      width = 256,
      height = 256,
      hexpand = true,
      vexpand = true,
      onpaint = function(ev)
        local ctx = ev.context

        -- background
        ctx.color = Color{ r=30, g=30, b=30, a=255 }
        ctx:fillRect(ev.bounds)

        if not previewImg then return end

        local iw, ih = previewImg.width, previewImg.height
        if iw == 0 or ih == 0 then return end

        -- scale to fit canvas
        local cw, ch = ctx.width, ctx.height
        local scale = math.min(cw / iw, ch / ih)
        if scale <= 0 then scale = 1 end
        local dw = iw * scale
        local dh = ih * scale
        local dx = (cw - dw) / 2
        local dy = (ch - dh) / 2

        ctx:drawImage(previewImg,
          0, 0, iw, ih,   -- src rect
          dx, dy, dw, dh) -- dst rect
      end
    }

    dlg:button{
      text = "Bake animation to new sprite",
      onclick = function()
        if not spr then return end

        local side   = params.side
        local orient = params.orient
        local nudgeX = params.nx
        local nudgeY = params.ny

        app.transaction(function()
          -- First frame
          local srcImg0 = Image(spr.spec)
          srcImg0:clear()
          srcImg0:drawSprite(spr, 1)
          local firstOut = triangulateImage(srcImg0, side, orient, nudgeX, nudgeY)

          local newSpr = Sprite(firstOut.width, firstOut.height, spr.colorMode)
          newSpr:newCel(newSpr.layers[1], 1, firstOut, Point(0,0))

          local frameCount = #spr.frames
          for i = 2, frameCount do
            newSpr:newFrame()
            local srcImg = Image(spr.spec)
            srcImg:clear()
            srcImg:drawSprite(spr, i)
            local outImg = triangulateImage(srcImg, side, orient, nudgeX, nudgeY)
            newSpr:newCel(newSpr.layers[1], i, outImg, Point(0,0))
          end

          app.sprite = newSpr
        end)
      end
    }

    dlg:button{
      text = "Close",
      onclick = function() dlg:close() end
    }

    dlg:show{ wait = false }

    -- Initial build
    rebuildPreview()

    -- Auto-refresh hooks
    spr.events:on("change", function()
      rebuildPreview()
    end)

    app.events:on("sitechange", function(ev)
      if app.sprite == spr then
        rebuildPreview()
      end
    end)
  end

  ----------------------------------------------------------------------
  -- settings dialog (runs first)
  ----------------------------------------------------------------------

  local function openSettingsDialog()
    local settingsDlg = Dialog{ title = "Triangle Settings" }
    local accepted = false

    settingsDlg:number{
      id = "side",
      label = "Side",
      text = tostring(params.side),
      decimals = 0,
    }
    settingsDlg:combobox{
      id = "orient",
      label = "Orient",
      options = {"cols","rows"},
      option = params.orient,
    }
    settingsDlg:number{
      id = "nx",
      label = "NX",
      text = tostring(params.nx),
      decimals = 0,
    }
    settingsDlg:number{
      id = "ny",
      label = "NY",
      text = tostring(params.ny),
      decimals = 0,
    }

    settingsDlg:button{
      text = "OK",
      onclick = function()
        local d = settingsDlg.data or {}
        params.side   = math.max(2, math.floor(tonumber(d.side  or params.side)   or params.side))
        params.orient = d.orient or params.orient
        params.nx     = math.floor(tonumber(d.nx or params.nx) or params.nx)
        params.ny     = math.floor(tonumber(d.ny or params.ny) or params.ny)
        accepted = true
        settingsDlg:close()
      end
    }

    settingsDlg:button{
      text = "Cancel",
      onclick = function()
        accepted = false
        settingsDlg:close()
      end
    }

    settingsDlg:show{ wait = true }
    return accepted
  end

  ----------------------------------------------------------------------
  -- main flow
  ----------------------------------------------------------------------

  local ok = openSettingsDialog()
  if not ok then
    return
  end

  openPreviewDialog()
end