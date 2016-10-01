require 'addressable/template'
module Scorpio
  class Model
    class << self
      inheritable_accessors = [
        [:resource_name, nil],
        [:api_description, nil],
        [:schema_keys, []],
        [:schemas_by_key, {}],
        [:schemas_by_id, {}],
        [:base_url, nil],
      ]
      inheritable_accessors.each do |(accessor, default_value)|
        define_method(accessor) { default_value }
        define_method(:"#{accessor}=") do |value|
          singleton_class.instance_exec(value) do |value_|
            begin
              remove_method(accessor)
            rescue NameError
            end
            define_method(accessor) { value_ }
          end
        end
      end

      def set_api_description(api_description)
        # TODO full validation against google api rest description
        unless api_description.is_a?(Hash)
          raise ArgumentError, "given api description was not a hash; got: #{api_description.inspect}"
        end
        self.api_description = api_description
        (api_description['schemas'] || {}).each do |schema_key, schema|
          unless schema['id']
            raise ArgumentError, "schema #{schema_key} did not contain an id"
          end
          schemas_by_id[schema['id']] = schema
          schemas_by_key[schema_key] = schema
        end
        if resource_name
          resource_api_methods = ((api_description['resources'] || {})[resource_name] || {})['methods'] || {}
          resource_api_methods.each do |method_name, method_desc|
            unless respond_to?(method_name)
              define_singleton_method(method_name) do |attributes = {}|
                call_api_method(method_name, attributes)
              end
            end
          end
        end
        update_instance_accessors
      end

      def update_instance_accessors
        schemas_by_key.select { |k, _| schema_keys.include?(k) }.each do |schema_key, schema|
          unless schema['type'] == 'object'
            raise "schema key #{schema_key} for #{self} is not of type object - type must be object for Scorpio Model to represent this schema" # TODO class
          end
          schema['properties'].each do |property_name, property_schema|
            define_method(property_name) do
              self[property_name]
            end
          end
        end
      end

      def deref_schema(schema)
        schema && schemas_by_id[schema['$ref']] || schema
      end

      MODULES_FOR_JSON_SCHEMA_TYPES = {
        'object' => [Hash],
        'array' => [Array, Set],
        'string' => [String],
        'integer' => [Integer],
        'number' => [Numeric],
        'boolean' => [TrueClass, FalseClass],
        'null' => [NilClass],
      }

      def call_api_method(method_name, attributes = {})
        attributes = Scorpio.stringify_symbol_keys(attributes)
        method_desc = api_description['resources'][self.resource_name]['methods'][method_name]
        http_method = method_desc['httpMethod'].downcase.to_sym
        relative_uri = Addressable::Template.new(method_desc['path']).expand(attributes)
        url = Addressable::URI.parse(base_url) + relative_uri
        response = connection.run_request(http_method, url, nil, nil).tap do |response|
          raise unless response.success?
        end
        response_schema = method_desc['response']
        response_object_to_instances(response.body, response_schema)
      end

      def response_object_to_instances(object, schema)
        schema = deref_schema(schema)
        if schema
          if schemas_by_key.any? { |key, as| as['id'] == schema['id'] && schema_keys.include?(key) }
            new(object)
          elsif schema['type'] == 'object' && MODULES_FOR_JSON_SCHEMA_TYPES['object'].any? { |m| object.is_a?(m) }
            object.map do |key, value|
              schema_for_value = schema['properties'][key] || schema['additionalProperties']
              {key => response_object_to_instances(value, schema_for_value)}
            end.inject({}, &:update)
          elsif schema['type'] == 'array' && MODULES_FOR_JSON_SCHEMA_TYPES['array'].any? { |m| object.is_a?(m) }
            object.map do |element|
              response_object_to_instances(element, schema['items'])
            end
          else
            object
          end
        else
          object
        end
      end
    end

    def initialize(attributes = {}, options = {})
      unless attributes.is_a?(Hash)
        raise(ArgumentError, "attributes must be a hash; got: #{attributes.inspect}")
      end
      @attributes = attributes.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
      unless options.is_a?(Hash)
        raise(ArgumentError, "options must be a hash; got: #{options.inspect}")
      end
      @options = options.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
    end

    attr_reader :attributes
    attr_reader :options

    def [](key)
      @attributes[key]
    end

    def ==(other)
      @attributes == other.instance_eval { @attributes }
    end

    alias eql? ==

    def hash
      @attributes.hash
    end
  end
end
