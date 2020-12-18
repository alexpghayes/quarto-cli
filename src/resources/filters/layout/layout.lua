-- layout.lua
-- Copyright (C) 2020 by RStudio, PBC

-- required version
PANDOC_VERSION:must_be_at_least '2.11.2'

-- required modules
text = require 'text'

-- global layout state
layout = {}

-- [import]
function import(script)
  local sep = package.config:sub(1,1)
  script = string.gsub(script, "/", sep)
  local path = PANDOC_SCRIPT_FILE:match("(.*" .. sep .. ")")
  dofile(path .. script)
end
import("meta.lua")
import("width.lua")
import("latex.lua")
import("html.lua")
import("wp.lua")
import("docx.lua")
import("odt.lua")
import("pptx.lua")
import("table.lua")
import("figures.lua")
import("../common/json.lua")
import("../common/pandoc.lua")
import("../common/format.lua")
import("../common/refs.lua")
import("../common/layout.lua")
import("../common/figures.lua")
import("../common/params.lua")
import("../common/meta.lua")
import("../common/table.lua")
import("../common/debug.lua")
-- [/import]


function layout2()

  return {
    Div = function(el)
      if hasLayoutAttributes(el) then
        
        -- partition
        local preamble, cells = partitionCells(el)
        
        -- derive layout
        local layout = layoutCells(el, cells)
        
        -- call the panel layout functions
        -- TODO
        local panel = layout
        
        -- if we have a preamble then wrap everything in a div
        -- with the preamble blocks and the panel
        if #preamble then
          local div = pandoc.Div(preamble)
          div.content:insert(panel)
          return div
        -- otherwise just return the panel
        else
          return panel
        end
        
      end
    end
  }  

  
end

function partitionCells(divEl)
  
  local preamble = pandoc.List:new()
  local cells = pandoc.List:new()
  
  local heading = nil
  
  for _,block in ipairs(divEl.content) do
    
    if isPreambleBlock(divEl) then
      preamble:insert(divEl)
    else if block.t == "Heading" then
      heading = block
    else 
      -- ensure we are dealing with a div
      local cellDiv = nil
      if block.t == "Div" then
        cellDiv = block
      else
        cellDiv = pandoc.Div(block)
      end
  
      -- if we have a heading then insert it
      if heading then 
        cellDiv.content:insert(1, heading)
        heading = nil
      end
      
      -- if this is an image div then get a reference to the
      -- image and copy the height and width attributes
      -- to the outer div
      local fig = figureImageFromCell(cellDiv)
      cellDiv.attr.attributes["width"] = fig.attributes["width"]
      cellDiv.attr.attributes["height"] = fig.attributes["height"]
      
      -- add the div
      cells:insert(cellDiv)
      
    end
    
  end

  return preamble, cells
  
end


function layoutCells(divEl, cells)
  
  -- layout to return (list of rows)
  local rows = pandoc.List:new()
  
   -- note any figure layout attributes
  local layoutRows = tonumber(attribute(divEl, kLayoutNrow, nil))
  local layoutCols = tonumber(attribute(divEl, kLayoutNcol, nil))
  local layout = attribute(divEl, kLayout, nil)
  
  -- if there is layoutRows but no layoutCols then compute layoutCols
  if not layoutCols and layoutRows ~= nil then
    layoutCols = math.ceil(#cells / layoutRows)
  end
  
  -- check for cols
  if layoutCols ~= nil then
    for i,cell in ipairs(cells) do
      if math.fmod(i-1, layoutCols) == 0 then
        rows:insert(pandoc.List:new())
      end
      rows[#rows]:insert(cell)
    end
    -- convert width units to percentages
    widthsToPercent(rows, layoutCols)
    
    -- allocate remaining space
    layoutWidths(rows, layoutCols)
    
  -- check for layout
  elseif layout ~= nil then
    -- parse the layout
    layout = parseLayoutWidths(layout, #cells)
    
    -- manage/perform next insertion into the layout
    local cellIndex = 1
    function layoutNextCell(width)
      -- check for a spacer width (negative percent)
      if isSpacerWidth(width) then
        local cell = pandoc.Div({
          pandoc.Para({pandoc.Str(" ")}),
          pandoc.Para({})
        }, pandoc.Attr(
          "", 
          { "quarto-figure-spacer" }, 
          { width = text.sub(width, 2, #width) }
        ))
        rows[#rows]:insert(cell)
      -- normal figure layout
      else
        local cell = cells[cellIndex]
        if cell then
          cellIndex = cellIndex + 1
          cell.attr.attributes["width"] = width
          cell.attr.attributes["height"] = nil
          rows[#rows]:insert(cell)
        end
      end
    end
  
    -- process the layout
    for _,item in ipairs(layout) do
      if cellIndex > #cells then
        break
      end
      rows:insert(pandoc.List:new())
      for _,width in ipairs(item) do
        layoutNextCell(width)
      end
    end
    
  end
  
  -- percentage based layouts need to be scaled down so they don't overflow the page 
  rows = rows:map(function(row)
    return row:map(function(fig)
      local percentWidth = widthToPercent(attribute(fig, "width", nil))
      if percentWidth then
        percentWidth = round(percentWidth * 0.96,1)
        fig.attr.attributes["width"] = tostring(percentWidth) .. "%"
      end
      return fig
    end)
   
  end)  

  -- return layout
  return rows
  
end



function isPreambleBlock(el)
  return el.t == "Div" and 
         (el.attr.classes:includes("cell-code") or 
         el.attr.classes:includes("cell-output-stderr"))
end


function layout() 
  
  return {
    
    Div = function(el)
      
      if hasLayoutAttributes(el) then
        
        -- handle subfigure layout
        local code, subfigures = layoutSubfigures(el)
        if subfigures then
          if isLatexOutput() then
            subfigures = latexPanel(el, subfigures)
          elseif isHtmlOutput() then
            subfigures = htmlPanel(el, subfigures)
          elseif isDocxOutput() then
            subfigures = tableDocxPanel(el, subfigures)
          elseif isOdtOutput() then
            subfigures = tableOdtPanel(el, subfigures)
          elseif isWordProcessorOutput() then
            subfigures = tableWpPanel(el, subfigures)
          elseif isPowerPointOutput() then
            subfigures = pptxPanel(el, subfigures)
          else
            subfigures = tablePanel(el, subfigures)
          end
          
          -- we have code then wrap the code and subfigues in a div
          if code then
            local div = pandoc.Div(code)
            div.content:insert(subfigures)
            return div
          -- otherwise just return the subfigures
          else
            return subfigures
          end
        
      end
    end,
    
  }
end


-- chain of filters
return {
  initParams(),
  layout(),
  extendedFigures(),
  metaInject()
}


