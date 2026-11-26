local palettes = {
    technical = {'#245b83', '#f3f6f9', '#253347'},
    academic = {'#404040', '#f5f5f5', '#292929'},
    professional = {'#183b58', '#eef3f7', '#203244'},
    minimal = {'#222222', '#f5f5f5', '#222222'},
}
local theme = 'technical'
local default_size = 'auto'
local sizes = {auto=true, small=true, normal=true, large=true, full=true}

local function configure(meta)
    default_size = meta['mermaid-size'] and pandoc.utils.stringify(meta['mermaid-size']) or 'auto'
    assert(sizes[default_size], 'Invalid mermaid-size: ' .. default_size)
    local override = os.getenv('MD2PDF_THEME_OVERRIDE')
    theme = override and override ~= '' and override or (meta.theme and pandoc.utils.stringify(meta.theme) or 'technical')
end

local function render(block)
    local size = block.attributes.size
    local is_mermaid = block.classes:includes('mermaid')
    for _, class in ipairs(block.classes) do
        local suffix = class:match('^mermaid%-(%a+)$')
        if suffix and sizes[suffix] then is_mermaid, size = true, suffix end
    end
    if not is_mermaid then return nil end
    size = size or default_size
    assert(sizes[size], 'Invalid Mermaid size: ' .. size)

    local resolved = size
    local uri = pandoc.system.with_temporary_directory('md2pdf-mermaid', function(dir)
        local output = dir .. '/diagram.svg'

        local colors = assert(palettes[theme], 'Invalid theme: ' .. theme)
        local config = dir .. '/config.json'
        local cfg = assert(io.open(config, 'w'))
        cfg:write(string.format([[{"theme":"base","themeVariables":{"primaryColor":"%s","primaryBorderColor":"%s","primaryTextColor":"%s","lineColor":"%s","fontFamily":"Inter, sans-serif","fontSize":"14px"},"themeCSS":".node rect, .node polygon, .node path, .node circle { filter: none !important; } .node { filter: none !important; }","flowchart":{"htmlLabels":false,"nodeSpacing":22,"rankSpacing":25}}]], colors[2], colors[1], colors[3], colors[1]))
        cfg:close()
        pandoc.pipe('mmdc', {
            '-i', '-',
            '-o', output,
            '-c', config,
            '-b', 'transparent',
        }, block.text)

        local file = assert(io.open(output, 'rb'))
        local svg = file:read('*a')
        file:close()

        if size == 'auto' then
            local viewbox = svg:match('viewBox%s*=%s*"([^"]+)"') or svg:match("viewBox%s*=%s*'([^']+)'")
            local values = {}
            for value in (viewbox or ''):gmatch('[^,%s]+') do values[#values+1] = tonumber(value) end
            local w, h = values[3], values[4]
            resolved = 'normal'
            if w and h and w > 0 and h > 0 then
                if h / w >= 2.1 or h >= 1000 then resolved = 'large'
                elseif h <= 260 then resolved = 'small' end
            end
        end
        return 'data:image/svg+xml;base64,' .. pandoc.pipe('base64', {'-w0'}, svg)
    end)

    return pandoc.Div({pandoc.Para({pandoc.Image({pandoc.Str('Mermaid diagram')}, uri)})},
        pandoc.Attr(block.identifier, {'mermaid-diagram', 'mermaid-' .. resolved}))
end

return {{Meta = configure}, {CodeBlock = render}}
