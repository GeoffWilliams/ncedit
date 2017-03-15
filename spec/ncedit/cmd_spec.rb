require "spec_helper"
require "ncedit/cmd"

RSpec.describe NCEdit::Cmd do
  it "read_batch_data fails when no file specified" do
    expect {NCEdit::Cmd.read_batch_data()}.to raise_error(/must/)
  end

  it "read_batch_data fails when both files specified" do
    expect {NCEdit::Cmd.read_batch_data(json_file: "foo", yaml_file: "bar")}.to raise_error(/both/)
  end

  it "read_batch_data catches missing yaml file" do
    expect {NCEdit::Cmd.read_batch_data(yaml_file: "nothere")}.to raise_error(/not found/)
  end

  it "read_batch_data catches missing json file" do
    expect {NCEdit::Cmd.read_batch_data(json_file: "nothere")}.to raise_error(/not found/)
  end

  it "read_batch_data catches bad json syntax" do
    expect {NCEdit::Cmd.read_batch_data(json_file: "./spec/fixtures/bad_json.json")}.to raise_error(/syntax/)
  end

  it "read_batch_data catches bad yaml syntax" do
    expect {NCEdit::Cmd.read_batch_data(yaml_file: "./spec/fixtures/bad_yaml.yaml")}.to raise_error(/syntax/)
  end

  it "parses yaml file OK" do
    NCEdit::Cmd.read_batch_data(yaml_file: "./doc/example/batch.yaml")
  end

  it "parses yaml file OK" do
    NCEdit::Cmd.read_batch_data(json_file: "./doc/example/batch.json")
  end

  it "delete_class removes class" do
    group = { "classes" => {"foo"=>{}}}

    update = NCEdit::Cmd.delete_class(group, "foo")
    expect(group["classes"].has_key?("foo")).to be false
    expect(update).to be true
  end

  it "delete_class does not raise error when class already deleted" do
    group = { "classes" => {"foo"=>nil}}

    update = NCEdit::Cmd.delete_class(group, "bar")
    expect(group["classes"].has_key?("foo")).to be true
    expect(update).to be false
  end

  it "delete_param removes class" do
    group = { "classes" => {"foo"=>{"bar"=>"baz"}}}

    update = NCEdit::Cmd.delete_param(group, "foo", "bar")
    expect(group["classes"]["foo"].has_key?("bar")).to be false
    expect(update).to be true
  end

  it "delete_class does not raise error when param already deleted" do
    group = { "classes" => {"foo"=>{"bar"=>"baz"}}}

    update = NCEdit::Cmd.delete_param(group, "foo", "clive")
    expect(group["classes"].has_key?("foo")).to be true
    expect(update).to be false
  end

  it "delete_class does not raise error when class not present" do
    group = { "classes" => {}}

    update = NCEdit::Cmd.delete_param(group, "foo", "clive")
    expect(update).to be false
  end

  it "ensure_class creates new class" do
    group = { "classes" => {"foo" => {}}}

    update = NCEdit::Cmd.ensure_class(group, "bar")
    expect(group["classes"].has_key?("bar")).to be true
    expect(update).to be true
  end

  it "ensure_class does not raise error when class already exist" do
    group = { "classes" => {"bar"=>{}}}

    update = NCEdit::Cmd.ensure_class(group, "bar")
    expect(group["classes"].has_key?("bar")).to be true
    expect(update).to be false
  end

  it "ensure_param creates new param" do
    group = { "classes" => {"foo" => {}}}

    NCEdit::Cmd.ensure_class(group, "bar")
    update = NCEdit::Cmd.ensure_param(group, "bar", "baz", "clive")
    expect(group["classes"].has_key?("bar")).to be true
    expect(group["classes"]["bar"].has_key?("baz")).to be true
    expect(group["classes"]["bar"]["baz"]).to eq "clive"
    expect(update).to be true
  end

  it "ensure_param does not error when param exists" do
    group = { "classes" => {"foo" => {"bar" => "baz"}}}

    update = NCEdit::Cmd.ensure_param(group, "foo", "bar", "baz")
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("bar")).to be true
    expect(group["classes"]["foo"]["bar"]).to eq "baz"
    expect(update).to be false
  end

  it "deletes classes correctly" do
    group = {"classes" => {"foo"=>{}, "bar"=>{}}}

    # use fake puppetclassify
    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.delete_classes("test", ["foo","bar"])
    expect(group["classes"].has_key?("foo")).to be false
    expect(group["classes"].has_key?("bar")).to be false
    expect(update).to be true
  end

  it "deletes classes idempotently" do
    group = {"classes" => {"foo1"=>{}, "bar1"=>{}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.delete_classes("test", ["foo","bar"])
    expect(group["classes"].has_key?("foo1")).to be true
    expect(group["classes"].has_key?("bar1")).to be true
    expect(update).to be false
  end


  it "deletes params correctly" do
    group = {"classes" => {"foo"=>{"a"=>"a","b"=>"b"}, "bar"=>{"a"=>"a"}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.delete_params("test", {"foo" => ["a", "b"]})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("a")).to be false
    expect(group["classes"]["foo"].has_key?("b")).to be false

    expect(group["classes"]["bar"].has_key?("a")).to be true
    expect(update).to be true
  end

  it "deletes params idempotently" do
    group = {"classes" => {"foo"=>{"a1"=>"a","b1"=>"b"}, "bar"=>{"a"=>"a"}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.delete_params("test", {"foo" => ["a", "b"]})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("a1")).to be true
    expect(group["classes"]["foo"].has_key?("b1")).to be true

    expect(update).to be false
  end

  it "creates simple classes" do
    group = {"classes" => {}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params("test", {"foo" =>{}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be true
  end

  it "creates classes idempotently" do
    group = {"classes" => {"foo" =>{}, "bar" => {}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params("test", {"foo" =>{}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be false
  end

  it "creates params and classes" do
    group = {"classes" => {}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params("test", {"foo" =>{"a"=>"a","b"=>"b"}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("a")).to be true
    expect(group["classes"]["foo"]["a"]).to eq "a"
    expect(group["classes"]["foo"].has_key?("b")).to be true
    expect(group["classes"]["foo"]["b"]).to eq "b"
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be true
  end

  it "creates params and classes idempotently" do
    group = {"classes" => {"foo" =>{"a"=>"a","b"=>"b"}, "bar" => {}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params("test", {"foo" =>{"a"=>"a","b"=>"b"}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("a")).to be true
    expect(group["classes"]["foo"]["a"]).to eq "a"
    expect(group["classes"]["foo"].has_key?("b")).to be true
    expect(group["classes"]["foo"]["b"]).to eq "b"
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be false
  end

  it "ensures rules correctly" do
    group = {"rule" => nil}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules("test", [
      "or",
      [
        ["=", "name", "vmpump02.puppet.com"],
        ["=", "name", "vmpump03.puppet.com"],
      ]
    ])

    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 2
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"

    expect(group["rule"][1][1][0]).to eq "="
    expect(group["rule"][1][1][1]).to eq "name"
    expect(group["rule"][1][1][2]).to eq "vmpump03.puppet.com"
    expect(update).to be true
  end

  it "appends rules correctly" do
    # ensure_rules(group_name, data.dig("rules"))
    group = {"rule" => ["or", [["=", "name", "vmpump02.puppet.com"]]]}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules("test", [
      "or",
      [
        ["=", "fqdn", "vmpump03.puppet.com"],
        ["=", "fqdn", "vmpump04.puppet.com"],
      ]
    ])

    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 3
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"
    expect(group["rule"][1][1][0]).to eq "="
    expect(group["rule"][1][1][1]).to eq "fqdn"
    expect(group["rule"][1][1][2]).to eq "vmpump03.puppet.com"
    expect(group["rule"][1][2][0]).to eq "="
    expect(group["rule"][1][2][1]).to eq "fqdn"
    expect(group["rule"][1][2][2]).to eq "vmpump04.puppet.com"
    expect(update).to be true
  end

  it "ensures rules idempotently" do
    # ensure_rules(group_name, data.dig("rules"))
    group = {"rule" => ["or", [["=", "name", "vmpump02.puppet.com"],["=", "name", "vmpump03.puppet.com"]]]}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules("test", [
      "or",
      [
        ["=", "name", "vmpump02.puppet.com"],
        ["=", "name", "vmpump03.puppet.com"],
      ]
    ])

    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 2
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"
    expect(group["rule"][1][1][0]).to eq "="
    expect(group["rule"][1][1][1]).to eq "name"
    expect(group["rule"][1][1][2]).to eq "vmpump03.puppet.com"
    expect(update).to be false
  end

  it "handles partial rule updates correctly" do
    # ensure_rules(group_name, data.dig("rules"))
    group = {"rule" => ["or",[["=", "name", "vmpump02.puppet.com"]]]}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules("test", [
      "or",
      [
        ["=", "name", "vmpump02.puppet.com"],
        ["=", "name", "vmpump03.puppet.com"],
      ]
    ])

    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 2
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"
    expect(group["rule"][1][1][0]).to eq "="
    expect(group["rule"][1][1][1]).to eq "name"
    expect(group["rule"][1][1][2]).to eq "vmpump03.puppet.com"
    expect(update).to be true
  end

  it "ensure_rule creates new rule" do
    group = { "rule" => ["or",[]]}

    update = NCEdit::Cmd.ensure_rule(group, ["=", "name", "vmpump02.puppet.com"])
    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 1
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"

    expect(update).to be true
  end

  it "ensure_rule creates new rule idempotently" do
    group = { "rule" => ["or", [["=", "name", "vmpump02.puppet.com"]]]}

    update = NCEdit::Cmd.ensure_rule(group, ["=", "name", "vmpump02.puppet.com"])
    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 1
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"

    expect(update).to be false
  end

  it "ensure_rule appends to end of ruleset" do
    group = { "rule" => ["or", [["=", "name", "vmpump02.puppet.com"]]]}

    update = NCEdit::Cmd.ensure_rule(group, ["=", "name", "vmpump03.puppet.com"])
    expect(group["rule"].size).to be 2
    expect(group["rule"][0]).to eq "or"
    expect(group["rule"][1].size).to be 2
    expect(group["rule"][1][0][0]).to eq "="
    expect(group["rule"][1][0][1]).to eq "name"
    expect(group["rule"][1][0][2]).to eq "vmpump02.puppet.com"
    expect(group["rule"][1][1][0]).to eq "="
    expect(group["rule"][1][1][1]).to eq "name"
    expect(group["rule"][1][1][2]).to eq "vmpump03.puppet.com"
    expect(update).to be true
  end

  it "sets rule conjuction correctly" do
    group = { "rule" => ["or", [["=", "name", "vmpump02.puppet.com"]]]}

    update = NCEdit::Cmd.ensure_rule_conjunction(group, "and")
    expect(update).to be true
    expect(group["rule"][0]).to eq "and"
  end

  it "sets rule conjuction idempotently" do
    group = { "rule" => ["and", [["=", "name", "vmpump02.puppet.com"]]]}

    update = NCEdit::Cmd.ensure_rule_conjunction(group, "and")
    expect(update).to be false
    expect(group["rule"][0]).to eq "and"
  end
end
