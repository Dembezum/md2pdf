local function setting(meta, name, env, fallback, allowed)
    local value = os.getenv(env)
    if not value or value == '' then value = meta[name] and pandoc.utils.stringify(meta[name]) or fallback end
    if not allowed[value] then error('Invalid ' .. name .. ': ' .. value) end
    return value
end

function Meta(meta)
    meta['md2pdf-theme'] = setting(meta, 'theme', 'MD2PDF_THEME_OVERRIDE', 'technical', {technical=true, academic=true, professional=true, minimal=true})
    meta['md2pdf-pagination'] = setting(meta, 'pagination', 'MD2PDF_PAGINATION_OVERRIDE', 'chapters', {chapters=true, sections=true, flow=true})
    if os.getenv('MD2PDF_TOC') == 'false' or meta.toc == false then meta.toc = false else meta.toc = true end
    meta['md2pdf-footer'] = os.getenv('MD2PDF_FOOTER') ~= 'false'
    if meta.cover and not meta.title then error('cover requires title metadata') end
    return meta
end

local alerts = {NOTE='Note', TIP='Tip', IMPORTANT='Important', WARNING='Warning', CAUTION='Caution'}
function BlockQuote(block)
    local first = block.content[1]
    if not first or (first.t ~= 'Para' and first.t ~= 'Plain') then return nil end
    local marker = first.content[1]
    if not marker or marker.t ~= 'Str' then return nil end
    local kind = marker.text:match('^%[!([A-Z]+)%]$')
    if not kind or not alerts[kind] then return nil end
    first.content:remove(1)
    if first.content[1] and (first.content[1].t == 'SoftBreak' or first.content[1].t == 'LineBreak' or first.content[1].t == 'Space') then first.content:remove(1) end
    if #first.content == 0 then block.content:remove(1) end
    block.content:insert(1, pandoc.Div({pandoc.Plain({pandoc.Str(alerts[kind])})}, pandoc.Attr('', {'callout-title'})))
    return pandoc.Div(block.content, pandoc.Attr('', {'callout', 'callout-' .. kind:lower()}))
end

function Div(block)
    for _, class in ipairs(block.classes) do
        if alerts[class:upper()] and block.content[1] and block.content[1].t == 'Div' and block.content[1].classes:includes('title') then
            block.classes:insert('callout')
            block.classes:insert('callout-' .. class)
            block.content[1].classes:insert('callout-title')
            return block
        end
    end
end

function CodeBlock(block)
    local language = block.classes[1]
    if not language or language == 'mermaid' or language == 'text' or language == 'plain' then return nil end
    local label = pandoc.Div({pandoc.Plain({pandoc.Str(language:upper())})}, pandoc.Attr('', {'code-label'}))
    return pandoc.Div({label, block}, pandoc.Attr('', {'code-panel'}))
end
