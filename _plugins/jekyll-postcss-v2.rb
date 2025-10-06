# MIT License
#
# Copyright (c) 2024 Liam Bigelow
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require "pathname"

module PostCssV2
  class Engine
    def initialize(source, options = {})
      @script = File.expand_path(options[:script] || 'node_modules/.bin/postcss', source)
      unless File.exist?(@script)
        Jekyll.logger.error "PostCSS v2:",
                            "PostCSS not found.
                             Make sure postcss and postcss-cli
                             are installed in your Jekyll source."
        Jekyll.logger.error "PostCSS v2:",
                            "Couldn't find #{@script}"
        exit 1
      end

      @config = File.expand_path(options[:config] || 'postcss.config.js', source)
      unless File.exist?(@config)
        Jekyll.logger.error "PostCSS v2:",
                            "postcss.config.js not found.
                             Make sure it exists in your Jekyll source."
        Jekyll.logger.error "PostCSS v2:",
                            "Couldn't find #{@config}"
        exit 1
      end
    end

    def process(page)
      file_path = Pathname.new(page.destination(page.site.dest))
      postcss_command = `#{@script} #{file_path} -r --config #{@config}`
      Jekyll.logger.info "PostCSS v2:",
                         "Rewrote #{page.url} #{postcss_command}"
    end
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  site.pages.each do |page|
    if %r!\.css$! =~ page.destination(site.dest)
      engine = PostCssV2::Engine.new(site.source, {
        script: site.config.dig("postcss", "script"),
        config: site.config.dig("postcss", "config"),
      })
      engine.process(page)
    end
  end
end
