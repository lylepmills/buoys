# buoys

buoys is an app for [norns](https://monome.org/norns/).

READ THIS FIRST: If you're just trying to get started with buoys, make sure to look below for the instructions on reaching "meta mode". You'll need to know how to do that so you can load samples into the app. Otherwise, if docs aren't your thing, most things should be possible to figure out on your own with a little imagination :-)

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

## Notes / Errata
buoys is not intended to be a perfect physical simulation of waves moving in water, or even a very good one. It's just good enough to get a nice-enough looking approximation, and many corners have been cut. Even so, it's not impossible to overtax the norns processor by pushing it to extremes. Several safeguards have been put in place to make it harder to shoot yourself in the foot, but these aren't guaranteed to work 100% of the time so just bear that in mind. Generally speaking the more big tides are on the grid at any given time, the harder the physical simulation is having to work. By the same token the app may try to prevent you from doing things that it knows are going to overtax it, for instance setting too fast of a tide advance time with high clock multipliers (you'll get a warning and the clock multiplier will automatically downshift). You have been warned.

## Parameters Guide

### App parameters
**channel style** - open vs flume. An open channel allows tides to escape out the edges, whereas a flume will not.

**extended buoy params** - if on, you'll see more detailed options when editing buoys, such as setting zenith and nadir points.

**smoothing** - if on, the grid lighting will smoothly morph between one state and the next, giving a more natural appearance. If off, you will see a more honest representation of the app state in terms of the current tide depths that buoys will be responding to.

**pausing** - pause buoys vs continue. If set to pause buoys, playback of any sounds associated with buoys will pause immediately when the tides pause. If set to continue, they will not - non-looping buoys will play to their end point, and looping buoys will continue looping indefinitely.

**unpausing** - resume vs reset buoys. If set to resume, buoys will continue playing back from wherever they are in their buffer (regardless of the "pausing" setting). If set to reset buoys, They will reset to their start points. This can be use as a means of syncing loops.

**tide height multiplier**, **tide shape index**, **tide angle**, **dispersion** - same as described above in the arc section. Since these are regular norns app parameters they can be mapped to an external midi controller. The only difference is that without an arc, you won't get the circular morphing of the tide shape index.

**crow input 1**, **crow input 2** - note that both crow inputs cannot be set to the same option, except "none"
- none - the input does nothing
- clock - the input serves as a clock in for syncing to analog clock
- run - if the input is high (5V or greater), the tides will advance, if the input is low they will pause
- start/stop - if the input goes high, the tides will pause if they were running or unpause if they were paused
- reset - if the input goes high, all tides on the grid will be immediately cleared and a new tide will begin
- cv tide height - controls tide height multiplier, 0v to 5v
- cv tide shape - controls the tide shape, 0v to 5v
- cv tide angle - controls the tide angle, -5v to 5v
- cv dispersion - controls dispersion, -5v to 5v

**background brightness** - this sets the LED brightness level of grid keys that have a tide depth of zero. By default it is set to 1 but if you're in a bright space it may be hard to see the difference between a brightness of 1 and a brightness of 0 (for a piling), so this can help increase that contrast.

**max depth** - this sets the max depth for all tides. By default it's 14 because that's the difference between the max LED brightness for the grid (15) and the default background brightness (1). The main utility of this option is as a performance tweak - higher tides require the processor to work harder in the physical modeling of the tides, so if you don't need all 14 steps of resolution for whatever you're using the app for, turning this down can help with overall performance.

**arc orientation** - if set to horizontal, the LED animations that accompany the four arc encoders will be oriented for horizontal use, ditto for vertical.

### Buoy parameters
Coming soon
