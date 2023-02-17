require 'yaml'

module YAMLTools
  class Comparer
    @source_anchors = {}
    @destination_anchors = {}
    @modified_anchors = []

    def processLevel (s, d, indent = '')
      level = []

      # Split into key/value pairs
      sourceChildren = s.each_slice(2).to_a
      destinationChildren = d.each_slice(2).to_a

      # Add all anchors for this level for use when performing potential comparisons later
      sourceChildren.find_all {|i| !i[1].is_a?(Psych::Nodes::Alias) && !i[1].anchor.nil?}.each {|i| @source_anchors[i[1].anchor] = i[1]}
      destinationChildren.find_all {|i| !i[1].is_a?(Psych::Nodes::Alias) && !i[1].anchor.nil?}.each {|i| @destination_anchors[i[1].anchor] = i[1]}

      destinationChildren.each {|destinationPair|
        destinationKey = destinationPair[0]
        destinationValue = destinationPair[1]

        # Find source pair
        sourcePairs = sourceChildren.find_all {|i| i[0].value == destinationKey.value}

        if (sourcePairs.length > 1) then
          if (destinationKey.value == "<<") then
            # Find merge key with matching alias
            sourcePair = sourcePairs.find {|i| i[1].is_a?(Psych::Nodes::Alias) && i[1].anchor == destinationValue.anchor}
          else
            # Some ArchivesSpace files have duplicate keys so use the last one
            sourcePair = sourcePairs.last
          end
        else
          sourcePair = sourcePairs.first
        end

        if (sourcePair == nil) then
          # Source not found so copy node
          level << destinationKey
          level << destinationValue
        else
          sourceKey = sourcePair[0]
          sourceValue = sourcePair[1]

          if (sourceKey.value == "<<") then
            # Handle merge keys specifically since they can be an individual alias or a sequence or aliases

            if (sourceValue.is_a?(Psych::Nodes::Sequence)) then
              if (destinationValue.is_a?(Psych::Nodes::Sequence)) then
                if (sourceValue.children.length == destinationValue.children.length) then
                  # Compare sequences
                  sourceValue.children.each_with_index {|a, index|
                    if (a.anchor != destinationValue.children[index].anchor || @modified_anchors.include?(destinationValue.children[index].anchor)) then
                      # Different aliases or ordering
                      level << destinationKey
                      level << destinationValue
                      break
                    end
                  }
                else
                  # Different number of aliases
                  level << destinationKey
                  level << destinationValue
                end
              elsif (destinationValue.is_a?(Psych::Nodes::Alias)) then
                # Sequence of aliases overriden by single alias
                level << destinationKey
                level << destinationValue
              else
                # Bad data
                # TODO Handle this
              end
            elsif (sourceValue.is_a?(Psych::Nodes::Alias)) then
              if (destinationValue.is_a?(Psych::Nodes::Sequence)) then
                # Single alias overriden by sequence of aliases
                level << destinationKey
                level << destinationValue
              elsif (destinationValue.is_a?(Psych::Nodes::Alias)) then
                # Compare aliases
                if (sourceValue.anchor != destinationValue.anchor || @modified_anchors.include?(destinationValue.anchor)) then
                  # Different aliases
                  level << destinationKey
                  level << destinationValue
                end
              else
                # Bad data
                # TODO Handle this
              end
            else
              # Bad data
              # TODO Handle this
            end
          elsif (destinationValue.is_a?(Psych::Nodes::Mapping)) then
            childLevel = processLevel(sourceValue.children, destinationValue.children, indent + '  ')

            if (childLevel.length > 0) then
              newMapping = Psych::Nodes::Mapping.new(destinationValue.anchor, destinationValue.tag, destinationValue.implicit, destinationValue.style)
              newMapping.children.push(*childLevel)

              level << destinationKey
              level << newMapping

              if (destinationValue.anchor != nil) then
                @modified_anchors << destinationValue.anchor
              end
            end
          else
            # Compare scalars or aliases to scalars
            if (destinationValue.is_a?(Psych::Nodes::Scalar) || (destinationValue.is_a?(Psych::Nodes::Alias) && @destination_anchors[destinationValue.anchor].is_a?(Psych::Nodes::Scalar))) then
              # Compare values

              if (sourceValue.is_a?(Psych::Nodes::Alias)) then
                # Use anchor value
                sourceValueData = @source_anchors[sourceValue.anchor].value
              else
                sourceValueData = sourceValue.value
              end

              if (destinationValue.is_a?(Psych::Nodes::Alias)) then
                # Use anchor value
                destinationValueData = @destination_anchors[destinationValue.anchor].value
              else
                destinationValueData = destinationValue.value
              end

              if (destinationValueData != sourceValueData || @modified_anchors.include?(destinationValue.anchor)) then
                level << destinationKey
                level << destinationValue

                if (destinationValue.is_a?(Psych::Nodes::Scalar) && destinationValue.anchor != nil) then
                  @modified_anchors << destinationValue.anchor
                end
              end
            end
          end
        end
      }

      # Find source pairs where value is alias that don't exist in destination
      # Look for aliases whose anchor was modified
      sourceChildren.find_all {|i|
        i[1].is_a?(Psych::Nodes::Alias) &&
        !i[1].anchor.nil? &&
        @modified_anchors.include?(i[1].anchor)
      }.each {|sp|
        dPair = destinationChildren.find_all {|i| i[0].value == sp[0].value}.last

        if (dPair == nil) then
          level << sp[0]
          level << sp[1]
        end
      }

      level
    end

    def processModifiedAnchors(s, anchors)
      level = []

      # Split into key/value pairs
      sourceChildren = s.each_slice(2).to_a

      sourceChildren.each {|sourcePair|
        sourceKey = sourcePair[0]
        sourceValue = sourcePair[1]

        # Check if merge key
        if (sourceKey.value == "<<") then
          # Check if in modified_anchors

          if (sourceValue.is_a?(Psych::Nodes::Sequence)) then
            # Check each anchor in sequence
            aliases = sourceValue.children.find_all {|a| anchors.include?(a.anchor)}

            if (aliases.length > 0) then
              if (aliases.length == 1) then
                level << sourceKey
                level << aliases[0]
              else
                newSequence = Psych::Nodes::Sequence.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)
                newSequence.children.push(*aliases)

                level << sourceKey
                level << newSequence
              end
            end
          else
            if (anchors.include?(sourceValue.anchor)) then
              # Add the merge key and include in the level
              level << sourceKey
              level << sourceValue
            end
          end

          next
        elsif (sourceValue.is_a?(Psych::Nodes::Mapping)) then
          childLevel = processModifiedAnchors(sourceValue.children, anchors)

          if (childLevel.length > 0) then
            newMapping = Psych::Nodes::Mapping.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)
            newMapping.children.push(*childLevel)

            level << sourceKey
            level << newMapping

            # Add new anchors that are located
            if (sourceValue.anchor != nil) then
              @modified_anchors << sourceValue.anchor
            end
          end
        elsif (sourceValue.is_a?(Psych::Nodes::Alias) && anchors.include?(sourceValue.anchor)) then
            # Add the merge key and include in the level
            level << sourceKey
            level << sourceValue
        end
      }

      level
    end

    def mergeDifferences (s, d)
      level = []

      # Split into key/value pairs
      sourceChildren = s.each_slice(2).to_a
      destinationChildren = d.each_slice(2).to_a

      # Add all source pairs that don't exist in the destination

      sourceChildren.each {|sourcePair|
        sourceKey = sourcePair[0]
        sourceValue = sourcePair[1]

        destinationPair = destinationChildren.find_all {|i| i[0].value == sourceKey.value}.last

        if (destinationPair == nil) then
          level << sourceKey
          level << sourceValue
        end
      }

      # Add all destination pairs that don't exist in the source

      destinationChildren.each {|destinationPair|
        destinationKey = destinationPair[0]
        destinationValue = destinationPair[1]

        # Find source pair (Note: when finding key value pairs, we find the last pair since some ArchivesSpace YAML files contain duplicate keys)
        sourcePair = sourceChildren.find_all {|i| i[0].value == destinationKey.value}.last

        if (sourcePair == nil) then
          # Source not found so copy node
          level << destinationKey
          level << destinationValue
        else
          sourceKey = sourcePair[0]
          sourceValue = sourcePair[1]

          if (sourceValue.class != destinationValue.class) then
            # If aliases or sequences of aliases then merge
            if ((sourceValue.is_a?(Psych::Nodes::Alias) || sourceValue.is_a?(Psych::Nodes::Sequence)) && (destinationValue.is_a?(Psych::Nodes::Alias) || destinationValue.is_a?(Psych::Nodes::Sequence))) then
              if (sourceValue.is_a?(Psych::Nodes::Alias) && (destinationValue.is_a?(Psych::Nodes::Sequence) && destinationValue.children.all? {|a| a.is_a?(Psych::Nodes::Alias)})) then
                # Merge aliases
                if (destinationValue.children.none? {|a| a.anchor == sourceValue.anchor}) then
                  # Add alias to sequence
                  destinationValue.children = destinationValue.children << sourceValue
                end

                level << destinationKey
                level << destinationValue

              elsif (destinationValue.is_a?(Psych::Nodes::Alias) && (sourceValue.is_a?(Psych::Nodes::Sequence) && sourceValue.children.all? {|a| a.is_a?(Psych::Nodes::Alias)})) then
                # Merge aliases
                if (sourceValue.children.none? {|a| a.anchor == destinationValue.anchor}) then
                  # Add alias to sequence
                  sourceValue.children = sourceValue.children << destinationValue
                end

                level << destinationKey
                level << sourceValue
              end
            else
              # Bad data
              raise "Cannot process different types: #{sourceValue.class} and #{destinationValue.class}"
            end
          elsif (destinationValue.is_a?(Psych::Nodes::Mapping)) then
            childLevel = mergeDifferences(sourceValue.children, destinationValue.children)

            if (childLevel.length > 0) then
              newMapping = Psych::Nodes::Mapping.new(destinationValue.anchor, destinationValue.tag, destinationValue.implicit, destinationValue.style)
              newMapping.children.push(*childLevel)

              level << destinationKey
              level << newMapping
            end
          elsif (destinationValue.is_a?(Psych::Nodes::Sequence)) then
            # Merge sequences
            newSequence = (sourceValue | destinationValue).uniq {|a| a.anchor}

            level << destinationKey
            level << newSequence

          elsif (destinationValue.is_a?(Psych::Nodes::Alias)) then
            # Create sequence if aliases aren't the same
            if (sourceValue.anchor != destinationValue.anchor) then
              newSequence = Psych::Nodes::Sequence.new(sourceValue.anchor, sourceValue.tag, sourceValue.implicit, sourceValue.style)
              newSequence.children = newSequence.children << sourceValue
              newSequence.children = newSequence.children << destinationValue

              level << destinationKey
              level << newSequence
            else
              # Aliases are the same
              level << destinationKey
              level << destinationValue
            end
          else
            level << destinationKey
            level << destinationValue
          end
        end
      }

      level
    end

    def compare_files(sourceFilePath, destinationFilePath)
      sourceFile = File.open(options[:source], "r")
      differenceFile = File.open(options[:difference], "r")

      begin
        result = compare(sourceFile, differenceFile)
      ensure
        sourceFile.close
        differenceFile.close
      end

      result
    end

    def compare(source, destination, includeAnchorDependencies = false)
      @source_anchors = {}
      @destination_anchors = {}
      @modified_anchors = []

      y1 = YAML.parse(source)
      y2 = YAML.parse(destination)

      @differences = processLevel(y1.root.children, y2.root.children)

      if (includeAnchorDependencies) then
        @current_modified_anchors = []

        loop do
          @current_modified_anchors = @modified_anchors.clone
          @modified_anchors = []
          modified_anchor_additions = processModifiedAnchors(y1.root.children, @current_modified_anchors)

          if (modified_anchor_additions.length > 0) then
            mergedDifferences = mergeDifferences(@differences, modified_anchor_additions);
            @differences = mergedDifferences
          end

          break if (@current_modified_anchors.length == 0)
        end
      end

      if (@differences.length > 0) then
        differenceDocument = Psych::Nodes::Document.new()
        differenceDocumentRoot = Psych::Nodes::Mapping.new();
        differenceDocumentRoot.children.push(*@differences)
        differenceDocument.children << differenceDocumentRoot

        stream = Psych::Nodes::Stream.new
        stream.children << differenceDocument
        output = stream.to_yaml

        # Remove initial document start
        document_start = (output.index("---\n") || size - 1) + 4
        output.slice!(0, document_start)
      else
        output = ''
      end

      output
    end
  end
end
