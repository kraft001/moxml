require_relative "base"
require_relative "customized_oga/xml_generator"
require "oga"

module Moxml
  module Adapter
    class Oga < Base
      class << self
        def set_root(doc, element)
          doc.children.clear  # Clear any existing children
          doc.children << element
        end

        def parse(xml, options = {})
          native_doc = begin
              ::Oga.parse_xml(xml, strict: options[:strict])
            rescue ::Oga::XML::SyntaxError => e
              raise Moxml::ParseError.new(e.message)
            end

          DocumentBuilder.new(Context.new(:oga)).build(native_doc)
        end

        def create_document
          ::Oga::XML::Document.new
        end

        def create_native_element(name)
          ::Oga::XML::Element.new(name: name)
        end

        def create_native_text(content)
          ::Oga::XML::Text.new(text: content)
        end

        def create_native_cdata(content)
          ::Oga::XML::Cdata.new(text: content)
        end

        def create_native_comment(content)
          ::Oga::XML::Comment.new(text: content)
        end

        def create_native_processing_instruction(target, content)
          ::Oga::XML::ProcessingInstruction.new(name: target, text: content)
        end

        def create_native_declaration(version, encoding, standalone)
          ::Oga::XML::ProcessingInstruction.new(
            name: "xml",
            text: build_declaration_attrs(version, encoding, standalone),
          )
        end

        def create_native_namespace(element, prefix, uri)
          ns = element.available_namespaces[prefix]
          return ns unless ns.nil?

          element.register_namespace(prefix, uri)
          ::Oga::XML::Namespace.new(name: prefix, uri: uri)
        end

        def set_namespace(element, ns)
          return if element.available_namespaces.include?(ns.name)

          element.register_namespace(ns.name, ns.uri)
        end

        def namespace(element)
          ns = element.respond_to?(:namespaces) && element.namespaces.values.last
          ns ||= element.respond_to?(:namespace) && element.namespace
          ns
        rescue NoMethodError
          # Oga attributes fail with NoMethodError:
          # undefined method `available_namespaces' for nil:NilClass
          nil
        end

        def processing_instruction_target(node)
          node.name
        end

        def node_type(node)
          case node
          when ::Oga::XML::Element then :element
          when ::Oga::XML::Text then :text
          when ::Oga::XML::Cdata then :cdata
          when ::Oga::XML::Comment then :comment
          when ::Oga::XML::ProcessingInstruction then :processing_instruction
          when ::Oga::XML::Document then :document
          else :unknown
          end
        end

        def node_name(node)
          node.name
        end

        def set_node_name(node, name)
          node.name = name
        end

        def children(node)
          return [] unless node.respond_to?(:children)
          node.children.reject do |child|
            child.is_a?(::Oga::XML::Text) &&
              child.text.strip.empty? &&
              !(child.previous.nil? && child.next.nil?)
          end
        end

        def parent(node)
          node.parent if node.respond_to?(:parent)
        end

        def next_sibling(node)
          node.next
        end

        def previous_sibling(node)
          node.previous
        end

        def document(node)
          current = node
          while parent(current)
            current = current.parent
          end

          current
        end

        def root(document)
          document.children.find { |node| node.is_a?(::Oga::XML::Element) }
        end

        def attribute_element(attr)
          attr.element
        end

        def attributes(element)
          element.respond_to?(:attributes) ? element.attributes : []
        end

        def set_attribute(element, name, value)
          namespace_name = nil
          if name.to_s.include?(':')
            namespace_name, name = name.to_s.split(':', 2)
          end

          attr = ::Oga::XML::Attribute.new(
            name: name.to_s,
            namespace_name: namespace_name,
            value: value.to_s
          )
          element.add_attribute(attr)
        end

        def get_attribute(element, name)
          element.attribute(name.to_s)
        end

        def remove_attribute(element, name)
          attr = element.attribute(name.to_s)
          element.attributes.delete(attr) if attr
        end

        def add_child(element, child)
          element.children << child
        end

        def add_previous_sibling(node, sibling)
          node.before(sibling)
        end

        def add_next_sibling(node, sibling)
          node.after(sibling)
        end

        def remove(node)
          node.remove
        end

        def replace(node, new_node)
          node.replace(new_node)
        end

        def replace_children(node, new_children)
          node.inner_text = ""
          new_children.each { |child| add_child(node, child) }
        end

        def text_content(node)
          node.text
        end

        def set_text_content(node, content)
          node.inner_text = content
        end

        def cdata_content(node)
          node.text
        end

        def set_cdata_content(node, content)
          node.text = content
        end

        def comment_content(node)
          node.text
        end

        def set_comment_content(node, content)
          node.text = content
        end

        def processing_instruction_content(node)
          node.text
        end

        def set_processing_instruction_content(node, content)
          node.text = content
        end

        def namespace_prefix(namespace)
          namespace.name
        end

        def namespace_uri(namespace)
          namespace.uri
        end

        def namespace_definitions(node)
          return [] unless node.respond_to?(:namespaces)
          node.namespaces
        end

        def xpath(node, expression, namespaces = {})
          node.xpath(expression).to_a
        rescue ::Oga::XPath::Error => e
          raise Moxml::XPathError, e.message
        end

        def at_xpath(node, expression, namespaces = {})
          node.at_xpath(expression)
        rescue ::Oga::XPath::Error => e
          raise Moxml::XPathError, e.message
        end

        def serialize(node, options = {})
          if options[:expand_empty]
            # Expand empty tags with a custom generator
            ::Moxml::Adapter::CustomizedOga::XmlGenerator.new(node).to_xml
          else
            # Use the native generator
            node.to_xml
          end
        end
      end
    end
  end
end
