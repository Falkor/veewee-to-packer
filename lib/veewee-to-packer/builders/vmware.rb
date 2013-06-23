require "fileutils"

module VeeweeToPacker
  module Builders
    class VMware
      GUESTOS_MAP = {
        "Ubuntu" => "ubuntu",
        "Ubuntu_64" => "ubuntu-64"
      }

      def self.name
        "vmware"
      end

      def self.convert(input, input_dir, output_dir)
        warnings = []
        builder = { "type" => "vmware" }

        if input[:boot_cmd_sequence]
          builder["boot_command"] = input.delete(:boot_cmd_sequence).map do |command|
            command = command.gsub("<Esc>", "<esc>").
              gsub("<Enter>", "<enter>").
              gsub("<Return>", "<return>").
              gsub("<Tab>", "<tab>").
              gsub("%IP%", "{{ .HTTPIP }}").
              gsub("%PORT%", "{{ .HTTPPort }}")

            # We insert a wait after every command because that is the behavior
            # of Veewee
            "#{command}<wait>"
          end
        end

        if input[:boot_wait]
          builder["boot_wait"] = "#{input.delete(:boot_wait)}s"
        end

        if input[:disk_size]
          builder["disk_size"] = input.delete(:disk_size).to_i
        end

        if input[:os_type_id]
          guestos_id = input.delete(:os_type_id)
          guestos = GUESTOS_MAP[guestos_id]
          if !guestos
            guestos = "other"
            warnings << "Unknown guest OS type: '#{guestos_id}'. Using 'other'."
          end

          builder["guest_os_type"] = guestos
        end

        if input[:kickstart_file]
          http_dir = output_dir.join("http")
          http_dir.mkpath

          kickstart_file_src = Pathname.new(File.expand_path(input.delete(:kickstart_file), input_dir))
          kickstart_file_dest = http_dir.join(kickstart_file_src.basename)

          FileUtils.cp(kickstart_file_src, kickstart_file_dest)

          builder["http_directory"] = "http"
        end

        builder["iso_md5"] = input.delete(:iso_md5)
        builder["iso_url"] = input.delete(:iso_src)

        builder["ssh_username"] = input.delete(:ssh_user) if input[:ssh_user]
        builder["ssh_password"] = input.delete(:ssh_password) if input[:ssh_password]
        builder["ssh_port"] = input.delete(:ssh_guest_port).to_i if input[:ssh_guest_port]
        builder["ssh_wait_timeout"] = "#{input.delete(:ssh_login_timeout)}s" if input[:ssh_login_timeout]

        builder["shutdown_command"] = input.delete(:shutdown_cmd) if input[:shutdown_cmd]
        if builder["shutdown_command"] && input[:sudo_cmd]
          sudo_command = input.delete(:sudo_cmd).
            gsub("%p", builder["ssh_password"]).
            gsub("%f", "shutdown.sh")

          builder["shutdown_command"] = "echo '#{builder["shutdown_command"]}' > shutdown.sh; #{sudo_command}"
        end

        builder["vmx_data"] = {}

        if input[:memory_size]
          builder["vmx_data"]["memsize"] = input.delete(:memory_size)
        end

        if input[:cpu_count]
          builder["vmx_data"]["numvcpus"] = input.delete(:cpu_count)
          builder["vmx_data"]["cpuid.coresPerSocket"] = "1"
        end

        # These are unused, so just ignore them.
        input.delete(:disk_format)
        input.delete(:kickstart_port)
        input.delete(:kickstart_timeout)
        input.delete(:hostiocache)
        input.delete(:iso_download_timeout)
        input.delete(:iso_file)
        input.delete(:ssh_host_port)
        input.delete(:ssh_key)

        if input.length > 0
          raise Error, "Uknown keys: #{input.keys.sort.inspect}"
        end

        return builder
      end
    end
  end
end
