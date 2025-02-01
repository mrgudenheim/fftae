# [Click here for newest release](https://github.com/mrgudenheim/FFTae/releases)

# About
This tool streamlines creating xml patches for FFT that edit animations.

# Features
- Change opcodes and parameters
- Insert and delete opcodes
- Add or delete animations
- Add, delete, or edit animation pointers
- Create SEQ file or xml patch
- Preview animation and SHP frames
- SEQ and SHP will be auto selected when selecting an SPR. SHP will be auto selected when selecting SEQ
- Partial Experimental support for opcodes from Animation Rewrite ASM

# Limitations and Notes
- Having two Move opcodes in a row (ex. MoveForward2() followed by MoveForward2()) may cause weird issues when ran in game
- Recommend against deleting vanilla animations. Deleting an animation will cause any pointer that points past the end to instead point to the first animation
- Pointers above the max limit will not be saved in seq or xml
- Frames are dependent on the following settings:
	MON.SHP uses Sp2 files based on animation index, so the frames retrieved may change depending on which animation is selected.
	WEP.SHP offsets the selection vertically based on weapon id
	OTHER.SHP offsets the selection vertically based on the "other type"
- Since the Animation Rewrite ASM changes the ffc2 opcode to have 1 parameter instead of 0, there may be issues unless all vanilla ffc2 opcodes are changed to something else.

# Future Improvements
- Improve UI
- Allow editing SHPs
- Support "animation rewrite" ASM hack

# Building From Source
This project is built with Godot 4.3 
https://godotengine.org/
