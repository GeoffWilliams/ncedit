# A fake puppetclassify instance that always succeeds

class FakePuppetClassify
  def initialize(nc_api_url, https_settings)
  end

  def groups
    @groups
  end

  def groups=(group_data)
    @groups = FakePuppetClassify::FakeGroups.new(group_data)
  end

  def nodes
    @nodes
  end

  def nodes=(nodes)
    @nodes = nodes
  end

  def environments
    @environments
  end

  def environments=(environments)
    @environments = environments
  end

  def classes
    @classes
  end

  def classes=(classes)
    @classes = classes
  end

  def import_hierarchy
    @import_hierarchy
  end

  def import_hierarchy=(import_hierarchy)
    @import_hierarchy = import_hierarchy
  end

  def update_classes
    @update_classes
  end

  def update_classes=(update_classes)
    @update_classes = update_classes
  end

  def validate
    return true
  end

  def rules
    @rules
  end

  def rules=(rules)
    @rules = rules
  end


  def last_class_update
    @last_class_update
  end

  def last_class_update=(last_class_update)
    @last_class_update = last_class_update
  end


  def classification
    @classification
  end

  def classification=(classification)
    @classification = classification
  end

  def commands
    @commands
  end

  def commands=(commands)
    @commands = commands
  end

  class FakeGroups
    def initialize(group_data)
      @group_data = group_data
    end

    def get_group_id(group_name)
      "DEADBEEF"
    end

    def get_group(group_id)
      @group_data
    end
  end

end
