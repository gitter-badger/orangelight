
module ApplicationHelper
  # def make_this_a_link options={}
  #   options[:document] # the original document
  #   options[:field] # the field to render
  #   options[:value] # the value of the field

  #   link_to options[:value], options[:value]
  # end

  # Creates link for electronic access URL, works only if one electronic access link.
  # First argument of link_to is optional display text. If null, the second argument
  # (URL) is the display text for the link.

  def urlify args
    args[:document][args[:field]][0] = link_to(args[:document][args[:field]][1],
      args[:document][args[:field]][0], :target => "_blank")
  end

  def wheretofind args
  	args[:document][args[:field]].each_with_index do |location, i|
  		args[:document][args[:field]][i] = link_to("Locate", "http://library.princeton.edu/searchit/map?loc=#{location}&id=#{args[:document]["id"]}", :target => "_blank")
  			# http://library.princeton.edu/locator/index.php?loc=#{location}&id=#{args[:document]["id"]}")
    end
  end

  def locate_link location, bib
    link_to("[Find it]", "http://library.princeton.edu/searchit/map?loc=#{location}&id=#{bib}", :target => "_blank", style: "font-size:10px; font-style:italic")
  end  


  def holding_block args
    args[:document][args[:field]].each_with_index do |call_numb, i|
      block = "Call Number: #{call_numb}<br>"
      block += "Location: #{args[:document]['location'][i]}"
      findit = locate_link(args[:document]['location_code_s'][i], args[:document]['id'])
      block += " #{findit}<br><br>"
      args[:document][args[:field]][i] = block.html_safe
    end    
  end

  def holding_block_search args
    if args[:document][args[:field]].size > 2
      return "Multiple Holdings"
    else
      args[:document][args[:field]].each_with_index do |call_numb, i|
        block = "Call Number: #{call_numb}<br>"
        block += "Location: #{args[:document]['location'][i]}"
        findit = locate_link(args[:document]['location_code_s'][i], args[:document]['id'])
        block += " #{findit}<br><br>"
        args[:document][args[:field]][i] = block.html_safe
      end    
    end
  end

  # def relatedor args
  #   args[:document][args[:field]].each_with_index do |related_name, i|
  #     args[:document][args[:field]][i] = "#{args[:document]['marc_relatedor_display'][i]}: #{related_name}"
  #   end
  # end

  SEPARATOR = '—'
  QUERYSEP = '—'
  def subjectify args

    all_subjects = []
    sub_array = []
    args[:document][args[:field]].each_with_index do |subject, i|
      spl_sub = subject.split(QUERYSEP)
      sub_array << []
      subjectaccum = ''
      spl_sub.each_with_index do |subsubject, j|
        spl_sub[j] = subjectaccum + subsubject
        subjectaccum = spl_sub[j] + QUERYSEP 
        sub_array[i] << spl_sub[j]
      end
      all_subjects[i] = subject.split(QUERYSEP)
    end
    linked_subsubjects = ''
    args[:document][args[:field]].each_with_index do |subject, i|    
      lnk = ''
      lnk_accum = ''
      full_sub = ''
      all_subjects[i].each_with_index do |subsubject, j|
        lnk = lnk_accum + link_to(subsubject,
          "/?f[subject_topic_facet][]=#{sub_array[i][j]}")
        lnk_accum = lnk + SEPARATOR
        full_sub = sub_array[i][j]
      end
      lnk += '  '
      lnk += link_to('[Browse]', "/browse/subjects?q=#{full_sub}", style: "font-size:10px; font-style:italic")
      args[:document][args[:field]][i] = lnk.html_safe        
    end


  end

  def browse_name args
    args[:document][args[:field]].each_with_index do |name, i|
      newname = link_to(name, "/?f[author_s][]=#{name}") + '  ' + link_to('[Browse]', "/browse/names?q=#{name}", style: "font-size:10px; font-style:italic")
      args[:document][args[:field]][i] = newname.html_safe
    end
  end

  def browse_related_name args
    args[:document][args[:field]].each_with_index do |name, i|
      rel_term =  /^.*：/.match(name) ? /^.*：/.match(name)[0] : ''
      rel_name = name.gsub(/^.*：/,'')
      newname = rel_term + link_to(rel_name, "/?f[author_s][]=#{rel_name}") + '  ' + link_to('[Browse]', "/browse/names?q=#{rel_name}", style: "font-size:10px; font-style:italic")
      args[:document][args[:field]][i] = newname.html_safe
    end
  end



  def multiple_locations args
    if args[:document][args[:field]][1] 
      args[:document][args[:field]] = ["Multiple Locations"]
    else
      args[:document][args[:field]][0]
    end
  end

end
