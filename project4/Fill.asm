// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, the
// program clears the screen, i.e. writes "white" in every pixel.

(LOOP)
@KBD
D=M
@WHITE
D;JEQ
@BLACK
D;JNE
@LOOP
0;JMP

(WHITE)
@8192 //Number of words in screen
D=A
@R0
M=D //Set a counter

(WHITEFILL)
@SCREEN
D=A
@R0
A=D+M
M=0
@R0
M=M-1
D=M
@WHITEFILL
D;JGE
@LOOP
D;JLT

(BLACK)
@8192 //Number of words in screen
D=A
@R0
M=D //Set a counter
(BLACKFILL)
@SCREEN
D=A
@R0
A=D+M
M=-1
@R0
M=M-1
D=M
@BLACKFILL
D;JGE
@LOOP
D;JLT
