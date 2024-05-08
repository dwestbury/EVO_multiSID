# MultiSID Tester  
## A simple utility to test SIDs listening on different addresses  

By: **Darrell Westbury**  
Version: 0.9 (Beta)  
Preview Release: May 8th 2024   

## Background:
This is the first Assembly Language code I've written since 1992.  
It's been a blast rolling the sleeves up again, but I'm 'clearly' a bit rusty (cough)  

## Usage:
* This tool is intended for [**EVO64**](https://evo64.com) users, to enable them to test which address(es) their SIDs are responding on.
* However, there's nothing preventing you from using this tool with other Multi-SID enabled C64 system.
* I'm hoping that the simple Grid-based navigation system makes it easy, intuitive and straight forward to use this tool.
* There's an info page available to explain the controls, although they should me mostly self-explanatory.  

## Credits:
When I was looking for a Music Player routine that I could modify easily to support multiple SID addresses,
I was thrilled to find some code by **Cadaver** that just what the Doctor ordered.
https://cadaver.github.io/rants/music.html


## Other great tools I used include:
* KickAssembler: http://theweb.dk/KickAssembler/Main.html
* VICE: https://vice-emu.sourceforge.io/
* Ultimate II+ Cartridge: https://www.ultimate64.com/
* EVO64: https://www.evo64.com/
* PETSCII Editor: https://petscii.krissz.hu/

## Considerations:
* This is an early work in progress, and I'm sure there are many bugs and opportunities for improvements to be made.
* You will experience instability if you're using a cartridge like RetroReplay and tryin to use SIDs addressing in the $DE00-$DFE0 range.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.  
  
    
## Grid Navigation & SID Selection Page  

![Example Image](images/Grid%20Navigation%20Screen.png "Grid Navigation and SID Selection Page")

## Usage and Info Page
![Example Image](images/Usage%20and%20Info%20Screen.png "Usage and Info Page")
