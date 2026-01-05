# Page64

## Attr
- pageMask : mark 64 slots is active or not
- activeCount: number of active slots
- entityOnPage: 0, 1, 2, ... 4095 => the offset on the block

Page64 offer function for Block64
Block64 can operate slots on Page64

* components: I design a array with length 4096 to store components

4096 / 64 -> blockid
4096 % 64 -> pageid


1. add : activate slots and give index on componets, double activate will break
2. remove: inactive slots on page

