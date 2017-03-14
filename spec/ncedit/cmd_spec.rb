require "spec_helper"
require "ncedit/cmd"

RSpec.describe NCEdit::Cmd do
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

  it "ensure rules correctly" do
    # ensure_rules(group_name, data.dig("rules"))
  end

  it "ensure rules idempotently" do
    # ensure_rules(group_name, data.dig("rules"))
  end

end
