# dejure.rb
# a nanoc filter for dejure.org legal integration service
# see <https://dejure.org/vernetzung.html>
#
# adapted from PHP reference implementation
# at <https://dejure.org/vernetzung/vernetzungsfunktion.zip>
#
# (c) 2017 Thomas Hochstein <thh@inter.net>
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
# 
#
# params may be set as follows:
# params[:format] -> [weit|schmal]          (weit)
# params[:target] -> target for <a href>    ('')
# params[:class]  -> CSS class for <a href> ('')
# params[:buzer]  -> fallback to buzer.de?  (1)

require 'net/http'

module Nanoc::Filters
  class DeJureIntegrator < Nanoc::Filter
  	identifier :dejure
  	type :text

    def set_params (params)
      # set default params
      params[:version]            = '0.1'
      if !@config[:base_url].nil?
        params[:Anbieterkennung]  = @config[:base_url]
      else
        params[:Anbieterkennung] = 'http://unknown.nanoc.installation.invalid'
      end
      params[:format]           ||= 'weit'
      params[:buzer]            ||= 1
      return params
    end

    def run(content, params={})
      if !(/§|&sect;|Art\.|\/[0-9][0-9](?![0-9\/])| [0-9][0-9]?[\/\.][0-9][0-9](?![0-9\.])|[0-9][0-9], / =~ content)
        # nothing to replace
        return content
      else
        params = set_params(params)
        return DeJureIntegrator(content.strip, params)
      end
    end

    def DeJureIntegrator (text, params={})
      prot = 'http://'
      host = 'rechtsnetz.dejure.org'
      path = '/dienste/vernetzung/vernetzen'
      uri  = URI(prot + host + path)

      http     = Net::HTTP.new(uri.host, uri.port)
      request  = Net::HTTP::Post.new(uri.request_uri)
      request['User-Agent']   = params[:Anbieterkennung] + ' (DeJureIntegrator for nanoc ruby-' + params[:version] + ')'
      request['Content-Type'] = 'application/x-www-form-urlencoded'

      formdata = params
      formdata['Originaltext'] = text
      request.set_form_data(formdata)

      response = http.request(request)

      if (response.code != '200')  || response.body.nil? || (text.length > response.body.length)
        # HTTP error, empty body or response body smaller than original text
        printf("DeJureIntegrator HTTP error: %s\n", response.code)
        return text
      else
        return IntegrityCheck(text,response.body.force_encoding('UTF-8'))
      end
    end

  def IntegrityCheck (input,output)
    # compare input and output text after removing all added links - texts should match!
    regexp = /<a href="http:\/\/dejure.org\/[^>]*>([^<]*)<\/a>/i
    if input.strip.gsub(regexp, '\\1') == output.strip.gsub(regexp, '\\1')
      return output
    else
      # texts don't match 
      puts "DeJureIntegrator integrity error\n"
      return input
    end
  end

  end
end
