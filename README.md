# TFS1
Super-lightweight, custom file system for my 65C02 computer.

I ran into an issue where I was able to generate programs on the computer itself using TFORTH, but was not able to save them anywhere. I wired up a SD card module to port A of the VIA and wrote routines into MON3 monitor to interface with the SD card controller. 

Unfortunately, arguably the simplest file system still supported on modern computers is FAT-12. The internal calculations required for navigating the file system seemed unnecessary to me. The programs on my computer are only ever able to be less than 32K in size. The level of overhead to implement FAT-12 just seemed wasteful.

Thus, TFS was born. It’s about as simple as a file system can possibly be:

* Sector 1 is the PROPERTIES sector. It contains the metadata of the entire file system. There is only ever one PROPERTIES sector.

* Sector 2 to N is the first ROOT sector. This is similar to a C array of structs, which contain the location, name, status, and size of the file. Each entry is exactly 16-bytes, so a linked-list is not needed. There can be an adjustable number of ROOT sectors. Default number of ROOT sectors is 1, thus (because by SD specifications, each sector = 512 bytes) the default maximum number of files is 32. 

* Sectors N+1 and beyond are the sectors within the file clusters.

Note that all files stored are a FIXED SIZE (mostly to aid in calculation). Every file is assigned exactly 1 cluster (made up of N sectors), regardless of the actual file size. So, to prevent the computer from loading the entire cluster, a field in the ROOT sector is used to tell the computer how many sectors the file uses within the cluster. 

This files system is only useful for this specific computer. The design goals for it were to minimize the number of calculation time needed to locate files. Because of the fixed size of the files, the lookup process can be done very quickly. 

(See the prototype/main.c for the specific structure of the file system). 
