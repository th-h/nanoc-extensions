# abbreviations.rb
# a nanoc filter
# licensed as nanoc itself
#
# add <bbrev> tags for all known abbreviations by a
# very naive - and time consuming - regexp matchingA
#
# data source: YAML file in /content/_data/abbreviations
#
module Nanoc::Filters
  class Abbreviations < Nanoc::Filter
  	identifier :abbrev
  	type :text

    def run(content, params={})
      output = content;
  		@items['/_data/abbreviations/'][:abbreviations].each do |a|
        output = output.gsub(/(\s|[-,.;:"'!?>\(\[]+)#{a[:abbrev]}(\s|[-,.;:"'!?<\)\]]+)/,'\\1<abbr title="' + a[:fulltext] + '">' + a[:abbrev]+ '</abbr>\\2')
      end
      return output       
    end
  end
end
