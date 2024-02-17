This is a portable relocatable kernel for the ProDOS :tm: filesystem.
It's adapated from the v2.0.3 source code found at https://github.com/markpmlim/ProDOS8.
This was the last version published by Apple in 1993, identifying as `version=$23`.
Unfortunately the source for the more recent [ProDOS 2.4](https://prodos8.com/)
doesn't appear to be publicly available at this time.
The notice in the original code appeared as:

    ProDOS 8 V2.0.3      06-May-93
    Copyright Apple Computer, Inc., 1983-93
    All Rights Reserved.

The work here is purely for my own education
and not intended for any commerical use.
As a long-ago Apple //e owner and user of ProDOS it's been fun working
to understand more about how it worked and resurrect some of it
on a 65c02-based breadboard computer.

The original ProDOS was a full operating system targeted at early Apple hardware
platforms, including bootloader, display IO and hardware-specific device drivers.
However it contains a core filesystem with a machine language interface (MLI)
which are both [well documented](https://prodos8.com/docs/techref/) and not Apple-specific.
Conveniently, ProDOS also abstracts all IO via a simple block device driver API.
This makes it easy to plug in arbitrary storage devices like RAM disks or SD cards.
Drivers simply read (and optionally write) sequentially numbered
512 byte blocks from their storage.

This slimmed down build contains just that filesystem and MLI implementation
in an easily relocatable form with no specific hardware dependencies.
It requires a little under 8K ROM, 2K RAM and 10 zeropage bytes (normally at $40-4F).
For maximum flexibility it's a "bring your own" driver platform
which provides a well-tested, feature-rich filesystem for 65c02 platforms.

The example in `demo.s` shows how to interact with the MLI using a simple
RAM disk device driver hosting a (very small!) standard ProDOS disk image.
Using an SD card device driver would provide up to 14 x 32Mb volumes, or nearly
half a gigabyte of read/write file storage.

All of the documented MLI is supported except for `[ALLOC|DEALLOC]_INTERRUPT`.
See the [quick reference](https://prodos8.com/docs/techref/quick-reference-card/).

Building the demo
---

The Merlin assembler code was ported to [cc65](https://cc65.github.io/) where
it can be compiled as a relocatable object `p8fs.o` like this:

    cl65 -c -g --verbose --target none  -l p8fs.lst -o p8fs.o p8fs.s

The object requires one external symbol `ClockDriver` which can be set
to the imported `NoClock` or just pointed at a known `rts` instruction.

To use the filesystem kernel, you should call `InitMLI`,
register at least one device with `RegisterMLI`,
reserve memory for your own code with `ReserveMLI`,
and then interact with the ProDOS MLI using `GoMLI`.
See `demo.s` with some simple examples interacting with a RAM-disk driver:

    cl65 -g --verbose --target none --config demo.cfg -m demo.map -Ln demo.sym -o demo.bin p8fs.o demo.s

You can run the demo in a simulator like [py65](https://github.com/mnaberez/py65).
My [fork of py65](https://github.com/patricksurry/py65)
has a few improvements (imho).
Build the ROM image `demo.bin` and run like this:

    ; prepare labels for py65
    sed 's/\.//' demo.sym > /tmp/labels

    py65mon -m 65c02 -l demo.bin -a c000

    . batch /tmp/labels     ; import symbols
    . load demovol.po $400  ; load disk image with block 2 @ $800
    . goto test_start

This should run through a few tests and then show the opening lines of
[The Hitchhikers Guide](https://en.wikipedia.org/wiki/The_Hitchhiker%27s_Guide_to_the_Galaxy)
read from the RAM disk:

    GET_DATE_TIME OK
    ONLINE OK
    SET_PREFIX OK
    OPEN OK
    READ OK
    Far out in the uncharted backwaters of the unfashionable  end  of
    the  western  spiral  arm  of  the Galaxy lies a small unregarded
    yellow sun.
    ...

There are many tools to create and manage ProDOS volumes as disk images.
I wrote my own [pyprodos](https://github.com/patricksurry/pyprodos)
as a way to better understand the filesystem spec. I created the demo
volume like this:

    % prodos demovol.po create --size 10 --name DEMOVOL
    % prodos demovol.po import hhg.txt README
    % prodos demovol.po ls

    README                  893 2/00 ------ 24-02-03T08:59 24-02-03T08:59 3 @ 7
        1 files in DEMOVOL F RW-BN- 24-02-03T08:59

Memory map
---

The original ProDOS had a global page at $BF00 with code living in
banked memory beyond the $C000 I/O area.
This implementation is easily relocatable via the `p8fs.cfg` file.
The source is divided into four relocatable
segments, `ZP`, `CODE`, `DATA` and `DEMO`.  `CODE` and `DEMO` (about 8K) can live in ROM,
and `DATA` (2K) should be mapped to RAM.  Note that `ZP`(16 bytes) and `DATA` are not emitted
in the output `p8fs.bin` image but are instead initialized by the `InitMLI` routine.

ProDOS uses a simple memory mapping scheme to track free RAM pages in the lower 48K of memory.
This is used for buffer management so its important to flag any pages needed for your
code (including `DATA` if mapped below $C000)
after calling `InitMLI` but before any `GoMLI` call.
The default initialization only reserves page 0 and 1 (zero page and stack).
For example an MLI `OPEN` call checks that the IO buffer parameter points to free memory
which it then reserves.

Notes
---

A couple of lines in the [original code](https://github.com/markpmlim/ProDOS8/blob/a292fcb62ae866753f6dc461809a0f77b33e0cea/MLI.SRC/NEWFNDVOL.S#L24) were written like
`LDA |blockNum,Y`.  I'm not sure what the `|` signified, and removed it.

I removed what seemed like a spurious `ORA #$80` in [bfmgr.s](https://github.com/patricksurry/p8fs/blob/main/bfmgr.s#L69) which appeared to force the absolute path check to always fail.
Maybe this was an unexercised path with the original initialization?
