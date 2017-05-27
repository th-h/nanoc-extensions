# nanoc extensions

*[nanoc](http://nanoc.ws/)* is a popular *static site generator*.

I'll add some little extensions for *nanoc* (v3) here.

## filters

### abbreviations.rb

Simple *nanoc* filter to add `<abbr>` tags.

After reading a YAML document from `/content/_data/abbreviations.yam`,
all occurences of each $abbrev are replaced by a
`<abbr title="$abbrev">$fulltext</abbr>` construct.

The filter currently uses a very naive - and time consuming - regexp approach.

The abbreviations dictionay in `/content/_data/abbreviations.yaml` has to
look like this:

    ---
	  abbreviations:
	  - abbrev: HTML
      fulltext: HyperText Markup Language

You'll need a (compile and) routing rule to stop the `abbreviations.yaml`
from being rendered and compiled, i.e. like this:

    # ignore everything starting with _
    compile %r{/_} do
      nil
    end
    route %r{/_} do
      nil
    end

### dejure.rb

*nanoc* filter implementation of the *dejure.org*
[legal integration service](https://dejure.org/vernetzung.html).

    filter :dejure,
      format: 'weit',
      buzer: 1,
      noheadings: 0,
      target: '_blank',
      class: 'dejure'
