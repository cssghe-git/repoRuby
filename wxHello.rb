require 'wx'

class HelloFrame < Wx::Frame
  def initialize
    super(nil, title: 'Hello wxRuby3!', size: [400, 300])

    panel  = Wx::Panel.new(self)
    label  = Wx::StaticText.new(panel, label: 'Hello from wxRuby3!')
    button = Wx::Button.new(panel, label: 'Click me')

    sizer = Wx::VBoxSizer.new
    sizer.add(label,  0, Wx::ALL | Wx::CENTRE, 20)
    sizer.add(button, 0, Wx::ALL | Wx::CENTRE, 10)
    panel.set_sizer(sizer)

    evt_button(button.get_id) { on_click }

    centre
  end

  private

  def on_click
    Wx::message_box('Button clicked!', 'Hello', Wx::OK | Wx::ICON_INFORMATION)
  end
end

Wx::App.run { HelloFrame.new.show }