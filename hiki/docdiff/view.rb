#!/usr/bin/ruby

class String
  def scan_lines(eol)
    case eol
    when nil then    scan(/\A.*\Z/m)
    when "CR" then   scan(/.*?\r|[^\r]+\Z/m)
    when "LF" then   scan(/.*?\n|[^\n]+\Z/m)
    when "CRLF" then scan(/.*?\r\n|.+\Z/m)
    else raise "#{eol} is not supported.\n"
    end
  end
  def scan_eols(eol)
    case eol
    when nil then    []
    when "CR" then   scan(/\r/m)
    when "LF" then   scan(/\n/m)
    when "CRLF" then scan(/\r\n/m)
    else raise "#{eol} is not supported.\n"
    end
  end
end

class View

#  EOL_CHARS_PAT = Regexp.new(/\r\n|\r(?!\n)|(?:\A|[^\r])\n/m)

  def initialize(difference, encoding, eol)
    @difference = difference
    @encoding = encoding
    @eol = eol
    @eol_char = {'CR'=>"\r", 'LF'=>"\n", 'CRLF'=>"\r\n"}[@eol]
#     if CharString::EOLChars[@eol]
#       @eol_char = CharString::EOLChars[@eol].eol_char
#     else
#       @eol_char = nil
#     end
  end

  def apply_style(tags, headfoot = true)
    result = []
    @difference.each{|block|
      operation = block.first
      if block_given?
        source = yield block[1].to_s
        target = yield block[2].to_s
      else
        source = block[1].to_s
        target = block[2].to_s
      end
      case operation
      when :common_elt_elt
        result << (
          tags[:start_common] +
          source.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} +
          tags[:end_common]
        )
      when :change_elt
        result << (tags[:start_before_change] + 
          source.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
                   tags[:end_before_change] + 
                   tags[:start_after_change] + 
          target.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
                   tags[:end_after_change])
      when :del_elt
        result << (tags[:start_del] +
          source.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
          tags[:end_del]
        )
      when :add_elt
        result << (tags[:start_add] +
          target.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
          tags[:end_add]
        )
      else
        raise "invalid attribute: #{block.first}\n"
      end
    }
    if headfoot == true
      result = tags[:header] + result + tags[:footer]
    end
    result.delete_if{|elem|elem==''}
  end
  def apply_style_digest(tags, headfoot = true)
    result = []
    doc1_lnum = 1
    doc2_lnum = 1
    @difference.each_with_index{|block, i|
      operation = block.first
      if block_given?
        source = yield block[1].to_s
        target = yield block[2].to_s
      else
        source = block[1].to_s
        target = block[2].to_s
      end
      span1 = source_lines_involved = source.scan_lines(@eol).size
      span2 = target_lines_involved = target.scan_lines(@eol).size
      pos = ""

      case
      when i == 0 then prefix = ""
      else prefix = @difference[i-1][1].to_s.scan(prefix_pat).to_s
      end
      case
      when (i + 1) == @difference.size then postfix = ""
      else postfix = @difference[i+1][1].to_s.scan(postfix_pat).to_s
      end

      case operation
      when :common_elt_elt
      when :change_elt
        pos += "#{doc1_lnum}"
        pos += "-#{doc1_lnum + span1 - 1}" if span1 > 1
        pos += ",#{doc2_lnum}"
        pos += "-#{doc2_lnum + span2 - 1}" if span2 > 1
        result << (
          tags[:start_entry] + 
          tags[:start_position] + pos + tags[:end_position] + 
          tags[:start_prefix] + prefix.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} + tags[:end_prefix] +
          tags[:start_before_change] +
          source.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
          tags[:end_before_change] + 
          tags[:start_after_change] +
          target.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
          tags[:end_after_change] +
          tags[:start_postfix] + postfix.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} + tags[:end_postfix] +
          tags[:end_entry] + (@eol_char||"")
        )
      when :del_elt
        pos += "#{doc1_lnum}"
        pos += "-#{doc1_lnum + span1 - 1}" if span1 > 1
        pos += ",(#{doc2_lnum})"
        result << (
          tags[:start_entry] +
          tags[:start_position] + pos + tags[:end_position] +
          tags[:start_prefix] + prefix.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} + tags[:end_prefix] +
          tags[:start_del] +
          source.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
          tags[:end_del] + 
          tags[:start_postfix] + postfix.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} + tags[:end_postfix] +
          tags[:end_entry] + (@eol_char||"")
        )
      when :add_elt
        pos += "(#{doc1_lnum})"
        pos += ",#{doc2_lnum}"
        pos += "-#{doc2_lnum + span2 - 1}" if span2 > 1
        result << (
          tags[:start_entry] +
          tags[:start_position] + pos + tags[:end_position] +
          tags[:start_prefix] + prefix.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} + tags[:end_prefix] +
          tags[:start_add] +
          target.gsub(tags[:inside_escape_pat]){|m| tags[:inside_escape_dic][m]} +
          tags[:end_add] +
          tags[:start_postfix] + postfix.gsub(tags[:outside_escape_pat]){|m| tags[:outside_escape_dic][m]} + tags[:end_postfix] +
          tags[:end_entry] + (@eol_char||"")
        )
      else
        raise "invalid attribute: #{block.first}\n"
      end
      doc1_lnum += source.scan_eols(@eol).size
      doc2_lnum += target.scan_eols(@eol).size
    }
    result.unshift(tags[:start_digest_body])
    result.push(tags[:end_digest_body])
    if headfoot == true
      result = tags[:header] + result + tags[:footer]
    end
    result.delete_if{|elem|elem==''}
  end

  def source_lines()
    if @source_lines == nil
      @source_lines = @difference.collect{|entry| entry[1]}.join.scan_lines(@eol)
    end
    @source_lines
  end
  def target_lines()
    if @target_lines == nil
      @target_lines = @difference.collect{|entry| entry[2]}.join.scan_lines(@eol)
    end
    @target_lines
  end
  PREFIX_LENGTH = 16
  POSTFIX_LENGTH = 16
  def prefix_pat()
    Regexp.new('.{0,'+"#{PREFIX_LENGTH}"+'}\Z', Regexp::MULTILINE,
               @encoding.sub(/ASCII/i, 'none'))
  end
  def postfix_pat()
    Regexp.new('\A.{0,'+"#{POSTFIX_LENGTH}"+'}', Regexp::MULTILINE,
               @encoding.sub(/ASCII/i, 'none'))
  end

  # tty (terminal)
  def tty_header()
    []
  end
  def tty_footer()
    []
  end
  TTYEscapeDic = {'ThisRandomString' => 'ThisRandomString'}
  TTYEscapePat = /(\r\n|#{TTYEscapeDic.keys.collect{|k|Regexp.quote(k)}.join('|')})/m
  def tty_tags()
    {:outside_escape_dic  => TTYEscapeDic,
     :outside_escape_pat  => TTYEscapePat,
     :inside_escape_dic   => TTYEscapeDic,
     :inside_escape_pat   => TTYEscapePat,
     :start_digest_body   => "----#{@eol_char||''}",
     :end_digest_body     => '',
     :start_entry         => '',
     :end_entry           => "#{@eol_char||''}----",
     :start_position      => '',
     :end_position        => "#{@eol_char||''}",
     :start_prefix        => '',
     :end_prefix          => '',
     :start_postfix       => '',
     :end_postfix         => '',
     :header              => tty_header(),
     :footer              => tty_footer(),
     :start_common        => '',
     :end_common          => '',
     :start_del           => "\033[7;4;31m",  # Inverted, Underlined, Red
     :end_del             => "\033[0m",
     :start_add           => "\033[7;1;34m",  # Inverted, Bold, Blue
     :end_add             => "\033[0m",
     :start_before_change => "\033[7;4;33m",  # Inverted, Underlined, Yellow
     :end_before_change   => "\033[0m",
     :start_after_change  => "\033[7;1;32m",  # Inverted, Bold, Green
     :end_after_change    => "\033[0m"}
  end
  def to_tty(overriding_tags = nil, headfoot = true)  # color escape sequence
    tags = tty_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style(tags, headfoot)
  end
  def to_tty_digest(overriding_tags = nil, headfoot = true)
    tags = tty_tags
    tags.update(overriding_tags) if overriding_tags
    apply_style_digest(tags, headfoot)
  end

  # HTML (XHTML)
  def html_header()
    ["<?xml version=\"1.0\" encoding=\"#{@encoding||''}\"?>#{@eol_char||''}",
     "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"#{@eol_char||''}",
     "\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">#{@eol_char||''}",
     "<html><head>#{@eol_char||''}",
     "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=#{@encoding||''}\" />#{@eol_char||''}",
     "<title>Difference</title>#{@eol_char||''}",
     "<style type=\"text/css\">#{@eol_char||''}" +
     " body {font-family: monospace;}#{@eol_char||''}" +
     " span.del {background: hotpink; border: thin inset;}#{@eol_char||''}" +
     " span.add {background: deepskyblue; font-weight: bolder; border: thin outset;}#{@eol_char||''}" +
     " span.before_change {background: yellow; border: thin inset;}#{@eol_char||''}" +
     " span.after_change {background: lime; font-weight: bolder; border: thin outset;}#{@eol_char||''}" +
     " li.entry .position {font-weight: bolder; margin-top: 0em; margin-bottom: 0em; padding-top: 0em; padding-bottom: 0em;}#{@eol_char||''}" +
     " li.entry .body {margin-top: 0em; margin-bottom: 0em; padding-top: 0em; padding-bottom: 0em;}#{@eol_char||''}" +
     "</style>#{@eol_char||''}",
     "</head><body>#{@eol_char||''}"]
  end
  def html_footer()
    [(@eol_char||"") + '</body></html>' + (@eol_char||"")]
  end
  HTMLEscapeDic = {'<'=>'&lt;', '>'=>'&gt;', '&'=>'&amp;', '  '=>'&nbsp;&nbsp;',
                   "\r\n" => "<br />\r\n", "\r" => "<br />\r", "\n" => "<br />\n"}
  HTMLEscapePat = /(\r\n|#{HTMLEscapeDic.keys.collect{|k|Regexp.quote(k)}.join('|')})/m
  def html_tags()
    {:outside_escape_dic  => HTMLEscapeDic,
     :outside_escape_pat  => HTMLEscapePat,
     :inside_escape_dic   => HTMLEscapeDic,
     :inside_escape_pat   => HTMLEscapePat,
     :start_digest_body   => '<ul><hr />',
     :end_digest_body     => '</ul>',
     :start_entry         => '<li class="entry">',
     :end_entry           => '</p></blockquote></li><hr />',
     :start_position      => '<p class="position">',
     :end_position        => '</p><blockquote class="body"><p class="body">',
     :start_prefix        => '',
     :end_prefix          => '',
     :start_postfix       => '',
     :end_postfix         => '',
     :header              => html_header(),
     :footer              => html_footer(),
     :start_common        => '<span class="common">',
     :end_common          => '</span>',
     :start_del           => '<span class="del"><del>',
     :end_del             => '</del></span>',
     :start_add           => '<span class="add"><ins>',
     :end_add             => '</ins></span>',
     :start_before_change => '<span class="before_change"><del>',
     :end_before_change   => '</del></span>',
     :start_after_change  => '<span class="after_change"><ins>',
     :end_after_change    => '</ins></span>'}
  end
  def to_html(overriding_tags = nil, headfoot = true)
    tags = html_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style(tags, headfoot)
  end
  def to_html_digest(overriding_tags = nil, headfoot = true)
    tags = html_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style_digest(tags, headfoot)
  end

  # Manued
  def manued_header()
    ["defparentheses [ ]"        + (@eol_char||"\n"),
     "defdelete      /"          + (@eol_char||"\n"),
     "defswap        |"          + (@eol_char||"\n"),
     "defcomment     ;"          + (@eol_char||"\n"),
     "defescape      ~"          + (@eol_char||"\n"),
     "deforder       newer-last" + (@eol_char||"\n"),
     "defversion     0.9.5"      + (@eol_char||"\n")]
  end
  def manued_footer()
    []
  end
  ManuedInsideEscapeDic = {'~'=>'~~', '/'=>'~/', '['=>'~[', ']'=>'~]', ';'=>'~;'}
  ManuedInsideEscapePat = /(#{ManuedInsideEscapeDic.keys.collect{|k|Regexp.quote(k)}.join('|')})/m
  ManuedOutsideEscapeDic = {'~'=>'~~', '['=>'~['}
  ManuedOutsideEscapePat = /(#{ManuedOutsideEscapeDic.keys.collect{|k|Regexp.quote(k)}.join('|')})/m
  def manued_tags()
    {:inside_escape_dic   => ManuedInsideEscapeDic, 
     :inside_escape_pat   => ManuedInsideEscapePat,
     :outside_escape_dic  => ManuedOutsideEscapeDic,
     :outside_escape_pat  => ManuedOutsideEscapePat,
     :start_digest_body   => "----#{@eol_char||''}",
     :end_digest_body     => '',
     :start_entry         => '',
     :end_entry           => "#{@eol_char||''}----",
     :start_position      => '',
     :end_position        => "#{@eol_char||''}",
     :start_prefix        => '',
     :end_prefix          => '',
     :start_postfix       => '',
     :end_postfix         => '',
     :header              => manued_header(),
     :footer              => manued_footer(),
     :start_common        => '',
     :end_common          => '',
     :start_del           => '[',
     :end_del             => '/]',
     :start_add           => '[/',
     :end_add             => ']',
     :start_before_change => '[',
     :end_before_change   => '/',
     :start_after_change  => '',
     :end_after_change    => ']'
    }
  end
  def to_manued(overriding_tags = nil, headfoot = true)  # [ / ; ]
    tags = manued_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style(tags, headfoot)
  end
  def to_manued_digest(overriding_tags = nil, headfoot = true)  # [ / ; ]
    tags = manued_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style_digest(tags, headfoot)
  end

  # wdiff-like
  def wdiff_header()
    []
  end
  def wdiff_footer()
    []
  end
  WDIFFEscapeDic = {'ThisRandomString' => 'ThisRandomString'}
  WDIFFEscapePat = /(\r\n|#{WDIFFEscapeDic.keys.collect{|k|Regexp.quote(k)}.join('|')})/m
  def wdiff_tags()
    {:outside_escape_dic  => WDIFFEscapeDic,
     :outside_escape_pat  => WDIFFEscapePat,
     :inside_escape_dic   => WDIFFEscapeDic,
     :inside_escape_pat   => WDIFFEscapePat,
     :start_digest_body   => "----#{@eol_char||''}",
     :end_digest_body     => '',
     :start_entry         => '',
     :end_entry           => "#{@eol_char||''}----",
     :start_position      => '',
     :end_position        => "#{@eol_char||''}",
     :start_prefix        => '',
     :end_prefix          => '',
     :start_postfix       => '',
     :end_postfix         => '',
     :header              => wdiff_header(),
     :footer              => wdiff_footer(),
     :start_common        => '',
     :end_common          => '',
     :start_del           => '[-',
     :end_del             => '-]',
     :start_add           => '{+',
     :end_add             => '+}',
     :start_before_change => '[-',
     :end_before_change   => '-]',
     :start_after_change  => '{+',
     :end_after_change    => '+}'}
  end
  def to_wdiff(overriding_tags = nil, headfoot = true)
    tags = wdiff_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style(tags)
  end
  def to_wdiff_digest(overriding_tags = nil, headfoot = true)
    tags = wdiff_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style_digest(tags, headfoot)
  end

  # user defined markup
  def user_header(); []; end
  def user_footer(); []; end
  UserEscapeDic = {'ThisRandomString' => 'ThisRandomString'}
  UserEscapePat = /(\r\n|#{UserEscapeDic.keys.collect{|k|Regexp.quote(k)}.join('|')})/m
  def user_tags()
    {:outside_escape_dic  => UserEscapeDic,
     :outside_escape_pat  => UserEscapePat,
     :inside_escape_dic   => UserEscapeDic,
     :inside_escape_pat   => UserEscapePat,
     :start_digest_body   => '',
     :end_digest_body     => '',
     :start_entry         => '',
     :end_entry           => '',
     :start_position      => '',
     :end_position        => ' ',
     :start_prefix        => '',
     :end_prefix          => '',
     :start_postfix       => '',
     :end_postfix         => '',
     :header              => user_header(),
     :footer              => user_footer(),
     :start_common        => '',
     :end_common          => '',
     :start_del           => '',
     :end_del             => '',
     :start_add           => '',
     :end_add             => '',
     :start_before_change => '',
     :end_before_change   => '',
     :start_after_change  => '',
     :end_after_change    => ''}
  end
  def to_user(overriding_tags = nil, headfoot = true)
    tags = user_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style(tags, headfoot)
  end
  def to_user_digest(overriding_tags = nil, headfoot = true)
    tags = user_tags()
    tags.update(overriding_tags) if overriding_tags
    apply_style_digest(tags, headfoot)
  end

  def to_debug()
  end

end