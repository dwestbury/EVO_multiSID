/* -------------------------------------------------------------------------------------------
MultiSID Tester - A simple utility to test SIDs listening on different addresses

By: Darrell Westbury (DWestbury_505@msn.com)
Version: 0.9 (Beta)
Preview Release: May 6th 2024 

Background:
This is the first Assembly Language code I've written since 1992.
It's been a blast rolling the sleeves up again, but I'm 'clearly' a bit rusty.

Usage:
I'm hoping the simple Grid-based navigation system, combined with the lower status bar and
the Command Reference make this tool pretty easy and intuitive to use.

Credits:
When I was looking for a Music Player routine that I could modify easily to support multiple SID addresses,
I was thrilled to find some code by Cadaver (loorni@gmail.com) that just what the Doctor ordered.
https://cadaver.github.io/rants/music.html

I also made good use of this nifty PETSCII editor to create the Command Reference screen.
https://petscii.krissz.hu/

Other great tools I used include:
KickAssembler: http://theweb.dk/KickAssembler/Main.html
VICE: https://vice-emu.sourceforge.io/
Ultimate II+ Cartridge: https://www.ultimate64.com/
EVO64: https://www.evo64.com/

Considerations:
> This is an early work in progress, and I'm sure there are many bugs and opportunities for improvements to be made.
> You will experience instability if you're using a cartridge like RetroReplay and tryin to use SIDs addressing in the $DE00-$DFE0 range.
> I welcome suggestions and feedback, so please feel free to reach out to me at: DWestbury_505@msn.com
*/


.pc = $0801 "Basic SYS 2064"  // BASIC Header with default start address
:BasicUpstart($810)

.pc = $810 "SID-Grid Interface"

// Define labels and constants
.const SCREEN_MEM    = $0400  // Start of C64 screen memory
.const COLOR_MEM     = $D800  // Start of C64 color memory
.const CHAR_GRID_X   = $02    // Zeropage reference for the current X positon on the Grid
.const CHAR_GRID_Y   = $03    // Zeropage reference for the current Y positon on the Grid

// Main program start
    jsr DrawSIDGrid           // Draw the SID address table with Sprite0 for navigation
    jsr InitializeStatusBar   // Initialize the status bar
    jsr SetUpRasterInterrupt  // Set up a raster interrupt for Sprite0 color cycling
    lda #$00                  // Initialize the music player for SID 1 @ $D400
    jsr MUSIC_INIT              

// Main loop to scan for key presses and joystick movements
MainLoop:
    jsr $FFE4                 // C64 Kernal routine to check for key press
    bne KeyPressed            // check if no key has been pressed
    inc JOYSTICK_DEBOUNCE     // Read Joystick in port 2 with debounce logic (e.g., every 1,280 MainLoop cycles)
    lda JOYSTICK_DEBOUNCE
    bne MainLoop
    inc JOYSTICK_DEBOUNCE +1
    lda JOYSTICK_DEBOUNCE +1
    cmp #$05
    bne MainLoop
    lda #$00
    sta JOYSTICK_DEBOUNCE +1
    lda $DC00                 // Read joystick port 2
    cmp #$7F                  // Check for joystick movement
    bne Joystick_handler 
    jmp MainLoop

Joystick_handler:
    cmp #$7E                  // Joystick 2 up
    beq CursorUp
    cmp #$7D                  // Joystick 2 down
    beq CursorDown
    cmp #$77                  // Joystick 2 left
    beq CursorLeft
    cmp #$7B                  // Joystick 2 right
    beq CursorRight
    cmp #$6F                  // Joystick 2 fire button
    beq SpaceSelect
    jmp MainLoop

KeyPressed:
    cmp #$11                  // cursor down
    beq CursorDown
    cmp #$91                  // cursor up
    beq CursorUp
    cmp #$1D                  // cursor left
    beq CursorLeft
    cmp #$9D                  // cursor right
    beq CursorRight
    cmp #$20                  // space bar to select
    beq SpaceSelect
    cmp #$85                  // F1 to Activate Command Reference
    beq CMDRefJump
    jmp MainLoop

//Jump table for Grid movement (maintains relative branching distances below 128 bytes)
CursorDown:
    jmp exCursorDown

CursorUp:  
    jmp exCursorUp

CursorLeft:
    jmp exCursorLeft

CursorRight:
    jmp exCursorRight

SpaceSelect:
    jmp exSpaceSelect

CMDRefJump:
    jmp CommandRefScreen


exCursorDown:
    lda SPRITE_GRID_Y
    clc
    adc #$01
    cmp #$06
    beq CursorDownBypass
    sta SPRITE_GRID_Y
    jsr MoveGridBlock
CursorDownBypass:
    jmp MainLoop

exCursorUp:
    lda SPRITE_GRID_Y
    sec
    sbc #$01
    cmp #$FF
    beq CursorUpBypass
    sta SPRITE_GRID_Y
    jsr MoveGridBlock
CursorUpBypass:
    jmp MainLoop

exCursorLeft:
    lda SPRITE_GRID_X
    clc
    adc #$01
    cmp #$08
    beq CursorLeftBypass
    sta SPRITE_GRID_X
    jsr MoveGridBlock
CursorLeftBypass:
    jmp MainLoop

exCursorRight:
    lda SPRITE_GRID_X
    sec
    sbc #$01
    cmp #$FF
    beq CursorRightBypass
    sta SPRITE_GRID_X
    jsr MoveGridBlock
CursorRightBypass:
    jmp MainLoop

exSpaceSelect:
    clc
    lda SPRITE_GRID_Y         // load the Y counter for the currently selected SID
    asl                       // Multiply by 8 to get the Y position in the grid
    asl
    asl
    clc
    adc SPRITE_GRID_X         // add the X counter to get the complete grid position
    sta NEW_SID_INDEX         // store the new SID index

    lda MUSIC_PLAY_FLAG       // If no SIDs are playing, active the Grid cell and start the music
    bne DeterminePlayState

NoMusicIsPlaying:
    lda #$01
    ldx NEW_SID_INDEX
    sta BOX_GRID_STATE, x     // store the new state of the box
    stx ACTIVE_SID_PLAY_INDEX
    sta MUSIC_PLAY_FLAG
    jsr DrawClosedbox
    jmp EndGridSelect

DeterminePlayState:           // Check whether a previous Grid cell was active
    lda NEW_SID_INDEX
    cmp ACTIVE_SID_PLAY_INDEX
    beq DeselectOld

DeselectOldAndSelectnew:      // Clear the old Grid cell and deactivate SID Playback
    ldx ACTIVE_SID_PLAY_INDEX
    lda #$00
    sta BOX_GRID_STATE, x     
    jsr DrawOpenBox

    ldx NEW_SID_INDEX         // Set the Grid cell and state for the new SID
    lda #$01
    sta BOX_GRID_STATE, x
    sta MUSIC_PLAY_FLAG
    stx ACTIVE_SID_PLAY_INDEX
    jsr DrawClosedbox
    jmp EndGridSelect

DeselectOld:                  // Clear the old Grid cell and deactivates SID Playback
    tax
    lda #$00
    sta BOX_GRID_STATE, x
    sta MUSIC_PLAY_FLAG
    jsr DrawOpenBox

EndGridSelect:
    lda ACTIVE_SID_PLAY_INDEX
    jsr MUSIC_INIT
    jmp MainLoop


DrawOpenBox:
    lda BOX_GRID_LB,x
    sta CHAR_GRID_X
    lda BOX_GRID_HB,x
    sta CHAR_GRID_Y
    ldy #$00
    lda #$70
    sta (CHAR_GRID_X),y
    iny
    lda #$6E
    sta (CHAR_GRID_X),y
    ldy #$28
    lda #$6D
    sta (CHAR_GRID_X),y
    iny
    lda #$7D
    sta (CHAR_GRID_X),y
    lda CHAR_GRID_Y
    clc
    adc #$D4
    sta CHAR_GRID_Y
    ldy #$00
    lda #$0F
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    ldy #$28
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    rts

DrawClosedbox:
    lda BOX_GRID_LB,x
    sta CHAR_GRID_X
    lda BOX_GRID_HB,x
    sta CHAR_GRID_Y
    ldy #$00
    lda #$6C
    sta (CHAR_GRID_X),y
    iny
    lda #$7B
    sta (CHAR_GRID_X),y
    ldy #$28
    lda #$7C
    sta (CHAR_GRID_X),y
    iny
    lda #$7E
    sta (CHAR_GRID_X),y
    lda CHAR_GRID_Y
    clc
    adc #$D4
    sta CHAR_GRID_Y
    ldy #$00
    lda #$02
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    ldy #$28
    sta (CHAR_GRID_X),y
    iny
    sta (CHAR_GRID_X),y
    rts


// Draws the Command Reference Screen
CommandRefScreen:
    ldx #$00
    stx $D015 // Disable sprite 0
CopyCMDRefCharLoop:
    lda SCREEN_MEM       + 00,x
    sta $C000            + 00,x
    lda COLOR_MEM        + 00,x
    sta $c400            + 00,x
    lda MENU_SCREEN_DATA + 00,x
    sta SCREEN_MEM       + 00,x
    lda MENU_COLOR_DATA  + 00,x
    sta COLOR_MEM        + 00,x

    lda SCREEN_MEM       + 256,x
    sta $C000            + 256,x
    lda COLOR_MEM        + 256,x
    sta $c400            + 256,x
    lda MENU_SCREEN_DATA + 256,x
    sta SCREEN_MEM       + 256,x
    lda MENU_COLOR_DATA  + 256,x
    sta COLOR_MEM        + 256,x

    lda SCREEN_MEM       + 512,x
    sta $C000            + 512,x
    lda COLOR_MEM        + 512,x
    sta $c400            + 512,x
    lda MENU_SCREEN_DATA + 512,x
    sta SCREEN_MEM       + 512,x
    lda MENU_COLOR_DATA  + 512,x
    sta COLOR_MEM        + 512,x

    lda SCREEN_MEM       + 768,x
    sta $C000            + 768,x
    lda COLOR_MEM        + 768,x
    sta $c400            + 768,x
    lda MENU_SCREEN_DATA + 768,x
    sta SCREEN_MEM       + 768,x
    lda MENU_COLOR_DATA  + 768,x
    sta COLOR_MEM        + 768,x
    inx
    bne CopyCMDRefCharLoop

// Check for F1 key to exit Command Reference and return to Mainloop
MenuLoop:
    jsr $FFE4                 // C64 Kernal routine to check for key press
    cmp #$85                  // F1 to Exit Menu and Return to Mainloop
    beq ExitCMDRef
    cmp #$20                  // Space bar also Exits Menu
    beq ExitCMDRef
    jmp MenuLoop

ExitCMDRef:    
    ldx #$00
RestoreScreenState:
    lda $C000            + 00,x
    sta SCREEN_MEM       + 00,x
    lda $c400            + 00,x
    sta COLOR_MEM        + 00,x

    lda $C000            + 256,x
    sta SCREEN_MEM       + 256,x
    lda $c400            + 256,x
    sta COLOR_MEM        + 256,x

    lda $C000            + 512,x
    sta SCREEN_MEM       + 512,x
    lda $c400            + 512,x
    sta COLOR_MEM        + 512,x

    lda $C000            + 768,x
    sta SCREEN_MEM       + 768,x
    lda $c400            + 768,x
    sta COLOR_MEM        + 768,x
    inx
    bne RestoreScreenState
    lda #$FF
    sta $D015                 // Reenable sprites
    jmp MainLoop


// Subroutine to draw the main screen grid with SID address table
DrawSIDGrid:
    ldx #$00
    stx $d021                 // Set border color
//  inx
    stx $d020                 // Set screen background color
    lda #$01
    sta $0286                 // Set the active screen color (cursor) to white
    jsr $E544                 // Call C64 Kernal routine to clear the screen and fill color mem with white
    lda #$85                  // Set the character mode to Upper case
    jsr $FFE4
    lda #$08                  // Disable character change from upper to lower case
    jsr $FFE4


    ldx #$00    
CopySIDGridChars:
    lda MAIN_SCREEN_DATA + 00,x
    sta SCREEN_MEM       + 00,x
    lda MAIN_COLOR_DATA  + 00,x
    sta COLOR_MEM        + 00,x
    lda MAIN_SCREEN_DATA + 256,x
    sta SCREEN_MEM       + 256,x
    lda MAIN_COLOR_DATA  + 256,x
    sta COLOR_MEM        + 256,x
    lda MAIN_SCREEN_DATA + 512,x
    sta SCREEN_MEM       + 512,x
    lda MAIN_COLOR_DATA  + 512,x
    sta COLOR_MEM        + 512,x
    lda MAIN_SCREEN_DATA + 768,x
    sta SCREEN_MEM       + 768,x
    lda MAIN_COLOR_DATA  + 768,x
    sta COLOR_MEM        + 768,x
    inx
    bne CopySIDGridChars


// Place Grid Block Sprite on the screen
    lda #(SPR_GRID_BLOCK/64)   // Set sprite definition to Grid Block
    sta $07f8 
    lda #$02
    sta $d027                  // Set sprite color to red
    lda #$01
    sta $d015                  // Enable sprite 0
    
    lda #$00                   // Initialize the grid block position
    sta SPRITE_GRID_X
    sta SPRITE_GRID_Y

MoveGridBlock:
    ldx SPRITE_GRID_X          // Pointer to a table of fixed X coordinates 
    ldy SPRITE_GRID_Y          // Pointer to a table of fixed Y coordinates
    lda SPRITE_POS_X, x
    sta $d000                  // Set Grid Block (sprite 0) x position
    lda SPRITE_POS_X_OFFSET, x
    sta $d010
    lda SPRITE_POS_Y, y
    sta $d001                  // Set Grid Block (sprite 0) y position
    rts

// Status Bar Sprites
InitializeStatusBar:
    lda #$ff
    sta $d015                   // Enable Status Bar Sprites
    lda #$00
    sta STATUS_BAR_MSG_INDEX    // Initialize the status bar message index
    tay
    tax
InitStatusBarLoop:
    lda STATUS_BAR_SPRITE_X,y
    sta $d002,x
    lda #$F2
    sta $d003,x
    lda #$01
    sta $d028,y
    inx
    inx
    iny
    cpy #$07
    bne InitStatusBarLoop


UpdateStatusBar:
    lda #$00
    sta STATUS_BAR_SPR_DEF_OFFSET
    clc
    lda STATUS_BAR_MSG_INDEX
    asl
    rol STATUS_BAR_SPR_DEF_OFFSET
    asl
    rol STATUS_BAR_SPR_DEF_OFFSET
    asl
    rol STATUS_BAR_SPR_DEF_OFFSET
    clc
    adc #<STATUS_BAR_SPRITE_DEF
    sta UpdateStatusBarLoop + 1
    lda STATUS_BAR_SPR_DEF_OFFSET
    adc #>STATUS_BAR_SPRITE_DEF
    sta UpdateStatusBarLoop + 2    
    ldx #$00
UpdateStatusBarLoop:
    lda STATUS_BAR_SPRITE_DEF,x
    sta $07f9,x
    inx
    cpx #$07
    bne UpdateStatusBarLoop
    rts

StatusBarCycle:
    ldx STATUS_BAR_CYCLE_INDEX      // Cycle through SID play status and most commonly used menu options
    lda STATUS_BAR_CYCLE_STEP,x
    cmp #$FF                        // Check for special status messages (e.g., show the currently active SID or explain how to select & activate them)
    bne ContinueCycle
    lda MUSIC_PLAY_FLAG             // Check flag to see if SIDs are active. If not, cycle messages related to grid navigation & SID activation
    bne SIDsAreActive
    lda STATUS_BAR_CYCLE_WHEN_SIDS_OFF
    jmp ContinueCycle
SIDsAreActive:                      // If SIDs are active, show which SID is currently playing
    lda ACTIVE_SID_PLAY_INDEX
ContinueCycle:
    sta STATUS_BAR_MSG_INDEX

    inc STATUS_BAR_CYCLE_COUNTER    // Delay timer to hold current status message
    lda STATUS_BAR_CYCLE_COUNTER
    cmp #$80                        // Set number of screen refreshes to hold the message
    bne StatusBarDisplay
    lda #$00
    sta STATUS_BAR_CYCLE_COUNTER

    ldx STATUS_BAR_CYCLE_INDEX      // If SIDs are inactive, cycle through the activation tips
    lda STATUS_BAR_CYCLE_STEP,x
    cmp #$ff
    bne SkipInactiveSIDCycle
    lda NO_ACTIVE_SIDS
    bne SkipInactiveSIDCycle
    lda STATUS_BAR_CYCLE_WHEN_SIDS_OFF
    eor #$07
    sta STATUS_BAR_CYCLE_WHEN_SIDS_OFF

SkipInactiveSIDCycle:               // Increment through status bar messages
    inc STATUS_BAR_CYCLE_INDEX
    lda STATUS_BAR_CYCLE_INDEX
    cmp #$06
    bne StatusBarDisplay
    lda #$00
    sta STATUS_BAR_CYCLE_INDEX
StatusBarDisplay:
    jmp UpdateStatusBar



// Set up the raster interrupt
SetUpRasterInterrupt:
    sei                       // Disable interrupts while setting up
    lda #$7f                  // Mask all but the raster interrupt
    sta $DC0D                 // in CIA 1 interrupt control register
    sta $DD0D
    lda #$FF                  // Raster line at the beginning of the lower border
    sta $D012                 // Raster line low byte
    lda $D011                 // Load current value of $D011
    and #%01111111            // Clear bit 7
//    ora #%10000000          // Set bit 7 if LOWER_BORDER_RASTER_LINE is greater than 255
    sta $D011                 // Store back to $D011
    lda #$01
    sta $D01A                 // Enable raster interrupts
    lda #<RasterInterruptISR
    sta $0314
    lda #>RasterInterruptISR
    sta $0315
    cli                       // Re-enable interrupts
    rts

// Raster Interrupt Service Routine
RasterInterruptISR:
    pha                       // Save registers
    txa
    pha
    tya
    pha
//  inc $d020                 // Debug: Check ISR timing by changing the border color, before and after the interrupt
    jsr Sprite_Color_Cycle
    jsr StatusBarCycle
    jsr Play_Music
//  dec $d020                 // Debug: Reset the border color
    inc $D019                 // Acknowledge the interrupt
    pla                       // Restore registers
    tay
    pla
    tax
    pla
    jmp $EA31                 // Exit to Kernal routine to scan the keyboard


// Increment the color cycle of Sprite 0
Sprite_Color_Cycle:
    ldx CURRENT_COLOR_INDEX
    lda COLOR_SEQUENCE,x
    sta $D027
    sta $d028
    sta $d029
    sta $d02a
    sta $d02b
    sta $d02c
    sta $d02d
    sta $d02e
    inc CURRENT_COLOR_INDEX
    lda CURRENT_COLOR_INDEX
    cmp #$24
    bne SkipReset
    lda #$00
    sta CURRENT_COLOR_INDEX
SkipReset:
    rts

Play_Music:
    lda MUSIC_PLAY_FLAG
    beq SkipMusic
    ldx ACTIVE_SID_PLAY_INDEX
    lda BOX_GRID_STATE, x
    beq SkipMusic
    jsr MUSIC_PLAYER
SkipMusic:
    rts


// ----------------------------------------------------------
// Various Flags, Counters and Indices
// ----------------------------------------------------------

SPRITE_POS_X:
.byte 109, 133, 157, 181, 205, 229, 253, 277

SPRITE_POS_X_OFFSET:
.byte  0, 0, 0, 0, 0, 0, 0, 1

SPRITE_POS_Y:
.byte  103, 127, 151, 175, 199, 223

SPRITE_GRID_X:
.byte 0

SPRITE_GRID_Y:
.byte 0

BOX_GRID_LB:
.byte $FA, $FD, $00, $03, $06, $09, $0C, $0F 
.byte $72, $75, $78, $7B, $7E, $81, $84, $87
.byte $EA, $ED, $F0, $F3, $F6, $F9, $FC, $FF 
.byte $62, $65, $68, $6B, $6E, $71, $74, $77 
.byte $DA, $DD, $E0, $E3, $E6, $E9, $EC, $EF 
.byte $52, $55, $58, $5B, $5E, $61, $64, $67 

BOX_GRID_HB:
.byte $04, $04, $05, $05, $05, $05, $05, $05 
.byte $05, $05, $05, $05, $05, $05, $05, $05 
.byte $05, $05, $05, $05, $05, $05, $05, $05 
.byte $06, $06, $06, $06, $06, $06, $06, $06 
.byte $06, $06, $06, $06, $06, $06, $06, $06
.byte $07, $07, $07, $07, $07, $07, $07, $07 

BOX_GRID_STATE:
.byte 0, 0, 0, 0, 0, 0, 0, 0 
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0
.byte 0, 0, 0, 0, 0, 0, 0, 0

// Color cycle for Sprite 0: White, Yellow, Light Red... 
COLOR_SEQUENCE:
.byte   1,  1,  1,  1,  1,  7,  7,  7
.byte   7,  7, 10, 10, 10, 10, 10, 10
.byte  10,  2,  2,  2,  2,  2,  2,  2
.byte   2,  2, 10, 10, 10, 10, 10,  7
.byte   7,  7,  7,  7

// Status Bar Sprite Positions
STATUS_BAR_SPRITE_X:
.const SPRITE_BAR_X = 111
.byte  SPRITE_BAR_X +24*0
.byte  SPRITE_BAR_X +24*1
.byte  SPRITE_BAR_X +24*2
.byte  SPRITE_BAR_X +24*3
.byte  SPRITE_BAR_X +24*4
.byte  SPRITE_BAR_X +24*5
.byte  SPRITE_BAR_X +24*6


STATUS_BAR_MSG_INDEX:
.byte 0

STATUS_BAR_SPR_DEF_OFFSET:
.byte 0

STATUS_BAR_CYCLE_COUNTER:
.byte 0

STATUS_BAR_CYCLE_INDEX:
.byte 0

STATUS_BAR_CYCLE_WHEN_SIDS_OFF:
.byte $34

STATUS_BAR_CYCLE_STEP:
//.byte 48, 255, 49, 255, 50, 255
.byte 255, 255, 255, 255, 255, 255

// Flags & indicies
CURRENT_COLOR_INDEX:
.byte 0

ACTIVE_SID_PLAY_INDEX:
.byte 0

NEW_SID_INDEX:
.byte 0

NO_ACTIVE_SIDS:
.byte 0

MUSIC_PLAY_FLAG:
.byte 0

JOYSTICK_DEBOUNCE:
.byte 0, 0


// -----------------------------------------------
// Sprite Definition Sets for the Lower Status Bar
// -----------------------------------------------
STATUS_BAR_SPRITE_DEF:
// -----------------------
// SIDS in the $D400 Range
// -----------------------
// ACTIVE SID ON:  $D400
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +0
.byte 0

// ACTIVE SID ON:  $D420
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +1
.byte 0

// ACTIVE SID ON:  $D440
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +2
.byte 0

// ACTIVE SID ON:  $D460
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +3
.byte 0

// ACTIVE SID ON:  $D480
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +4
.byte 0

// ACTIVE SID ON:  $D4A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +5
.byte 0

// ACTIVE SID ON:  $D4C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +6
.byte 0

// ACTIVE SID ON:  $D4E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +7
.byte 0

// -----------------------
// SIDS in the $D500 Range
// -----------------------
// ACTIVE SID ON:  $D500
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +8
.byte 0

// ACTIVE SID ON:  $D520
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +9
.byte 0

// ACTIVE SID ON:  $D540
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +10
.byte 0

// ACTIVE SID ON:  $D560
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +11
.byte 0

// ACTIVE SID ON:  $D580
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +12
.byte 0

// ACTIVE SID ON:  $D5A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +13
.byte 0

// ACTIVE SID ON:  $D5C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +14
.byte 0

// ACTIVE SID ON:  $D5E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +15
.byte 0

// -----------------------
// SIDS in the $D600 Range
// -----------------------
// ACTIVE SID ON:  $D600
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +16
.byte 0

// ACTIVE SID ON:  $D620
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +17
.byte 0

// ACTIVE SID ON:  $D640
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +18
.byte 0

// ACTIVE SID ON:  $D660
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +19
.byte 0

// ACTIVE SID ON:  $D680
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +20
.byte 0

// ACTIVE SID ON:  $D6A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +21
.byte 0

// ACTIVE SID ON:  $D6C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +22
.byte 0

// ACTIVE SID ON:  $D6E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +23
.byte 0

// -----------------------
// SIDS in the $D700 Range
// -----------------------
// ACTIVE SID ON:  $D700
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +24
.byte 0

// ACTIVE SID ON:  $D720
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +25
.byte 0

// ACTIVE SID ON:  $D740
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +26
.byte 0

// ACTIVE SID ON:  $D760
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +27
.byte 0

// ACTIVE SID ON:  $D780
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +28
.byte 0

// ACTIVE SID ON:  $D7A0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +29
.byte 0

// ACTIVE SID ON:  $D7C0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +30
.byte 0

// ACTIVE SID ON:  $D7E0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +31
.byte 0

// -----------------------
// SIDS in the $DE00 Range
// -----------------------
// ACTIVE SID ON:  $DE00
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +32
.byte 0

// ACTIVE SID ON:  $DE20
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +33
.byte 0

// ACTIVE SID ON:  $DE40
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +34
.byte 0

// ACTIVE SID ON:  $DE60
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +35
.byte 0

// ACTIVE SID ON:  $DE80
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +36
.byte 0

// ACTIVE SID ON:  $DEA0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +37
.byte 0

// ACTIVE SID ON:  $DEC0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +38
.byte 0

// ACTIVE SID ON:  $DEE0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +39
.byte 0

// -----------------------
// SIDS in the $DF00 Range
// -----------------------
// ACTIVE SID ON:  $DF00
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +40
.byte 0

// ACTIVE SID ON:  $DF20
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +41
.byte 0

// ACTIVE SID ON:  $DF40
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +42
.byte 0

// ACTIVE SID ON:  $DF60
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +43
.byte 0

// ACTIVE SID ON:  $DF80
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +44
.byte 0

// ACTIVE SID ON:  $DFA0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +45
.byte 0

// ACTIVE SID ON:  $DFC0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +46
.byte 0

// ACTIVE SID ON:  $DFE0
.byte (SPR_STATUS4/64) +0
.byte (SPR_STATUS4/64) +1
.byte (SPR_STATUS4/64) +2
.byte (SPR_STATUS4/64) +3
.byte (SPR_STATUS4/64) +4
.byte (SPR_STATUS4/64) +5
.byte (SPR_SIDADDR/64) +47
.byte 0

// [F3] TOGGLES MUSIC
.byte (SPR_STATUS1/64) +0
.byte (SPR_STATUS1/64) +1
.byte (SPR_STATUS1/64) +2
.byte (SPR_STATUS1/64) +3
.byte (SPR_STATUS1/64) +4
.byte (SPR_STATUS1/64) +5
.byte (SPR_STATUS1/64) +6
.byte 0

// [F5/F6] TO SWITCH SID
.byte (SPR_STATUS2/64) +0
.byte (SPR_STATUS2/64) +1
.byte (SPR_STATUS2/64) +2
.byte (SPR_STATUS2/64) +3
.byte (SPR_STATUS2/64) +4
.byte (SPR_STATUS2/64) +5
.byte (SPR_STATUS2/64) +6
.byte 0

// [F7] CLEARS THE GRID
.byte (SPR_STATUS3/64) +0
.byte (SPR_STATUS3/64) +1
.byte (SPR_STATUS3/64) +2
.byte (SPR_STATUS3/64) +3
.byte (SPR_STATUS3/64) +4
.byte (SPR_STATUS3/64) +5
.byte (SPR_STATUS3/64) +6
.byte 0

// MOVE - CURSORS / JOY2
.byte (SPR_STATUS5/64) +0
.byte (SPR_STATUS5/64) +1
.byte (SPR_STATUS5/64) +2
.byte (SPR_STATUS5/64) +3
.byte (SPR_STATUS5/64) +4
.byte (SPR_STATUS5/64) +5
.byte (SPR_STATUS5/64) +6
.byte 0

// SELECT - SPACE / FIRE
.byte (SPR_STATUS6/64) +0
.byte (SPR_STATUS6/64) +1
.byte (SPR_STATUS6/64) +2
.byte (SPR_STATUS6/64) +3
.byte (SPR_STATUS6/64) +4
.byte (SPR_STATUS6/64) +5
.byte (SPR_STATUS6/64) +6
.byte 0


//------------------------------------------------------------------------------
//-Musicroutine by: Cadaver (loorni@gmail.com)
//-https://cadaver.github.io/rants/music.html                                                  
//                                                                              
//-Additions by: Darrell Westbury (dwestbury_505@msn.com)
// > Converted code for KickAssembler
// > Added Multi-SID support
//-----------------------------------------------------------------------------
.pc = $1000 "Multi-SID Music Player"

MUSIC_INIT:     jmp init                //Jump to the initialization routine
MUSIC_PLAYER:   jmp play                //Jump to the play routine

.const temp1    = $fb                   //zeropage addresses for indirect indexing
.const temp2    = $fc
.const temp3    = $fd                   //Multi-SID address vectoring
.const temp4    = $fe

.const C0       = $00                   //Definitions for note data.
.const CIS0     = $01                   //Note numbers are always followed
.const D0       = $02                   //by the note duration in frames
.const DIS0     = $03
.const E0       = $04
.const F0       = $05
.const FIS0     = $06
.const G0       = $07
.const GIS0     = $08
.const A0       = $09
.const B0       = $0a
.const H0       = $0b
.const C1       = $0c
.const CIS1     = $0d
.const D1       = $0e
.const DIS1     = $0f
.const E1       = $10
.const F1       = $11
.const FIS1     = $12
.const G1       = $13
.const GIS1     = $14
.const A1       = $15
.const B1       = $16
.const H1       = $17
.const C2       = $18
.const CIS2     = $19
.const D2       = $1a
.const DIS2     = $1b
.const E2       = $1c
.const F2       = $1d
.const FIS2     = $1e
.const G2       = $1f
.const GIS2     = $20
.const A2       = $21
.const B2       = $22
.const H2       = $23
.const C3       = $24
.const CIS3     = $25
.const D3       = $26
.const DIS3     = $27
.const E3       = $28
.const F3       = $29
.const FIS3     = $2a
.const G3       = $2b
.const GIS3     = $2c
.const A3       = $2d
.const B3       = $2e
.const H3       = $2f
.const C4       = $30
.const CIS4     = $31
.const D4       = $32
.const DIS4     = $33
.const E4       = $34
.const F4       = $35
.const FIS4     = $36
.const G4       = $37
.const GIS4     = $38
.const A4       = $39
.const B4       = $3a
.const H4       = $3b
.const C5       = $3c
.const CIS5     = $3d
.const D5       = $3e
.const DIS5     = $3f
.const E5       = $40
.const F5       = $41
.const FIS5     = $42
.const G5       = $43
.const GIS5     = $44
.const A5       = $45
.const B5       = $46
.const H5       = $47
.const C6       = $48
.const CIS6     = $49
.const D6       = $4a
.const DIS6     = $4b
.const E6       = $4c
.const F6       = $4d
.const FIS6     = $4e
.const G6       = $4f
.const GIS6     = $50
.const A6       = $51
.const B6       = $52
.const H6       = $53
.const C7       = $54
.const CIS7     = $55
.const D7       = $56
.const DIS7     = $57
.const E7       = $58
.const F7       = $59
.const FIS7     = $5a
.const G7       = $5b
.const GIS7     = $5c
.const A7       = $5d
.const B7       = $5e
.const H7       = $5f
.const REST     = $60                   //Rest clears the gatebit
.const CONTINUE = $61                   //Continue just continues the note
.const INSTR    = $80                   //Values $80-$fe are instrument changes
.const END      = $ff                   //End voice data// followed by a 16-bit jump
                                        //address

//-----------------------------------------------------------------------------
//-Initialize Routine: Sets the song number and clears all SID registers
//-----------------------------------------------------------------------------
init:           sta sid_address_index   //Receive Multi-SID address index from caller
                lda #$00
                sta play_flag+1         //Set the Song to be played
                tax                     //Clear SID registers for each SID addresses
set_sid_addr:   lda sid_address_lo,x
                sta temp3
                lda sid_address_hi,x
                sta temp4
                ldy #$00
clear_reg_loop: sta (temp3),y
                iny
                cpy #$28
                bne clear_reg_loop
                inx
                cpx #$20                //Only clear the first 32 SIDs to avoid conflict with Retro Replay cart.
                bne set_sid_addr        //Loop until all SID registers are cleared
                ldx sid_address_index   //Load the Multi-SID address index
                lda sid_address_lo,x    //Set the specific SID address to be used
                sta temp3
                lda sid_address_hi,x
                sta temp4
                lda #$FF
                ldy #$18
                sta (temp3),y           //Set the volume to maximum for active SID
                rts

//-----------------------------------------------------------------------------
//-Interrupt Service Routine (ISR) to play sounds once per screen refresh cycle
//-----------------------------------------------------------------------------
play:           ldx #$00                //X will be the voice index
play_flag:      lda #$00                //Check the init/play flag
                bmi play_playloop       //Nonnegative value -> init song
                                        //(song number is the value)
                                        //Negative value -> play
                asl
                sta temp1               //Multiply songnumber by 6 to get
                asl                     //index to song startaddresstable
                adc temp1
                tay

play_initloop:  lda songtbl,y           //Copy start address of music data
                sta v_ptrlo,x           //to voice data pointer (16bit
                lda songtbl+1,y         //value)
                sta v_ptrhi,x
                iny                     //Increment index for next voice
                iny
                lda #$02                //Reset note-duration counter to 2
                sta v_counter,x         //(new notes will be fetched)
                lda #$08                //Set testbit in waveform, to reset
                sta v_waveform,x        //noise waveform if it has been stuck
                inx
                cpx #$03                //Loop thru all 3 voices
                bcc play_initloop
                lda #$00                //Reset filter bits - this musicroutine
                ldy #$17
                sta (temp3),y           //doesn't use filter - Now Multi-SID compatible
                lda #$0f                //Reset volume to maximum
                ldy #$18
                sta (temp3),y           //Now Multi-SID compatible
                lda #$ff                //Set negative value to the playing flag
                sta play_flag+1         //so that playing can start
                rts

play_initnew:   ldy v_note,x            //Get notenumber
                cpy #REST               //If it's a rest or continue, do nothing
                bcs play_initonlycounter
                lda freqtbllo,y         //Get note's frequency from the
                sta v_freqlo,x          //frequency table
                lda freqtblhi,y
                sta v_freqhi,x
                ldy v_instr,x           //Get voice instrument number
                lda i_pulselo,y         //Copy pulse width initial value,
                sta v_pulselo,x         //waveform and ADSR from instrument
                lda i_pulsehi,y         //data to voice variables
                sta v_pulsehi,x
                lda i_waveform,y
                sta v_waveform,x
                lda i_ad,y
                sta v_ad,x
                lda i_sr,y
                sta v_sr,x
play_initonlycounter:
                lda v_counternew,x      //New value for the note duration
                sta v_counter,x         //counter
                jmp play_deccounter

play_playloop:  lda v_counter,x         //Time to init new notes?
                beq play_initnew
                cmp #$02                //Or fetch new notes?
                beq play_fetchnew
play_pulsemod:  ldy v_instr,x
                lda v_pulselo,x         //If not, do the pulsewidth modulation,
                clc                     //decrement note duration counter,
                adc i_pulsespeed,y      //dump voice variables to SID and
                sta v_pulselo,x         //go to the next channel.
                lda v_pulsehi,x
                adc #$00
                sta v_pulsehi,x
play_deccounter:dec v_counter,x
                ldy v_regindex,x        //Get SID register index (0,7,14 for
                lda v_freqlo,x          //different voices)
                sta (temp3),y           //Frequency - Now Multi-SID compatible
                lda v_freqhi,x
                iny
                sta (temp3),y           //Now Multi-SID compatible
                lda v_pulselo,x
                iny
                sta (temp3),y           //Pulse - Now Multi-SID compatible
                lda v_pulsehi,x
                iny
                sta (temp3),y           //Now Multi-SID compatible
                lda v_waveform,x
                iny
                sta (temp3),y           //Waveform - Now Multi-SID compatible
                lda v_ad,x
                iny
                sta (temp3),y           //Attack/Decay - Now Multi-SID compatible
                lda v_sr,x
                iny
                sta (temp3),y           //Sustain/Release - Now Multi-SID compatible
play_nextvoice: inx                     //Loop until all 3 voices done
                cpx #$03
                bcc play_playloop
                rts

play_fetchnew:  lda v_ptrlo,x           //Put voice data pointer to zeropage
                sta temp1               //for indirect access
                lda v_ptrhi,x
                sta temp2
                ldy #$00                //Y register for indexing voice data
play_fetchloop: lda (temp1),y           //Get byte from voice data
                bpl play_fetchnote      //Nonnegative value = note
                iny                     //Increment index already here to avoid
                                        //having to do it twice
                cmp #$ff                //A jump command?
                bcc play_instrchange    //No, an instrument change
                lda (temp1),y           //Get lowbyte of jump address
                sta v_ptrlo,x
                iny
                lda (temp1),y           //Get highbyte of jump address and
                sta v_ptrhi,x           //go back to fetch loop hoping it isn't
                jmp play_fetchnew       //an endless loop :)
play_instrchange:
                and #$7f                //Clear the high bit and we have the
                sta v_instr,x           //instrument number
                jmp play_fetchloop
play_fetchnote: sta v_note,x            //Store note number
                iny
                lda (temp1),y           //Then get note duration
                sta v_counternew,x
                iny
                lda v_note,x            //Is it a "continue note"-command?
                cmp #CONTINUE           //If yes, skip the gatebit reset
                beq play_skipgatebit
                lda v_waveform,x
                and #$fe
                sta v_waveform,x
play_skipgatebit:
                tya                     //Now move the voice data pointer by
                clc                     //the amount of bytes that were
                adc temp1               //fetched
                sta v_ptrlo,x
                lda temp2
                adc #$00
                sta v_ptrhi,x
                jmp play_deccounter     //And go back to the loop (note: pulse
                                        //modulation is omitted to save some
                                        //time)

//-----------------------------------------------------------------------------
//-Voice variables for each voice                                              
//-----------------------------------------------------------------------------
v_regindex:     .byte 0,7,14             //SID register index
v_freqlo:       .byte 0,0,0              //Frequency lowbyte (ghost register)
v_freqhi:       .byte 0,0,0              //Frequency highbyte (ghost register)
v_pulselo:      .byte 0,0,0              //Pulse lowbyte (ghost register)
v_pulsehi:      .byte 0,0,0              //Pulse highbyte (ghost register)
v_waveform:     .byte 0,0,0              //Waveform (ghost register)
v_ad:           .byte 0,0,0              //Attack/Decay (ghost register)
v_sr:           .byte 0,0,0              //Sustain/Release (ghost register)
v_instr:        .byte 0,0,0              //Instrument number
v_note:         .byte 0,0,0              //Note number
v_counter:      .byte 0,0,0              //Note duration counter
v_counternew:   .byte 0,0,0              //Duration of new note
v_ptrlo:        .byte 0,0,0              //Voice data pointer lowbyte
v_ptrhi:        .byte 0,0,0              //Voice data pointer highbyte

//-----------------------------------------------------------------------------
//-Frequency tables (from GoatTracker playroutines)                            
//-----------------------------------------------------------------------------
freqtblhi:      
.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02
.byte $02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04
.byte $04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08
.byte $08,$09,$09,$0a,$0a,$0b,$0c,$0c,$0d,$0e,$0f,$10
.byte $11,$12,$13,$14,$15,$17,$18,$19,$1b,$1d,$1e,$20
.byte $22,$24,$26,$29,$2b,$2e,$30,$33,$36,$3a,$3d,$41
.byte $45,$49,$4d,$52,$57,$5c,$61,$67,$6d,$74,$7b,$82
.byte $8a,$92,$9b,$a4,$ae,$b8,$c3,$cf,$db,$e8,$f6,$ff

freqtbllo:
.byte $15,$25,$36,$49,$5c,$71,$87,$9f,$b7,$d1,$ed,$0a
.byte $2a,$4a,$6d,$92,$b9,$e3,$0f,$3e,$6f,$a3,$db,$15
.byte $54,$95,$db,$25,$73,$c7,$1e,$7c,$de,$47,$b6,$2b
.byte $a8,$2b,$b7,$4b,$e7,$8e,$3d,$f8,$bd,$8e,$6c,$57
.byte $50,$57,$6e,$96,$cf,$1c,$7b,$f0,$7b,$1d,$d8,$ae
.byte $a0,$af,$dd,$2d,$9f,$38,$f7,$e0,$f6,$3b,$b1,$5d
.byte $40,$5e,$bb,$5a,$3f,$70,$ef,$c1,$ed,$76,$63,$ba
.byte $80,$bc,$76,$b4,$7f,$e0,$de,$83,$da,$ed,$c7,$ff

//-----------------------------------------------------------------------------
//-Instrument data (each value sequentially for each instrument)               
//-----------------------------------------------------------------------------
i_pulselo:      .byte $00,$00,$00        //Pulse width lowbyte
i_pulsehi:      .byte $02,$00,$00        //Pulse width highbyte
i_pulsespeed:   .byte $20,$00,$00        //Pulse width speed
i_ad:           .byte $09,$58,$0a        //Attack/Decay
i_sr:           .byte $00,$aa,$00        //Sustain/Release
i_waveform:     .byte $41,$21,$11        //Waveform (must have gatebit on)

//-----------------------------------------------------------------------------
//-Song table (address of voice data start for each voice)                     
//-----------------------------------------------------------------------------
songtbl:
.word song0voice1
.word song0voice2
.word song0voice3
//More songs could be added here

//-----------------------------------------------------------------------------
//-Voice 1 data                                                                
//-----------------------------------------------------------------------------
song0voice1:    .byte INSTR+0            //Set instrument 0
                .byte A2,14              //Note/duration pairs
                .byte A2,14
                .byte A2,14
                .byte H2,7
                .byte C3,7
                .byte D3,14
                .byte D3,14
                .byte D3,14
                .byte C3,14
                .byte G2,14
                .byte G2,14
                .byte G2,14
                .byte A2,7
                .byte H2,7
                .byte C3,14
                .byte C3,14
                .byte C3,14
                .byte H2,14
                .byte F2,14
                .byte F2,14
                .byte F2,14
                .byte G2,7
                .byte A2,7
                .byte H2,14
                .byte H2,14
                .byte H2,14
                .byte A2,14
                .byte E2,14
                .byte E2,14
                .byte E2,14
                .byte E2,14
                .byte E2,7
                .byte F2,7
                .byte E2,7
                .byte D2,7
                .byte E2,7
                .byte F2,7
                .byte G2,7
                .byte H2,7
                .byte END                        //End command, followed by
                .word song0voice1                //restart address

//-----------------------------------------------------------------------------
//-Voice 2 data                                                                
//-----------------------------------------------------------------------------
song0voice2:    .byte INSTR+1                    //Set instrument 1
                .byte C4,7
                .byte REST,7                     //Rest also has a duration
                .byte C4,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte D4,7
                .byte C4,7
                .byte H3,7
                .byte A3,7
                .byte G3,7
                .byte A3,7
                .byte H3,7
                .byte C4,7
                .byte H3,7
                .byte REST,7
                .byte H3,7
                .byte REST,7
                .byte H3,7
                .byte REST,7
                .byte H3,7
                .byte REST,7
                .byte C4,7
                .byte H3,7
                .byte A3,7
                .byte G3,7
                .byte A3,7
                .byte H3,7
                .byte C4,7
                .byte D4,7
                .byte A3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte D4,7
                .byte C4,7
                .byte H3,7
                .byte A3,7
                .byte GIS3,7
                .byte FIS3,7
                .byte GIS3,7
                .byte A3,7
                .byte C4,42
                .byte H3,7
                .byte A3,7
                .byte H3,42
                .byte REST,14
                .byte E4,7
                .byte REST,7
                .byte C4,7
                .byte H3,7
                .byte C4,7
                .byte REST,7
                .byte A4,7
                .byte REST,7
                .byte A4,7
                .byte G4,7
                .byte F4,7
                .byte E4,7
                .byte D4,7
                .byte E4,7
                .byte F4,7
                .byte G4,7
                .byte D4,7
                .byte REST,7
                .byte G3,7
                .byte FIS3,7
                .byte G3,7
                .byte REST,7
                .byte F4,7
                .byte REST,7
                .byte F4,7
                .byte E4,7
                .byte D4,7
                .byte E4,7
                .byte C4,7
                .byte REST,7
                .byte E4,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte F3,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte DIS4,7
                .byte REST,7
                .byte A3,7
                .byte REST,7
                .byte C4,7
                .byte REST,7
                .byte DIS4,7
                .byte REST,7
                .byte E4,28
                .byte FIS4,28
                .byte GIS4,42
                .byte REST,14
                .byte END
                .word song0voice2

//-----------------------------------------------------------------------------
//-Voice 3 data                                                                
//-----------------------------------------------------------------------------
song0voice3:    .byte INSTR+2                    //Set instrument 2
                .byte A4,42
                .byte H4,7
                .byte C5,7
                .byte D5,56
                .byte G4,42
                .byte A4,7
                .byte H4,7
                .byte C5,56
                .byte F4,42
                .byte G4,7
                .byte A4,7
                .byte H4,56
                .byte E4,35
                .byte F4,7
                .byte E4,7
                .byte D4,7
                .byte E4,56
                .byte A4,42
                .byte H4,7
                .byte C5,7
                .byte D5,56
                .byte G4,42
                .byte A4,7
                .byte H4,7
                .byte C5,56
                .byte F4,42
                .byte G4,7
                .byte A4,7
                .byte H4,56
                .byte E4,35
                .byte A4,7
                .byte H4,7
                .byte C5,7
                .byte D5,56
                .byte END
                .word song0voice3

temp_vars:
.byte 0, 0, 0, 0

//-----------------------------------------------------------------------------
//-Tables below added for Multi-SID support
//-----------------------------------------------------------------------------
sid_address_lo:
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0
.byte $00, $20, $40, $60, $80, $a0, $c0, $e0

sid_address_hi:
.byte $d4, $d4, $d4, $d4, $d4, $d4, $d4, $d4
.byte $d5, $d5, $d5, $d5, $d5, $d5, $d5, $d5
.byte $d6, $d6, $d6, $d6, $d6, $d6, $d6, $d6
.byte $d7, $d7, $d7, $d7, $d7, $d7, $d7, $d7
.byte $de, $de, $de, $de, $de, $de, $de, $de
.byte $df, $df, $df, $df, $df, $df, $df, $df

sid_address_index:
.byte 0


// ----------------------------------------------
// Sprite data for text status 
// ----------------------------------------------
// [F3] TOGGLES MUSIC
// ----------------------------------------------
.pc = $2000 "Sprite Data"  // __[
SPR_STATUS1:
.byte   0,   0,  60,   0,   0,  48,   0,   0,  48,   0,   0,  48,   0,   0,  48,   0,   0,  48,   0,   0,  60

.pc = $2000 + 64*1  "Sprite" // 03]
.byte 126,  60,  60,  96, 102,  12,  96,   6,  12, 120,  28,  12,  96,   6,  12,  96, 102,  12,  96,  60,  60

.pc = $2000 + 64*2  "Sprite" // _TO
.byte 0, 126,  60,   0,  24, 102,   0,  24, 102,   0,  24, 102,   0,  24, 102,   0,  24, 102,   0,  24,  60

.pc = $2000 + 64*3  "Sprite" // GGL
.byte  60,  60,  96, 102, 102,  96,  96,  96,  96, 110, 110,  96, 102, 102,  96, 102, 102,  96,  60,  60, 126

.pc = $2000 + 64*4  "Sprite" // ES_
.byte 126,  60,   0,  96, 102,   0,  96,  96,   0, 120,  60,   0,  96,   6,   0,  96, 102,   0, 126,  60

.pc = $2000 + 64*5  "Sprite" // MUS
.byte  99, 102,  60, 119, 102, 102, 127, 102,  96, 107, 102,  60,  99, 102,   6,  99, 102, 102,  99,  60,  60

.pc = $2000 + 64*6  "Sprite" // IC_
.byte  60,  60,   0,  24, 102,   0,  24,  96,   0,  24,  96,   0,  24,  96,   0,  24, 102,   0,  60,  60

// ----------------------------------------------
// [F5/F6] TO SWITCH SID
// ----------------------------------------------
.pc = $2000 + 64*7  "Sprite" // [F5
SPR_STATUS2:
.byte  60, 126, 126,  48,  96,  96,  48,  96, 124,  48, 120,   6,  48,  96,   6,  48,  96, 102,  60,  96,  60

.pc = $2000 + 64*8  "Sprite" // /F6
.byte   0, 126,  60,   6,  96, 102,  12,  96,  96,  24, 120, 124,  48,  96, 102,  96,  96, 102,  192,  96,  60

.pc = $2000 + 64*9  "Sprite" // ]_T
.byte  60,   0, 126,  12,   0,  24,  12,   0,  24,  12,   0,  24,  12,   0,  24,  12,   0,  24,  60,   0,  24

.pc = $2000 + 64*10 "Sprite" // O_S
.byte  60,   0,  60, 102,   0, 102, 102,   0,  96, 102,   0,  60, 102,   0,   6, 102,   0, 102,  60,   0,  60

.pc = $2000 + 64*11 "Sprite" // WIT
.byte  99,  60, 126,  99,  24,  24,  99,  24,  24, 107,  24,  24, 127,  24,  24, 119,  24,  24,  99,  60,  24

.pc = $2000 + 64*12 "Sprite" // CH_
.byte  60, 102,   0, 102, 102,   0,  96, 102,   0,  96, 126,   0,  96, 102,   0, 102, 102,   0,  60, 102

.pc = $2000 + 64*13 "Sprite" // SID
.byte  60,  60, 120, 102,  24, 108,  96,  24, 102,  60,  24, 102,   6,  24, 102, 102,  24, 108,  60,  60, 120

// ----------------------------------------------
// [F7] CLEARS THE GRID
// ----------------------------------------------
.pc = $2000 + 64*14 "Sprite" // [F7
SPR_STATUS3:
.byte  60, 126, 126,  48,  96, 102,  48,  96,  12,  48, 120,  24,  48,  96,  24,  48,  96,  24,  60,  96,  24

.pc = $2000 + 64*15 "Sprite" // ]_C
.byte  60,   0,  60,  12,   0, 102,  12,   0,  96,  12,   0,  96,  12,   0,  96,  12,   0, 102,  60,   0,  60

.pc = $2000 + 64*16 "Sprite" // LEA
.byte  96, 126,  24,  96,  96,  60,  96,  96, 102,  96, 120, 126,  96,  96, 102,  96,  96, 102, 126, 126, 102

.pc = $2000 + 64*17 "Sprite" // RS_
.byte 124,  60,   0, 102, 102,   0, 102,  96,   0, 124,  60,   0, 120,   6,   0, 108, 102,   0, 102,  60

.pc = $2000 + 64*18 "Sprite" // THE
.byte 126, 102, 126,  24, 102,  96,  24, 102,  96,  24, 126, 120,  24, 102,  96,  24, 102,  96,  24, 102, 126

.pc = $2000 + 64*19 "Sprite" // _GR
.byte  0, 60, 124,   0, 102, 102,   0,  96, 102,   0, 110, 124,   0, 102, 120,   0, 102, 108,   0,  60, 102

.pc = $2000 + 64*20 "Sprite" // ID_
.byte  60, 120,   0,  24, 108,   0,  24, 102,   0,  24, 102,   0,  24, 102,   0,  24, 108,   0,  60, 120

// ----------------------------------------------
// ACTIVE SID ON:  $D___
// ----------------------------------------------
.pc = $2000 + 64*21 "Sprite" // ACT
SPR_STATUS4:
.byte  24,  60, 126,  60, 102,  24, 102,  96,  24, 126,  96,  24, 102,  96,  24, 102, 102,  24, 102,  60,  24

.pc = $2000 + 64*22 "Sprite" // IVE
.byte  60, 102, 126,  24, 102,  96,  24, 102,  96,  24, 102, 120,  24, 102,  96,  24,  60,  96,  60,  24, 126

.pc = $2000 + 64*23 "Sprite" // _SI
.byte  0, 60,  60,   0, 102,  24,   0,  96,  24,   0,  60,  24,   0,   6,  24,   0, 102,  24,   0,  60,  60

.pc = $2000 + 64*24 "Sprite" // D_O
.byte  120,   0,  60, 108,   0, 102, 102,   0, 102, 102,   0, 102, 102,   0, 102, 108,   0, 102, 120,   0,  60

.pc = $2000 + 64*25 "Sprite" // N:_
.byte  102,   0,   0, 118,   0,   0, 126,  24,   0, 126,   0,   0, 110,   0,   0, 102,  24,   0, 102

.pc = $2000 + 64*26 "Sprite" // _$D
.byte    0,  24, 120,   0,  62, 108,   0,  96, 102,   0,  60, 102,   0,   6, 102,   0, 124, 108,   0,  24, 120

// ----------------------------------------------
// MOVE - CURSORS / JOY2
// ----------------------------------------------
.pc = $2000 + 64*27 "Sprite" // MOV
SPR_STATUS5:
.byte 99, 60, 102, 119, 102, 102, 127, 102, 102, 107, 102, 102, 99, 102, 102, 99, 102, 60, 99, 60, 24

.pc = $2000 + 64*28 "Sprite" // E_-
.byte 126, 0, 0, 96, 0, 0, 96, 0, 0, 120, 0, 126, 96, 0, 0, 96, 0, 0, 126

.pc = $2000 + 64*29 "Sprite" // _CU
.byte 0, 60, 102, 0, 102, 102, 0, 96, 102, 0, 96, 102, 0, 96, 102, 0, 102, 102, 0, 60, 60

.pc = $2000 + 64*30 "Sprite" // RSO
.byte 124, 60, 60, 102, 102, 102, 102, 96, 102, 124, 60, 102, 120, 6, 102, 108, 102, 102, 102, 60, 60

.pc = $2000 + 64*31 "Sprite" // ORS
.byte 124, 60, 0, 102, 102, 0, 102, 96, 0, 124, 60, 0, 120, 6, 0, 108, 102, 0, 102, 60

.pc = $2000 + 64*32 "Sprite" // /_J
.byte 0, 0, 30, 3, 0, 12, 6, 0, 12, 12, 0, 12, 24, 0, 12, 48, 0, 108, 96, 0, 56

.pc = $2000 + 64*33 "Sprite" // OY2
.byte 60, 102, 60, 102, 102, 102, 102, 102, 6, 102, 60, 12, 102, 24, 48, 102, 24, 96, 60, 24, 126


// ----------------------------------------------
// SELECT - SPACE / FIRE
// ----------------------------------------------
.pc = $2000 + 64*34 "Sprite" // SEL
SPR_STATUS6:
.byte 60, 126, 96, 102, 96, 96, 96, 96, 96, 60, 120, 96, 6, 96, 96, 102, 96, 96, 60, 126, 126

.pc = $2000 + 64*35 "Sprite" // ECT
.byte 126, 60, 126, 96, 102, 24, 96, 96, 24, 120, 96, 24, 96, 96, 24, 96, 102, 24, 126, 60, 24

.pc = $2000 + 64*36 "Sprite" // _/_
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 126, 0, 0, 0, 0, 0, 0, 0

.pc = $2000 + 64*37 "Sprite" // SPA
.byte 60, 124, 24, 102, 102, 60, 96, 102, 102, 60, 124, 126, 6, 96, 102, 102, 96, 102, 60, 96, 102

.pc = $2000 + 64*38 "Sprite" // CE_
.byte 60, 126, 0, 102, 96, 0, 96, 96, 0, 96, 120, 0, 96, 96, 0, 102, 96, 0, 60, 126

.pc = $2000 + 64*39 "Sprite" // /_F
.byte 3, 0, 126, 6, 0, 96, 12, 0, 96, 24, 0, 120, 48, 0, 96, 96, 0, 96, 0, 0, 96

.pc = $2000 + 64*40 "Sprite" // IRE
.byte 60, 124, 126, 24, 102, 96, 24, 102, 96, 24, 124, 120, 24, 120, 96, 24, 108, 96, 60, 102, 126


// ----------------------------------------------
// 400 - FE0
// ----------------------------------------------
.pc = $2000 + 64*41 "Sprite" // 400
SPR_SIDADDR:
.byte    6, 60, 60, 14, 102, 102, 30, 110, 110, 102, 118, 118, 127, 102, 102, 6, 102, 102, 6, 60, 60

.pc = $2000 + 64*42 "Sprite" // 420
.byte    6, 60, 60, 14, 102, 102, 30, 6, 110, 102, 12, 118, 127, 48, 102, 6, 96, 102, 6, 126, 60

.pc = $2000 + 64*43 "Sprite" // 440
.byte    6, 6, 60, 14, 14, 102, 30, 30, 110, 102, 102, 118, 127, 127, 102, 6, 6, 102, 6, 6, 60

.pc = $2000 + 64*44 "Sprite" // 460
.byte    6, 60, 60, 14, 102, 102, 30, 96, 110, 102, 124, 118, 127, 102, 102, 6, 102, 102, 6, 60, 60

.pc = $2000 + 64*45 "Sprite" // 480
.byte    6, 60, 60, 14, 102, 102, 30, 102, 110, 102, 60, 118, 127, 102, 102, 6, 102, 102, 6, 60, 60

.pc = $2000 + 64*46 "Sprite" // 4A0
.byte    6, 24, 60, 14, 60, 102, 30, 102, 110, 102, 126, 118, 127, 102, 102, 6, 102, 102, 6, 102, 60

.pc = $2000 + 64*47 "Sprite" // 4C0
.byte    6, 60, 60, 14, 102, 102, 30, 96, 110, 102, 96, 118, 127, 96, 102, 6, 102, 102, 6, 60, 60

.pc = $2000 + 64*48 "Sprite" // 4E0
.byte    6, 126, 60, 14, 96, 102, 30, 96, 110, 102, 120, 118, 127, 96, 102, 6, 96, 102, 6, 126, 60

.pc = $2000 + 64*49 "Sprite" // 500
.byte  126, 60, 60, 96, 102, 102, 124, 110, 110, 6, 118, 118, 6, 102, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*50 "Sprite" // 520
.byte  126, 60, 60, 96, 102, 102, 124, 6, 110, 6, 12, 118, 6, 48, 102, 102, 96, 102, 60, 126, 60

.pc = $2000 + 64*51 "Sprite" // 540
.byte  126, 6, 60, 96, 14, 102, 124, 30, 110, 6, 102, 118, 6, 127, 102, 102, 6, 102, 60, 6, 60

.pc = $2000 + 64*52 "Sprite" // 560
.byte  126, 60, 60, 96, 102, 102, 124, 96, 110, 6, 124, 118, 6, 102, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*53 "Sprite" // 580
.byte  126, 60, 60, 96, 102, 102, 124, 102, 110, 6, 60, 118, 6, 102, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*54 "Sprite" // 5A0
.byte  126, 24, 60, 96, 60, 102, 124, 102, 110, 6, 126, 118, 6, 102, 102, 102, 102, 102, 60, 102, 60

.pc = $2000 + 64*55 "Sprite" // 5C0
.byte  126, 60, 60, 96, 102, 102, 124, 96, 110, 6, 96, 118, 6, 96, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*56 "Sprite" // 5E0
.byte  126, 126, 60, 96, 96, 102, 124, 96, 110, 6, 120, 118, 6, 96, 102, 102, 96, 102, 60, 126, 60

.pc = $2000 + 64*57 "Sprite" // 600
.byte   60, 60, 60, 102, 102, 102, 96, 110, 110, 124, 118, 118, 102, 102, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*58 "Sprite" // 620
.byte   60, 60, 60, 102, 102, 102, 96, 6, 110, 124, 12, 118, 102, 48, 102, 102, 96, 102, 60, 126, 60

.pc = $2000 + 64*59 "Sprite" // 640
.byte   60, 6, 60, 102, 14, 102, 96, 30, 110, 124, 102, 118, 102, 127, 102, 102, 6, 102, 60, 6, 60

.pc = $2000 + 64*60 "Sprite" // 660
.byte   60, 60, 60, 102, 102, 102, 96, 96, 110, 124, 124, 118, 102, 102, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*61 "Sprite" // 680
.byte   60, 60, 60, 102, 102, 102, 96, 102, 110, 124, 60, 118, 102, 102, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*62 "Sprite" // 6A0
.byte   60, 24, 60, 102, 60, 102, 96, 102, 110, 124, 126, 118, 102, 102, 102, 102, 102, 102, 60, 102, 60

.pc = $2000 + 64*63 "Sprite" // 6C0
.byte   60, 60, 60, 102, 102, 102, 96, 96, 110, 124, 96, 118, 102, 96, 102, 102, 102, 102, 60, 60, 60

.pc = $2000 + 64*64 "Sprite" // 6E0
.byte   60, 126, 60, 102, 96, 102, 96, 96, 110, 124, 120, 118, 102, 96, 102, 102, 96, 102, 60, 126, 60

.pc = $2000 + 64*65 "Sprite" // 700
.byte  126, 60, 60, 102, 102, 102, 12, 110, 110, 24, 118, 118, 24, 102, 102, 24, 102, 102, 24, 60, 60

.pc = $2000 + 64*66 "Sprite" // 720
.byte  126, 60, 60, 102, 102, 102, 12, 6, 110, 24, 12, 118, 24, 48, 102, 24, 96, 102, 24, 126, 60

.pc = $2000 + 64*67 "Sprite" // 740
.byte  126, 6, 60, 102, 14, 102, 12, 30, 110, 24, 102, 118, 24, 127, 102, 24, 6, 102, 24, 6, 60

.pc = $2000 + 64*68 "Sprite" // 760
.byte  126, 60, 60, 102, 102, 102, 12, 96, 110, 24, 124, 118, 24, 102, 102, 24, 102, 102, 24, 60, 60

.pc = $2000 + 64*69 "Sprite" // 780
.byte  126, 60, 60, 102, 102, 102, 12, 102, 110, 24, 60, 118, 24, 102, 102, 24, 102, 102, 24, 60, 60

.pc = $2000 + 64*70 "Sprite" // 7A0
.byte  126, 24, 60, 102, 60, 102, 12, 102, 110, 24, 126, 118, 24, 102, 102, 24, 102, 102, 24, 102, 60

.pc = $2000 + 64*71 "Sprite" // 7C0
.byte  126, 60, 60, 102, 102, 102, 12, 96, 110, 24, 96, 118, 24, 96, 102, 24, 102, 102, 24, 60, 60

.pc = $2000 + 64*72 "Sprite" // 7E0
.byte  126, 126, 60, 102, 96, 102, 12, 96, 110, 24, 120, 118, 24, 96, 102, 24, 96, 102, 24, 126, 60

.pc = $2000 + 64*73 "Sprite" // E00
.byte  126, 60, 60, 96, 102, 102, 96, 110, 110, 120, 118, 118, 96, 102, 102, 96, 102, 102, 126, 60, 60

.pc = $2000 + 64*74 "Sprite" // E20
.byte  126, 60, 60, 96, 102, 102, 96, 6, 110, 120, 12, 118, 96, 48, 102, 96, 96, 102, 126, 126, 60

.pc = $2000 + 64*75 "Sprite" // E40
.byte  126, 6, 60, 96, 14, 102, 96, 30, 110, 120, 102, 118, 96, 127, 102, 96, 6, 102, 126, 6, 60

.pc = $2000 + 64*76 "Sprite" // E60
.byte  126, 60, 60, 96, 102, 102, 96, 96, 110, 120, 124, 118, 96, 102, 102, 96, 102, 102, 126, 60, 60

.pc = $2000 + 64*77 "Sprite" // E80
.byte  126, 60, 60, 96, 102, 102, 96, 102, 110, 120, 60, 118, 96, 102, 102, 96, 102, 102, 126, 60, 60

.pc = $2000 + 64*78 "Sprite" // EA0
.byte  126, 24, 60, 96, 60, 102, 96, 102, 110, 120, 126, 118, 96, 102, 102, 96, 102, 102, 126, 102, 60

.pc = $2000 + 64*79 "Sprite" // EC0
.byte  126, 60, 60, 96, 102, 102, 96, 96, 110, 120, 96, 118, 96, 96, 102, 96, 102, 102, 126, 60, 60

.pc = $2000 + 64*80 "Sprite" // EE0
.byte  126, 126, 60, 96, 96, 102, 96, 96, 110, 120, 120, 118, 96, 96, 102, 96, 96, 102, 126, 126, 60

.pc = $2000 + 64*81 "Sprite" // F00
.byte  126, 60, 60, 96, 102, 102, 96, 110, 110, 120, 118, 118, 96, 102, 102, 96, 102, 102, 96, 60, 60

.pc = $2000 + 64*82 "Sprite" // F20
.byte  126, 60, 60, 96, 102, 102, 96, 6, 110, 120, 12, 118, 96, 48, 102, 96, 96, 102, 96, 126, 60

.pc = $2000 + 64*83 "Sprite" // F40
.byte  126, 6, 60, 96, 14, 102, 96, 30, 110, 120, 102, 118, 96, 127, 102, 96, 6, 102, 96, 6, 60

.pc = $2000 + 64*84 "Sprite" // F60
.byte  126, 60, 60, 96, 102, 102, 96, 96, 110, 120, 124, 118, 96, 102, 102, 96, 102, 102, 96, 60, 60

.pc = $2000 + 64*85 "Sprite" // F80
.byte  126, 60, 60, 96, 102, 102, 96, 102, 110, 120, 60, 118, 96, 102, 102, 96, 102, 102, 96, 60, 60

.pc = $2000 + 64*86 "Sprite" // FA0
.byte  126, 24, 60, 96, 60, 102, 96, 102, 110, 120, 126, 118, 96, 102, 102, 96, 102, 102, 96, 102, 60

.pc = $2000 + 64*87 "Sprite" // FC0
.byte  126, 60, 60, 96, 102, 102, 96, 96, 110, 120, 96, 118, 96, 96, 102, 96, 102, 102, 96, 60, 60

.pc = $2000 + 64*88 "Sprite" // FE0
.byte  126, 126, 60, 96, 96, 102, 96, 96, 110, 120, 120, 118, 96, 96, 102, 96, 96, 102, 96, 126, 60

.pc = $2000 + 64*89 "Sprite" // GRID SELECTION BLOCK
SPR_GRID_BLOCK: 
.byte 252, 0, 0, 252, 0, 0, 252, 0, 0, 252, 0, 0, 252, 0, 0, 252

.pc = $2000 + 64*90 "Sprite" // Empty Sprite
SPR_EMPTY:
.byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0


//----------------------------------------------------------------------
// Character Screen Data
//----------------------------------------------------------------------
.pc = $4000 "Grid Selector Characters"
MAIN_SCREEN_DATA:

.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 13, 21, 12, 20,  9, 45, 19,  9,  4, 32, 20,  5, 19, 20,  5, 18, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 27,  6, 49, 29, 32,  6, 15, 18, 32, 16, 18, 15, 10,  5,  3, 20, 32,  9, 14,  6, 15, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,112, 67, 67,114, 67, 67,114, 67, 67,114, 67, 67,114, 67, 67,114, 67, 67,114, 67, 67,114, 67, 67,110, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 66, 48, 48, 66, 50, 48, 66, 52, 48, 66, 54, 48, 66, 56, 48, 66,  1, 48, 66,  3, 48, 66,  5, 48, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,107, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67,115, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32,  4, 52, 48, 48, 32, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,107, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67,115, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32,  4, 53, 48, 48, 32, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,107, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67,115, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32,  4, 54, 48, 48, 32, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,107, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67,115, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32,  4, 55, 48, 48, 32, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,107, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67,115, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32,  4,  5, 48, 48, 32, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,107, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67, 91, 67, 67,115, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 93,112,110, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32,  4,  6, 48, 48, 32, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66,109,125, 66, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32,109, 67, 67,113, 67, 67,113, 67, 67,113, 67, 67,113, 67, 67,113, 67, 67,113, 67, 67,113, 67, 67,125, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32

.pc = $4400 "Grid Selector Colors"
MAIN_COLOR_DATA:

.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 14,  1,  1,  1,  1,  1,  1,  1,  1,  1, 14, 14, 14, 14, 14, 14, 14, 14
.byte   1,  1,  1, 14,  1,  1,  1,  1,  1,  1,  1,  2,  1,  1,  2,  1,  2,  2,  2,  1,  2,  2,  2,  2,  2,  2,  2,  1,  2,  2,  2,  2,  1,  1,  1,  1,  1,  1, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12,  1,  1, 12,  1,  1, 12,  1,  1, 12,  1,  1, 12,  1,  1, 12,  1,  1, 12,  1,  1, 12,  1,  1, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  1,  1,  1,  1, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  1,  1,  1,  1, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  1,  1,  1,  1, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  1,  1,  1,  1, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  1,  1,  1,  1, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  1,  1,  1,  1, 14, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 15, 15, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14




.pc = $4800 "Command Menu Characters"
MENU_SCREEN_DATA:

.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 13, 21, 12, 20,  9, 45, 19,  9,  4, 32, 20,  5, 19, 20,  5, 18, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte 108, 32,  1, 32, 19,  9, 13, 16, 12,  5, 32, 21, 20,  9, 12,  9, 20, 25, 32, 20, 15, 32, 20,  5, 19, 20, 32, 19,  9,  4, 19, 32,  1,  3, 18, 15, 19, 19, 32, 32
.byte  32, 32, 23,  9,  4,  5, 32, 18,  1, 14,  7,  5, 32, 15,  6, 32, 16, 15, 19, 19,  9,  2, 12,  5, 32,  1,  4,  4, 18,  5, 19, 19,  5, 19, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte 108, 32,  3, 21, 18, 19, 15, 18, 32, 11,  5, 25, 19, 32, 15, 18, 32,  1, 32, 10, 15, 25, 19, 20,  9,  3, 11, 32,  9, 14, 32, 16, 15, 18, 20, 32, 50, 32, 32, 32
.byte  32, 32, 20, 15, 32, 14,  1, 22,  9,  7,  1, 20,  5, 32, 20,  8,  5, 32,  7, 18,  9,  4, 32,  1, 14,  4, 32, 19,  5, 12,  5,  3, 20, 32,  1, 32, 19,  9,  4, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte 108, 32, 19, 16,  1,  3,  5, 32,  2,  1, 18, 32, 15, 18, 32, 10, 15, 25, 19, 20,  9,  3, 11, 32,  6,  9, 18,  5, 32,  2, 21, 20, 20, 15, 14, 32, 20, 15, 32, 32
.byte  32, 32, 20, 15,  7,  7, 12,  5, 32, 13, 21, 19,  9,  3, 32, 15, 14, 32, 47, 32, 15,  6,  6, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte 108, 32, 13, 21, 19,  9,  3, 32, 16, 12,  1, 25,  5, 18, 32,  2, 25, 58, 32,  3,  1,  4,  1, 22,  5, 18, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 13, 21, 12, 20,  9, 45, 19,  9,  4, 32,  1,  4,  4, 18,  5, 19, 19,  9, 14,  7, 32,  2, 25, 58, 32,  4, 23,  5, 19, 20,  2, 21, 18, 25, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 27,  6, 49, 29, 32, 15, 18, 32, 19, 16,  1,  3,  5, 32, 18,  5, 20, 21, 18, 14, 19, 32, 20, 15, 32,  7, 18,  9,  4, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32
.byte  32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32

.pc = $4C00 "Command Menu Colors"
MENU_COLOR_DATA:

.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,  1,  1,  1,  1,  1,  1,  1,  1,  1, 14,  1,  1,  1,  1,  1,  1, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  12, 14,  2, 14,  2,  2,  2,  2,  2,  2, 14,  2,  2,  2,  2,  2,  2,  2, 14,  2,  2, 14,  1,  1,  1,  1, 14,  1,  1,  1,  1, 14,  2,  2,  2,  2,  2,  2, 14, 14
.byte  12, 14,  2,  2,  2,  2, 14,  2,  2,  2,  2,  2, 14,  2,  2, 14,  2,  2,  2,  2,  2,  2,  2,  2, 14,  2,  2,  2,  2,  2,  2,  2,  2,  2, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  12, 14,  1,  1,  1,  1,  1,  1, 14,  1,  1,  1,  1, 14,  2,  2, 14,  2, 14,  1,  1,  1,  1,  1,  1,  1,  1, 14,  2,  2, 14,  1,  1,  1,  1, 14,  1, 14, 14, 14
.byte  14, 14,  2,  2, 14,  2,  2,  2,  2,  2,  2,  2,  2, 14,  2,  2,  2, 14,  2,  2,  2,  2, 14,  2,  2,  2, 14,  2,  2,  2,  2,  2,  2, 14,  2, 14,  2,  2,  2, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  12, 14,  1,  1,  1,  1,  1, 14,  1,  1,  1, 14,  2,  2, 14,  1,  1,  1,  1,  1,  1,  1,  1, 14,  1,  1,  1,  1, 14,  2,  2,  2,  2,  2,  2, 14,  2,  2, 14, 14
.byte  14, 14,  2,  2,  2,  2,  2,  2, 14,  1,  1,  1,  1,  1, 14,  1,  1, 14,  2, 14,  1,  1,  1, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  12, 14,  2,  2,  2,  2,  2, 14,  2,  2,  2,  2,  2,  2, 14,  2,  2,  2, 14,  1,  1,  1,  1,  1,  1,  1, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14,  2,  2,  2,  2,  2,  2,  2,  2,  2, 14,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2, 14,  2,  2,  2, 14,  1,  1,  1,  1,  1,  1,  1,  1,  1, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14,  2,  1,  1,  2, 14,  2,  2, 14,  1,  1,  1,  1,  1, 14,  2,  2,  2,  2,  2,  2,  2, 14,  2,  2, 14,  2,  2,  2,  2, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
.byte  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14
