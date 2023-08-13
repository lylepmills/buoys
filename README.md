# buoys

buoys is an app for [norns](https://monome.org/norns/).

READ THIS FIRST: If you're just trying to get started with buoys, make sure to look below for the instructions on reaching "meta mode". You'll need to know how to do that so you can load samples into the app. Otherwise, if docs aren't your thing, most things should be possible to figure out on your own with a little imagination :-)

Discussion at https://llllllll.co/t/buoys/37639.

Video walkthroughts at https://vimeo.com/showcase/7782830.

## Concept

A tide of light moves across the grid, activating sounds and modulations as the tide interacts with any number of "buoys" that have been placed anywhere in its path. The core physical metaphor is that of a wave/tide of water moving through space and having interactions with objects in the water along the way. Besides buoys, pilings are the other type of object that can be placed in the water. Unlike buoys, pilings do not yield to the tide, the tide yields to them. The tide will be disrupted by pilings it runs into as it moves along. On the grid, brighter lights correspond to deeper "waters".

The app requires only an varibright [monome grid](https://monome.org/docs/grid/) (8x16 or 16x16) and the norns to run. However if connected, an [arc](https://monome.org/docs/arc/) can be used to expose four useful tide parameters for more immediate interaction, and provide visual feedback on those parameters. buoys also plays nice with both [crow](https://monome.org/docs/crow/) and midi devices.

## Buoys

Each buoy can be associated with a sound. As the buoy gets lifted up and down by the tide, any number of sonic parameters can be modulated proportionally to the momentary depth of the tide, such as playback volume, playback rate, filter cutoffs, and more. Additionally other modulations related to the momentary tide depth can be sent out via crow or midi.

## UI Interactions Guide

### Norns
**Screen** - the default view shows pilings and buoys. Pilings are displayed as solid circles, whereas buoys are displayed as a square within a square. When that buoy is actively playing a sound, the inner square will light up brighter.

**K1** - long-press to get to meta mode. This is where you can do more setup type things that you probably don't want to use while performing but will need to do from time to time, like load a folder of samples.

**K2** - toggles between two ways of displaying buoys on the grid. By default they are not shown on the grid, however their locations are still visible on the norns screen. When K2 is pressed, they will instead appear at maximum brightness. This is so you can easily find them when you need to, but also enjoy the tides display on its own without those bright lights when you don't need them.

**K3** - pauses and unpauses the tides. There are various options for how the sounds should react when the tides are paused in the params page.

**K2+K3 (both held)** - while held, switches the grid to a tide editor. NOTE: the view of this page is rotated counter-clockwise on 8x16 grids in order to make it fit - correspondingly on 8x16 grids you can only have 8 tide shapes with a maximum of 8 segments, whereas on 16x16 grids you can have 16 tide shapes each with up to 16 segments. You can switch between tide shapes using the grid buttons on the top (or the far left on an 8x16 grid). The remaining grid buttons set the tide depth from 0 to 14, with the far-right (top on 8x16) row corresponding to the first segment of the next tide which will be generated. You can turn several adjacent tide shapes into a bigger tide with more than 16/8 segments - in order to do so, you press two buttons in the far left column instead of one. They can wrap around (#16->#1 or #8->#1) so the order in which you press the two buttons matters.

**E1** - this isn't essential to the app (but may be for future versions). For now it's a macro which gently adjusts reverb.

**E2** - makes adjustments to the tide advance time. The tide advance time is how long it takes, in seconds, for the tide to move one grid square from the left to the right. If the app is being synced to a clock either via crow or via midi in, this instead controls a clock multiplier setting.

**E3** - makes adjustments to the tide gap. The tide gap is how many tide advancements occur between new tides. In other words the overall time it takes between tides is (tide advance time * tide gap). It's possible to set a tide gap that is less than the width of the tide, so for instance a tide gap of 3 will just constantly cycle between the first 3 segments of the tide (1, 2, 3, 1, 2, 3...).

### Grid
**Long press and hold** any key on the grid to edit a buoy there. You can press more than one key and buoys at all held spots will be edited.

**Short press** any grid key to toggle whats there - buoy vs piling vs nothing. If a buoy has never been edited on that key, then you'll just be toggling between piling and nothing.

### Arc
The experience of using an arc definitely enhances buoys, however all the parameters you can access using arc can also be accessed in the parameters page and/or be mapped to an external midi controller (ideally one with knobs/encoders), so if you don't have one you are still gonna be just fine. The lighting displays on the arc are designed for horizontal use by default but can be switched to vertical by an option on the parameters page.

**First ring** - Tide height multiplier. This can scale up or down the overall height of your tides without having to manually edit the tide shape in the tide shape editor.

**Second ring** - Tide shape. This smoothly morphs between the 8 tide shapes (circularly) as defined in the tide shape editor, with interpolation between adjacent shapes.

**Third ring** - Tide angle. Adjusts the onset angle of the tide from -60 degrees to +60 degrees.

**Fourth ring** - Dispersion. Adjusts the tendency of brighter tides to disperse into dimmer ones. By default it's set to a moderate level, to simulate reality, but reality is only a starting point. You can push it up or down from there. In the middle there is a dead zone of no dispersion, which is indicated by the lights when all the leds around the ring are on but at the dimmest level. If you continue CCW from there you reach the mysterious range of negative dispersion, where dimmer tides instead coalesce into brighter ones.

## Parameters Guide

### App parameters
**channel style** - open vs flume. An open channel allows tides to escape out the edges, whereas a flume will not.

**extended buoy params** - if on, you'll see more detailed options when editing buoys, such as setting zenith and nadir points.

**midi buoy params** - if on, you'll see options for midi outputs when editing buoys.

**smoothing** - if on, the grid lighting will smoothly morph between one state and the next, giving a more natural appearance. If off, you will see a more honest representation of the app state in terms of the current tide depths that buoys will be responding to.

**pausing** - pause buoys vs continue. If set to pause buoys, playback of any sounds associated with buoys will pause immediately when the tides pause. If set to continue, they will not - non-looping buoys will play to their end point, and looping buoys will continue looping indefinitely.

**unpausing** - resume vs reset buoys. If set to resume, buoys will continue playing back from wherever they are in their buffer (regardless of the "pausing" setting). If set to reset buoys, They will reset to their start points. This can be used as a means of syncing loops.

**tide height multiplier**, **tide shape index**, **tide angle**, **dispersion** - same as described above in the arc section. Since these are regular norns app parameters they can be mapped to an external midi controller. The only difference is that without an arc, you won't get the ability to wrap around the tide shape index (8->1).

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
Note you'll only see sound parameters if you've loaded some sounds into the app (see "choose sample folder" in meta mode). And you'll only see crow parameters if you have a crow attached to the norns. Midi params can be toggled on or off in the global app parameters. In this way, the app tries to whittle down the buoy params displayed down to just the ones most useful for however you're currently using the app.

**sound** - the sample file you'll be working with, if any.

**looping** - whether or not the sound selection should play in a loop, or as a one-shot when activated by a tide crossing the play threshold.

**uninterruptible** - whether other buoys should be able to steal the voice from this one once it has begun playing (buoys is built on softcut, and softcut only has 6 simultaneous voices). Note that if a sound is both looping and uninterruptible, once initially activated it will play back indefinitely.

**octave/semitone/cent offset** - here you can control the pitch of the sample you are playing back. Higher pitches, higher playback rates.

**play threshold** - the tide depth which, when reached, will initiate playback of the sound. Note that if we've already reached the maximum number of concurrent softcut voices (6), this buoy will attempt to steal a voice from other buoys, oldest first excluding anything marked uninterruptible. If too many uninterruptible buoys are already playing, this buoy will not be able to play.

**reset threshold** - the tide depth which, when reached, will reset playback of the sound to it's start point.

**zenith/nadir volume, pan, filter cutoff, filter Q, rate, midi CC, midi velocity, crow voltage** - throughout, zenith and nadir refer to the high and low points of the tide. By default these are 14 and 0 respectively. By setting different parameter values for the zenith and nadir you make it such that the given parameter will be modulated by the tide depth. The value of the parameter need not be higher for the zenith than the nadir, it also works the other way around.

### Extended buoy parameters
If extended params are enabled in the main app parameters, you'll see some extras that will give you even more control.

**sound start point/end point** - set the start and end points of the sample (applies to both one-shots and loops).

**play/reset threshold hysteresis** - set how far below the threshold the tide must return before it triggers again. For instance if play threshold is 5 and play threshold hysteresis is 2, then after the tide reaches a depth of 5 and begins playing once, it must drop at least to a depth of 3 before reaching 5 will get it to play again.

**volume/pan/rate slew** - set the slew time for these values to adjust between tide "steps" (one unit of the tide advance time). By default they are set to auto, which will have them take exactly the length of the tide advance time to reach the new parameter levels. Not all parameters support slew at this time due to limitations in softcut, but hopefully in the near future those too can be slewed.

**volume/pan/cutoff/Q/rate zenith/nadir points** - adjust what is considered the high and low point of the tide as it pertains to modulation of the given parameter. For instance if pan nadir point is set to 6, pan zenith point is set to 10, and the nadir pan is set to 100L, and the zenith pan is set to 100R, then for any tide depth at or below 6, the pan setting will be at 100L, whereas at any tide depth at or above 10, the pan setting will be 100R. In between the parameter value will be linearly interpolated as usual, e.g. at a tide depth of 8 the pan setting will be centered.

## Meta mode
**Long-press K1** to get to meta mode. Each meta mode option is described below.

**choose sample folder** - this is how you load samples to be used by buoys. Navigate the file structure with E2 and K3 (K2 to back out). Once you've found the folder you'd like to load from, choose any sample in that folder and all samples from that folder will be loaded.

**clear inactive buoys** - when buoys are toggled inactive (i.e. not showing on the main screen) with a short grid press, we still save all their parameters so that they can be toggled back on without having to re-input all those parameters. However sometimes it may be useful to start from a clean slate, so this option will clear all buoys that aren't currently active.

**save preset** - save the current state of the app to one of 127 slots (255 on a 16x16 grid). On either size of grid, the 128th slot is for autosave. Select the slot by pressing the corresponding grid key. The preset name for the active selection will appear onscreen and the corresponding grid key will blink. While selecting a slot all grid keys where there is already save data will be at max brightness, whereas the rest of the grid keys will show the activity of the tides in the background at a dimmed brightness. When you select a slot that already has save data, you'll see a preview of the buoys and pilings in the screen's background, so you can see what you'll be overwriting if you confirm.

**load preset** - load up the app from one of up to 128/256 previous saves (including the autosave). The bottom-right grid key on an 8x16 grid (i.e. H16) corresponds to the autosave slot (for more on how the autosave works see the Tips and Tricks section below). Select the slot by pressing the corresponding grid key. The preset name for the active selection will appear onscreen and the corresponding grid key will blink. While selecting a slot all grid keys where there is already save data will be at max brightness, whereas the rest of the grid keys will show the ongoing activity of the tides in the background at a dimmed brightness. When you select a slot that already has save data, you'll see a preview of the buoys and pilings in the screen's background, so you can see what you'll be loading if you confirm.

## Crow and Midi
buoys integrates with both crow and midi inputs and outputs. For crow, buoys has several input types (see more details in the App Parameters section), for midi currently only clocks and transport messages (i.e. start/stop) are supported.

buoys has its own hand-rolled approach to clocking (for both crow and midi) which emphasizes getting the tide advancement to happen strictly on the beat. This works best when the external clock is constant; buoys is not especially good at handling clock rates that are changing over time, so if clock rate changes expect some short-term jumpiness in the appearance of the tide advancement.

In terms of outputs, buoys currently supports three output types for crow and three for midi. For crow, you can output either a variable voltage, a trigger, or a gate. The voltage corresponds to tide depth similar to modulation of the sound parameters, and can be unipolar or bipolar depending on the settings for the zenith/nadir voltages. The trigger/gate go high or low based on crossing a certain threshold for tide depth. For midi, you can output midi notes (note on/note off based on crossing a threshold), velocity, and CC messages.

## Tips and Tricks
The app autosaves what you've been working on once a minute. This autosave data lives in the bottom right slot of the grid when loading presets. When you load up the app for the first time or load a new preset, it won't autosave for at least a minute at first, to give you time to load the previous autosave if you want.

It is possible to edit multiple buoys at once. When you hold down multiple grid keys to reach the buoy editing view, whichever grid key was pressed first will be the one whose params are shown, but when a parameter is changed it will be changed for all the buoys whose keys are currently held.

It is possible to copy existing buoys to slots where no buoy currently exists (i.e. no buoy has ever been placed there, or they've been cleared out with the "clear inactive buoys" option in meta mode). First hold down the grid key of the buoy you'd like to copy. Then, while still holding down the key for the "prototype" buoy, press additional grid keys to place copies of the original buoy there.

## Notes / Errata
buoys is not intended to be a perfect physical simulation of tides moving in water, or even a very good one. It's just good enough to get a nice-enough looking approximation, and many corners have been cut. Even so, it's not impossible to overtax the norns processor by pushing it to extremes. Several safeguards have been put in place to make it harder to shoot yourself in the foot, but these aren't guaranteed to work 100% of the time so just bear that in mind. Generally speaking the more big tides are on the grid at any given time, the harder the physical simulation is having to work. By the same token the app may try to prevent you from doing things that it knows are going to overtax it, for instance setting too fast of a tide advance time with high clock multipliers (you'll get a warning and the clock multiplier will automatically downshift). You have been warned.
