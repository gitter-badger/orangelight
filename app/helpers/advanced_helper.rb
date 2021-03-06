# Helper methods for the advanced search form
module AdvancedHelper

  # Fill in default from existing search, if present
  # -- if you are using same search fields for basic
  # search and advanced, will even fill in properly if existing
  # search used basic search on same field present in advanced.
  def label_tag_default_for(key)
    if (! params[key].blank?)
      return params[key]
    elsif params["search_field"] == key || guided_context(key)
      return params["q"]
    else
      return nil
    end
  end

  # Is facet value in adv facet search results?
  def facet_value_checked?(field, value)
    BlacklightAdvancedSearch::QueryParser.new(params, blacklight_config).filters_include_value?(field, value)
  end

  def select_menu_for_field_operator
    options = {
      t('blacklight_advanced_search.all') => 'AND',
      t('blacklight_advanced_search.any') => 'OR'
    }.sort

    return select_tag(:op, options_for_select(options,params[:op]), :class => 'input-small')
  end

  # Current params without fields that will be over-written by adv. search,
  # or other fields we don't want.
  def advanced_search_context
    my_params = params.except :page, :commit, :f_inclusive, :q, :search_field, :op, :action, :index, :sort, :controller, :utf8

    my_params.except! *search_fields_for_advanced_search.map { |key, field_def| field_def[:key] }
  end

  def search_fields_for_advanced_search
    @search_fields_for_advanced_search ||= begin
      blacklight_config.search_fields.select { |k,v| v.include_in_advanced_search or v.include_in_advanced_search.nil? }
    end
  end

  def advanced_labels
    labels = []
    search_fields_for_advanced_search.each do |field|
      labels << field[1][:label] 
    end
    labels
  end

  def advanced_key_value
    key_value = []
    search_fields_for_advanced_search.each do |field|
      key_value << [field[1][:label], field[0]]
    end
    key_value    
  end

  # carries over original search field and original guided search fields if user switches to guided search from regular search 
  def guided_field(field_num, default_val)
    if field_num == :f1 && params[:f1].nil? && params[:f2].nil? && params[:f3].nil? && params[:search_field] && search_fields_for_advanced_search[ params[:search_field] ]
      return search_fields_for_advanced_search[ params[:search_field] ].key || default_val
    end
    return params[field_num] || default_val
  end


  # carries over original search query if user switches to guided search from regular search 
  def guided_context(key)
    key == :q1 && params[:f1].nil? && params[:f2].nil? && params[:f3].nil? && params[:search_field] && search_fields_for_advanced_search[ params[:search_field] ]
  end

  # carries over guided search operations if user switches back to guided search from regular search  
  def guided_radio(op_num, op)
    if params[op_num] 
      checked = params[op_num] == op
    else
      checked = op == "AND"
    end

  end

  def is_guided?
    return params[:search_field] == 'guided'
  end
end

module BlacklightAdvancedSearch
  class QueryParser
    include AdvancedHelper
    def keyword_op

      # advanced search uses same operation between all fields AND/OR
      return @params["op"] || "AND" unless is_guided?

      # for guided search add the operations if there are queries to join
      # NOTs get added to the query. Only AND/OR are operations
      @keyword_op = []
      unless @params[:q1].blank? || @params[:q2].blank? || @params[:op2] == "NOT"
        @keyword_op << @params[:op2] if (@params[:f1] != @params[:f2])
      end
      unless @params[:q3].blank? || @params[:op3] == "NOT"
        @keyword_op << @params[:op3] if @params[:f2] != @params[:f3]
      end 
      return @keyword_op
    end

    def keyword_queries
      unless(@keyword_queries)
        @keyword_queries = {}

        return @keyword_queries unless @params[:search_field] == ::AdvancedController.blacklight_config.advanced_search[:url_key] || is_guided?





        if is_guided?

          # spaces need to be stripped from the query because they don't get properly stripped in Solr
          ###### TO GET STARTS WITH TO WORK #######
          q1 = @params[:f1] == "left_anchor" ? @params[:q1].delete(' ') : @params[:q1]
          q2 = @params[:f2] == "left_anchor" ? @params[:q2].delete(' ') : @params[:q2]
          q3 = @params[:f3] == "left_anchor" ? @params[:q3].delete(' ') : @params[:q3]                    
          #########################################


          been_combined = false
          @keyword_queries[@params[:f1]] = q1 unless @params[:q1].blank?
          unless @params[:q2].blank?
            if @keyword_queries.has_key?(@params[:f2])
              @keyword_queries[@params[:f2]] = "(#{@keyword_queries[@params[:f2]]}) " + @params[:op2] + " (#{q2})"
              been_combined = true
            elsif @params[:op2] == "NOT"
              @keyword_queries[@params[:f2]] = "NOT " + q2
            else
              @keyword_queries[@params[:f2]] = q2
            end
          end
          unless @params[:q3].blank?
            if @keyword_queries.has_key?(@params[:f3])
              @keyword_queries[@params[:f3]] = "(#{@keyword_queries[@params[:f3]]})" unless been_combined
              @keyword_queries[@params[:f3]] = "#{@keyword_queries[@params[:f3]]} " + @params[:op3] + " (#{q3})"
            elsif @params[:op3] == "NOT"
              @keyword_queries[@params[:f3]] = "NOT " + q3            
            else
              @keyword_queries[@params[:f3]] = q3
            end
          end     

        # advanced search behavior  
        else
          config.search_fields.each do | key, field_def |
            if ! @params[ key.to_sym ].blank?
              @keyword_queries[ key ] = @params[ key.to_sym ]
            end
          end          
        end  

      end

      return @keyword_queries
    end

  end
end

module BlacklightAdvancedSearch::ParsingNestingParser
  
  def process_query(params,config)
    queries = []
    ops = keyword_op
    keyword_queries.each do |field, query|
      query = query.delete(' ') if field == "left_anchor" 
      queries << ParsingNesting::Tree.parse(query, config.advanced_search[:query_parser]).to_query( local_param_hash(field, config) )
      queries << ops.shift if is_guided?
    end
    is_guided? ? queries.join(' ') : queries.join( ' ' + ops + ' ')
  end
end

module BlacklightAdvancedSearch::CatalogHelperOverride

  def remove_guided_keyword_query(fields, my_params = params)
    my_params = my_params.dup
    fields.each do |guided_field|
      my_params.delete(guided_field)      
    end
    return my_params
  end  
end


module BlacklightAdvancedSearch::RenderConstraintsOverride

  def guided_search(my_params = params)
    constraints = []
    unless my_params[:q1].blank?
      label = search_field_def_for_key(my_params[:f1])[:label]
      query = my_params[:q1]
      #query = 'NOT ' + my_params[:q1] if my_params[:op1] == 'NOT'
      constraints << render_constraint_element(
            label, query,
            :remove =>
              catalog_index_path(remove_guided_keyword_query([:f1, :q1],my_params))
          )
    end
    unless my_params[:q2].blank?
      label = search_field_def_for_key(my_params[:f2])[:label]
      query = my_params[:q2]
      query = 'NOT ' + my_params[:q2] if my_params[:op2] == 'NOT'
      constraints << render_constraint_element(
            label, query,
            :remove =>
              catalog_index_path(remove_guided_keyword_query([:f2, :q2, :op2],my_params))
          )
    end
    unless my_params[:q3].blank?
      label = search_field_def_for_key(my_params[:f3])[:label]
      query = my_params[:q3]
      query = 'NOT ' + my_params[:q3] if my_params[:op3] == 'NOT'
      constraints << render_constraint_element(
            label, query,
            :remove =>
              catalog_index_path(remove_guided_keyword_query([:f3, :q3, :op3],my_params))
          )
    end  
    return constraints      
  end
  #Over-ride of Blacklight method, provide advanced constraints if needed,
  # otherwise call super. Existence of an @advanced_query instance variable
  # is our trigger that we're in advanced mode.
  def render_constraints_query(my_params = params)
    if (@advanced_query.nil? || @advanced_query.keyword_queries.empty? )
      return super(my_params)
    else
      if is_guided?
        content = guided_search
      else
        content = []
        @advanced_query.keyword_queries.each_pair do |field, query|
          label = search_field_def_for_key(field)[:label]
          content << render_constraint_element(
            label, query,
            :remove =>
              catalog_index_path(remove_advanced_keyword_query(field,my_params))
          )
        end
        if (@advanced_query.keyword_op == "OR" &&
            @advanced_query.keyword_queries.length > 1)
          content.unshift content_tag(:span, "Any of:", class:'operator')
          content_tag :span, class: "inclusive_or appliedFilter well" do
            return safe_join(content.flatten, "\n")
          end
        end
      end
      safe_join(content.flatten, "\n")          
    end
  end
end

module BlacklightAdvancedSearch::Controller
  def is_advanced_search? req_params = params
    (req_params[:search_field] == self.blacklight_config.advanced_search[:url_key]) ||
          req_params[:f_inclusive] || req_params[:search_field] == 'guided'
  end
end