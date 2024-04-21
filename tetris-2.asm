################ CSC258H1F Winter 2024 Assembly Final Project ##################
# This file contains our implementation of Tetris.
#
# Student 1: Ashenafee Mandefro, 1007071151
# Student 2: Name, Student Number (if applicable)
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       8
# - Unit height in pixels:      8
# - Display width in pixels:    512
# - Display height in pixels:   256
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

.data

##############################################################################
# Immutable Data
##############################################################################

# ----------------------------------------------------------------------------
# Bitmap Configuration
# ----------------------------------------------------------------------------

bitmapWidth:
    .word 0x180

bitmapHeight:
    .word 0x100

bitmapPixelWidth:
    .word 0x30

bitmapPixelHeight:
    .word 0x20

unitWidth:
    .word 0x8

unitHeight:
    .word 0x8

# ----------------------------------------------------------------------------
# Interface Addresses
# ----------------------------------------------------------------------------

# The address of the bitmap display.
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard.
ADDR_KBRD:
    .word 0xffff0000

# ----------------------------------------------------------------------------
# Pixel Colours
# ----------------------------------------------------------------------------

# Arena Colours
backgroundColour1:
    .word 0x212121
backgroundColour2:
    .word 0x2F2F2F
borderColour:
    .word 0x1C1C1C

# Score Box Colours
backgroundColour3:
    .word 0x303030

backgroundPixel:
    .word 0x000000
whitePixel:
    .word 0xFFFFFF
redPixel:
    .word 0xFF0000
greenPixel:
    .word 0x00FF00
bluePixel:
    .word 0x0000FF

##############################################################################
# Mutable Data
##############################################################################

# ----------------------------------------------------------------------------
# Shapes
# ----------------------------------------------------------------------------
currentBlockOrientation:
    .word 0
currentBlockX:
    .word 0
currentBlockY:
    .word 0

# ----------------------------------------------------------------------------
# Tetromino Segments
# ----------------------------------------------------------------------------
    
    # Each label below corresponds to the location of either the X or Y value of a
    # given tetromino segment. There are eight labels total; four X and four Y.
# Each of the four segments has one of these X and Y labels associated with
# them.

# TODO: Refactor this to

# Notes: Gravity
#   - Screen will update itself 60 times per second.
#   - Sleep for 1/60 seconds.
#   - Everytime it wakes, it checks if someone's pressed a key.
#   - If someone's pressed a key, it would update the screen.
#   - After 60 sleep intervals, 1 second has gone by so the piece will go down automatically.

currentBlockSegments:
    .space 8

currentBlockS1X:
    .word 0
currentBlockS1Y:
    .word 0
currentBlockS2X:
    .word 0
currentBlockS2Y:
    .word 0
currentBlockS3X:
    .word 0
currentBlockS3Y:
    .word 0
currentBlockS4X:
    .word 0
currentBlockS4Y:
    .word 0

# ----------------------------------------------------------------------------
# Arena Stack
# ----------------------------------------------------------------------------

# The space below is used to store the state of the arena. It acts as a copy
# of the bitmap display, where each space in memory holds a word representing
# the colour used at the corresponding location in the bitmap.
#
# For example, the first word in arenaSnapshot will hold the colour used at
# the top left pixel of the bitmap display.

.align 2
arenaSnapshot:
    .space 6144

# ----------------------------------------------------------------------------
# Extras
# ----------------------------------------------------------------------------

# The space below is for extra features like a game score, level, etc.

gameScore:
    .word 0
    
gravityCounter:
    .word 0
    
gamePauseState:
    .word 0

themeSequence:
    .word 64, 59, 60, 62, 64, 62, 60, 59, 57, 57, 60, 64, 62, 60, 59, 
          60, 60, 62, 64, 60, 57, 57, 59, 60, 62, 64, 62, 60, 59, 
          64, 64, 67, 64, 62, 60, 59, 57, 55, 55, 55, 57, 59, 
          60, 59, 57, 59, 62, 64, 62, 59, 60, 62, 64, 62, 60, 59, 57
themeLength:
    .word 64
themePosition:
    .word 0


##############################################################################
# Code
##############################################################################
.text
	.globl main

	# Run the Tetris game.
main:
    # Initialize the game
    
    # Load the address of the bitmap display to s0
    lw $s0, ADDR_DSPL
    # Load the address of the keyboard input to s1
    lw $s1, ADDR_KBRD
    # Load the address of the arena snapshot to s2
    la $s2, arenaSnapshot
    
    INIT_GAME:
        # Set the score to 0
        sw $zero, gameScore

        # Set the current block orientation to 0
        sw $zero, currentBlockOrientation

        # Paint the bitmap black
        addi $sp, $sp, -12
        lw $t1, backgroundPixel
        sw $t1, 0($sp)
        sw $t1, 4($sp)
        
        # Paint over the whole screen
        add $a0, $zero, $zero
        li $a1, 48
        add $a2, $zero, $zero
        li $a3, 32
        jal PAINT
    
        # Load the color red for painting
        lw $t1, redPixel
        sw $t1, 0($sp)
        sw $t1, 4($sp)

        # Paint the arena
        jal PAINT_ARENA
        
        # Paint the score box
        jal PAINT_SCORE_BOX
        
        # Paint the initial score
        addi $a0, $zero, 32
        addi $a1, $zero, 5
        lw $a2, redPixel
        jal PAINT_NUMBER
        
        # Paint the preview box
        jal PAINT_PREVIEW_BOX

        # Store the initial state of the game
        jal STORE_ARENA_STATE
        
        # Paint an "I" block in orientation A at (10, 5) in red
        addi $a0, $zero, 10
        addi $a1, $zero, 0
        lw $a2, redPixel
        jal PAINT_IA
    
    INPUT_LOOP:
        # Get the first word from the keyboard
        lw $t4, 0($s1)
        beq $t4, 1, KBRD_INPUT
        
        # Load the gravity counter
        lw $a3, gravityCounter
        
        CALL_GRAVITY:
            beq $a3, 10, BASIC_GRAVITY
            
            # Increment gravityCounter
            addi $a3, $a3, 1
            sw $a3, gravityCounter
            
            # Call delay
            li $v0, 32
            li $a0, 100
            syscall
            
            # Get if even or odd gravityCounter
            li $t6, 3
            divu $t6, $a3, $t6
            mfhi $t6
            beq $t6, $zero START_THEME
            bne $t6, $zero ALLOW_MOVE
            
            START_THEME:
                jal PLAY_THEME_SONG
            ALLOW_MOVE:
            # jal PLAY_THEME_SONG
                j INPUT_LOOP
            
            j CALL_GRAVITY
        CALL_GRAVITY_END:
            # j INPUT_LOOP
    
    INPUT_PAUSED:
        # Get the first word from the keyboard
        lw $t4, 0($s1)
        beq $t4, 1, CHECK_FUNCTION_KEY
        
        j INPUT_PAUSED
        
        # Check if the "P" key was pressed (pause)
        CHECK_FUNCTION_KEY:
            # Load second word from keyboard
            lw $t4, 4($s1)
            
            # Check if the "Q" key was pressed (quit)
            beq $t4, 0x71, Q_RESPONSE
        
            # Check if the "R" key was pressed (reset)
            beq $t4, 0x72, R_RESPONSE
            
            # Check if "P" was pressed (pause)
            beq $t4, 0x70, PAUSE_RESPONSE
            
            j INPUT_PAUSED
        
        PAUSE_RESPONSE:
            # Load in the pause state
            lw $t1, gamePauseState
            
            beq $t1, 0, P0_RESPONSE
            beq $t1, 0xffffffff, P1_RESPONSE

# Subroutine - BASIC_GRAVITY
# Moves the current block down by one unit.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
BASIC_GRAVITY:
    # # Store the original return address in the stack
    # addi $sp, $sp, -4
    # sw $ra, 0($sp)

    # Load and reset the gravityCounter
    lw $t8, gravityCounter
    add $t8, $zero, $zero
    sw $t8, gravityCounter

    jal DOWN_RESPONSE
    
    j INPUT_LOOP

    # # Restore the original return address from the stack
    # lw $ra, 0($sp)
    # addi $sp, $sp, 4
    # jr $ra

# Subroutine - KBRD_INPUT
# Handles the response to different keyboard inputs.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
KBRD_INPUT:
    # Load second word from keyboard
    lw $a0, 4($s1)
    
    # Check if the "Q" key was pressed (quit)
    beq $a0, 0x71, Q_RESPONSE

    # Check if the "R" key was pressed (reset)
    beq $a0, 0x72, R_RESPONSE
    
    # Check if the "P" key was pressed (pause)
    beq $a0, 0x70, P0_RESPONSE
    
    # Check if the "W" key was pressed
    beq $a0, 0x77, W_RESPONSE
    
    # Check if the "A" key was pressed
    beq $a0, 0x61, LEFT_RESPONSE
    
    # Check if the "S" key was pressed
    beq $a0, 0x73, DOWN_RESPONSE
    
    # # Check if the "D" key was pressed
    beq $a0, 0x64, RIGHT_RESPONSE
    
    j INPUT_LOOP

# -------
# Sounds
# -------

# Subroutine - PLAY_THEME_SONG
# Plays a basic version of the Korobeiniki theme song
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PLAY_THEME_SONG:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load the current index of the theme from memory
    lw $t0, themePosition

    # Check if we reached the end of the theme
    lw $t1, themeLength
    bge $t0, $t1, END_THEME  # If yes, jump to end or loop
    
    # Calculate the address of the current pitch in the sequence
    sll $t2, $t0, 2          # Index * 4 because each .word is 4 bytes
    la $t3, themeSequence   # Load the address (base) of the themeSequence into $t3
    add $t3, $t3, $t2       # Add offset to base address to get the correct pitch address
    
    # Load the pitch associated with the index
    lw $a0, 0($t3)          # Load the word at the calculated address into $a0
    
    # Make a syscall to generate a sound
    li $v0, 31
    li $a1, 10
    li $a2, 10
    li $a3, 50
    syscall
    
    # Increment the current theme position
    addi $t0, $t0, 1
    sw $t0, themePosition
    
    # Restore the original return address from the stack and return
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

END_THEME:
    # Reset themePosition if you want to loop or handle end of theme
    li $t0, 0
    sw $t0, themePosition
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra


# Subroutine - PLAY_VALID_MOVE_SOUND
# Plays a sound to indicate a valid move.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PLAY_VALID_MOVE_SOUND:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Make a syscall to generate a sound
    li $v0, 33
    li $a0, 90
    li $a1, 10
    li $a2, 73
    li $a3, 50
    syscall
    
    # Restore the original return address from the stack
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Subroutine - PLAY_INVALID_MOVE_SOUND
# Plays a sound to indicate an invalid move.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PLAY_INVALID_MOVE_SOUND:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Make a syscall to generate a sound
    li $v0, 33
    li $a0, 60
    li $a1, 10
    li $a2, 73
    li $a3, 50
    syscall
    
    # Restore the original return address from the stack
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Subroutine - PLAY_CLEAR_ROW_SOUND
# Plays a sound to indicate a row has been cleared.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PLAY_CLEAR_ROW_SOUND:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Make a syscall to generate a sound
    # Initialize $a0 with the starting tone
    li $a0, 25

    # Label for the start of the loop
    CLEAR_ROW_SOUND_LOOP:
        beq $a0, 100, CLEAR_ROW_SOUND_LOOP_END

        # Set the system call number for playing a tone
        li $v0, 33

        # Set the other arguments for the system call
        li $a1, 10
        li $a2, 80
        li $a3, 100

        # Make the system call
        syscall

        # Increment the tone
        addi $a0, $a0, 5
        j CLEAR_ROW_SOUND_LOOP
    CLEAR_ROW_SOUND_LOOP_END:
    
    # Restore the original return address from the stack
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

Q_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Paint a game over message
    jal PAINT_GAME_OVER
    
    # Jump back to the input loop
    j INPUT_PAUSED

R_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Re-initialize the game
    j INIT_GAME

P0_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load and toggle the game pause state
    lw $t0, gamePauseState
    nor $t0, $t0, $t0
    sw $t0, gamePauseState
    
    # Load the white for painting the pause symbol
    lw $t0, whitePixel
    sw $t0, 4($sp)
    sw $t0, 0($sp)
    
    # Paint the pause screen
    li $a0, 35
    li $a1, 2
    li $a2, 21
    li $a3, 8
    jal PAINT
    
    li $a0, 39
    li $a1, 2
    li $a2, 21
    li $a3, 8
    jal PAINT
    
    # Pause the input
    j INPUT_PAUSED
    
P1_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load and toggle the game pause state
    lw $t0, gamePauseState
    nor $t0, $t0, $t0
    sw $t0, gamePauseState
    
    # # Load the white for painting the pause symbol
    # lw $t0, backgroundColour3
    # sw $t0, 4($sp)
    # sw $t0, 0($sp)
    
    # # Paint the pause screen
    # li $a0, 30
    # li $a1, 2
    # li $a2, 20
    # li $a3, 8
    # jal PAINT
    
    # Unpause the input
    j INPUT_LOOP

W_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load the address of memory storing the location of each segment
    la $t9, currentBlockSegments

    # Load the current orientation
    lw $t4, currentBlockOrientation

    # Initialize a counter
    add $t8, $zero, $zero
    
    # Get X location of current segment (currentBlockSegments[0])
    lw $t0, 0($t9)

    # Get Y location of current segment (currentBlockSegments[1])
    lw $t1, 4($t9)

    # Calculate the Y offset
    lw $t2, bitmapPixelWidth
    mult $t2, $t2, $t1
    mult $t2, $t2, 4

    # Calculate and add in the X offset
    mult $t3, $t0, 4
    add $t2, $t2, $t3

    # If the orientation is 0 the next one is 1 ("|" -> "-")
    # In this case, check the 3 segments to the right of the current segment
    li $t0, 0
    CHECK_COLOUR_ROTATE_0:
        beq $t0, 3, CHECK_COLOUR_ROTATE_0_END

        # Calculate the X offset
        addi $t2, $t2, 4

        # Load the previous state
        la $t3, arenaSnapshot
        add $t3, $t3, $t2
        lw $t3, 0($t3)

        # Check if it is the same colour as redPixel
        lw $t5, redPixel
        beq $t5, $t3, SKIP_MOVE
        # Check if the colour is the same as the border colour
        lw $t5, borderColour
        beq $t5, $t3, SKIP_MOVE

        # Check the next segment
        addi $t0, $t0, 1
        j CHECK_COLOUR_ROTATE_0
    CHECK_COLOUR_ROTATE_0_END:
    
    # Reload the previously saved arena state
    jal LOAD_ARENA_STATE
    
    # Increment currentBlockOrientation
    lw $t0, currentBlockOrientation
    addi $t0, $t0, 1
    
    # Check if the value is greater than 3
    li $t1, 4
    bge $t0, $t1, RESET_ORIENTATION  # If $t0 >= 4, reset to 0
    
    # Otherwise, store the incremented value and skip the reset
    j CONTINUE

    RESET_ORIENTATION:
        # Reset the orientation to 0
        li $t0, 0
    
    CONTINUE:
        # Store the value back to currentBlockOrientation
        sw $t0, currentBlockOrientation

    # Get the current X and Y coordinates of the block
    lw $a0, currentBlockX
    lw $a1, currentBlockY
    
    # Repaint the block based on the orientation
    li $t1, 0
    beq $t0, $t1, ROT_I_ORI1
    li $t1, 1
    beq $t0, $t1, ROT_I_ORI2
    li $t1, 2
    beq $t0, $t1, ROT_I_ORI1
    li $t1, 3
    beq $t0, $t1, ROT_I_ORI2
    
    # Branches
    ROT_I_ORI1:
        # Repaint the rotated block
        lw $a2, redPixel
        jal PAINT_IA
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND
        j INPUT_LOOP
    
    ROT_I_ORI2:
        # Repaint the rotated block
        lw $a2, redPixel
        jal PAINT_IB
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND
        j INPUT_LOOP
    
    j INPUT_LOOP

LEFT_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load the current X position and check if moving left is possible
    lw $t0, currentBlockS1X
    addi $t0, $t0, -1  # Calculate new X position if moved left

    # Check against left boundary (0)
    blt $t0, 1, SKIP_MOVE

        # Load the address of memory storing the location of each segment
    la $t9, currentBlockSegments

    # Initialize a counter
    add $t8, $zero, $zero

    CHECK_COLOUR_LEFT:
        bge $t8, 4, CHECK_COLOUR_LEFT_END
    
        # Get X location of current segment (currentBlockSegments[0])
        lw $t0, 0($t9)

        # Get Y location of current segment (currentBlockSegments[1])
        lw $t1, 4($t9)

        # Hypothetical next X location
        addi $t0, $t0, -1

        # Calculate the Y offset
        lw $t2, bitmapPixelWidth
        mult $t2, $t2, $t1
        mult $t2, $t2, 4

        # Calculate and add in the X offset
        mult $t3, $t0, 4
        add $t2, $t2, $t3

        # Load the previous state
        la $t3, arenaSnapshot
        add $t3, $t3, $t2
        lw $t3, 0($t3)

        # Check if it is the same colour as redPixel
        lw $t0, redPixel
        beq $t0, $t3, SKIP_MOVE
        # Check if the colour is the same as the border colour
        lw $t0, borderColour
        beq $t0, $t3, SKIP_MOVE

        # Increment the counter
        addi $t8, $t8, 1

        # Check the next segment
        addi $t9, $t9, 8
        j CHECK_COLOUR_LEFT
    CHECK_COLOUR_LEFT_END:
    
    # Reload the previously saved arena state
    jal LOAD_ARENA_STATE
    
    # Load the current orientation
    lw $t2, currentBlockOrientation
    
    # Shift the X position of the block 1 to the left (-1)
    lw $t0, currentBlockX
    lw $t1, currentBlockY
    addi $t0, $t0, -1
    
    # Shift the current orientation of the block 1 unit to the left (-1)
    li $t3, 0
    beq $t2, $t3, MOVE_I_ORI1_L
    li $t3, 1
    beq $t2, $t3, MOVE_I_ORI2_L
    li $t3, 2
    beq $t2, $t3, MOVE_I_ORI1_L
    li $t3, 3
    beq $t2, $t3, MOVE_I_ORI2_L
    
    # Branches
    MOVE_I_ORI1_L:
        # Repaint the block at the new position
        add $a0, $zero, $t0
        add $a1, $zero, $t1
        lw $a2, redPixel
        jal PAINT_IA
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND
        j INPUT_LOOP
    
    MOVE_I_ORI2_L:
        # Repaint the block at the new position
        add $a0, $zero, $t0
        add $a1, $zero, $t1
        lw $a2, redPixel
        jal PAINT_IB
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND
        j INPUT_LOOP

    j INPUT_LOOP

DOWN_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load the current Y position and check if moving down is possible
    lw $t0, currentBlockS4Y
    addi $t0, $t0, 1  # Calculate new Y position if moved down

    # Check against bottom boundary (31)
    bgt $t0, 30, SPAWN_BLOCK
    
    # Load the address of memory storing the location of each segment
    la $t9, currentBlockSegments

    # Initialize a counter
    add $t8, $zero, $zero

    CHECK_COLOUR_DOWN:
        bge $t8, 4, CHECK_COLOUR_DOWN_END

        # Get X location of current segment (currentBlockSegments[0])
        lw $t0, 0($t9)

        # Get Y location of current segment (currentBlockSegments[1])
        lw $t1, 4($t9)
        
        # Hypothetical next Y location
        addi $t1, $t1, 1

        # Calculate the Y offset
        lw $t2, bitmapPixelWidth
        mult $t2, $t2, $t1
        mult $t2, $t2, 4

        # Calculate and add in the X offset
        mult $t3, $t0, 4
        add $t2, $t2, $t3

        # Load the previous state
        la $t3, arenaSnapshot
        add $t3, $t3, $t2
        lw $t3, 0($t3)

        # Check if it is the same colour as redPixel
        lw $t0, redPixel
        beq $t0, $t3, SPAWN_BLOCK
        # Check if the colour is the same as the border colour
        lw $t0, borderColour
        beq $t0, $t3, SPAWN_BLOCK

        # Increment the counter
        addi $t8, $t8, 1

        # Check the next segment
        addi $t9, $t9, 8
        j CHECK_COLOUR_DOWN
    CHECK_COLOUR_DOWN_END:
    
    # Reload the previously saved arena state
    jal LOAD_ARENA_STATE
    
    # Load the current orientation
    lw $t2, currentBlockOrientation
    
    # Shift the Y position of the block 1 down (+1)
    lw $t0, currentBlockX
    lw $t1, currentBlockY
    addi $t1, $t1, 1
    
    # Branch on the type of block to repaint based on the orientation
    li $t3, 0
    beq $t2, $t3, MOVE_I_ORI1_D
    li $t3, 1
    beq $t2, $t3, MOVE_I_ORI2_D
    li $t3, 2
    beq $t2, $t3, MOVE_I_ORI1_D
    li $t3, 3
    beq $t2, $t3, MOVE_I_ORI2_D
    
    # Branches
    MOVE_I_ORI1_D:
        # Repaint the block at the new position
        add $a0, $zero, $t0
        add $a1, $zero, $t1
        lw $a2, redPixel
        jal PAINT_IA
        
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND

        # Check if the whole row is filled
        jal CHECK_ROW_FILLED

        # Check if any of the segments are at the top
        # Load the address of memory storing the location of each segment
        la $t9, currentBlockSegments

        # Loop counter
        # add $t8, $zero, $zero
        # CHECK_MAX_STACK_IA:
            # bge $t8, 4, CHECK_MAX_STACK_IA_END

            # # Get the Y location of the current segment
            # lw $t1, 4($t9)

            # # Check if the segment is at the top
            # li $t0, 0
            # beq $t1, $t0, PAINT_GAME_OVER

            # # Increment the counter
            # addi $t8, $t8, 1

            # # Check the next segment
            # addi $t9, $t9, 8
            # j CHECK_MAX_STACK_IA
        # CHECK_MAX_STACK_IA_END:

        j INPUT_LOOP
    
    MOVE_I_ORI2_D:
        # Repaint the block at the new position
        add $a0, $zero, $t0
        add $a1, $zero, $t1
        lw $a2, redPixel
        jal PAINT_IB
        
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND

        # Check if the whole row is filled
        jal CHECK_ROW_FILLED

        # Check if any of the segments are at the top
        # Load the address of memory storing the location of each segment
        la $t9, currentBlockSegments

        # Check if the Y segment is at the top (all have the same Y)
        lw $t1, 4($t9)

        beq $t1, 0, PAINT_GAME_OVER

        j INPUT_LOOP
    
    j INPUT_LOOP


RIGHT_RESPONSE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load the current X position and check if moving right is possible
    lw $t0, currentBlockS4X
    addi $t0, $t0, 1  # Calculate new X position if moved right

    # Check against right boundary (26)
    bgt $t0, 26, SKIP_MOVE

    # Load the address of memory storing the location of each segment
    la $t9, currentBlockSegments

    # Initialize a counter
    add $t8, $zero, $zero

    CHECK_COLOUR_RIGHT:
        bge $t8, 4, CHECK_COLOUR_RIGHT_END
    
        # Get X location of current segment (currentBlockSegments[0])
        lw $t0, 0($t9)

        # Get Y location of current segment (currentBlockSegments[1])
        lw $t1, 4($t9)

        # Hypothetical next X location
        addi $t0, $t0, 1

        # Calculate the Y offset
        lw $t2, bitmapPixelWidth
        mult $t2, $t2, $t1
        mult $t2, $t2, 4

        # Calculate and add in the X offset
        mult $t3, $t0, 4
        add $t2, $t2, $t3

        # Load the previous state
        la $t3, arenaSnapshot
        add $t3, $t3, $t2
        lw $t3, 0($t3)

        # Check if it is the same colour as redPixel
        lw $t0, redPixel
        beq $t0, $t3, SKIP_MOVE
        # Check if the colour is the same as the border colour
        lw $t0, borderColour
        beq $t0, $t3, SKIP_MOVE

        # Increment the counter
        addi $t8, $t8, 1

        # Check the next segment
        addi $t9, $t9, 8
        j CHECK_COLOUR_RIGHT
    CHECK_COLOUR_RIGHT_END:
    
    # Reload the previously saved arena state
    jal LOAD_ARENA_STATE
    
    # Load the current orientation
    lw $t2, currentBlockOrientation
    
    # Shift the X position of the block 1 to the left (-1)
    lw $t0, currentBlockX
    lw $t1, currentBlockY
    addi $t0, $t0, 1
    
    # Shift the current orientation of the block 1 unit to the left (-1)
    li $t3, 0
    beq $t2, $t3, MOVE_I_ORI1_R
    li $t3, 1
    beq $t2, $t3, MOVE_I_ORI2_R
    li $t3, 2
    beq $t2, $t3, MOVE_I_ORI1_R
    li $t3, 3
    beq $t2, $t3, MOVE_I_ORI2_R
    
    # Branches
    MOVE_I_ORI1_R:
        # Repaint the block at the new position
        add $a0, $zero, $t0
        add $a1, $zero, $t1
        lw $a2, redPixel
        jal PAINT_IA
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND
        j INPUT_LOOP
    
    MOVE_I_ORI2_R:
        # Repaint the block at the new position
        add $a0, $zero, $t0
        add $a1, $zero, $t1
        lw $a2, redPixel
        jal PAINT_IB
        # Play a sound to indicate a valid move
        jal PLAY_VALID_MOVE_SOUND
        j INPUT_LOOP

    # Repaint the block at the new position
    add $a0, $zero, $t0
    add $a1, $zero, $t1
    lw $a2, redPixel
    jal PAINT_IA
    
    j INPUT_LOOP
    
SKIP_MOVE:
    # Restore the original return address and return to the input loop
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    # Play a sound to indicate an invalid move
    jal PLAY_INVALID_MOVE_SOUND
    j INPUT_LOOP

SPAWN_BLOCK:
    la $t9, currentBlockSegments

    # Loop counter
    add $t8, $zero, $zero
    CHECK_MAX_STACK_IA:
        bge $t8, 4, CHECK_MAX_STACK_IA_END

        # Get the Y location of the current segment
        lw $t1, 4($t9)

        # Check if the segment is at the top
        li $t0, 0
        beq $t1, $t0, PAINT_GAME_OVER

        # Increment the counter
        addi $t8, $t8, 1

        # Check the next segment
        addi $t9, $t9, 8
        j CHECK_MAX_STACK_IA
    CHECK_MAX_STACK_IA_END:

    # Store the previous block in arenaSnapshot
    la $t0, arenaSnapshot
    jal STORE_ARENA_STATE

    # Reset the orientation of the current shape
    lw $t0 currentBlockOrientation
    add $t0, $zero, $zero
    sw $t0, currentBlockOrientation

    addi $a0, $zero, 10
    addi $a1, $zero, 0
    lw $a2, redPixel
    jal PAINT_IA
    j INPUT_LOOP

CHECK_ROW_FILLED:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load the snapshot
    la $t9, arenaSnapshot

    # Offset to 69 bytes before the end of the snapshot
    addi $t9, $t9, 5764

    # Initialize a counter
    add $t8, $zero, $zero

    CHECK_ROW_FILLED_LOOP:
        bge $t8, 26, CHECK_ROW_FILLED_END

        # Load the current pixel colour
        lw $t0, 0($t9)

        # Check if the pixel is red
        lw $t1, redPixel
        bne $t0, $t1, CHECK_ROW_FILLED_END

        # Increment the counter
        addi $t8, $t8, 1

        # Move to the next pixel
        addi $t9, $t9, 4
        j CHECK_ROW_FILLED_LOOP


CHECK_ROW_FILLED_END:
    # Check if the loop counter is 26
    beq $t8, 26, SHIFT_ROWS_DOWN

    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

    SHIFT_ROWS_DOWN:
        # Play a sound to indicate a row has been cleared
        jal PLAY_CLEAR_ROW_SOUND

        # Load the snapshot
        la $t9, arenaSnapshot
        la $t6, arenaSnapshot

        # Load a reference to the bitmap
        lw $t8, ADDR_DSPL
        lw $t4, ADDR_DSPL

        # Initialize a counter
        add $t7, $zero, $zero
        
        SHIFT_ROWS_DOWN_LOOP:
            bge $t7, 1440, SHIFT_ROWS_DOWN_END

            # Increment the counter
            addi $t7, $t7, 1

            # Load the current pixel colour
            lw $t0, 0($t9)

            # Increment the pointer to the next pixel
            addi $t9, $t9, 4

            # Check if pixel is NOT border colour
            lw $t1, borderColour
            beq $t0, $t1, SHIFT_ROWS_DOWN_LOOP
            # Check if pixel is NOT black
            lw $t1, backgroundPixel
            beq $t0, $t1, SHIFT_ROWS_DOWN_LOOP
            # Check if pixel is NOT status background
            lw $t1, backgroundColour3
            beq $t0, $t1, SHIFT_ROWS_DOWN_LOOP
            
            # Get offset from start of snapshot to shift pixel down 1 row
            sub $t5, $t9, $t6
            add $t3, $t4, $t5
            addi $t3, $t3, 188

            # If the current pixel is backgroundColour1, paint it with backgroundColour2
            lw $t1, backgroundColour1
            beq $t0, $t1, PAINT_BACKGROUND2

            # If the current pixel is backgroundColour2, paint it with backgroundColour1
            lw $t1, backgroundColour2
            beq $t0, $t1, PAINT_BACKGROUND1

            # Otherwise, paint the pixel with the current colour
            sw $t0, 0($t3)
            j SHIFT_ROWS_DOWN_LOOP

            PAINT_BACKGROUND1:
                lw $t0, backgroundColour1
                j PAINT_SHIFTED_PIXEL
            
            PAINT_BACKGROUND2:
                lw $t0, backgroundColour2
                j PAINT_SHIFTED_PIXEL

            PAINT_SHIFTED_PIXEL:
                sw $t0, 0($t3)

            j SHIFT_ROWS_DOWN_LOOP
    SHIFT_ROWS_DOWN_END:

    # Update the score
    lw $t0, gameScore
    addi $t0, $t0, 1
    sw $t0, gameScore

    # Repaint the score box
    add $a0, $zero, $t0
    jal PAINT_NUMBER

    # Spawn a new block
    j SPAWN_BLOCK

    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - STORE_ARENA_STATE
# Stores the state of the arena, including settled blocks.
#
# Arguments
#   - None
# Stack Arguments
#   - None
STORE_ARENA_STATE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Get a reference to where the state is stored
    la $t0, arenaSnapshot
    
    # Get a reference to the base address of the bitmap
    lw $t1, ADDR_DSPL
    
    # Initialize the loop counter
    add $t2, $zero, $zero
    
    # Calculate the upper bound of the loop
    add $t3, $zero, $zero
    lw $t9, bitmapPixelWidth
    lw $t8, bitmapPixelHeight
    mult $t3, $t9, $t8
    SAVE_PIXEL:
        # Break to the end of this subroutine if the entire state has been saved
        beq $t2, $t3, STORE_ARENA_STATE_END
        
        # Fetch the current pixel colour from the screen
        lw $t4, 0($t1)
        
        # Save the pixel colour to the snapshot
        sw $t4, 0($t0)
        
        # Increment the pointers for the snapshot and the bitmap display
        addi $t0, $t0, 4
        addi $t1, $t1, 4
    
        # Increment the loop counter
        addi $t2, $t2, 1
        
        j SAVE_PIXEL

STORE_ARENA_STATE_END:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - LOAD_ARENA_STATE
# Loads the most recently saved arena state from memory.
#
# Arguments
#   - None
# Stack Arguments
#   - None
LOAD_ARENA_STATE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Get a reference to where the state is stored
    add $t0, $zero, $s2
    
    # Get a reference to the base address of the bitmap
    lw $t1, ADDR_DSPL
    
    # Initialize the loop counter
    add $t2, $zero, $zero
    
    # Calculate the upper bound of the loop
    add $t3, $zero, $zero
    lw $t9, bitmapPixelWidth
    lw $t8, bitmapPixelHeight
    mult $t3, $t9, $t8
    LOAD_PIXEL:
        # Break to the end of this subroutine if the entire state has been saved
        beq $t2, $t3, LOAD_ARENA_STATE_END
        
        # Fetch the current pixel colour
        lw $t4, 0($t0)
        
        # Paint the pixel colour on the bitmap
        sw $t4, 0($t1)
        
        # Increment the pointers for the bitmap display and the snapshot
        addi $t0, $t0, 4
        addi $t1, $t1, 4
    
        # Increment the loop counter
        addi $t2, $t2, 1
        
        j LOAD_PIXEL

LOAD_ARENA_STATE_END:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - PAINT_ARENA
# Paints the tetris arena.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PAINT_ARENA:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    PAINT_ARENA_BACKGROUND:
        addi $sp, $sp, -12
        add $a0, $zero, $zero
        addi $a0, $a0, 1
        add $a1, $zero, $zero
        addi $a1, $a1, 26
        add $a2, $zero, $zero
        addi $a2, $a2, 0
        add $a3, $zero, $zero
        addi, $a3, $a3, 31
        
        # Load the colours for painting the background
        lw $t0, backgroundColour1
        sw $t0, 4($sp)
        lw $t1, backgroundColour2
        sw $t1, 0($sp)
        
        # Call the PAINT subroutine to create the checkered background
        jal PAINT
        
        # Restore the stack pointer
        addi $sp, $sp, 12
    
    PAINT_ARENA_BOUNDS:
        PAINT_ARENA_LEFT:
            addi $sp, $sp, -12
            add $a0, $zero, $zero
            addi $a0, $a0, 0
            add $a1, $zero, $zero
            addi $a1, $a1, 1
            add $a2, $zero, $zero
            addi $a2, $a2, 0
            add $a3, $zero, $zero
            addi, $a3, $a3, 31
            
            # Load the colours for painting the background
            lw $t0, borderColour
            sw $t0, 4($sp)
            lw $t1, borderColour
            sw $t1, 0($sp)
            
            # Call the PAINT subroutine to create the checkered background
            jal PAINT
            
            # Restore the stack pointer
            addi $sp, $sp, 12
        
        PAINT_ARENA_BOTTOM:
            addi $sp, $sp, -12
            add $a0, $zero, $zero
            addi $a0, $a0, 0
            add $a1, $zero, $zero
            addi $a1, $a1, 28
            add $a2, $zero, $zero
            addi $a2, $a2, 31
            add $a3, $zero, $zero
            addi, $a3, $a3, 1
            
            # Load the colours for painting the background
            lw $t0, borderColour
            sw $t0, 4($sp)
            lw $t1, borderColour
            sw $t1, 0($sp)
            
            # Call the PAINT subroutine to create the checkered background
            jal PAINT
            
            # Restore the stack pointer
            addi $sp, $sp, 12
        
        PAINT_ARENA_RIGHT:
            addi $sp, $sp, -12
            add $a0, $zero, $zero
            addi $a0, $a0, 27
            add $a1, $zero, $zero
            addi $a1, $a1, 1
            add $a2, $zero, $zero
            addi $a2, $a2, 0
            add $a3, $zero, $zero
            addi, $a3, $a3, 31
            
            # Load the colours for painting the background
            lw $t0, borderColour
            sw $t0, 4($sp)
            lw $t1, borderColour
            sw $t1, 0($sp)
            
            # Call the PAINT subroutine to create the checkered background
            jal PAINT
            
            # Restore the stack pointer
            addi $sp, $sp, 12

PAINT_ARENA_DONE:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - PAINT_SCORE_BOX
# Paints the score box.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PAINT_SCORE_BOX:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    PAINT_SCORE_BOX_BACKGROUND:
        addi $sp, $sp, -12
        add $a0, $zero, $zero
        addi $a0, $a0, 30
        add $a1, $zero, $zero
        addi $a1, $a1, 16
        add $a2, $zero, $zero
        addi $a2, $a2, 2
        add $a3, $zero, $zero
        addi, $a3, $a3, 16
        
        # Load the colours for painting the background
        lw $t0, backgroundColour3
        sw $t0, 4($sp)
        lw $t1, backgroundColour3
        sw $t1, 0($sp)
        
        # Call the PAINT subroutine to create the checkered background
        jal PAINT
        
        # Restore the stack pointer
        addi $sp, $sp, 12

PAINT_SCORE_BOX_DONE:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - PAINT_PREVIEW_BOX
# Paints the preview box that shows the next block.
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PAINT_PREVIEW_BOX:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    PAINT_PREVIEW_BOX_BACKGROUND:
        addi $sp, $sp, -12
        add $a0, $zero, $zero
        addi $a0, $a0, 30
        add $a1, $zero, $zero
        addi $a1, $a1, 16
        add $a2, $zero, $zero
        addi $a2, $a2, 20
        add $a3, $zero, $zero
        addi, $a3, $a3, 10
        
        # Load the colours for painting the background
        lw $t0, backgroundColour3
        sw $t0, 4($sp)
        lw $t1, backgroundColour3
        sw $t1, 0($sp)
        
        # Call the PAINT subroutine to create the checkered background
        jal PAINT
        
        # Restore the stack pointer
        addi $sp, $sp, 12

PAINT_PREVIEW_BOX_DONE:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - PAINT_IA
# Paints the "I" block in orientation A.
#
# Arguments
#  - $a0: The X coordinate to start painting at.
#  - $a1: The Y coordinate to start painting at.
#  - $a2: The colour to paint the block in.
#
# Stack Arguments
#  None
PAINT_IA:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load the colours for painting the block
    addi $sp, $sp, -12
    sw $a2, 4($sp)
    sw $a2, 0($sp)
    
    # Store the current X and Y position of the block
    sw $a0, currentBlockX
    sw $a1, currentBlockY
    
    # Load the space in memory for the segments
    la $t1, currentBlockSegments

    # Initialize the segments
    add $t2, $a0, $zero
    add $t3, $a1, $zero

    # Initialize the counter
    add $t4, $zero, $zero
    STORE_IA:
        bge $t4, 4, STORE_IA_DONE

        # Store the segments in memory
        sw $t2, 0($t1)
        sw $t3, 4($t1)

        # Increment the Y position of the segment
        addi $t3, $t3, 1

        # Increment the pointer to the next segment
        addi $t1, $t1, 8

        # Increment the counter
        addi $t4, $t4, 1
        j STORE_IA
    STORE_IA_DONE:
    
    # Set the arguments for the X/Y position to paint the block
    move $a0, $a0
    move $a2, $a1

    # Set the width/height of the block (1x4)
    add $a1, $zero, $zero
    addi $a1, $a1, 1
    add $a3, $zero, $zero
    addi, $a3, $a3, 4
    
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12
    
PAINT_IA_DONE:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - PAINT_IB
# Paints the "I" block in orientation B.
#
# Arguments
#  - $a0: The X coordinate to start painting at.
#  - $a1: The Y coordinate to start painting at.
#  - $a2: The colour to paint the block in.
#
# Stack Arguments
#  None
PAINT_IB:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load the colours for painting the block
    addi $sp, $sp, -12
    sw $a2, 4($sp)
    sw $a2, 0($sp)
    
    # Store the current X and Y position of the block
    sw $a0, currentBlockX
    sw $a1, currentBlockY
    
    # STORE_IB:
        # add $t2, $a0, $zero
        
        # # Store the segments in memory
        # sw $t2, currentBlockS1X
        # add $t2, $t2, 1
        # sw $t2, currentBlockS2X
        # add $t2, $t2, 1
        # sw $t2, currentBlockS3X
        # add $t2, $t2, 1
        # sw $t2, currentBlockS4X
        # # add $t2, $t2, 1
        
        # add $t2, $a1, $zero
        # sw $t2, currentBlockS1Y
        # # add $t2, $t2, 1
        # sw $t2, currentBlockS2Y
        # # add $t2, $t2, 1
        # sw $t2, currentBlockS3Y
        # # add $t2, $t2, 1
        # sw $t2, currentBlockS4Y
        # # add $t2, $t2, 1
    
    # Load the space in memory for the segments
    la $t1, currentBlockSegments

    # Initialize the segments
    add $t2, $a0, $zero
    add $t3, $a1, $zero

    # Initialize the counter
    add $t4, $zero, $zero
    STORE_IB:
        bge $t4, 4, STORE_IB_DONE

        # Store the segments in memory
        sw $t2, 0($t1)
        sw $t3, 4($t1)

        # Increment the X position of the segment
        addi $t2, $t2, 1

        # Increment the pointer to the next segment
        addi $t1, $t1, 8

        # Increment the counter
        addi $t4, $t4, 1
        j STORE_IB
    STORE_IB_DONE:
    
    # Set the arguments for the X/Y position to paint the block
    move $a0, $a0
    move $a2, $a1

    # Set the width/height of the block (4x1)
    add $a1, $zero, $zero
    addi $a1, $a1, 4
    add $a3, $zero, $zero
    addi, $a3, $a3, 1
    
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12
    
PAINT_IB_DONE:
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0

# ------
# Screens
# ------

# Subroutine - PAINT_GAME_OVER
# Paints the game over screen with a centered red "X".
#
# Arguments
#   - None
#
# Stack Arguments
#   - None
PAINT_GAME_OVER:   
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Load the colour for painting the whole background
    addi $sp, $sp, -12
    lw $t1, backgroundPixel
    sw $t1, 0($sp)
    sw $t1, 4($sp)
    
    # Paint over the whole screen
    add $a0, $zero, $zero
    li $a1, 48
    add $a2, $zero, $zero
    li $a3, 32
    jal PAINT

    # Load the color red for painting
    lw $t1, redPixel
    sw $t1, 0($sp)
    sw $t1, 4($sp)

    # Define the starting X ($a0) and Y ($a2) coordinates for the first diagonal
    li $a0, 17
    li $a2, 9

    # Loop for the first diagonal (top left to bottom right)
    li $t7, 12
    PAINT_X_FIRST_DIAGONAL:
        beq $t7, $zero, PAINT_X_FIRST_DIAGONAL_DONE
        
        # Paint a 2x2 block for each part of the diagonal
        li $a1, 2
        li $a3, 2
        jal PAINT
        
        # Shift the pointer for painting the next position
        addi $a0, $a0, 1
        addi $a2, $a2, 1
        addi $t7, $t7, -1
        j PAINT_X_FIRST_DIAGONAL
    PAINT_X_FIRST_DIAGONAL_DONE:
        # Re-initialize variables (for painting the second diagonal)
        li $a0, 17
        li $a2, 20
        li $t7, 12
    
    PAINT_X_SECOND_DIAGONAL:
        beq $t7, $zero, PAINT_GAME_OVER_DONE
        
        li $a1, 2
        li $a3, 2
        jal PAINT
        
        # Shift the pointer for painting the next position
        addi $a0, $a0, 1
        addi $a2, $a2, -1
        addi $t7, $t7, -1
        j PAINT_X_SECOND_DIAGONAL

PAINT_GAME_OVER_DONE:
    # Restore the stack pointer
    addi $sp, $sp, 12
    # Load the return address from the stack
    lw $t0, 0($sp)
    jr $t0
    jr $ra



# -------
# Numbers
# -------

# This section contains subroutines for displaying numbers on the score box. The
# numbers will be displayed in the format "00" to "99". Each digit will occupy
# its own 7-segment display.
#
# In this implementation, the 7-segment display requires three pixels for each
# of its segments, making it 5 pixels wide and 9 pixels tall.

# Subroutine - PAINT_NUMBER
# Paints a number on the score box.
#
# Arguments
#   - $a0: The number to paint (0-99)
#
# Stack Arguments
#   - None
PAINT_NUMBER:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Clear the score board
    jal PAINT_SCORE_BOX

    # Load the number to paint
    lw $t0, gameScore
    
    # Calculate tens and ones digits
    li $t1, 10
    div $t0, $t1
    mflo $t6  # Tens digit
    mfhi $t7  # Ones digit

    # Tens digit painting
    # Assuming a function called PAINT_DIGIT that abstracts the painting of any digit
    addi $a0, $t6, 0   # Move tens digit to $a0 for PAINT_DIGIT
    jal PAINT_TENS_DIGIT    # Paint tens digit

    # Ones digit painting
    # Move to next position if tens digit was painted (adjust coordinates as needed)
    addi $a0, $t7, 0   # Move ones digit to $a0 for PAINT_DIGIT
    jal PAINT_ONES_DIGIT    # Paint ones digit

    # Restore the stack and return
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

PAINT_DIGIT:
    beq $a0, 0, PAINT_ZERO
    beq $a0, 1, PAINT_ONE

    jr $ra
    
PAINT_NUMBER_DONE:
    # Restore the original return address from the stack
    lw $t9, 0($sp)
    jr $t9

# Subroutine - PAINT_TENS_DIGIT
# Paints the tens digit of a number on the score box. This will paint the digit
# in the left 7-segment display.
#
# Arguments
#   - $a0: The digit to paint (0-9)
#
# Stack Arguments
#   - None
PAINT_TENS_DIGIT:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load the number to paint
    add $t0, $a0, $zero
    
    # Paint the digit
    addi $a0, $zero, 33
    addi $a1, $zero, 5
    lw $a2, greenPixel
    
    beq $t0, 0, PAINT_ZERO
    beq $t0, 1, PAINT_ONE
    beq $t0, 2, PAINT_TWO
    beq $t0, 3, PAINT_THREE
    beq $t0, 4, PAINT_FOUR
    beq $t0, 5, PAINT_FIVE
    beq $t0, 6, PAINT_SIX
    beq $t0, 7, PAINT_SEVEN
    beq $t0, 8, PAINT_EIGHT
    beq $t0, 9, PAINT_NINE
    
    
    
    # Restore the stack pointer
    addi $sp, $sp, 4
    lw $t9, 0($sp)
    jr $t9

# Subroutine - PAINT_ONES_DIGIT
# Paints the ones digit of a number on the score box. This will paint the digit
# in the right 7-segment display.
#
# Arguments
#   - $a0: The digit to paint (0-9)
#
# Stack Arguments
#   - None
PAINT_ONES_DIGIT:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Load the number to paint
    add $t0, $a0, $zero
    
    # Paint the digit
    addi $a0, $zero, 39
    addi $a1, $zero, 5
    lw $a2, greenPixel
    
    beq $t0, 0, PAINT_ZERO
    beq $t0, 1, PAINT_ONE
    beq $t0, 2, PAINT_TWO
    beq $t0, 3, PAINT_THREE
    beq $t0, 4, PAINT_FOUR
    beq $t0, 5, PAINT_FIVE
    beq $t0, 6, PAINT_SIX
    beq $t0, 7, PAINT_SEVEN
    beq $t0, 8, PAINT_EIGHT
    beq $t0, 9, PAINT_NINE
    
    
    # Restore the stack pointer
    addi $sp, $sp, 4
    lw $t9, 0($sp)
    jr $t9

# Subroutines - Numbers
# The subroutines below are each responsible for painting a single digit, given
# the top-left corner of the 7-segment display.
#
# Arguments
#   - $a0: The X coordinate of the top-left corner of the 7-segment display
#   - $a1: The Y coordinate of the top-left corner of the 7-segment display
#   - $a2: The colour to paint the digit
#
# Stack Arguments
#   - None

PAINT_ZERO:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display
 
    # Load the colours for painting the block
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_ZERO_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_ONE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_ONE_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_TWO:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_TWO_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0


PAINT_THREE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_THREE_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_FOUR:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_FOUR_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_FIVE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_FIVE_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_SIX:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_SIX_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_SEVEN:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_SEVEN_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_EIGHT:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_EIGHT_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

PAINT_NINE:
    # Store the original return address in the stack
    addi $sp, $sp, -4
    sw $ra, 0($sp)

    # Translate the coordinates to the address of the top-left corner of the
    # 7-segment display

    # Load the colours for painting the block
    # Colour
    addi $sp, $sp, -12
    sw $a2, 0($sp)
    sw $a2, 4($sp)

    # Paint segment 1
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $a0
    li $a1, 3
    add $a2, $zero, $a1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 2
    addi $t0, $a0, 3
    addi $t1, $a2, 1

    # Paint segment 2
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 3
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 3
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 4
    addi $t0, $a0, -3
    addi $t1, $a2, 3

    # Paint segment 4
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT

    # Calculate offset for segment 5
    addi $t0, $a0, -1
    addi $t1, $a2, -7

    # Paint segment 5
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 6
    add $t0, $a0, $zero
    addi $t1, $a2, 4

    # Paint segment 6
    # No colour
    lw $a2, backgroundColour1
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 1
    add $a2, $zero, $t1
    li $a3, 3
    jal PAINT

    # Calculate offset for segment 7
    addi $t0, $a0, 1
    addi $t1, $a2, -1

    # Paint segment 7
    # Colour
    lw $a2, greenPixel
    sw $a2, 0($sp)
    sw $a2, 4($sp)
    add $a0, $zero, $t0
    li $a1, 3
    add $a2, $zero, $t1
    li $a3, 1
    jal PAINT
    
    # Restore the stack pointer
    addi $sp, $sp, 12

PAINT_NINE_DONE:
    # Restore the original return address from the stack
    lw $t0, 0($sp)
    jr $t0

# Subroutine - PAINT
# Paints a given area on the connected bitmap display in a checkered pattern,
# alternating between two colors both horizontally and vertically.
#
# Arguments
#  - $a0: The X coordinate to start painting at.
#  - $a1: The number of iterations to paint "right" from $a0 (X).
#  - $a2: The Y coordinate to start painting at.
#  - $a3: The number of iterations to paint "down" from $a2 (Y).
#
# Stack Arguments
#  - $t8: The first color in the pattern.
#  - $t9: The second color in the pattern.
PAINT:
  # Retrieve arguments from the stack
  lw $t8, 4($sp)
  lw $t9, 0($sp)

  # Store the bitmap width
  lw $t0, bitmapWidth
   
  # Store the unit width
  lw $t1, unitWidth
   
  # Calculate the number of pixels available in each row of the bitmap
  divu $t1, $t1, 4
  divu $t0, $t0, $t1
   
  # Initialize base address and counters
  add $t5, $zero, $s0 # Base address of the bitmap
  mult $t1, $a0, 4
  add $t5, $t5, $t1
  mult $t1, $a2, $t0
  add $t5, $t5, $t1
  add $t1, $zero, $zero # X counter
  add $t2, $zero, $zero # Y counter
  add $t4, $zero, $zero # Not used in this version

  # Begin painting loop
  PAINT_LOOP_Y_START:
    beq $t2, $a3, PAINT_DONE # Exit loop if Y counter matches the Y iterations

    add $t1, $zero, $zero # Reset X counter for new row

    PAINT_LOOP_X_START:
      beq $t1, $a1, PAINT_LOOP_Y_END # Exit loop if X counter matches the X iterations

      # Checkered pattern logic: alternate starting color every row and every column
      add $t6, $t1, $t2 # Add X and Y counters
      andi $t6, $t6, 1 # Check if sum is even or odd for checkered pattern
      beqz $t6, USE_COLOR_T8
      add $t3, $zero, $t9 # Use second color
      j PAINT_PIXEL
    USE_COLOR_T8:
      add $t3, $zero, $t8 # Use first color

    PAINT_PIXEL:
      # Paint the pixel
      sw $t3, 0($t5)

      # Increment X counter and move to next pixel
      addi $t1, $t1, 1
      addi $t5, $t5, 4
      j PAINT_LOOP_X_START

    PAINT_LOOP_Y_END:
      # Prepare for the next row
      addi $t2, $t2, 1 # Increment Y counter
      mult $t1, $a1, 4
      sub $t5, $t5, $t1 # Move back to the start of the row
      add $t5, $t5, $t0 # Move down to the next row
      j PAINT_LOOP_Y_START

  PAINT_DONE:
    jr $ra
