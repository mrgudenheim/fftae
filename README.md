# [Click here for newest release](https://github.com/mrgudenheim/FFTae/releases)

# About
This tool streamlines creating xml patches for FFT that edit animations.

# Features
- Change opcodes and parameters
- Insert and delete opcodes
- Add or delete animations
- Add, delete, or edit animation pointers
- Create SEQ or xml patch

# Limitations and Notes
- Having two Move opcodes in a row (ex. MoveForward2() followed by MoveForward2()) may cause weird issues
- Pointers above the max limit will not be saved in seq or xml

# Future Improvements
- Improve UI
- Preview animations
- Allow editing SHPs

# Building From Source
This project is built with Godot 4.3 
https://godotengine.org/
