local palettes = {
    technical = {'#245b83', '#f3f6f9', '#253347'},
    academic = {'#404040', '#f5f5f5', '#292929'},
    professional = {'#183b58', '#eef3f7', '#203244'},
    minimal = {'#222222', '#f5f5f5', '#222222'},
}
local theme = 'technical'

local function configure(meta)
    local override = os.getenv('MD2PDF_THEME_OVERRIDE')
    theme = override and override ~= '' and override or (meta.theme and pandoc.utils.stringify(meta.theme) or 'technical')
end

local function render(block)
    if not block.classes:includes('mermaid') then
        return nil
    end

    local uri = pandoc.system.with_temporary_directory('md2pdf-mermaid', function(dir)
        local output = dir .. '/diagram.svg'

        local colors = assert(palettes[theme], 'Invalid theme: ' .. theme)
        local config = dir .. '/config.json'
        local cfg = assert(io.open(config, 'w'))
        cfg:write(string.format([[{"theme":"base","themeVariables":{"primaryColor":"%s","primaryBorderColor":"%s","primaryTextColor":"%s","lineColor":"%s","fontFamily":"Inter, sans-serif","fontSize":"14px"},"flowchart":{"htmlLabels":false,"nodeSpacing":30,"rankSpacing":35}}]], colors[2], colors[1], colors[3], colors[1]))
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

        return 'data:image/svg+xml;base64,' .. pandoc.pipe('base64', {'-w0'}, svg)
    end)

    return pandoc.Div({pandoc.Para({pandoc.Image({pandoc.Str('Mermaid diagram')}, uri)})},
        pandoc.Attr(block.identifier, {'mermaid-diagram'}))
end

return {{Meta = configure}, {CodeBlock = render}}
