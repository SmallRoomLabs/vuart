#!/bin/bash

FILE=uart
FILES=$(ls *.v | sed s/${FILE}\.\v//)
DR="docker run --rm --log-driver=none -a stdout -a stderr -w/work -v${PWD}/:/work"
PCF=dummy.pcf
PACKAGE=vq100
XTAL=100
CLK=25

SKIN=netlistsvg.skin
INKSCAPE=/Applications/Inkscape.app/Contents/MacOS/Inkscape
function jsonToPng {
    netlistsvg $1.json -o $1.svg --skin $SKIN
    $INKSCAPE $1.svg --without-gui --export-dpi=150 --export-background=WHITE --export-background-opacity=1.0 --export-type=png --export-file $1.png 2> /dev/null
    rm $1.svg $1.json
}

echo --LINTING
$DR verilator/verilator -Wall -Wno-UNUSED --top-module $FILE --lint-only $FILE.v $FILES

echo --YOSYSING
$DR cranphin/icestorm yosys  -p "synth_ice40 -top $FILE -json $FILE.json" $FILE.v $FILES > $FILE.yosys.tmp
if [ $? != 0 ]; then echo "ERROR"; cat $FILE.yosys.tmp; exit 1; fi

echo --PLACEING
$DR cranphin/icestorm nextpnr-ice40 --pcf-allow-unconstrained --freq $CLK --hx1k --package $PACKAGE --pcf $PCF --json $FILE.json --asc $FILE.asc > $FILE.nextpnr.tmp 2> $FILE.nextpnr.tmp2 
if [ $? != 0 ]; then echo "ERROR"; cat $FILE.nextpnr.tmp; cat $FILE.nextpnr.tmp2; exit 1; fi
cat $FILE.nextpnr.tmp2 | grep "Info: Max frequency for clock"
cat $FILE.nextpnr.tmp2 | sed -ne '/^Info: Device utilisation:/,$ p' | sed '1d' | sed 's/        //g' | sed -n '/^[[:space:]]*$/q;p' | sed 's/Info: //g'

echo --TIMING
$DR cranphin/icestorm icetime -c $CLK -d hx1k -P $PACKAGE -p $PCF -m $FILE.asc > $FILE.icetime.tmp
cat $FILE.icetime.tmp | grep -A1 'Timing' | sed 's/\/\/ /        /g'
if [ $? != 0 ]; then echo "ERROR"; exit 1; fi

echo --PACKING
$DR cranphin/icestorm icepack $FILE.asc $FILE.bin
if [ $? != 0 ]; then echo "ERROR"; exit 1; fi

echo --GRAPHING
$DR cranphin/icestorm yosys -q -p "prep -top $FILE; write_json $FILE.json" $FILE.v
if [ $? != 0 ]; then echo "ERROR"; exit 1; fi
jsonToPng $FILE &

if [ "$1" == "up" ]; then
    ./upload/iceflash /dev/cu.usbmodem48065801 -h -e -w $FILE.bin -g
    tio /dev/cu.usbmodem48065801 
    exit 0;
fi


echo --TESTING
$DR cranphin/iverilog iverilog -g2012 -o $FILE.vvp $FILE.vt $FILE.v $FILES 
if [ $? != 0 ]; then echo "ERROR"; exit 1; fi
$DR cranphin/iverilog vvp $FILE.vvp 
if [ $? != 0 ]; then echo "ERROR"; exit 1; fi

echo --Done
