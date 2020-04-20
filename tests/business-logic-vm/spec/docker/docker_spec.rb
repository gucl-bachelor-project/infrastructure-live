require 'spec_helper'
require 'docker'

set :backend, :docker

describe "Docker" do
  before(:all) do
    @container = Docker::Container.get('main-app')
    set :docker_container, @container.id
  end

  describe host('db-access-app') do
    it { should be_reachable } # Ping
  end

  describe port(8080) do
    it { should be_listening }
  end
end
