Swagger::Docs::Config.register_apis(
  {
    "1.0" =>  {
      #:controller_base_path => "/app/controllers/api/v0",
      # the extension used for the API
      :api_extension_type => :json,
      # the output location where your .json files are written to
      :api_file_path => "public/",
      # the URL base path to your API
      :base_path => "http://localhost:3000",
      # if you want to delete all .json files at each generation
      :clean_directory => true,
      # add custom attributes to api-docs
      :attributes => {
        :info => {
          "title" => "Caritathelp API Documention",
          "description" => "Just another amazing API",
          "contact" => "robin.vasseur@epitech.eu"
        }
      }
    }
  })
