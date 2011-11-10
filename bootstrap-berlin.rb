#!/usr/bin/env ruby

require './init'

config = YAML.load_file("config.yml")["config"]
bootstrap = config["bootstrap"]
folder_path = bootstrap["folder_path"]

adder = RustRadio::ShowAdder.new
adder.remove_all
adder.add(folder_path)

