# dejure.rb
# A nanoc filter for the dejure.org legal integration service
# See <https://dejure.org/vernetzung.html>
#
# Adapted from the PHP reference implementation
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
# params[:format]      -> [weit|schmal]          (weit)
# params[:buzer]       -> fallback to buzer.de?  (1)
# params[:target]      -> target for <a href>    ('')
# params[:class]       -> CSS class for <a href> ('')
# params[:cache_days]  -> cache validity in days (7)

require 'net/http'
require 'digest'

module Nanoc::Filters
  class DejureAutolinker < Nanoc::Filter
  	identifier :dejure
  	type :text

    VERSION   = '0.3-beta'
    CACHEDIR  = 'tmp/dejure-org'
    CACHEDAYS = 7

    def run(input, params={})
      if !(/§|&sect;|Art\.|\/[0-9][0-9](?![0-9\/])| [0-9][0-9]?[\/\.][0-9][0-9](?![0-9\.])|[0-9][0-9], / =~ input)
        # nothing to replace
        return input
      end
      # set cache validity in days from params or set a default
      cache_days = params.delete(:cache_days)
      if cache_days.nil?
        cache_days = CACHEDAYS
      end
      # return output if it's already cached
      if !(output = cache_read(input.strip,cache_days))
        # purge cache if a purge is due
        puts "DejureAutolinker cache purged!\n" if cache_purge(cache_days)
        # call out to dejure.org
        output = call_dejure(input.strip, set_params(params))
      end
      # do an integrity check
      return integrity_check(input,output)
    end

    def set_params (params)
      # set default params
      params[:version]            = VERSION
      if !@config[:base_url].nil?
        params[:Anbieterkennung]  = @config[:base_url]
      else
        params[:Anbieterkennung] = 'http://unknown.nanoc.installation.invalid'
      end
      params[:format]           ||= 'weit'
      params[:buzer]            ||= 1
      return params
    end

    def call_dejure (input, params={})
      prot = 'https://'
      host = 'rechtsnetz.dejure.org'
      path = '/dienste/vernetzung/vernetzen'
      uri  = URI(prot + host + path)

      http     = Net::HTTP.new(uri.host)
      request  = Net::HTTP::Post.new(uri.request_uri)
      request['User-Agent']   = params[:Anbieterkennung] + ' (DejureAutolinker for nanoc ruby-' + params[:version] + ')'
      request['Content-Type'] = 'application/x-www-form-urlencoded'

      formdata = params
      formdata['Originaltext'] = input
      request.set_form_data(formdata)

      response = http.request(request)

      if (response.code != '200')  || response.body.nil? || (input.length > response.body.length)
        # HTTP error, empty body or response body smaller than original text
        printf("DejureAutolinker HTTP error: %s\n", response.code)
        return input
      else
        output = response.body.force_encoding('UTF-8').strip
        # write cache
        cache_write(input,output)
        return output
      end
    end

    def cache_filename (input)
      # filename is created from length and MD5 of input;
      return input.length.to_s + Digest::MD5.hexdigest(input)
    end
 
     def cache_age (cache_days)
      return (Time.now.to_i - cache_days*86400)
    end
  
    def cache_write (input,output,cache_dir=CACHEDIR)
      # create cache_dir, if necessary
      FileUtils.mkdir_p(cache_dir) if !File.exist?(cache_dir)
      # write output to cache file
      cache_file = cache_dir + '/' + cache_filename(input)
      if File.directory?(cache_dir)
        File.open(cache_file, 'w') do |f|
          f.write(output)
        end
      end
    end

    def cache_read (input,cache_days=CACHEDAYS,cache_dir=CACHEDIR)
      cache_file = cache_dir + '/' + cache_filename(input)
      # file exists and is younger than cache_days?
      if File.exist?(cache_file) && File.mtime(cache_file).to_i > cache_age(cache_days)
        return File.read(cache_file)
      else
        return false
      end
    end

    def cache_purge (cache_days=CACHEDAYS,cache_dir=CACHEDIR)
      # cache_dir is not a directory?
      return false if !File.directory?(cache_dir)
      lastpurge = File.read(cache_dir + '/lastpurge') if File.exist?(cache_dir + '/lastpurge')
      # already purged in the last cache_days days?
      return false if lastpurge && lastpurge.to_i > cache_age(cache_days)
      # delete all files in cache_dir older than cache_days
      Pathname.new(cache_dir).children.each do |f|
        f.unlink if File.mtime(f).to_i < cache_age(cache_days)
      end
      # save the time of the purge
      File.open(cache_dir + '/lastpurge', 'w') do |f|
        f.write(Time.now.to_i)
      end
      return true
    end

    def integrity_check (input,output)
      # compare input and output text after removing all added links - texts should match!
      regexp = /<a href="http:\/\/dejure.org\/[^>]*>([^<]*)<\/a>/i
      if input.strip.gsub(regexp, '\\1') == output.strip.gsub(regexp, '\\1')
        return output
      else
        # texts don't match 
        puts "DejureAutolinker integrity error!\n"
        return input
      end
    end

  end
end
