require 'rrd'
require 'faraday'
require 'nokogiri'

module RustRadio
  class RRD

    def initialize(config_file)
      @config = YAML.load_file(config_file)["config"]
      initialize_rrd(@config["rrd"]["path"])
    end

    def update!
      if @rrd.update(Time.now, listener_count)
        puts "updated listener count: #{listener_count}"
      else
        puts @rrd.error
        puts "error updating..."
      end
    end

    private

    def initialize_rrd(rrd_path)
      @rrd = ::RRD::Base.new(rrd_path) 

      unless File.exist?(rrd_path)
        puts "creating RRD file: #{rrd_path}"
        # fix strange off-by-one hour
        @rrd.create start: Time.now - 3600, step: 60.seconds do
          datasource "listeners", type: :gauge, heartbeat: 120.seconds, min: 0, max: :unlimited
          archive :average, every: 120.seconds, during: 1.month
        end
      end
    end

    def listener_count
      icecast = @config["icecast"]

      username = icecast["admin"]["username"]
      password = icecast["admin"]["password"]
      protocol = icecast["protocol"]
      hostname = icecast["hostname"]
      port = icecast["port"]

      xml_host = "#{protocol}://#{hostname}:#{port}"
      xml_path = "/admin/stats.xml"

      get_xml_count(xml_host, username, password, xml_path, "/icestats/listeners")
    end

    def get_xml_count(xml_host, username, password, xml_path, xpath)
      conn = Faraday.new(url: xml_host)
      conn.basic_auth(username, password)
      response = conn.get(xml_path)

      xml = response.body
      xml_doc = Nokogiri::XML(xml)
      xml_doc.xpath("#{xpath}/text()").to_s.to_i
    end

  end
end
