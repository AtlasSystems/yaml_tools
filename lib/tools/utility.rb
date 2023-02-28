require 'yaml'

module YAMLTools
  def self.createDocument(levels)
    document = Psych::Nodes::Document.new()
    documentRoot = Psych::Nodes::Mapping.new();
    documentRoot.children.push(*levels)
    document.children << documentRoot

    stream = Psych::Nodes::Stream.new
    stream.children << document
    output = stream.to_yaml

    # Remove initial document start
    output.slice!(0, 4) if (output.start_with?("---\n"))

    output
  end

  def self.flatten_merge_keys(s)
    level = []

    sourceChildren = s.each_slice(2).to_a

    mergeKeys = sourceChildren.find_all {|i| i[0].value == "<<" }

    if (mergeKeys.length > 0) then
      if (mergeKeys.length == 1) then
        # Add merge key
        level << mergeKeys.first[0]
        level << mergeKeys.first[1]
      else
        newSequence = Psych::Nodes::Sequence.new(nil, nil, true, Psych::Nodes::Sequence::FLOW)

        mergeKeys.each {|m|
          if (m[1].is_a?(Psych::Nodes::Alias)) then
            newSequence.children << m[1]
          elsif (m[1].is_a?(Psych::Nodes::Sequence)) then
            newSequence.children.concat(m[1].children)
          end
        }

        level << Psych::Nodes::Scalar.new("<<")
        level << newSequence
      end
    end

    sourceChildren.each {|sourcePair|
      sourceKey = sourcePair[0]
      sourceValue = sourcePair[1]

      if (sourceValue.is_a?(Psych::Nodes::Mapping)) then
        childLevel = flatten_merge_keys(sourceValue.children)

        newMapping = Psych::Nodes::Mapping.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)

        if (childLevel.length > 0) then
          newMapping.children.push(*childLevel)
        end

        level << sourceKey
        level << newMapping
      else
        if (sourceKey.value != "<<") then
          level << sourceKey
          level << sourceValue
        end
      end
    }

    level
  end
end
