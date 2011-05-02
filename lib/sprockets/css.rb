require 'tilt'

module Sprockets
  class SassImporter < Sass::Importers::Base
    GLOB = /\*|\[.+\]/
    PARTIAL = /^_/
    HAS_EXTENSION = /\.css(.s[ac]ss)?$/

    SASS_EXTENSIONS = {
      ".css.sass" => :sass,
      ".css.scss" => :scss
    }
    attr_reader :context

    def initialize(context)
      @context = context
    end

    def sass_file?(filename)
      filename = filename.to_s
      SASS_EXTENSIONS.keys.any?{|ext| filename[ext]}
    end

    def syntax(filename)
      filename = filename.to_s
      SASS_EXTENSIONS.each {|ext, syntax| return syntax if filename[(ext.size+2)..-1][ext]}
      nil
    end

    def glob_imports(glob, base_pathname, options)
      contents = ""
      tree = base_pathname.dirname.relative_path_from(context.pathname.dirname)
      each_pathname_in_tree(tree, glob) do |p|
        if p.file? && p != base_pathname
          contents << "@import #{p.relative_path_from(base_pathname.dirname).to_s.inspect};\n"
        end
      end
      Sass::Engine.new(contents, options.merge(
        :filename => base_pathname,
        :importer => self,
        :syntax => :scss
      ))
    end

    def extensionify(name)
      if name.to_s =~ HAS_EXTENSION
        name.to_s
      else
        "#{name}.css"
      end
    end

    def resolve(name, base_pathname = nil)
      name = Pathname.new(extensionify(name))
      if base_pathname && base_pathname.to_s.size > 0
        name = base_pathname.dirname.relative_path_from(context.pathname.dirname).join(name)
      end
      partial_name = name.dirname.join("_#{name.basename}")

      sprockets_resolve(name) || sprockets_resolve(partial_name)
    end

    def find_relative(name, base, options)
      base_pathname = Pathname.new(base)
      if name =~ GLOB
        glob_imports(name, base_pathname, options)
      elsif pathname = resolve(name, base_pathname)
        if sass_file?(pathname)
          Sass::Engine.new(pathname.read, options.merge(:filename => pathname.to_s, :importer => self, :syntax => syntax(pathname)))
        else
          Sass::Engine.new(sprockets_process(pathname), options.merge(:filename => pathname.to_s, :importer => self, :syntax => :scss))
        end
      else
        nil
      end
    end

    def find(name, options)
      if pathname = resolve(name)
        if sass_file?(pathname)
          Sass::Engine.new(pathname.read, options.merge(:filename => pathname.to_s, :importer => self, :syntax => syntax(pathname)))
        else
          Sass::Engine.new(sprockets_process(pathname), options.merge(:filename => pathname.to_s, :importer => self, :syntax => :scss))
        end
      else
        nil
      end
    end

    def mtime(name, options)
      if name =~ GLOB
        mtime = nil
        each_pathname_in_tree(".", name) do |p|
          mtime ||= p.mtime
          mtime = [mtime, p.mtime].max
        end
        mtime
      elsif pathname = resolve(name)
        pathname.mtime
      end
    end

    def key(name, options)
      if name.to_s =~ GLOB
        ["Sprockets:#{context.base_path}", name]
      else
        ["Sprockets:" + File.dirname(File.expand_path(name)), File.basename(name)]
      end
    end

    def to_s
      "Sprockets::SassImporter(#{context.pathname})"
    end

    private
      def sprockets_resolve(path)
        context.sprockets_resolve(path)
      rescue Sprockets::FileNotFound
        nil
      end

      def each_pathname_in_tree(relative_path = ".", glob = "**/*")
        Dir["#{context.pathname.dirname.join(relative_path)}/#{glob}"].sort.each do |filename|
          pathname = Pathname.new(filename)

          if pathname.directory?
            yield pathname
          elsif pathname.file? &&
              context.content_type_for(pathname) == context.content_type_for(context.pathname)
            yield pathname
          end
        end
      end
  end

  class SassTemplate < Tilt::SassTemplate
    self.default_mime_type = 'text/css'

    def initialize(*args)
      super
      @context = Context
    end

    def syntax
      :sass
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      importer = SassImporter.new(scope)
      Sass::Engine.new(data, {
        :filename => eval_file,
        :line => line,
        :syntax => syntax,
        :importer => importer,
        :load_paths => [importer]
      }).render
    end
  end

  class ScssTemplate < SassTemplate
    self.default_mime_type = 'text/css'

    def syntax
      :scss
    end
  end
end
