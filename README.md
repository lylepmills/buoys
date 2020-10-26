# buoys

buoys is an app for [norns](https://monome.org/norns/).

READ THIS FIRST: If you're just trying to get started with buoys, make sure to look below for the instructions on reaching "meta mode". You'll need to know how to do that so you can load samples into the app. Otherwise, if docs aren't your thing, most things should be possible to figure out on your own with a little imagination.

## Concept

A tide of light moves across the grid, activating sounds and modulations as the tide interacts with any number of "buoys" that have been placed anywhere in its path. The core physical metaphor is that of a wave/tide of water moving through space and having interactions with objects in the water along the way. Besides buoys, pilings are the other type of object that can be placed in the water. Unlike buoys, pilings do not yield to the tide, the tide yields to them. The tide will be disrupted by pilings it runs into as it moves along. On the grid, brighter lights correspond to deeper "waters".

The app requires only an 8x16 varibright [monome grid](https://monome.org/docs/grid/) and the norns to run. However if connected, an [arc](https://monome.org/docs/arc/) can be used to expose four useful tide parameters for more immediate interaction, and provide visual feedback on those parameters. buoys also plays nice with both [crow](https://monome.org/docs/crow/) and midi devices.

## Buoys 

Each buoy can be associated with a sound. As the buoy gets lifted up and down by the tide, any number of sonic parameters can be modulated proportionally to the momentary depth of the tide, such as playback volume, playback rate, filter cutoffs, and more. Additionally other modulations related to the momentary tide depth can be sent out via crow or midi.

## UI Interactions Guide

### Norns
**Screen** - the default view shows pilings and buoys. Pilings are displayed as solid circles, whereas buoys are displayed as a square within a square. When that buoy is actively playing a sound, the inner square will light up brighter.

**K2** - toggles between two ways of displaying buoys on the grid. By default they are not shown on the grid, however their locations are still visible on the norns screen. When K2 is pressed, they will instead appear at maximum brightness. This is so you can easily find them when you need to, but also enjoy the waves display on its own without those bright lights when you don't need them.

**K3** - pauses and unpauses the tides. There are various options for how the sounds should react when the tides are paused in the params page.

**K2+K3 (both held)** - while held, switches the grid to a tide editor. You can edit and recall 8 different tide shapes, which can be switched between using the grid buttons on the far left. The remaining grid buttons set the tide depth from 0 to 14 (best viewed sideways), with the top row corresponding to the first segment of the next tide which will be generated. You can turn several adjacent tide shapes into a bigger tide with more than 8 segments - in order to do so, you press two buttons in the far left column instead of one. They can wrap around (#8->#1) so the order in which you press the two buttons matters.

**E1** - this isn't essential to the app (but may be for future versions). For now it's a macro which gently adjusts reverb.

**E2** - makes adjustments to the tide advance time. The tide advance time is how long it takes, in seconds, for the tide to move one grid square from the left to the right. If the app is being synced to a clock either via crow or via midi in, this instead controls a clock multiplier setting.

**E3** - makes adjustments to the tide gap. The tide gap is how many tide advancements occur between new tides. In other words the overall time it takes between tides is (tide advance time * tide gap).

### Grid
**Long press and hold** any key on the grid to edit a buoy there. You can press more than one key and buoys at all held spots will be edited. 

**Short press** any grid key to toggle whats there - buoy vs piling vs nothing. If a buoy has never been edited on that key, then you'll just be toggling between piling and nothing.

**Press all four keys on the corners** to get to meta mode. This is where you can do more setup type things that you probably don't want to use while performing but will need to do from time to time, like load a folder of samples.

### Arc
The experience of using an arc definitely enhances buoys, however all the parameters you can access using arc can also be accessed in the parameters page and/or be mapped to an external midi controller (ideally one with knobs/encoders), so if you don't have one you are still gonna be just fine. The lighting displays on the arc are designed for horizontal use by default but can be switched to vertical by an option on the parameters page.

**First ring** - Tide height multiplier. This can scale up or down the overall height of your tides without having to manually edit the tide shape in the tide shape editor.

**Second ring** - Tide shape. This smoothly morphs between the 8 wave shapes (circularly) as defined in the wave shape editor, with interpolation between adjacent shapes.

**Third ring** - Tide angle. Adjusts the onset angle of the tide from -60 degrees to +60 degrees.

**Fourth ring** - Dispersion. Adjusts the tendency of brighter tides to disperse into dimmer ones. By default it's set to a moderate level, to simulate reality, but reality is only a starting point. You can push it up or down from there. In the middle there is a dead zone of no dispersion, which is indicated by the lights when all the leds around the ring are on but at the dimmest level. If you continue CCW from there you reach the mysterious range of negative dispersion, where dimmer tides instead coalesce into brighter ones.

## Parameters Guide
Coming soon
