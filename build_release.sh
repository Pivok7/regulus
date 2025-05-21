#!/bin/sh

zig build -Doptimize=ReleaseFast
strip zig-out/bin/regulus
