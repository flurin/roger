require File.dirname(__FILE__) + '../../../resolver'

module HtmlMockup::Release::Processors
  class UrlRelativizer < Base
    
    def initialize(options={})
      @options = {
        :url_attributes => %w{src href action},
        :match => ["**/*.html"]
      }
      
      @options.update(options) if options            
    end

    def call(release, options={})
      options = {}.update(@options).update(options)
      
      release.log(self, "Relativizing all URLS in #{options[:match].inspect} files in attributes #{options[:url_attributes].inspect}")
      
      @resolver = HtmlMockup::Resolver.new(release.build_path)
      release.get_files(options[:match]).each do |file_path|
        orig_source = File.read(file_path)
        File.open(file_path,"w") do |f| 
          source = relativize_urls(orig_source, file_path, options)
          f.write(source) 
        end
      end
    end
    
    protected
    
    def relativize_urls(source, file_path, options={})
      doc = Hpricot(source)
      options[:url_attributes].each do |attribute|
        (doc/"*[@#{attribute}]").each do |tag|
          converted_url = @resolver.url_to_relative_url(tag[attribute], file_path)
              
          case converted_url
          when String
            tag[attribute] = converted_url
          when nil
            puts "Could not resolve link #{tag[attribute]} in #{file_path}"
          end
        end
      end
      
      doc.to_original_html      
    end
        
  end
end