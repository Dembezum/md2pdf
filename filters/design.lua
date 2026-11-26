local function setting(meta, name, env, fallback, allowed)
    local value = os.getenv(env)
    if not value or value == '' then value = meta[name] and pandoc.utils.stringify(meta[name]) or fallback end
    if not allowed[value] then error('Invalid ' .. name .. ': ' .. value) end
    return value
end

function Meta(meta)
    meta['md2pdf-theme'] = setting(meta, 'theme', 'MD2PDF_THEME_OVERRIDE', 'technical', {technical=true, academic=true, professional=true, minimal=true})
    meta['md2pdf-pagination'] = setting(meta, 'pagination', 'MD2PDF_PAGINATION_OVERRIDE', 'smart', {smart=true, chapters=true, sections=true, flow=true})
    if os.getenv('MD2PDF_TOC') == 'false' or meta.toc == false then meta.toc = false else meta.toc = true end
    meta['md2pdf-footer'] = os.getenv('MD2PDF_FOOTER') ~= 'false'
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

-- Group only bounded leaf subsections; long or nested sections remain breakable.
local function short_section(blocks)
    local words, diagrams = 0, 0
    if #blocks > 8 then return false end
    for _, block in ipairs(blocks) do
        if block.t == 'Div' and block.classes:includes('mermaid-diagram') then
            if block.classes:includes('mermaid-full') then return false end
            diagrams = diagrams + 1
        elseif block.t == 'Para' or block.t == 'Plain' or block.t == 'BulletList' or block.t == 'OrderedList' or block.t == 'Header' then
            for _ in pandoc.utils.stringify(block):gmatch('%S+') do words = words + 1 end
        else
            return false
        end
    end
    return diagrams <= 1 and words <= (diagrams == 1 and 120 or 230)
end

local function group_sections(blocks)
    local result = pandoc.List()
    local i = 1
    while i <= #blocks do
        local head = blocks[i]
        if head.t == 'Header' and head.level >= 2 then
            local j = i + 1
            while j <= #blocks and blocks[j].t ~= 'Header' do j = j + 1 end
            local leaf = j > #blocks or blocks[j].level <= head.level
            local section = pandoc.List()
            for k = i, j - 1 do section:insert(blocks[k]) end
            if leaf and #section > 1 and short_section(section) then
                result:insert(pandoc.Div(section, pandoc.Attr('', {'smart-section'})))
            else
                for _, block in ipairs(section) do result:insert(block) end
            end
            i = j
        else
            result:insert(head)
            i = i + 1
        end
    end
    return result
end

function Pandoc(doc)
    local default_title = os.getenv('MD2PDF_DEFAULT_TITLE') or ''
    local cover = os.getenv('MD2PDF_COVER_OVERRIDE') or ''
    if cover ~= '' then
        doc.meta.cover = pandoc.MetaBool(cover == 'true')
    elseif doc.meta.cover == nil then
        doc.meta.cover = pandoc.MetaBool(default_title ~= '')
    end
    if not doc.meta.title and default_title ~= '' then
        doc.meta.title = pandoc.MetaString(default_title)
    end
    if not doc.meta.title then
        for _, block in ipairs(doc.blocks) do
            if block.t == 'Header' and block.level == 1 then
                doc.meta.title = pandoc.MetaInlines(block.content)
                break
            end
        end
    end
    if doc.meta.cover and not doc.meta.title then error('cover requires a title or H1') end
    if pandoc.utils.stringify(doc.meta['md2pdf-pagination']) == 'smart' then
        doc.blocks = group_sections(doc.blocks)
    end
    return doc
end
