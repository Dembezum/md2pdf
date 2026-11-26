function CodeBlock(block)
    if not block.classes:includes('mermaid') then
        return nil
    end

    local uri = pandoc.system.with_temporary_directory('md2pdf-mermaid', function(dir)
        local output = dir .. '/diagram.svg'

        pandoc.pipe('mmdc', {
            '-i', '-',
            '-o', output,
            '-t', 'neutral',
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
