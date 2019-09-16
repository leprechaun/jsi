require_relative 'test_helper'

describe JSI::Util do
  describe '.stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      assert_equal({'a' => 'b', 'c' => 'd', nil => 3}, JSI.stringify_symbol_keys({a: 'b', 'c' => 'd', nil => 3}))
    end
    it 'stringifies HashNode keys' do
      actual = JSI.stringify_symbol_keys(JSI::JSON::Node.new_doc({a: 'b', 'c' => 'd', nil => 3}))
      expected = JSI::JSON::Node.new_doc({'a' => 'b', 'c' => 'd', nil => 3})
      assert_equal(expected, actual)
    end
    it 'stringifies JSI hash keys' do
      klass = JSI.class_for_schema(type: 'object')
      expected = JSI.stringify_symbol_keys(klass.new({a: 'b', 'c' => 'd', nil => 3}))
      actual = klass.new({'a' => 'b', 'c' => 'd', nil => 3})
      assert_equal(expected, actual)
    end
    describe 'non-hash-like argument' do
      it 'errors' do
        err = assert_raises(ArgumentError) { JSI.stringify_symbol_keys(nil) }
        assert_equal("expected argument to be a hash; got NilClass: nil", err.message)
        err = assert_raises(ArgumentError) { JSI.stringify_symbol_keys(JSI::JSON::Node.new_doc(3)) }
        assert_equal("expected argument to be a hash; got JSI::JSON::Node: #<JSI::JSON::Node fragment=\"#\" 3>", err.message)
        err = assert_raises(ArgumentError) { JSI.stringify_symbol_keys(JSI.class_for_schema({}).new(3)) }
        assert_match(%r(\Aexpected argument to be a hash; got JSI::SchemaClasses\["[^"]+#"\]: #<JSI::SchemaClasses\["[^"]+#"\] 3>\z)m, err.message)
      end
    end
  end
  describe '.deep_stringify_symbol_keys' do
    it 'stringifies symbol hash keys' do
      actual = JSI.deep_stringify_symbol_keys({
        a: 'b',
        'c' => [
          {d: true},
          [{'e' => 0}],
        ],
        nil => 3,
      })
      expected = {
        'a' => 'b',
        'c' => [
          {'d' => true},
          [{'e' => 0}],
        ],
        nil => 3,
      }
      assert_equal(expected, actual)
    end
    it 'deep stringifies HashNode keys' do
      actual = JSI.deep_stringify_symbol_keys(JSI::JSON::Node.new_doc({a: 'b', 'c' => {d: 0}, nil => 3}))
      expected = JSI::JSON::Node.new_doc({'a' => 'b', 'c' => {'d' => 0}, nil => 3})
      assert_equal(expected, actual)
    end
    it 'deep stringifies JSI instance' do
      klass = JSI.class_for_schema(type: 'object')
      actual = JSI.deep_stringify_symbol_keys(klass.new(JSI::JSON::Node.new_doc({a: 'b', 'c' => {d: 0}, nil => 3})))
      expected = klass.new(JSI::JSON::Node.new_doc({'a' => 'b', 'c' => {'d' => 0}, nil => 3}))
      assert_equal(expected, actual)
    end
  end
end
