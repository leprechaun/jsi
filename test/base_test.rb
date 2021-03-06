require_relative 'test_helper'

NamedSchemaInstance = JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/base/named_schema'}).jsi_schema_class

# hitting .tap(&:name) causes JSI to assign a constant name from the ID,
# meaning the name NamedSchemaInstanceTwo is not known.
NamedSchemaInstanceTwo = JSI::Schema.new({id: 'https://schemas.jsi.unth.net/test/base/named_schema_two'}).jsi_schema_class.tap(&:name)

describe JSI::Base do
  let(:schema_content) { {} }
  let(:schema) { JSI::Schema.new(schema_content) }
  let(:instance) { {} }
  let(:subject) { schema.new_jsi(instance) }
  describe 'class .inspect' do
    it 'is the same as Class#inspect on the base' do
      assert_equal('JSI::Base', JSI::Base.inspect)
    end
    it 'is (JSI Schema Class) for generated subclass without id' do
      assert_equal("(JSI Schema Class: #)", subject.class.inspect)
    end
    describe 'with schema id' do
      let(:schema_content) { {'id' => 'https://jsi/foo'} }
      it 'is (JSI Schema Class: ...) for generated subclass with id' do
        assert_equal("(JSI Schema Class: https://jsi/foo#)", subject.class.inspect)
      end
    end
    it 'is the constant name plus id for a class assigned to a constant' do
      assert_equal(%q(NamedSchemaInstance (https://schemas.jsi.unth.net/test/base/named_schema#)), NamedSchemaInstance.inspect)
    end
    it 'is not the constant name when the constant name has been generated from the schema_id' do
      assert_equal("JSI::SchemaClasses::Xhttps___schemas_jsi_unth_net_test_base_named_schema_two_", NamedSchemaInstanceTwo.name)
      assert_equal("(JSI Schema Class: https://schemas.jsi.unth.net/test/base/named_schema_two#)", NamedSchemaInstanceTwo.inspect)
    end
  end
  describe 'class name' do
    let(:schema_content) { {'id' => 'https://jsi/BaseTest'} }
    it 'generates a class name from schema_id' do
      assert_equal('JSI::SchemaClasses::Xhttps___jsi_BaseTest_', subject.class.name)
    end
    it 'uses an existing name' do
      assert_equal('NamedSchemaInstance', NamedSchemaInstance.name)
    end
  end
  describe 'class for schema .schema' do
    it '.schema' do
      assert_equal(schema, JSI.class_for_schema(schema).schema)
    end
  end
  describe 'class for schema .schema_id' do
    it '.schema_id' do
      assert_equal(schema.schema_id, JSI.class_for_schema(schema).schema_id)
    end
  end
  describe 'module for schema .inspect' do
    it '.inspect' do
      assert_equal("(JSI Schema Module: #)", JSI::SchemaClasses.module_for_schema(schema).inspect)
    end
  end
  describe 'module for schema .schema' do
    it '.schema' do
      assert_equal(schema, JSI::SchemaClasses.module_for_schema(schema).schema)
    end
  end
  describe '.class_for_schema' do
    it 'returns a class from a schema' do
      class_for_schema = JSI.class_for_schema(schema)
      # same class every time
      assert_equal(JSI.class_for_schema(schema), class_for_schema)
      assert_operator(class_for_schema, :<, JSI::Base)
    end
    it 'returns a class from a hash' do
      assert_equal(JSI.class_for_schema(schema), JSI.class_for_schema(schema_content))
    end
  end
  describe 'JSI::SchemaClasses.module_for_schema' do
    it 'returns a module from a schema' do
      module_for_schema = JSI::SchemaClasses.module_for_schema(schema)
      # same module every time
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), module_for_schema)
    end
    it 'returns a module from a hash' do
      assert_equal(JSI::SchemaClasses.module_for_schema(schema), JSI::SchemaClasses.module_for_schema(schema.jsi_instance))
    end
  end
  describe 'initialization' do
    describe 'on Base' do
      it 'errors' do
        err = assert_raises(TypeError) { JSI::Base.new({}) }
        assert_equal('cannot instantiate JSI::Base which has no method #schema. please use JSI.class_for_schema', err.message)
      end
    end
    describe 'nil' do
      let(:instance) { nil }
      it 'initializes with nil instance' do
        assert_equal(nil, subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'arbitrary instance' do
      let(:instance) { Object.new }
      it 'initializes' do
        assert_equal(instance, subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'hash' do
      let(:instance) { {'foo' => 'bar'} }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal({'foo' => 'bar'}, subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'JSI::JSON::HashNode' do
      let(:instance) { JSI::JSON::HashNode.new({'foo' => 'bar'}, JSI::JSON::Pointer.new([])) }
      let(:schema_content) { {'type' => 'object'} }
      it 'initializes' do
        assert_equal(JSI::JSON::HashNode.new({'foo' => 'bar'}, JSI::JSON::Pointer.new([])), subject.jsi_instance)
        assert(!subject.respond_to?(:to_ary))
        assert(subject.respond_to?(:to_hash))
      end
    end
    describe 'array' do
      let(:instance) { ['foo'] }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(['foo'], subject.jsi_instance)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'JSI::JSON::ArrayNode' do
      let(:instance) { JSI::JSON::ArrayNode.new(['foo'], JSI::JSON::Pointer.new([])) }
      let(:schema_content) { {'type' => 'array'} }
      it 'initializes' do
        assert_equal(JSI::JSON::ArrayNode.new(['foo'], JSI::JSON::Pointer.new([])), subject.jsi_instance)
        assert(subject.respond_to?(:to_ary))
        assert(!subject.respond_to?(:to_hash))
      end
    end
    describe 'another JSI::Base invalid' do
      let(:schema_content) { {'type' => 'object'} }
      let(:instance) { schema.new_jsi({'foo' => 'bar'}) }
      it 'initializes with an error' do
        err = assert_raises(TypeError) { subject }
        assert_equal("assigning another JSI::Base instance to a (JSI Schema Class: #) instance is incorrect. received: \#{<JSI> \"foo\" => \"bar\"}", err.message)
      end
    end
    describe 'Schema invalid' do
      let(:instance) { JSI::Schema.new({}) }
      it 'initializes with an error' do
        err = assert_raises(TypeError) { subject }
        assert_equal("assigning a schema to a (JSI Schema Class: #) instance is incorrect. received: \#{<JSI::JSONSchemaOrgDraft06 Schema>}", err.message)
      end
    end
  end
  describe '#parent_jsis, #parent_jsi' do
    let(:schema_content) { {'properties' => {'foo' => {'properties' => {'bar' => {'properties' => {'baz' => {}}}}}}} }
    let(:instance) { {'foo' => {'bar' => {'baz' => {}}}} }
    describe 'no parent_jsis' do
      it 'has none' do
        assert_equal([], subject.parents)
        assert_equal([], subject.parent_jsis)
        assert_equal(nil, subject.parent)
        assert_equal(nil, subject.parent_jsi)
      end
    end
    describe 'one parent_jsi' do
      it 'has one' do
        assert_equal([subject], subject.foo.parents)
        assert_equal([subject], subject.foo.parent_jsis)
        assert_equal(subject, subject.foo.parent)
        assert_equal(subject, subject.foo.parent_jsi)
      end
    end
    describe 'more parent_jsis' do
      it 'has more' do
        assert_equal([subject.foo.bar, subject.foo, subject], subject.foo.bar.baz.parents)
        assert_equal([subject.foo.bar, subject.foo, subject], subject.foo.bar.baz.parent_jsis)
        assert_equal(subject.foo.bar, subject.foo.bar.baz.parent)
        assert_equal(subject.foo.bar, subject.foo.bar.baz.parent_jsi)
      end
    end
  end
  describe '#each, Enumerable methods' do
    let(:instance) { 'a string' }
    it "raises NoMethodError calling each or Enumerable methods" do
      assert_raises(NoMethodError) { subject.each { nil } }
      assert_raises(NoMethodError) { subject.map { nil } }
    end
  end
  describe '#modified_copy' do
    describe 'with an instance that does not have #modified_copy' do
      let(:instance) { Object.new }
      it 'yields the instance to modify' do
        new_instance = Object.new
        modified = subject.modified_copy do |o|
          assert_equal(instance, o)
          new_instance
        end
        assert_equal(new_instance, modified.jsi_instance)
        assert_equal(instance, subject.jsi_instance)
        refute_equal(instance, modified)
      end
    end
    describe 'with an instance that does have #modified_copy' do
      it 'yields the instance to modify' do
        modified = subject.modified_copy do |o|
          assert_equal({}, o)
          {'a' => 'b'}
        end
        assert_equal({'a' => 'b'}, modified.jsi_instance)
        assert_equal({}, subject.jsi_instance)
        refute_equal(instance, modified)
      end
    end
    describe 'no modification' do
      it 'yields the instance to modify' do
        modified = subject.modified_copy { |o| o }
        # this doesn't really need to be tested but ... whatever
        assert_equal(subject.jsi_instance.object_id, modified.jsi_instance.object_id)
        assert_equal(subject, modified)
        refute_equal(subject.object_id, modified.object_id)
      end
    end
    describe 'resulting in a different type' do
      let(:schema_content) { {'type' => 'object'} }
      it 'works' do
        # I'm not really sure the best thing to do here, but this is how it is for now. this is subject to change.
        modified = subject.modified_copy do |o|
          o.to_s
        end
        assert_equal('{}', modified.jsi_instance)
        assert_equal({}, subject.jsi_instance)
        refute_equal(instance, modified)
        # interesting side effect
        assert(subject.respond_to?(:to_hash))
        assert(!modified.respond_to?(:to_hash))
      end
    end
  end
  describe 'validation' do
    describe 'without errors' do
      it '#fully_validate' do
        assert_equal([], subject.fully_validate)
      end
      it '#validate' do
        assert_equal(true, subject.validate)
      end
      it '#validate!' do
        assert_equal(true, subject.validate!)
      end
    end
  end
  describe 'property accessors' do
    let(:schema_content) do
      {
        'type' => 'object',
        'properties' => {
          'foo' => {'type' => 'object'},
          'bar' => {'type' => 'array'},
          'baz' => {},
        },
      }
    end
    let(:instance) do
      {'foo' => {'x' => 'y'}, 'bar' => [3.14159], 'baz' => true, 'qux' => []}
    end
    describe 'readers' do
      it 'reads attributes described as properties' do
        assert_equal({'x' => 'y'}, subject.foo.as_json)
        assert_instance_of(JSI.class_for_schema(schema['properties']['foo']), subject.foo)
        assert_respond_to(subject.foo, :to_hash)
        refute_respond_to(subject.foo, :to_ary)
        assert_equal([3.14159], subject.bar.as_json)
        assert_instance_of(JSI.class_for_schema(schema['properties']['bar']), subject.bar)
        refute_respond_to(subject.bar, :to_hash)
        assert_respond_to(subject.bar, :to_ary)
        assert_equal(true, subject.baz)
        refute_respond_to(subject.baz, :to_hash)
        refute_respond_to(subject.baz, :to_ary)
        refute_respond_to(subject, :qux)
      end
      describe 'when the instance is not hashlike' do
        let(:instance) { nil }
        it 'errors' do
          err = assert_raises(NoMethodError) { subject.foo }
          assert_equal(%q(cannot subcript (using token: "foo") from instance: nil), err.message)
        end
      end
      describe 'properties with the same names as instance methods' do
        let(:schema_content) do
          {
            'type' => 'object',
            'properties' => {
              'foo' => {},            # not an instance method
              'initialize' => {},     # Base
              'inspect' => {},        # Base
              'pretty_inspect' => {}, # Kernel
              'as_json' => {},        # Base::OverrideFromExtensions, extended on initialization
              'each' => {},           # BaseHash / BaseArray
              'instance_exec' => {},  # BasicObject
              'instance' => {},       # Base
              'schema' => {},         # module_for_schema singleton definition
            },
          }
        end
        let(:instance) do
          {
            'foo' => 'bar',
            'initialize' => 'hi',
            'inspect' => 'hi',
            'pretty_inspect' => 'hi',
            'as_json' => 'hi',
            'each' => 'hi',
            'instance_exec' => 'hi',
            'instance' => 'hi',
            'schema' => 'hi',
          }
        end
        it 'does not define readers' do
          assert_equal('bar', subject.foo)
          assert_equal(JSI::SchemaClasses.module_for_schema(subject.schema, conflicting_modules: [JSI::Base, JSI::BaseArray, JSI::BaseHash]), subject.method(:foo).owner)

          assert_equal(JSI::Base, subject.method(:initialize).owner)
          assert_equal('hi', subject['initialize'])
          assert_equal(%q(#{<JSI> "foo" => "bar", "initialize" => "hi", "inspect" => "hi", "pretty_inspect" => "hi", "as_json" => "hi", "each" => "hi", "instance_exec" => "hi", "instance" => "hi", "schema" => "hi"}), subject.inspect)
          assert_equal('hi', subject['inspect'])
          assert_equal(%Q(\#{<JSI>\n  "foo" => "bar",\n  "initialize" => "hi",\n  "inspect" => "hi",\n  "pretty_inspect" => "hi",\n  "as_json" => "hi",\n  "each" => "hi",\n  "instance_exec" => "hi",\n  "instance" => "hi",\n  "schema" => "hi"\n}\n), subject.pretty_inspect)
          assert_equal(instance, subject.as_json)
          assert_equal(subject, subject.each { })
          assert_equal(2, subject.instance_exec { 2 })
          assert_equal(instance, subject.jsi_instance)
          assert_equal(schema, subject.schema)
        end
      end
    end
    describe 'writers' do
      it 'writes attributes described as properties' do
        orig_foo = subject.foo

        subject.foo = {'y' => 'z'}

        assert_equal({'y' => 'z'}, subject.foo.as_json)
        assert_instance_of(JSI.class_for_schema(schema['properties']['foo']), orig_foo)
        assert_instance_of(JSI.class_for_schema(schema['properties']['foo']), subject.foo)
      end
      it 'modifies the instance, visible to other references to the same instance' do
        orig_instance = subject.jsi_instance

        subject.foo = {'y' => 'z'}

        assert_equal(orig_instance, subject.jsi_instance)
        assert_equal({'y' => 'z'}, orig_instance['foo'])
        assert_equal({'y' => 'z'}, subject.jsi_instance['foo'])
        assert_equal(orig_instance.class, subject.jsi_instance.class)
      end
      describe 'when the instance is not hashlike' do
        let(:instance) { nil }
        it 'errors' do
          err = assert_raises(NoMethodError) { subject.foo = 0 }
          assert_equal('cannot assign subcript (using token: "foo") to instance: nil', err.message)
        end
      end
    end
  end
  describe '#inspect' do
    # if the instance is hash-like, #inspect gets overridden
    let(:instance) { Object.new }
    it 'inspects' do
      assert_match(%r(\A\#<JSI\ \#<Object:[^<>]*>>\z), subject.inspect)
    end
  end
  describe '#pretty_print' do
    # if the instance is hash-like, #pretty_print gets overridden
    let(:instance) { Object.new }
    it 'pretty_prints' do
      assert_match(%r(\A\#<JSI\ \#<Object:[^<>]*>>\z), subject.pretty_inspect.chomp)
    end
  end
  describe '#as_json' do
    it '#as_json' do
      assert_equal({'a' => 'b'}, JSI::Schema.new({}).new_jsi({'a' => 'b'}).as_json)
      assert_equal({'a' => 'b'}, JSI::Schema.new({}).new_jsi(JSI::JSON::Node.new_doc({'a' => 'b'})).as_json)
      assert_equal({'a' => 'b'}, JSI::Schema.new({'type' => 'object'}).new_jsi(JSI::JSON::Node.new_doc({'a' => 'b'})).as_json)
      assert_equal(['a', 'b'], JSI::Schema.new({'type' => 'array'}).new_jsi(JSI::JSON::Node.new_doc(['a', 'b'])).as_json)
      assert_equal(['a'], JSI::Schema.new({}).new_jsi(['a']).as_json(some_option: true))
    end
  end
  describe 'equality between different classes of JSI::Base subclasses' do
    let(:subject_subclass) { Class.new(JSI.class_for_schema(schema)).new(instance) }

    it 'considers a Base subclass (class_for_schema) and subsubclass to be equal with the same instance' do
      assert_equal(subject.hash, subject_subclass.hash)
      assert(subject == subject_subclass)
      assert(subject_subclass == subject)
      assert(subject.eql?(subject_subclass))
      assert(subject_subclass.eql?(subject))
    end
  end
end
