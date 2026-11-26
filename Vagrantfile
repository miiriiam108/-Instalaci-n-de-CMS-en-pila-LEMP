# -*- mode: ruby -*-
# vi: set ft=ruby :

# Cargar variables desde el fichero .env si existe
env_file = File.join(__dir__, ".env")
if File.exist?(env_file)
  File.readlines(env_file).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    ENV[key] = value.gsub(/\A['"]|['"]\z/, "") if key && value
  end
end

VM_NAME = ENV["VM_NAME"] || "lempMiriam"

Vagrant.configure("2") do |config|
  config.vm.define VM_NAME do |machine|
    machine.vm.box = "debian/bookworm64"
    machine.vm.hostname = VM_NAME

    # Mapeo de puertos: 8080 -> 80 (HTTP) y 8443 -> 443 (HTTPS)
    machine.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: false
    machine.vm.network "forwarded_port", guest: 443, host: 8443, auto_correct: false

    # Recursos recomendados en VirtualBox
    machine.vm.provider "virtualbox" do |vb|
      vb.name = VM_NAME
      vb.memory = "2048"
      vb.cpus = 2
    end

    # Aprovisionamiento automático en orden
    machine.vm.provision "shell", path: "provision/lemp.sh"
    machine.vm.provision "shell", path: "provision/wordpress.sh"
    machine.vm.provision "shell", path: "provision/https.sh"
  end
end
