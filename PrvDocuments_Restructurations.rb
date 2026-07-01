# Gemfile

gem "httparty"
gem "dotenv"

# .env

NOTION_TOKEN=secret_xxxxxxxxxxxxxxxxx
PARENT_PAGE_ID=35872117082a80bdae35ce799c7e44c2

# notion_setup.rb

require "httparty"
require "json"
require "dotenv/load"

class NotionSetup

API_URL = "https://api.notion.com/v1"

def initialize
@headers = {
"Authorization" => "Bearer #{ENV['NOTION_TOKEN']}",
"Notion-Version" => "2022-06-28",
"Content-Type" => "application/json"
}
end

def create_database(name, properties)

```
body = {
  parent: {
    type: "page_id",
    page_id: ENV["PARENT_PAGE_ID"]
  },
  title: [
    {
      type: "text",
      text: {
        content: name
      }
    }
  ],
  properties: properties
}

response = HTTParty.post(
  "#{API_URL}/databases",
  headers: @headers,
  body: body.to_json
)

puts "#{name} : #{response.code}"
JSON.parse(response.body)
```

end

def create_domaines
create_database(
"Domaines",
{
"Nom" => {
"title" => {}
}
}
)
end

def create_types
create_database(
"Types",
{
"Nom" => {
"title" => {}
}
}
)
end

def create_dossiers
create_database(
"Dossiers",
{
"Nom" => {
"title" => {}
}
}
)
end

def create_tags
create_database(
"Tags",
{
"Nom" => {
"title" => {}
}
}
)
end

def create_emetteurs
create_database(
"Emetteurs",
{
"Nom" => {
"title" => {}
}
}
)
end

def create_alertes
create_database(
"Alertes",
{
"Titre" => { "title" => {} },
"Commentaires" => { "rich_text" => {} },
"Statut" => { "status" => {} },
"Date début" => { "date" => {} },
"Date fin" => { "date" => {} },
"Niveau" => {
"select" => {
"options" => [
{ "name" => "Faible" },
{ "name" => "Moyenne" },
{ "name" => "Haute" },
{ "name" => "Critique" }
]
}
}
}
)
end

def create_documents
create_database(
"Documents",
{
"Référence" => { "title" => {} },
"Description" => { "rich_text" => {} },
"Statut" => { "status" => {} },
"Version" => { "number" => {} },
"Date validation" => { "date" => {} },
"Date révision" => { "date" => {} },
"FileID" => { "rich_text" => {} },
"FileName" => { "rich_text" => {} },
"FileSize" => { "number" => {} },
"Ancienne table" => { "rich_text" => {} },
"Fichier" => { "files" => {} },
"Responsable" => { "people" => {} }
}
)
end
end

setup = NotionSetup.new

setup.create_domaines
setup.create_types
setup.create_dossiers
setup.create_tags
setup.create_emetteurs
setup.create_alertes
setup.create_documents
