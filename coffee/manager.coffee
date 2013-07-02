
DefaultSystem = new LSystem({
    size: {value:12.27}
    angle: {value:4187.5}
  }
  ,{}
  ,{
    size: {value:1}
  }
  ,"L : SS\nS : F->[F-Y[S(L]]\nY : [-|F-F+)Y]\n"
  ,12
  ,"click-and-drag-me!"
)

class InputHandler
  snapshot: null # lsystem params as they were was when joystick activated
  constructor: (@keystate, @joystick) ->
  update: (system) =>
    return if not @joystick.active
    if (@keystate.alt)
      system.params.size.value = Util.round(@snapshot.params.size.value + (@joystick.dy(system.sensitivities.size.value)), 2)
      system.params.size.growth = Util.round(@snapshot.params.size.growth + @joystick.dx(system.sensitivities.size.growth),6)
    else if (@keystate.meta or @keystate.ctrl)
      system.offsets.x = @snapshot.offsets.x + @joystick.dx()
      system.offsets.y = @snapshot.offsets.y + @joystick.dy()
    else
      system.params.angle.value = Util.round(system.params.angle.value + @joystick.dx(system.sensitivities.angle.value), 2)
      system.params.angle.growth = Util.round(system.params.angle.growth + @joystick.dy(system.sensitivities.angle.growth),9)


#yes this is an outrageous name for a .. system ... manager. buh.
class SystemManager
  joystick:null
  keystate: null
  inputHandler: null
  renderer:null
  currentSystem:null
  constructor: (@canvas, @controls) ->
    @joystick = new Joystick(canvas)
    @keystate = new KeyState
    @inputHandler = new InputHandler(@keystate, @joystick)

    @joystick.onRelease = => @syncLocation()
    @joystick.onActivate = => @inputHandler.snapshot = @currentSystem.clone()

    @renderer = new Renderer(canvas)
    @currentSystem = LSystem.fromUrl() or DefaultSystem
    @init()

  syncLocation: -> location.hash = @currentSystem.toUrl()
  syncLocationQuiet: -> location.quietSync = true; @syncLocation()

  updateFromControls: ->
    @currentSystem = new LSystem(
      @paramControls.toJson(),
      @offsetControls.toJson(),
      @sensitivityControls.toJson(),
      $(@controls.rules).val(),
      parseInt($(@controls.iterations).val()),
      @currentSystem.name
    )

  exportToPng: ->
    [x,y] = [@canvas.width / 2 , @canvas.height / 2]

    b = @renderer.context.bounding
    c = $('<canvas></canvas>').attr({
      "width" : b.width()+30,
      "height": b.height()+30
    })[0]

    r = new Renderer(c)
    r.reset = (system) ->
      r.context.reset(system)
      r.context.state.x = (x-b.x1+15)
      r.context.state.y = (y-b.y1+15)

    r.render(@currentSystem)
    Util.openDataUrl(c.toDataURL("image/png"))

  init: ->
    @createBindings()
    @createControls()
    @syncControls()

  run: ->
    @inputHandler.update(@currentSystem)
    if @joystick.active and not @renderer.isDrawing
      @draw()
      @joystick.draw()
      @syncControls()
    setTimeout((() => @run()), 10)

  draw: ->
    t = @renderer.render(@currentSystem)
    #todo: get from bindings
    $("#rendered").html("#{t}ms")
    $("#segments").html("#{@currentSystem.elements().length}")

  createControls: ->
    @paramControls = new Controls(Defaults.params(), ParamControl)
    @offsetControls = new OffsetControl(Defaults.offsets())
    @sensitivityControls = new Controls(Defaults.sensitivities(), SensitivityControl)

    @paramControls.create(@controls.params)
    @offsetControls.create(@controls.offsets)
    @sensitivityControls.create(@controls.sensitivities)

  syncControls: ->
    $(@controls.iterations).val(@currentSystem.iterations)
    $(@controls.rules).val(@currentSystem.rules)
    @paramControls.sync(@currentSystem.params)
    @offsetControls.sync(@currentSystem.offsets)
    @sensitivityControls.sync(@currentSystem.sensitivities)

  createBindings: ->
    setMoving = (ev) =>
      method = if (ev.metaKey or ev.ctrlKey) then 'add' else 'remove'
      $(@canvas)["#{method}Class"]('moving')

    document.addEventListener("keydown", (ev) =>
      if ev.keyCode == Key.enter and ev.ctrlKey
        @updateFromControls()
        @syncLocation()
        return false
      if ev.keyCode == Key.enter and ev.shiftKey
        @exportToPng()
      setMoving(ev)
    )

    document.addEventListener("keyup", setMoving)
    document.addEventListener("mousedown", setMoving)

    window.onhashchange = =>
      if location.hash != ""
        sys = LSystem.fromUrl()
        @currentSystem.merge(sys)
        @syncControls()
        @draw() if not location.quietSync
        location.quietSync = false

#===========================================
