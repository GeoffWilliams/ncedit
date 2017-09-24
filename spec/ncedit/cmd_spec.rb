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

    update = NCEdit::Cmd.ensure_class(group, "foo", delete:true)
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"]).to be nil
    expect(group["classes"].has_key?("bar")).to be true
    expect(update).to be true
  end

  it "deletes classes idempotently" do
    # foo class gone...
    group = {"classes" => {"bar"=>{}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    # ... so we should NOT be told an update is needed
    update = NCEdit::Cmd.ensure_class(group, "foo", delete:true)
    expect(update).to be false
  end


  it "deletes params correctly" do
    group = {"classes" => {"foo"=>{"a"=>"a","b"=>"b"}, "bar"=>{"a"=>"a"}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_param(group, "foo", "a", nil, delete:true)
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("a")).to be true
    expect(group["classes"]["foo"]["a"]).to be nil
    expect(group["classes"]["foo"].has_key?("b")).to be true

    expect(group["classes"]["bar"].has_key?("a")).to be true
    expect(update).to be true
  end

  it "deletes params idempotently" do
    # a1 parameter already deleted from class foo...
    group = {"classes" => {"foo"=>{"b"=>"b"}, "bar"=>{"a"=>"a"}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_param(group, "foo", "a", nil, delete:true)
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("b")).to be true
    expect(group["classes"]["bar"].has_key?("a")).to be true

    # ...so check no updated flagged as needed
    expect(update).to be false
  end

  it "creates simple classes" do
    group = {"classes" => {}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params(group, {"foo" =>{}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be true
  end

  it "creates classes idempotently" do
    group = {"classes" => {"foo" =>{}, "bar" => {}}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params(group, {"foo" =>{}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be false
  end

  it "creates params and classes" do
    group = {"classes" => {}}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_classes_and_params(group, {"foo" =>{"a"=>"a","b"=>"b"}, "bar" => {}})
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

    update = NCEdit::Cmd.ensure_classes_and_params(group, {"foo" =>{"a"=>"a","b"=>"b"}, "bar" => {}})
    expect(group["classes"].has_key?("foo")).to be true
    expect(group["classes"]["foo"].has_key?("a")).to be true
    expect(group["classes"]["foo"]["a"]).to eq "a"
    expect(group["classes"]["foo"].has_key?("b")).to be true
    expect(group["classes"]["foo"]["b"]).to eq "b"
    expect(group["classes"].has_key?("bar")).to be true

    expect(update).to be false
  end

  it "ensures rules to empty ruleset" do
    group = {"rule" => nil}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules(group, [
      "or",
      [
        ["=", "name", "vmpump02.puppet.com"],
        ["=", "name", "vmpump03.puppet.com"],
      ]
    ])

    expected = [
      "or",
      [
        ["=", "name", "vmpump02.puppet.com"],
        ["=", "name", "vmpump03.puppet.com"],
      ]
    ]

    expect(expected == group["rule"]).to be true
    expect(update).to be true
  end

  it "appends rules correctly" do
    # ensure_rules(group_name, data.dig("rules"))
    group = {"rule" => ["or", ["=", "name", "vmpump02.puppet.com"]]}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules(group, [
      "or",
      ["=", ["fact","zigzag"], "vmpump03.puppet.com"],
      ["=", "fqdn", "vmpump04.puppet.com"],
    ])

    expected = ["or",
       ["=", "name", "vmpump02.puppet.com"],
       ["=", ["fact", "zigzag"], "vmpump03.puppet.com"],
       ["=", "fqdn", "vmpump04.puppet.com"]]

    expect(group["rule"] == expected).to be true
    expect(update).to be true
  end

  it "ensures rules idempotently" do
    # ensure_rules(group_name, data.dig("rules"))
    group = {"rule" => [
      "or",
      ["=", "name", "vmpump02.puppet.com"],
      ["=", "name", "vmpump03.puppet.com"]
    ]}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules(group, [
      "or",
      ["=", "name", "vmpump02.puppet.com"],
      ["=", "name", "vmpump03.puppet.com"],
    ])

    expected = [
      "or",
      ["=", "name", "vmpump02.puppet.com"],
      ["=", "name", "vmpump03.puppet.com"]
    ]

    expect(expected == group["rule"]).to be true
    expect(update).to be false
  end

  it "handles partial rule updates correctly" do
    # ensure_rules(group_name, data.dig("rules"))
    group = {"rule" => ["or",["=", "name", "vmpump02.puppet.com"]]}

    fake_pc = FakePuppetClassify.new(nil,nil)
    fake_pc.groups=(group)
    NCEdit::Cmd.init(fake_pc)

    update = NCEdit::Cmd.ensure_rules(group, [
      "or",
      ["=", "name", "vmpump02.puppet.com"],
      ["=", "name", "vmpump03.puppet.com"],
    ])

    expected = [
      "or",
      ["=", "name", "vmpump02.puppet.com"],
      ["=", "name", "vmpump03.puppet.com"]
    ]

    expect(expected == group["rule"]).to be true
    expect(update).to be true
  end

  it "ensure_rule creates new rule" do
    group = { "rule" => ["or"]}

    expected = ["or", ["=", "name", "vmpump02.puppet.com"]]
    update = NCEdit::Cmd.ensure_rule(group, ["=", "name", "vmpump02.puppet.com"])

    expect(expected == group["rule"]).to be true
    expect(update).to be true
  end

  it "ensure_rule creates new rule idempotently" do
    group = { "rule" => ["or", ["=", "name", "vmpump02.puppet.com"]]}

    update = NCEdit::Cmd.ensure_rule(group, ["=", "name", "vmpump02.puppet.com"])
    expected = ["or", ["=", "name", "vmpump02.puppet.com"]]

    expect(expected == group["rule"]).to be true
    expect(update).to be false
  end

  it "ensure_rule appends to end of ruleset" do
    group = { "rule" => ["or", ["=", "name", "vmpump02.puppet.com"]]}

    update = NCEdit::Cmd.ensure_rule(group, ["=", "name", "vmpump03.puppet.com"])
    expected = [
      "or",
      ["=", "name", "vmpump02.puppet.com"],
      ["=", "name", "vmpump03.puppet.com"]
    ]

    expect(expected == group["rule"]).to be true
    expect(update).to be true
  end

  it "sets rule conjuction correctly" do
    group = { "rule" => ["or", ["=", "name", "vmpump02.puppet.com"]]}

    update = NCEdit::Cmd.ensure_rule_conjunction(group, "and")
    expect(update).to be true
    expect(group["rule"][0]).to eq "and"
  end

  it "sets rule conjuction idempotently" do
    group = { "rule" => ["and", ["=", "name", "vmpump02.puppet.com"]]}

    update = NCEdit::Cmd.ensure_rule_conjunction(group, "and")
    expect(update).to be false
    expect(group["rule"][0]).to eq "and"
  end

  it "reports class delta saved for new class" do
    nc_class    = {"foo" => {}}
    class_delta = {"foo" => {}}

    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be true
  end

  it "reports class delta not saved for new class" do
    nc_class    = {}
    class_delta = {"foo" => {}}

    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be false
  end

  it "reports class delta saved for new param" do
    nc_class    = {"foo" => {"bar"=>"baz"}}
    class_delta = {"foo" => {"bar"=>"baz"}}

    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be true
  end

  it "reports class delta not saved for new param" do
    # wrong value
    nc_class    = {"foo" => {"bar"=>"baz1"}}
    class_delta = {"foo" => {"bar"=>"baz"}}
    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be false

    # missing value
    nc_class    = {"foo" => {}}
    class_delta = {"foo" => {"bar"=>"baz"}}
    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be false

    # missing class
    nc_class    = {}
    class_delta = {"foo" => {"bar"=>"baz"}}
    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be false
  end

  it "reports class delta saved correctly for deleted class" do
    nc_class    = {}
    class_delta = {"foo" => nil}

    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be true
  end

  it "reports class delta saved correctly for deleted param" do
    nc_class    = {"foo" => {}}
    class_delta = {"foo" => {"bar"=>nil}}

    expect(NCEdit::Cmd.delta_saved?(nc_class, class_delta)).to be true
  end

  it "reports if a parameter belongs to r10k settings correctly" do
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::master", "r10k_remote")).to be true
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::master", "r10k_proxy")).to be true
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::master", "r10k_postrun")).to be true
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::master", "r10k_private_key")).to be true
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::master", "code_manager_auto_configure")).to be true

    # protect against namespace clash
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::masterX", "r10k_remote")).to be false
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::masterX", "r10k_proxy")).to be false
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::masterX", "r10k_postrun")).to be false
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::masterX", "r10k_private_key")).to be false
    expect(NCEdit::Cmd.is_r10k_param("puppet_enterprise::profile::masterX", "code_manager_auto_configure")).to be false
  end


  it "reports r10k settings found correctly" do
    data = {
      "frog"=> {},
      "ocean" => {
        "classes" => {
          "blah" => {
            "a" => "a",
          }
        }
      },
      "PE Masters" => {
        "classes" => {
          "puppet_enterprise::profile::master" => {
            "code_manager_auto_configure" => true,
            "r10k_remote" => "https://github.com/GeoffWilliams/r10k-control",
            "r10k_private_key" => "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa",
          },
          "my_other_class" => {}
        }
      }
    }
    res = NCEdit::Cmd.contains_r10k_settings(data)
    expect(res.class).to eq Hash
    expect(res.size).to eq 1
    expect(res.key?("PE Masters")).to be true
    expect(res["PE Masters"].key?("classes")).to be true
    expect(res["PE Masters"]["classes"].key?("puppet_enterprise::profile::master")).to be true
    expect(res["PE Masters"]["classes"]["puppet_enterprise::profile::master"].key?("code_manager_auto_configure")).to be true
    expect(res["PE Masters"]["classes"]["puppet_enterprise::profile::master"].key?("r10k_remote")).to be true
    expect(res["PE Masters"]["classes"]["puppet_enterprise::profile::master"].key?("r10k_private_key")).to be true

    expect(res["PE Masters"]["classes"]["puppet_enterprise::profile::master"]["code_manager_auto_configure"]).to be true
    expect(res["PE Masters"]["classes"]["puppet_enterprise::profile::master"]["r10k_remote"]).to eq "https://github.com/GeoffWilliams/r10k-control"
    expect(res["PE Masters"]["classes"]["puppet_enterprise::profile::master"]["r10k_private_key"]).to eq "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
  end

  it "reports r10k settings not found correctly" do
    data = {
      "PE Masters" => {
        "classes" => {
          "puppet_enterprise::profile::master" => {
              "notarealparam" => "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa",
          }
        }
      }
    }
    expect(NCEdit::Cmd.contains_r10k_settings(data)).to be false

    data = {
      "My Group" => {
        "classes" => {
          "a_different_class" => {
              "example" => "abc",
          }
        }
      }
    }
    expect(NCEdit::Cmd.contains_r10k_settings(data)).to be false

  end


end
