# GruniozercaGB

## About
This is an port of the Gruniozerca game for the GameBoy. The original game has been released in 2016 as a support for a Polish 24h charity stream [Gramytatywnie](https://gramytatywnie.pl/) for Famicom/Nintendo Entertainment System by Łukasz Kur and Ryszard Brzukała.

## Warning
As the author couldn't play on the real hardware, the game has been tested on the following emulators:
- [bgb](http://bgb.bircd.org/)
- [Gambette](https://sourceforge.net/projects/gambatte/files/gambatte/)
- VisualBoyAdvance

## Rules
Match the colour of the guinea pig to the falling carrot and catch the vegetable. You can miss 3 times, miss 4th time and it's game over! Use d-pad to move the guinea pig left and right and press A to change the colour.

## Compiling
To compile the source code you will need:
- Rednex Game Boy Development System ([source](https://github.com/rednex/rgbds) / [binaries](https://github.com/rednex/rgbds/releases))
- [GameBoy Hardware Definitions](https://github.com/gbdev/hardware.inc/blob/master/hardware.inc)

To compile in Windows place the definitions and the asm file in the same folder as the development system and in the command line write:
```
rgbasm.exe -o Gruniozerca.obj Gruniozerca.asm
rgblink.exe -o Gruniozerca.gb Gruniozerca.obj
rgbfix.exe -p0 -v Gruniozerca.gb
```

## Special thanks
- The [Arhn.eu](https://arhn.eu/) Team
- H. Mulder for the great tools: [GameBoy Tile Designer](http://www.devrs.com/gb/hmgd/gbtd.html) and [GameBoy Map Builder](http://www.devrs.com/gb/hmgd/gbmb.html)
- Pan of Anthrox, GABY,  Marat Fayzullin, Pascal Felber, Paul Robson, Martin Korth, kOOPa, Bowser for their amazing [manual](http://marc.rawer.de/Gameboy/index.html)
- Bas Steendijk, the bgb author for amazing debugging tools
- Rednex for simple in use tools
