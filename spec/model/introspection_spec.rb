# encoding: utf-8
require File.join(File.dirname(__FILE__), "../spec_helper.rb")

describe Her::Model::Introspection do
  context "introspecting a resource" do
    before do
      Her::API.setup :url => "https://api.example.com" do |builder|
        builder.use Her::Middleware::FirstLevelParseJSON
        builder.use Faraday::Request::UrlEncoded
        builder.adapter :test do |stub|
          stub.post("/users")     { |env| [200, {}, { :id => 1, :name => "Tobias Funke" }.to_json] }
          stub.get("/users/1")    { |env| [200, {}, { :id => 1, :name => "Tobias Funke" }.to_json] }
          stub.put("/users/1")    { |env| [200, {}, { :id => 1, :name => "Tobias Funke" }.to_json] }
          stub.delete("/users/1") { |env| [200, {}, { :id => 1, :name => "Tobias Funke" }.to_json] }
          stub.get("/projects/1/comments") { |env| [200, {}, [{ :id => 1, :body => "Hello!" }].to_json] }
          stub.get("/users/2")    { |env| [200, {}, { :id => 2, :name => "Lindsay Fünke", :role => { :id => 1, name: "Member" }, :comments => [{ :id => 1, :body => "They're having a FIRESALE?", :user_id => 2 }] }.to_json] }
        end
      end

      spawn_model "Foo::User" do
        has_many :comments, class_name: "Foo::Comment"
        has_one :role
      end
      spawn_model "Foo::Comment" do
        collection_path "projects/:project_id/comments"
      end
      spawn_model "Foo::Role"
    end

    describe "#inspect" do
      it "outputs resource attributes for an existing resource" do
        @user = Foo::User.find(1)
        ["#<Foo::User(users/1) name=\"Tobias Funke\" id=1>", "#<Foo::User(users/1) id=1 name=\"Tobias Funke\">"].should include(@user.inspect)
      end

      it "outputs resource attributes for an not-saved-yet resource" do
        @user = Foo::User.new(:name => "Tobias Funke")
        @user.inspect.should == "#<Foo::User(users) name=\"Tobias Funke\">"
      end

      it "outputs resource attributes using getters" do
        @user = Foo::User.new(:name => "Tobias Funke", :password => "Funke")
        @user.instance_eval {def password; 'filtered'; end}
        @user.inspect.should include("name=\"Tobias Funke\"")
        @user.inspect.should include("password=\"filtered\"")
        @user.inspect.should_not include("password=\"Funke\"")
      end

      it "support dash on attribute" do
        @user = Foo::User.new(:'life-span' => "3 years")
        @user.inspect.should include("life-span=\"3 years\"")
      end

      it "omits associations' detail attributes" do
        @user = Foo::User.find(2)
        @user.inspect.should include("role=#<Foo::Role>")
        @user.inspect.should include("comments=[#<Foo::Comment>(1)]")
      end
    end

    describe "#inspect with errors in resource path" do
      it "prints the resource path as “unknown”" do
        @comment = Foo::Comment.where(:project_id => 1).first
        path = '<unknown path, missing `project_id`>'
        ["#<Foo::Comment(#{path}) body=\"Hello!\" id=1>", "#<Foo::Comment(#{path}) id=1 body=\"Hello!\">"].should include(@comment.inspect)
      end
    end
  end

  describe "#her_nearby_class" do
    context "for a class inside of a module" do
      before do
        spawn_model "Foo::User"
        spawn_model "Foo::AccessRecord"
        spawn_model "AccessRecord"
        spawn_model "Log"
      end

      it "returns a sibling class, if found" do
        Foo::User.her_nearby_class("AccessRecord").should == Foo::AccessRecord
        AccessRecord.her_nearby_class("Log").should == Log
        Foo::User.her_nearby_class("Log").should == Log
        Foo::User.her_nearby_class("X").should be_nil
      end
    end
  end
end
