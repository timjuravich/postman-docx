require "sablon"
require "json"
require "redcarpet"
require 'nokogiri'
require 'neatjson'
require 'pygments'
require 'rouge'

renderer = Redcarpet::Render::HTML.new(filter_html: true, escape_html: true, hard_wrap: true)
markdown = Redcarpet::Markdown.new(renderer, extensions = {})
fileName = "./output/Output-#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.docx"

Sablon.configure do |config|
    config.register_html_tag(:code, :inline, properties: {})
    config.register_html_tag(:pre, :inline, properties: {})
end

# Get initial template
template = Sablon.template(File.expand_path("./Template.docx"))

# Get collection file
file = File.open("./collection.json") 
collectionJson = JSON.parse(file.read)

def generateJson(input)
    renderer = Redcarpet::Render::XHTML.new(hard_wrap: true, fenced_code_blocks: true, disable_indented_code_blocks: true)
    markdown = Redcarpet::Markdown.new(renderer, extensions = {})

    if input
        html = ""

        if input.is_a? String 
            html = JSON.neat_generate(JSON.parse(input), wrap: true, object_padding:4, indent:"  ")
        else
            html = JSON.neat_generate(input, wrap: true, object_padding:4, indent:"  ")
        end

        formatter = Rouge::Formatters::HTMLInline.new("base16.light")
        output = Rouge::Formatters::HTMLLineTable.new(formatter, opts={})
        lexer = Rouge::Lexers::JSON.new
        
        return Sablon.content(:html, markdown.render(formatter.format(lexer.lex(html))))
    else
        return ""
    end
end

def generateHtml(input)
    if input
        #TODO move to class so we dont have to copy and paste this
        renderer = Redcarpet::Render::XHTML.new(hard_wrap: true, fenced_code_blocks: true, disable_indented_code_blocks: true)
        markdown = Redcarpet::Markdown.new(renderer, extensions = {})
        return Sablon.content(:html, markdown.render(input))
    else
        return ""
    end
end

def parseItem(item, level)
    if item["name"]
        str = "-" * (level - 1)
        puts "parsed: #{str} #{item["name"]}"
    end

    item["request"] = [] if item["request"].nil?
    item["response"] = [] if item["response"].nil?

    if item["request"].any?
        if item["request"]["header"].any?
            # TODO, need to see if we actually want this?
            item["request"]["header"] = generateJson(item["request"]["header"][0])
        end
        if item["request"]["body"]
            mode = item["request"]["body"]["mode"]
            item["request"]["body"] = generateJson(item["request"]["body"]["#{mode}"])
        end

        item["request"]["description"] = generateHtml(item["request"]["description"])
    end
    
    item["response"].each do |response|
        # TODO, need to see if we actually want this?
        response["header"] = generateJson(response["header"][0])
        response["body"] = generateJson(response["body"])
    end

    return {
        name: item["name"] ? item["name"] : "",
        description: generateHtml(item["description"]),
        request: item["request"],
        response: item["response"],
        subItems: []
    }
end

def getChildren(items, itemJson)
    # Parse the root level items
    item = parseItem(itemJson, 1)

    # If the root level has subItems, parse them
    if itemJson["item"]
        subItems = []
        itemJson["item"].each do |subItemJson|
            subItem = parseItem(subItemJson, 2)

            # If the second level has subItems, parse them
            if subItemJson["item"]
                subSubItems = []
                subItemJson["item"].each do |subSubItemJson|
                    subSubItem = parseItem(subSubItemJson, 3)
                    subSubItems << subSubItem
                end
                subItem[:subItems] = subSubItems
            end

            subItems << subItem
        end
        item[:subItems] = subItems
    end

    items << item
end

items = Array.new

collectionJson["item"].each do |item|
    getChildren(items, item)
end

context = {
  intro: {
     title: collectionJson["info"]["name"],
     description: generateHtml(collectionJson["info"]["description"])
  },
  items: items
}

puts "Rendering file"
template.render_to_file File.expand_path(fileName), context
puts "Rendering Complete. Opening generated documentation"
system %{open "#{File.expand_path(fileName)}"}