require 'yaml'

module YAMLTools
  class Combiner
    def combine_levels (s, d)
      level = []

      # Split into key/value pairs
      sourceChildren = s.each_slice(2).to_a
      differenceChildren = d.each_slice(2).to_a

      sourceChildren.each {|sourcePair|
        sourceKey = sourcePair[0]
        sourceValue = sourcePair[1]

        # Find difference pair
        differencePairs = differenceChildren.find_all {|i| i[0].value == sourceKey.value}

        if (differencePairs.length > 1) then
          if (sourceKey.value == "<<") then
            # Find merge key with matching alias
            differencePair = differencePairs.find {|i| i[1].is_a?(Psych::Nodes::Alias) && i[1].anchor == sourceValue.anchor}
          else
            # Some ArchivesSpace files have duplicate keys so use the last one
            differencePair = differencePairs.last
          end
        else
          differencePair = differencePairs.first
        end

        if (differencePair == nil) then
          # difference not found so copy node
          level << sourceKey
          level << sourceValue
        else
          differenceKey = differencePair[0]
          differenceValue = differencePair[1]

          if (differenceValue.is_a?(Psych::Nodes::Mapping)) then
            childLevel = combine_levels(sourceValue.children, differenceValue.children)

            newMapping = Psych::Nodes::Mapping.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)

            if (childLevel.length > 0) then
              newMapping.children.push(*childLevel)
            end

            level << differenceKey
            level << newMapping
          else
            level << differenceKey
            level << differenceValue
          end
        end
      }

      # Add all difference pairs that don't exist in the source

      differenceChildren.each {|differencePair|
        differenceKey = differencePair[0]
        differenceValue = differencePair[1]

        if (sourceChildren.none? {|i| i[0].value == differenceKey.value}) then
          level << differenceKey
          level << differenceValue
        end
      }

      level
    end

    def flatten_merge_keys(s)
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

    def combine_files(sourceFilePath, differenceFilePath)
      sourceFile = File.open(options[:source], "r")
      differenceFile = File.open(options[:difference], "r")

      begin
        output = combine(sourceFile, differenceFile)
      ensure
        sourceFile.close
        differenceFile.close
      end

      output
    end

    def combine(source, difference)
      # Load files
      sourceDocument = YAML.parse(source)
      differenceDocument = YAML.parse(difference)

      # Flatten merge keys for older ArchivesSpace files
      sourceDocument = flatten_merge_keys(sourceDocument.root.children)
      differenceDocument = flatten_merge_keys(differenceDocument.root.children)

      @combined = combine_levels(sourceDocument, differenceDocument)

      if (@combined.length > 0) then
        combinedDocument = Psych::Nodes::Document.new()
        combinedDocumentRoot = Psych::Nodes::Mapping.new();
        combinedDocumentRoot.children.push(*@combined)
        combinedDocument.children << combinedDocumentRoot

        stream = Psych::Nodes::Stream.new
        stream.children << combinedDocument
        output = stream.to_yaml

        # Remove document start
        document_start = (output.index("---\n") || size - 1) + 4
        output.slice!(0, document_start)
      else
        output = ''
      end

      output
    end
  end
end
