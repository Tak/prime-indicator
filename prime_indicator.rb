#!/usr/bin/env ruby

require 'gtk2'
require 'ruby-libappindicator'

class PrimeIndicator
  def initialize()
    @indicator = AppIndicator::AppIndicator.new('PrimeIndicator', 'nvidia-settings', AppIndicator::Category::APPLICATION_STATUS)
    @reboot_required = false
  end

  def request_switch()
    pid = Process.spawn("gksu --sudo-mode --message 'Elevated privileges are required to switch the selected graphics card' -- prime-select #{@current}")
    Process.wait(pid)
    if ($?.exitstatus == 0)
      pid = Process.spawn("gksu --sudo-mode --message 'Elevated privileges are required to switch the selected graphics card' -- cp /etc/X11/xorg.conf.#{@current} /etc/X11/xorg.conf")
      Process.wait(pid)
      return $?.exitstatus == 0
    end
    return false
  end

  def request_reboot()
    dialog = Gtk::MessageDialog.new(nil, 0, Gtk::MessageDialog::Type::QUESTION, Gtk::MessageDialog::BUTTONS_NONE, 'Reboot is required for this change to take effect.')
    dialog.add_buttons(['Reboot now', 0], ['Reboot later', 1])
    response = dialog.run()
    dialog.destroy()
    if (response == 0)
      pid = Process.spawn("gksu --sudo-mode --message 'Elevated privileges are required to reboot' -- reboot")
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

  def toggle_selection(menu_item)
    @current = (if @current == :nvidia then :intel else :nvidia end)
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
      enable_menu_items()
    else
      puts("Unable to request switch!")
    end
  end

  def enable()
    query()
    menu = Gtk::Menu.new()
    @nvidia = Gtk::RadioMenuItem.new('NVidia')
    @nvidia.active = (@current == :nvidia)
    @nvidia.signal_connect('toggled'){ |item|
      if (item.active?)
        toggle_selection(item)
      end
    }
    menu.append(@nvidia)

    @intel = Gtk::RadioMenuItem.new(@nvidia, 'Intel')
    @intel.active = (@current == :intel)
    @intel.signal_connect('toggled'){ |item|
      if (item.active?)
        toggle_selection(item)
      end
    }
    menu.append(@intel)
    menu.show_all()

    @indicator.set_menu(menu)
    @indicator.set_status(AppIndicator::Status::ACTIVE)
  end

  def query()
    IO.popen('prime-select query') { |io|
      @current = io.read().chomp().to_sym()
    }
    puts("Current selection is '#{@current}'")
  end
end

if (__FILE__ == $0)
  indicator = PrimeIndicator.new()
  indicator.enable()
  Gtk.main()
end