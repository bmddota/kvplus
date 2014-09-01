class LevelScalingModifierPlugin < Plugin
  def init()
    puts "LEVELSCALINGMODIFIERPLUGIN"
  end

  def execute(kvs, options)
    puts "LEVELSCALINGMODIFIERPLUGIN: execute"
    options = options.first
    if(options["Target"])
      options["Target"].each do |path|
        puts "LEVELSCALINGMODIFIERPLUGIN: searching #{path} for ApplyModifiers"
        replace_scaling_modifiers kvs[path]
        puts writeKV("output/" + path, "DOTAAbilities", kvs[path])
      end
    end
    
  end
  
  # Recursively search for and replace ApplyModifier blocks, if they're split using spaces
  def replace_scaling_modifiers(root)
    return unless root and root.is_a? Enumerable
    
    new_random_blocks = []
    
    root.each do |key, value|
      if key != "ApplyModifier" # nope, moving on..
        replace_scaling_modifiers (value || key)
        next
      end
      
      value.each do |apply_block|
        # there shouldn't be multiple modifier name blocks, right?
        name = apply_block["ModifierName"].first 
        targets = apply_block["Target"]
        modifier_names = name.split(" ")
        if modifier_names.length > 1
          puts "LEVELSCALINGMODIFIERPLUGIN: found ModifierName with spaces in it: \"#{name}\""
          root.delete(key) # remove it so we can replace it later
          new_random_blocks.push build_chance_block(modifier_names, targets)
        end
      end
    end
    if new_random_blocks.length > 0
      puts "LEVELSCALINGMODIFIERPLUGIN: Replaced #{new_random_blocks.length} ApplyModifier blocks"
      root["Random"] = new_random_blocks
    end
  end
  
  def build_chance_block(modifier_names, modifier_targets, zero_offset=0)
    if(modifier_names.length == 1)
      return build_modifier_block(modifier_names.first, modifier_targets)
    end
    
    base = {
      "Chance" => ["0"  + " 0" * zero_offset + " 100" * (modifier_names.length - 1)],
      "OnSuccess" => [build_chance_block(modifier_names[1..-1], modifier_targets, zero_offset + 1)],
      "OnFailure" => [build_modifier_block(modifier_names.first, modifier_targets)]
    }
    return base if zero_offset == 0
    return {"Random" => [base]}
  end
  
  def build_modifier_block(modifier_name, modifier_targets)
    return {"ApplyModifier" => [{"ModifierName"=>[modifier_name], "Target"=>modifier_targets}]}
  end
end
