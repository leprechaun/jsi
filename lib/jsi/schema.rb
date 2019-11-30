require 'jsi/json/node'

module JSI
  # JSI::Schema represents a JSON Schema. initialized from a Hash-like schema
  # object, JSI::Schema is a relatively simple class to abstract useful methods
  # applied to a JSON Schema.
  class Schema
    include Memoize

    class << self
      # @param schema_object [#to_hash, Boolean, JSI::Schema] an object to be instantiated as a schema.
      #   if it's already a schema, it is returned as-is.
      # @return [JSI::Schema]
      def from_object(schema_object)
        if schema_object.is_a?(Schema)
          schema_object
        else
          new(schema_object)
        end
      end
    end

    # initializes a schema from a given JSI::Base, JSI::JSON::Node, or hash. Boolean schemas are
    # instantiated as their equivalent hash ({} for true and {"not" => {}} for false).
    #
    # @param schema_object [JSI::Base, #to_hash, Boolean] the schema
    def initialize(schema_object)
      if schema_object.is_a?(JSI::Schema)
        raise(TypeError, "will not instantiate Schema from another Schema: #{schema_object.pretty_inspect.chomp}")
      elsif schema_object.is_a?(JSI::PathedNode)
        @schema_node = JSI.deep_stringify_symbol_keys(schema_object.deref)
      elsif schema_object.respond_to?(:to_hash)
        @schema_node = JSI::JSON::Node.new_doc(JSI.deep_stringify_symbol_keys(schema_object))
      elsif schema_object == true
        @schema_node = JSI::JSON::Node.new_doc({})
      elsif schema_object == false
        @schema_node = JSI::JSON::Node.new_doc({"not" => {}})
      else
        raise(TypeError, "cannot instantiate Schema from: #{schema_object.pretty_inspect.chomp}")
      end
    end

    # @return [JSI::PathedNode] a JSI::PathedNode (JSI::JSON::Node or JSI::Base) for the schema
    attr_reader :schema_node

    alias_method :schema_object, :schema_node

    # @return [JSI::Base, JSI::JSON::Node, Object] property value from the schema_object
    # @param property_name [String, Object] property name to access from the schema_object
    def [](property_name)
      schema_object[property_name]
    end

    # @return [String] an absolute id for the schema, with a json pointer fragment
    def schema_id
      @schema_id ||= begin
        # start from schema_node and ascend parents looking for an 'id' property.
        # append a fragment to that id (appending to an existing fragment if there
        # is one) consisting of the path from that parent to our schema_node.
        node_for_id = schema_node
        path_from_id_node = []
        done = false

        while !done
          # TODO: track what parents are schemas. somehow.
          # look at 'id' if node_for_id is a schema, or the document root.
          # decide whether to look at '$id' for all parent nodes or also just schemas.
          if node_for_id.respond_to?(:to_hash)
            if node_for_id.node_ptr.root? || node_for_id.object_id == schema_node.object_id
              # I'm only looking at 'id' for the document root and the schema node
              # until I track what parents are schemas.
              parent_id = node_for_id['$id'] || node_for_id['id']
            else
              # will look at '$id' everywhere since it is less likely to show up outside schemas than
              # 'id', but it will be better to only look at parents that are schemas for this too.
              parent_id = node_for_id['$id']
            end
          end

          if parent_id || node_for_id.node_ptr.root?
            done = true
          else
            path_from_id_node.unshift(node_for_id.node_ptr.reference_tokens.last)
            node_for_id = node_for_id.parent_node
          end
        end
        if parent_id
          parent_auri = Addressable::URI.parse(parent_id)
        else
          node_for_id = schema_node.document_root_node
          validator = ::JSON::Validator.new(Typelike.as_json(node_for_id), nil)
          # TODO not good instance_exec'ing into another library's ivars
          parent_auri = validator.instance_exec { @base_schema }.uri
        end
        if parent_auri.fragment
          # add onto the fragment
          parent_id_path = JSI::JSON::Pointer.from_fragment('#' + parent_auri.fragment).reference_tokens
          path_from_id_node = parent_id_path + path_from_id_node
          parent_auri.fragment = nil
        #else: no fragment so parent_id good as is
        end

        fragment = JSI::JSON::Pointer.new(path_from_id_node).fragment
        schema_id = parent_auri.to_s + fragment

        schema_id
      end
    end

    # @return [Class subclassing JSI::Base] shortcut for JSI.class_for_schema(schema)
    def jsi_schema_class
      JSI.class_for_schema(self)
    end

    alias_method :schema_class, :jsi_schema_class

    # calls #new on the class for this schema with the given arguments. for parameters,
    # see JSI::Base#initialize documentation.
    #
    # @return [JSI::Base] a JSI whose schema is this schema and whose instance is the given instance
    def new_jsi(other_instance, *a, &b)
      jsi_schema_class.new(other_instance, *a, &b)
    end

    # if this schema is a oneOf, allOf, anyOf schema, #match_to_instance finds
    # one of the subschemas that matches the given instance and returns it. if
    # there are no matching *Of schemas, this schema is returned.
    #
    # @param other_instance [Object] the instance to which to attempt to match *Of subschemas
    # @return [JSI::Schema] a matched subschema, or this schema (self)
    def match_to_instance(other_instance)
      # matching oneOf is good here. one schema for one instance.
      # matching anyOf is okay. there could be more than one schema matched. it's often just one. if more
      #   than one is a match, you just get the first one.
      %w(oneOf anyOf).select { |k| schema_node[k].respond_to?(:to_ary) }.each do |someof_key|
        schema_node[someof_key].map(&:deref).map do |someof_node|
          someof_schema = self.class.new(someof_node)
          if someof_schema.validate_instance(other_instance)
            return someof_schema.match_to_instance(other_instance)
          end
        end
      end
      return self
    end

    # @param property_name_ [String] the property for which to find a subschema
    # @return [JSI::Schema, nil] a subschema from `properties`,
    #   `patternProperties`, or `additionalProperties` for the given
    #    property_name
    def subschema_for_property(property_name_)
      memoize(:subschema_for_property, property_name_) do |property_name|
        if schema_object['properties'].respond_to?(:to_hash) && schema_object['properties'][property_name].respond_to?(:to_hash)
          self.class.new(schema_object['properties'][property_name])
        else
          if schema_object['patternProperties'].respond_to?(:to_hash)
            _, pattern_schema_object = schema_object['patternProperties'].detect do |pattern, _|
              property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
            end
          end
          if pattern_schema_object
            self.class.new(pattern_schema_object)
          else
            if schema_object['additionalProperties'].respond_to?(:to_hash)
              self.class.new(schema_object['additionalProperties'])
            else
              nil
            end
          end
        end
      end
    end

    # @param index_ [Integer] the index for which to find a subschema
    # @return [JSI::Schema, nil] a subschema from `items` or
    #   `additionalItems` for the given index
    def subschema_for_index(index_)
      memoize(:subschema_for_index, index_) do |index|
        if schema_object['items'].respond_to?(:to_ary)
          if index < schema_object['items'].size
            self.class.new(schema_object['items'][index])
          elsif schema_object['additionalItems'].respond_to?(:to_hash)
            self.class.new(schema_object['additionalItems'])
          end
        elsif schema_object['items'].respond_to?(:to_hash)
          self.class.new(schema_object['items'])
        else
          nil
        end
      end
    end

    # @return [Set] any object property names this schema indicates may be
    #   present on its instances. this includes, if present: keys of this
    #   schema's "properties" object; entries of this schema's array of
    #   "required" property keys. if this schema has allOf subschemas, those
    #   schemas are checked (recursively) for their described object property names.
    def described_object_property_names
      memoize(:described_object_property_names) do
        Set.new.tap do |property_names|
          if schema_node['properties'].respond_to?(:to_hash)
            property_names.merge(schema_node['properties'].keys)
          end
          if schema_node['required'].respond_to?(:to_ary)
            property_names.merge(schema_node['required'].to_ary)
          end
          # we should look at dependencies (TODO).
          if schema_node['allOf'].respond_to?(:to_ary)
            schema_node['allOf'].map(&:deref).map do |allOf_node|
              property_names.merge(self.class.new(allOf_node).described_object_property_names)
            end
          end
        end
      end
    end

    # @return [Array<String>] array of schema validation error messages for
    #   the given instance against this schema
    def fully_validate_instance(other_instance)
      ::JSON::Validator.fully_validate(JSI::Typelike.as_json(schema_node.node_document), JSI::Typelike.as_json(other_instance), fragment: schema_node.node_ptr.fragment)
    end

    # @return [true, false] whether the given instance validates against this schema
    def validate_instance(other_instance)
      ::JSON::Validator.validate(JSI::Typelike.as_json(schema_node.node_document), JSI::Typelike.as_json(other_instance), fragment: schema_node.node_ptr.fragment)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate the instance is valid against this schema
    # @raise [::JSON::Schema::ValidationError] raises if the instance has
    #   validation errors against this schema
    def validate_instance!(other_instance)
      ::JSON::Validator.validate!(JSI::Typelike.as_json(schema_node.node_document), JSI::Typelike.as_json(other_instance), fragment: schema_node.node_ptr.fragment)
    end

    # @return [Array<String>] array of schema validation error messages for
    #   this schema, validated against its metaschema. a default metaschema
    #   is assumed if the schema does not specify a $schema.
    def fully_validate_schema
      ::JSON::Validator.fully_validate(JSI::Typelike.as_json(schema_node.node_document), [], fragment: schema_node.node_ptr.fragment, validate_schema: true, list: true)
    end

    # @return [true, false] whether this schema validates against its metaschema
    def validate_schema
      ::JSON::Validator.validate(JSI::Typelike.as_json(schema_node.node_document), [], fragment: schema_node.node_ptr.fragment, validate_schema: true, list: true)
    end

    # @return [true] if this method does not raise, it returns true to
    #   indicate this schema is valid against its metaschema
    # @raise [::JSON::Schema::ValidationError] raises if this schema has
    #   validation errors against its metaschema
    def validate_schema!
      ::JSON::Validator.validate!(JSI::Typelike.as_json(schema_node.node_document), [], fragment: schema_node.node_ptr.fragment, validate_schema: true, list: true)
    end

    # @return [String] a string for #instance and #pretty_print including the schema_id
    def object_group_text
      "schema_id=#{schema_id}"
    end

    # @return [String] a string representing this Schema
    def inspect
      "\#<#{self.class.inspect} #{object_group_text} #{schema_object.inspect}>"
    end
    alias_method :to_s, :inspect

    # pretty-prints a representation this Schema to the given printer
    # @return [void]
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#<#{obj.class.inspect} #{obj.object_group_text}"
        group_sub {
          nest(2) {
            breakable ' '
            pp obj.schema_object
          }
        }
        breakable ''
        text '>'
      end
    end

    # @return [Object] returns a jsonifiable representation of this schema
    def as_json(*opt)
      Typelike.as_json(schema_object, *opt)
    end

    # @return [Object] an opaque fingerprint of this Schema for FingerprintHash
    def fingerprint
      {class: self.class, schema_ptr: schema_node.node_ptr, schema_document: JSI::Typelike.as_json(schema_node.node_document)}
    end
    include FingerprintHash
  end
end
