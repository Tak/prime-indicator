require 'gtk3'

module PrimeIndicator
  class PrimeIndicator
    NVIDIA_DISPLAY = 'Nvidia'
    INTEL_DISPLAY = 'Intel'

    def initialize()
      @reboot_required = false
    end

    def self.check_program_using_help(program)
      begin
        pid = Process.spawn("#{program} --help")
        Process.wait(pid)
        return $?.exitstatus == 0
      rescue
      end
      return false
    end

    def self.get_valid_elevator()
      if (check_program_using_help('gksu'))
        return "gksu --sudo-mode --message 'Elevated privileges are required to switch the selected graphics card' --"
      elsif (check_program_using_help('pkexec'))
        return 'pkexec'
      else
        # Not sure whether it's better to override a rarely configured askpass
        # or to try to guess one
        return "sudo -HA --"
      end
    end

    def self.run_command_using_permission_elevator(elevator, command)
      command = "#{elevator} #{command}"
      print(command)
      pid = Process.spawn(command)
      Process.wait(pid)
      return ($?.exitstatus == 0)
    end

    def request_switch
      elevator = PrimeIndicator.get_valid_elevator()
      return (PrimeIndicator.run_command_using_permission_elevator(elevator, "prime-select #{@current}")) ?
        PrimeIndicator.run_command_using_permission_elevator(elevator, "cp /etc/X11/xorg.conf.#{@current} /etc/X11/xorg.conf") :
        false
    end

    def request_reboot()
      dialog = Gtk::MessageDialog.new(nil, 0, Gtk::MessageDialog::Type::QUESTION, Gtk::MessageDialog::BUTTONS_NONE, 'Reboot is required for this change to take effect.')
      dialog.add_buttons(['Reboot now', 0], ['Reboot later', 1])
      response = dialog.run()
      dialog.destroy()
      if (response == 0)
        elevator = PrimeIndicator.get_valid_elevator()
        pid = Process.spawn("#{elevator} reboot")
        Process.detach(pid)
      end
    end

    def enable_menu_items()
      @intel.sensitive = true
      @nvidia.sensitive = true
    end

    def disable_menu_items()
      @intel.sensitive = false
      @nvidia.sensitive = false
    end

    def toggle_current()
      @current = @current == :nvidia ? :intel : :nvidia
    end

    def toggle_selection(menu_item)
      toggle_current()
      puts("Selected #{@current}")
      disable_menu_items()

      if (request_switch())
        if (@reboot_required)
          # Reset!
          enable()
        else
          @reboot_required = true
          menu_item.label += '(*)'
          request_reboot()
        end
      else
        puts("Unable to request switch!")
        toggle_current()
      end
      enable_menu_items()
    end

    def enable()
      query()
      selection_display = @current == :nvidia ? NVIDIA_DISPLAY : INTEL_DISPLAY
      @icon = Gtk::StatusIcon.new()
      # TODO: better icon
      @icon.file = '/usr/share/pixmaps/nvidia-settings.png'
      @icon.tooltip_text = "Prime Indicator (#{selection_display})"
      @icon.visible = true

      @menu = Gtk::Menu.new()
      @nvidia = Gtk::RadioMenuItem.new(nil, NVIDIA_DISPLAY)
      @nvidia.active = (@current == :nvidia)
      @nvidia.signal_connect('toggled'){ |item|
        if (item.active?)
          toggle_selection(item)
        end
      }
      @menu.append(@nvidia)

      @intel = Gtk::RadioMenuItem.new(@nvidia, INTEL_DISPLAY)
      @intel.active = (@current == :intel)
      @intel.signal_connect('toggled'){ |item|
        if (item.active?)
          toggle_selection(item)
        end
      }
      @menu.append(@intel)
      @menu.show_all()

      @icon.signal_connect('activate') do |icon|
        @menu.popup(nil, nil, 1, Gdk::CURRENT_TIME) { |menu, x, y, push_in| Gtk::StatusIcon.position_menu(menu, x, y, icon) }
      end
      @icon.signal_connect('popup-menu') do |icon, button, time|
        @menu.popup(nil, nil, button, time) { |menu, x, y, push_in| Gtk::StatusIcon.position_menu(menu, x, y, icon) }
      end
    end

    def query()
      IO.popen('prime-select query') { |io|
        @current = io.read().chomp().to_sym()
      }
      puts("Current selection is '#{@current}'")
    end
  end
end
